/// Analytics screen — Switch Velocity, Temporal Heatmap, Brain Load, Recovery Coefficient.
library;

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
import '../../widgets/wm_strain_bar.dart';
import '../../../core/providers/analytics_provider.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AnalyticsProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AnalyticsProvider>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildVelocitySection(p)),
            SliverToBoxAdapter(child: _buildHeatmap(p)),
            SliverToBoxAdapter(child: _buildBrainLoad(p)),
            SliverToBoxAdapter(child: _buildRecoveryCoeff(p)),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 12, AppSpacing.lg, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ANALYTICS',
                style: AppTextStyles.display
                    .copyWith(fontWeight: FontWeight.w800, fontSize: 30)),
            const SizedBox(height: 4),
            Text('SENSOR-ID: AS-40 · GATEWAY: 12MS',
                style: AppTextStyles.chipLabel
                    .copyWith(color: AppColors.textMuted)),
          ],
        ),
      );

  // ── Switch Velocity bar chart ──────────────────────────────────────────────

  Widget _buildVelocitySection(AnalyticsProvider p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 20, AppSpacing.lg, 0),
      child: NtCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const NtLabel('NEURAL TELEMETRY'),
          const SizedBox(height: AppSpacing.xs),
          Row(children: [
            Text('Switch Velocity', style: AppTextStyles.sectionHead),
            const Spacer(),
            if (!p.loading && p.breachCount > 0)
              NtChip('${p.breachCount} BREACHES TODAY', color: AppColors.red),
          ]),
          const SizedBox(height: AppSpacing.md),
          if (p.loading)
            const ShimmerCard(height: 180)
          else
            RepaintBoundary(
              child: _VelocityChart(bars: p.todayHourlyBars),
            ),
        ]),
      ),
    );
  }

  // ── Temporal Heatmap ──────────────────────────────────────────────────────

  Widget _buildHeatmap(AnalyticsProvider p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 12, AppSpacing.lg, 0),
      child: NtCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const NtLabel('TEMPORAL DENSITY'),
          const SizedBox(height: AppSpacing.xs),
          Text('Neural Load Heatmap', style: AppTextStyles.sectionHead),
          const SizedBox(height: AppSpacing.md),
          if (p.loading)
            const ShimmerCard(height: 120)
          else
            _TemporalHeatmap(
              grid: p.heatmapGrid,
              dayLabels: p.heatmapDayLabels,
              peakCell: p.heatmapPeakCell,
              peakValue: p.heatmapPeak,
            ),
        ]),
      ),
    );
  }

  // ── Brain Load ────────────────────────────────────────────────────────────

  Widget _buildBrainLoad(AnalyticsProvider p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 12, AppSpacing.lg, 0),
      child: NtCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const NtLabel('COMPONENT METRICS'),
          const SizedBox(height: AppSpacing.xs),
          Text('Brain Load', style: AppTextStyles.sectionHead),
          const SizedBox(height: AppSpacing.md),
          if (p.loading)
            const ShimmerCard(height: 100)
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('WM STRAIN', style: AppTextStyles.chipLabel),
                Text('${p.wmStrain.toStringAsFixed(0)}%',
                    style: AppTextStyles.metricValue
                        .copyWith(color: AppColors.red, fontSize: 20)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            WmStrainBar(value: p.wmStrain / 100, showPercent: false),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Attention Decay', style: AppTextStyles.body),
                Text(p.attentionDecayLabel, style: AppTextStyles.cardTitle),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Neural Noise', style: AppTextStyles.body),
                Row(children: [
                  Text('${p.neuralNoise.toStringAsFixed(1)}Hz',
                      style: AppTextStyles.cardTitle
                          .copyWith(color: AppColors.red)),
                  const SizedBox(width: 4),
                  const Icon(Icons.analytics, size: 14, color: AppColors.red),
                ]),
              ],
            ),
          ],
        ]),
      ),
    );
  }

  // ── Recovery Coefficient chart ────────────────────────────────────────────

  Widget _buildRecoveryCoeff(AnalyticsProvider p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 12, AppSpacing.lg, 0),
      child: NtCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Recovery Coefficient', style: AppTextStyles.sectionHead),
          const SizedBox(height: 4),
          Text('Efficiency before vs after neural recess',
              style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _legendDot(AppColors.chartGray, 'Pre-Break'),
              const SizedBox(width: 12),
              _legendDot(AppColors.red, 'Post-Break'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (p.loading)
            const ShimmerCard(height: 160)
          else
            RepaintBoundary(
              child: _RecoveryChart(periods: p.recoveryCoeff),
            ),
        ]),
      ),
    );
  }

  Widget _legendDot(Color c, String label) => Row(children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: c)),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.chipLabel),
      ]);
}

// ── Switch Velocity Bar Chart ─────────────────────────────────────────────────

class _VelocityChart extends StatelessWidget {
  const _VelocityChart({required this.bars});

  final List<double> bars;

