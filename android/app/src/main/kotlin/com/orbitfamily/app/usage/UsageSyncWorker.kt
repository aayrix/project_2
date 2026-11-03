package com.orbitfamily.app.usage

import android.app.AppOpsManager
import android.content.Context
import android.os.Process
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions
import kotlinx.coroutines.tasks.await
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.TimeUnit

class UsageSyncWorker(
    appContext: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(appContext, workerParams) {

    companion object {
        const val WORK_NAME = "orbit_family_usage_sync_work"

        fun schedulePeriodicSync(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()

            val syncRequest = PeriodicWorkRequestBuilder<UsageSyncWorker>(
                15, TimeUnit.MINUTES,
                5, TimeUnit.MINUTES // 5 min flex interval
            )
                .setConstraints(constraints)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                syncRequest
            )
        }

        fun cancelPeriodicSync(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
        }
    }

    override suspend fun doWork(): Result {
        val prefs = applicationContext.getSharedPreferences(
            "FlutterSharedPreferences",
            Context.MODE_PRIVATE
        )

        val familyId = prefs.getString("flutter.linked_family_id", null)
        val childId = prefs.getString("flutter.linked_child_id", null)

        if (familyId.isNullOrEmpty() || childId.isNullOrEmpty()) {
            // Not linked yet
            return Result.success()
        }

        if (!hasUsagePermission()) {
            return Result.retry()
        }

        return try {
            val appUsageList = UsageStatsHelper.getTodayUsage(applicationContext)

            var totalMs = 0L
            val appsMap = mutableMapOf<String, Any>()

            for (app in appUsageList) {
                totalMs += app.ms
                appsMap[app.packageName] = mapOf(
                    "appName" to app.appName,
                    "category" to resolveCategoryString(app.packageName, app.category),
                    "ms" to app.ms
                )
            }

            val todayKey = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
            val firestore = FirebaseFirestore.getInstance()

            val usageDayData = mapOf(
                "totalMs" to totalMs,
                "updatedAt" to FieldValue.serverTimestamp(),
                "apps" to appsMap
            )

            // 1. Upload daily usage document
            firestore.collection("families")
                .document(familyId)
                .collection("children")
                .document(childId)
                .collection("usageDays")
                .document(todayKey)
                .set(usageDayData, SetOptions.merge())
                .await()

            // 2. Update child lastSeen timestamp
            firestore.collection("families")
                .document(familyId)
                .collection("children")
                .document(childId)
                .update("lastSeen", FieldValue.serverTimestamp())
                .await()

            Result.success()
        } catch (e: Exception) {
            e.printStackTrace()
            Result.retry()
        }
    }

    private fun hasUsagePermission(): Boolean {
        val appOps = applicationContext.getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager
            ?: return false
        val mode = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                applicationContext.packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                applicationContext.packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun resolveCategoryString(packageName: String, androidCategory: Int): String {
        val pkg = packageName.lowercase()
        return when {
            pkg.contains("youtube") || pkg.contains("netflix") || pkg.contains("disney") || pkg.contains("twitch") -> "video"
            pkg.contains("instagram") || pkg.contains("facebook") || pkg.contains("tiktok") || pkg.contains("twitter") || pkg.contains("snapchat") -> "social"
            pkg.contains("whatsapp") || pkg.contains("telegram") || pkg.contains("discord") || pkg.contains("messenger") -> "communication"
            pkg.contains("chrome") || pkg.contains("firefox") || pkg.contains("browser") -> "browsing"
            pkg.contains("game") || androidCategory == 0 -> "games"
            androidCategory == 1 || androidCategory == 2 -> "video"
            androidCategory == 4 -> "social"
            else -> "other"
        }
    }
}
