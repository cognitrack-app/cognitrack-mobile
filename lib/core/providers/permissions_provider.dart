/// PermissionsProvider — Android Usage Stats permission gate.
/// On iOS: always returns hasPermission = true (no gate needed).
library;

import 'dart:io' as io;
import 'package:flutter/widgets.dart';
import '../../platform/android/usage_stats_collector.dart';

class PermissionsProvider extends ChangeNotifier with WidgetsBindingObserver {
  bool _hasPermission = false;
  bool _isChecked = false;
  bool _isListening = false;

  bool get hasPermission => _hasPermission;
  bool get isChecked => _isChecked;

  /// Call from the owning widget's initState() to start lifecycle observation.
  void startListening() {
    if (_isListening) return;
    _isListening = true;
    WidgetsBinding.instance.addObserver(this);
  }

  /// Call from the owning widget's dispose() to stop lifecycle observation.
  void stopListening() {
    if (!_isListening) return;
    _isListening = false;
    WidgetsBinding.instance.removeObserver(this);
  }

  /// Re-check permission when the user returns from Android Settings.
  /// This is the correct replacement for the 500ms timer: the timer fires
  /// while the user is still in Settings (always sees denied), whereas
  /// AppLifecycleState.resumed fires only after the user has navigated back.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      check();
    }
  }

  Future<void> check({bool skipServiceStart = false}) async {
    if (io.Platform.isIOS) {
      _hasPermission = true;
      _isChecked = true;
      notifyListeners();
      return;
    }
    final collector = UsageStatsCollector();
    _hasPermission = await collector.hasPermission();
    _isChecked = true;

    // MISS-02 FIX: main.dart calls startForegroundService() before runApp().
    // check() previously always called it again unconditionally, resulting in
    // two back-to-back service start intents on every cold launch for users
    // who already have permission. Two starts can cause duplicate event batches
    // in the first polling cycle. skipServiceStart: true lets main.dart signal
    // that the service is already running so we skip the redundant start.
    if (_hasPermission && !skipServiceStart) {
      await collector.startForegroundService();
    }
    notifyListeners();
  }

  Future<void> requestPermission() async {
    if (io.Platform.isIOS) return;
    final collector = UsageStatsCollector();
    // Opens Android Settings — user may take 5-30s to find and toggle the
    // permission. Re-check is handled by didChangeAppLifecycleState.resumed
    // instead of a 500ms timer (which always fires before the user returns).
    await collector.requestPermission();
  }
}
