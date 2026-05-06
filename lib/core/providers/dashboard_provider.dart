/// DashboardProvider — today's metrics + 7-day history + computed fields.
/// Reads live data from SQLiteStore (written by SyncEngine every 15 min).
library;

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:intl/intl.dart';
import '../database/sqlite_store.dart';
import '../sync/sync_engine.dart';

class DashboardProvider extends ChangeNotifier {
  final SQLiteStore _store;
  final SyncEngine _sync;

  DailyMetricsRow? today;
  DailyMetricsRow? yesterday;
  List<DailyMetricsRow> weekHistory = [];
  List<DailyMetricsRow> twoWeeks = [];
  bool loading = true;
  String? error;

  DashboardProvider({required SQLiteStore store, required SyncEngine sync})
      : _store = store,
        _sync = sync {
    load();
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> load() async {
    // Only show shimmer on the very first load (no data yet).
    // Subsequent refresh() calls must NOT flash loading=true or the screen
    // flickers back to shimmer while perfectly good data is already visible.
    final firstLoad = today == null && weekHistory.isEmpty;
    if (firstLoad) {
      loading = true;
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 300));
    }
    error = null;

    try {
      final todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final yesterdayDate = DateFormat('yyyy-MM-dd')
          .format(DateTime.now().subtract(const Duration(days: 1)));

      today = await _store.getDailyMetrics(todayDate);
      yesterday = await _store.getDailyMetrics(yesterdayDate);

      // getLast14Days returns DESC order — reverse to get oldest-first for
      // chart rendering (index 0 = 13 days ago, index 13 = today).
      final raw14 = await _store.getMetricsHistory(days: 14);
      twoWeeks = raw14.reversed.toList();
      weekHistory = twoWeeks.length > 7
          ? twoWeeks.sublist(twoWeeks.length - 7)
          : twoWeeks;
    } catch (e, st) {
      debugPrint('[DashboardProvider] load error: $e\n$st');
      error = e.toString();
    }

