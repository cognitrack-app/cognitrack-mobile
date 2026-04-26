/// Permission screen — Android Usage Stats permission gate.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../../core/providers/permissions_provider.dart';

class PermissionScreen extends StatelessWidget {
  const PermissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final perms = context.watch<PermissionsProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xxl),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.redDim,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.security_outlined,
                    size: 32, color: AppColors.red),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('One Permission\nRequired',
                  style: AppTextStyles.display.copyWith(height: 1.2)),
              const SizedBox(height: AppSpacing.md),
              Text(
                'CogniTrack needs access to App Usage data to track '
                'context switches and compute your cognitive load accurately. '
                'No data leaves your device without encryption.',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppSpacing.xl),

              // Permission items
              _PermItem(
                icon: Icons.smartphone_outlined,
                title: 'App Usage Access',
                description:
                    'Counts context switches between apps to measure cognitive load.',
              ),
              const SizedBox(height: AppSpacing.sm),
              _PermItem(
                icon: Icons.lock_outlined,
                title: 'No Data Sold',
                description: 'All processing happens locally on your device.',
              ),

              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (await Permission.ignoreBatteryOptimizations.isDenied) {
                      await Permission.ignoreBatteryOptimizations.request();
                    }
                    await perms.requestPermission();
                  },
                  child: Text('GRANT PERMISSION',
                      style: AppTextStyles.chipLabel
                          .copyWith(color: Colors.white, letterSpacing: 1.5)),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermItem extends StatelessWidget {
  const _PermItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardR),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.red, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.cardTitle),
                const SizedBox(height: 2),
                Text(description, style: AppTextStyles.deltaLabel),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
