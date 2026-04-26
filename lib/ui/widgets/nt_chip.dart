/// Status badge chip — CRITICAL, HIGH VOLATILITY, etc.
library;

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_spacing.dart';

class NtChip extends StatelessWidget {
  const NtChip(
    this.label, {
    super.key,
    this.color = AppColors.red,
    this.outlined = false,
  });

  final String label;
  final Color color;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 0.8),
      ),
      child: Text(
        label,
        style: AppTextStyles.chipLabel.copyWith(color: color),
      ),
    );
  }
}
