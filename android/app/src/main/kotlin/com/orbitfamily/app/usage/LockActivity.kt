package com.orbitfamily.app.usage

import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.content.DialogInterface
import android.content.Intent
import android.content.SharedPreferences
import android.os.Bundle
import android.preference.PreferenceManager
import android.view.Window
import android.view.WindowManager
import android.widget.EditText
import com.orbitfamily.app.R

/**
 * Full-screen lock activity shown when an app is blocked or a time limit is reached.
 * Displays "Time's up. Ask your parent" and cannot be dismissed by the child.
 * Includes a "Parent unlock" option that accepts the parent PIN to grant +15 min.
 */
class LockActivity : Activity() {

    private var checkHandler: android.os.Handler? = null
    private var checkRunnable: Runnable? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Make it full-screen and always on top
        window.requestFeature(Window.FEATURE_NO_TITLE)
        window.addFlags(
            WindowManager.LayoutParams.FLAG_FULLSCREEN or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
        )

        setContentView(R.layout.activity_lock)

        // Wire up parent unlock button
        findViewById<android.widget.Button>(R.id.btn_parent_unlock).setOnClickListener {
            showParentUnlockDialog()
        }

        // Start periodic re-check while lock is showing
        startPeriodicCheck()
    }

    override fun onResume() {
        super.onResume()
        moveTaskToBack(false)
    }

    override fun onBackPressed() {
        // Ignore back button - child cannot dismiss the lock
    }

    override fun onDestroy() {
        stopPeriodicCheck()
        super.onDestroy()
    }

    private fun startPeriodicCheck() {
        stopPeriodicCheck()
        checkHandler = android.os.Handler(android.os.Looper.getMainLooper())
        val runnable = object : Runnable {
            override fun run() {
                // Re-check if unlock time has passed
                val prefs = PreferenceManager.getDefaultSharedPreferences(this@LockActivity)
                val unlockUntilMs = prefs.getLong("orbit_parent_unlock_until_ms", 0)
                if (unlockUntilMs > 0 && System.currentTimeMillis() >= unlockUntilMs) {
                    // Unlock expired, finish lock activity
                    this@LockActivity.finish()
                }
                checkHandler?.postDelayed(this, 5000)
            }
        }
        checkRunnable = runnable
        checkHandler?.postDelayed(runnable, 5000)
    }

    private fun stopPeriodicCheck() {
        checkRunnable?.let { checkHandler?.removeCallbacks(it) }
        checkHandler = null
        checkRunnable = null
    }

    /// Shows the parent unlock PIN dialog.
    fun showParentUnlockDialog() {
        val input = EditText(this).apply {
            inputType = android.text.InputType.TYPE_CLASS_NUMBER or
                android.text.InputType.TYPE_NUMBER_VARIATION_PASSWORD
            hint = "Enter parent PIN"
        }

        AlertDialog.Builder(this)
            .setTitle("Parent Unlock")
            .setMessage("Enter the parent PIN to grant +15 minutes.")
            .setView(input)
            .setPositiveButton("Unlock") { _, _ ->
                val pin = input.text.toString().trim()
                if (pin.isNotEmpty()) {
                    verifyPinAndUnlock(pin)
                }
            }
            .setNegativeButton("Cancel", null)
            .setCancelable(false)
            .show()
    }

    private fun verifyPinAndUnlock(pin: String) {
        val prefs = PreferenceManager.getDefaultSharedPreferences(this)
        val storedHash = prefs.getString("orbit_parent_pin_hash", "") ?: ""
        val storedSalt = prefs.getString("orbit_parent_pin_salt", "") ?: ""

        if (storedHash.isEmpty() || storedSalt.isEmpty()) {
            showError("No PIN has been set yet.")
            return
        }

        // Hash entered PIN with stored salt
        val inputBytes = (pin + ":" + storedSalt).toByteArray()
        val digest = java.security.MessageDigest.getInstance("SHA-256").digest(inputBytes)
        val inputHash = digest.joinToString("") { "%02x".format(it) }

        if (inputHash == storedHash) {
            // PIN correct: grant +15 minutes
            val unlockUntilMs = System.currentTimeMillis() + (15 * 60 * 1000L)
            prefs.edit().putLong("orbit_parent_unlock_until_ms", unlockUntilMs).apply()

            finish()
        } else {
            showError("Incorrect PIN.")
        }
    }

    private fun showError(message: String) {
        runOnUiThread {
            AlertDialog.Builder(this)
                .setTitle("Unlock Failed")
                .setMessage(message)
                .setPositiveButton("OK", null)
                .setCancelable(false)
                .show()
        }
    }

    companion object {
        fun start(context: Context) {
            val intent = Intent(context, LockActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            context.startActivity(intent)
        }
    }
}
