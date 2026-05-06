/// App entry point — initialises Firebase and wires up providers.
library;

import 'dart:async';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'core/database/sqlite_store.dart';
import 'core/mock/mock_data_seeder.dart';
import 'core/sync/firestore_client.dart';
import 'core/sync/sync_engine.dart';
import 'platform/android/usage_stats_collector.dart';
import 'dart:io' as io;
import 'platform/ios/manual_session_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise Firebase FIRST so Crashlytics is active before any other work.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Wire up Crashlytics to capture all uncaught Flutter and platform errors.
  // FlutterError.onError catches errors thrown inside Flutter framework callbacks
  // (build, layout, painting). PlatformDispatcher.onError catches errors thrown
  // outside the Flutter framework (isolates, platform channels, async gaps).
  if (!kDebugMode) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  // Google Fonts: remove CDN pre-fetch — fonts are resolved from cache or
  // system fallback at paint time. The pendingFonts() network call added
  // latency on every cold start and silently failed on first offline launch.
  // Fonts are loaded on-demand by the google_fonts package with disk caching.

  // Bootstrap core services
  final store = SQLiteStore();
  final firestoreClient = FirestoreClient();
  final syncEngine = SyncEngine(store: store, client: firestoreClient);

  // BUG-14: register auth listener BEFORE start() so the connectivity-restore
  // path inside start() cannot fire _flushPendingQueue() before device
  // registration has been attempted.
  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null) {
      // ignore: unawaited_futures — intentional fire-and-forget
      syncEngine.registerDevice().catchError((Object e, StackTrace st) {
        debugPrint('[main] registerDevice failed: $e\n$st');
      });
    }
  });

  // Start 15-minute sync timer after the auth listener is wired up.
  syncEngine.start();

  // AUTO-SEED: In debug builds, automatically seed 14 days of mock data on
  // every cold start so the UI is never empty during development or demos.
  // Uses ConflictAlgorithm.replace — safe to call on every launch.
  if (kDebugMode) {
    try {
      await MockDataSeeder(store: store).seed();
      debugPrint('[main] ✅ Auto-seeded 14 days of mock data.');
    } catch (e) {
      debugPrint('[main] Mock data seed failed (non-fatal): $e');
    }
  }

  if (io.Platform.isAndroid) {
    final collector = UsageStatsCollector();
    collector.setUsageEventsHandler((events) async {
      for (final event in events) {
        await store.insertEvent(RawEventInsert(
          timestamp: event.timestamp,
          appId: event.appId,
          category: event.category.name,
          eventType: event.eventType.name,
          durationMs: event.durationMs,
          deviceType: event.deviceType.name,
        ));
      }
    });
    if (await collector.hasPermission()) {
      await collector.startForegroundService();

      // FUNC-03 FIX: The ForegroundService is push-only and takes up to 60 s
      // to deliver its first batch. On the first open of the day (or after a
      // restart) SQLite is empty and the dashboard shows nothing.
      //
      // Backfill events from midnight → now immediately so the dashboard has
      // real data from the first frame. Errors are non-fatal (best-effort).
      try {
        final now = DateTime.now();
        final midnight = DateTime(now.year, now.month, now.day);
        final backfillEvents = await collector.queryEvents(
          startMs: midnight.millisecondsSinceEpoch,
          endMs: now.millisecondsSinceEpoch,
        );
        for (final event in backfillEvents) {
          await store.insertEvent(RawEventInsert(
            timestamp: event.timestamp,
            appId: event.appId,
            category: event.category.name,
            eventType: event.eventType.name,
            durationMs: event.durationMs,
            deviceType: event.deviceType.name,
          ));
        }
        // Trigger an immediate sync so today's data reaches Firestore now.
        unawaited(syncEngine.syncNow().catchError(
              (Object e) =>
                  debugPrint('[main] initial backfill sync error: $e'),
            ));
      } catch (e) {
        debugPrint('[main] FUNC-03 backfill error (non-fatal): $e');
      }
    }
  } else if (io.Platform.isIOS) {
    // BUG-C: retain the instance (not created inline) so any internal timers /
    // subscriptions are not orphaned and eligible for GC. Also guard start()
    // with hasPermission(), matching the Android pattern structurally.
    final iosLogger = ManualSessionLogger(store: store);
    if (await iosLogger.hasPermission()) {
      iosLogger.start();
    }
  }

  final prefs = await SharedPreferences.getInstance();
  final hasSeenOnboarding = prefs.getBool('onboarding_done') ?? false;

  runApp(
    MultiProvider(
      providers: [
        Provider<SQLiteStore>.value(value: store),
        Provider<FirestoreClient>.value(value: firestoreClient),
        Provider<SyncEngine>.value(value: syncEngine),
      ],
      child: CogniTrackApp(
        sqliteStore: store,
        syncEngine: syncEngine,
        hasSeenOnboarding: hasSeenOnboarding,
      ),
    ),
  );
}
