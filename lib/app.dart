/// Top-level dependency injection and app router wire-up.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/database/sqlite_store.dart';
import 'core/sync/sync_engine.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/permissions_provider.dart';
import 'core/providers/dashboard_provider.dart';
import 'core/providers/analytics_provider.dart';
import 'core/providers/recovery_provider.dart';
import 'routing/app_router.dart';
import 'ui/theme/app_theme.dart';

class CogniTrackApp extends StatefulWidget {
  final SQLiteStore sqliteStore;
  final SyncEngine syncEngine;
  final bool hasSeenOnboarding;

  const CogniTrackApp({
    super.key,
    required this.sqliteStore,
    required this.syncEngine,
    required this.hasSeenOnboarding,
  });

  @override
  State<CogniTrackApp> createState() => _CogniTrackAppState();
}

class _CogniTrackAppState extends State<CogniTrackApp> {
  late final AuthProvider _authProvider;
  late final PermissionsProvider _permissionsProvider;
  late final DashboardProvider _dashboardProvider;
  late final AnalyticsProvider _analyticsProvider;
  late final RecoveryProvider _recoveryProvider;
  late final router = buildRouter(
    authProvider: _authProvider,
    permissionsProvider: _permissionsProvider,
    hasSeenOnboarding: widget.hasSeenOnboarding,
  );

  @override
  void initState() {
    super.initState();
    _authProvider = AuthProvider();
    _permissionsProvider = PermissionsProvider()..check();
    _dashboardProvider = DashboardProvider(
      store: widget.sqliteStore,
      sync: widget.syncEngine,
    );
    _analyticsProvider = AnalyticsProvider(store: widget.sqliteStore);
    _recoveryProvider = RecoveryProvider(store: widget.sqliteStore);
  }

  @override
  void dispose() {
    _authProvider.dispose();
    _permissionsProvider.dispose();
    _dashboardProvider.dispose();
    _analyticsProvider.dispose();
    _recoveryProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider.value(value: _permissionsProvider),
        ChangeNotifierProvider.value(value: _dashboardProvider),
        ChangeNotifierProvider.value(value: _analyticsProvider),
        ChangeNotifierProvider.value(value: _recoveryProvider),
      ],
      child: MaterialApp.router(
        title: 'CogniTrack',
        theme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
