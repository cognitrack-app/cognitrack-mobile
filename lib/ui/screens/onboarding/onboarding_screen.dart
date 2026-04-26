/// Onboarding screen — full-screen brain hero + CTA.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  bool _ctaTapped = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _proceed() async {
    setState(() => _ctaTapped = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (mounted) context.go('/auth/sign-in');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // ── Radial glow behind brain ─────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.55,
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.1,
                  colors: [Color(0xFF1A0505), AppColors.bg],
                ),
              ),
            ),
          ),

          // ── Brain illustration placeholder (atmospheric glow) ────────────
          Positioned(
            top: size.height * 0.02,
            left: 0,
            right: 0,
            height: size.height * 0.48,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Red glow blob
                  Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.red.withValues(alpha: 0.15),
                          blurRadius: 120,
                          spreadRadius: 60,
                        ),
                      ],
                    ),
                  ),
                  // Brain icon representation
                  const Icon(
                    Icons.psychology,
                    size: 180,
                    color: Color(0xFF3A0808),
                  ),
                  // Overlay pulsing ring
                  Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.red.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Top bar ──────────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            child: Row(
              children: [
                Text(
                  'CogniTrack',
                  style: AppTextStyles.cardTitle.copyWith(
                    color: AppColors.red,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _proceed,
                  child: Text(
                    'Skip',
                    style: AppTextStyles.chipLabel.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom content ───────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: size.height * 0.48,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.bg, AppColors.bg],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Know Your Brain.\nOwn Your Focus.',
                    style: AppTextStyles.display.copyWith(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Track cognitive debt, focus loss, and mental overload '
                    'in real time. Science-backed insights for peak performance.',
                    style: AppTextStyles.body,
                  ),
                  const Spacer(),
                  // ── CTA ─────────────────────────────────────────────────
                  GestureDetector(
                    onTap: _proceed,
                    child: AnimatedScale(
                      scale: _ctaTapped ? 0.95 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.red,
                            ),
                            child: const Icon(Icons.arrow_forward,
                                color: Colors.white),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Text(
                            'Connect Now',
                            style: AppTextStyles.sectionHead.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                      height: MediaQuery.of(context).padding.bottom +
                          AppSpacing.lg),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
