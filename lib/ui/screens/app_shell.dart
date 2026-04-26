/// AppShell — bottom navigation bar + Android back-press handling.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static int _locationToIndex(String loc) {
    if (loc.startsWith('/analytics')) return 1;
    if (loc.startsWith('/recovery')) return 2;
    if (loc.startsWith('/sanctuary')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    final idx = _locationToIndex(loc);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && idx != 0) context.go('/dashboard');
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: child,
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: AppColors.navBg,
            border: Border(
              top: BorderSide(color: AppColors.border, width: 0.5),
            ),
          ),
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            selectedIndex: idx,
            onDestinationSelected: (i) {
              const routes = [
                '/dashboard',
                '/analytics',
                '/recovery',
                '/sanctuary'
              ];
              context.go(routes[i]);
            },
            destinations: [
              _navDest(0, idx, Icons.home_outlined, Icons.home, 'Home'),
              _navDest(1, idx, Icons.show_chart_outlined, Icons.show_chart,
                  'Analytics'),
              _navDest(2, idx, Icons.grid_view_outlined, Icons.grid_view,
                  'Recovery'),
              _navDest(3, idx, Icons.self_improvement_outlined,
                  Icons.self_improvement, 'Sanctuary'),
            ],
          ),
        ),
      ),
    );
  }

  NavigationDestination _navDest(
    int i,
    int selected,
    IconData icon,
    IconData selectedIcon,
    String label,
  ) {
    return NavigationDestination(
      icon: Icon(icon, color: AppColors.textMuted, size: 22),
      selectedIcon: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.red,
        ),
        child: Icon(selectedIcon, color: Colors.white, size: 22),
      ),
      label: label,
    );
  }
}
