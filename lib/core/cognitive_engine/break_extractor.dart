/// Break event extraction from a day's idle markers.
/// Dart port of cognitrack-desktop/src/electron/main/breakExtractor.ts
library;

import 'models.dart';

/// Minimum continuous idle duration to count as a trackable break (5 min).
const int _minBreakMs = 5 * 60 * 1000;

/// Extracts [BreakEvent] list from a sorted day's [AppEvent] array.
///
/// Algorithm:
///  - An [EventType.idle] event marks the START of a break.
///  - The break ends when the next [EventType.switch_] event arrives.
///  - Breaks shorter than 5 minutes are dropped (micro-pauses, not recovery).
///  - [debtBefore] / [debtAfter] come from the hourly debt array produced by
///    [calculateCognitiveDebt], using the hour bucket of start/end.
///  - Activity type is classified by duration:
///      IDLE       → 5–19 min  (unintentional short idle)
///      STRUCTURED → 20–479 min (deliberate break or lunch)
///      SLEEP      → 480+ min  (overnight / nap ≥ 8 h)
///
/// CRITICAL-1 FIX: This function enables mobile to write break_events into
/// PhoneSyncPayload so the Cloud Function's recovery radar and verified break
/// minutes include phone breaks (not just desktop breaks).
List<BreakEvent> extractBreakEvents(
  List<AppEvent> events,
  List<double> hourlyDebtPct,
) {
  final breaks = <BreakEvent>[];

  for (int i = 0; i < events.length; i++) {
    final e = events[i];
    if (e.eventType != EventType.idle) continue;

    // Find the first switch event after this idle marker.
    AppEvent? nextSwitch;
    for (int j = i + 1; j < events.length; j++) {
      if (events[j].eventType == EventType.switch_) {
        nextSwitch = events[j];
        break;
      }
    }

    // If no subsequent switch (user went offline for the evening),
    // fall back to current time — same logic as desktop breakExtractor.ts.
    final endTs =
        nextSwitch?.timestamp ?? DateTime.now().millisecondsSinceEpoch;
    final durationMs = endTs - e.timestamp;

    // Drop micro-pauses (< 5 min).
    if (durationMs < _minBreakMs) continue;

    final startHour = DateTime.fromMillisecondsSinceEpoch(e.timestamp).hour;
    final endHour = DateTime.fromMillisecondsSinceEpoch(endTs).hour;

    final debtBefore =
        startHour < hourlyDebtPct.length ? hourlyDebtPct[startHour] : 0.0;
    final debtAfter =
        endHour < hourlyDebtPct.length ? hourlyDebtPct[endHour] : 0.0;
    final ptsRecovered = debtBefore > debtAfter ? debtBefore - debtAfter : 0.0;

    final durationMin = (durationMs / 60000).round();

    final activityType = durationMin >= 480
        ? 'SLEEP'
        : durationMin >= 20
            ? 'STRUCTURED'
            : 'IDLE';

    final efficiencyPct = debtBefore > 0
        ? ((ptsRecovered / debtBefore) * 100).clamp(0, 100).round()
        : 0;

    breaks.add(BreakEvent(
      startTime: DateTime.fromMillisecondsSinceEpoch(e.timestamp)
          .toUtc()
          .toIso8601String(),
      endTime:
          DateTime.fromMillisecondsSinceEpoch(endTs).toUtc().toIso8601String(),
      activityType: activityType,
      durationMinutes: durationMin,
      debtBefore: debtBefore,
      debtAfter: debtAfter,
      ptsRecovered: (ptsRecovered * 10).roundToDouble() / 10,
      efficiencyPct: efficiencyPct,
    ));
  }

  return breaks;
}
