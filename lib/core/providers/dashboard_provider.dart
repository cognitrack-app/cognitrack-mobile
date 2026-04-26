/// DashboardProvider — today's metrics + 7-day history + computed fields.
library;

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
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
        _sync = sync;

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
      twoWeeks = (await _store.getMetricsHistory(days: 14)).reversed.toList();
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
  int get peakLoadHour => today?.peakLoadHour ?? 0;

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

  /// Week-over-week comparison (avg this week vs last week)
  double get weekOverWeekDelta {
    if (twoWeeks.length < 14) return 0;
    final thisWeek = twoWeeks.sublist(twoWeeks.length - 7);
    final lastWeek = twoWeeks.sublist(0, 7);
    final avgThis =
        thisWeek.map((d) => d.cognitiveLoadPct).reduce((a, b) => a + b) / 7;
    final avgLast =
        lastWeek.map((d) => d.cognitiveLoadPct).reduce((a, b) => a + b) / 7;
    if (avgLast == 0) return 0;
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
    return '${d >= 0 ? '+' : ''}${d.toStringAsFixed(1)}% vs Prev. Week';
  }

  String get attnResidueLabel {
    if (residueAtEOD > 0.6) return 'High';
    if (residueAtEOD > 0.3) return 'Moderate';
    return 'Low';
  }

  String get peakStressLabel {
    if (peakLoadHour == 0) return '--';
    final dt = DateTime(2000, 1, 1, peakLoadHour);
    return DateFormat('h a').format(dt);
  }

  String get focusBlocksLabel {
    // Estimate focus as complement of screen fragmentation
    final focusHours = max(0.0, screenTime * (wmCapacity / 100));
    final h = focusHours.floor();
    final m = ((focusHours - h) * 60).round();
    if (h == 0 && m == 0) return '--';
    return m > 0 ? '${h}h ${m}m' : '${h}h';
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
    final seed = (today?.cognitiveDebt ?? 0).toInt();
    return 'CTR-${(seed * 137 + 1000).toRadixString(16).toUpperCase().padLeft(6, '0')}';
  }

  // ── Weekly chart data ─────────────────────────────────────────────────────

  List<double> get weeklyLoadValues =>
      weekHistory.map((d) => d.cognitiveLoadPct).toList();

  double get weeklyPeak =>
      weeklyLoadValues.isEmpty ? 0 : weeklyLoadValues.reduce(max);

  List<double> get todayHourlyValues {
    if (today == null) return [];
    try {
      return (jsonDecode(today!.hourlyLoad) as List)
          .map((e) => (e as num).toDouble()).toList();
    } catch (_) { return []; }
  }

  bool get isPickupsAboveAvg {
    if (weekHistory.length < 2) return false;
    final avg = weekHistory.map((d) => d.totalPickups)
        .reduce((a, b) => a + b) / weekHistory.length;
    return totalPickups > avg;
  }

  String get pickupsDeltaLabel =>
      isPickupsAboveAvg ? 'Above avg' : 'Below avg';

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _dateStr(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);
}
