package com.orbitfamily.app.usage

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.view.Window
import android.view.WindowManager
import com.orbitfamily.app.R

/**
 * Full-screen lock activity shown when an app is blocked or a time limit is reached.
 * Displays "Time's up. Ask your parent" and cannot be dismissed by the child.
 */
class LockActivity : Activity() {

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
    }

    override fun onResume() {
        super.onResume()
        // Ensure the lock stays in front
        moveTaskToBack(false)
    }

    override fun onBackPressed() {
        // Ignore back button - child cannot dismiss the lock
    }

    companion object {
        fun start(context: android.content.Context) {
            val intent = Intent(context, LockActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            context.startActivity(intent)
        }
    }
}
