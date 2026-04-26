/// Uppercase section label — "NEURAL TELEMETRY", "METRIC 01".
library;

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class NtLabel extends StatelessWidget {
  const NtLabel(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.chipLabel.copyWith(
        color: color ?? AppColors.textMuted,
        letterSpacing: 1.5,
      ),
    );
  }
}
