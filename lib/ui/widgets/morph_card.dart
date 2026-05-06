/// MorphCard — 3D glassmorphism card with depth, glow, and shimmer sweep.
/// Rebuilt for the "Clinical Observer" design system.
library;

import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;
import '../theme/app_colors.dart';

class MorphCard extends StatefulWidget {
  const MorphCard({
    super.key,
    required this.child,
    this.padding,
    this.height,
    this.animateIn = false,
    this.animationDelay = Duration.zero,
    this.enableSweep = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? height;

  /// Whether to play the entry animation (stagger-in from parent).
  final bool animateIn;
  final Duration animationDelay;

  /// Sweep shimmer on first appearance.
  final bool enableSweep;

  @override
  State<MorphCard> createState() => _MorphCardState();
}

class _MorphCardState extends State<MorphCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _sweepAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
    ));

    _sweepAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.2, 1.0, curve: Curves.easeInOut),
    );

    if (widget.animateIn) {
      Future.delayed(widget.animationDelay, () {
        if (mounted) _ctrl.forward();
      });
    } else {
      _ctrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Called by parent to re-trigger the animation (e.g. every time metrics load).
  void replay() {
    _ctrl.reset();
    _ctrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: AnimatedBuilder(
            animation: _sweepAnim,
            builder: (context, child) {
              return CustomPaint(
                foregroundPainter: widget.enableSweep
                    ? _SweepPainter(progress: _sweepAnim.value)
                    : null,
                child: child,
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), // 20px blur
                child: Container(
                  height: widget.height,
                  padding: widget.padding ?? const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    // surface_container_lowest at 92% opacity
                    color: AppColors.surfaceLowest.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(16),
                    // Ghost Border Fallback
                    border: Border.all(
                      color: AppColors.outlineVariant.withValues(alpha: 0.15),
                      width: 1.0,
                    ),
                    boxShadow: [
                      // Ambient Shadows: blur 40px, 6% opacity, tinted Crimson
                      BoxShadow(
                        color: AppColors.shadowCrimson.withValues(alpha: 0.06),
                        blurRadius: 40,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    // Neural glow radial transition
                    gradient: RadialGradient(
                      center:
                          const Alignment(0.8, -0.8), // 45 degree angle approx
                      radius: 1.5,
                      colors: [
                        AppColors.primaryContainer.withValues(alpha: 0.15),
                        AppColors.primary.withValues(alpha: 0.05),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.4, 1.0],
                    ),
                  ),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints a single diagonal sweep shimmer across the card.
class _SweepPainter extends CustomPainter {
  const _SweepPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(16));

    // Sweep moves from left-outside to right-outside
    final sweepX = (progress * (size.width + 80)) - 40;

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.04), // subtle shimmer
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(
        Rect.fromLTWH(sweepX - 30, 0, 60, size.height),
      );

    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(Rect.fromLTWH(sweepX - 30, 0, 60, size.height), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SweepPainter old) => old.progress != progress;
}
