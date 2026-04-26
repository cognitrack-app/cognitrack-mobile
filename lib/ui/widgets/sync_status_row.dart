/// Sync status row — live telemetry dot + last sync text.
library;

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class SyncStatusRow extends StatelessWidget {
  const SyncStatusRow({
    super.key,
    required this.isLive,
    this.lastSyncMinutesAgo,
    this.deviceId,
  });

  final bool isLive;
  final int? lastSyncMinutesAgo;
  final String? deviceId;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (deviceId != null)
          Text(
            'ID: ${deviceId!.substring(0, 8).toUpperCase()}',
            style: AppTextStyles.chipLabel.copyWith(color: AppColors.textMuted),
          ),
        const SizedBox(width: 8),
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isLive ? AppColors.good : AppColors.warn,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          isLive ? '• LIVE TELEMETRY' : '• OFFLINE',
          style: AppTextStyles.chipLabel.copyWith(
            color: isLive ? AppColors.good : AppColors.warn,
          ),
        ),
        if (lastSyncMinutesAgo != null) ...[
          const SizedBox(width: 8),
          Text(
            'Sync: ${lastSyncMinutesAgo}m ago',
            style: AppTextStyles.deltaLabel,
          ),
        ],
      ],
    );
  }
}
