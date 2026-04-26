/// Dashboard screen — Daily Brain Load, hero metrics, weekly chart.
library;

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
import '../../widgets/delta_badge.dart';
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

class _DashboardScreenState extends State<DashboardScreen> {
  int _tabIndex = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().load();
    });
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
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: Builder(builder: (c) => _buildHeader(c.watch<DashboardProvider>()))),
              SliverToBoxAdapter(child: Builder(builder: (c) => _buildHeroSection(c.watch<DashboardProvider>()))),
              SliverToBoxAdapter(child: _buildTabSelector()),
              SliverToBoxAdapter(child: Builder(builder: (c) => _buildWeeklySection(c.watch<DashboardProvider>()))),
              SliverToBoxAdapter(child: Builder(builder: (c) => _buildMetric4Grid(c.watch<DashboardProvider>()))),
              SliverToBoxAdapter(child: Builder(builder: (c) => _buildNeuralObservation(c.watch<DashboardProvider>()))),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
      floatingActionButton: io.Platform.isIOS ? FloatingActionButton.extended(
        backgroundColor: AppColors.red,
        onPressed: () => _showManualLogDialog(context),
        icon: const Icon(Icons.timer, color: Colors.white),
        label: const Text('Log Focus', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ) : null,
    );
  }

  void _showManualLogDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Log Focus Session', style: AppTextStyles.cardTitle),
        content: Text('Manually log a 30-minute focus session for your tracking.', style: AppTextStyles.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text('Cancel', style: AppTextStyles.chipLabel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(c);
              final store = context.read<SQLiteStore>();
              final logger = ManualSessionLogger(store: store);
              await logger.logFocusSession(30);
              if (mounted) {
                context.read<DashboardProvider>().refresh();
                // We'll also try to refresh RecoveryProvider if it's available, but it might not be in the widget tree here
                try {
                  context.read<RecoveryProvider>().load();
                } catch (_) {}
              }
            },
            child: Text('Log 30m', style: AppTextStyles.chipLabel.copyWith(color: AppColors.good)),
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(DashboardProvider p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 12, AppSpacing.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ID: ${(p.today?.date ?? 'XXXXXX').replaceAll('-', '')}',
                      style: AppTextStyles.chipLabel
                          .copyWith(color: AppColors.textMuted)),
                  Row(children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: p.lastSyncMinutesAgo < 20
                            ? AppColors.good
                            : AppColors.warn,
                      ),
                    ),
                    const SizedBox(width: 4),
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
                            shape: BoxShape.circle, color: AppColors.red),
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
          Text('Daily Brain\nLoad',
              style: AppTextStyles.display.copyWith(
                  fontSize: 32, fontWeight: FontWeight.w800, height: 1.15)),
        ],
      ),
    );
  }

  // ── Hero + Metric Grid ─────────────────────────────────────────────────────

  Widget _buildHeroSection(DashboardProvider p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 16, AppSpacing.lg, 0),
      child: p.loading
          ? const ShimmerList(count: 3, itemHeight: 80)
          : _buildMetricGrid(p),
    );
  }

  Widget _buildMetricGrid(DashboardProvider p) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _cogDebtCard(p)),
            const SizedBox(width: AppSpacing.sectionGap),
            Expanded(child: _switchesCard(p)),
          ],
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        Row(
          children: [
            Expanded(child: _screenTimeCard(p)),
            const SizedBox(width: AppSpacing.sectionGap),
            Expanded(child: _pickupsCard(p)),
          ],
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        _cogDebtPtsCard(p),
      ],
    );
  }

  Widget _cogDebtCard(DashboardProvider p) => NtCard(
        redBorder: p.isCritical,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const NtLabel('COG. DEBT'),
            if (p.isCritical) ...[
              const Spacer(),
              const NtChip('CRITICAL', color: AppColors.red),
            ],
          ]),
          const SizedBox(height: AppSpacing.xs),
          Text('${p.cogDebtPct.toStringAsFixed(0)}%',
              style: AppTextStyles.metricValue.copyWith(
                  color: p.isCritical ? AppColors.red : AppColors.textPrimary)),
        ]),
      );

  Widget _switchesCard(DashboardProvider p) => NtCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const NtLabel('SWITCHES'),
          const SizedBox(height: AppSpacing.xs),
          Text('${p.totalSwitches}', style: AppTextStyles.metricValue),
          if (p.isHighVolatility)
            Row(children: [
              const Icon(Icons.warning_amber, size: 12, color: AppColors.warn),
              const SizedBox(width: 3),
              Text('High Volatility',
                  style:
                      AppTextStyles.deltaLabel.copyWith(color: AppColors.warn)),
            ]),
        ]),
      );

  Widget _screenTimeCard(DashboardProvider p) => NtCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const NtLabel('SCREEN TIME'),
            const Spacer(),
            DeltaBadge(p.screenTimeDeltaLabel,
                type: p.screenTimeDelta > 0
                    ? DeltaType.negative
                    : DeltaType.positive),
          ]),
          const SizedBox(height: AppSpacing.xs),
          Text('${p.screenTime.toStringAsFixed(1)}h',
              style: AppTextStyles.metricValue),
          if (p.lastSyncMinutesAgo > 0)
            Text('Sync: ${p.lastSyncMinutesAgo}m ago',
                style: AppTextStyles.deltaLabel),
        ]),
      );

  Widget _pickupsCard(DashboardProvider p) => NtCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const NtLabel('PICKUPS'),
          const SizedBox(height: AppSpacing.xs),
          Text('${p.totalPickups}', style: AppTextStyles.metricValue),
          DeltaBadge(
            p.pickupsDeltaLabel,
            type: p.isPickupsAboveAvg ? DeltaType.negative : DeltaType.positive,
          ),
        ]),
      );

  Widget _cogDebtPtsCard(DashboardProvider p) => NtCard(
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const NtLabel('COG. DEBT PTS'),
            const SizedBox(height: AppSpacing.xs),
            Text(p.cogDebtPts.toStringAsFixed(0),
                style:
                    AppTextStyles.metricValue.copyWith(color: AppColors.red)),
            Text(p.cogDebtDeltaLabel,
                style:
                    AppTextStyles.deltaLabel.copyWith(color: AppColors.warn)),
          ]),
          const Spacer(),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.redGlow,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderRed),
            ),
            child: Center(
              child: Text('${p.cogDebtPct.toStringAsFixed(0)}%',
                  style:
                      AppTextStyles.chipLabel.copyWith(color: AppColors.red)),
            ),
          ),
        ]),
      );

  // ── Tab selector ──────────────────────────────────────────────────────────

  Widget _buildTabSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 20, AppSpacing.lg, 0),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: ['DAY', 'WEEK', 'MONTH'].asMap().entries.map((e) {
            final selected = e.key == _tabIndex;
            final disabled = e.key != 1; // Only WEEK is implemented
            
            Widget tab = Container(
              margin: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: selected ? AppColors.red : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(e.value,
                    style: AppTextStyles.chipLabel.copyWith(
                      color: selected 
                          ? Colors.white 
                          : (disabled ? AppColors.textMuted.withValues(alpha: 0.3) : AppColors.textMuted),
                    )),
              ),
            );

            if (disabled) {
              tab = Tooltip(message: 'Coming soon', child: tab);
            } else {
              tab = GestureDetector(
                onTap: () => setState(() => _tabIndex = e.key),
                child: tab,
              );
            }

            return Expanded(child: tab);
          }).toList(),
        ),
      ),
    );
  }

  // ── Weekly Pattern chart ──────────────────────────────────────────────────

  Widget _buildWeeklySection(DashboardProvider p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 20, AppSpacing.lg, 0),
      child: NtCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const NtLabel('BIOMETRIC TELEMETRY'),
          const SizedBox(height: AppSpacing.xs),
          Row(children: [
            Text('Weekly Pattern', style: AppTextStyles.sectionHead),
            const Spacer(),
            if (!p.loading && p.weeklyLoadValues.isNotEmpty)
              Row(children: [
                Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: AppColors.red)),
                const SizedBox(width: 4),
                Text('${p.cogDebtPct.toStringAsFixed(0)}% Cog. Debt',
                    style: AppTextStyles.chipLabel
                        .copyWith(color: AppColors.textSecondary)),
              ]),
          ]),
          const SizedBox(height: AppSpacing.md),
          if (p.loading)
            const ShimmerCard(height: 120)
          else if (p.weeklyLoadValues.isEmpty)
            SizedBox(
              height: 120,
              child:
                  Center(child: Text('No data yet', style: AppTextStyles.body)),
            )
          else
            RepaintBoundary(child: _buildTabChart(p)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('COGNITIVE LOAD INDEX', style: AppTextStyles.chipLabel),
              DeltaBadge(p.weekOverWeekLabel,
                  type: p.weekOverWeekDelta >= 0
                      ? DeltaType.negative
                      : DeltaType.positive),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _buildTabChart(DashboardProvider p) {
    return switch (_tabIndex) {
      0 => p.todayHourlyValues.isEmpty
          ? SizedBox(height: 120,
              child: Center(child: Text('No data today', style: AppTextStyles.body)))
          : RepaintBoundary(child: _HourlyBarChart(values: p.todayHourlyValues)),
      2 => p.weeklyLoadValues.isEmpty
          ? SizedBox(height: 120,
              child: Center(child: Text('No data yet', style: AppTextStyles.body)))
          : RepaintBoundary(child: _WeeklyChart(
              values: p.weeklyLoadValues, peak: p.weeklyPeak)),
      _ => p.weeklyLoadValues.isEmpty
          ? SizedBox(height: 120,
              child: Center(child: Text('No data yet', style: AppTextStyles.body)))
          : RepaintBoundary(child: _WeeklyChart(
              values: p.weeklyLoadValues, peak: p.weeklyPeak)),
    };
  }

  // ── 4-metric 2×2 grid ─────────────────────────────────────────────────────

  Widget _buildMetric4Grid(DashboardProvider p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 12, AppSpacing.lg, 0),
      child: p.loading
          ? const ShimmerList(count: 2, itemHeight: 100)
          : Column(children: [
              Row(children: [
                Expanded(
                    child: _metricCard('METRIC 01', 'Focus Blocks',
                        p.focusBlocksLabel, '+12% VS LAST')),
                const SizedBox(width: AppSpacing.sectionGap),
                Expanded(
                    child: _metricCard('METRIC 02', 'Peak Stress',
                        p.peakStressLabel, 'LATER THAN AVG')),
              ]),
              const SizedBox(height: AppSpacing.sectionGap),
              Row(children: [
                Expanded(
                    child: _metricCard('METRIC 03', 'Attn Residue',
                        p.attnResidueLabel, 'SIGNIFICANT INCR.',
                        valueColor: p.residueAtEOD > 0.5
                            ? AppColors.warn
                            : AppColors.textPrimary)),
                const SizedBox(width: AppSpacing.sectionGap),
                Expanded(
                    child: _metricCard(
                        'METRIC 04',
                        'Recovery',
                        '${(p.wmCapacity / 100 * 8).toStringAsFixed(0)}h',
                        'STABLE VS PREV.')),
              ]),
            ]),
    );
  }

  Widget _metricCard(
    String label,
    String title,
    String value,
    String delta, {
    Color? valueColor,
  }) =>
      NtCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          NtLabel(label),
          const SizedBox(height: 2),
          Text(title, style: AppTextStyles.cardTitle),
          const SizedBox(height: AppSpacing.xs),
          Text(value,
              style: AppTextStyles.sectionHead.copyWith(
                  color: valueColor ?? AppColors.textPrimary, fontSize: 20)),
          const SizedBox(height: 2),
          Text(delta, style: AppTextStyles.deltaLabel),
        ]),
      );

  // ── Neural Observation ────────────────────────────────────────────────────

  Widget _buildNeuralObservation(DashboardProvider p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 12, AppSpacing.lg, 0),
      child: p.loading
          ? const ShimmerCard(height: 110)
          : NtCard(
              redBorder: p.isCritical,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.biotech, size: 14, color: AppColors.red),
                      const SizedBox(width: 6),
                      Text('NEURAL OBSERVATION',
                          style: AppTextStyles.chipLabel),
                    ]),
                    const SizedBox(height: AppSpacing.sm),
                    Text(p.neuralObservation, style: AppTextStyles.body),
                    const SizedBox(height: AppSpacing.sm),
                    Text('Ref ID: ${p.neuralObservationRefId}',
                        style: AppTextStyles.chipLabel
                            .copyWith(color: AppColors.textMuted)),
                  ]),
            ),
    );
  }
}

// ── Weekly Line Chart ────────────────────────────────────────────────────────

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
                  if (i < 0 || i >= days.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(days[i],
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
                  strokeColor: AppColors.red.withValues(alpha: 0.3),
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

// ── Hourly Bar Chart ────────────────────────────────────────────────────────

class _HourlyBarChart extends StatelessWidget {
  const _HourlyBarChart({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Text('Hourly Data (Coming Soon)', style: AppTextStyles.body),
      ),
    );
  }
}
