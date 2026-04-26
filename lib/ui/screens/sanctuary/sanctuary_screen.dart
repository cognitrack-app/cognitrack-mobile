/// Sanctuary screen — Neural decompression visualization, breathe sync, recovery protocols.
library;

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/nt_card.dart';
import '../../widgets/nt_chip.dart';
import '../../widgets/nt_label.dart';
import 'package:provider/provider.dart';
import '../../../core/database/sqlite_store.dart';
import '../../../platform/ios/manual_session_logger.dart';
import '../../../core/providers/dashboard_provider.dart';
import '../../../core/providers/recovery_provider.dart';

class SanctuaryScreen extends StatefulWidget {
  const SanctuaryScreen({super.key});

  @override
  State<SanctuaryScreen> createState() => _SanctuaryScreenState();
}

class _SanctuaryScreenState extends State<SanctuaryScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _breatheCtrl;

  @override
  void initState() {
    super.initState();
    _breatheCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4), // 4s in, 4s out
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breatheCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildBreathingOrb()),
            SliverToBoxAdapter(child: _buildProtocols()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 12, AppSpacing.lg, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('SANCTUARY',
              style: AppTextStyles.display
                  .copyWith(fontWeight: FontWeight.w800, fontSize: 30)),
          const SizedBox(height: 4),
          Text('NEURAL DECOMPRESSION ZONE',
              style: AppTextStyles.chipLabel
                  .copyWith(color: AppColors.textMuted, letterSpacing: 1.5)),
        ]),
      );

  // ── Breathing Orb Hero ────────────────────────────────────────────────────

  Widget _buildBreathingOrb() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: AnimatedBuilder(
          animation: _breatheCtrl,
          builder: (context, child) {
            final scale = 0.85 + (_breatheCtrl.value * 0.3);
            final opacity = 0.2 + (_breatheCtrl.value * 0.4);
            return Stack(
              alignment: Alignment.center,
              children: [
                // Outer glow
                Container(
                  width: 280 * scale,
                  height: 280 * scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.red.withValues(alpha: opacity * 0.3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.red.withValues(alpha: opacity * 0.5),
                        blurRadius: 60 * scale,
                        spreadRadius: 20 * scale,
                      ),
                    ],
                  ),
                ),
                // Inner solid
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.redGlow,
                        AppColors.red.withValues(alpha: 0.8),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.red.withValues(alpha: 0.6),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _breatheCtrl.status == AnimationStatus.forward
                          ? 'INHALE'
                          : 'EXHALE',
                      style: AppTextStyles.chipLabel.copyWith(
                        color: Colors.white,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Protocols List ────────────────────────────────────────────────────────

  Widget _buildProtocols() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NtLabel('RECOMMENDED PROTOCOLS'),
          const SizedBox(height: AppSpacing.md),
          _ProtocolCard(
            title: 'Box Breathing',
            duration: '5 MIN',
            pts: '-12 PTS',
            description: '4s inhale, 4s hold, 4s exhale, 4s hold. '
                'Optimal for immediate parasympathetic activation.',
            icon: Icons.air,
            isRecommended: true,
            onStart: () => _logProtocol(context, 5),
          ),
          const SizedBox(height: AppSpacing.md),
          _ProtocolCard(
            title: 'NSDR / Yoga Nidra',
            duration: '15 MIN',
            pts: '-35 PTS',
            description: 'Non-Sleep Deep Rest protocol. Proven to accelerate '
                'dopamine baseline reset and clear attention residue.',
            icon: Icons.self_improvement,
            isRecommended: false,
            onStart: () => _logProtocol(context, 15),
          ),
          const SizedBox(height: AppSpacing.md),
          _ProtocolCard(
            title: 'Visual Defocus',
            duration: '2 MIN',
            pts: '-8 PTS',
            description: 'Expand peripheral vision to trigger relaxation '
                'response and reduce cranial nerve strain.',
            icon: Icons.visibility,
            isRecommended: false,
            onStart: () => _logProtocol(context, 2),
          ),
        ],
      ),
    );
  }

  void _logProtocol(BuildContext context, int durationMinutes) async {
    final store = context.read<SQLiteStore>();
    final logger = ManualSessionLogger(store: store);
    await logger.logFocusSession(durationMinutes);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Protocol logged successfully')),
      );
      try {
        context.read<DashboardProvider>().refresh();
        context.read<RecoveryProvider>().load();
      } catch (_) {}
    }
  }
}

class _ProtocolCard extends StatelessWidget {
  const _ProtocolCard({
    required this.title,
    required this.duration,
    required this.pts,
    required this.description,
    required this.icon,
    required this.isRecommended,
    required this.onStart,
  });

  final String title;
  final String duration;
  final String pts;
  final String description;
  final IconData icon;
  final bool isRecommended;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return NtCard(
      redBorder: isRecommended,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      isRecommended ? AppColors.redDim : AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon,
                    size: 20,
                    color:
                        isRecommended ? AppColors.red : AppColors.textPrimary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style:
                            AppTextStyles.sectionHead.copyWith(fontSize: 18)),
                    Text('$duration · $pts DEBT',
                        style: AppTextStyles.chipLabel),
                  ],
                ),
              ),
              if (isRecommended) const NtChip('OPTIMAL', color: AppColors.good),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(description, style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onStart,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isRecommended ? AppColors.red : AppColors.surfaceHigh,
                foregroundColor:
                    isRecommended ? Colors.white : AppColors.textPrimary,
                elevation: 0,
              ),
              child: Text('START PROTOCOL',
                  style: AppTextStyles.chipLabel.copyWith(
                    color: isRecommended ? Colors.white : AppColors.textPrimary,
                    letterSpacing: 1.5,
                  )),
            ),
          ),
        ],
      ),
    );
  }
}
