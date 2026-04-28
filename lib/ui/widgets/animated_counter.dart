/// AnimatedCounter — counts up from 0 → [value] on mount and on [replay()].
///
/// Android performance:
///   • Uses AnimatedBuilder — only the Text widget rebuilds, not the tree
///   • AnimationController disposed on widget dispose (no leaks)
///   • Delay is a simple Future.delayed, not a Timer (lighter weight)
///   • easeOutCubic curve: fast start → smooth settle (feels snappy on device)
library;

import 'package:flutter/material.dart';

typedef CounterFormatter = String Function(double value);

class AnimatedCounter extends StatefulWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    required this.style,
    this.duration = const Duration(milliseconds: 1100),
    this.curve = Curves.easeOutCubic,
    this.formatter,
    this.delay = Duration.zero,
  });

  /// The target numeric value to count up to.
  final double value;
  final TextStyle style;
  final Duration duration;
  final Curve curve;

  /// Custom display formatter.  Defaults to integer string.
  final CounterFormatter? formatter;

  /// Delay before the counter starts (used for staggered card entrance).
  final Duration delay;

  @override
  State<AnimatedCounter> createState() => AnimatedCounterState();
}

class AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _buildAnimation();
    _schedulePlay();
  }

  @override
  void didUpdateWidget(AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _buildAnimation();
      replay();
    }
  }

  void _buildAnimation() {
    _anim = Tween<double>(begin: 0, end: widget.value).animate(
      CurvedAnimation(parent: _ctrl, curve: widget.curve),
    );
  }

  void _schedulePlay() {
    if (widget.delay == Duration.zero) {
      _ctrl.forward(from: 0);
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward(from: 0);
      });
    }
  }

  /// Restart the count-up.  Called by DashboardScreen when tab becomes visible.
  void replay() {
    if (!mounted) return;
    _ctrl.reset();
    _schedulePlay();
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
        final formatted = widget.formatter != null
            ? widget.formatter!(_anim.value)
            : _anim.value.toStringAsFixed(0);
        return Text(formatted, style: widget.style);
      },
    );
  }
}
