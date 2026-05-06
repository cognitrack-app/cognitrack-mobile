/// CogniTrack design system — color tokens.
/// Rebuilt for the "Clinical Observer" design system.
/// All 6 surface tiers from Stitch namedColors are now represented.
library;

import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Backgrounds & Surfaces (Full 6-tier "Obsidian Glass" stack) ────────
  /// Level 0: The void. Outermost container / page background.
  static const bg = Color(0xFF131313);

  /// Level 0: Surface dim — same as bg for seamless integration.
  static const surfaceDim = Color(0xFF131313);

  /// Level 0-: Glassmorphism base — 92% opacity with BackdropFilter.
  static const surfaceLowest = Color(0xFF0E0E0E);

  /// Level 1: Subtle containment — between bg and cards. (surface_container_low)
  static const surfaceContainerLow = Color(0xFF1C1B1B);

  /// Level 2: Primary content blocks / card fill. (surface_container)
  static const surface = Color(0xFF201F1F);

  /// Level 3: Active/Interactive elements. (surface_container_high)
  static const surfaceContainerHigh = Color(0xFF2A2A2A);

  /// Level 4: Modals / highest interactive. (surface_container_highest)
  static const surfaceHigh = Color(0xFF353534);

  /// surface_bright — pop-overs and toasts.
  static const surfaceBright = Color(0xFF3A3939);

  // ── Brand / Neural Accents ──────────────────────────────────────────────
  /// The "Signal through the noise" — Crimson. (#CC1020)
  static const primaryContainer = Color(0xFFCC1020);

  /// Primary tint / salmon — for chart lines and data points. (#FFB3AD)
  static const primary = Color(0xFFFFB3AD);

  /// Deep crimson — for ambient shadows. (#680009)
  static const shadowCrimson = Color(0xFF680009);

  /// Darker crimson — for gradient stops. (#930011)
  static const primaryDark = Color(0xFF930011);

  // ── Semantic ────────────────────────────────────────────────────────────
  /// Tertiary blue — used for baseline/historical chart data. (#99CBFF)
  static const good = Color(0xFF99CBFF);

  /// Warm rose-amber for visible alert states — NOT the outline grey. (#E6BDB9)
  static const warn = Color(0xFFE6BDB9);

  /// Error / on-primary-container: vibrant error. (#FFB4AB)
  static const critical = Color(0xFFFFB4AB);

  // ── Text ────────────────────────────────────────────────────────────────
  /// Critical data points and primary headlines. (on-surface white)
  static const textPrimary = Color(0xFFFFFFFF);

  /// Standard text — on-surface. (#E5E2E1)
  static const textSecondary = Color(0xFFE5E2E1);

  /// Variant text / supporting descriptions. (on-surface-variant #E6BDB9)
  static const textMuted = Color(0xFFE6BDB9);

  // ── Chart ───────────────────────────────────────────────────────────────
  static const chartActive = Color(0xFFFFB3AD); // primary
  static const chartBaseline = Color(0xFF99CBFF); // tertiary
  static const chartIdle = Color(0xFF353534); // surface-variant

  // ── Border (Ghost Borders — outline_variant at 15% opacity in use sites) ─
  static const outlineVariant = Color(0xFF5D3F3D);

  // ── Nav ─────────────────────────────────────────────────────────────────
  /// Nav bar stays at surface_container_lowest (#0E0E0E) for separation from bg (#131313).
  static const navBg = Color(0xFF0E0E0E);

  // ── Aliases ─────────────────────────────────────────────────────────────
  /// True crimson CTA color. (#CC1020)
  static const red = primaryContainer;
  static const redDim = shadowCrimson;
  static const redGlow = primaryContainer;
  static const textRed = primaryContainer;
  static const chartRed = primaryContainer;
  static const chartGray = chartIdle;
  static const chartStrain = shadowCrimson;

  /// Ghost border — outlineVariant. Use at 15% opacity per design spec.
  static const border = outlineVariant;
  static const borderRed = primaryContainer;
}
