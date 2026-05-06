/// Sign-in screen — Google Sign-In only.
// ignore_for_file: prefer_const_constructors
library;

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../../core/providers/auth_provider.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().signInWithGoogle();
      // GoRouter will auto-redirect to /dashboard via refreshListenable
    } on FirebaseAuthException catch (e) {
      setState(() =>
          _error = e.message ?? 'Google sign-in failed. Please try again.');
    } catch (e) {
      // User cancelled picker — silent
      final msg = e.toString();
      if (!msg.contains('cancel') && !msg.contains('null')) {
        setState(() => _error = 'Sign-in failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: size.height * 0.12),

              // ── Logo ────────────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.red,
                    ),
                    child: const Icon(
                      Icons.psychology,
                      size: 22,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'CogniTrack',
                    style: AppTextStyles.cardTitle.copyWith(
                      color: AppColors.red,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),

              SizedBox(height: size.height * 0.06),

              // ── Headline ──────────────────────────────────────────────────
              Text(
                'Welcome Back.',
                textAlign: TextAlign.center,
                style: AppTextStyles.display.copyWith(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Monitor your neural performance.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),

              const Spacer(),

              // ── Error banner ──────────────────────────────────────────────
              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primaryContainer.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.primaryContainer, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: AppTextStyles.labelSm.copyWith(
                            color: AppColors.primaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Google Sign-In button ───────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _loading ? null : _signInWithGoogle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.red,
                    disabledBackgroundColor:
                        AppColors.red.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Google "G" logo rendered in white
                            _GoogleGLogo(),
                            const SizedBox(width: 12),
                            Text(
                              'Sign in with Google',
                              style: AppTextStyles.body.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Footer note ─────────────────────────────────────────────────
              Text(
                'A new account is created automatically\nif you sign in for the first time.',
                textAlign: TextAlign.center,
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
              ),

              SizedBox(
                height: MediaQuery.of(context).padding.bottom + AppSpacing.lg,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Google "G" logo widget ─────────────────────────────────────────────────────
class _GoogleGLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          'G',
          style: TextStyle(
            color: Colors.red.shade700,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
