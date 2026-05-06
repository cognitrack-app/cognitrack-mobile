/// CogniTrack shared data models — Dart port of @cognitrack/shared/src/types.ts
library;

// ─── Enums ───────────────────────────────────────────────────────────────────

enum Category {
  productive,
  tools,
  social,
  entertainment,
  passiveWaste;

  static Category fromString(String s) {
    return Category.values.firstWhere(
      (c) => c.name == s,
      orElse: () => Category.tools,
    );
  }
}

enum Platform { darwin, win32, android, ios }

enum DeviceType { phone, desktop }

enum EventType { switch_, pickup, break_, idle }

extension EventTypeExt on EventType {
  String get value {
    switch (this) {
      case EventType.switch_:
        return 'switch';
      case EventType.pickup:
        return 'pickup';
      case EventType.break_:
        return 'break';
      case EventType.idle:
        return 'idle';
    }
  }

  static EventType fromString(String s) {
    switch (s) {
      case 'switch':
        return EventType.switch_;
      case 'pickup':
        return EventType.pickup;
      case 'break':
        return EventType.break_;
      case 'idle':
        return EventType.idle;
      default:
        return EventType.idle;
    }
  }
}

// ─── Core Models ─────────────────────────────────────────────────────────────

class AppEvent {
  final String id;
  final int timestamp; // Unix ms
  final String appId; // canonical app ID e.g. "android.instagram"
  final Category category;
  final int durationMs;
  final EventType eventType;
  final DeviceType deviceType;

  const AppEvent({
    required this.id,
    required this.timestamp,
    required this.appId,
    required this.category,
    required this.durationMs,
    required this.eventType,
    required this.deviceType,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'timestamp': timestamp,
        'appId': appId,
        'category': category.name,
        'durationMs': durationMs,
        'eventType': eventType.value,
        'deviceType': deviceType.name,
      };
}

class CognitiveState {
  double wmCapacity; // Working memory [0–100]
  double residue; // Attention residue [0–1]
  double focusDepth; // Accumulated deep focus [0–30]
  int lastSwitchTs; // Timestamp of last context switch (ms)
  // NOTE: lastResiduDecayTs removed (BUG-10) — was never read; decay uses
  // lastSwitchTs for the timeSinceLast calculation inside applySwitch().

  CognitiveState({
    required this.wmCapacity,
    required this.residue,
    required this.focusDepth,
    required this.lastSwitchTs,
  });
}

class CognitiveReport {
  final double cognitiveDebt;
  final double cognitiveLoadPct; // 0–100
  final double wmCapacityRemaining;
  final double residueAtEOD; // 0–1
  final List<double> hourlyDebt; // 24-element, each 0–100
  // Peak hour defaults to 0 if there are no events to match desktop parity.
  final int peakLoadHour; // 0–23

  const CognitiveReport({
    required this.cognitiveDebt,
    required this.cognitiveLoadPct,
    required this.wmCapacityRemaining,
    required this.residueAtEOD,
    required this.hourlyDebt,
    required this.peakLoadHour,
  });
}

class CategoryBreakdown {
  final double productive;
  final double entertainment;
  final double social;
  final double passiveWaste;

  const CategoryBreakdown({
    required this.productive,
    required this.entertainment,
    required this.social,
    required this.passiveWaste,
  });

  Map<String, dynamic> toMap() => {
        'productive': productive,
        'entertainment': entertainment,
        'social': social,
        'passiveWaste': passiveWaste,
      };

