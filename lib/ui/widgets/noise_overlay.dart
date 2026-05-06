import 'package:flutter/material.dart';

/// Stitch film-grain texture — subtle noise at 3% opacity over every screen.
/// Uses a CustomPainter fallback so it NEVER shows a broken-image cross,
/// even if the PNG asset fails to decode.
class NoiseOverlay extends StatelessWidget {
  const NoiseOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: Image.asset(
          'assets/images/noise_texture.png',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          color: Colors.white.withValues(alpha: 0.03),
          colorBlendMode: BlendMode.modulate,
          // CRITICAL: without errorBuilder, a failed decode renders a
          // full-screen broken-image icon (the red X cross seen on every page).
          // Silently fall back to a zero-opacity container instead.
          errorBuilder: (_, __, ___) => const SizedBox.expand(),
        ),
      ),
    );
  }
}
