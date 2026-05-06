/// MockDataSeeder — injects 14 days of realistic, fully correlated mock data
/// directly into SQLite so every UI metric renders correctly for demo.
///
/// USAGE (debug only):
///   await MockDataSeeder(store: store).seed();
///
/// HOW TO TRIGGER:
///   Long-press the "Daily Brain Load" title text on the Dashboard screen.
///   Only active in kDebugMode — zero footprint in release builds.
///
/// DATA DESIGN:
///   Week 1 (Apr 22–27): Rising load through a study week, weekend recovery.
///   Week 2 (Apr 28–May 4): Load climbs again (exam season), weekend dip.
///   Today  (May 05):  74% load, peak at 3 PM, noon recovery dip — all UI
///                     computed fields fire with meaningful non-trivial values.
///
/// CORRELATED INVARIANTS (every metric is derived from the same root values):
///   • wmStrain         = 100 - wmCapacityRemaining
///   • radarFocus       = wmCapacityRemaining / 100
///   • radarWmStrain    = 1 - wmCapacityRemaining / 100
///   • radarRecovery    = 1 - residueAtEOD
///   • radarDopamine    = 1 - cognitiveLoadPct / 100
///   • radarSleep       = max(0, 1 - screenTime / 16)
///   • breakQuality     = hourlyLoad has a valley <20 after a peak >40
///   • weekOverWeekDelta = (week2 avg load) - (week1 avg load)  ≈ +13.5%
///   • focusBlocksLabel = screenTime × (productive% / 100)
///   • neuralObservation = residueAtEOD > 0.6  → "weekly accumulation" text
///   • isCritical       = cognitiveLoadPct > 70  → red badge fires today
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../database/sqlite_store.dart';

class MockDataSeeder {
  final SQLiteStore store;

  const MockDataSeeder({required this.store});

  // ─── Hourly load profiles ─────────────────────────────────────────────────
  // Each profile is a 24-element list (hours 0–23, values 0–100).
  // Profiles with a "valley" at hour 12 (<20 after >40 at hour 11) trigger
  // breakQualityReport to detect a recovery window on those days.

  static const List<double> _profileLightStudy = [
    0,
    0,
    0,
    0,
    0,
    2,
    10,
    24,
    45,
    58,
    64,
    72,
    16,
    38,
    68,
    78,
    71,
    62,
    48,
    34,
    22,
    14,
    8,
    2,
  ];

  static const List<double> _profileMediumStudy = [
    0,
    0,
    0,
    0,
    0,
    3,
    12,
    28,
    52,
    65,
    70,
    78,
    17,
    42,
    74,
    84,
    77,
    66,
    52,
    38,
    26,
    18,
    10,
    3,
  ];

  static const List<double> _profileHeavyStudy = [
    0,
    0,
    0,
    0,
    0,
    3,
    14,
    30,
    56,
    68,
    75,
    84,
    18,
    46,
    80,
    92,
    85,
    74,
    58,
    44,
    31,
    20,
    12,
    4,
  ];

  static const List<double> _profileWeekend = [
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    8,
    18,
    28,
    34,
    38,
    14,
    22,
    30,
    36,
    32,
    28,
    22,
    18,
    12,
    8,
    4,
    0,
  ];

  static const List<double> _profileWeekendLight = [
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    6,
    14,
    22,
    28,
    31,
    10,
    16,
    24,
    28,
    26,
    22,
    16,
    12,
    8,
    5,
    2,
    0,
  ];

  // Today's profile — engineered for maximum demo impact:
  //   hour 11 = 81  → breach (>80)   → red bar in Switch Velocity chart
  //   hour 12 = 18  → valley <20 after hour 11 >40  → break detected
  //   hour 15 = 91  → absolute peak  → peakLoadHour = 15 = "3 PM"
  //   Recovery coefficient: morning degrades, afternoon recovers after noon dip
  static const List<double> _profileToday = [
    0,
    0,
    0,
    0,
    0,
    3,
    12,
    28,
    52,
    67,
    72,
    81,
    18,
    44,
    78,
    91,
    83,
    72,
    58,
    42,
    31,
    22,
    14,
    6,
  ];

  // ─── Category breakdown helper ────────────────────────────────────────────
  // No 'tools' key — folded into 'productive' per AND-16 fix in sync_engine.
  // Values are percentages; they must sum to ~100.

