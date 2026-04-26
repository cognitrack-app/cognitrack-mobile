/// Reusable metric tile: label + big value + optional delta.
library;

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'nt_label.dart';

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.delta,
    this.valueColor,
    this.trailing,
  });

  final String label;
  final String value;
  final String? delta;
  final Color? valueColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            NtLabel(label),
            if (trailing != null) ...[
              const Spacer(),
              trailing!,
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: AppTextStyles.metricValue.copyWith(
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
        if (delta != null) ...[
          const SizedBox(height: 2),
          Text(delta!, style: AppTextStyles.deltaLabel),
        ],
      ],
    );
  }
}
