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
// ignore_for_file: unawaited_futures
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../cognitive_engine/cognitive_engine.dart';
import '../cognitive_engine/models.dart';
import '../cognitive_engine/break_extractor.dart'; // CRITICAL-1 FIX
import '../cognitive_engine/constants.dart'; // schema version
import '../database/sqlite_store.dart';
import '../device_id.dart';
import 'firestore_client.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/widgets.dart';
import '../../platform/android/screen_on_receiver.dart';

/// Sync health metrics for observability
class SyncHealthMetrics {
  final DateTime? lastSyncAt;
  final DateTime? lastSyncAttemptAt;
  final int pendingQueueSize;
  final int failedSyncCount;
  final int totalSyncsToday;
  final int successfulSyncsToday;
  final Duration? lastSyncDuration;
  final String? lastError;
  final bool isOnline;
  final bool isSyncing;

  const SyncHealthMetrics({
    this.lastSyncAt,
    this.lastSyncAttemptAt,
    required this.pendingQueueSize,
    required this.failedSyncCount,
    required this.totalSyncsToday,
    required this.successfulSyncsToday,
    this.lastSyncDuration,
    this.lastError,
    required this.isOnline,
    required this.isSyncing,
  });

  Map<String, dynamic> toJson() => {
        'lastSyncAt': lastSyncAt?.toIso8601String(),
        'lastSyncAttemptAt': lastSyncAttemptAt?.toIso8601String(),
        'pendingQueueSize': pendingQueueSize,
        'failedSyncCount': failedSyncCount,
        'totalSyncsToday': totalSyncsToday,
        'successfulSyncsToday': successfulSyncsToday,
        'lastSyncDurationMs': lastSyncDuration?.inMilliseconds,
        'lastError': lastError,
        'isOnline': isOnline,
        'isSyncing': isSyncing,
      };
}

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
class SyncEngine with WidgetsBindingObserver {
  final SQLiteStore _store;
  final FirestoreClient _client;
  final Connectivity _connectivity;
  // BUG-05 / BUG-16: inject singleton — not constructed per-sync
  final ScreenOnReceiver _screenOnReceiver;

  Timer? _periodicTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  DateTime? _lastSyncAt;
  DateTime? _lastSyncAttemptAt;
  Duration? _lastSyncDuration;
  String? _lastError;
  int _successfulSyncsToday = 0;
  int _totalSyncsToday = 0;
  String? _lastSyncDate;
  // B1 FIX: guard against concurrent syncNow() calls.
  // The 15-min timer, AppLifecycleState.paused, connectivity-restore, and
  // manual refresh() can all fire simultaneously. Without this flag,
  // _flushPendingQueue() is entered concurrently and fires duplicate Firestore
  // writes + races on _store.deletePendingSync(row.id!).
  bool _isSyncing = false;

  // demo mode — set to true by main_demo.dart via the isDemo constructor param.
  // When true, syncNow() and _flushPendingQueue() are no-ops so no real data
  // is ever written to Firestore during a demo run.
  final bool _isDemo;

  static const _syncIntervalMinutes = 15;

  // Metrics stream controller for real-time observability
  final _metricsController = StreamController<SyncHealthMetrics>.broadcast();

  SyncEngine({
    required SQLiteStore store,
    required FirestoreClient client,
    Connectivity? connectivity,
    ScreenOnReceiver? screenOnReceiver,
    bool isDemo = false,
  })  : _store = store,
        _client = client,
        _connectivity = connectivity ?? Connectivity(),
        _screenOnReceiver = screenOnReceiver ?? ScreenOnReceiver(),
        _isDemo = isDemo;

  /// Stream of sync health metrics for observability / debugging UI
  Stream<SyncHealthMetrics> get metricsStream => _metricsController.stream;

