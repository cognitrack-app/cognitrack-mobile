/// Dual-device fragmentation score.
/// Dart port of @cognitrack/shared/src/fragmentation.ts
library;

import 'models.dart';

class FragmentationInput {
  final List<double> phoneHourlyDebt;
  final List<double> desktopHourlyDebt;
  final CategoryBreakdown phoneCategoryBreakdown;
  final CategoryBreakdown desktopCategoryBreakdown;

  FragmentationInput({
    required this.phoneHourlyDebt,
    required this.desktopHourlyDebt,
    required this.phoneCategoryBreakdown,
    required this.desktopCategoryBreakdown,
  });
}

class FragmentationReport {
  final int score;
  final int dualActiveHours;
  final int peakOverlapHour;

  FragmentationReport({
    required this.score,
    required this.dualActiveHours,
    required this.peakOverlapHour,
  });
}

/// Compute dual-device fragmentation score.
///
/// An hour counts as "dual-active" when:
///   - phone load > 20%  AND
///   - desktop load > 30%
///
/// This detects hours where the user was meaningfully engaged on BOTH
/// devices simultaneously, which is the primary fragmentation signal.
FragmentationReport computeDualDeviceFragmentation(FragmentationInput input) {
  int dualActiveHours = 0;
  int peakOverlapHour = 0;
  double maxOverlap = 0;

  for (int hour = 0; hour < 24; hour++) {
    final phoneLoad = input.phoneHourlyDebt[hour];
    final desktopLoad = input.desktopHourlyDebt[hour];

    if (phoneLoad > 20 && desktopLoad > 30) {
      dualActiveHours++;
      final overlap = phoneLoad + desktopLoad;
      if (overlap > maxOverlap) {
        maxOverlap = overlap;
        peakOverlapHour = hour;
      }
    }
  }

  return FragmentationReport(
    score: 24 < dualActiveHours ? 24 : dualActiveHours,
    dualActiveHours: dualActiveHours,
    peakOverlapHour: peakOverlapHour,
  );
}
