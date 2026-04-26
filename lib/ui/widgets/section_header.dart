/// Section header row — NtLabel above large section title.
library;

import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'nt_label.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.label,
    this.trailing,
  });

  final String title;
  final String? label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          NtLabel(label!),
          const SizedBox(height: AppSpacing.xs),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(title, style: AppTextStyles.sectionHead),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ],
    );
  }
}
