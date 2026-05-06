package com.cognitrack.cognitrack_mobile

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * UsageEventBuffer — a SharedPreferences-backed queue that bridges
 * ForegroundService (producer) and UsageStatsPlugin (consumer).
 *
 * Why this exists (BUG-3 fix):
 *   ForegroundService polls UsageStatsManager natively every 60 seconds.
 *   Before this fix, it sent a USAGE_EVENTS_READY broadcast that was only
 *   handled by a BroadcastReceiver registered inside UsageStatsPlugin —
 *   which in turn only lived inside MainActivity's FlutterEngine.
 *   Between device reboot and the first time the user opened the app,
 *   all usage events were silently dropped.
 *
 * New contract:
 *   - ForegroundService.startPollingLoop() calls UsageEventBuffer.append()
 *     to enqueue native Kotlin events as JSON in SharedPreferences.
 *   - UsageStatsPlugin.onAttachedToEngine() calls UsageEventBuffer.drain()
 *     which atomically reads and clears the queue, then forwards the events
 *     to Dart via MethodChannel("onUsageEvents").
 *   - drain() is also called by the USAGE_EVENTS_READY broadcast handler
 *     for the case where MainActivity is already open when the poll fires.
 *
 * Thread safety:
 *   append() is called from a Dispatchers.IO coroutine in the service.
 *   drain() is called from the main thread inside UsageStatsPlugin.
 *   Both are synchronized on the SharedPreferences commit — Android's
 *   SharedPreferences implementation guarantees atomic commit() on a single
 *   file, so there is no torn read/write between the two callers.
 */
object UsageEventBuffer {
    private const val PREFS_NAME  = "cognitrack_event_buffer"
    private const val KEY_PENDING = "pending_usage_events"

    /**
     * Append [events] to the tail of the persistent queue.
     * Each element must be a Map<String, Any> compatible with
     * UsageStatsPlugin.queryUsageEvents() return format:
     *   { packageName, timestamp, eventType, durationMs }
     *
     * Called from Dispatchers.IO — SharedPreferences.commit() is
     * used (not apply()) to guarantee the write is flushed before
     * the next poll fires 60 seconds later.
     */
    fun append(context: Context, events: List<Map<String, Any>>) {
        if (events.isEmpty()) return
        val prefs    = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val existing = prefs.getString(KEY_PENDING, "[]") ?: "[]"
        val array    = try { JSONArray(existing) } catch (_: Exception) { JSONArray() }
        for (e in events) {
            val obj = JSONObject()
            obj.put("packageName", e["packageName"] as? String ?: "")
            obj.put("timestamp",   e["timestamp"]   as? Long   ?: 0L)
            obj.put("eventType",   e["eventType"]   as? String ?: "switch")
            obj.put("durationMs",  e["durationMs"]  as? Long   ?: 0L)
            array.put(obj)
        }
        prefs.edit().putString(KEY_PENDING, array.toString()).commit()
    }

    /**
     * Atomically read and clear the pending queue.
     * Returns all buffered events as a List<Map<String, Any>>.
     * After drain() returns the queue is empty.
     *
     * Called from the main thread inside UsageStatsPlugin.
     */
    fun drain(context: Context): List<Map<String, Any>> {
        val prefs    = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw      = prefs.getString(KEY_PENDING, "[]") ?: "[]"
        // Clear immediately before parsing so we never double-deliver even
        // if parsing throws (corrupt data is silently discarded).
        prefs.edit().putString(KEY_PENDING, "[]").commit()

        return try {
            val array  = JSONArray(raw)
            val result = mutableListOf<Map<String, Any>>()
            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                result.add(mapOf(
                    "packageName" to obj.optString("packageName"),
                    "timestamp"   to obj.optLong("timestamp"),
                    "eventType"   to obj.optString("eventType", "switch"),
                    "durationMs"  to obj.optLong("durationMs"),
                ))
            }
            result
        } catch (_: Exception) {
            emptyList()
        }
    }
}
