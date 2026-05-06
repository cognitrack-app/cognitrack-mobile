/// Sanctuary screen — Neural Restoration Centre.
/// Rebuilt to match Stitch design: header with avatar + debt banner,
/// 4 sections: Breathing Protocols, Eye Strain Relief, 10-Min Meditations, Nature Sounds.
// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
library;

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/nt_card.dart';

class SanctuaryScreen extends StatelessWidget {
  const SanctuaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildDebtBanner()),
            SliverToBoxAdapter(child: _buildBreathingProtocols()),
            SliverToBoxAdapter(child: _buildEyeStrainRelief()),
            SliverToBoxAdapter(child: _buildMeditations()),
            SliverToBoxAdapter(child: _buildNatureSounds()),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  // ── ITEM 6: Header — NEURAL RESTORATION CENTRE + SANCTUARY + avatar ─────

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 12, AppSpacing.lg, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.red,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'NEURAL RESTORATION CENTRE',
                    style: AppTextStyles.chipLabel.copyWith(
                      color: AppColors.red,
                      letterSpacing: 1.2,
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(
                  'SANCTUARY',
                  style: AppTextStyles.cardTitle.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/images/avatar.png',
                fit: BoxFit.cover,
                // Fix #7: Graceful fallback when avatar asset is missing.
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.person_outline,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      );

  // ── ITEM 7: Sticky red debt banner ────────────────────────────────────────

  Widget _buildDebtBanner() => Container(
        margin: const EdgeInsets.only(top: 12),
        width: double.infinity,
        color: AppColors.red,
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 10),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            'COG. DEBT 73% — TIER 1 PROTOCOLS ACTIVE',
            style: AppTextStyles.chipLabel.copyWith(
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          const Icon(Icons.chevron_right, color: Colors.white, size: 18),
        ]),
      );

  // ── ITEM 9: Breathing Protocols — 2-col image grid ───────────────────────

  Widget _buildBreathingProtocols() => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 28, AppSpacing.lg, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('BREATHING PROTOCOLS',
                style: AppTextStyles.chipLabel
                    .copyWith(letterSpacing: 2.0, color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.md),
            Row(children: [
              Expanded(
                child: _ImageProtocolCard(
                  title: 'Box\nBreathing',
                  subtitle: '04:00 · FOCUS',
                  imagePath: 'assets/images/lungs_box.png',
                  imageOpacity: 0.85,
                ),
              ),
              const SizedBox(width: AppSpacing.sectionGap),
              Expanded(
                child: _ImageProtocolCard(
                  title: '4-7-8\nReset',
                  subtitle: '05:00 · SLEEP',
                  imagePath: 'assets/images/lungs_478.png',
                  imageOpacity: 0.85,
                  flipVertical: true,
                ),
              ),
            ]),
          ],
        ),
      );

  // ── ITEM 10: Eye Strain Relief — 2-col image grid ─────────────────────────

  Widget _buildEyeStrainRelief() => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 24, AppSpacing.lg, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('EYE STRAIN RELIEF',
                style: AppTextStyles.chipLabel
                    .copyWith(letterSpacing: 2.0, color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.md),
            Row(children: [
              Expanded(
                child: _ImageProtocolCard(
                  title: '20-20-20\nProtocol',
                  subtitle: 'RECALIBRATE',
                  imagePath: 'assets/images/eye_2020.png',
                  imageOpacity: 0.85,
                  imageFit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: AppSpacing.sectionGap),
              Expanded(
                child: _ImageProtocolCard(
                  title: 'Palming\nSession',
                  subtitle: 'DECOMPRESS',
                  imagePath: 'assets/images/eye_palming.png',
                  imageOpacity: 0.85,
                  imageFit: BoxFit.cover,
                ),
              ),
            ]),
          ],
        ),
      );

  // ── ITEM 11: 10-Min Meditations — horizontal rows with thumbs ─────────────

  Widget _buildMeditations() => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 24, AppSpacing.lg, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('10-MIN MEDITATIONS',
                style: AppTextStyles.chipLabel
                    .copyWith(letterSpacing: 2.0, color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.md),
            _MeditationRow(
              title: 'Neural Drift',
              subtitle: 'THETA WAVE TUNING',
              thumbPath: 'assets/thumbs/neural_drift.png',
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            _MeditationRow(
              title: 'Gamma Sync',
              subtitle: 'COGNITIVE ALIGNMENT',
              thumbPath: 'assets/thumbs/gamma_sync.png',
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            _MeditationRow(
              title: 'White Noise',
              subtitle: 'NEURAL MASKING',
              thumbPath: 'assets/thumbs/white_noise.png',
            ),
          ],
        ),
      );

  // ── ITEM 12: Nature Sounds — 2-col image grid ─────────────────────────────

  Widget _buildNatureSounds() => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 24, AppSpacing.lg, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('NATURE SOUNDS',
                style: AppTextStyles.chipLabel
                    .copyWith(letterSpacing: 2.0, color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.md),
            Row(children: [
              Expanded(
                child: _ImageProtocolCard(
                  title: 'River /\nStream',
                  subtitle: 'AQUEOUS AMBIENT',
                  imagePath: 'assets/images/river_stream.png',
                  imageOpacity: 0.80,
                  imageFit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: AppSpacing.sectionGap),
              Expanded(
                child: _ImageProtocolCard(
                  title: 'Zen\nForest',
                  subtitle: 'BIOPHILIC REST',
                  imagePath: 'assets/images/zen_forest.png',
                  imageOpacity: 0.80,
                  imageFit: BoxFit.cover,
                ),
              ),
            ]),
          ],
        ),
      );
}

