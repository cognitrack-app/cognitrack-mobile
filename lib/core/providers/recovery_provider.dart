/// RecoveryProvider — radar data, countdown, efficiency log, debt arc, breaks.
/// Reads live data from SQLiteStore (written by SyncEngine every 15 min).
/// Break events derive from real AppEvents stored in SQLite.
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

// ────────────────────────────────────────────────────────────────────────────

class RecoveryProvider extends ChangeNotifier {
  final SQLiteStore _store;

  DailyMetricsRow? today;
  List<DailyMetricsRow> last7Days = [];
  List<AppEvent> todayBreaks = [];
  bool loading = true;
  String? error;

  RecoveryProvider({required SQLiteStore store}) : _store = store;

  // ── Load ─────────────────────────────────────────────────────────────────

  Future<void> load() async {
    // Only show shimmer on the very first load (no data yet).
    final firstLoad = today == null;
    if (firstLoad) {
      loading = true;
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 300));
    }
    error = null;

    try {
      final todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

      today = await _store.getDailyMetrics(todayDate);

      // getMetricsHistory returns DESC — reverse for oldest-first chart order.
      final raw = await _store.getMetricsHistory(days: 7);
      last7Days = raw.reversed.toList();

      // Load today's break/idle events from SQLite so breakQualityReport
      // is derived from real detected breaks, not hardcoded values.
      final allEvents = await _store.getEventsForDate(todayDate);
      todayBreaks = allEvents
          .where((e) =>
              e.eventType == EventType.break_ || e.eventType == EventType.idle)
          .toList();
    } catch (e, st) {
      debugPrint('[RecoveryProvider] load error: $e\n$st');
      error = e.toString();
    }

    loading = false;
    notifyListeners();
  }

  // ── Radar pentagon values [0.0–1.0] ───────────────────────────────────────

  List<double> get radarValues {
    final load = today?.cognitiveLoadPct ?? 0;
    final wm = today?.wmCapacityRemaining ?? 100;
    final residue = today?.residueAtEOD ?? 0;
    final screen = today?.totalScreenTime ?? 8;

    final focus = (wm / 100).clamp(0.0, 1.0);
    final recovery = max(0.0, 1 - residue);
    final wmStrain = max(0.0, 1 - (wm / 100));
    final sleep = max(0.0, (1 - (screen / 16))).clamp(0.0, 1.0);
    final dopamine = max(0.0, 1 - (load / 100));

    return [focus, recovery, wmStrain, sleep, dopamine];
  }

  // ── Countdown to next neural reset ───────────────────────────────────────

  Duration get timeToReset {
    final now = DateTime.now();
    final peakHour = today?.peakLoadHour ?? 15;
    var resetDt = DateTime(now.year, now.month, now.day, peakHour)
        .add(const Duration(hours: 8));
    if (resetDt.isBefore(now)) {
      resetDt = resetDt.add(const Duration(days: 1));
    }
    return resetDt.difference(now);
  }

  // ── Efficiency log — 7-day cogLoad values ──────────────────────────────

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

  // ── Cognitive debt arc — hourly breakdown ──────────────────────────────

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
    if (pts.isEmpty) return today?.peakLoadHour ?? 0;
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

  double get netDebtCleared {
    if (last7Days.length < 2) return 0;
    final todayDebt = last7Days.last.cognitiveDebt;
    final yesterdayDebt = last7Days[last7Days.length - 2].cognitiveDebt;
    return yesterdayDebt - todayDebt;
  }

  // ── Break quality report — derived from real SQLite break/idle events ────
  //
  // Each break event is a contiguous idle gap between app switches.
  // We scan todayBreaks and pair the hourly load snapshot before and
  // after each break window to compute recoveryDeltaPts and effectivePct.

  List<BreakQualityEntry> get breakQualityReport {
    if (todayBreaks.isEmpty) return [];

    final hourly = debtArcPoints;
    // hourly has 24 slots; guard against empty to avoid index errors.
    if (hourly.isEmpty || hourly.every((v) => v == 0)) return [];

    final entries = <BreakQualityEntry>[];

    for (final event in todayBreaks) {
      // Duration must be at least 5 minutes to qualify as a meaningful break.
      if (event.durationMs < 5 * 60 * 1000) continue;

      final breakDt = DateTime.fromMillisecondsSinceEpoch(event.timestamp);
      final hourBefore = (breakDt.hour - 1).clamp(0, 23);
      final hourAfter = breakDt.hour.clamp(0, 23);

      final before = hourly[hourBefore];
      final after = hourly[hourAfter];
      final delta = before - after; // positive = load dropped = good recovery
      final eff = before > 0 ? (delta / before).clamp(0.0, 1.0) : 0.0;

      final timeLabel = DateFormat('HH:mm').format(breakDt);
      final breakType = event.durationMs >= 20 * 60 * 1000
          ? 'Extended Break'
          : event.eventType == EventType.idle
              ? 'Idle Window'
              : 'Neural Breathwork';

      entries.add(BreakQualityEntry(
        time: timeLabel,
        breakType: breakType,
        recoveryDeltaPts: delta,
        beforePct: before,
        afterPct: after,
        effectivePct: eff,
      ));

      // Cap at 5 entries to keep the UI readable.
      if (entries.length >= 5) break;
    }

    return entries;
  }

  int get breaksAccepted => breakQualityReport.length;

  // Cross-device stats — derived from real today metrics rather than hardcoded.
  // crossDeviceEvents: total switch events (phone + desktop both write switches).
  // crossDevicePts: approximate cognitive load contribution from switches.
  int get crossDeviceEvents => today?.totalSwitches ?? 0;
  int get crossDevicePts => ((today?.cognitiveDebt ?? 0) * 0.4).round();
  String get crossDeviceLoadLabel {
    final load = today?.cognitiveLoadPct ?? 0;
    if (load == 0) return 'No data yet';
    return 'Desktop sync — ${load.toStringAsFixed(0)}% load';
  }

  // ── Tomorrow's readiness ───────────────────────────────────────────────

  double get tomorrowReadiness =>
      (100 - (today?.cognitiveLoadPct ?? 0)).clamp(0, 100).toDouble();

  bool get hasNewAlerts =>
      (today?.cognitiveLoadPct ?? 0) > 60 || unclearedDebt > 30;

  double get unclearedDebt => today?.cognitiveDebt ?? 0;

  String get readinessConclusion {
    final debt = today?.cognitiveDebt ?? 0;
    final load = today?.cognitiveLoadPct ?? 0;

    if (today == null) {
      return 'No data recorded yet. CogniTrack will generate '
          'a recovery plan once it has tracked your activity today.';
    }

    final baseMinutes = 23 * 60;
    final extraMinutes = ((debt / 50) * 30).clamp(0, 90).round();
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
