/// DEMO entrypoint — pre-seeded mock data, no real Firestore writes.
///
/// Build: flutter build apk --flavor demo -t lib/main_demo.dart
/// Run:   flutter run --flavor demo -t lib/main_demo.dart
///
/// What this does differently from main_live.dart:
///   • Sets IS_DEMO = true  →  MockDataSeeder always runs on cold start
///   • SyncEngine.start() is called but syncNow() is a no-op in demo mode
///     (see sync_engine.dart — skips Firestore writes when IS_DEMO=true)
///   • Crashlytics is disabled (no noise in Firebase console from demo runs)
///   • App label: "CogniTrack Demo"  (set via productFlavor resValue)
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/database/sqlite_store.dart';
import 'core/mock/mock_data_seeder.dart';
import 'core/sync/firestore_client.dart';
import 'core/sync/sync_engine.dart';
import 'platform/android/usage_stats_collector.dart';
import 'dart:io' as io;
import 'platform/ios/manual_session_logger.dart';
import 'app.dart';
import 'firebase_options.dart';

/// Compile-time flag read by SyncEngine and MockDataSeeder.
/// true  → seed mock data, skip Firestore writes.
/// false → never used in this file (that’s main_live.dart).
const bool kIsDemo = true;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Crashlytics intentionally disabled in demo builds — no noise in console.
  // (No FlutterError.onError override here.)

  final store = SQLiteStore();
  final firestoreClient = FirestoreClient();
  final syncEngine = SyncEngine(
    store: store,
    client: firestoreClient,
    isDemo: kIsDemo, // ← SyncEngine skips all Firestore writes in demo mode
  );

  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null) {
      // Still register device so sign-in flow works, but no data writes.
      syncEngine.registerDevice().catchError((Object e, StackTrace st) {
        debugPrint('[main_demo] registerDevice failed: $e\n$st');
      });
    }
  });

  syncEngine.start();

  // Seed 14 days of mock data on every cold start so the UI is always full.
  // ConflictAlgorithm.replace — safe to call multiple times.
  try {
    await MockDataSeeder(store: store).seedAlways();
    debugPrint('[main_demo] ✅ Mock data seeded.');
  } catch (e) {
    debugPrint('[main_demo] Mock seed failed (non-fatal): $e');
  }

  // Start usage tracking so live device activity still flows into the UI
  // on top of the seeded historical data, giving a realistic live feel.
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
        // Sync today’s live usage into local SQLite (not Firestore in demo mode)
        unawaited(syncEngine.syncNow().catchError(
              (Object e) => debugPrint('[main_demo] backfill sync error: $e'),
            ));
      } catch (e) {
        debugPrint('[main_demo] backfill error (non-fatal): $e');
      }
    }
  } else if (io.Platform.isIOS) {
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
        isDemo: kIsDemo, // true → bypasses Google Sign-In in demo flavor
      ),
    ),
  );
}
