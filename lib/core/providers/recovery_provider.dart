/// RecoveryProvider — radar data, countdown, efficiency log, debt arc, breaks.
library;

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../database/sqlite_store.dart';
import '../cognitive_engine/models.dart';

class BreakQualityEntry {
  final String time;
  final String breakType;
  final double recoveryDeltaPts;
  final double beforePct;
  final double afterPct;
  final double effectivePct;

  const BreakQualityEntry({
    required this.time,
    required this.breakType,
    required this.recoveryDeltaPts,
    required this.beforePct,
    required this.afterPct,
    required this.effectivePct,
  });
}

class RecoveryProvider extends ChangeNotifier {
  final SQLiteStore _store;

  DailyMetricsRow? today;
  List<DailyMetricsRow> last7Days = [];
  List<AppEvent> todayBreaks = [];
  bool loading = true;
  String? error;

  RecoveryProvider({required SQLiteStore store}) : _store = store;

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      today = await _store.getDailyMetrics(todayDate);
      last7Days = (await _store.getMetricsHistory(days: 7)).reversed.toList();
      todayBreaks = await _store.getBreaksForDate(todayDate);
    } catch (e, st) {
      error = e.toString();
      debugPrint('[RecoveryProvider] load error: $e\n$st');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // ── Radar pentagon values [0.0–1.0] ──────────────────────────────────────
  // Axes: Dopamine, Focus, Recovery, WM Strain, Sleep (in order)

  List<double> get radarValues {
    final load    = today?.cognitiveLoadPct ?? 0;
    final wm      = today?.wmCapacityRemaining ?? 100;
    final residue = today?.residueAtEOD ?? 0;
    final screen  = today?.totalScreenTime ?? 8;

    // GAP-01 FIX: _RadarPentagonPainter maps value[i] → label[i].
    // Labels array (recovery_screen.dart): ['FOCUS','RECOVERY','WM STRAIN','SLEEP','DOPAMINE']
    // Previous order was [dopamine, focus, recovery, wmStrain, sleep] — every
    // axis was showing the wrong metric (e.g. dopamine value on the FOCUS axis).
    // Reordered to match label indices exactly.
    final focus    = (wm / 100).clamp(0.0, 1.0);                    // index 0 → FOCUS
    final recovery = max(0.0, 1 - residue);                          // index 1 → RECOVERY
    final wmStrain = max(0.0, 1 - (wm / 100));                      // index 2 → WM STRAIN
    final sleep    = max(0.0, (1 - (screen / 16))).clamp(0.0, 1.0); // index 3 → SLEEP
    final dopamine = max(0.0, 1 - (load / 100));                    // index 4 → DOPAMINE

    return [focus, recovery, wmStrain, sleep, dopamine];
  }

  // ── Countdown to next neural reset ───────────────────────────────────────

  Duration get timeToReset {
    final now = DateTime.now();
    final peakHour = today?.peakLoadHour ?? 14;
    // Reset 8h after peak load
    var resetDt = DateTime(now.year, now.month, now.day, peakHour).add(
      const Duration(hours: 8),
    );
    if (resetDt.isBefore(now)) {
      resetDt = resetDt.add(const Duration(days: 1));
    }
    return resetDt.difference(now);
  }

  // ── Efficiency log — 7-day cogLoad values ────────────────────────────────

  List<double> get efficiencyLog7Day =>
      last7Days.map((d) => d.cognitiveLoadPct).toList();

  List<String> get efficiencyLog7DayLabels => last7Days.map((d) {
        try {
          return DateFormat('MMM d')
              .format(DateFormat('yyyy-MM-dd').parse(d.date));
        } catch (_) {
          return '';
        }
      }).toList();

  // ── Cognitive debt arc — hourly breakdown ─────────────────────────────────

  List<double> get debtArcPoints {
    if (today == null) return List.filled(24, 0);
    try {
      return (jsonDecode(today!.hourlyLoad) as List)
          .map((e) => (e as num).toDouble())
          .toList();
    } catch (_) {
      return List.filled(24, 0);
    }
  }

  double get debtArcPeak =>
      debtArcPoints.isEmpty ? 0 : debtArcPoints.reduce(max);

  int get debtArcPeakHour {
    final pts = debtArcPoints;
    if (pts.isEmpty) return today?.peakLoadHour ?? 14;
    double peak = 0;
    int idx = 0;
    for (int i = 0; i < pts.length; i++) {
      if (pts[i] > peak) {
        peak = pts[i];
        idx = i;
      }
    }
    return idx;
  }

  /// Net pts cleared today vs yesterday's closing value
  double get netDebtCleared {
    if (last7Days.length < 2) return 0;
    final todayDebt = last7Days.last.cognitiveDebt;
    final yesterday = last7Days[last7Days.length - 2].cognitiveDebt;
    return yesterday - todayDebt;
  }

  // ── Break quality report ──────────────────────────────────────────────────

  List<BreakQualityEntry> get breakQualityReport {
    if (todayBreaks.isNotEmpty) {
      return todayBreaks.asMap().entries.map((e) {
        final event = e.value;
        final dt = DateTime.fromMillisecondsSinceEpoch(event.timestamp);
        final timeStr = DateFormat('hh:mm a').format(dt);
        final before = today?.cognitiveLoadPct ?? 60;
        final after = max(0.0, before - (event.durationMs / 60000 * 2));
        return BreakQualityEntry(
          time: timeStr,
          breakType: _breakTypeLabel(e.key),
          recoveryDeltaPts: before - after,
          beforePct: before,
          afterPct: after,
          effectivePct: min(1.0, event.durationMs / 600000), // 10 min = 100%
        );
      }).toList();
    }

    // FUNC-07 FIX: The Android ForegroundService emits ACTIVITY_RESUMED /
    // ACTIVITY_PAUSED events, not eventType='break', so todayBreaks is always
    // empty on Android. Fall back to detecting recovery windows directly from
    // the hourlyLoad array: an hour where load drops below 20 after being
    // above 40 is a genuine low-load recovery window.
    if (today == null) return [];
    final hourly = today!.hourlyLoadList;
    final entries = <BreakQualityEntry>[];
    for (int i = 1; i < hourly.length - 1; i++) {
      if (hourly[i] < 20 && hourly[i - 1] > 40) {
        final timeStr = '${i.toString().padLeft(2, '0')}:00';
        final before = hourly[i - 1];
        final after = i + 1 < hourly.length ? hourly[i + 1] : hourly[i];
        final delta = (before - after).clamp(0.0, 100.0);
        entries.add(BreakQualityEntry(
          time: timeStr,
          breakType: _breakTypeLabel(entries.length),
          recoveryDeltaPts: delta,
          beforePct: before,
          afterPct: after,
          effectivePct: (delta / 100).clamp(0.0, 1.0),
        ));
      }
    }
    return entries;
  }

  String _breakTypeLabel(int i) {
    const types = [
      'Neural Breathwork',
      'Mindful Break',
      'Physical Reset',
      'Micro-Rest'
    ];
    return types[i % types.length];
  }

  // ── Cross-device load ─────────────────────────────────────────────────────

  /// GAP-10: FirestoreClient has zero read methods — pulling desktop session
  /// data onto the phone is not supported at launch. Return an honest stub
  /// so the UI row doesn't crash. Full implementation requires adding a
  /// getDesktopMetrics(date) read method to FirestoreClient.
  String get crossDeviceLoadLabel => 'Desktop sync — pending';

  // ── Tomorrow's readiness ──────────────────────────────────────────────────

  double get tomorrowReadiness =>
      (100 - (today?.cognitiveLoadPct ?? 0)).clamp(0, 100).toDouble();

  double get unclearedDebt => today?.cognitiveDebt ?? 0;

  String get readinessConclusion {
    final debt = today?.cognitiveDebt ?? 0;
    final load  = today?.cognitiveLoadPct ?? 0;

    // GAP-11 FIX: Old version returned generic tier text with no bedtime.
    // UI design shows "Sleep before 11:30 PM to reach <40% baseline tomorrow."
    // Compute a specific target bedtime: start from 23:00, subtract up to
    // 90 minutes based on cognitive debt level so heavier debt → earlier bed.
    final baseMinutes = 23 * 60; // 11:00 PM
    final extraMinutes = ((debt / 50) * 30).clamp(0, 90).round(); // 0–90 min earlier
    final targetMinutes = baseMinutes - extraMinutes;
    final tH = targetMinutes ~/ 60;
    final tM = targetMinutes % 60;
    final amPm = tH < 12 ? 'AM' : 'PM';
    final displayH = tH % 12 == 0 ? 12 : tH % 12;
    final timeStr = '$displayH:${tM.toString().padLeft(2, '0')} $amPm';

    if (load > 60) {
      return 'Sleep before $timeStr to reach <40% baseline tomorrow. '
          'High cognitive debt requires extended neural restoration.';
    }
    if (load > 30) {
      return 'Sleep before $timeStr for optimal recovery. '
          'Moderate debt accumulation detected — wind-down protocol recommended.';
    }
    return 'Neural pathways showing effective recovery. '
        'Maintain current sleep schedule for peak performance tomorrow.';
  }
}
