/// Recovery screen — Pentagon radar, countdown timer, efficiency log, debt arc, breaks.
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
  // FUNC-08 FIX: Same as AnalyticsScreen — replace initState with
  // didChangeDependencies so RecoveryProvider.load() re-fires on every
  // tab re-visit, not just the first insert.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<RecoveryProvider>().load();
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
            SliverToBoxAdapter(child: _buildRadar(p)),
            SliverToBoxAdapter(child: _buildCountdown(p)),
            SliverToBoxAdapter(child: _buildEfficiencyLog(p)),
            SliverToBoxAdapter(child: _buildDebtArc(p)),
            SliverToBoxAdapter(child: _buildBreakQuality(p)),
            SliverToBoxAdapter(child: _buildTomorrowReadiness(p)),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
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
              Text('COGNITRACK',
                  style: AppTextStyles.display.copyWith(fontSize: 14)),
              const Spacer(),
              Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.notifications_outlined,
                      color: AppColors.textSecondary),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: AppColors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints:
                          const BoxConstraints(minWidth: 12, minHeight: 12),
                      child: const Text('14',
                          style: TextStyle(color: Colors.white, fontSize: 8),
                          textAlign: TextAlign.center),
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
            Text('Recovery Plan',
                style: AppTextStyles.display
                    .copyWith(fontWeight: FontWeight.w800)),
            const Spacer(),
            const NtChip('DOPAMINE', outlined: true),
          ]),
        ]),
      );

  // ── Pentagon radar ────────────────────────────────────────────────────────

  Widget _buildRadar(RecoveryProvider p) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 16, AppSpacing.lg, 0),
        child: NtCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const NtLabel('NEURAL PROFILE'),
            const SizedBox(height: AppSpacing.xs),
            const Text('Cognitive Radar',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.md),
            if (p.loading)
              const ShimmerCard(height: 220)
            else
              SizedBox(
                height: 220,
                child: CustomPaint(
                  painter: _RadarPentagonPainter(values: p.radarValues),
                  size: const Size(double.infinity, 220),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            // Legend row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                'FOCUS',
                'RECOVERY',
                'WM STRAIN',
                'SLEEP',
                'DOPAMINE',
              ]
                  .asMap()
                  .entries
                  .map((e) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(e.value,
                            style:
                                AppTextStyles.chipLabel.copyWith(fontSize: 8)),
                      ))
                  .toList(),
            ),
          ]),
        ),
      );

  // ── Neural Load Countdown ─────────────────────────────────────────────────

  Widget _buildCountdown(RecoveryProvider p) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 12, AppSpacing.lg, 0),
        child: NtCard(
          redBorder: true,
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
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 12, AppSpacing.lg, 0),
        child: NtCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('HOURLY LOAD INDEX · 7-DAY PATTERN',
                style: AppTextStyles.chipLabel),
            const SizedBox(height: AppSpacing.xs),
            Text('Efficiency Log', style: AppTextStyles.sectionHead),
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
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 12, AppSpacing.lg, 0),
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
            else
              RepaintBoundary(
                child: _DebtArcChart(
                  points: p.debtArcPoints,
                  peakHour: p.debtArcPeakHour,
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Net debt cleared today: −${p.netDebtCleared.abs().toStringAsFixed(0)}pts',
              style: AppTextStyles.body.copyWith(color: AppColors.good),
            ),
          ]),
        ),
      );

  // ── Break Quality Report ──────────────────────────────────────────────────

  Widget _buildBreakQuality(RecoveryProvider p) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 12, AppSpacing.lg, 0),
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
                                if (entry.recoveryDeltaPts < 0)
                                  const Icon(Icons.warning_amber,
                                      size: 12, color: AppColors.warn),
                                if (entry.recoveryDeltaPts < 0)
                                  const SizedBox(width: 4),
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
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 12, AppSpacing.lg, 0),
        child: NtCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const NtLabel("TOMORROW'S READINESS"),
            const SizedBox(height: AppSpacing.xs),
            Row(children: [
              Text('Projected Baseline', style: AppTextStyles.body),
              const Spacer(),
              Text('EST.',
                  style: AppTextStyles.chipLabel
                      .copyWith(color: AppColors.textMuted)),
            ]),
            const SizedBox(height: AppSpacing.sm),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(
                p.tomorrowReadiness.toStringAsFixed(0),
                style: AppTextStyles.display
                    .copyWith(fontSize: 52, color: AppColors.warn),
              ),
              Text('%',
                  style: AppTextStyles.display
                      .copyWith(fontSize: 28, color: AppColors.warn)),
            ]),
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
            _readinessRow(Icons.warning_outlined, AppColors.warn,
                'Cross-device load', p.crossDeviceLoadLabel),
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

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.36;

    final gridPaint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Concentric pentagons (background grid)
    for (final r in [0.33, 0.66, 1.0]) {
      _drawPentagon(canvas, center, radius * r, gridPaint);
    }

    // Axis lines
    final axisPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 0.5;
    for (int i = 0; i < 5; i++) {
      final angle = -pi / 2 + (2 * pi / 5) * i;
      canvas.drawLine(
        center,
        Offset(
            center.dx + radius * cos(angle), center.dy + radius * sin(angle)),
        axisPaint,
      );
    }

    // Data polygon
    final safeValues = values.length >= 5
        ? values.take(5).toList()
        : [...values, ...List.filled(5 - values.length, 0.3)];

    final path = Path();
    for (int i = 0; i < 5; i++) {
      final angle = -pi / 2 + (2 * pi / 5) * i;
      final r = radius * safeValues[i].clamp(0.05, 1.0);
      final pt = Offset(center.dx + r * cos(angle), center.dy + r * sin(angle));
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();

    canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.redGlow
          ..style = PaintingStyle.fill);
    canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.red
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);

    // Vertex dots
    for (int i = 0; i < 5; i++) {
      final angle = -pi / 2 + (2 * pi / 5) * i;
      final r = radius * safeValues[i].clamp(0.05, 1.0);
      canvas.drawCircle(
        Offset(center.dx + r * cos(angle), center.dy + r * sin(angle)),
        4,
        Paint()..color = Colors.white,
      );
    }

    // Axis labels
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < 5; i++) {
      final angle = -pi / 2 + (2 * pi / 5) * i;
      final labelR = radius * 1.22;
      final lx = center.dx + labelR * cos(angle);
      final ly = center.dy + labelR * sin(angle);
      tp.text = TextSpan(
        text: labels[i],
        style: AppTextStyles.chipLabel.copyWith(fontSize: 8),
      );
      tp.layout();
      tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));
    }
  }

  void _drawPentagon(Canvas c, Offset center, double r, Paint p) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final angle = -pi / 2 + (2 * pi / 5) * i;
      final pt = Offset(center.dx + r * cos(angle), center.dy + r * sin(angle));
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    c.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_RadarPentagonPainter old) => old.values != values;
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderRed, width: 1),
      ),
      child: Center(
        child: Text('[$h:$m:$s]', style: AppTextStyles.countdown),
      ),
    );
  }
}

