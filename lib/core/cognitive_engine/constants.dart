/// CogniTrack cognitive engine constants.
/// Dart port of @cognitrack/shared/src/constants.ts
library;

import 'models.dart';

// ─── Working Memory ──────────────────────────────────────────────────────────
const double wmInitial = 100.0;
const double wmFloor = 15.0; // Never fully depletes
const double wmFocusGain = 6.0; // Per 5-min uninterrupted productive session
const double wmBreakGain = 14.0; // Per verified break
const double wmSwitchCost = 0.15; // Proportional to switch cost

// ─── Focus Depth ─────────────────────────────────────────────────────────────
const int focusBuildThresholdMs = 5 * 60 * 1000; // 5 minutes in ms
const double focusDepthGain = 2.0; // Per 5-min productive window
const double focusDepthMax = 30.0;

// ─── Residue Decay ───────────────────────────────────────────────────────────
/// Fitted to 23-minute recovery window (Sophie Leroy, 2009)
const double tauMs = 7.67 * 60 * 1000; // 460,200 ms

// ─── Cross-Device Multiplier ─────────────────────────────────────────────────
const double crossDeviceMultiplier = 2.2;

// ─── Normalisation Thresholds ────────────────────────────────────────────────
/// Empirically: a very heavy day = ~500 raw debt units => 100% load
const double dailyDebtThreshold = 500.0;

/// Per-hour: a very heavy hour = ~40 raw debt units => 100%
const double hourlyDebtThreshold = 40.0;

// ─── Context Distance Matrix (Asymmetric) ────────────────────────────────────
/// FROM category (outer key) → TO category (inner key)
/// Research: Pettigrew & Martin 2016; Leroy 2009
const Map<Category, Map<Category, double>> contextDistance = {
  Category.productive: {
    Category.productive: 1.0,
    Category.tools: 1.5,
    Category.social: 6.0,
    Category.entertainment: 5.0,
    Category.passiveWaste: 7.0,
  },
  Category.social: {
    Category.productive: 8.0,
    Category.tools: 5.0,
    Category.social: 2.0,
    Category.entertainment: 2.5,
    Category.passiveWaste: 1.5,
  },
  Category.entertainment: {
    Category.productive: 7.0,
    Category.tools: 4.5,
    Category.social: 2.0,
    Category.entertainment: 1.5,
    Category.passiveWaste: 1.0,
  },
  Category.passiveWaste: {
    Category.productive: 9.0, // TikTok→VSCode: hardest re-entry
    Category.tools: 6.0,
    Category.social: 1.5,
    Category.entertainment: 1.0,
    Category.passiveWaste: 1.0,
  },
  Category.tools: {
    Category.productive: 2.0,
    Category.tools: 1.5,
    Category.social: 5.0,
    Category.entertainment: 4.0,
    Category.passiveWaste: 6.0,
  },
};
