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
  
  await Future.wait([
    GoogleFonts.pendingFonts([
      GoogleFonts.inter(),
      GoogleFonts.jetBrainsMono(),
    ]),
  ]);

  // Initialise Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Bootstrap core services
  final store = SQLiteStore();
  final firestoreClient = FirestoreClient();
  final syncEngine = SyncEngine(store: store, client: firestoreClient);

  // Start 15-minute sync timer
  syncEngine.start();

  // Register device whenever user signs in
  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null) {
      // ignore: unawaited_futures — intentional fire-and-forget
      syncEngine.registerDevice().catchError((Object e, StackTrace st) {
        debugPrint('[main] registerDevice failed: $e\n$st');
      });
    }
  });

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
    }
  } else if (io.Platform.isIOS) {
    ManualSessionLogger(store: store).start();
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
