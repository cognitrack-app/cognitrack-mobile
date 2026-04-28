/// CogDebtRing — premium 3D arc progress ring for the hero COG. DEBT PTS card.
/// Animates from 0 → value every time the value changes.
/// Uses Canvas only — no external packages, zero jank on Android.
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
              style: AppTextStyles.chipLabel.copyWith(
                color: AppColors.red,
                fontSize: 11,
                fontWeight: FontWeight.w700,
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
    const strokeW = 4.5;
    const startAngle = -math.pi / 2;

    // Track
    final trackPaint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), radius, trackPaint);

    // Filled arc — red with glow
    final sweepAngle = 2 * math.pi * (percent.clamp(0, 100) / 100);

    // Glow layer (wider, dimmer)
    final glowPaint = Paint()
      ..color = AppColors.red.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW + 5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      startAngle,
      sweepAngle,
      false,
      glowPaint,
    );

    // Main arc
    final arcPaint = Paint()
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + (sweepAngle > 0 ? sweepAngle : 0.001),
        colors: [
          AppColors.red.withValues(alpha: 0.7),
          AppColors.red,
        ],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(Rect.fromCircle(
          center: Offset(cx, cy), radius: radius))
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
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.percent != percent;
}
