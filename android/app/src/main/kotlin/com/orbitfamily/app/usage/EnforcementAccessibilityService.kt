package com.orbitfamily.app.usage

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Handler
import android.os.Looper
import android.preference.PreferenceManager
import android.provider.Settings
import android.view.accessibility.AccessibilityEvent
import org.json.JSONObject

/**
 * AccessibilityService that enforces screen-time limits and app blocks.
 *
 * Reads cached rules from SharedPreferences (written by Dart's RuleCacheService)
 * and queries UsageStatsManager locally, so enforcement works fully offline.
 *
 * On TYPE_WINDOW_STATE_CHANGED, checks the foreground app against rules:
 *   - Always-allowed packages are never blocked
 *   - Per-app blocks (blockedApps) are enforced
 *   - Phone-wide block (allBlockedUntil) is enforced
 *   - Per-app daily limits are enforced
 *   - Total daily limit is enforced
 *
 * When a block is triggered, launches LockActivity.
 * Re-checks every ~12 seconds while a blocked app remains in the foreground.
 */
class EnforcementAccessibilityService : AccessibilityService() {

    private val checkHandler = Handler(Looper.getMainLooper())
    private var checkRunnable: Runnable? = null

    companion object {
        const val CHECK_INTERVAL_MS = 12000L

        // Must match AppConstants.alwaysAllowedPackages in Dart
        internal val alwaysAllowedPackages = setOf(
            "com.orbitfamily.app",
            "com.android.systemui",
            "com.android.settings",
            "com.android.server.telecom",
            "com.android.incallui",
        )

        fun isServiceEnabled(context: Context): Boolean {
            val enabledServices =
                Settings.Secure.getString(
                    context.contentResolver,
                    Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
                )
            return enabledServices?.contains("${context.packageName}/.usage.EnforcementAccessibilityService") == true
        }

        fun openSettings(context: Context) {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
        }
        serviceInfo = info
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val packageName = event?.packageName?.toString() ?: return
        checkAndEnforce(packageName)
    }

    override fun onInterrupt() {
        // Service interrupted by system
    }

    private fun checkAndEnforce(packageName: String) {
        // Always-allowed apps are never blocked
        if (alwaysAllowedPackages.contains(packageName)) {
            stopPeriodicCheck()
            return
        }

        val context = applicationContext
        val prefs: SharedPreferences = PreferenceManager.getDefaultSharedPreferences(context)

        val familyId = prefs.getString("flutter.linked_family_id", "") ?: ""
        if (familyId.isEmpty()) return
        val childId = prefs.getString("flutter.linked_child_id", "") ?: ""
        if (childId.isEmpty()) return

        // Read cached rules (offline-capable)
        val rulesKey = "orbit_rules_${familyId}_${childId}"
        val rulesJson = prefs.getString(rulesKey, "") ?: ""
        if (rulesJson.isEmpty()) return
        val rules = parseRules(rulesJson) ?: return

        val now = System.currentTimeMillis()

        // Check phone-wide block
        if (rules.allBlockedUntilMs != null && now < rules.allBlockedUntilMs) {
            showLock(context)
            return
        }

        // Check per-app block
        val blockUntilMs = rules.blockedApps[packageName]
        if (blockUntilMs != null && now < blockUntilMs) {
            showLock(context)
            return
        }

        // Check per-app daily limit
        val appLimitMs = rules.appLimits[packageName]
        if (appLimitMs != null) {
            val appUsageMs = getAppUsageMs(context, packageName)
            if (appUsageMs >= appLimitMs) {
                showLock(context)
                return
            }
        }

        // Check total daily limit
        if (rules.dailyLimitMs != null) {
            val totalMs = getTotalUsageMs(context)
            if (totalMs >= rules.dailyLimitMs) {
                showLock(context)
                return
            }
        }

        // Not blocked - stop checking
        stopPeriodicCheck()
    }

    private fun showLock(context: Context) {
        startPeriodicCheck()

        val intent = Intent(context, LockActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        context.startActivity(intent)
    }

    private fun startPeriodicCheck() {
        stopPeriodicCheck()
        val runnable = object : Runnable {
            override fun run() {
                val currentPkg = getForegroundPackageName(applicationContext)
                if (currentPkg != null) {
                    checkAndEnforce(currentPkg)
                }
                checkHandler.postDelayed(this, CHECK_INTERVAL_MS)
            }
        }
        checkRunnable = runnable
        checkHandler.postDelayed(runnable, CHECK_INTERVAL_MS)
    }

    private fun stopPeriodicCheck() {
        checkRunnable?.let { checkHandler.removeCallbacks(it) }
        checkRunnable = null
    }

    private fun getForegroundPackageName(context: Context): String? {
        return try {
            val activityManager =
                context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val tasks = activityManager.appTasks
            tasks.firstOrNull()?.taskInfo?.topActivity?.packageName
        } catch (e: Exception) {
            null
        }
    }

    private fun getAppUsageMs(context: Context, packageName: String): Long {
        val usage = UsageStatsHelper.getTodayUsage(context)
        return usage.find { it.packageName == packageName }?.ms ?: 0L
    }

    private fun getTotalUsageMs(context: Context): Long {
        val usage = UsageStatsHelper.getTodayUsage(context)
        return usage.sumOf { it.ms }
    }

    private fun parseRules(json: String): RuleData? {
        return try {
            val obj = JSONObject(json)
            val dailyLimitMs = obj.optLong("dailyLimitMs", -1)
            val dailyLimit = if (dailyLimitMs >= 0) dailyLimitMs else null

            val appLimits = mutableMapOf<String, Long>()
            val appLimitsObj = obj.optJSONObject("appLimits")
            if (appLimitsObj != null) {
                val keys = appLimitsObj.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    appLimits[key] = appLimitsObj.getLong(key)
                }
            }

            val blockedApps = mutableMapOf<String, Long>()
            val blockedAppsObj = obj.optJSONObject("blockedApps")
            if (blockedAppsObj != null) {
                val keys = blockedAppsObj.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    val isoString = blockedAppsObj.getString(key)
                    val ms = parseIso8601Ms(isoString)
                    if (ms != null) blockedApps[key] = ms
                }
            }

            var allBlockedUntilMs: Long? = null
            val allBlockedIso = obj.optString("allBlockedUntil", null)
            if (allBlockedIso != null) {
                allBlockedUntilMs = parseIso8601Ms(allBlockedIso)
            }

            RuleData(dailyLimit, appLimits, blockedApps, allBlockedUntilMs)
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    /// Parses an ISO-8601 string to epoch milliseconds. Returns null on failure.
    private fun parseIso8601Ms(isoString: String?): Long? {
        if (isoString == null) return null
        return try {
            java.time.Instant.parse(isoString).toEpochMilli()
        } catch (e: Exception) {
            null
        }
    }

    data class RuleData(
        val dailyLimitMs: Long?,
        val appLimits: Map<String, Long>,
        val blockedApps: Map<String, Long>,
        val allBlockedUntilMs: Long?,
    )
}
