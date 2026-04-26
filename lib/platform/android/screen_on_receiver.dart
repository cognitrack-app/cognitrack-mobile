/// Android screen-on / pickup counter MethodChannel bridge.
/// Zero permissions required — uses ACTION_SCREEN_ON broadcast.
library;

import 'package:flutter/services.dart';

class ScreenOnReceiver {
  static const _channel = MethodChannel('com.cognitrack/screen_state');
  static const _eventChannel = EventChannel('com.cognitrack/screen_events');

  /// Get current pickup count for today (incremented by Kotlin BroadcastReceiver).
  Future<int> getTodayPickupCount() async {
    final result = await _channel.invokeMethod<int>('getTodayPickupCount');
    return result ?? 0;
  }

  /// Stream of screen-on events. Each event is a Unix timestamp (int).
  /// Uses safe cast via num? to guard against null or unexpected types
  /// from the Kotlin EventChannel (Long maps to Dart int via standard codec,
  /// but a null or mismatched type would otherwise throw a TypeError).
  Stream<int> get screenOnStream => _eventChannel
      .receiveBroadcastStream()
      .map((e) => (e as num?)?.toInt() ?? 0);

  /// Reset pickup counter (called at midnight).
  Future<void> resetCounter() async {
    await _channel.invokeMethod('resetCounter');
  }
}
