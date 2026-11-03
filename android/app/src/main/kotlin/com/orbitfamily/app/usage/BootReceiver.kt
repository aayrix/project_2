package com.orbitfamily.app.usage

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action == Intent.ACTION_BOOT_COMPLETED || action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            val prefs = context.getSharedPreferences(
                "FlutterSharedPreferences",
                Context.MODE_PRIVATE
            )

            val isLinked = !prefs.getString("flutter.linked_family_id", null).isNullOrEmpty()
            val childName = prefs.getString("flutter.linked_child_name", "Child") ?: "Child"

            if (isLinked) {
                // 1. Android 12+ Safe: WorkManager handles the reliable background sync
                UsageSyncWorker.schedulePeriodicSync(context)

                // 2. Attempt foreground notification restart (safely handled on Android 12+)
                MonitoringForegroundService.startServiceSafely(context, childName)
            }
        }
    }
}
