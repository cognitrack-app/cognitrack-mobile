/// iOS foreground sync trigger.
/// As per Architecture v6.0: iOS background sync fires on applicationDidBecomeActive
/// (AppLifecycleState.resumed). No background timers — iOS reliability is "Certain: unreliable".
library;

import 'package:flutter/widgets.dart';

/// Registers a callback that fires every time the app comes to foreground.
/// Used to trigger a sync flush when the user opens the app.
class ForegroundSync with WidgetsBindingObserver {
  final Future<void> Function()? onResume;
  final Future<void> Function()? onPause;

  ForegroundSync({this.onResume, this.onPause});

  void register() {
    WidgetsBinding.instance.addObserver(this);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResume?.call();
    }
    if (state == AppLifecycleState.paused) {
      onPause?.call();
    }
  }
}
