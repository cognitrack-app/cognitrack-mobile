/// Main cognitive state machine — calculates cognitive debt from a day's events.
/// Dart port of @cognitrack/shared/src/cognitiveEngine.ts
library;

import 'models.dart';
import 'constants.dart';
import 'residue_decay.dart';
import 'velocity_multiplier.dart';

// ─── Working Memory helper ───────────────────────────────────────────────────

double updateWorkingMemory(
  double currentWm,
  double switchCost, {
  bool isBreak = false,
  bool isSustainedFocus = false,
}) {
  double wm = currentWm;
  if (isBreak) wm += wmBreakGain;
  if (isSustainedFocus) wm += wmFocusGain;
  if (switchCost > 0) wm -= switchCost * wmSwitchCost;
  return wm.clamp(wmFloor, wmInitial).roundToDouble();
}

// ─── Focus Depth helper ──────────────────────────────────────────────────────

double updateFocusDepth(
  double currentDepth,
  int msSinceLastSwitch,
  Category category,
) {
  if (category != Category.productive && category != Category.tools) return 0;
  if (msSinceLastSwitch < focusBuildThresholdMs) return currentDepth;
  return (currentDepth + focusDepthGain).clamp(0, focusDepthMax);
}

// ─── Local hour helper ───────────────────────────────────────────────────────

int _getLocalHour(int timestampMs) {
  return DateTime.fromMillisecondsSinceEpoch(timestampMs).hour;
}

// ─── Main Cognitive Engine ───────────────────────────────────────────────────

/// Run the full cognitive state machine over a day's worth of AppEvents.
///
/// Events MUST be for a single day and single device.
/// Returns a CognitiveReport suitable for Firestore sync.
CognitiveReport calculateCognitiveDebt(List<AppEvent> events) {
  if (events.isEmpty) {
    return CognitiveReport(
      cognitiveDebt: 0,
      cognitiveLoadPct: 0,
      wmCapacityRemaining: wmInitial,
      residueAtEOD: 0,
      hourlyDebt: List.filled(24, 0),
      peakLoadHour: 0,
    );
  }

  // Sort ascending by timestamp (defensive; callers should pre-sort)
  final sorted = [...events]..sort((a, b) => a.timestamp - b.timestamp);

  final startTs = sorted.first.timestamp;

  final state = CognitiveState(
    wmCapacity: wmInitial,
    residue: 0,
    focusDepth: 0,
    lastSwitchTs: startTs,
    lastResiduDecayTs: startTs,
  );

  Category? lastCategory;
  double totalDebt = 0;

  // Raw debt accumulated per hour (index = 0–23)
  final hourlyRaw = List<double>.filled(24, 0);

  // Switch velocity window: keep last 5-min switch timestamps
  final recentSwitchTs = <int>[];

  for (final event in sorted) {
    final hour = _getLocalHour(event.timestamp);

    if (event.eventType == EventType.switch_) {
      final timeSinceLast = (event.timestamp - state.lastSwitchTs).toDouble();

      // NOTE: Do NOT pre-decay state.residue here.
      // applySwitch() (Step 5) calls decayResidue() internally.
      // A pre-decay here would decay residue twice per event, halving
      // the effective TAU from 23 min to ~11.5 min (Leroy 2009 violation).

      // 2. Context distance (switch cost)
      final switchCost = lastCategory != null
          ? (contextDistance[lastCategory]?[event.category] ?? 1.0)
          : 1.0;

      // 3. Velocity multiplier (count switches in last 5 min)
      final fiveMinAgo = event.timestamp - 5 * 60000;
      recentSwitchTs.removeWhere((ts) => ts < fiveMinAgo);
      recentSwitchTs.add(event.timestamp);
      final switchesPerMin = recentSwitchTs.length / 5.0;
      final velocityMult = computeVelocityMultiplier(switchesPerMin);

      // 4. Adjusted switch cost
      final adjustedCost = switchCost * velocityMult;

      // 5. Decay old residue and stack new residue — single decay pass.
      //    applySwitch() applies e^(-timeSinceLast/TAU_MS) then adds switchCost.
      state.residue = applySwitch(state.residue, timeSinceLast, switchCost);

      // 6. Deplete working memory
      state.wmCapacity = updateWorkingMemory(
        state.wmCapacity,
        adjustedCost,
      );

      // 7. Reset focus depth on any switch
      state.focusDepth = 0;

      // 8. Compute debt contribution: cost amplified by residue
      final debtContribution = adjustedCost * (1 + state.residue);
      totalDebt += debtContribution;
      hourlyRaw[hour] += debtContribution;

      // 9. Update state
      state.lastSwitchTs = event.timestamp;
      state.lastResiduDecayTs = event.timestamp;
      lastCategory = event.category;
    } else if (event.eventType == EventType.break_ ||
        event.eventType == EventType.idle) {
      // Reward verified break
      state.wmCapacity = updateWorkingMemory(
        state.wmCapacity,
        0,
        isBreak: true,
      );
      state.focusDepth = 0;
      lastCategory = null;
      // Reset velocity window after a real break
      recentSwitchTs.clear();
    } else {
      // eventType == pickup or uninterrupted active time
      // Check for sustained focus reward
      final msSinceLast = event.timestamp - state.lastSwitchTs;
      if (msSinceLast >= focusBuildThresholdMs && lastCategory != null) {
        state.focusDepth = updateFocusDepth(
          state.focusDepth,
          msSinceLast,
          lastCategory,
        );
        if (state.focusDepth > 0) {
          state.wmCapacity = updateWorkingMemory(
            state.wmCapacity,
            0,
            isSustainedFocus: true,
          );
        }
      }
    }
  }

  // ─── Normalise to 0-100 per hour ─────────────────────────────────────────
  final hourlyDebt = hourlyRaw
      .map((raw) =>
          ((raw / hourlyDebtThreshold) * 100).clamp(0, 100).roundToDouble())
      .toList();

  // Peak hour = hour with highest normalised load
  int peakLoadHour = 0;
  for (int i = 1; i < 24; i++) {
    if (hourlyDebt[i] > hourlyDebt[peakLoadHour]) peakLoadHour = i;
  }

  final cognitiveLoadPct =
      ((totalDebt / dailyDebtThreshold) * 100).clamp(0, 100).roundToDouble();

  return CognitiveReport(
    cognitiveDebt: (totalDebt * 10).roundToDouble() / 10,
    cognitiveLoadPct: cognitiveLoadPct,
    wmCapacityRemaining: state.wmCapacity,
    residueAtEOD: (state.residue * 1000).roundToDouble() / 1000,
    hourlyDebt: hourlyDebt,
    peakLoadHour: peakLoadHour,
  );
}
