/// NtMorphCard — base card for Recovery, Sanctuary, and secondary sections.
///
/// Matches the Stitch "Clinical Observer" design system exactly:
///   • Fill: surface_container (#201F1F) — Level 2 of the obsidian stack.
///   • No directional light-source borders (violated the No-Line Rule).
///   • "Ghost Border" fallback: outline_variant at 15% opacity only if
///     [ghostBorder] is true (accessibility / redBorder states only).
///   • Ambient Crimson shadow: 40px blur, 6% opacity — per design spec.
///   • Corner radius: 8px — Stitch ROUND_EIGHT.
///   • [redBorder] applies crimson ghost border + crimson ambient glow.
///   • [elevated] deepens the shadow for hero cards.
///
/// Android optimisation:
///   • BoxDecoration is static — renders once, hardware-cached.
///   • Animate only children via Transform / FadeTransition.
///   • Wrap parent in RepaintBoundary for entrance animations.
library;

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class NtMorphCard extends StatelessWidget {
  const NtMorphCard({
    super.key,
    required this.child,
    this.redBorder = false,
    this.elevated = false,
    this.padding,
  });

  final Widget child;

  /// Draws a crimson ghost border + crimson ambient glow.
  final bool redBorder;

  /// Increases shadow depth — use for hero "COG. DEBT PTS" card.
  final bool elevated;

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        // ── Surface fill: Level 2 obsidian (surface_container) ─────────────
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardR), // 8px
        // ── Ghost Border Rule: only when redBorder or explicit border needed ─
        border: redBorder
            ? Border.all(
                color: AppColors.primaryContainer.withValues(alpha: 0.40),
                width: 0.8,
              )
            : Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.15),
                width: 0.8,
              ),
        // ── Shadow stack ─────────────────────────────────────────────────────
        boxShadow: [
          // Ambient shadow: 40px blur, tinted Crimson (#680009), 6% opacity
          BoxShadow(
            color: AppColors.shadowCrimson.withValues(
              alpha: elevated ? 0.10 : 0.06,
            ),
            blurRadius: 40,
            offset: const Offset(0, 8),
          ),
          // Contact shadow for physical depth
          if (elevated)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          // Red ambient glow for critical / redBorder cards
          if (redBorder)
            BoxShadow(
              color: AppColors.primaryContainer.withValues(alpha: 0.13),
              blurRadius: 30,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: child,
    );
  }
}