  /// Current sync health snapshot
  Future<SyncHealthMetrics> getMetrics() async {
    final pending = await _store.getReadyPendingSyncs();
    final allPending = await _store.getAllPendingSyncs();
    final failedCount = allPending.where((r) => r.retryCount >= 4).length;

    // Check actual connectivity, not just that _connectivity object exists
    final connectivityResults = await _connectivity.checkConnectivity();
    final hasConnection = connectivityResults.any((r) => r != ConnectivityResult.none);

    return SyncHealthMetrics(
      lastSyncAt: _lastSyncAt,
      lastSyncAttemptAt: _lastSyncAttemptAt,
      pendingQueueSize: pending.length,
      failedSyncCount: failedCount,
      totalSyncsToday: _totalSyncsToday,
      successfulSyncsToday: _successfulSyncsToday,
      lastSyncDuration: _lastSyncDuration,
      lastError: _lastError,
      isOnline: _client.isAuthenticated && hasConnection,
      isSyncing: _isSyncing,
    );
  }

  void _emitMetrics() {
    getMetrics().then(_metricsController.add).catchError((e) {
      debugPrint('[SyncEngine] Failed to emit metrics: $e');
    });
  }

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
      if (hasConnection) unawaited(_flushPendingQueue());
    });
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
    _periodicTimer?.cancel();
    _connectivitySub?.cancel();
    _metricsController.close();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // didChangeAppLifecycleState cannot be async, so we attach an error
      // handler inline. An unhandled exception inside syncNow() would otherwise
      // become an uncaught zone error crashing the dart:async error handler.
      unawaited(syncNow().catchError(
        (Object e, StackTrace st) =>
            debugPrint('[SyncEngine] paused sync error: $e\n$st'),
      ));
    }
  }

  DateTime? get lastSyncAt => _lastSyncAt;

  // ── Main sync flow ────────────────────────────────────────────────────────

  /// Compute today's metrics from local SQLite events and push to Firestore.
  /// Called by timer, lifecycle paused, and manual refresh.
  /// No-op in demo mode — metrics are pre-seeded, no Firestore writes needed.
  Future<void> syncNow() async {
    // Demo guard: skip all Firestore writes in demo flavor.
    if (_isDemo) {
      debugPrint('[SyncEngine] demo mode — syncNow() skipped.');
      return;
    }
    // B1 FIX: early-exit if a sync is already in progress.
    if (!_client.isAuthenticated || _isSyncing) return;
    _isSyncing = true;
    _emitMetrics();

    final today = _todayDate();
    final syncStart = DateTime.now();

    // Reset daily counters on day rollover
    if (_lastSyncDate != null && _lastSyncDate != today) {
      _successfulSyncsToday = 0;
      _totalSyncsToday = 0;
    }
    _totalSyncsToday++;

    // DAY ROLLOVER FIX: Reset pickup counter at midnight regardless of sync success.
    // The Kotlin BroadcastReceiver increments pickups continuously; if the device
    // is offline at midnight, the counter would never reset, causing next day's
    // pickups to be counted under the previous day. Check and reset here before
    // building the payload so the correct daily count is used.
    if (io.Platform.isAndroid &&
        _lastSyncDate != null &&
        _lastSyncDate != today) {
      debugPrint('[SyncEngine] Day rollover detected: $_lastSyncDate → $today, resetting pickup counter');
      await _screenOnReceiver.resetCounter().catchError(
        (Object e) => debugPrint('[SyncEngine] resetCounter failed: $e'),
      );
    }
    _lastSyncDate = today;

    // Build payload once. On Firestore failure, pass this same object to
    // _enqueuePendingSync so the retry queue always matches local DB state.
    // (BUG-B: avoids a second _buildPayload() call that races new events)
    PhoneSyncPayload? payload;
    try {
      payload = await _buildPayload(today);

      // H1 FIX: guard against writing an all-zero row on fresh install.
      // On first launch mid-day, getEventsForDate() returns [] because the
      // foreground service hasn't collected anything yet. Upserting a zero
      // row would overwrite any existing Firestore data for today with zeros.
      // Skip the upsert entirely and let the next 15-min tick do it properly.
      if (payload.totalSwitches == 0 && payload.totalScreenTime < 0.001) {
        debugPrint('[SyncEngine] no events yet — skipping zero upsert.');
        _lastSyncAttemptAt = DateTime.now();
        _lastSyncDuration = DateTime.now().difference(syncStart);
        _emitMetrics();
        return;
      }

      // ✅ ALWAYS persist locally first, regardless of Firestore outcome
      await _store.upsertDailyMetrics(_payloadToMetricsRow(payload));

      await _client.writePhoneMetrics(payload);

      // Mark as synced in local DB
      await _store.markSynced(today);
      _lastSyncAt = DateTime.now();
      _lastSyncAttemptAt = DateTime.now();
      _lastSyncDuration = DateTime.now().difference(syncStart);
      _lastError = null;
      _successfulSyncsToday++;

      // Also update device lastSeen
      await _client.updateDeviceLastSeen(payload.deviceId);

      // Flush any pending queue items now that we're online
      await _flushPendingQueue();
    } catch (e) {
      // Offline or transient error — enqueue the already-built payload.
      // If _buildPayload itself threw, payload is null and _enqueuePendingSync
      // will log + return without crashing.
      _lastSyncAttemptAt = DateTime.now();
      _lastSyncDuration = DateTime.now().difference(syncStart);
      _lastError = e.toString();
      await _enqueuePendingSync(today, prebuiltPayload: payload);
    } finally {
      // B1 FIX: always release the guard, even on exception.
      _isSyncing = false;
      _emitMetrics();
    }
  }

  // ── Payload builder ───────────────────────────────────────────────────────

  Future<PhoneSyncPayload> _buildPayload(String date) async {
    final events = await _store.getEventsForDate(date);
    final report = calculateCognitiveDebt(events);

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
          fiveMinMs) {
        left++;
      }
      final count = right - left + 1;
      final v = count / 5.0;
      if (v > velocityPeak) velocityPeak = v;
    }

    // Total screen time (sum of durationMs for all events → hours)
    final totalMs = events.fold<int>(0, (sum, e) => sum + e.durationMs);
    final totalScreenTime = totalMs / 3600000.0;

    // Category breakdown denominator: only switch events (active intent), matching desktop batchProcessor.ts
    final switchMs = events
        .where((e) => e.eventType == EventType.switch_)
        .fold<int>(0, (sum, e) => sum + e.durationMs);
    final breakdown = _computeCategoryBreakdown(events, switchMs);

    // CRITICAL-1 FIX: extract break events from idle markers so the Cloud
    // Function can compute recovery_verified_break_minutes and recovery radar.
    final breakEvents = extractBreakEvents(events, report.hourlyDebt);

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
      breakEvents: breakEvents, // CRITICAL-1 FIX
      schemaVersion: syncPayloadSchemaVersion,
    );
  }

  CategoryBreakdown _computeCategoryBreakdown(
    List<AppEvent> events,
    int switchMs,
  ) {
    if (switchMs == 0) {
      return const CategoryBreakdown(
        productive: 0, tools: 0, entertainment: 0, social: 0, passiveWaste: 0);
    }

    final msPerCategory = <Category, int>{};
    for (final e in events) {
      if (e.eventType != EventType.switch_) continue;
      msPerCategory[e.category] =
          (msPerCategory[e.category] ?? 0) + e.durationMs;
    }

    // Tools apps (Terminal, Settings, IDE) are cognitively active.
    // Keep tools as a separate category to match desktop DesktopCategoryBreakdown (5 categories).
    // This ensures cross-platform parity for fragmentation and category analysis.
    // Only switch events are counted (active intent), matching desktop batchProcessor.ts.
    final toolsMs = msPerCategory[Category.tools] ?? 0;
    final productiveMs = msPerCategory[Category.productive] ?? 0;

    // Compute raw percentages
    double rawPct(int ms) => (ms / switchMs * 100);

    final rawProductive = rawPct(productiveMs);
    final rawTools = rawPct(toolsMs);
    final rawEntertainment = rawPct(msPerCategory[Category.entertainment] ?? 0);
    final rawSocial = rawPct(msPerCategory[Category.social] ?? 0);

    // ROUNDING FIX: Use floor for first four categories, let passiveWaste absorb remainder
    // so the sum is always exactly 100. Matches desktop batchProcessor.ts logic.
    final productive = rawProductive.floor();
    final tools = rawTools.floor();
    final entertainment = rawEntertainment.floor();
    final social = rawSocial.floor();
    final passiveWaste = 100 - productive - tools - entertainment - social;

    return CategoryBreakdown(
      productive: productive.toDouble(),
      tools: tools.toDouble(),
      entertainment: entertainment.toDouble(),
      social: social.toDouble(),
      passiveWaste: passiveWaste.toDouble(),
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
              backoffBaseMs, // first retry in 30s
        ));
      }
    } catch (e, st) {
      debugPrint('[SyncEngine] _enqueuePendingSync failed: $e\n$st');
    }
  }

  Future<void> _flushPendingQueue() async {
    // Demo guard: never flush the offline queue in demo mode.
    if (_isDemo) return;
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

        // SCHEMA MIGRATION: Handle older payload versions gracefully.
        // v1 payloads won't have schemaVersion or break_events.
        // Default schemaVersion to 1 for backward compatibility.
        final schemaVersion =
            (firestoreMap['schemaVersion'] as num?)?.toInt() ?? 1;

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
          // Peak load hour defaults to 0
          peakLoadHour: (firestoreMap['peakLoadHour'] as num?)?.toInt() ?? 0,
          hourlyLoad: (firestoreMap['hourlyLoad'] as List)
              .map((e) => (e as num).toDouble())
              .toList(),
          lastUpdated: firestoreMap['lastUpdated'] as String,
          breakEvents: schemaVersion >= 2
              ? (firestoreMap['break_events'] as List? ?? [])
                  .map((b) => BreakEvent(
                        startTime: b['start_time'] as String,
                        endTime: b['end_time'] as String,
                        activityType: b['activity_type'] as String,
                        durationMinutes: (b['duration_minutes'] as num).toInt(),
                        debtBefore: (b['debt_before'] as num).toDouble(),
                        debtAfter: (b['debt_after'] as num).toDouble(),
                        ptsRecovered: (b['pts_recovered'] as num).toDouble(),
                        efficiencyPct: (b['efficiency_pct'] as num).toInt(),
                      ))
                  .toList()
              : const [],
          schemaVersion: schemaVersion,
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
              backoffBaseMs * (1 << row.retryCount); // 30s, 60s, 120s, 240s
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

  // Secure storage for iOS fallback device ID (survives app reinstall, backup/restore)
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );
  static const _fallbackKey = 'cognitrack_fallback_device_uuid';
  // App Group identifier for cross-extension data sharing (iOS)
  // Must match the App Group configured in Xcode (e.g., "group.cognitrack")
  static const _appGroupId = 'group.cognitrack';
  static const _fallbackKeyAppGroup = 'cognitrack_fallback_device_uuid_appgroup';

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
      // Fall back to a persistent random UUID stored in Keychain so every
      // device gets a unique ID rather than all colliding on the same
      // SHA-256('unknown-ios'). Keychain survives app reinstall and backup/restore.
      final idfv = ios.identifierForVendor;
      if (idfv != null && idfv.isNotEmpty) {
        rawId = idfv;
      } else {
        // Try App Group first (shared with DeviceActivityMonitorExtension)
        var stored = await _secureStorage.read(key: _fallbackKeyAppGroup, aOptions: AndroidOptions(encryptedSharedPreferences: true), iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device));
        if (stored == null) {
          // Fall back to main app Keychain
          stored = await _secureStorage.read(key: _fallbackKey);
        }
        if (stored == null) {
          stored = const Uuid().v4();
          // Write to both App Group (for extension access) and main Keychain
          await _secureStorage.write(key: _fallbackKeyAppGroup, value: stored, aOptions: AndroidOptions(encryptedSharedPreferences: true), iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device));
          await _secureStorage.write(key: _fallbackKey, value: stored);
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