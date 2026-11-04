package com.orbitfamily.app

import android.Manifest
import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Process
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.orbitfamily.app.usage.EnforcementAccessibilityService
import com.orbitfamily.app.usage.MonitoringForegroundService
import com.orbitfamily.app.usage.UsageStatsHelper
import com.orbitfamily.app.usage.UsageSyncWorker
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.orbitfamily.app/usage"
    private val NOTIFICATION_PERMISSION_REQUEST_CODE = 301

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasUsagePermission" -> {
                    result.success(hasUsagePermission())
                }

                "openUsageSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INTENT_ERROR", e.localizedMessage, null)
                    }
                }

                "hasNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        val granted = ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.POST_NOTIFICATIONS
                        ) == PackageManager.PERMISSION_GRANTED
                        result.success(granted)
                    } else {
                        // Automatically granted on Android 12 and below
                        result.success(true)
                    }
                }

                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                            NOTIFICATION_PERMISSION_REQUEST_CODE
                        )
                    }
                    result.success(true)
                }

                "getTodayUsage" -> {
                    try {
                        val usageList = UsageStatsHelper.getTodayUsage(applicationContext)
                        val mappedList = usageList.map {
                            mapOf(
                                "packageName" to it.packageName,
                                "appName" to it.appName,
                                "category" to it.category,
                                "ms" to it.ms
                            )
                        }
                        result.success(mappedList)
                    } catch (e: Exception) {
                        result.error("USAGE_QUERY_ERROR", e.localizedMessage, null)
                    }
                }

                "startMonitoringService" -> {
                    val childName = call.argument<String>("childName") ?: "Child"
                    try {
                        // 1. Show persistent foreground notification
                        MonitoringForegroundService.startServiceSafely(applicationContext, childName)

                        // 2. Schedule 15-minute background WorkManager
                        UsageSyncWorker.schedulePeriodicSync(applicationContext)

                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_START_ERROR", e.localizedMessage, null)
                    }
                }

                "stopMonitoringService" -> {
                    try {
                        MonitoringForegroundService.stopService(applicationContext)
                        UsageSyncWorker.cancelPeriodicSync(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_STOP_ERROR", e.localizedMessage, null)
                    }
                }

                "getDeviceModelName" -> {
                    val manufacturer = Build.MANUFACTURER.replaceFirstChar {
                        if (it.isLowerCase()) it.titlecase() else it.toString()
                    }
                    val model = Build.MODEL
                    val name = if (model.startsWith(manufacturer, ignoreCase = true)) {
                        model
                    } else {
                        "$manufacturer $model"
                    }
                    result.success(name)
                }

                "isAccessibilityEnabled" -> {
                    result.success(EnforcementAccessibilityService.isServiceEnabled(this))
                }

                "openAccessibilitySettings" -> {
                    try {
                        EnforcementAccessibilityService.openSettings(this)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ACCESSIBILITY_SETTINGS_ERROR", e.localizedMessage, null)
                    }
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun hasUsagePermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager
            ?: return false
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }
}
