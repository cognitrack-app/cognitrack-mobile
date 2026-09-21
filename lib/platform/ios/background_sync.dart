/// iOS background sync handler using BGAppRefresh.
/// Called from native AppDelegate via MethodChannel.
library;

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../../core/sync/sync_engine.dart';

class IOSBackgroundSync {
  static const MethodChannel _channel = MethodChannel('com.cognitrack/sync');
  static SyncEngine? _syncEngine;

  static void initialize(SyncEngine syncEngine) {
    _syncEngine = syncEngine;
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'triggerBackgroundSync') {
      if (_syncEngine != null) {
        try {
          await _syncEngine!.syncNow();
          if (kDebugMode) {
            debugPrint('[IOSBackgroundSync] Background sync completed successfully');
          }
        } catch (e, st) {
          debugPrint('[IOSBackgroundSync] Background sync failed: $e\n$st');
          rethrow;
        }
      }
    }
  }
}