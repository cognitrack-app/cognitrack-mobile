/// App entry point — initialises Firebase and wires up providers.
library;

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'core/database/sqlite_store.dart';
import 'core/sync/firestore_client.dart';
import 'core/sync/sync_engine.dart';
import 'platform/android/usage_stats_collector.dart';
import 'dart:io' as io;
import 'platform/ios/manual_session_logger.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // BUG-15: initialise Firebase (and error tracking) BEFORE loading optional
  // assets. If font loading throws, Crashlytics is already running to capture
  // the failure — previously it was never initialised in that path.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Font preloading is best-effort: a network failure here is non-fatal.
  await Future.wait([
    GoogleFonts.pendingFonts([
      GoogleFonts.inter(),
      GoogleFonts.jetBrainsMono(),
    ]),
  ]).catchError((_) => <List<void>>[/* fonts are optional — fallback fonts will be used */]);

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
        syncEngine.syncNow().catchError(
          (Object e) => debugPrint('[main] initial backfill sync error: $e'),
        );
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
