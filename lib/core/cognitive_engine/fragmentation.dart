/// Dual-device fragmentation score.
/// Dart port of @cognitrack/shared/src/fragmentation.ts
library;

import 'constants.dart';

/// Compute dual-device fragmentation score when phone switches interleave
/// with desktop work. Uses CROSS_DEVICE_MULTIPLIER = 2.2.
///
/// phoneInterrupts: count of phone pickups/switches while desktop was active
/// totalDesktopSwitches: desktop switch count for the day
///
/// Returns a 0–100 fragmentation score.
double computeFragmentation({
  required int phoneInterrupts,
  required int totalDesktopSwitches,
}) {
  if (totalDesktopSwitches == 0) return 0;
  final raw = phoneInterrupts * crossDeviceMultiplier;
  return (raw / totalDesktopSwitches * 100).clamp(0, 100);
}
