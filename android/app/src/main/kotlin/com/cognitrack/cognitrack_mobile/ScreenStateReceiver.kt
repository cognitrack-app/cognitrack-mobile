package com.cognitrack.cognitrack_mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * ScreenStateReceiver — listens to ACTION_SCREEN_ON and ACTION_USER_PRESENT.
 *
 * Zero extra permissions required — these are standard system broadcasts.
 *
 * MethodChannel:  com.cognitrack/screen_state
 *   - getTodayPickupCount() → Int
 *   - resetCounter()        → void
 *
 * EventChannel:   com.cognitrack/screen_events
 *   - Emits Unix timestamp (Long) on each screen-on event
 */
class ScreenStateReceiver : FlutterPlugin, BroadcastReceiver() {
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var context: Context
    private lateinit var prefs: SharedPreferences
    private var eventSink: EventChannel.EventSink? = null

    companion object {
        private const val PREFS_NAME = "cognitrack_screen"
        private const val KEY_TODAY_PICKUPS = "today_pickups"
        private const val KEY_LAST_RESET_DATE = "last_reset_date"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        methodChannel = MethodChannel(binding.binaryMessenger, "com.cognitrack/screen_state")
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getTodayPickupCount" -> {
                    maybeResetForNewDay()
                    result.success(prefs.getInt(KEY_TODAY_PICKUPS, 0))
                }
                "resetCounter" -> {
                    prefs.edit().putInt(KEY_TODAY_PICKUPS, 0).apply()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        eventChannel = EventChannel(binding.binaryMessenger, "com.cognitrack/screen_events")
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                eventSink = sink
            }
            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })

        // Register broadcast receiver
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        context.registerReceiver(this, filter)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context.unregisterReceiver(this)
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_USER_PRESENT -> {
                maybeResetForNewDay()
                val current = prefs.getInt(KEY_TODAY_PICKUPS, 0)
                prefs.edit().putInt(KEY_TODAY_PICKUPS, current + 1).apply()
                eventSink?.success(System.currentTimeMillis())
            }
            Intent.ACTION_SCREEN_ON -> {
                // Do nothing here — AOD triggers this without a real pickup
            }
        }
    }

    /** Reset pickup counter at midnight. */
    private fun maybeResetForNewDay() {
        val today = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US)
            .format(java.util.Date())
        val lastReset = prefs.getString(KEY_LAST_RESET_DATE, "")
        if (lastReset != today) {
            prefs.edit()
                .putInt(KEY_TODAY_PICKUPS, 0)
                .putString(KEY_LAST_RESET_DATE, today)
                .apply()
        }
    }
}
