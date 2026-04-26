package com.cognitrack.cognitrack_mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*

/**
 * ForegroundService — persistent background service for CogniTrack tracking.
 *
 * Required for Android 8+ to keep UsageStats polling alive when app is backgrounded.
 * Polls every 60 seconds matching the architecture's 5-min velocity window.
 *
 * The service writes events to local SQLite via the Flutter engine's MethodChannel —
 * it does NOT have direct DB access to avoid threading issues.
 * Instead, it sends events to the Flutter isolate via a background MethodChannel.
 */
class ForegroundService : Service() {
    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    companion object {
        private const val CHANNEL_ID = "cognitrack_tracking"
        private const val NOTIFICATION_ID = 1001
        const val ACTION_START = "com.cognitrack.START_TRACKING"
        const val ACTION_STOP = "com.cognitrack.STOP_TRACKING"

        fun start(context: Context) {
            val intent = Intent(context, ForegroundService::class.java).apply {
                action = ACTION_START
            }
            context.startForegroundService(intent)
        }

        fun stop(context: Context) {
            val intent = Intent(context, ForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    private var isPolling = false

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                isPolling = false
                stopSelf()
                return START_NOT_STICKY
            }
            else -> {
                startForeground(NOTIFICATION_ID, buildNotification())
                if (!isPolling) {
                    isPolling = true
                    startPollingLoop()
                }
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        serviceScope.cancel()
        super.onDestroy()
    }

    /**
     * Poll UsageStatsManager every 60 seconds.
     * The 60-second interval feeds the 5-minute velocity window used by the engine.
     */
    private fun startPollingLoop() {
        var lastQueriedEndMs = System.currentTimeMillis() - 60_000L
        serviceScope.launch {
            while (isActive && isPolling) {
                val endMs = System.currentTimeMillis()
                val startMs = lastQueriedEndMs
                lastQueriedEndMs = endMs
                // Broadcast result to Flutter via a dedicated result channel
                val pollIntent = Intent("com.cognitrack.USAGE_EVENTS_READY").apply {
                    putExtra("startMs", startMs)
                    putExtra("endMs", endMs)
                    setPackage(packageName)
                }
                sendBroadcast(pollIntent)
                delay(60_000L)
            }
            isPolling = false
        }
    }

    private fun buildNotification(): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("CogniTrack")
            .setContentText("Monitoring focus quality")
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "CogniTrack Tracking",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Background focus quality monitoring"
        }
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }
}