  static String _cat(double p, double e, double s, double w) => jsonEncode({
        'productive': p,
        'entertainment': e,
        'social': s,
        'passiveWaste': w,
      });

  // ─── Master 14-day dataset ────────────────────────────────────────────────
  // Ordered oldest → newest. Entry index 13 = today (May 05).
  //
  // weekOverWeekDelta computation:
  //   Week 1 avg cogLoadPct = (58+63+71+76+38+32+62)/7 = 57.1%  [uses last 7 of first 7]
  //   Actually provider uses: twoWeeks[-7:] vs twoWeeks[-14:-7]
  //   Slot [0..6]  = Apr 22–28  avg = (58+63+71+76+38+32+62)/7 = 57.1
  //   Slot [7..13] = Apr 29–May05 avg = (67+72+78+74+41+35+74)/7 = 63.0
  //   weekOverWeekDelta = (63.0-57.1)/57.1*100 = +10.3%  → "RISING LOAD" story

  List<Map<String, dynamic>> get _days => [
        // ── Week 1 ──────────────────────────────────────────────────────────────

        // [0] Apr 22 — Tuesday, start of study week
        {
          'date': '2026-04-22',
          'cogDebt': 142.0,
          'cogLoadPct': 58.0,
          'wmCapacity': 68.0,
          'residue': 0.34,
          'screenTime': 5.8,
          'switches': 98,
          'pickups': 42,
          'peakHour': 14,
          'switchVelPeak': 4.2,
          'hourly': _profileLightStudy,
          'cat': _cat(48, 22, 18, 12),
        },

        // [1] Apr 23 — Wednesday, load building
        {
          'date': '2026-04-23',
          'cogDebt': 168.0,
          'cogLoadPct': 63.0,
          'wmCapacity': 62.0,
          'residue': 0.41,
          'screenTime': 6.4,
          'switches': 118,
          'pickups': 51,
          'peakHour': 15,
          'switchVelPeak': 5.1,
          'hourly': _profileMediumStudy,
          'cat': _cat(52, 19, 16, 13),
        },

        // [2] Apr 24 — Thursday, sustained effort
        {
          'date': '2026-04-24',
          'cogDebt': 198.0,
          'cogLoadPct': 71.0,
          'wmCapacity': 54.0,
          'residue': 0.52,
          'screenTime': 7.1,
          'switches': 142,
          'pickups': 63,
          'peakHour': 14,
          'switchVelPeak': 6.4,
          'hourly': _profileHeavyStudy,
          'cat': _cat(55, 18, 15, 12),
        },

        // [3] Apr 25 — Friday, highest load of week 1
        {
          'date': '2026-04-25',
          'cogDebt': 224.0,
          'cogLoadPct': 76.0,
          'wmCapacity': 48.0,
          'residue': 0.58,
          'screenTime': 7.8,
          'switches': 165,
          'pickups': 74,
          'peakHour': 15,
          'switchVelPeak': 7.2,
          'hourly': _profileHeavyStudy,
          'cat': _cat(50, 24, 16, 10),
        },

        // [4] Apr 26 — Saturday, significant recovery dip
        {
          'date': '2026-04-26',
          'cogDebt': 88.0,
          'cogLoadPct': 38.0,
          'wmCapacity': 82.0,
          'residue': 0.21,
          'screenTime': 3.4,
          'switches': 52,
          'pickups': 28,
          'peakHour': 12,
          'switchVelPeak': 2.4,
          'hourly': _profileWeekend,
          'cat': _cat(24, 42, 22, 12),
        },

        // [5] Apr 27 — Sunday, deepest recovery
        {
          'date': '2026-04-27',
          'cogDebt': 71.0,
          'cogLoadPct': 32.0,
          'wmCapacity': 88.0,
          'residue': 0.16,
          'screenTime': 2.9,
          'switches': 44,
          'pickups': 22,
          'peakHour': 11,
          'switchVelPeak': 1.8,
          'hourly': _profileWeekendLight,
          'cat': _cat(18, 48, 24, 10),
        },

        // [6] Apr 28 — Monday, back to work after good weekend
        {
          'date': '2026-04-28',
          'cogDebt': 158.0,
          'cogLoadPct': 62.0,
          'wmCapacity': 64.0,
          'residue': 0.44,
          'screenTime': 6.2,
          'switches': 112,
          'pickups': 55,
          'peakHour': 13,
          'switchVelPeak': 5.4,
          'hourly': _profileMediumStudy,
          'cat': _cat(51, 20, 17, 12),
        },

        // ── Week 2 ──────────────────────────────────────────────────────────────

        // [7] Apr 29 — Tuesday, load building
        {
          'date': '2026-04-29',
          'cogDebt': 182.0,
          'cogLoadPct': 67.0,
          'wmCapacity': 58.0,
          'residue': 0.48,
          'screenTime': 6.7,
          'switches': 131,
          'pickups': 59,
          'peakHour': 14,
          'switchVelPeak': 5.9,
          'hourly': _profileMediumStudy,
          'cat': _cat(54, 18, 16, 12),
        },

        // [8] Apr 30 — Wednesday, heavier than same day last week
        {
          'date': '2026-04-30',
          'cogDebt': 208.0,
          'cogLoadPct': 72.0,
          'wmCapacity': 52.0,
          'residue': 0.55,
          'screenTime': 7.3,
          'switches': 148,
          'pickups': 68,
          'peakHour': 15,
          'switchVelPeak': 6.8,
          'hourly': _profileHeavyStudy,
          'cat': _cat(56, 17, 15, 12),
        },

        // [9] May 01 — Thursday, peak of week 2
        {
          'date': '2026-05-01',
          'cogDebt': 241.0,
          'cogLoadPct': 78.0,
          'wmCapacity': 46.0,
          'residue': 0.62,
          'screenTime': 8.1,
          'switches': 178,
          'pickups': 79,
          'peakHour': 14,
          'switchVelPeak': 7.8,
          'hourly': _profileHeavyStudy,
          'cat': _cat(58, 16, 14, 12),
        },

        // [10] May 02 — Friday, slightly lower than Thursday
        {
          'date': '2026-05-02',
          'cogDebt': 228.0,
          'cogLoadPct': 74.0,
          'wmCapacity': 50.0,
          'residue': 0.57,
          'screenTime': 7.6,
          'switches': 161,
          'pickups': 72,
          'peakHour': 15,
          'switchVelPeak': 7.1,
          'hourly': _profileHeavyStudy,
          'cat': _cat(53, 20, 16, 11),
        },

        // [11] May 03 — Saturday, weekend recovery
        {
          'date': '2026-05-03',
          'cogDebt': 96.0,
          'cogLoadPct': 41.0,
          'wmCapacity': 79.0,
          'residue': 0.24,
          'screenTime': 3.8,
          'switches': 58,
          'pickups': 31,
          'peakHour': 13,
          'switchVelPeak': 2.8,
          'hourly': _profileWeekend,
          'cat': _cat(22, 44, 22, 12),
        },

        // [12] May 04 — Sunday, deepest recovery of week 2
        {
          'date': '2026-05-04',
          'cogDebt': 78.0,
          'cogLoadPct': 35.0,
          'wmCapacity': 85.0,
          'residue': 0.19,
          'screenTime': 3.1,
          'switches': 46,
          'pickups': 25,
          'peakHour': 12,
          'switchVelPeak': 2.1,
          'hourly': _profileWeekendLight,
          'cat': _cat(20, 46, 24, 10),
        },

        // [13] TODAY — May 05, Tuesday ─────────────────────────────────────────
        // Computed UI state this day produces:
        //   isCritical            = true  (cogLoadPct 74 > 70)  → red badge
        //   neuralObservation     = "Weekly accumulation..."  (residue 0.63 > 0.6)
        //   attnResidueLabel      = "High"  (0.63 > 0.6)
        //   attnResidueDeltaLabel = "SIGNIFICANT INCR."  (jumped from 0.19)
        //   wmStrain              = 49%  (100 - 51)
        //   recoveryDeltaLabel    = "DECLINING"  (this week WM avg ~52 vs last ~67)
        //   peakStressLabel       = "3 PM"  (hour 15)
        //   peakStressDeltaLabel  = "LATER THAN AVG"  (prev avg ~14, today 15)
        //   focusBlocksLabel      = "4h 4m"  (7.4 × 0.55)
        //   focusBlocksDeltaLabel = "+6% VS LAST MO."  (55% vs ~50.8% last week)
        //   tomorrowReadiness     = 26%  (100 - 74)
        //   readinessConclusion   → bedtime ~10:36 PM
        //   breakQuality          → 1 entry: hour 12 (18) after hour 11 (81)
        //   weekOverWeekDelta     ≈ +10.3%  (63.0 vs 57.1 avg)
        //   radarValues           = [0.51, 0.37, 0.49, 0.54, 0.26]
        //   heatmap               → row for today lights up hours 11, 14, 15 red
        {
          'date': '2026-05-05',
          'cogDebt': 231.0,
          'cogLoadPct': 74.0,
          'wmCapacity': 51.0,
          'residue': 0.63,
          'screenTime': 7.4,
          'switches': 158,
          'pickups': 71,
          'peakHour': 15,
          'switchVelPeak': 7.3,
          'hourly': _profileToday,
          'cat': _cat(55, 19, 15, 11),
        },
      ];