// ── Efficiency Log Line Chart ─────────────────────────────────────────────────

class _EfficiencyChart extends StatelessWidget {
  const _EfficiencyChart({required this.values, required this.labels});

  final List<double> values;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return SizedBox(
        height: 130,
        child: Center(child: Text('No data yet', style: AppTextStyles.body)),
      );
    }
    final spots = values
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    return SizedBox(
      height: 130,
      child: LineChart(LineChartData(
        backgroundColor: Colors.transparent,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: 100,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (val, _) {
                final i = val.toInt();
                if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(labels[i],
                      style: AppTextStyles.chipLabel.copyWith(fontSize: 8)),
                );
              },
            ),
          ),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: AppColors.red,
            barWidth: 1.5,
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
        extraLinesData: ExtraLinesData(verticalLines: [
          VerticalLine(
            x: peakHour.toDouble(),
            color: AppColors.red.withValues(alpha: 0.7),
            strokeWidth: 1,
            dashArray: [4, 4],
            label: VerticalLineLabel(
              show: true,
              alignment: Alignment.topRight,
              labelResolver: (_) => 'Context Switch Peak',
              style: AppTextStyles.chipLabel
                  .copyWith(color: AppColors.red, fontSize: 8),
            ),
          ),
          VerticalLine(
            x: (peakHour + 2).toDouble(),
            color: AppColors.good.withValues(alpha: 0.7),
            strokeWidth: 1,
            dashArray: [4, 4],
            label: VerticalLineLabel(
              show: true,
              alignment: Alignment.topRight,
              labelResolver: (_) => 'Neural Reset Detected',
              style: AppTextStyles.chipLabel
                  .copyWith(color: AppColors.good, fontSize: 8),
            ),
          ),
          VerticalLine(
            x: (peakHour + 5).toDouble(),
            color: AppColors.warn.withValues(alpha: 0.7),
            strokeWidth: 1,
            dashArray: [4, 4],
            label: VerticalLineLabel(
              show: true,
              alignment: Alignment.topRight,
              labelResolver: (_) => 'Break 3 — Phone opened — No recovery',
              style: AppTextStyles.chipLabel
                  .copyWith(color: AppColors.warn, fontSize: 8),
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
