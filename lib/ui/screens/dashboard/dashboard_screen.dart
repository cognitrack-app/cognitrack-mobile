/// Dashboard screen — 3D Morphism redesign.
/// Animations re-trigger on every metrics load, not just first open.
/// Android-optimised: RepaintBoundary on every heavy widget, no blur filters,
/// all animations use easeOutCubic curves @ 60fps-safe durations.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/nt_label.dart';
import '../../widgets/shimmer_card.dart';
import '../../widgets/delta_badge.dart';
import '../../widgets/morph_metric_card.dart';
import '../../widgets/cog_debt_ring.dart';
import '../../widgets/animated_metric_value.dart';
import '../../../core/providers/dashboard_provider.dart';
import '../../../core/providers/recovery_provider.dart';
import '../../../core/database/sqlite_store.dart';
import '../../../platform/ios/manual_session_logger.dart';
import 'dart:io' as io;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  int _tabIndex = 1;

  // Header animation — plays every time loading → done
  late final AnimationController _headerCtrl;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;

  // Track loading state to detect the loading→done transition
  bool _wasLoading = true;

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _headerFade = CurvedAnimation(
      parent: _headerCtrl,
      curve: Curves.easeOut,
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _headerCtrl,
      curve: Curves.easeOutCubic,
    ));
    // Play header in immediately
    _headerCtrl.forward();
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    super.dispose();
  }

  /// Called whenever the provider state changes. Re-triggers header anim
  /// each time data finishes loading (shimmer → content).
  void _handleLoadingTransition(bool isLoading) {
    if (_wasLoading && !isLoading) {
      // Data just became available — re-animate header
      _headerCtrl
        ..reset()
        ..forward();
    }
    _wasLoading = isLoading;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.red,
          backgroundColor: AppColors.surface,
          onRefresh: () => context.read<DashboardProvider>().refresh(),
          child: Consumer<DashboardProvider>(
            builder: (context, p, _) {
              // Detect load completion to trigger re-animations
              WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _handleLoadingTransition(p.loading));

              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader(p)),
                  SliverToBoxAdapter(child: _buildHeroSection(p)),
                  SliverToBoxAdapter(child: _buildTabSelector()),
                  SliverToBoxAdapter(child: _buildWeeklySection(p)),
                  SliverToBoxAdapter(child: _buildMetric4Grid(p)),
                  SliverToBoxAdapter(child: _buildNeuralObservation(p)),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: io.Platform.isIOS
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.red,
              onPressed: () => _showManualLogDialog(context),
              icon: const Icon(Icons.timer, color: Colors.white),
              label: const Text('Log Focus',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  void _showManualLogDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Log Focus Session', style: AppTextStyles.cardTitle),
        content: Text(
            'Manually log a 30-minute focus session for your tracking.',
            style: AppTextStyles.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text('Cancel', style: AppTextStyles.chipLabel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(c);
              final store = context.read<SQLiteStore>();
              final dashP = context.read<DashboardProvider>();
              final recoveryP = context.read<RecoveryProvider>();
              final logger = ManualSessionLogger(store: store);
              await logger.logFocusSession(30);
              if (mounted) {
                dashP.refresh();
                try {
                  recoveryP.load();
                } catch (_) {}
              }
            },
            child: Text('Log 30m',
                style:
                    AppTextStyles.chipLabel.copyWith(color: AppColors.good)),
          ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────────────

  Widget _buildHeader(DashboardProvider p) {
    return FadeTransition(
      opacity: _headerFade,
      child: SlideTransition(
        position: _headerSlide,
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(AppSpacing.lg, 14, AppSpacing.lg, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Builder(builder: (ctx) {
                        final dateStr = p.today?.date ?? 'XXXXXX';
                        final hash = dateStr.hashCode.abs() % 0xFFFF;
                        final idStr =
                            '0x${hash.toRadixString(16).toUpperCase().padLeft(4, '0')}_JD';
                        return Text('ID: $idStr',
                            style: AppTextStyles.chipLabel
                                .copyWith(color: AppColors.textMuted));
                      }),
                      const SizedBox(height: 3),
                      Row(children: [
                        // Pulsing live dot
                        _PulseDot(
                            color: p.lastSyncMinutesAgo < 20
                                ? AppColors.good
                                : AppColors.warn),
                        const SizedBox(width: 5),
                        Text('LIVE TELEMETRY',
                            style: AppTextStyles.chipLabel.copyWith(
                                color: p.lastSyncMinutesAgo < 20
                                    ? AppColors.good
                                    : AppColors.warn)),
                      ]),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Stack(children: [
                      const Icon(Icons.notifications_outlined,
                          color: AppColors.textSecondary),
                      if (p.isCritical)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.red),
                          ),
                        ),
                    ]),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.person_outline,
                        color: AppColors.textSecondary),
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // Morphism title block
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.textPrimary,
                    AppColors.textPrimary.withValues(alpha: 0.75),
                  ],
                ).createShader(bounds),
                child: Text(
                  'Daily Brain\nLoad',
                  style: AppTextStyles.display.copyWith(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    height: 1.12,
                    color: Colors.white, // ShaderMask overrides this
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Hero Section ──────────────────────────────────────────────────────────────────

  Widget _buildHeroSection(DashboardProvider p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 18, AppSpacing.lg, 0),
      child: p.loading
          ? const ShimmerList(count: 3, itemHeight: 84)
          : _buildMorphMetricGrid(p),
    );
  }

  Widget _buildMorphMetricGrid(DashboardProvider p) {
    // Stagger delays: each card enters 80ms after the previous
    return Column(
      children: [
        // Row 1: COG DEBT + SWITCHES
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: MorphMetricCard(
                  label: 'COG. DEBT',
                  value: p.cogDebtPct,
                  suffix: '%',
                  isCritical: p.isCritical,
                  chipLabel: p.isCritical ? 'CRITICAL' : null,
                  icon: Icons.psychology_outlined,
                  animationDelay: const Duration(milliseconds: 0),
                ),
              ),
              const SizedBox(width: AppSpacing.sectionGap),
              Expanded(
                child: MorphMetricCard(
                  label: 'SWITCHES',
                  value: p.totalSwitches.toDouble(),
                  suffix: '',
                  subText: p.isHighVolatility ? '⚠ High Volatility' : null,
                  glowColor: p.isHighVolatility
                      ? AppColors.warn
                      : AppColors.red,
                  animationDelay: const Duration(milliseconds: 80),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sectionGap),

        // Row 2: SCREEN TIME + PICKUPS
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: MorphMetricCard(
                  label: 'SCREEN TIME',
                  value: p.screenTime,
                  suffix: 'h',
                  decimals: 1,
                  deltaLabel: p.lastSyncMinutesAgo > 0
                      ? 'Sync: ${p.lastSyncMinutesAgo}m ago'
                      : null,
                  deltaType: p.screenTimeDelta > 0
                      ? DeltaType.negative
                      : DeltaType.positive,
                  animationDelay: const Duration(milliseconds: 160),
                ),
              ),
              const SizedBox(width: AppSpacing.sectionGap),
              Expanded(
                child: MorphMetricCard(
                  label: 'PICKUPS',
                  value: p.totalPickups.toDouble(),
                  suffix: '',
                  deltaLabel: p.pickupsDeltaLabel,
                  deltaType: p.isPickupsAboveAvg
                      ? DeltaType.negative
                      : DeltaType.positive,
                  animationDelay: const Duration(milliseconds: 240),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sectionGap),

        // Full-width COG DEBT PTS hero card
        _CogDebtHeroCard(
          p: p,
          animationDelay: const Duration(milliseconds: 320),
        ),
      ],
    );
  }

  // ── Tab Selector ─────────────────────────────────────────────────────────────────

  Widget _buildTabSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 22, AppSpacing.lg, 0),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.surfaceHigh,
              AppColors.surface,
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border, width: 0.6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: ['DAY', 'WEEK', 'MONTH'].asMap().entries.map((e) {
            final selected = e.key == _tabIndex;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _tabIndex = e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    gradient: selected
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
                          )
                        : null,
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: AppColors.red.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 220),
                      style: AppTextStyles.chipLabel.copyWith(
                        color:
                            selected ? Colors.white : AppColors.textMuted,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      child: Text(e.value),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Weekly/Chart Section ────────────────────────────────────────────────────────

  Widget _buildWeeklySection(DashboardProvider p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 18, AppSpacing.lg, 0),
      child: p.loading
          ? const ShimmerCard(height: 180)
          : RepaintBoundary(
              child: _ChartMorphCard(
                tabIndex: _tabIndex,
                p: p,
              ),
            ),
    );
  }

  // ── Metric4 Grid (secondary stats) ──────────────────────────────────────────────

  Widget _buildMetric4Grid(DashboardProvider p) {
    if (p.loading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(
            AppSpacing.lg, 18, AppSpacing.lg, 0),
        child: ShimmerList(count: 2, itemHeight: 70),
      );
    }
    final metrics = p.metric4;
    if (metrics == null || metrics.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding:
          const EdgeInsets.fromLTRB(AppSpacing.lg, 18, AppSpacing.lg, 0),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _SmallMorphCell(
                    label: metrics.isNotEmpty ? metrics[0].label : '',
                    value: metrics.isNotEmpty ? metrics[0].value : '',
                    delta: metrics.isNotEmpty ? metrics[0].delta : '',
                    dotColor:
                        metrics.isNotEmpty ? metrics[0].dotColor : null,
                    animationDelay:
                        const Duration(milliseconds: 0),
                  ),
                ),
                const SizedBox(width: AppSpacing.sectionGap),
                Expanded(
                  child: _SmallMorphCell(
                    label: metrics.length > 1 ? metrics[1].label : '',
                    value: metrics.length > 1 ? metrics[1].value : '',
                    delta: metrics.length > 1 ? metrics[1].delta : '',
                    dotColor:
                        metrics.length > 1 ? metrics[1].dotColor : null,
                    animationDelay:
                        const Duration(milliseconds: 80),
                  ),
                ),
              ],
            ),
          ),
          if (metrics.length > 2) ...[
            const SizedBox(height: AppSpacing.sectionGap),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _SmallMorphCell(
                      label: metrics[2].label,
                      value: metrics[2].value,
                      delta: metrics[2].delta,
                      dotColor: metrics[2].dotColor,
                      animationDelay:
                          const Duration(milliseconds: 160),
                    ),
                  ),
                  if (metrics.length > 3) ...[
                    const SizedBox(width: AppSpacing.sectionGap),
                    Expanded(
                      child: _SmallMorphCell(
                        label: metrics[3].label,
                        value: metrics[3].value,
                        delta: metrics[3].delta,
                        dotColor: metrics[3].dotColor,
                        animationDelay:
                            const Duration(milliseconds: 240),
                      ),
                    ),
                  ] else
                    const Expanded(child: SizedBox.shrink()),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Neural Observation ──────────────────────────────────────────────────────────────

  Widget _buildNeuralObservation(DashboardProvider p) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(AppSpacing.lg, 14, AppSpacing.lg, 0),
      child: p.loading
          ? const ShimmerCard(height: 110)
          : _AnimatedNeuralObs(p: p),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────────