  @override
  Widget build(BuildContext context) {
    final groups = bars.asMap().entries.map((e) {
      final isBreached = e.value > 80;
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: e.value,
            color: isBreached ? AppColors.red : AppColors.chartGray,
            width: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      );
    }).toList();

    return SizedBox(
      height: 180,
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
                  if (h == 8) return _axisLabel('08:00');
                  if (h == 20) return _axisLabel('20:00');
                  return const SizedBox.shrink();
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
          maxY: 100,
          extraLinesData: ExtraLinesData(horizontalLines: [
            HorizontalLine(
              y: 80,
              color: AppColors.red.withValues(alpha: 0.6),
              strokeWidth: 1,
              dashArray: [4, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                labelResolver: (_) => 'Threshold 80/HR',
                style: AppTextStyles.chipLabel.copyWith(color: AppColors.red),
              ),
            ),
            HorizontalLine(
              y: 40,
              color: AppColors.textMuted.withValues(alpha: 0.4),
              strokeWidth: 1,
              dashArray: [4, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                labelResolver: (_) => 'Baseline 40/HR',
                style: AppTextStyles.chipLabel,
              ),
            ),
          ]),
          barGroups: groups,
        ),
      ),
    );
  }

  Widget _axisLabel(String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(text, style: AppTextStyles.chipLabel.copyWith(fontSize: 9)),
      );
}

// ── Temporal Heatmap ──────────────────────────────────────────────────────────

class _TemporalHeatmap extends StatelessWidget {
  const _TemporalHeatmap({
    required this.grid,
    required this.dayLabels,
    required this.peakCell,
    required this.peakValue,
  });

  final List<List<double>> grid;
  final List<String> dayLabels;
  final (int, int) peakCell;
  final double peakValue;

  Color _cellColor(double v) {
    if (v < 30) return AppColors.chartIdle;
    if (v < 70) return AppColors.chartStrain;
    return AppColors.chartRed;
  }

  @override
  Widget build(BuildContext context) {
    const hourLabels = ['08', '10', '12', '14', '16', '18', '20'];
    final showHours = List.generate(13, (i) => i + 8); // 08–20

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hour header
        Padding(
          padding: const EdgeInsets.only(left: 36),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: hourLabels
                .map((h) => Text(h,
                    style: AppTextStyles.chipLabel.copyWith(fontSize: 9)))
                .toList(),
          ),
        ),
        const SizedBox(height: 4),
        // Grid rows
        ...List.generate(min(grid.length, 7), (rowIdx) {
          final dayData = grid[rowIdx];
          final label = rowIdx < dayLabels.length ? dayLabels[rowIdx] : '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(label,
                      style: AppTextStyles.chipLabel.copyWith(fontSize: 9)),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: showHours.map((h) {
                      final v = h < dayData.length ? dayData[h] : 0.0;
                      return Container(
                        width: 14,
                        height: 14,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: _cellColor(v),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: AppSpacing.sm),
        // Legend
        Row(children: [
          _legendCell(AppColors.chartIdle, 'Idle'),
          const SizedBox(width: 8),
          _legendCell(AppColors.chartStrain, 'Strain'),
          const SizedBox(width: 8),
          _legendCell(AppColors.chartRed, 'Peak'),
        ]),
        if (peakValue > 0) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Peak observed: ${peakValue.toStringAsFixed(0)}% Load '
            '@ ${dayLabels.isNotEmpty && peakCell.$1 < dayLabels.length ? dayLabels[peakCell.$1] : ""} ${(peakCell.$2).toString().padLeft(2, "0")}:00',
            style: AppTextStyles.chipLabel.copyWith(color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }

  Widget _legendCell(Color c, String label) => Row(children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.chipLabel.copyWith(fontSize: 9)),
      ]);
}

// ── Recovery Coefficient Bar Chart ────────────────────────────────────────────

class _RecoveryChart extends StatelessWidget {
  const _RecoveryChart({required this.periods});

  final Map<String, Map<String, double>> periods;

  @override
  Widget build(BuildContext context) {
    final keys = periods.keys.toList();
    final groups = keys.asMap().entries.map((e) {
      final pre = periods[e.value]!['pre'] ?? 0;
      final post = periods[e.value]!['post'] ?? 0;
      return BarChartGroupData(
        x: e.key,
        groupVertically: false,
        barsSpace: 4,
        barRods: [
          BarChartRodData(
              toY: pre,
              color: AppColors.chartGray,
              width: 14,
              borderRadius: BorderRadius.circular(3)),
          BarChartRodData(
              toY: post,
              color: AppColors.red,
              width: 14,
              borderRadius: BorderRadius.circular(3)),
        ],
      );
    }).toList();

    return SizedBox(
      height: 160,
      child: BarChart(
        BarChartData(
          backgroundColor: Colors.transparent,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          maxY: 100,
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (val, _) {
                  final i = val.toInt();
                  if (i < 0 || i >= keys.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(keys[i].substring(0, min(4, keys[i].length)),
                        style: AppTextStyles.chipLabel.copyWith(fontSize: 9)),
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
          barGroups: groups,
        ),
      ),
    );
  }
}
