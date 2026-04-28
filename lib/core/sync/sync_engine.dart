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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

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
  // BUG-05 / BUG-16: inject singleton — not constructed per-sync
  final ScreenOnReceiver _screenOnReceiver;

  Timer? _periodicTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  DateTime? _lastSyncAt;
  // FUNC-09: track the last date we synced so we can detect a day rollover
  // and reset the Android pickup counter at midnight.
  String? _lastSyncDate;

  // B1 FIX: guard against concurrent syncNow() calls.
  // The 15-min timer, AppLifecycleState.paused, connectivity-restore, and
  // manual refresh() can all fire simultaneously. Without this flag,
  // _flushPendingQueue() is entered concurrently and fires duplicate Firestore
  // writes + races on _store.deletePendingSync(row.id!).
  bool _isSyncing = false;

  static const _syncIntervalMinutes = 15;

  SyncEngine({
    required SQLiteStore store,
    required FirestoreClient client,
    Connectivity? connectivity,
    ScreenOnReceiver? screenOnReceiver,
  })  : _store = store,
        _client = client,
        _connectivity = connectivity ?? Connectivity(),
        _screenOnReceiver = screenOnReceiver ?? ScreenOnReceiver();

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
    // B1 FIX: early-exit if a sync is already in progress.
    if (!_client.isAuthenticated || _isSyncing) return;
    _isSyncing = true;

    final today = _todayDate();
    // Build payload once. On Firestore failure, pass this same object to
    // _enqueuePendingSync so the retry queue always matches local DB state.
    // (BUG-B: avoids a second _buildPayload() call that races new events)
    PhoneSyncPayload? payload;
    try {
      payload = await _buildPayload(today);

      // ✅ ALWAYS persist locally first, regardless of Firestore outcome
      await _store.upsertDailyMetrics(_payloadToMetricsRow(payload));

      await _client.writePhoneMetrics(payload);

      // Mark as synced in local DB
      await _store.markSynced(today);
      _lastSyncAt = DateTime.now();

      // FUNC-09 FIX: resetCounter() is documented as "called at midnight" but
      // was never called anywhere in Dart. The Kotlin BroadcastReceiver grows
      // totalPickups indefinitely across days. Reset it on the first sync
      // after midnight so each day's count starts fresh.
      if (io.Platform.isAndroid &&
          _lastSyncDate != null &&
          _lastSyncDate != today) {
        _screenOnReceiver.resetCounter().catchError(
              (Object e) => debugPrint('[SyncEngine] resetCounter failed: $e'),
            );
      }
      _lastSyncDate = today;

      // Also update device lastSeen
      await _client.updateDeviceLastSeen(payload.deviceId);

      // Flush any pending queue items now that we're online
      await _flushPendingQueue();
    } catch (e) {
      // Offline or transient error — enqueue the already-built payload.
      // If _buildPayload itself threw, payload is null and _enqueuePendingSync
      // will log + return without crashing.
      await _enqueuePendingSync(today, prebuiltPayload: payload);
    } finally {
      // B1 FIX: always release the guard, even on exception.
      _isSyncing = false;
    }
  }

  // ── Payload builder ───────────────────────────────────────────────────────

  Future<PhoneSyncPayload> _buildPayload(String date) async {
    final events = await _store.getEventsForDate(date);
    final report = await compute(calculateCognitiveDebt, events);

    // Compute phone-specific extras
    final totalSwitches =
        events.where((e) => e.eventType == EventType.switch_).length;
    // BUG-05: reuse injected singleton — no new channel handle per sync
    final totalPickups = await _screenOnReceiver.getTodayPickupCount();

    // Switch velocity peak (busiest 5-min window)
    final switchEvents =
        events.where((e) => e.eventType == EventType.switch_).toList();

    // Scan all 5-min windows and keep the maximum
    double velocityPeak = 0.0;
    int left = 0;
    for (int right = 0; right < switchEvents.length; right++) {
      while (switchEvents[right].timestamp - switchEvents[left].timestamp >
          300000) {
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

    // AND-16 FIX: Category.tools events contribute to totalMs (denominator)
    // but appeared in NONE of the four CategoryBreakdown fields. On a developer
    // device this silently deflates all percentages (sum could be 60-70%).
    //
    // Tools apps (Terminal, Settings, IDE) are cognitively active but not
    // "productive content" in the phone usage sense. We fold them into the
    // productive bucket (consistent with desktop batchProcessor which adds
    // tools to totalFocusedMs). This ensures the four fields always sum to
    // 100% and tools time is not silently discarded.
    final toolsMs = msPerCategory[Category.tools] ?? 0;
    final productiveMs = (msPerCategory[Category.productive] ?? 0) + toolsMs;

    // Compute percentages using the original totalMs as denominator so the
    // absolute screen time proportions are preserved.
    double pct(int ms) => (ms / totalMs * 100).clamp(0, 100);

    return CategoryBreakdown(
      productive: pct(productiveMs),
      entertainment: pct(msPerCategory[Category.entertainment] ?? 0),
      social: pct(msPerCategory[Category.social] ?? 0),
      passiveWaste: pct(msPerCategory[Category.passiveWaste] ?? 0),
    );
  }

  // ── Pending queue ─────────────────────────────────────────────────────────

  /// Enqueue [date]'s metrics for offline retry.
  ///
  /// [prebuiltPayload] should be passed whenever the payload was already
  /// computed by the calling path (BUG-B: avoids a second _buildPayload()
  /// that races new events inserted between the two builds).
  Future<void> _enqueuePendingSync(
    String date, {
    PhoneSyncPayload? prebuiltPayload,
  }) async {
    try {
      // B2 FIX: always persist the *latest* payload.
      // Previously, if an entry already existed (e.g. device went offline at
      // 09:00 and stayed offline until 18:00), we returned early and the queue
      // permanently held stale 09:00 data, losing 9 hours of events.
      // Now we upsert: insert on first failure, UPDATE on every subsequent one.
      final payload = prebuiltPayload ?? await _buildPayload(date);
      final serialised = jsonEncode(payload.toFirestore());

      final existing = await _store.getPendingSyncForDate(date);
      if (existing != null) {
        // Replace the stale payload with the fresher one; keep retryCount/backoff.
        await _store.updatePendingSyncPayload(existing.id!, serialised);
      } else {
        await _store.enqueuePendingSync(PendingSyncRow(
          date: date,
          payload: serialised,
          retryCount: 0,
          nextRetryAt: DateTime.now().millisecondsSinceEpoch +
              30000, // first retry in 30s
        ));
      }
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
          // BUG-01: Firestore returns num (possibly double); use .toInt()
          totalSwitches: (firestoreMap['totalSwitches'] as num).toInt(),
          totalPickups: (firestoreMap['totalPickups'] as num).toInt(),
          switchVelocityPeak:
              (firestoreMap['switchVelocityPeak'] as num).toDouble(),
          categoryBreakdown: CategoryBreakdown.fromMap(
              firestoreMap['categoryBreakdown'] as Map<String, dynamic>),
          // BUG-08: peakLoadHour is int? — JSON value may be null on no-event days.
          peakLoadHour: (firestoreMap['peakLoadHour'] as num?)?.toInt(),
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

    // B6 FIX: Platform.localHostname leaks a user-identifiable string
    // (e.g. "gaurav-galaxy-s24"). Use the model number only — no username.
    String displayName;
    if (io.Platform.isAndroid) {
      final android = await DeviceInfoPlugin().androidInfo;
      displayName = 'Android ${android.model}';
    } else {
      final ios = await DeviceInfoPlugin().iosInfo;
      displayName = 'iPhone ${ios.utsname.machine}';
    }

    await _client.registerDevice(
      deviceId: deviceId,
      platform: io.Platform.isAndroid ? 'android' : 'ios',
      displayName: displayName,
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
      // BUG-03: identifierForVendor is null after factory reset / MDM.
      // Fall back to a persistent random UUID so every device gets a unique
      // ID rather than all colliding on the same SHA-256('unknown-ios').
      final idfv = ios.identifierForVendor;
      if (idfv != null && idfv.isNotEmpty) {
        rawId = idfv;
      } else {
        const prefKey = 'cognitrack_fallback_device_uuid';
        final prefs = await SharedPreferences.getInstance();
        var stored = prefs.getString(prefKey);
        if (stored == null) {
          stored = const Uuid().v4();
          await prefs.setString(prefKey, stored);
        }
        rawId = stored;
      }
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
