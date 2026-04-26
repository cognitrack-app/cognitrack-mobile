/// Red filled linear progress bar — WM Strain indicator.
library;

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class WmStrainBar extends StatelessWidget {
  const WmStrainBar({
    super.key,
    required this.value,
    this.label,
    this.showPercent = true,
  });

  final double value; // 0.0 – 1.0
  final String? label;
  final bool showPercent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null || showPercent)
          Row(
            children: [
              if (label != null) Text(label!, style: AppTextStyles.chipLabel),
              const Spacer(),
              if (showPercent)
                Text(
                  '${(value * 100).toStringAsFixed(0)}%',
                  style: AppTextStyles.chipLabel.copyWith(color: AppColors.red),
                ),
            ],
          ),
        if (label != null || showPercent) const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            backgroundColor: AppColors.chartGray,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.red),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
