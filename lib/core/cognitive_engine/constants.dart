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

// ─── Pickup Penalty ───────────────────────────────────────────────────────────
const double pickupPenalty = 3.5;

// ─── Normalisation Thresholds ────────────────────────────────────────────────
/// Empirically: a very heavy day = ~500 raw debt units => 100% load
const double dailyDebtThreshold = 500.0;

/// Per-hour: a very heavy hour = ~40 raw debt units => 100%
const double hourlyDebtThreshold = 40.0;

// ─── Sync Payload Schema Version ──────────────────────────────────────────────
/// Increment when payload structure changes in a backward-incompatible way.
/// v1: Initial release
/// v2: Added break_events, 5-category breakdown (tools), cross-device multiplier parity
const int syncPayloadSchemaVersion = 2;

// ─── Shared Timing Constants ──────────────────────────────────────────────────
/// 5-minute window for velocity calculation and break detection
const int fiveMinMs = 5 * 60 * 1000; // 300,000 ms
/// 7-day TTL for local event storage
const int ttlSevenDaysMs = 7 * 24 * 60 * 60 * 1000; // 604,800,000 ms
/// Base backoff for sync retry (30 seconds)
const int backoffBaseMs = 30 * 1000; // 30,000 ms
/// Velocity multiplier cap at 4 switches/min
const int velocityCapSwitchesPerMin = 4;

// ─── Break Classification Thresholds ──────────────────────────────────────────
/// Minimum break duration to track (5 minutes)
const int minBreakMs = fiveMinMs;
/// Structured break threshold (20 minutes)
const int structuredBreakMin = 20;
/// Sleep/overnight break threshold (8 hours = 480 minutes)
const int sleepBreakMin = 480;

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