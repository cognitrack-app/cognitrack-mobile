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
    final load = today?.cognitiveLoadPct ?? 0;
    final wm = today?.wmCapacityRemaining ?? 100;
    final residue = today?.residueAtEOD ?? 0;
    final screen = today?.totalScreenTime ?? 8;

    final dopamine = max(0.0, 1 - (load / 100)); // inverse of load
    final focus = (wm / 100).clamp(0.0, 1.0);
    final recovery = max(0.0, 1 - residue);
    final wmStrain = max(0.0, 1 - (wm / 100)); // inverted for radar
    final sleep = max(0.0, (1 - (screen / 16))).clamp(0.0, 1.0); // approx

    return [dopamine, focus, recovery, wmStrain, sleep];
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
    if (todayBreaks.isEmpty) {
      // Return empty list instead of fake data
      return [];
    }
    return todayBreaks.asMap().entries.map((e) {
      final event = e.value;
      final dt = DateTime.fromMillisecondsSinceEpoch(event.timestamp);
      final timeStr = DateFormat('hh:mm a').format(dt);
      final before = today?.cognitiveLoadPct ?? 60;
      final after = max(0.0, before - (event.durationMs / 60000 * 2));
      return BreakQualityEntry(
        time: timeStr,
        breakType: _breakTypeLabel(e.key),
        recoveryDeltaPts: -(before - after),
        beforePct: before,
        afterPct: after,
        effectivePct: min(1.0, event.durationMs / 600000), // 10min = 100%
      );
    }).toList();
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

  // ── Tomorrow's readiness ──────────────────────────────────────────────────

  double get tomorrowReadiness =>
      (100 - (today?.cognitiveLoadPct ?? 0)).clamp(0, 100).toDouble();

  double get unclearedDebt => today?.cognitiveDebt ?? 0;

  String get readinessConclusion {
    final r = tomorrowReadiness;
    if (r > 70) {
      return 'System optimized for high-performance tomorrow. '
          'Neural pathways show effective recovery trajectory.';
    }
    if (r > 40) {
      return 'Moderate recovery expected. Consider extending '
          'wind-down protocols for improved baseline restoration.';
    }
    return 'High cognitive debt detected. Neural restoration protocol '
        'strongly recommended before tomorrow\'s peak workload.';
  }
}
