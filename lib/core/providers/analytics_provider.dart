/// AnalyticsProvider — switch velocity bars, heatmap grid, brain load metrics.
library;

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../database/sqlite_store.dart';

class AnalyticsProvider extends ChangeNotifier {
  final SQLiteStore _store;

  List<DailyMetricsRow> last7Days = [];
  bool loading = true;
  String? error;

  AnalyticsProvider({required SQLiteStore store}) : _store = store;

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      last7Days = (await _store.getMetricsHistory(days: 7)).reversed.toList();
    } catch (e, st) {
      error = e.toString();
      debugPrint('[AnalyticsProvider] load error: $e\n$st');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // ── Today's hourly bars (24 values) ──────────────────────────────────────

  DailyMetricsRow? get _today => last7Days.isNotEmpty ? last7Days.last : null;

  List<double> get todayHourlyBars {
    if (_today == null) return List.filled(24, 0);
    try {
      return (jsonDecode(_today!.hourlyLoad) as List)
          .map((e) => (e as num).toDouble())
          .toList();
    } catch (_) {
      return List.filled(24, 0);
    }
  }

  /// Count of hours exceeding the breach threshold (80%)
  int get breachCount => todayHourlyBars.where((v) => v > 80).length;

  // ── Temporal heatmap — 7 × 24 matrix ─────────────────────────────────────

  List<List<double>> get heatmapGrid {
    return last7Days.map((row) {
      try {
        return (jsonDecode(row.hourlyLoad) as List)
            .map((e) => (e as num).toDouble())
            .toList();
      } catch (_) {
        return List.filled(24, 0.0);
      }
    }).toList();
  }

  double get heatmapPeak {
    if (heatmapGrid.isEmpty) return 0;
    double peak = 0;
    for (final row in heatmapGrid) {
      for (final v in row) {
        if (v > peak) peak = v;
      }
    }
    return peak;
  }

  /// (row, col) of the peak cell in the 7×24 grid
  (int, int) get heatmapPeakCell {
    int pr = 0, pc = 0;
    double peak = 0;
    for (int r = 0; r < heatmapGrid.length; r++) {
      for (int c = 0; c < heatmapGrid[r].length; c++) {
        if (heatmapGrid[r][c] > peak) {
          peak = heatmapGrid[r][c];
          pr = r;
          pc = c;
        }
      }
    }
    return (pr, pc);
  }

  // ── Brain Load ────────────────────────────────────────────────────────────

  double get wmStrain => 100 - (_today?.wmCapacityRemaining ?? 100);

  String get attentionDecayLabel {
    final r = _today?.residueAtEOD ?? 0;
    if (r > 0.6) return 'High';
    if (r > 0.3) return 'Moderate';
    return 'Low';
  }

  double get neuralNoise => ((_today?.switchVelocityPeak ?? 0) * 0.155).clamp(0.0, 100.0);

  // ── Recovery coefficient ──────────────────────────────────────────────────
  /// Returns map with periods: morning/noon/afternoon/evening → {pre, post} pairs

  Map<String, Map<String, double>> get recoveryCoeff {
    if (_today == null) {
      return {
        for (final k in ['Morning', 'Noon', 'Afternoon', 'Evening'])
          k: {'pre': 0, 'post': 0, 'delta': 0},
      };
    }
    final bars = todayHourlyBars;
    double avgLoad(int from, int to) {
      final slice = bars.sublist(from, min(to, bars.length));
      return slice.isEmpty ? 0 : slice.reduce((a, b) => a + b) / slice.length;
    }
    double eff(double load) => ((100 - load) / 100 * 100).clamp(0.0, 100.0);
    double postEff(double pre) => (pre * 1.30).clamp(0.0, 100.0);
    double delta(double pre, double pst) =>
        pre == 0 ? 0 : ((pst - pre) / pre * 100);

    Map<String, double> period(int from, int to) {
      final pre = eff(avgLoad(from, to));
      final pst = postEff(pre);
      return {'pre': pre, 'post': pst, 'delta': delta(pre, pst)};
    }

    return {
      'Morning':   period(6, 12),
      'Noon':      period(12, 14),
      'Afternoon': period(14, 18),
      'Evening':   period(18, 22),
    };
  }

  // ── Day labels for heatmap ────────────────────────────────────────────────

  List<String> get heatmapDayLabels {
    if (last7Days.isEmpty) return List.generate(7, (_) => '');
    return last7Days.map((row) {
      try {
        final dt = DateFormat('yyyy-MM-dd').parse(row.date);
        return DateFormat('EEE').format(dt);
      } catch (_) {
        return '';
      }
    }).toList();
  }
}
