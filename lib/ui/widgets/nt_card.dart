import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class NtCard extends StatelessWidget {
  const NtCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.glass = false, // set true for hero floating cards
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final baseDecoration = BoxDecoration(
      color: glass
          ? const Color(0xFF121212).withValues(alpha: 0.7)
          : (color ?? AppColors.surface),
      borderRadius: BorderRadius.circular(AppSpacing.cardR),
      // No-Line Rule: borders are forbidden for containment.
      // Separation is achieved through tonal color shift (surface #201F1F on bg #131313).
      boxShadow: [
        BoxShadow(
          color: AppColors.shadowCrimson.withValues(alpha: 0.06),
          blurRadius: 40,
          offset: const Offset(0, 8),
        ),
      ],
    );

    final inner = Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      decoration: baseDecoration,
      child: child,
    );

    if (!glass) return inner;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.cardR),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: inner,
      ),
    );
  }
}
