/// Recovery screen — Pentagon radar, countdown timer, efficiency log, debt arc, breaks.
// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, curly_braces_in_flow_control_structures
library;

import 'dart:async';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/nt_card.dart';
import '../../widgets/nt_chip.dart';
import '../../widgets/nt_label.dart';
import '../../widgets/shimmer_card.dart';
import '../../../core/providers/recovery_provider.dart';

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key});

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  bool _loaded = false;

  // Load exactly once. didChangeDependencies fired on every ancestor rebuild
  // → load() → loading=true → shimmer → content flash every rebuild cycle.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_loaded) {
        _loaded = true;
        context.read<RecoveryProvider>().load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<RecoveryProvider>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(p)),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverToBoxAdapter(child: _buildRadar(p)),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(child: _buildCountdown(p)),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(child: _buildEfficiencyLog(p)),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(child: _buildDebtArc(p)),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(child: _buildBreakQuality(p)),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(child: _buildTomorrowReadiness(p)),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(RecoveryProvider p) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 12, AppSpacing.lg, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              Text('COGNITRACK', style: AppTextStyles.labelSm),
              const Spacer(),
              Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.notifications_outlined,
                      color: AppColors.textSecondary),
                  // H03 FIX: badge was always-visible; now conditional on state.
                  if (p.hasNewAlerts)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const NtLabel('PROTOCOL MODULE'),
          const SizedBox(height: AppSpacing.xs),
          Row(children: [
            Text('Recovery Plan', style: AppTextStyles.sectionHeadBold),
            const Spacer(),
            const NtChip('DOPAMINE', outlined: true),
          ]),
        ]),
      );

  // ── Pentagon radar ────────────────────────────────────────────────────────

  Widget _buildRadar(RecoveryProvider p) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: NtCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const NtLabel('NEURAL PROFILE'),
              const Spacer(),
              const Icon(Icons.radar, size: 14, color: AppColors.red),
            ]),
            const SizedBox(height: AppSpacing.xs),
            const Text('Cognitive Radar',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.md),
            if (p.loading)
              const ShimmerCard(height: 260)
            else
              // LayoutBuilder gives us the real rendered width so the painter
              // can derive radius from min(w,h) instead of assuming a square.
              RepaintBoundary(
                child: LayoutBuilder(
                  builder: (_, constraints) {
                    final side = constraints.maxWidth.clamp(0.0, 300.0);
                    return Center(
                      child: SizedBox(
                        width: side,
                        height: side,
                        child: CustomPaint(
                          painter: _RadarPentagonPainter(values: p.radarValues),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ]),
        ),
      );

  // ── Neural Load Countdown ─────────────────────────────────────────────────

  Widget _buildCountdown(RecoveryProvider p) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: NtCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const NtLabel('NEURAL LOAD'),
              const Spacer(),
              const Icon(Icons.psychology, size: 16, color: AppColors.red),
            ]),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Core prefrontal cortex strain is currently high. '
              'Dopamine baseline reset suggested in:',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.md),
            if (p.loading)
              const ShimmerCard(height: 60)
            else
              _CountdownTimer(duration: p.timeToReset),
            const SizedBox(height: AppSpacing.sm),
            Row(children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: AppColors.good)),
              const SizedBox(width: 4),
              Text('Live Synced', style: AppTextStyles.deltaLabel),
              const Spacer(),
              Text(
                'Critical Threshold ${(p.today?.cognitiveLoadPct ?? 0).toStringAsFixed(0)}%',
                style: AppTextStyles.deltaLabel,
              ),
            ]),
          ]),
        ),
      );

  // ── Efficiency Log 7-day chart ────────────────────────────────────────────

  Widget _buildEfficiencyLog(RecoveryProvider p) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: NtCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('HOURLY LOAD INDEX · 7-DAY PATTERN',
                        style: AppTextStyles.chipLabel),
                    const SizedBox(height: AppSpacing.xs),
                    Text('Efficiency Log', style: AppTextStyles.sectionHead),
                  ],
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withValues(alpha: 0.08),
                    border: Border.all(
                      color: const Color(0xFFF97316).withValues(alpha: 0.21),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(AppSpacing.cardRFull),
                  ),
                  child: Text(
                    '${p.breaksAccepted} BREAKS ACCEPTED',
                    style: AppTextStyles.chipLabel.copyWith(
                      color: const Color(0xFFF97316),
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (p.loading)
              const ShimmerCard(height: 130)
            else
              RepaintBoundary(
                child: _EfficiencyChart(
                  values: p.efficiencyLog7Day,
                  labels: p.efficiencyLog7DayLabels,
                ),
              ),
          ]),
        ),
      );

  // ── Cognitive Debt Arc ────────────────────────────────────────────────────

  Widget _buildDebtArc(RecoveryProvider p) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: NtCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const NtLabel('DEBT ANALYSIS'),
            const SizedBox(height: AppSpacing.xs),
            Text('Cognitive Debt Arc — Today',
                style: AppTextStyles.sectionHead),
            const SizedBox(height: AppSpacing.md),
            if (p.loading)
              const ShimmerCard(height: 140)
            // Guard: if no data yet, show a clean empty state instead of
            // rendering vertical lines at hours that exceed maxX and crashing
            // fl_chart's assertion (x value outside minX/maxX bounds).
            else if (p.debtArcPoints.every((v) => v == 0))
              SizedBox(
                height: 140,
                child: Center(
                  child: Text('No load data recorded yet',
                      style: AppTextStyles.body),
                ),
              )
            else
              RepaintBoundary(
                child: _DebtArcChart(
                  points: p.debtArcPoints,
                  peakHour: p.debtArcPeakHour,
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            // M3 FIX: hide when there is no history to compute a delta from,
            // or when the delta is zero (no change / first day of data).
            if (p.netDebtCleared.abs() >= 1)
              Text(
                'Net debt cleared today: −${p.netDebtCleared.abs().toStringAsFixed(0)}pts',
                style: AppTextStyles.body.copyWith(color: AppColors.good),
              ),
          ]),
        ),
      );

  // ── Break Quality Report ──────────────────────────────────────────────────

  Widget _buildBreakQuality(RecoveryProvider p) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: NtCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const NtLabel('RECOVERY EVENTS'),
            const SizedBox(height: AppSpacing.xs),
            Text('Break Quality Report', style: AppTextStyles.sectionHead),
            const SizedBox(height: AppSpacing.md),
            if (p.loading)
              const ShimmerList(count: 2, itemHeight: 60)
            else if (p.breakQualityReport.isEmpty)
              SizedBox(
                height: 60,
                child: Center(
                  child: Text('No breaks detected today',
                      style: AppTextStyles.body),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: p.breakQualityReport.length,
                separatorBuilder: (_, __) => const Divider(
                    color: AppColors.border, height: 1, thickness: 0.5),
                itemBuilder: (_, i) {
                  final entry = p.breakQualityReport[i];
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Row(children: [
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.time, style: AppTextStyles.chipLabel),
                            const SizedBox(height: 2),
                            Text(entry.breakType,
                                style: AppTextStyles.cardTitle),
                          ]),
                      const Spacer(),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (entry.recoveryDeltaPts < 0) ...[
                                  const Icon(Icons.warning_amber,
                                      size: 12, color: AppColors.warn),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  'Recovery: ${entry.recoveryDeltaPts.toStringAsFixed(0)}pts',
                                  style: AppTextStyles.deltaLabel.copyWith(
                                      color: entry.recoveryDeltaPts < 0
                                          ? AppColors.warn
                                          : AppColors.good),
                                ),
                              ],
                            ),
                            Text(
                              '${entry.beforePct.toStringAsFixed(0)}% → '
                              '${entry.afterPct.toStringAsFixed(0)}%',
                              style: AppTextStyles.chipLabel,
                            ),
                            Row(children: [
                              SizedBox(
                                width: 60,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: entry.effectivePct.clamp(0.0, 1.0),
                                    backgroundColor: AppColors.chartGray,
                                    valueColor: const AlwaysStoppedAnimation(
                                        AppColors.red),
                                    minHeight: 3,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${(entry.effectivePct * 100).toStringAsFixed(0)}% Eff.',
                                style: AppTextStyles.chipLabel
                                    .copyWith(fontSize: 9),
                              ),
                            ]),
                          ]),
                    ]),
                  );
                },
              ),
          ]),
        ),
      );

  // ── Tomorrow's Readiness ──────────────────────────────────────────────────

  Widget _buildTomorrowReadiness(RecoveryProvider p) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: NtCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const NtLabel("TOMORROW'S READINESS"),
            const SizedBox(height: AppSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // existing number column stays here
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Projected Baseline', style: AppTextStyles.body),
                  const SizedBox(height: AppSpacing.xs),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(p.tomorrowReadiness.toStringAsFixed(0),
                        style: AppTextStyles.sectionHeadBold.copyWith(
                            fontSize: 60, color: AppColors.textPrimary)),
                    Text('%',
                        style: AppTextStyles.display
                            .copyWith(fontSize: 24, color: AppColors.red)),
                  ]),
                ]),
                const Spacer(),
                // ← THIS IS THE MISSING PART
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10), width: 1),
                    color: Colors.black.withValues(alpha: 0.4),
                  ),
                  child: const Icon(Icons.calendar_today_outlined,
                      size: 22, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _readinessRow(Icons.check_circle_outline, AppColors.good,
                'Sleep quality projected', '7h 10m (EST.)'),
            const SizedBox(height: 6),
            _readinessRow(
                Icons.error_outline,
                AppColors.red,
                'Uncleared debt tonight',
                '${p.unclearedDebt.toStringAsFixed(0)}pts'),
            const SizedBox(height: 6),
            // Cross-device load row
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(children: [
                const Icon(Icons.device_hub,
                    size: 16, color: Color(0xFFF97316)),
                const SizedBox(width: AppSpacing.sm),
                Text('Cross-device load', style: AppTextStyles.body),
                const Spacer(),
                Text('${p.crossDeviceEvents} events  +${p.crossDevicePts} pts',
                    style: AppTextStyles.body.copyWith(
                      color: const Color(0xFFF97316),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    )),
              ]),
            ),
            const SizedBox(height: 6),
            _readinessRow(Icons.check_circle_outline, AppColors.good,
                'Circadian alignment', 'Good (EST.)'),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surfaceDim,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(p.readinessConclusion, style: AppTextStyles.body),
            ),
          ]),
        ),
      );

  Widget _readinessRow(
          IconData icon, Color color, String label, String value) =>
      Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(label, style: AppTextStyles.body),
        const Spacer(),
        Text(value, style: AppTextStyles.cardTitle),
      ]);
}

