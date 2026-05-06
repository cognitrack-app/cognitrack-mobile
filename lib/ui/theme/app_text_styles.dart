/// CogniTrack design system — typography tokens.
/// Built for the "Clinical Observer" system.
/// High-contrast typographic hierarchy: Plus Jakarta Sans for massive,
/// authoritative headers. Inter for clinical, precise metadata.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

abstract final class AppTextStyles {
  // ── Display & Headlines (Plus Jakarta Sans) ──────────────────────────

  /// Extreme scale for cognitive scores (3.5rem = 56px per Stitch spec)
  static final TextStyle displayLg = GoogleFonts.plusJakartaSans(
    fontSize: 56,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1.05,
    letterSpacing: -1.5,
  );

  /// Standard display for high-priority numbers (1.75rem)
  static final TextStyle display = GoogleFonts.plusJakartaSans(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  /// Section headers (1.75rem) — semi-bold for "Clinical Observer" authority.
  static final TextStyle sectionHead = GoogleFonts.plusJakartaSans(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  /// Bold section headers
  static final TextStyle sectionHeadBold = GoogleFonts.plusJakartaSans(
    fontSize: 36,
    fontWeight: FontWeight.w300,
    color: AppColors.textPrimary,
    letterSpacing: -1.0,
  );

  /// Card titles
  static final TextStyle cardTitle = GoogleFonts.plusJakartaSans(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  // ── Body & Labels (Inter) ───────────────────────────────────────────

  /// The workhorse. Technical, clean aesthetic.
  static final TextStyle body = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.6,
  );

  /// Dense, microscopic functional labels. The "HUD" elements.
  static final TextStyle labelSm = GoogleFonts.inter(
    fontSize: 11, // 0.6875rem
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5, // +5% letter spacing
    color: AppColors.textMuted,
  );

  /// Chip/Tag label
  static final TextStyle chipLabel = GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    color: AppColors.textSecondary,
  );

  /// Small delta labels
  static final TextStyle deltaLabel = GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    color: AppColors.textMuted,
  );

  // ── Specialty ───────────────────────────────────────────────────────

  /// Countdown timer — uses JetBrains Mono for a technical look.
  static final TextStyle countdown = GoogleFonts.jetBrainsMono(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: 2,
  );

  /// Alias for metric values.
  static final TextStyle metricValue = display;
}
