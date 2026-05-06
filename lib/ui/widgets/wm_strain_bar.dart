/// Gradient linear progress bar — WM Strain indicator.
/// Rebuilt for the "Clinical Observer" design system.
// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
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
              if (label != null) Text(label!, style: AppTextStyles.labelSm),
              const Spacer(),
              if (showPercent)
                Text(
                  '${(value * 100).toStringAsFixed(0)}%',
                  style:
                      AppTextStyles.labelSm.copyWith(color: AppColors.primary),
                ),
            ],
          ),
        if (label != null || showPercent) const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final activeWidth = width * value.clamp(0.0, 1.0);

            return Container(
              height: 4, // Tapered, thin line
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.chartIdle,
                borderRadius: BorderRadius.circular(2),
              ),
              child: Stack(
                children: [
                  // Active Progress Gradient
                  Container(
                    width: activeWidth,
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: const LinearGradient(
                        colors: [AppColors.chartIdle, AppColors.primary],
                      ),
                    ),
                  ),
                  // Neural Glow Point (Leading edge)
                  if (activeWidth > 0)
                    Positioned(
                      left: activeWidth - 4,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 4,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryContainer,
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