// ── Pentagon Radar Painter ────────────────────────────────────────────────────

class _RadarPentagonPainter extends CustomPainter {
  _RadarPentagonPainter({required this.values});

  final List<double> values; // 5 values [0.0–1.0]
  static const labels = ['FOCUS', 'RECOVERY', 'WM STRAIN', 'SLEEP', 'DOPAMINE'];

  // Approx max label width in pixels at 9px font — used to shrink radius so
  // labels never paint outside the canvas bounds.
  static const _labelPad = 36.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Use the smaller dimension minus label padding so labels always fit.
    final maxR = (size.shortestSide / 2) - _labelPad;
    final radius = maxR.clamp(40.0, 120.0);

    final gridPaint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // Concentric pentagons (background grid)
    for (final r in [0.33, 0.66, 1.0]) {
      _drawPentagon(canvas, center, radius * r, gridPaint);
    }

    // Axis lines from center to each vertex
    final axisPaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.6)
      ..strokeWidth = 0.8;
    for (int i = 0; i < 5; i++) {
      final angle = -pi / 2 + (2 * pi / 5) * i;
      canvas.drawLine(
        center,
        Offset(
            center.dx + radius * cos(angle), center.dy + radius * sin(angle)),
        axisPaint,
      );
    }

    // Pad values to 5 entries
    final safeValues = values.length >= 5
        ? values.take(5).toList()
        : [...values, ...List.filled(5 - values.length, 0.3)];

    // Data polygon
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final angle = -pi / 2 + (2 * pi / 5) * i;
      final r = radius * safeValues[i].clamp(0.05, 1.0);
      final pt = Offset(center.dx + r * cos(angle), center.dy + r * sin(angle));
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.redGlow.withValues(alpha: 0.22)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Vertex dots
    for (int i = 0; i < 5; i++) {
      final angle = -pi / 2 + (2 * pi / 5) * i;
      final r = radius * safeValues[i].clamp(0.05, 1.0);
      canvas.drawCircle(
        Offset(center.dx + r * cos(angle), center.dy + r * sin(angle)),
        3.5,
        Paint()..color = Colors.white,
      );
    }

    // Axis labels — placed at labelR = radius + fixed gap so they are always
    // outside the outermost pentagon ring and inside the canvas bounds.
    final tp = TextPainter(textDirection: TextDirection.ltr);
    const labelStyle = TextStyle(
      color: AppColors.textSecondary,
      fontSize: 9,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    );
    for (int i = 0; i < 5; i++) {
      final angle = -pi / 2 + (2 * pi / 5) * i;
      // Fixed 18px gap beyond the outer pentagon edge
      final labelR = radius + 18.0;
      final lx = center.dx + labelR * cos(angle);
      final ly = center.dy + labelR * sin(angle);
      tp.text = TextSpan(text: labels[i], style: labelStyle);
      tp.layout(maxWidth: _labelPad * 2);
      // Clamp so text never paints outside canvas
      final px = (lx - tp.width / 2).clamp(0.0, size.width - tp.width);
      final py = (ly - tp.height / 2).clamp(0.0, size.height - tp.height);
      tp.paint(canvas, Offset(px, py));
    }
  }

  void _drawPentagon(Canvas c, Offset center, double r, Paint p) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final angle = -pi / 2 + (2 * pi / 5) * i;
      final pt = Offset(center.dx + r * cos(angle), center.dy + r * sin(angle));
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    c.drawPath(path, p);
  }

  @override
  // Compare list contents not reference — old != values is always true for lists
  bool shouldRepaint(_RadarPentagonPainter old) {
    if (old.values.length != values.length) return true;
    for (int i = 0; i < values.length; i++) {
      if (old.values[i] != values[i]) return true;
    }
    return false;
  }
}

