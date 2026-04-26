/// Base dark card with optional red border.
library;

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class NtCard extends StatelessWidget {
  const NtCard({
    super.key,
    required this.child,
    this.redBorder = false,
    this.padding,
    this.color,
  });

  final Widget child;
  final bool redBorder;
  final EdgeInsetsGeometry? padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardR),
        border: Border.all(
          color: redBorder ? AppColors.borderRed : AppColors.border,
          width: redBorder ? 1.0 : 0.5,
        ),
      ),
      child: child,
    );
  }
}