// Sub-widgets (private)
// ────────────────────────────────────────────────────────────────────────────────

/// Full-width hero card for Cog Debt Points with animated ring.
class _CogDebtHeroCard extends StatefulWidget {
  const _CogDebtHeroCard(
      {required this.p, required this.animationDelay});
  final DashboardProvider p;
  final Duration animationDelay;

  @override
  State<_CogDebtHeroCard> createState() => _CogDebtHeroCardState();
}

class _CogDebtHeroCardState extends State<_CogDebtHeroCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final Animation<double> _sweep;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fade = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut));
    _slide = Tween<Offset>(
            begin: const Offset(0, 0.07), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.0, 0.65,
                curve: Curves.easeOutCubic)));
    _sweep = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.2, 1.0, curve: Curves.easeInOut));
    Future.delayed(widget.animationDelay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void didUpdateWidget(_CogDebtHeroCard old) {
    super.didUpdateWidget(old);
    if (old.p.cogDebtPts != widget.p.cogDebtPts ||
        old.p.cogDebtPct != widget.p.cogDebtPct) {
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: AnimatedBuilder(
            animation: _sweep,
            builder: (ctx, child) => CustomPaint(
              foregroundPainter: _HeroSweepPainter(progress: _sweep.value),
              child: child,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.borderRed.withValues(alpha: 0.6),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.red.withValues(alpha: 0.12),
                    blurRadius: 28,
                    offset: const Offset(0, 8),
                    spreadRadius: -4,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.surfaceHigh,
                    const Color(0xFF1A0A0A), // deep red tint
                    AppColors.surfaceDim,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.bolt,
                              size: 11, color: AppColors.red),
                          const SizedBox(width: 5),
                          const NtLabel('COG. DEBT PTS'),
                        ]),
                        const SizedBox(height: 8),
                        AnimatedMetricValue(
                          value: p.cogDebtPts,
                          suffix: '',
                          decimals: 0,
                          duration: const Duration(milliseconds: 1100),
                          style: AppTextStyles.metricValue.copyWith(
                            color: AppColors.red,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p.cogDebtDeltaLabel,
                          style: AppTextStyles.deltaLabel
                              .copyWith(color: AppColors.warn),
                        ),
                      ],
                    ),
                  ),
                  CogDebtRing(percent: p.cogDebtPct, size: 74),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wider sweep for the hero card (slightly brighter).
