package com.cognitrack.cognitrack_mobile

import android.app.Application
import android.content.Context
import androidx.work.Configuration
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequest
import androidx.work.PeriodicWorkRequest.Builder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

object WorkManagerScheduler {
    private const val PERIODIC_SYNC_WORK_NAME = "cognitrack-periodic-sync"
    private const val HOURLY_SYNC_WORK_NAME = "cognitrack-hourly-sync"
    private const val PERIODIC_INTERVAL_MINUTES = 15
    private const val HOURLY_INTERVAL_HOURS = 1

    fun initialize(app: Application) {
        val config = Configuration.Builder()
            .setMinimumLoggingLevel(android.util.Log.DEBUG)
            .build()
        WorkManager.initialize(app, config)

        // Periodic sync every 15 minutes
        val syncRequest = Builder(
            SyncWorker::class.java,
            PERIODIC_INTERVAL_MINUTES.toLong(), TimeUnit.MINUTES
        )
            .setInitialDelay(PERIODIC_INTERVAL_MINUTES.toLong(), TimeUnit.MINUTES)
            .addTag(PERIODIC_SYNC_WORK_NAME)
            .build()

        WorkManager.getInstance(app)
            .enqueueUniquePeriodicWork(
                PERIODIC_SYNC_WORK_NAME,
                ExistingPeriodicWorkPolicy.REPLACE,
                syncRequest
            )

        // Hourly sync for full metrics computation
        val hourlyRequest = Builder(
            HourlySyncWorker::class.java,
            HOURLY_INTERVAL_HOURS.toLong(), TimeUnit.HOURS
        )
            .setInitialDelay(HOURLY_INTERVAL_HOURS.toLong(), TimeUnit.HOURS)
            .addTag(HOURLY_SYNC_WORK_NAME)
            .build()

        WorkManager.getInstance(app)
            .enqueueUniquePeriodicWork(
                HOURLY_SYNC_WORK_NAME,
                ExistingPeriodicWorkPolicy.REPLACE,
                hourlyRequest
            )
    }
}

/**
 * Worker that triggers a phone sync when the app is in the background.
 * Writes a sync trigger marker to SQLite so the Dart side picks it up
   on the next event insert or app resume.
 */
class SyncWorker(appContext: Context, workerParams: WorkerParameters)
    : Worker(appContext, workerParams) {

    override fun doWork(): Result {
        try {
            // Buffer a sync trigger event via UsageEventBuffer so the Dart
            // side drains it on next app resume or event insert.
            UsageEventBuffer.appendSyncTrigger(applicationContext)
            return Result.success()
        } catch (e: Exception) {
            return Result.failure()
        }
    }
}

/**
 * Worker that runs a full hourly sync for metrics computation.
 */
class HourlySyncWorker(appContext: Context, workerParams: WorkerParameters)
    : Worker(appContext, workerParams) {

    override fun doWork(): Result {
        try {
            UsageEventBuffer.appendSyncTrigger(applicationContext)
            return Result.success()
        } catch (e: Exception) {
            return Result.failure()
        }
    }
}