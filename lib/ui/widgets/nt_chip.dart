/// Status badge chip — CRITICAL, HIGH VOLATILITY, etc.
/// Stitch spec: "Use surface_container_highest for the background with no border."
library;

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_spacing.dart';

class NtChip extends StatelessWidget {
  const NtChip(
    this.label, {
    super.key,
    this.color = AppColors.primary,
    this.outlined = false,
  });

  final String label;
  final Color color;

  /// [outlined] kept for API compatibility — now just adjusts text alpha.
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        // Stitch: surface_container_highest background, no border
        color: AppColors.surfaceHigh.withValues(alpha: outlined ? 0.0 : 1.0),
        borderRadius: BorderRadius.circular(AppSpacing.cardR),
        // No explicit border — Stitch chip spec
      ),
      child: Text(
        label,
        style: AppTextStyles.chipLabel.copyWith(color: color),
      ),
    );
  }
}