class _HeroSweepPainter extends CustomPainter {
  const _HeroSweepPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final sweepX = (progress * (size.width + 100)) - 50;
    final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(18));
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.09),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(sweepX - 40, 0, 80, size.height));
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(
        Rect.fromLTWH(sweepX - 40, 0, 80, size.height), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HeroSweepPainter old) => old.progress != progress;
}

/// Small secondary metric cell with morph styling + entry animation.
class _SmallMorphCell extends StatefulWidget {
  const _SmallMorphCell({
    required this.label,
    required this.value,
    required this.delta,
    this.dotColor,
    required this.animationDelay,
  });
  final String label;
  final String value;
  final String delta;
  final Color? dotColor;
  final Duration animationDelay;

  @override
  State<_SmallMorphCell> createState() => _SmallMorphCellState();
}

class _SmallMorphCellState extends State<_SmallMorphCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550));
    _fade = CurvedAnimation(
        parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
            begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(widget.animationDelay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void didUpdateWidget(_SmallMorphCell old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _ctrl
        ..reset()
        ..forward();
    }
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
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border, width: 0.7),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                  spreadRadius: -3,
                ),
              ],
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.surfaceHigh, AppColors.surfaceDim],
                stops: [0.0, 1.0],
              ),
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NtLabel(widget.label),
                    const SizedBox(height: 6),
                    Text(widget.value,
                        style: AppTextStyles.metricValue
                            .copyWith(fontSize: 20)),
                    const SizedBox(height: 2),
                    Text(widget.delta,
                        style: AppTextStyles.deltaLabel),
                  ],
                ),
                if (widget.dotColor != null)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.dotColor,
                        boxShadow: [
                          BoxShadow(
                            color: widget.dotColor!
                                .withValues(alpha: 0.5),
                            blurRadius: 6,
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
    );
  }
}

