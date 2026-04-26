/// SyncEngine — 15-minute batch sync of computed phone metrics to Firestore.
///
/// Sync triggers:
///   1. Periodic timer (every 15 minutes)
///   2. AppLifecycleState.paused (app goes to background)
///   3. Manual pull-to-refresh
///
/// Offline behaviour:
///   - Failed syncs are written to pending_sync SQLite table
///   - Exponential backoff: 30s → 60s → 120s → 240s (max 4 retries)
///   - Queue flushes automatically when connectivity is restored
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:intl/intl.dart';

import '../cognitive_engine/cognitive_engine.dart';
import '../cognitive_engine/models.dart';
import '../database/sqlite_store.dart';
import '../device_id.dart';
import 'firestore_client.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/widgets.dart';
import '../../platform/android/screen_on_receiver.dart';

class SyncEngine with WidgetsBindingObserver {
  final SQLiteStore _store;
  final FirestoreClient _client;
  final Connectivity _connectivity;

  Timer? _periodicTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  DateTime? _lastSyncAt;

  static const _syncIntervalMinutes = 15;

  SyncEngine({
    required SQLiteStore store,
    required FirestoreClient client,
    Connectivity? connectivity,
  })  : _store = store,
        _client = client,
        _connectivity = connectivity ?? Connectivity();

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  void start() {
    WidgetsBinding.instance.addObserver(this);
    // 15-minute periodic sync
    _periodicTimer = Timer.periodic(
      const Duration(minutes: _syncIntervalMinutes),
      (_) => syncNow(),
    );

    // Sync when connectivity is restored
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) _flushPendingQueue();
    });
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
    _periodicTimer?.cancel();
    _connectivitySub?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // didChangeAppLifecycleState cannot be async, so we attach an error
      // handler inline. An unhandled exception inside syncNow() would otherwise
      // become an uncaught zone error crashing the dart:async error handler.
      syncNow().catchError(
        (Object e, StackTrace st) =>
            debugPrint('[SyncEngine] paused sync error: $e\n$st'),
      );
    }
  }

  DateTime? get lastSyncAt => _lastSyncAt;

  // ── Main sync flow ────────────────────────────────────────────────────────

  /// Compute today's metrics from local SQLite events and push to Firestore.
  /// Called by timer, lifecycle paused, and manual refresh.
  Future<void> syncNow() async {
    if (!_client.isAuthenticated) return;

    final today = _todayDate();

    try {
      final payload = await _buildPayload(today);

      // ✅ ALWAYS persist locally first, regardless of Firestore outcome
      await _store.upsertDailyMetrics(_payloadToMetricsRow(payload));

      await _client.writePhoneMetrics(payload);

      // Mark as synced in local DB
      await _store.markSynced(today);
      _lastSyncAt = DateTime.now();

      // Also update device lastSeen
      await _client.updateDeviceLastSeen(payload.deviceId);

      // Flush any pending queue items now that we're online
      await _flushPendingQueue();
    } catch (e) {
      // Offline or transient error — enqueue for retry
      await _enqueuePendingSync(today);
    }
  }

  // ── Payload builder ───────────────────────────────────────────────────────

  Future<PhoneSyncPayload> _buildPayload(String date) async {
    final events = await _store.getEventsForDate(date);
    final report = await compute(calculateCognitiveDebt, events);

    // Compute phone-specific extras
    final totalSwitches =
        events.where((e) => e.eventType == EventType.switch_).length;
    final totalPickups = await ScreenOnReceiver().getTodayPickupCount();

    // Switch velocity peak (busiest 5-min window)
    final switchEvents =
        events.where((e) => e.eventType == EventType.switch_).toList();

    // Scan all 5-min windows and keep the maximum
    double velocityPeak = 0.0;
    int left = 0;
    for (int right = 0; right < switchEvents.length; right++) {
      while (switchEvents[right].timestamp - switchEvents[left].timestamp > 300000) {
        left++;
      }
      final count = right - left + 1;
      final v = count / 5.0;
      if (v > velocityPeak) velocityPeak = v;
    }

    // Total screen time (sum of durationMs for all events → hours)
    final totalMs = events.fold<int>(0, (sum, e) => sum + e.durationMs);
    final totalScreenTime = totalMs / 3600000.0;

    // Category breakdown (% of screen time per category)
    final breakdown = _computeCategoryBreakdown(events, totalMs);

    final deviceId = await _getDeviceId();

    return PhoneSyncPayload(
      date: date,
      deviceId: deviceId,
      platform: io.Platform.isAndroid ? 'android' : 'ios',
      cognitiveDebt: report.cognitiveDebt,
      cognitiveLoadPct: report.cognitiveLoadPct,
      wmCapacityRemaining: report.wmCapacityRemaining,
      residueAtEOD: report.residueAtEOD,
      totalScreenTime: totalScreenTime,
      totalSwitches: totalSwitches,
      totalPickups: totalPickups,
      switchVelocityPeak: velocityPeak,
      categoryBreakdown: breakdown,
      peakLoadHour: report.peakLoadHour,
      hourlyLoad: report.hourlyDebt,
      lastUpdated: DateTime.now().toUtc().toIso8601String(),
    );
  }

  CategoryBreakdown _computeCategoryBreakdown(
    List<AppEvent> events,
    int totalMs,
  ) {
    if (totalMs == 0) {
      return const CategoryBreakdown(
          productive: 0, entertainment: 0, social: 0, passiveWaste: 0);
    }

    final msPerCategory = <Category, int>{};
    for (final e in events) {
      msPerCategory[e.category] =
          (msPerCategory[e.category] ?? 0) + e.durationMs;
    }

    double pct(Category c) =>
        ((msPerCategory[c] ?? 0) / totalMs * 100).clamp(0, 100);

    return CategoryBreakdown(
      productive: pct(Category.productive),
      entertainment: pct(Category.entertainment),
      social: pct(Category.social),
      passiveWaste: pct(Category.passiveWaste),
    );
  }

  // ── Pending queue ─────────────────────────────────────────────────────────

  Future<void> _enqueuePendingSync(String date) async {
    try {
      final existing = await _store.getPendingSyncForDate(date);
      if (existing != null) return;

      final payload = await _buildPayload(date);
      await _store.enqueuePendingSync(PendingSyncRow(
        date: date,
        payload: jsonEncode(payload.toFirestore()),
        retryCount: 0,
        nextRetryAt:
            DateTime.now().millisecondsSinceEpoch + 30000, // first retry in 30s
      ));
    } catch (e, st) {
      debugPrint('[SyncEngine] _enqueuePendingSync failed: $e\n$st');
    }
  }

  Future<void> _flushPendingQueue() async {
    if (!_client.isAuthenticated) return;

    final pending = await _store.getReadyPendingSyncs();
    for (final row in pending) {
      if (row.retryCount >= 4) {
        // Max retries exceeded — drop
        if (row.id != null) await _store.deletePendingSync(row.id!);
        continue;
      }

      try {
        final firestoreMap =
            Map<String, dynamic>.from(jsonDecode(row.payload) as Map);
        final payload = PhoneSyncPayload(
          date: firestoreMap['date'] as String,
          deviceId: firestoreMap['deviceId'] as String,
          platform: firestoreMap['platform'] as String,
          cognitiveDebt: (firestoreMap['cognitiveDebt'] as num).toDouble(),
          cognitiveLoadPct:
              (firestoreMap['cognitiveLoadPct'] as num).toDouble(),
          wmCapacityRemaining:
              (firestoreMap['wmCapacityRemaining'] as num).toDouble(),
          residueAtEOD: (firestoreMap['residueAtEOD'] as num).toDouble(),
          totalScreenTime: (firestoreMap['totalScreenTime'] as num).toDouble(),
          totalSwitches: firestoreMap['totalSwitches'] as int,
          totalPickups: firestoreMap['totalPickups'] as int,
          switchVelocityPeak:
              (firestoreMap['switchVelocityPeak'] as num).toDouble(),
          categoryBreakdown: CategoryBreakdown.fromMap(
              firestoreMap['categoryBreakdown'] as Map<String, dynamic>),
          peakLoadHour: firestoreMap['peakLoadHour'] as int,
          hourlyLoad: (firestoreMap['hourlyLoad'] as List)
              .map((e) => (e as num).toDouble())
              .toList(),
          lastUpdated: firestoreMap['lastUpdated'] as String,
        );

        await _client.writePhoneMetrics(payload);
        if (row.id != null) await _store.deletePendingSync(row.id!);
        await _store.markSynced(row.date);
        _lastSyncAt = DateTime.now();
      } catch (e, st) {
        debugPrint('[SyncEngine] _flushPendingQueue retry failed: $e\n$st');
        // Increment retry count with backoff
        if (row.id != null) {
          final backoffMs =
              30000 * (1 << row.retryCount); // 30s, 60s, 120s, 240s
          await _store.updatePendingSyncRetry(
            row.id!,
            row.retryCount + 1,
            nextRetryAt: DateTime.now().millisecondsSinceEpoch + backoffMs,
          );
        }
      }
    }
  }

  // ── Device registration ────────────────────────────────────────────────────

  /// Register device on first launch. Safe to call on every launch (idempotent).
  Future<void> registerDevice() async {
    if (!_client.isAuthenticated) return;

    final deviceId = await _getDeviceId();
    await _client.registerDevice(
      deviceId: deviceId,
      platform: io.Platform.isAndroid ? 'android' : 'ios',
      displayName:
          '${io.Platform.isAndroid ? 'Android' : 'iPhone'} (${io.Platform.localHostname})',
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _todayDate() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  String? _cachedDeviceId;

  Future<String> _getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;
    final info = DeviceInfoPlugin();
    String rawId;
    if (io.Platform.isAndroid) {
      final android = await info.androidInfo;
      rawId = android.id; // Android Settings.Secure.ANDROID_ID
    } else {
      final ios = await info.iosInfo;
      rawId = ios.identifierForVendor ?? 'unknown-ios';
    }
    _cachedDeviceId = computeDeviceId(rawId);
    return _cachedDeviceId!;
  }

  DailyMetricsRow _payloadToMetricsRow(PhoneSyncPayload p) => DailyMetricsRow(
        date: p.date,
        cognitiveDebt: p.cognitiveDebt,
        cognitiveLoadPct: p.cognitiveLoadPct,
        wmCapacityRemaining: p.wmCapacityRemaining,
        residueAtEOD: p.residueAtEOD,
        totalSwitches: p.totalSwitches,
        totalPickups: p.totalPickups,
        totalScreenTime: p.totalScreenTime,
        switchVelocityPeak: p.switchVelocityPeak,
        peakLoadHour: p.peakLoadHour,
        hourlyLoad: jsonEncode(p.hourlyLoad),
        categoryBreakdown: jsonEncode(p.categoryBreakdown.toMap()),
        synced: 0,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
}
