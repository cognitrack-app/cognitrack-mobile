/// MetricEntry — staggered slide-up + fade-in entrance animation wrapper.
///
/// Wraps any child in a FadeTransition + SlideTransition so the widget
/// glides in from slightly below.  Exposes [replay()] so DashboardScreen
/// can re-trigger the animation every time the home tab becomes active.
///
/// Android performance:
///   • FadeTransition → only changes opacity layer (GPU composited)
///   • SlideTransition → only changes transform matrix (GPU composited)
///   • ZERO layout recalculation during animation — safe at 60 / 120 Hz
///   • SingleTickerProviderStateMixin: minimal ticker overhead vs vsync pool
library;

import 'package:flutter/material.dart';

class MetricEntry extends StatefulWidget {
  const MetricEntry({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 520),
    /// Slide offset as a fraction of the widget’s own height (Offset.dy).
    this.offsetY = 0.10,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offsetY;

  @override
  State<MetricEntry> createState() => MetricEntryState();
}

class MetricEntryState extends State<MetricEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  late final Animation<double> _opacity = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOutCubic,
  );

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: Offset(0, widget.offsetY),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    _schedulePlay();
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

  /// Re-trigger entrance animation.  Called when the dashboard tab is
  /// re-selected so every visit feels fresh and alive.
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
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}
