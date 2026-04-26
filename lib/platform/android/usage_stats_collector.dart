/// Android UsageStats MethodChannel bridge.
/// Calls Kotlin UsageStatsPlugin to get app usage events.
library;

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../../core/cognitive_engine/models.dart';
import '../../core/cognitive_engine/app_normalizer.dart';

class UsageStatsCollector {
  static const _channel = MethodChannel('com.cognitrack/usage_stats');

  /// Request usage stats permission — deep-links to system settings.
  /// Must be called before queryEvents().
  Future<void> requestPermission() async {
    try {
      await _channel
          .invokeMethod('requestPermission')
          .timeout(const Duration(seconds: 5));
    } on PlatformException catch (e) {
      debugPrint('[UsageStatsCollector] requestPermission error: $e');
    }
  }

  /// Check if PACKAGE_USAGE_STATS permission is granted.
  Future<bool> hasPermission() async {
    try {
      final result = await _channel
          .invokeMethod<bool>('hasPermission')
          .timeout(const Duration(seconds: 3), onTimeout: () => false);
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('[UsageStatsCollector] hasPermission error: $e');
      return false;
    }
  }

  /// Start the persistent tracking ForegroundService.
  /// Must be called after permission is granted.
  Future<void> startForegroundService() async {
    try {
      await _channel
          .invokeMethod('startForegroundService')
          .timeout(const Duration(seconds: 5));
    } on PlatformException catch (e) {
      debugPrint('[UsageStatsCollector] startForegroundService error: $e');
    }
  }

  /// Query app usage events from [startMs] to [endMs].
  /// Returns a list of AppEvents with category resolved.
  Future<List<AppEvent>> queryEvents({
    required int startMs,
    required int endMs,
  }) async {
    List<dynamic>? raw;
    try {
      raw = await _channel.invokeMethod<List<dynamic>>(
        'queryEvents',
        {'startMs': startMs, 'endMs': endMs},
      ).timeout(const Duration(seconds: 10), onTimeout: () => <dynamic>[]);
    } on PlatformException catch (e) {
      debugPrint('[UsageStatsCollector] queryEvents error: $e');
      return [];
    }
    if (raw == null || raw.isEmpty) return [];

    final events = <AppEvent>[];
    for (final item in raw) {
      final m = Map<String, dynamic>.from(item as Map);
      final packageName = m['packageName'] as String? ?? '';
      final timestamp = m['timestamp'] as int? ?? 0;
      final eventType = m['eventType'] as String? ?? 'switch';
      final durationMs = m['durationMs'] as int? ?? 0;

      final appId = normalizeAppId(packageName, Platform.android);
      final category = resolveCategory(appId);

      events.add(AppEvent(
        id: '${timestamp}_${packageName.hashCode}',
        timestamp: timestamp,
        appId: appId,
        category: category,
        durationMs: durationMs,
        eventType: EventTypeExt.fromString(eventType),
        deviceType: DeviceType.phone,
      ));
    }
    return events;
  }

  /// Listen for background usage events broadcast by ForegroundService.
  void setUsageEventsHandler(void Function(List<AppEvent>) handler) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onUsageEvents') {
        final raw = call.arguments as List<dynamic>?;
        if (raw == null) return;

        final events = <AppEvent>[];
        for (final item in raw) {
          final m = Map<String, dynamic>.from(item as Map);
          final packageName = m['packageName'] as String? ?? '';
          final timestamp = m['timestamp'] as int? ?? 0;
          final eventType = m['eventType'] as String? ?? 'switch';
          final durationMs = m['durationMs'] as int? ?? 0;

          final appId = normalizeAppId(packageName, Platform.android);
          final category = resolveCategory(appId);

          events.add(AppEvent(
            id: '${timestamp}_${packageName.hashCode}',
            timestamp: timestamp,
            appId: appId,
            category: category,
            durationMs: durationMs,
            eventType: EventTypeExt.fromString(eventType),
            deviceType: DeviceType.phone,
          ));
        }
        handler(events);
      }
    });
  }
}
