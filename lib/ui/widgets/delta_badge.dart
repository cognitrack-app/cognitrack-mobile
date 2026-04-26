/// Delta badge — +12%, Below avg, LATER THAN AVG.
library;

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum DeltaType { positive, negative, neutral, warn }

class DeltaBadge extends StatelessWidget {
  const DeltaBadge(
    this.text, {
    super.key,
    this.type = DeltaType.neutral,
    this.color,
  });

  final String text;
  final DeltaType type;
  final Color? color;

  Color get _color {
    if (color != null) return color!;
    switch (type) {
      case DeltaType.positive:
        return AppColors.good;
      case DeltaType.negative:
        return AppColors.red;
      case DeltaType.warn:
        return AppColors.warn;
      case DeltaType.neutral:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.deltaLabel.copyWith(color: _color),
    );
  }
}