// ── Image-background square card ─────────────────────────────────────────────

class _ImageProtocolCard extends StatelessWidget {
  const _ImageProtocolCard({
    required this.title,
    required this.subtitle,
    required this.imagePath,
    this.imageOpacity = 0.4,
    this.flipVertical = false,
    this.imageFit = BoxFit.contain,
  });

  final String title;
  final String subtitle;
  final String imagePath;
  final double imageOpacity;
  final bool flipVertical;
  final BoxFit imageFit;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.cardR),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Background image
            Positioned.fill(
              child: Transform.scale(
                scaleY: flipVertical ? -1 : 1,
                child: Image.asset(
                  imagePath,
                  fit: imageFit,
                  scale: 1.1,
                  color: Colors.white.withValues(alpha: imageOpacity),
                  colorBlendMode: BlendMode.modulate,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.surfaceHigh,
                    child: const Center(
                      child: Icon(Icons.image_not_supported_outlined,
                          color: AppColors.textMuted, size: 32),
                    ),
                  ),
                ),
              ),
            ),
            // Text overlay at bottom-left
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.cardTitle.copyWith(
                        fontSize: 18,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: AppTextStyles.chipLabel.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Meditation horizontal row ─────────────────────────────────────────────────

class _MeditationRow extends StatelessWidget {
  const _MeditationRow({
    required this.title,
    required this.subtitle,
    required this.thumbPath,
  });

  final String title;
  final String subtitle;
  final String thumbPath;

  @override
  Widget build(BuildContext context) {
    return NtCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.md),
      child: Row(children: [
        // Thumbnail
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(AppSpacing.sm),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            thumbPath,
            fit: BoxFit.contain,
            color: Colors.white.withValues(alpha: 0.7),
            colorBlendMode: BlendMode.modulate,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.music_note_outlined,
              color: AppColors.textMuted,
              size: 24,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        // Title + subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.cardTitle),
              const SizedBox(height: 3),
              Text(subtitle,
                  style: AppTextStyles.chipLabel.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 9,
                    letterSpacing: 1.2,
                  )),
            ],
          ),
        ),
        // Play button
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.red.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: const Icon(
            Icons.play_arrow_rounded,
            color: AppColors.red,
            size: 22,
          ),
        ),
      ]),
    );
  }
}
