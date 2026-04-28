/// CogniTrack design system — color tokens.
/// Primary brand: RED #E53935 (extracted from mockups).
library;

import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Backgrounds ─────────────────────────────────────────────────────────────
  static const bg = Color(0xFF0D0D0F);
  static const surface = Color(0xFF161618);
  static const surfaceHigh = Color(0xFF1E1E22);
  static const surfaceDim = Color(0xFF111113);
  static const surfaceDeepRed = Color(0xFF1A0808); // hero cog-debt card tint

  // ── Brand ───────────────────────────────────────────────────────────────────
  static const red = Color(0xFFE53935);
  static const redDim = Color(0xFF7B1A1A);
  static const redGlow = Color(0x33E53935);

  // ── Semantic ────────────────────────────────────────────────────────────────
  static const good = Color(0xFF00C853);
  static const warn = Color(0xFFF57C00);
  static const critical = Color(0xFFE53935);

  // ── Text ────────────────────────────────────────────────────────────────────
  static const textPrimary = Color(0xFFF5F5F5);
  static const textSecondary = Color(0xFF9E9E9E);
  static const textMuted = Color(0xFF5E5E6E);
  static const textRed = Color(0xFFE53935);

  // ── Chart ───────────────────────────────────────────────────────────────────
  static const chartRed = Color(0xFFE53935);
  static const chartGray = Color(0xFF2E2E32);
  static const chartStrain = Color(0xFF6B2020);
  static const chartIdle = Color(0xFF1E1E22);

  // ── Border ──────────────────────────────────────────────────────────────────
  static const border = Color(0xFF2A2A2E);
  static const borderRed = Color(0xFF7B1A1A);

  // ── Nav ─────────────────────────────────────────────────────────────────────
  static const navBg = Color(0xFF0D0D0F);
}
