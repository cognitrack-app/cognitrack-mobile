/// Switch velocity multiplier.
/// Dart port of @cognitrack/shared/src/velocityMultiplier.ts
library;

import 'models.dart';

/// Linear penalty for rapid context switching.
/// <= 1 switch/min: no penalty (1.0)
/// >= 4 switches/min: hard cap at crisis mode (2.5)
/// 1–4: linear interpolation
double computeVelocityMultiplier(double switchesPerMinute) {
  if (switchesPerMinute <= 1.0) return 1.0;
  if (switchesPerMinute >= 4.0) return 2.5;
  return 1.0 + (switchesPerMinute - 1.0) * 0.5;
}

/// Compute switch velocity (switches/minute) in the 5-minute window
/// ending at the last event's timestamp.
double getSwitchVelocity(
  List<AppEvent> events, {
  int windowMs = 5 * 60 * 1000,
}) {
  if (events.isEmpty) return 0.0;
  final now = events.last.timestamp;
  final windowStart = now - windowMs;
  final recentSwitches = events
      .where(
          (e) => e.eventType == EventType.switch_ && e.timestamp >= windowStart)
      .length;
  return recentSwitches / (windowMs / 60000); // per minute
}
