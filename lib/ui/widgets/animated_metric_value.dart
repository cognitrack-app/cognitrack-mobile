/// AnimatedMetricValue — counts up to a number with a smooth curve,
/// re-plays every time the value changes (not just first open).
/// Uses integer-step ticker for sharp digit snapping on Android.
library;

import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';

class AnimatedMetricValue extends StatefulWidget {
  const AnimatedMetricValue({
    super.key,
    required this.value,
    required this.suffix,
    this.style,
    this.duration = const Duration(milliseconds: 900),
    this.decimals = 0,
  });

  final double value;
  final String suffix;
  final TextStyle? style;
  final Duration duration;
  final int decimals;

  @override
  State<AnimatedMetricValue> createState() => _AnimatedMetricValueState();
}

class _AnimatedMetricValueState extends State<AnimatedMetricValue>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  double _from = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _buildAnimation(0, widget.value);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(AnimatedMetricValue old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _from = old.value;
      _buildAnimation(_from, widget.value);
      _ctrl
        ..reset()
        ..forward();
    }
  }

  void _buildAnimation(double from, double to) {
    _anim = Tween<double>(begin: from, end: to).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Curves.easeOutCubic,
      ),
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
      builder: (_, __) {
        final display = widget.decimals > 0
            ? _anim.value.toStringAsFixed(widget.decimals)
            : _anim.value.round().toString();
        return Text(
          '$display${widget.suffix}',
          style: widget.style ?? AppTextStyles.metricValue,
        );
      },
    );
  }
}
