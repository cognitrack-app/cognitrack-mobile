package com.cognitrack.cognitrack_mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.IBinder
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*


/**
 * ForegroundService — persistent background service for CogniTrack tracking.
 *
 * Architecture: NO FlutterEngine runs inside this service. Running a full
 * Dart VM here caused four confirmed bugs:
 *   BUG-1: MissingPluginException — UsageStatsPlugin/ScreenStateReceiver are
 *           only registered on MainActivity's engine, not a service engine.
 *           The service isolate crashes on the first MethodChannel call.
 *   BUG-2: Dual concurrent SQLite write connections from two Dart isolates
 *           (service + MainActivity) without WAL coordination → data corruption.
 *   BUG-3: The USAGE_EVENTS_READY broadcast handler only exists inside
 *           UsageStatsPlugin.onAttachedToEngine() (MainActivity context).
 *           Between reboot and first app open, all usage events were lost.
 *   BUG-4: FlutterEngine cold-start (2–5 s) + Firebase init + SQLiteStore
 *           routinely exceeded the specialUse 10-second startForeground()
 *           deadline → Android force-stopped the service.
 *
 * Fix: The service queries UsageStatsManager natively (Kotlin) and buffers
 * the collected events as JSON in SharedPreferences under the key
 * "pending_usage_events". When MainActivity starts and UsageStatsPlugin
 * attaches, it calls UsageEventBuffer.drain() to retrieve and clear the
 * buffered events, then forwards them to Dart via the existing channel.
 *
 * This approach:
 *   - calls startForeground() synchronously in onStartCommand() — no timeout
 *   - has zero concurrent SQLite connections
 *   - loses zero events between reboot and app open
 *   - has no MethodChannel calls from a backgrounded process
 */
class ForegroundService : Service() {
    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    companion object {
        private const val CHANNEL_ID        = "cognitrack_tracking"
        private const val NOTIFICATION_ID   = 1001
        const  val ACTION_START             = "com.cognitrack.START_TRACKING"
        const  val ACTION_STOP              = "com.cognitrack.STOP_TRACKING"

        /** Launcher and system packages to exclude — same set as UsageStatsPlugin. */
        private val EXCLUDED_PACKAGES = setOf(
            "com.android.launcher",
            "com.android.launcher3",
            "com.google.android.apps.nexuslauncher",
            "com.sec.android.app.launcher",
            "com.samsung.android.app.spage",
            "com.miui.home",
            "com.oneplus.launcher",
            "com.oppo.launcher",
            "net.one.punch.launcher",
            "com.huawei.android.launcher",
            "com.hihonor.android.launcher",
            "com.asus.launcher",
            "com.lge.launcher3",
        )

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
        // Create notification channel synchronously — this is fast and required
        // before buildNotification() can succeed.
        createNotificationChannel()
        // NOTE: startForeground() is NOT called here. It is called at the top
        // of onStartCommand() so it always runs within the OS deadline regardless
        // of which code path reaches it first.
    }

    private var isPolling = false

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                // BUG-4 FIX: stopForeground must be called before stopSelf so
                // the persistent notification is cleared immediately.
                isPolling = false
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
            else -> {
                // BUG-4 FIX: startForeground() is the FIRST thing called in
                // onStartCommand(), synchronously, before any I/O or coroutine
                // launch. The specialUse 10-second deadline is met on every
                // device because no heavy initialization precedes this call.
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
        isPolling = false
        serviceScope.cancel()
        super.onDestroy()
    }

    // ── Native usage polling ──────────────────────────────────────────────────

    /**
     * BUG-1 / BUG-2 / BUG-3 FIX:
     * Poll UsageStatsManager every 60 seconds entirely in Kotlin.
     * Results are written to SharedPreferences via UsageEventBuffer so they
     * are available to UsageStatsPlugin when MainActivity eventually opens,
     * even if the app was never opened after reboot.
     *
     * No MethodChannel, no FlutterEngine, no Dart isolate, no SQLite.
     */
    private fun startPollingLoop() {
        var lastQueriedEndMs = System.currentTimeMillis() - 60_000L
        serviceScope.launch {
            while (isActive && isPolling) {
                val endMs   = System.currentTimeMillis()
                val startMs = lastQueriedEndMs
                lastQueriedEndMs = endMs

                val events = queryUsageEventsNative(startMs, endMs)
                if (events.isNotEmpty()) {
                    // Buffer into SharedPreferences for MainActivity to drain
                    UsageEventBuffer.append(applicationContext, events)
                }
                delay(60_000L)
            }
        }
    }

    /**
     * Query UsageStatsManager natively and return the raw event list.
     * Only MOVE_TO_FOREGROUND / MOVE_TO_BACKGROUND events are collected.
     * Launcher and system packages are filtered out — same logic as
     * UsageStatsPlugin.queryUsageEvents() so data is consistent.
     */
    private fun queryUsageEventsNative(
        startMs: Long,
        endMs:   Long,
    ): List<Map<String, Any>> {
        val usm = applicationContext.getSystemService(Context.USAGE_STATS_SERVICE)
            as? UsageStatsManager ?: return emptyList()

        val usageEvents = usm.queryEvents(startMs, endMs)
        val result      = mutableListOf<Map<String, Any>>()
        val event       = UsageEvents.Event()
        val lastFgTs    = mutableMapOf<String, Long>()

        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(event)
            val pkg = event.packageName ?: continue
            if (pkg in EXCLUDED_PACKAGES || pkg == packageName) continue

            when (event.eventType) {
                UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                    lastFgTs[pkg] = event.timeStamp
                    result.add(mapOf(
                        "packageName" to pkg,
                        "timestamp"   to event.timeStamp,
                        "eventType"   to "switch",
                        "durationMs"  to 0L,
                    ))
                }
                UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                    val fgTs     = lastFgTs[pkg] ?: event.timeStamp
                    val duration = event.timeStamp - fgTs
                    result.add(mapOf(
                        "packageName" to pkg,
                        "timestamp"   to event.timeStamp,
                        "eventType"   to "idle",
                        "durationMs"  to duration,
                    ))
                    lastFgTs.remove(pkg)
                }
            }
        }
        return result
    }

    // ── Notification ──────────────────────────────────────────────────────────

    private fun buildNotification(): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_IMMUTABLE,
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
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Background focus quality monitoring"
        }
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

}
