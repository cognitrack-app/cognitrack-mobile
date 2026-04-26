/// CogniTrack design system — typography tokens.
/// Uses Google Fonts: Inter (display/body) + JetBrains Mono (countdown timer).
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

abstract final class AppTextStyles {
  // Display — "Daily Brain Load", "Recovery Plan"
  static final TextStyle display = GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      );

  // Big metric values — "73%", "82", "6.4h"
  static final TextStyle metricValue = GoogleFonts.inter(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  // Section headers — "Weekly Pattern", "Brain Load"
  static final TextStyle sectionHead = GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  // Card titles — "Focus Blocks", "Peak Stress"
  static final TextStyle cardTitle = GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  // Uppercase tiny labels — "COG. DEBT", "NEURAL TELEMETRY"
  static final TextStyle chipLabel = GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: AppColors.textSecondary,
      );

  // Body — Neural Observation paragraph
  static final TextStyle body = GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.6,
      );

  // Countdown timer — [04:12:00]
  static final TextStyle countdown = GoogleFonts.jetBrainsMono(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: 2,
      );

  // Small delta labels — "+12% VS LAST MONTH"
  static final TextStyle deltaLabel = GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.8,
        color: AppColors.textMuted,
      );
}
