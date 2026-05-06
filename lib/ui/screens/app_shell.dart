import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../widgets/noise_overlay.dart';

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
        extendBody: true,
        body: Stack(
          children: [
            // Page content — RepaintBoundary isolates page repaints from
            // the noise overlay and bottom nav so they don't repaint together.
            RepaintBoundary(child: child),
            // NoiseOverlay in its own RepaintBoundary — only repaints itself,
            // never triggers the page content or bottom nav to repaint.
            const Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: NoiseOverlay(),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 32, left: 48, right: 48),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9999),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF201F1F).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                      width: 1,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0F680009),
                        blurRadius: 40,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _navBtn(context, 0, idx, Icons.home, '/dashboard'),
                      _navBtn(context, 1, idx, Icons.show_chart, '/analytics'),
                      _navBtn(context, 2, idx, Icons.hub_outlined, '/recovery'),
                      _navBtn(context, 3, idx, Icons.self_improvement,
                          '/sanctuary'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navBtn(
      BuildContext ctx, int i, int selected, IconData icon, String route) {
    final isActive = i == selected;
    return GestureDetector(
      onTap: () => ctx.go(route),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? AppColors.red : Colors.transparent,
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.red.withValues(alpha: 0.4),
                    blurRadius: 20,
                  )
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 22,
          color: isActive ? Colors.white : AppColors.textMuted,
        ),
      ),
    );
  }
}
