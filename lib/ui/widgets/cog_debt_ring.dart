/// CogDebtRing — premium 3D arc progress ring for the hero COG. DEBT PTS card.
/// Rebuilt for the "Clinical Observer" design system.
// ignore_for_file: prefer_const_literals_to_create_immutables
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class CogDebtRing extends StatefulWidget {
  const CogDebtRing({
    super.key,
    required this.percent,
    this.size = 72,
  });

  final double percent; // 0–100
  final double size;

  @override
  State<CogDebtRing> createState() => _CogDebtRingState();
}

class _CogDebtRingState extends State<CogDebtRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  double _fromPct = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _buildAnim(0, widget.percent);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(CogDebtRing old) {
    super.didUpdateWidget(old);
    if (old.percent != widget.percent) {
      _fromPct = old.percent;
      _buildAnim(_fromPct, widget.percent);
      _ctrl
        ..reset()
        ..forward();
    }
  }

  void _buildAnim(double from, double to) {
    _anim = Tween<double>(begin: from, end: to).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _RingPainter(percent: _anim.value),
          child: Center(
            child: Text(
              '${_anim.value.round()}%',
              style: AppTextStyles.labelSm.copyWith(
                color: AppColors.primary,
                fontSize: 12, // slightly larger for readability
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.percent});
  final double percent;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = (size.width / 2) - 5;
    const strokeW = 4.0; // Thicker, 4px arc per Stitch design
    const startAngle = -math.pi / 2;

    // Track - deep surface variant
    final trackPaint = Paint()
      ..color = AppColors.chartIdle
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), radius, trackPaint);

    final sweepAngle = 2 * math.pi * (percent.clamp(0, 100) / 100);

    if (sweepAngle <= 0) return;

    // Glow layer
    final glowPaint = Paint()
      ..color = AppColors.primaryContainer.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW + 8
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      startAngle,
      sweepAngle,
      false,
      glowPaint,
    );

    // Main arc - tapered gradient
    final arcPaint = Paint()
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + (sweepAngle > 0 ? sweepAngle : 0.001),
        colors: [
          AppColors.chartIdle,
          AppColors.primary,
        ],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      startAngle,
      sweepAngle,
      false,
      arcPaint,
    );

    // Neural Glow Point (Leading Edge)
    final dx = cx + radius * math.cos(startAngle + sweepAngle);
    final dy = cy + radius * math.sin(startAngle + sweepAngle);

    final pointGlow = Paint()
      ..color = AppColors.primaryContainer
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(Offset(dx, dy), 4, pointGlow);

    final pointWhite = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(dx, dy), 2, pointWhite);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.percent != percent;
}
