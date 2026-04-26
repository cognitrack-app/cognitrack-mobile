/// Splash screen — shown while Firebase auth state is resolving.
library;

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.red,
              ),
              child:
                  const Icon(Icons.psychology, size: 36, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text('CogniTrack',
                style: AppTextStyles.sectionHead.copyWith(
                  color: AppColors.textPrimary,
                  letterSpacing: 1,
                )),
            const SizedBox(height: 32),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