// ── Countdown Timer ────────────────────────────────────────────────────────────

class _CountdownTimer extends StatefulWidget {
  const _CountdownTimer({required this.duration});

  final Duration duration;

  @override
  State<_CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<_CountdownTimer> {
  late Duration _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.duration;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining.inSeconds > 0) {
        setState(() => _remaining -= const Duration(seconds: 1));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = _remaining.inHours.toString().padLeft(2, '0');
    final m = (_remaining.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    // RepaintBoundary isolates the 1-second tick repaints to this widget only.
    // Without it, every setState call here walks up to the nearest
    // RenderObject boundary and repaints the entire NtCard including the
    // radar CustomPaint and efficiency line chart, causing visible flicker.
    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: AppColors.borderRed.withValues(alpha: 0.30), width: 1),
        ),
        child: Center(
          child: Text('[$h:$m:$s]', style: AppTextStyles.countdown),
        ),
      ),
    );
  }
}

// ── Efficiency Log Bar Chart ──────────────────────────────────────────────────
// Uses BarChart instead of LineChart because:
//   1. BarChart renders correctly with 0–7 data points (LineChart throws a
//      render assertion when spots.length < 2).
//   2. Bar widths scale naturally to the available width — no label overlap.
//   3. Each bar shows a date label below without reservedSize fighting.

