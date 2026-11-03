package com.orbitfamily.app.usage

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import java.util.Calendar

object UsageStatsHelper {

    data class AppUsageInfo(
        val packageName: String,
        val appName: String,
        val category: Int,
        val ms: Long
    )

    /**
     * Calculates millisecond-accurate foreground app usage for today (midnight 00:00:00 to now).
     *
     * Architectural Decisions & Edge Case Handling:
     * 1. queryEvents vs queryUsageStats:
     *    queryUsageStats() uses pre-aggregated daily buckets whose rollover is managed by OEM
     *    maintenance routines, frequently yielding stale or wrong "today" totals on Samsung/Xiaomi.
     *    queryEvents() provides raw, timestamped lifecycle transitions for precise measurement.
     *
     * 2. App Already Open at Midnight:
     *    We start querying 2 hours before midnight. If an app was resumed prior to midnight and
     *    not paused before midnight, its foreground counter begins clamped at 00:00:00 today.
     *
     * 3. App Still in Foreground at Query Time:
     *    Any app with an open resume timestamp at the end of the events stream accumulates
     *    foreground time up to System.currentTimeMillis().
     *
     * 4. Screen Off and Keyguard Lock Events:
     *    When SCREEN_NON_INTERACTIVE or KEYGUARD_SHOWN fires, active foreground timers are paused
     *    so time with the screen off or locked is never counted as screen time. When
     *    SCREEN_INTERACTIVE or KEYGUARD_HIDDEN fires, timing resumes.
     *
     * 5. Ignoring Launcher & System UI:
     *    The device's default Home Launcher (e.g. Pixel Launcher, OneUI Home), System UI,
     *    the Android framework ("android"), and Orbit Family itself are excluded.
     */
    fun getTodayUsage(context: Context): List<AppUsageInfo> {
        val usageStatsManager =
            context.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
                ?: return emptyList()

        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val todayMidnight = calendar.timeInMillis
        val queryStart = todayMidnight - (2 * 60 * 60 * 1000L) // 2 hours before midnight
        val endTime = System.currentTimeMillis()

        // Discover default home launcher package to ignore
        val packageManager = context.packageManager
        val homeIntent = Intent(Intent.ACTION_MAIN).apply { addCategory(Intent.CATEGORY_HOME) }
        val resolveInfo = packageManager.resolveActivity(homeIntent, PackageManager.MATCH_DEFAULT_ONLY)
        val defaultLauncherPackage = resolveInfo?.activityInfo?.packageName

        val usageEvents = usageStatsManager.queryEvents(queryStart, endTime)
        val event = UsageEvents.Event()

        val foregroundDurations = mutableMapOf<String, Long>()
        var activeForegroundPackage: String? = null
        var activeResumeTime: Long = 0L
        var isScreenOnAndUnlocked = true

        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(event)
            val eventTime = event.timeStamp

            when (event.eventType) {
                // Case 4: Screen turned off or phone locked -> pause counting
                UsageEvents.Event.SCREEN_NON_INTERACTIVE,
                UsageEvents.Event.KEYGUARD_SHOWN -> {
                    if (isScreenOnAndUnlocked && activeForegroundPackage != null && activeResumeTime > 0) {
                        val effectiveStart = maxOf(activeResumeTime, todayMidnight)
                        if (eventTime > effectiveStart) {
                            val duration = eventTime - effectiveStart
                            foregroundDurations[activeForegroundPackage!!] =
                                (foregroundDurations[activeForegroundPackage!!] ?: 0L) + duration
                        }
                        activeResumeTime = 0L
                    }
                    isScreenOnAndUnlocked = false
                }

                // Case 4: Screen turned on / phone unlocked -> resume counting if app foregrounded
                UsageEvents.Event.SCREEN_INTERACTIVE,
                UsageEvents.Event.KEYGUARD_HIDDEN -> {
                    isScreenOnAndUnlocked = true
                    if (activeForegroundPackage != null) {
                        activeResumeTime = eventTime
                    }
                }

                // User navigated to an app
                UsageEvents.Event.ACTIVITY_RESUMED,
                UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                    val pkg = event.packageName ?: continue

                    // Close previous app duration if any
                    if (activeForegroundPackage != null && activeResumeTime > 0 && isScreenOnAndUnlocked) {
                        val effectiveStart = maxOf(activeResumeTime, todayMidnight)
                        if (eventTime > effectiveStart) {
                            val duration = eventTime - effectiveStart
                            foregroundDurations[activeForegroundPackage!!] =
                                (foregroundDurations[activeForegroundPackage!!] ?: 0L) + duration
                        }
                    }

                    activeForegroundPackage = pkg
                    // Case 2: If event was before midnight, clamp start to midnight
                    activeResumeTime = if (eventTime < todayMidnight) todayMidnight else eventTime
                }

                // User exited app or switched away
                UsageEvents.Event.ACTIVITY_PAUSED,
                UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                    val pkg = event.packageName ?: continue
                    if (activeForegroundPackage == pkg && activeResumeTime > 0 && isScreenOnAndUnlocked) {
                        val effectiveStart = maxOf(activeResumeTime, todayMidnight)
                        if (eventTime > effectiveStart) {
                            val duration = eventTime - effectiveStart
                            foregroundDurations[pkg] =
                                (foregroundDurations[pkg] ?: 0L) + duration
                        }
                        activeResumeTime = 0L
                        activeForegroundPackage = null
                    }
                }
            }
        }

        // Case 3: App still in foreground at query time
        if (activeForegroundPackage != null && activeResumeTime > 0 && isScreenOnAndUnlocked) {
            val effectiveStart = maxOf(activeResumeTime, todayMidnight)
            if (endTime > effectiveStart) {
                val duration = endTime - effectiveStart
                foregroundDurations[activeForegroundPackage!!] =
                    (foregroundDurations[activeForegroundPackage!!] ?: 0L) + duration
            }
        }

        val ourPackage = context.packageName
        val resultList = mutableListOf<AppUsageInfo>()

        // Case 5: Ignore launcher, system UI, Android OS, and Orbit Family itself
        val ignoredPackages = setOfNotNull(
            ourPackage,
            defaultLauncherPackage,
            "android",
            "com.android.systemui"
        )

        for ((pkg, totalMs) in foregroundDurations) {
            // Filter out ignored packages and transient sub-second transitions (< 1000ms)
            if (totalMs < 1000L || ignoredPackages.contains(pkg)) continue

            val appInfo = try {
                packageManager.getApplicationInfo(pkg, 0)
            } catch (e: PackageManager.NameNotFoundException) {
                null
            }

            val appName = if (appInfo != null) {
                packageManager.getApplicationLabel(appInfo).toString()
            } else {
                pkg
            }

            val category = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && appInfo != null) {
                appInfo.category
            } else {
                ApplicationInfo.CATEGORY_UNDEFINED
            }

            resultList.add(
                AppUsageInfo(
                    packageName = pkg,
                    appName = appName,
                    category = category,
                    ms = totalMs
                )
            )
        }

        resultList.sortByDescending { it.ms }
        return resultList
    }
}