/// Chart wrapped in a morph card with animated entry.
class _ChartMorphCard extends StatefulWidget {
  const _ChartMorphCard({required this.tabIndex, required this.p});
  final int tabIndex;
  final DashboardProvider p;

  @override
  State<_ChartMorphCard> createState() => _ChartMorphCardState();
}

class _ChartMorphCardState extends State<_ChartMorphCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
            begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_ChartMorphCard old) {
    super.didUpdateWidget(old);
    // Re-animate when tab changes or data refreshes
    if (old.tabIndex != widget.tabIndex ||
        old.p.weeklyLoadValues != widget.p.weeklyLoadValues) {
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 0.7),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 7),
                  spreadRadius: -4,
                ),
                BoxShadow(
                  color: AppColors.red.withValues(alpha: 0.04),
                  blurRadius: 20,
                ),
              ],
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.surfaceHigh,
                  AppColors.surface,
                  AppColors.surfaceDim,
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const NtLabel('BIOMETRIC TELEMETRY'),
                const SizedBox(height: 4),
                Row(children: [
                  Text('Weekly Pattern',
                      style: AppTextStyles.sectionHead),
                  const Spacer(),
                  if (p.weeklyLoadValues.isNotEmpty)
                    Row(children: [
                      Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.red)),
                      const SizedBox(width: 4),
                      Text(
                        '${p.cogDebtPct.toStringAsFixed(0)}% Cog. Debt',
                        style: AppTextStyles.chipLabel.copyWith(
                            color: AppColors.red),
                      ),
                    ]),
                ]),
                const SizedBox(height: 14),
                _buildTabChart(p),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabChart(DashboardProvider p) {
    return switch (widget.tabIndex) {
      0 => p.hourlyLoadValues.isEmpty
          ? _emptyChart()
          : _HourlyBarChart(values: p.hourlyLoadValues),
      1 => p.weeklyLoadValues.isEmpty
          ? _emptyChart()
          : _WeeklyChart(
              values: p.weeklyLoadValues, peak: p.weeklyPeak),
      2 => p.monthlyLoadValues.isEmpty
          ? _emptyChart()
          : _WeeklyChart(
              values: p.monthlyLoadValues,
              peak: p.monthlyPeak),
      _ => _emptyChart(),
    };
  }

  Widget _emptyChart() => SizedBox(
        height: 120,
        child: Center(
            child: Text('No data yet',
                style: AppTextStyles.body)),
      );
}

