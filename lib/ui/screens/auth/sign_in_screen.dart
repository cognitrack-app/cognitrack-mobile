/// Sign-in screen — email + password + Firebase Auth.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
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
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().signInWithEmail(
            _emailCtrl.text.trim(),
            _passCtrl.text,
          );
      // Router will redirect automatically via refreshListenable
    } catch (e) {
      setState(() => _error = 'Invalid email or password. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xxl),
                // Logo
                Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: AppColors.red),
                    child: const Icon(Icons.psychology,
                        size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text('CogniTrack',
                      style: AppTextStyles.cardTitle.copyWith(
                          color: AppColors.red,
                          fontWeight: FontWeight.w800,
                          fontSize: 18)),
                ]),
                const SizedBox(height: AppSpacing.xxl),
                Text('Sign In', style: AppTextStyles.display),
                const SizedBox(height: AppSpacing.xs),
                Text('Monitor your neural performance.',
                    style: AppTextStyles.body),
                const SizedBox(height: AppSpacing.xl),

                // Email
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style:
                      AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'EMAIL ADDRESS',
                    prefixIcon: const Icon(Icons.email_outlined,
                        color: AppColors.textMuted, size: 18),
                  ),
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Valid email required'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),

                // Password
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  style:
                      AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'PASSWORD',
                    prefixIcon: const Icon(Icons.lock_outline,
                        color: AppColors.textMuted, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textMuted,
                          size: 18),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.length < 6) ? 'Min 6 characters' : null,
                ),

                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(_error!,
                      style: AppTextStyles.chipLabel
                          .copyWith(color: AppColors.red)),
                ],
                const SizedBox(height: AppSpacing.xl),

                // Sign In button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _signIn,
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text('SIGN IN',
                            style: AppTextStyles.chipLabel.copyWith(
                                color: Colors.white, letterSpacing: 1.5)),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Go to sign up
                Center(
                  child: TextButton(
                    onPressed: () => context.go('/auth/sign-up'),
                    child: RichText(
                      text: TextSpan(children: [
                        TextSpan(
                          text: "Don't have an account? ",
                          style: AppTextStyles.body
                              .copyWith(color: AppColors.textMuted),
                        ),
                        TextSpan(
                          text: 'Sign Up',
                          style: AppTextStyles.body.copyWith(
                              color: AppColors.red,
                              fontWeight: FontWeight.w600),
                        ),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
