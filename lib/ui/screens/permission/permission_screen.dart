/// Permission screen — Android Usage Stats permission gate.
// ignore_for_file: prefer_const_constructors
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../../core/providers/permissions_provider.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen>
    with WidgetsBindingObserver {
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    // Register observer directly on this State so we own the lifecycle.
    // PermissionsProvider.startListening() is NOT called here to avoid
    // double-registration — this widget handles the resume check itself.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Called when user returns from Android Settings after toggling permission.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _recheckAndAdvance();
    }
  }

  Future<void> _recheckAndAdvance() async {
    final perms = context.read<PermissionsProvider>();
    await perms.check();
    // If permission was granted, GoRouter's refreshListenable will redirect.
    // Belt-and-suspenders: also manually go if we are still mounted.
    if (mounted && perms.hasPermission) {
      context.go('/dashboard');
    }
  }

  Future<void> _onGrantPressed() async {
    setState(() => _requesting = true);
    // Capture provider reference before any await — fixes
    // use_build_context_synchronously lint warning.
    final perms = context.read<PermissionsProvider>();
    // Request battery optimisation exemption first (silent, non-blocking)
    if (await Permission.ignoreBatteryOptimizations.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    }
    // Open Android Usage Access Settings — user toggles the switch there
    await perms.requestPermission();
    if (mounted) setState(() => _requesting = false);
    // Do NOT check here — user is still inside Settings.
    // didChangeAppLifecycleState.resumed handles the re-check when they return.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xxl),
              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.security_outlined,
                    size: 32, color: AppColors.red),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'One Permission\nRequired',
                style: AppTextStyles.display.copyWith(height: 1.2),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'CogniTrack needs App Usage access to track '
                'context switches and compute your cognitive load. '
                'All processing stays on your device.',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppSpacing.xl),
              _PermItem(
                icon: Icons.smartphone_outlined,
                title: 'App Usage Access',
                description:
                    'Counts context switches to measure cognitive load.',
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
                  onPressed: _requesting ? null : _onGrantPressed,
                  child: _requesting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'GRANT PERMISSION',
                          style: AppTextStyles.labelSm.copyWith(
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
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
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppColors.red),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.cardTitle
                        .copyWith(color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(description, style: AppTextStyles.labelSm),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
