package com.cognitrack.cognitrack_mobile

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.app.AppOpsManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * BUG-3 FIX NOTICE:
 * The previous implementation registered a BroadcastReceiver for
 * "com.cognitrack.USAGE_EVENTS_READY" inside onAttachedToEngine().
 * That receiver only existed while MainActivity was running. Between
 * device reboot and the first app open, ForegroundService was broadcasting
 * to nobody and all events were permanently lost.
 *
 * The new architecture:
 *   - ForegroundService queries UsageStatsManager natively and buffers
 *     results in UsageEventBuffer (SharedPreferences-backed).
 *   - onAttachedToEngine() calls UsageEventBuffer.drain() immediately to
 *     forward any events captured before MainActivity opened.
 *   - No BroadcastReceiver is registered here — ForegroundService no longer
 *     sends the USAGE_EVENTS_READY broadcast.
 */

/**
 * UsageStatsPlugin — exposes UsageStatsManager to Flutter via MethodChannel.
 *
 * Channel: com.cognitrack/usage_stats
 * Methods:
 *   - hasPermission()    → Boolean
 *   - requestPermission() → void (opens Settings)
 *   - queryEvents(startMs, endMs) → List<Map>
 */
class UsageStatsPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.cognitrack/usage_stats")
        channel.setMethodCallHandler(this)

        // BUG-3 FIX: Drain events buffered by ForegroundService while the app
        // was closed (e.g. after reboot, before first app open). This is safe
        // to call on the main thread — drain() is synchronous and fast because
        // it only reads/clears a single SharedPreferences key.
        val buffered = UsageEventBuffer.drain(context)
        if (buffered.isNotEmpty()) {
            channel.invokeMethod("onUsageEvents", buffered)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "hasPermission" -> result.success(hasUsagePermission())
            "requestPermission" -> {
                val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                context.startActivity(intent)
                result.success(null)
            }
            "startForegroundService" -> {
                ForegroundService.start(context)
                result.success(null)
            }
            "queryEvents" -> {
                val startMs = call.argument<Long>("startMs") ?: 0L
                val endMs = call.argument<Long>("endMs") ?: System.currentTimeMillis()
                CoroutineScope(Dispatchers.IO).launch {
                    val events = queryUsageEvents(startMs, endMs)
                    withContext(Dispatchers.Main) {
                        result.success(events)
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun hasUsagePermission(): Boolean {
        return try {
            val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                context.packageName
            )
            mode == AppOpsManager.MODE_ALLOWED
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Query UsageEvents for the given time range and return a list of maps:
     * [{ packageName, timestamp, eventType, durationMs }]
     *
     * We convert MOVE_TO_FOREGROUND (1) → "switch" and
     * MOVE_TO_BACKGROUND (2) → "idle".
     * Pickup detection is handled by ScreenStateReceiver separately.
     */
    // Launcher packages to exclude — pressing Home fires MOVE_TO_FOREGROUND
    // for the active launcher, which would count as a context switch to 'tools'
    // and inflate switch counts on every device. This set covers all major OEMs.
    private val launcherPackages by lazy {
        setOf(
            "com.android.launcher",              // AOSP generic
            "com.android.launcher3",             // AOSP Launcher3
            "com.google.android.apps.nexuslauncher", // Pixel 6+
            "com.sec.android.app.launcher",      // Samsung One UI
            "com.samsung.android.app.spage",     // Samsung Bixby Home
            "com.miui.home",                     // Xiaomi MIUI
            "com.oneplus.launcher",              // OnePlus OxygenOS
            "com.oppo.launcher",                 // Oppo ColorOS
            "net.one.punch.launcher",            // Realme
            "com.huawei.android.launcher",       // Huawei EMUI
            "com.hihonor.android.launcher",      // Honor
            "com.asus.launcher",                 // ASUS ZenUI
            "com.lge.launcher3",                 // LG UX
            context.packageName                  // CogniTrack itself
        )
    }

    private fun queryUsageEvents(startMs: Long, endMs: Long): List<Map<String, Any>> {
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events = usm.queryEvents(startMs, endMs)
        val result = mutableListOf<Map<String, Any>>()
        val event = UsageEvents.Event()

        // Track last foreground time per package for duration calculation
        val lastForegroundTs = mutableMapOf<String, Long>()

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val pkg = event.packageName ?: continue
            // Skip launchers and CogniTrack itself — all entries are in launcherPackages
            if (pkg in launcherPackages) continue

            when (event.eventType) {
                UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                    lastForegroundTs[pkg] = event.timeStamp
                    result.add(
                        mapOf(
                            "packageName" to pkg,
                            "timestamp" to event.timeStamp,
                            "eventType" to "switch",
                            "durationMs" to 0
                        )
                    )
                }
                UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                    val foregroundTs = lastForegroundTs[pkg] ?: event.timeStamp
                    val duration = event.timeStamp - foregroundTs
                    result.add(
                        mapOf(
                            "packageName" to pkg,
                            "timestamp" to event.timeStamp,
                            "eventType" to "idle",
                            "durationMs" to duration
                        )
                    )
                    lastForegroundTs.remove(pkg)
                }
            }
        }
        return result
    }
}