class _EfficiencyChart extends StatelessWidget {
  const _EfficiencyChart({required this.values, required this.labels});

  final List<double> values;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return SizedBox(
        height: 160,
        child: Center(child: Text('No data yet', style: AppTextStyles.body)),
      );
    }

    final barGroups = values.asMap().entries.map((e) {
      final pct = e.value.clamp(0.0, 100.0);
      // Color: green < 40, amber 40-70, red > 70
      final barColor = pct < 40
          ? AppColors.good
          : pct < 70
              ? AppColors.warn
              : AppColors.red;
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: pct,
            color: barColor,
            width: 18,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: 100,
              color: AppColors.surfaceHigh,
            ),
          ),
        ],
      );
    }).toList();

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          backgroundColor: Colors.transparent,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          maxY: 100,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.surface,
              getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                  BarTooltipItem(
                '${rod.toY.toStringAsFixed(0)}%',
                AppTextStyles.chipLabel.copyWith(color: AppColors.textPrimary),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (val, meta) {
                  final i = val.toInt();
                  if (i < 0 || i >= labels.length)
                    return const SizedBox.shrink();
                  // Show short label: 'Apr\n28' split to two lines to avoid overlap
                  final parts = labels[i].split(' ');
                  return SideTitleWidget(
                    axisSide: AxisSide.bottom,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          parts.isNotEmpty ? parts[0] : labels[i],
                          style: AppTextStyles.chipLabel.copyWith(fontSize: 7),
                        ),
                        if (parts.length > 1)
                          Text(
                            parts[1],
                            style:
                                AppTextStyles.chipLabel.copyWith(fontSize: 7),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (val, meta) {
                  if (val == 0 || val == 50 || val == 100) {
                    return SideTitleWidget(
                      axisSide: AxisSide.left,
                      child: Text(
                        '${val.toInt()}',
                        style: AppTextStyles.chipLabel.copyWith(fontSize: 8),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          barGroups: barGroups,
          alignment: BarChartAlignment.spaceAround,
        ),
      ),
    );
  }
}

// ── Debt Arc Line Chart ───────────────────────────────────────────────────────

class _DebtArcChart extends StatelessWidget {
  const _DebtArcChart({required this.points, required this.peakHour});

  final List<double> points;
  final int peakHour;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(
        height: 140,
        child: Center(child: Text('No data yet', style: AppTextStyles.body)),
      );
    }
    final spots = points
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    return SizedBox(
      height: 140,
      child: LineChart(LineChartData(
        backgroundColor: Colors.transparent,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 23,
        minY: 0,
        maxY: 100,
        // Vertical marker lines: short labels only — long strings cause overflow
        extraLinesData: ExtraLinesData(verticalLines: [
          VerticalLine(
            x: peakHour.toDouble().clamp(0, 22),
            color: AppColors.red.withValues(alpha: 0.7),
            strokeWidth: 1,
            dashArray: [4, 4],
            label: VerticalLineLabel(
              show: true,
              // topLeft avoids right-edge overflow on late-day peak hours
              alignment: Alignment.topLeft,
              labelResolver: (_) => 'PEAK',
              style: AppTextStyles.chipLabel
                  .copyWith(color: AppColors.red, fontSize: 7),
            ),
          ),
          // Only render RESET/BRK lines if they fit within the 0-23 range
          if ((peakHour + 2) <= 23)
            VerticalLine(
              x: (peakHour + 2).toDouble(),
              color: AppColors.good.withValues(alpha: 0.7),
              strokeWidth: 1,
              dashArray: [4, 4],
              label: VerticalLineLabel(
                show: true,
                alignment: Alignment.topLeft,
                labelResolver: (_) => 'RST',
                style: AppTextStyles.chipLabel
                    .copyWith(color: AppColors.good, fontSize: 7),
              ),
            ),
          if ((peakHour + 5) <= 23)
            VerticalLine(
              x: (peakHour + 5).toDouble(),
              color: AppColors.warn.withValues(alpha: 0.7),
              strokeWidth: 1,
              dashArray: [4, 4],
              label: VerticalLineLabel(
                show: true,
                alignment: Alignment.topLeft,
                labelResolver: (_) => 'BRK',
                style: AppTextStyles.chipLabel
                    .copyWith(color: AppColors.warn, fontSize: 7),
              ),
            ),
        ]),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (val, _) {
                if (val % 25 != 0) return const SizedBox.shrink();
                return Text('${val.toInt()}',
                    style: AppTextStyles.chipLabel.copyWith(fontSize: 8));
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 20,
              getTitlesWidget: (val, _) {
                final h = val.toInt();
                if (h % 6 != 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${h.toString().padLeft(2, "0")}:00',
                      style: AppTextStyles.chipLabel.copyWith(fontSize: 8)),
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.2,
            color: AppColors.red,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppColors.redGlow,
                  AppColors.redGlow.withValues(alpha: 0)
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          )
        ],
      )),
    );
  }
}