    loading = false;
    notifyListeners();
  }

  Future<void> refresh() async => load();

  // ── Computed ──────────────────────────────────────────────────────────────

  double get cogDebtPct => today?.cognitiveLoadPct ?? 0;
  double get cogDebtPts => today?.cognitiveDebt ?? 0;
  double get wmCapacity => today?.wmCapacityRemaining ?? 100;
  double get residueAtEOD => today?.residueAtEOD ?? 0;
  int get totalSwitches => today?.totalSwitches ?? 0;
  int get totalPickups => today?.totalPickups ?? 0;
  double get screenTime => today?.totalScreenTime ?? 0;
  double get switchVelocity => today?.switchVelocityPeak ?? 0;
  int? get peakLoadHour => today?.peakLoadHour;

  bool get isCritical => cogDebtPct > 70;
  bool get isHighVolatility => switchVelocity > 80;

  /// Real minutes since last successful sync.
  int get lastSyncMinutesAgo {
    final last = _sync.lastSyncAt;
    if (last == null) return -1; // -1 = never synced
    return DateTime.now().difference(last).inMinutes;
  }

  double get screenTimeDelta {
    final t = today?.totalScreenTime ?? 0;
    final y = yesterday?.totalScreenTime ?? 0;
    if (y == 0) return 0;
    return (t - y) / y * 100;
  }

  double get cogDebtDelta {
    final t = today?.cognitiveDebt ?? 0;
    final y = yesterday?.cognitiveDebt ?? 0;
    if (y == 0) return 0;
    return (t - y) / y * 100;
  }

  double? get weekOverWeekDelta {
    if (twoWeeks.length < 14) return null;
    final thisWeek = twoWeeks.sublist(twoWeeks.length - 7);
    final lastWeek = twoWeeks.sublist(0, 7);
    final avgThis =
        thisWeek.map((d) => d.cognitiveLoadPct).reduce((a, b) => a + b) / 7;
    final avgLast =
        lastWeek.map((d) => d.cognitiveLoadPct).reduce((a, b) => a + b) / 7;
    if (avgLast == 0) return null;
    return (avgThis - avgLast) / avgLast * 100;
  }

  String get screenTimeDeltaLabel {
    final d = screenTimeDelta;
    if (d == 0) return 'stable';
    return '${d > 0 ? '+' : ''}${d.toStringAsFixed(1)}%';
  }

  String get cogDebtDeltaLabel {
    final d = cogDebtDelta;
    if (d == 0) return 'stable';
    return '${d > 0 ? '+' : ''}${d.toStringAsFixed(0)} pts neural load';
  }

  String get weekOverWeekLabel {
    final d = weekOverWeekDelta;
    if (d == null) return 'Not enough data';
    return '${d >= 0 ? '+' : ''}${d.toStringAsFixed(1)}% vs Prev. Week';
  }

  String get attnResidueLabel {
    if (residueAtEOD > 0.6) return 'High';
    if (residueAtEOD > 0.3) return 'Moderate';
    return 'Low';
  }

  String get peakStressLabel {
    final hour = peakLoadHour;
    if (hour == null) return '--';
    final dt = DateTime(2000, 1, 1, hour);
    return DateFormat('h a').format(dt);
  }

  String get peakStressDeltaLabel {
    final hour = peakLoadHour;
    if (hour == null || weekHistory.length < 3) return '';
    final historicPeaks = weekHistory
        .where((d) => d.peakLoadHour != -1)
        .map((d) => d.peakLoadHour)
        .toList();
    if (historicPeaks.isEmpty) return '';
    final avgPeak =
        historicPeaks.reduce((a, b) => a + b) / historicPeaks.length;
    final diff = hour - avgPeak;
    if (diff.abs() < 1) return 'ON AVERAGE';
    return diff > 0 ? 'LATER THAN AVG' : 'EARLIER THAN AVG';
  }

  String get focusBlocksLabel {
    if (today == null) return '--';
    try {
      final breakdown =
          jsonDecode(today!.categoryBreakdown) as Map<String, dynamic>;
      final productivePct =
          (breakdown['productive'] as num?)?.toDouble() ?? 0.0;
      final focusFraction = (productivePct / 100).clamp(0.0, 1.0);
      final focusHours = screenTime * focusFraction;
      final h = focusHours.floor();
      final m = ((focusHours - h) * 60).round();
      if (h == 0 && m == 0) return '--';
      return m > 0 ? '${h}h ${m}m' : '${h}h';
    } catch (_) {
      return '--';
    }
  }

  String get focusBlocksDeltaLabel {
    if (twoWeeks.length < 14) return '';
    final recent = twoWeeks.sublist(twoWeeks.length - 7);
    final older =
        twoWeeks.sublist(max(0, twoWeeks.length - 14), twoWeeks.length - 7);
    if (older.isEmpty) return '';
    double sumRecent = 0, sumOlder = 0;
    for (final d in recent) {
      try {
        final bd = jsonDecode(d.categoryBreakdown) as Map<String, dynamic>;
        sumRecent += (bd['productive'] as num?)?.toDouble() ?? 0;
      } catch (_) {}
    }
    for (final d in older) {
      try {
        final bd = jsonDecode(d.categoryBreakdown) as Map<String, dynamic>;
        sumOlder += (bd['productive'] as num?)?.toDouble() ?? 0;
      } catch (_) {}
    }
    final avgRecent = sumRecent / recent.length;
    final avgOlder = sumOlder / older.length;
    if (avgOlder == 0) return '';
    final delta = (avgRecent - avgOlder) / avgOlder * 100;
    return '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(0)}% VS LAST MO.';
  }

  String get attnResidueDeltaLabel {
    if (today == null || weekHistory.length < 3) return '';
    final curr = today!.residueAtEOD;
    final prev = weekHistory.sublist(0, weekHistory.length - 1);
    if (prev.isEmpty) return '';
    final prevAvg =
        prev.map((d) => d.residueAtEOD).reduce((a, b) => a + b) / prev.length;
    if (prevAvg == 0) return '';
    final delta = (curr - prevAvg) / prevAvg * 100;
    if (delta > 20) return 'SIGNIFICANT INCR.';
    if (delta > 5) return 'SLIGHT INCR.';
    if (delta < -5) return 'IMPROVING';
    return 'STABLE';
  }

  String get recoveryHoursLabel {
    if (today == null) return '--';
    final recoveryFraction = (wmCapacity / 100).clamp(0.0, 1.0);
    final hours = recoveryFraction * 8.0;
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    if (h == 0 && m == 0) return '--';
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }

  String get recoveryDeltaLabel {
    if (twoWeeks.length < 14) return 'STABLE VS PREV.';
    final thisWeekWm = twoWeeks
            .sublist(twoWeeks.length - 7)
            .map((d) => d.wmCapacityRemaining)
            .reduce((a, b) => a + b) /
        7;
    final lastWeekWm = twoWeeks
            .sublist(twoWeeks.length - 14, twoWeeks.length - 7)
            .map((d) => d.wmCapacityRemaining)
            .reduce((a, b) => a + b) /
        7;
    if (lastWeekWm == 0) return 'STABLE VS PREV.';
    final delta = (thisWeekWm - lastWeekWm) / lastWeekWm * 100;
    if (delta.abs() < 3) return 'STABLE VS PREV.';
    return delta > 0 ? 'IMPROVING' : 'DECLINING';
  }

  String get neuralObservation {
    if (today == null) {
      return 'No data recorded yet. Start using your device — '
          'CogniTrack will begin tracking cognitive load automatically.';
    }
    if (residueAtEOD > 0.6) {
      return 'Weekly accumulation of Attention_Residue_Level is significantly '
          'higher than baseline (p < 0.05). Immediate neural_down-regulation '
          'protocol recommended for weekend recovery cycles.';
    }
    if (isCritical) {
      return 'Cognitive load exceeds sustainable threshold. Switch velocity has '
          'surpassed baseline. Consider structured break cycles to restore '
          'prefrontal cortex capacity.';
    }
    return 'Cognitive load within normal parameters. Maintain current focus '
        'cadence and scheduled breaks for optimal neural performance.';
  }

  String get neuralObservationRefId {
    final todayDate =
        today?.date ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    final seed = todayDate.replaceAll('-', '').hashCode.abs();
    final digits = (seed % 1000).toString().padLeft(3, '0');
    final letter = String.fromCharCode(65 + (seed ~/ 1000) % 26);
    return 'CTR-$digits-$letter';
  }

  // ── Weekly chart data ─────────────────────────────────────────────────────

  List<double> get weeklyLoadValues =>
      weekHistory.map((d) => d.cognitiveLoadPct).toList();

  double get weeklyPeak =>
      weeklyLoadValues.isEmpty ? 0 : weeklyLoadValues.reduce(max);

  List<double> get hourlyLoadValues => todayHourlyValues;

  List<double> get todayHourlyValues {
    if (today == null) return [];
    try {
      return (jsonDecode(today!.hourlyLoad) as List)
          .map((e) => (e as num).toDouble())
          .toList();
    } catch (_) {
      return [];
    }
  }

  List<double> get monthlyLoadValues =>
      twoWeeks.map((d) => d.cognitiveLoadPct).toList();

  double get monthlyPeak =>
      monthlyLoadValues.isEmpty ? 0 : monthlyLoadValues.reduce(max);

  bool get isPickupsAboveAvg {
    if (weekHistory.length < 2) return false;
    final avg = weekHistory.map((d) => d.totalPickups).reduce((a, b) => a + b) /
        weekHistory.length;
    return totalPickups > avg;
  }

  String get pickupsDeltaLabel => isPickupsAboveAvg ? 'Above avg' : 'Below avg';

  // ── Secondary metric grid (4 cells) ──────────────────────────────────────

  List<MetricCell>? get metric4 {
    if (loading) return null;
    return [
      MetricCell(
        label: 'ATTN. RESIDUE',
        value: '${(residueAtEOD * 100).toStringAsFixed(0)}%',
        delta: attnResidueLabel,
        dotColor: residueAtEOD > 0.6
            ? const Color(0xFFFF4444)
            : residueAtEOD > 0.3
                ? const Color(0xFFFFAA00)
                : const Color(0xFF44FF88),
      ),
      MetricCell(
        label: 'WM CAPACITY',
        value: '${wmCapacity.toStringAsFixed(0)}%',
        delta: recoveryDeltaLabel,
        dotColor: wmCapacity < 40
            ? const Color(0xFFFF4444)
            : wmCapacity < 70
                ? const Color(0xFFFFAA00)
                : const Color(0xFF44FF88),
      ),
      MetricCell(
        label: 'FOCUS BLOCKS',
        value: focusBlocksLabel,
        delta: focusBlocksDeltaLabel,
        dotColor: null,
      ),
      MetricCell(
        label: 'PEAK STRESS',
        value: peakStressLabel,
        delta: peakStressDeltaLabel,
        dotColor: null,
      ),
    ];
  }
}

// ── MetricCell ────────────────────────────────────────────────────────────────

class MetricCell {
  final String label;
  final String value;
  final String delta;
  final Color? dotColor;

  const MetricCell({
    required this.label,
    required this.value,
    required this.delta,
    required this.dotColor,
  });
}