  factory CategoryBreakdown.fromMap(Map<String, dynamic> m) =>
      CategoryBreakdown(
        productive: (m['productive'] as num?)?.toDouble() ?? 0,
        entertainment: (m['entertainment'] as num?)?.toDouble() ?? 0,
        social: (m['social'] as num?)?.toDouble() ?? 0,
        passiveWaste: (m['passiveWaste'] as num?)?.toDouble() ?? 0,
      );
}

// ─── Break Event ──────────────────────────────────────────────────────────────
// CRITICAL-1 FIX: Dart port of types.ts BreakEvent.
// Populated by extractBreakEvents() and included in PhoneSyncPayload so the
// Cloud Function can compute recovery_verified_break_minutes and recovery radar
// for phone sessions (previously always 0 because the field was never written).
class BreakEvent {
  final String startTime; // ISO timestamp
  final String endTime; // ISO timestamp
  final String activityType; // 'IDLE' | 'STRUCTURED' | 'SLEEP'
  final int durationMinutes;
  final double debtBefore; // cognitiveLoadPct snapshot before break
  final double debtAfter; // cognitiveLoadPct snapshot after break
  final double ptsRecovered;
  final int efficiencyPct; // ptsRecovered / debtBefore * 100

  const BreakEvent({
    required this.startTime,
    required this.endTime,
    required this.activityType,
    required this.durationMinutes,
    required this.debtBefore,
    required this.debtAfter,
    required this.ptsRecovered,
    required this.efficiencyPct,
  });

  Map<String, dynamic> toMap() => {
        'start_time': startTime,
        'end_time': endTime,
        'activity_type': activityType,
        'duration_minutes': durationMinutes,
        'debt_before': debtBefore,
        'debt_after': debtAfter,
        'pts_recovered': ptsRecovered,
        'efficiency_pct': efficiencyPct,
      };
}

/// The 11 scalar metrics written to Firestore as PhoneSyncPayload
class PhoneSyncPayload {
  final String date; // YYYY-MM-DD
  final String deviceId; // SHA-256 hash
  final String platform; // 'android' | 'ios'
  final double cognitiveDebt;
  final double cognitiveLoadPct;
  final double wmCapacityRemaining;
  final double residueAtEOD;
  final double totalScreenTime; // hours
  final int totalSwitches;
  final int totalPickups;
  final double switchVelocityPeak;
  final CategoryBreakdown categoryBreakdown;
  // Peak hour defaults to 0 if there are no events to match desktop parity.
  final int peakLoadHour; // 0–23
  final List<double> hourlyLoad; // 24-element 0–100
  final String lastUpdated; // ISO timestamp
  // CRITICAL-1 FIX: break_events was missing. Cloud Function now receives
  // phone break data for recovery radar and verified break minutes.
  final List<BreakEvent> breakEvents;

  const PhoneSyncPayload({
    required this.date,
    required this.deviceId,
    required this.platform,
    required this.cognitiveDebt,
    required this.cognitiveLoadPct,
    required this.wmCapacityRemaining,
    required this.residueAtEOD,
    required this.totalScreenTime,
    required this.totalSwitches,
    required this.totalPickups,
    required this.switchVelocityPeak,
    required this.categoryBreakdown,
    required this.peakLoadHour,
    required this.hourlyLoad,
    required this.lastUpdated,
    this.breakEvents = const [],
  });

  Map<String, dynamic> toFirestore() => {
        'date': date,
        'deviceId': deviceId,
        'agentType': 'phone',
        'platform': platform,
        'cognitiveDebt': cognitiveDebt,
        'cognitiveLoadPct': cognitiveLoadPct,
        'wmCapacityRemaining': wmCapacityRemaining,
        'residueAtEOD': residueAtEOD,
        'totalScreenTime': totalScreenTime,
        'totalSwitches': totalSwitches,
        'totalPickups': totalPickups,
        'switchVelocityPeak': switchVelocityPeak,
        'categoryBreakdown': categoryBreakdown.toMap(),
        'peakLoadHour': peakLoadHour,
        'hourlyLoad': hourlyLoad,
        'lastUpdated': lastUpdated,
        // CRITICAL-1 FIX: serialise break events so Cloud Function can compute
        // recovery_verified_break_minutes and recovery_radar.recovery for phone.
        'break_events': breakEvents.map((b) => b.toMap()).toList(),
      };
}
