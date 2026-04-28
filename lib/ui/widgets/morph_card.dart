/// MorphCard — 3D glassmorphism card with depth, glow, and shimmer sweep.
/// Android-optimised: uses RepaintBoundary, avoids ImageFilter blur on low-end.
library;

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class MorphCard extends StatefulWidget {
  const MorphCard({
    super.key,
    required this.child,
    this.glowColor,
    this.borderColor,
    this.padding,
    this.height,
    this.animateIn = false,
    this.animationDelay = Duration.zero,
    this.enableSweep = true,
  });

  final Widget child;
  final Color? glowColor;
  final Color? borderColor;
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
    final glow = widget.glowColor ?? AppColors.red;
    final border = widget.borderColor ?? AppColors.border;

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
            child: Container(
              height: widget.height,
              padding:
                  widget.padding ?? const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border, width: 0.8),
                boxShadow: [
                  // depth shadow
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                    spreadRadius: -4,
                  ),
                  // glow
                  BoxShadow(
                    color: glow.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 0),
                  ),
                ],
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.surfaceHigh,
                    AppColors.surface,
                    AppColors.surfaceDim,
                  ],
                  stops: const [0.0, 0.5, 1.0],
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
    final rrect =
        RRect.fromRectAndRadius(rect, const Radius.circular(16));

    // Sweep moves from left-outside to right-outside
    final sweepX = (progress * (size.width + 80)) - 40;

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.06),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(
        Rect.fromLTWH(sweepX - 30, 0, 60, size.height),
      );

    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(
        Rect.fromLTWH(sweepX - 30, 0, 60, size.height), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SweepPainter old) => old.progress != progress;
}