/// Neural Observation card with animated fade-in on every refresh.
class _AnimatedNeuralObs extends StatefulWidget {
  const _AnimatedNeuralObs({required this.p});
  final DashboardProvider p;

  @override
  State<_AnimatedNeuralObs> createState() => _AnimatedNeuralObsState();
}

class _AnimatedNeuralObsState extends State<_AnimatedNeuralObs>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    Future.delayed(const Duration(milliseconds: 420), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void didUpdateWidget(_AnimatedNeuralObs old) {
    super.didUpdateWidget(old);
    if (old.p.neuralObservation != widget.p.neuralObservation) {
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    return FadeTransition(
      opacity: _fade,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: p.isCritical
                ? AppColors.borderRed.withValues(alpha: 0.7)
                : AppColors.border,
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 5),
              spreadRadius: -3,
            ),
            if (p.isCritical)
              BoxShadow(
                color: AppColors.red.withValues(alpha: 0.06),
                blurRadius: 20,
              ),
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.surfaceHigh,
              p.isCritical
                  ? const Color(0xFF160808)
                  : AppColors.surface,
              AppColors.surfaceDim,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.biotech, size: 13, color: AppColors.red),
              const SizedBox(width: 6),
              const NtLabel('NEURAL OBSERVATION'),
            ]),
            const SizedBox(height: 10),
            Text(p.neuralObservation, style: AppTextStyles.body),
            const SizedBox(height: 8),
            Text('Ref ID: ${p.neuralObservationRefId}',
                style: AppTextStyles.chipLabel
                    .copyWith(color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

/// Pulsing live indicator dot — subtle scale pulse, no jank.
class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color});
  final Color color;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, __) => Transform.scale(
          scale: _scale.value,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.6),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Chart widgets (unchanged logic, kept local) ──────────────────────────────────

class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.values, required this.peak});
  final List<double> values;
  final double peak;

  @override
  Widget build(BuildContext context) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final spots = values
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();
    return SizedBox(
      height: 120,
      child: LineChart(
        LineChartData(
          backgroundColor: Colors.transparent,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (val, _) {
                  final i = val.toInt();
                  if (i < 0 || i >= days.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(days[i],
                        style: AppTextStyles.chipLabel
                            .copyWith(fontSize: 9)),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          minY: 0,
          maxY: 100,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: AppColors.red,
              barWidth: 2,
              dotData: FlDotData(
                getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                  radius: spot.y >= peak ? 5 : 0,
                  color: AppColors.red,
                  strokeColor:
                      AppColors.red.withValues(alpha: 0.3),
                  strokeWidth: 8,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppColors.redGlow,
                    AppColors.redGlow.withValues(alpha: 0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HourlyBarChart extends StatelessWidget {
  const _HourlyBarChart({required this.values});
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
            child: Text('No data today', style: AppTextStyles.body)),
      );
    }
    final groups = values.asMap().entries.map((e) {
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: e.value,
            color: AppColors.chartGray,
            width: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      );
    }).toList();
    return SizedBox(
      height: 120,
      child: BarChart(
        BarChartData(
          backgroundColor: Colors.transparent,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (val, _) {
                  final h = val.toInt();
                  if (h % 6 != 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                        '${h.toString().padLeft(2, '0')}:00',
                        style: AppTextStyles.chipLabel
                            .copyWith(fontSize: 9)),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          maxY: 100,
          barGroups: groups,
        ),
      ),
    );
  }
}
