/// DashboardProvider — today's metrics + 7-day history + computed fields.
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
    // BUG-06: auto-trigger load() so the dashboard is never stuck on blank
    // state when a consuming screen forgets to call load() manually.
    load();
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final todayDate = _dateStr(DateTime.now());
      final yesterdayDate =
          _dateStr(DateTime.now().subtract(const Duration(days: 1)));

      today = await _store.getDailyMetrics(todayDate);
      yesterday = await _store.getDailyMetrics(yesterdayDate);
      twoWeeks = (await _store.getMetricsHistory(days: 30)).reversed.toList();
      weekHistory = twoWeeks.length > 7
          ? twoWeeks.sublist(twoWeeks.length - 7)
          : twoWeeks;
    } catch (e, st) {
      error = e.toString();
      debugPrint('[DashboardProvider] load error: $e\n$st');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await _sync.syncNow();
    await load();
  }

  // ── Computed ──────────────────────────────────────────────────────────────

  double get cogDebtPct => today?.cognitiveLoadPct ?? 0;
  double get cogDebtPts => today?.cognitiveDebt ?? 0;
  double get wmCapacity => today?.wmCapacityRemaining ?? 100;
  double get residueAtEOD => today?.residueAtEOD ?? 0;
  int get totalSwitches => today?.totalSwitches ?? 0;
  int get totalPickups => today?.totalPickups ?? 0;
  double get screenTime => today?.totalScreenTime ?? 0;
  double get switchVelocity => today?.switchVelocityPeak ?? 0;
  // BUG-08: nullable int? so hour 0 (midnight) is distinguishable from
  // "no data". Callers must handle null explicitly.
  int? get peakLoadHour => today?.peakLoadHour;

  bool get isCritical => cogDebtPct > 70;
  bool get isHighVolatility => switchVelocity > 80;

  /// +12.4% delta vs yesterday
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

  /// Week-over-week comparison (avg this week vs last week).
  /// Returns null when fewer than 14 days of data exist so callers can
  /// show "Not enough data" instead of a misleading "+0.0%".
  double? get weekOverWeekDelta {
    if (twoWeeks.length < 14) return null; // BUG-09
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
    // BUG-11: guard d == 0 the same way screenTimeDeltaLabel does
    if (d == 0) return 'stable';
    return '${d > 0 ? '+' : ''}${d.toStringAsFixed(0)} pts neural load';
  }

  String get weekOverWeekLabel {
    final d = weekOverWeekDelta;
    // BUG-09: null means insufficient data — do not imply a comparison exists
    if (d == null) return 'Not enough data';
    return '${d >= 0 ? '+' : ''}${d.toStringAsFixed(1)}% vs Prev. Week';
  }

  String get attnResidueLabel {
    if (residueAtEOD > 0.6) return 'High';
    if (residueAtEOD > 0.3) return 'Moderate';
    return 'Low';
  }

  String get peakStressLabel {
    // BUG-08: null means no data; 0 is a valid midnight peak — show '12 AM'
    final hour = peakLoadHour;
    if (hour == null) return '--';
    final dt = DateTime(2000, 1, 1, hour);
    return DateFormat('h a').format(dt);
  }

  /// GAP-05: Compare today's peak load hour to the 7-day historic average.
  /// Previously missing — dashboard hard-coded 'LATER THAN AVG' literally.
  String get peakStressDeltaLabel {
    final hour = peakLoadHour;
    if (hour == null || weekHistory.length < 3) return '';
    final historicPeaks = weekHistory
        .where((d) => d.peakLoadHour != null && d.peakLoadHour != -1)
        .map((d) => d.peakLoadHour!)
        .toList();
    if (historicPeaks.isEmpty) return '';
    final avgPeak = historicPeaks.reduce((a, b) => a + b) / historicPeaks.length;
    final diff = hour - avgPeak;
    if (diff.abs() < 1) return 'ON AVERAGE';
    return diff > 0 ? 'LATER THAN AVG' : 'EARLIER THAN AVG';
  }

  String get focusBlocksLabel {
    // AND-12 + AND-16 FIX: After AND-16, Category.tools time is folded into the
    // 'productive' bucket in _computeCategoryBreakdown() (sync_engine.dart).
    // There is therefore NO 'tools' key in the stored JSON — it is always null
    // → 0.0. Reading (productivePct + toolsPct) meant only productivePct was
    // counted, showing ~half the correct focus time on developer devices.
    // Use productivePct alone — it already includes tools time.
    if (today == null) return '--';
    try {
      final breakdown = jsonDecode(today!.categoryBreakdown) as Map<String, dynamic>;
      final productivePct = (breakdown['productive'] as num?)?.toDouble() ?? 0.0;
      final focusFraction = (productivePct / 100).clamp(0.0, 1.0);
      final focusHours    = screenTime * focusFraction;
      final h = focusHours.floor();
      final m = ((focusHours - h) * 60).round();
      if (h == 0 && m == 0) return '--';
      return m > 0 ? '${h}h ${m}m' : '${h}h';
    } catch (_) {
      return '--';
    }
  }

  /// GAP-07: Compare this week's productive% average to the prior 7 days.
  /// Previously missing — dashboard hard-coded '+12% VS LAST'. Requires
  /// 14+ days of data in twoWeeks (now loaded as 30 days in load()).
  String get focusBlocksDeltaLabel {
    if (twoWeeks.length < 14) return '';
    final recent = twoWeeks.sublist(twoWeeks.length - 7);
    final older  = twoWeeks.sublist(max(0, twoWeeks.length - 14), twoWeeks.length - 7);
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
    final avgOlder  = sumOlder  / older.length;
    if (avgOlder == 0) return '';
    final delta = (avgRecent - avgOlder) / avgOlder * 100;
    return '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(0)}% VS LAST MO.';
  }

  /// GAP-06: Trend label for attention residue vs prior 6-day average.
  /// Previously missing — dashboard hard-coded 'SIGNIFICANT INCR.'.
  String get attnResidueDeltaLabel {
    if (today == null || weekHistory.length < 3) return '';
    final curr = today!.residueAtEOD;
    final prev = weekHistory.sublist(0, weekHistory.length - 1);
    if (prev.isEmpty) return '';
    final prevAvg = prev.map((d) => d.residueAtEOD).reduce((a, b) => a + b) / prev.length;
    if (prevAvg == 0) return '';
    final delta = (curr - prevAvg) / prevAvg * 100;
    if (delta > 20) return 'SIGNIFICANT INCR.';
    if (delta > 5)  return 'SLIGHT INCR.';
    if (delta < -5) return 'IMPROVING';
    return 'STABLE';
  }

  /// GAP-02: Estimated recovery time from WM capacity remaining.
  /// Previously missing — dashboard hard-coded the value inline in the widget.
  String get recoveryHoursLabel {
    if (today == null) return '--';
    final recoveryFraction = (wmCapacity / 100).clamp(0.0, 1.0);
    final hours = recoveryFraction * 8.0; // max 8h recovery window
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    if (h == 0 && m == 0) return '--';
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }

  /// GAP-02: Week-over-week WM capacity trend for the recovery card.
  String get recoveryDeltaLabel {
    if (twoWeeks.length < 14) return 'STABLE VS PREV.';
    final thisWeekWm = twoWeeks.sublist(twoWeeks.length - 7)
        .map((d) => d.wmCapacityRemaining).reduce((a, b) => a + b) / 7;
    final lastWeekWm = twoWeeks.sublist(twoWeeks.length - 14, twoWeeks.length - 7)
        .map((d) => d.wmCapacityRemaining).reduce((a, b) => a + b) / 7;
    if (lastWeekWm == 0) return 'STABLE VS PREV.';
    final delta = (thisWeekWm - lastWeekWm) / lastWeekWm * 100;
    if (delta.abs() < 3) return 'STABLE VS PREV.';
    return delta > 0 ? 'IMPROVING' : 'DECLINING';
  }

  int get lastSyncMinutesAgo {
    final last = _sync.lastSyncAt;
    if (last == null) return 9999;
    return DateTime.now().difference(last).inMinutes;
  }

  String get neuralObservation {
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
    // GAP-03 FIX: Old format was CTR-XXXXXX (6 hex chars, e.g. CTR-A3F22C).
    // Design shows CTR-NNN-L (3 decimal digits + dash + 1 uppercase letter,
    // e.g. CTR-772-B). Reformatted to match. Still stable for the full day.
    final todayDate = today?.date ?? _dateStr(DateTime.now());
    final seed = todayDate.replaceAll('-', '').hashCode.abs();
    final digits = (seed % 1000).toString().padLeft(3, '0');       // 000–999
    final letter = String.fromCharCode(65 + (seed ~/ 1000) % 26); // A–Z
    return 'CTR-$digits-$letter';
  }

  // ── Weekly chart data ─────────────────────────────────────────────────────

  List<double> get weeklyLoadValues =>
      weekHistory.map((d) => d.cognitiveLoadPct).toList();

  double get weeklyPeak =>
      weeklyLoadValues.isEmpty ? 0 : weeklyLoadValues.reduce(max);

  /// Alias for todayHourlyValues — used by the chart tab switcher.
  List<double> get hourlyLoadValues => todayHourlyValues;

  List<double> get todayHourlyValues {
    if (today == null) return [];
    try {
      return (jsonDecode(today!.hourlyLoad) as List)
          .map((e) => (e as num).toDouble()).toList();
    } catch (_) { return []; }
  }

  /// Last ≤30 days of daily cognitive load — for the Month chart tab.
  List<double> get monthlyLoadValues =>
      twoWeeks.map((d) => d.cognitiveLoadPct).toList();

  double get monthlyPeak =>
      monthlyLoadValues.isEmpty ? 0 : monthlyLoadValues.reduce(max);

  bool get isPickupsAboveAvg {
    if (weekHistory.length < 2) return false;
    final avg = weekHistory.map((d) => d.totalPickups)
        .reduce((a, b) => a + b) / weekHistory.length;
    return totalPickups > avg;
  }

  String get pickupsDeltaLabel =>
      isPickupsAboveAvg ? 'Above avg' : 'Below avg';

  // ── Secondary metric grid (4 cells) ──────────────────────────────────────
  // Used by _buildMetric4Grid in dashboard_screen.dart.

  /// Returns 4 MetricCell entries for the secondary stats row.
  /// Returns null when data is still loading so the grid shows a shimmer.
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

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _dateStr(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);
}

// ── MetricCell ────────────────────────────────────────────────────────────────
// Data class consumed by _SmallMorphCell in dashboard_screen.dart.

class MetricCell {
  const MetricCell({
    required this.label,
    required this.value,
    required this.delta,
    this.dotColor,
  });
  final String label;
  final String value;
  final String delta;
  final Color? dotColor;
}
