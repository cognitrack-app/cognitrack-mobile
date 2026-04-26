/// Shimmer skeleton card for loading states.
library;

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class ShimmerCard extends StatelessWidget {
  const ShimmerCard({super.key, this.height = 100, this.width});

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surfaceHigh,
      child: Container(
        width: width ?? double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.cardR),
        ),
      ),
    );
  }
}

class ShimmerList extends StatelessWidget {
  const ShimmerList({super.key, this.count = 3, this.itemHeight = 100});

  final int count;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
          count,
          (i) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sectionGap),
                child: ShimmerCard(height: itemHeight),
              )),
    );
  }
}
