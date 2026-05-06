/// MorphMetricCard — a single metric cell with glassmorphism base,
/// animated count-up value, label, and optional glow ring.
/// Rebuilt for the "Clinical Observer" design system.
/// BackdropFilter blur matches Stitch "Glass & Crimson" rule (20px).
library;

import 'dart:io' as io;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'animated_metric_value.dart';
import 'delta_badge.dart';
import 'nt_label.dart';
import 'nt_chip.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_spacing.dart';

class MorphMetricCard extends StatefulWidget {
  const MorphMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.suffix,
    this.decimals = 0,
    this.deltaLabel,
    this.deltaType = DeltaType.neutral,
    this.glowColor,
    this.isCritical = false,
    this.chipLabel,
    this.subText,
    this.animationDelay = Duration.zero,
    this.icon,
  });

  final String label;
  final double value;
  final String suffix;
  final int decimals;
  final String? deltaLabel;
  final DeltaType deltaType;
  final Color? glowColor;
  final bool isCritical;
  final String? chipLabel;
  final String? subText;
  final Duration animationDelay;
  final IconData? icon;

  @override
  State<MorphMetricCard> createState() => _MorphMetricCardState();
}

class _MorphMetricCardState extends State<MorphMetricCard> {
  final GlobalKey<_MorphCardState> _cardKey = GlobalKey<_MorphCardState>();

  // Track previous value to re-trigger card sweep on change
  double? _lastValue;

  @override
  void didUpdateWidget(MorphMetricCard old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && _lastValue != null) {
      _cardKey.currentState?.replay();
    }
    _lastValue = widget.value;
  }

  @override
  void initState() {
    super.initState();
    _lastValue = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    final glow = widget.isCritical
        ? AppColors.primaryContainer
        : (widget.glowColor ?? AppColors.primaryContainer);

    return _MorphCardShell(
      key: _cardKey,
      glowColor: glow,
      animateIn: true,
      animationDelay: widget.animationDelay,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 11, color: glow),
                const SizedBox(width: 5),
              ],
              NtLabel(widget.label,
                  color: widget.isCritical
                      ? AppColors.primary.withValues(alpha: 0.8)
                      : null),
              if (widget.chipLabel != null) ...[
                const Spacer(),
                NtChip(widget.chipLabel!, color: AppColors.primary),
              ],
            ],
          ),
          const SizedBox(height: 6),
          AnimatedMetricValue(
            value: widget.value,
            suffix: widget.suffix,
            decimals: widget.decimals,
            duration: const Duration(milliseconds: 950),
            // Fix #10: Use raw display style (28px = 1.75rem per Stitch spec).
            // Removed fontSize: 26 override.
            style: AppTextStyles.display.copyWith(
              color:
                  widget.isCritical ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
          if (widget.subText != null) ...[
            const SizedBox(height: 2),
            Text(widget.subText!, style: AppTextStyles.deltaLabel),
          ],
          if (widget.deltaLabel != null) ...[
            const SizedBox(height: 4),
            DeltaBadge(widget.deltaLabel!, type: widget.deltaType),
          ],
        ],
      ),
    );
  }
}

// Internal shell that exposes replay() via GlobalKey
class _MorphCardShell extends StatefulWidget {
  const _MorphCardShell({
    super.key,
    required this.child,
    required this.glowColor,
    required this.animateIn,
    required this.animationDelay,
  });

  final Widget child;
  final Color glowColor;
  final bool animateIn;
  final Duration animationDelay;

  @override
  State<_MorphCardShell> createState() => _MorphCardState();
}

class _MorphCardState extends State<_MorphCardShell>
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

  void replay() {
    _ctrl.reset();
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
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
              if (_sweepAnim.value >= 1.0 || _sweepAnim.value <= 0.0) {
                return child!;
              }
              return CustomPaint(
                foregroundPainter: _SweepPainter(
                  progress: _sweepAnim.value,
                  radius: AppSpacing.cardR,
                ),
                child: child,
              );
            },
            // BackdropFilter only on iOS — Android's GPU compositing
            // repaints the blur layer on every frame tick, causing visible
            // flicker. On Android we use a solid surface instead.
            child: io.Platform.isAndroid
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(AppSpacing.cardR),
                      border: Border.all(
                        color: AppColors.outlineVariant.withValues(alpha: 0.15),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              AppColors.shadowCrimson.withValues(alpha: 0.06),
                          blurRadius: 40,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      gradient: RadialGradient(
                        center: const Alignment(0.8, -0.8),
                        radius: 1.5,
                        colors: [
                          widget.glowColor.withValues(alpha: 0.15),
                          widget.glowColor.withValues(alpha: 0.05),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.4, 1.0],
                      ),
                    ),
                    child: widget.child,
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.cardR),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color:
                              AppColors.surfaceLowest.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(AppSpacing.cardR),
                          border: Border.all(
                            color: AppColors.outlineVariant
                                .withValues(alpha: 0.15),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.shadowCrimson
                                  .withValues(alpha: 0.06),
                              blurRadius: 40,
                              offset: const Offset(0, 8),
                            ),
                          ],
                          gradient: RadialGradient(
                            center: const Alignment(0.8, -0.8),
                            radius: 1.5,
                            colors: [
                              widget.glowColor.withValues(alpha: 0.15),
                              widget.glowColor.withValues(alpha: 0.05),
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

class _SweepPainter extends CustomPainter {
  const _SweepPainter({required this.progress, this.radius = 8.0});
  final double progress;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final sweepX = (progress * (size.width + 80)) - 40;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.055),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(sweepX - 30, 0, 60, size.height));
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(Rect.fromLTWH(sweepX - 30, 0, 60, size.height), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SweepPainter old) =>
      old.progress != progress || old.radius != radius;
}
