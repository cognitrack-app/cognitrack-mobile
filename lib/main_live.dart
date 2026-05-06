/// LIVE entrypoint — real Firestore data, release-signed, production build.
///
/// Build: flutter build apk --flavor live -t lib/main_live.dart --release
/// Run:   flutter run  --flavor live -t lib/main_live.dart
///
/// What this does differently from main_demo.dart:
///   • Sets IS_DEMO = false  →  MockDataSeeder is NEVER called
///   • SyncEngine writes real data to Firestore every 15 minutes
///   • Crashlytics is fully active for production crash reporting
///   • App label: "CogniTrack"  (set via productFlavor resValue)
library;

import 'dart:async';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/database/sqlite_store.dart';
import 'core/sync/firestore_client.dart';
import 'core/sync/sync_engine.dart';
import 'platform/android/usage_stats_collector.dart';
import 'dart:io' as io;
import 'platform/ios/manual_session_logger.dart';
import 'app.dart';
import 'firebase_options.dart';

/// Compile-time flag. Always false in live builds.
/// MockDataSeeder checks this and is never instantiated here.
const bool kIsDemo = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Crashlytics fully active in live/release builds.
  if (!kDebugMode) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  final store = SQLiteStore();
  final firestoreClient = FirestoreClient();
  final syncEngine = SyncEngine(
    store: store,
    client: firestoreClient,
    isDemo: kIsDemo, // false → full Firestore writes enabled
  );

  // BUG-14: register auth listener BEFORE start() so device registration
  // happens before connectivity-restore can fire _flushPendingQueue().
  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null) {
      syncEngine.registerDevice().catchError((Object e, StackTrace st) {
        debugPrint('[main_live] registerDevice failed: $e\n$st');
      });
    }
  });

  syncEngine.start();

  // No MockDataSeeder — only real device data.

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

      // FUNC-03 FIX: Backfill today’s events from midnight → now immediately
      // so the dashboard is not empty on first open.
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
        unawaited(syncEngine.syncNow().catchError(
              (Object e) =>
                  debugPrint('[main_live] initial backfill sync error: $e'),
            ));
      } catch (e) {
        debugPrint('[main_live] FUNC-03 backfill error (non-fatal): $e');
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
        isDemo: kIsDemo, // false → real Google Sign-In enabled
      ),
    ),
  );
}
