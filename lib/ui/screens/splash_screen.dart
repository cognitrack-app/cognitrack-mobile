/// Splash screen — shown while Firebase auth state is resolving.
/// Matches Stitch "CogniTrack Splash" screen:
///   Headline: "Know Your Brain. Own Your Focus."
///   Subtitle: "Track cognitive debt, focus loss, and mental overload in real time."
library;

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo mark
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(AppSpacing.cardR),
              ),
              child:
                  const Icon(Icons.psychology, size: 28, color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.xxl),
            // Brand name HUD label
            Text(
              'COGNITRACK',
              style: AppTextStyles.chipLabel.copyWith(
                color: AppColors.primaryContainer,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Stitch headline — "Know Your Brain. Own Your Focus."
            Text(
              'Know Your Brain.\nOwn Your Focus.',
              style: AppTextStyles.displayLg.copyWith(
                fontSize: 40,
                height: 1.15,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Stitch subtitle
            Text(
              'Track cognitive debt, focus loss, and mental overload in real time.',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textMuted,
                height: 1.6,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            // Loading indicator
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AppColors.primaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
