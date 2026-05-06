/// Sign-up screen — redirects to sign-in.
/// With Google-only auth, account creation is automatic on first sign-in.
/// This screen exists only to handle the /auth/sign-up route gracefully.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Auto-redirect after one frame so the route resolves cleanly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go('/auth/sign-in');
    });

    return const Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.red),
      ),
    );
  }
}
