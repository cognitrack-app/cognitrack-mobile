/// Onboarding screen — full-bleed brain hero, immersive dark design.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/noise_overlay.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _slideAnim;
  bool _ctaTapped = false;

  @override
  void initState() {
    super.initState();
    // Full-screen immersive: hide status bar, go edge-to-edge
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.04).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _slideAnim = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    // Restore system UI when leaving onboarding
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _proceed() async {
    if (_ctaTapped) return;
    setState(() => _ctaTapped = true);
    await context.read<AuthProvider>().completeOnboarding();
    if (mounted) context.go('/auth/sign-in');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPad = MediaQuery.of(context).padding.top;
    final botPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.bg,
      // extendBodyBehindAppBar not needed — no AppBar
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ───────────────────────────────────────────────────────────────────
          // LAYER 1: full-bleed brain image filling the top 60% of screen
          // ───────────────────────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.62,
            child: ScaleTransition(
              scale: _pulseAnim,
              child: Image.asset(
                'assets/images/brain_3d.png',
                width: size.width,
                height: size.height * 0.62,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (_, __, ___) => _BrainFallback(
                  width: size.width,
                  height: size.height * 0.62,
                ),
              ),
            ),
          ),

          // ───────────────────────────────────────────────────────────────────
          // LAYER 2: spoke rays overlay on the brain
          // ───────────────────────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.62,
            child: CustomPaint(
              painter: _SpokeRayPainter(),
            ),
          ),

          // ───────────────────────────────────────────────────────────────────
          // LAYER 3: gradient fade from transparent → bg (merges image into bg)
          // ───────────────────────────────────────────────────────────────────
          Positioned(
            top: size.height * 0.28,
            left: 0,
            right: 0,
            height: size.height * 0.40,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.bg.withValues(alpha: 0.0),
                    AppColors.bg.withValues(alpha: 0.55),
                    AppColors.bg,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // ───────────────────────────────────────────────────────────────────
          // LAYER 4: noise texture for premium feel
          // ───────────────────────────────────────────────────────────────────
          const Positioned.fill(child: NoiseOverlay()),

          // ───────────────────────────────────────────────────────────────────
          // LAYER 5: top bar (CogniTrack logo + Skip)
          // ───────────────────────────────────────────────────────────────────
          Positioned(
            top: topPad + 12,
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
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _proceed,
                  child: Text(
                    'skip',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ───────────────────────────────────────────────────────────────────
          // LAYER 6: bottom content — headline + body + CTA
          // ───────────────────────────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _fadeCtrl,
              builder: (context, child) => Transform.translate(
                offset: Offset(0, _slideAnim.value),
                child: Opacity(
                  opacity: _fadeAnim.value,
                  child: child,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  botPad + AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Know Your Brain.\nOwn Your Focus.',
                      style: AppTextStyles.display.copyWith(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Track cognitive debt, focus loss, and\nmental overload in real time.',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    // ── CTA row ──────────────────────────────────────────────
                    GestureDetector(
                      onTap: _proceed,
                      child: AnimatedScale(
                        scale: _ctaTapped ? 0.94 : 1.0,
                        duration: const Duration(milliseconds: 140),
                        curve: Curves.easeOut,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.red,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        AppColors.red.withValues(alpha: 0.45),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: _ctaTapped
                                  ? const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.arrow_forward_rounded,
                                      color: Colors.white,
                                      size: 26,
                                    ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Text(
                              'Connect Now',
                              style: AppTextStyles.sectionHead.copyWith(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Brain fallback when asset fails to load ─────────────────────────────────────────
class _BrainFallback extends StatelessWidget {
  final double width;
  final double height;
  const _BrainFallback({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.75,
          colors: [
            Color(0xFF00BCD4),
            Color(0xFF006064),
            Color(0xFF0A0A0A),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.psychology_outlined,
          size: 140,
          color: Color(0xFF80DEEA),
        ),
      ),
    );
  }
}

// ── Spoke ray painter ───────────────────────────────────────────────────────────────────
class _SpokeRayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCC1020).withValues(alpha: 0.22)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height * 0.52);
    final radius = size.width * 1.1;

    for (int i = 0; i < 16; i++) {
      final angle = (i * (360 / 16)) * (math.pi / 180.0);
      final end = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      canvas.drawLine(center, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
