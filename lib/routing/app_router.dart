/// GoRouter configuration — auth + permissions redirect guard.
library;

import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/providers/auth_provider.dart';
import '../core/providers/permissions_provider.dart';
import '../ui/screens/onboarding/onboarding_screen.dart';
import '../ui/screens/auth/sign_in_screen.dart';
import '../ui/screens/auth/sign_up_screen.dart';
import '../ui/screens/permission/permission_screen.dart';
import '../ui/screens/dashboard/dashboard_screen.dart';
import '../ui/screens/analytics/analytics_screen.dart';
import '../ui/screens/recovery/recovery_screen.dart';
import '../ui/screens/sanctuary/sanctuary_screen.dart';
import '../ui/screens/app_shell.dart';
import '../ui/screens/splash_screen.dart';

GoRouter buildRouter({
  required AuthProvider authProvider,
  required PermissionsProvider permissionsProvider,
  required bool hasSeenOnboarding,
}) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: Listenable.merge([authProvider, permissionsProvider]),
    redirect: (BuildContext ctx, GoRouterState state) {
      final auth = authProvider;
      final perms = permissionsProvider;
      final loc = state.matchedLocation;

      if (!auth.isChecked) return '/splash';
      if (!auth.isAuthenticated) {
        if (loc == '/onboarding' ||
            loc == '/auth/sign-in' ||
            loc == '/auth/sign-up') {
          return null;
        }
        if (!hasSeenOnboarding) return '/onboarding';
        return '/auth/sign-in';
      }

      // Authenticated below here
      if (io.Platform.isAndroid &&
          perms.isChecked &&
          !perms.hasPermission &&
          loc != '/permission') {
        return '/permission';
      }

      if (loc == '/splash' || loc.startsWith('/auth')) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/permission',
        builder: (_, __) => const PermissionScreen(),
      ),
      GoRoute(
        path: '/auth/sign-in',
        builder: (_, __) => const SignInScreen(),
      ),
      GoRoute(
        path: '/auth/sign-up',
        builder: (_, __) => const SignUpScreen(),
      ),
      ShellRoute(
        builder: (_, __, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, __) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/analytics',
            builder: (_, __) => const AnalyticsScreen(),
          ),
          GoRoute(
            path: '/recovery',
            builder: (_, __) => const RecoveryScreen(),
          ),
          GoRoute(
            path: '/sanctuary',
            builder: (_, __) => const SanctuaryScreen(),
          ),
        ],
      ),
    ],
  );
}
