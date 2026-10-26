package com.cognitrack.cognitrack_mobile

import android.app.Application
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.platformview.PlatformViewLinkingStrategy

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Register all native plugins
        flutterEngine.plugins.add(UsageStatsPlugin())
        flutterEngine.plugins.add(ScreenStateReceiver())

        // Initialize WorkManager for periodic sync when app is in background
        WorkManagerScheduler.initialize(applicationContext as Application)

        // MethodChannel for sync trigger coordination between Worker and Dart
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cognitrack/sync_trigger")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasPendingSyncTrigger" -> result.success(UsageEventBuffer.hasSyncTrigger(applicationContext))
                    "drainSyncTrigger" -> {
                        UsageEventBuffer.drainSyncTrigger(applicationContext)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