  // ─── Main seed methods ────────────────────────────────────────────────────

  /// [seed] — debug builds only. Skips if kDebugMode is false.
  /// Called from the legacy main.dart path.
  ///
  /// [seedAlways] — flavor-aware. Called from main_demo.dart regardless
  /// of build type, so demo APKs work in both debug and release mode.

  /// Writes all 14 days to SQLite. Safe to call multiple times — uses
  /// ConflictAlgorithm.replace so re-seeding always overwrites stale data.
  Future<void> seed() async {
    if (!kDebugMode) {
      debugPrint('[MockDataSeeder] Skipped — release build.');
      return;
    }

    debugPrint('[MockDataSeeder] Seeding ${_days.length} days of mock data...');
    int seeded = 0;

    for (final d in _days) {
      final hourly = d['hourly'] as List<double>;

      final row = DailyMetricsRow(
        date: d['date'] as String,
        cognitiveDebt: (d['cogDebt'] as num).toDouble(),
        cognitiveLoadPct: (d['cogLoadPct'] as num).toDouble(),
        wmCapacityRemaining: (d['wmCapacity'] as num).toDouble(),
        residueAtEOD: (d['residue'] as num).toDouble(),
        totalSwitches: d['switches'] as int,
        totalPickups: d['pickups'] as int,
        totalScreenTime: (d['screenTime'] as num).toDouble(),
        switchVelocityPeak: (d['switchVelPeak'] as num).toDouble(),
        peakLoadHour: d['peakHour'] as int,
        hourlyLoad: jsonEncode(hourly),
        categoryBreakdown: d['cat'] as String,
        // Mark as synced = 1 so the 15-min SyncEngine timer does NOT overwrite
        // historical days with empty recomputed values on next tick.
        synced: 1,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await store.upsertDailyMetrics(row);
      seeded++;
      debugPrint('[MockDataSeeder] ✓ ${d['date']} '
          '— load: ${d['cogLoadPct']}% '
          '| wm: ${d['wmCapacity']}% '
          '| residue: ${d['residue']}');
    }

    debugPrint('[MockDataSeeder] ✅ Done. $seeded rows written to SQLite.');
  }

  /// Flavor-aware seed — no kDebugMode guard.
  /// Use this from main_demo.dart so demo APKs work in both debug and
  /// release mode. Never call from main_live.dart.
  Future<void> seedAlways() async {
    debugPrint(
        '[MockDataSeeder] seedAlways() — demo flavor, seeding ${_days.length} days...');
    int seeded = 0;

    for (final d in _days) {
      final hourly = d['hourly'] as List<double>;

      final row = DailyMetricsRow(
        date: d['date'] as String,
        cognitiveDebt: (d['cogDebt'] as num).toDouble(),
        cognitiveLoadPct: (d['cogLoadPct'] as num).toDouble(),
        wmCapacityRemaining: (d['wmCapacity'] as num).toDouble(),
        residueAtEOD: (d['residue'] as num).toDouble(),
        totalSwitches: d['switches'] as int,
        totalPickups: d['pickups'] as int,
        totalScreenTime: (d['screenTime'] as num).toDouble(),
        switchVelocityPeak: (d['switchVelPeak'] as num).toDouble(),
        peakLoadHour: d['peakHour'] as int,
        hourlyLoad: jsonEncode(hourly),
        categoryBreakdown: d['cat'] as String,
        synced: 1,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await store.upsertDailyMetrics(row);
      seeded++;
    }

    debugPrint('[MockDataSeeder] ✅ seedAlways done. $seeded rows written.');
  }
}
