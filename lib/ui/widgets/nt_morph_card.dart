/// NtMorphCard — 3-D morphism card for the home dashboard.
///
/// Simulates a physical card floating above the dark surface by combining:
///   • Asymmetric directional borders (bright top-left edge, dark bottom-right)
///   • Linear gradient body (lighter top-left → darker bottom-right)
///   • Multi-layer box shadows (deep ambient + contact + optional red glow)
///   • Top specular highlight (1 px inset white shadow at 3 % opacity)
///
/// Android optimisation notes:
///   • BoxDecoration is static — renders once and is hardware-cached.
///   • Never animate the decoration itself; animate only the child via
///     Transform / FadeTransition (compositor layers, zero CPU cost).
///   • Wrap the card's parent in RepaintBoundary for entrance animations.
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

  /// Draws a red bottom/right border + red ambient glow.
  final bool redBorder;

  /// Increases shadow depth — use for the hero "COG. DEBT PTS" wide card.
  final bool elevated;

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        // ── Gradient body ─────────────────────────────────────────────────
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF202024), // lighter — simulates top-left light source
            Color(0xFF131315), // darker  — shadowed bottom-right
          ],
        ),
        // ── Directional borders ───────────────────────────────────────────
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 0.75,
          ),
          left: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
            width: 0.75,
          ),
          bottom: BorderSide(
            color: redBorder
                ? AppColors.borderRed
                : Colors.black.withValues(alpha: 0.70),
            width: redBorder ? 1.0 : 0.75,
          ),
          right: BorderSide(
            color: redBorder
                ? AppColors.borderRed.withValues(alpha: 0.55)
                : Colors.black.withValues(alpha: 0.50),
            width: 0.75,
          ),
        ),
        // ── Shadow stack ──────────────────────────────────────────────────
        boxShadow: [
          // Deep ambient shadow — creates the "floating" illusion
          BoxShadow(
            color: Colors.black.withValues(alpha: elevated ? 0.65 : 0.48),
            blurRadius: elevated ? 36 : 22,
            spreadRadius: elevated ? 2 : 0,
            offset: Offset(0, elevated ? 18 : 11),
          ),
          // Close contact shadow — sharpens the card edge
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
          // Red ambient glow for critical / redBorder cards
          if (redBorder)
            BoxShadow(
              color: AppColors.red.withValues(alpha: 0.13),
              blurRadius: 30,
              spreadRadius: 0,
              offset: const Offset(0, 8),
            ),
          // Top specular highlight — 1 px reflection of the "light source"
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.03),
            blurRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}
