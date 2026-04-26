/// Sign-up screen — create Firebase Auth account.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../../core/providers/auth_provider.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().signUpWithEmail(
            _emailCtrl.text.trim(),
            _passCtrl.text,
          );
    } catch (e) {
      setState(
          () => _error = 'Registration failed. Email may already be in use.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xxl),
                Row(children: [
                  IconButton(
                    onPressed: () => context.go('/auth/sign-in'),
                    icon: const Icon(Icons.arrow_back,
                        color: AppColors.textSecondary),
                  ),
                ]),
                const SizedBox(height: AppSpacing.md),
                Text('Create Account', style: AppTextStyles.display),
                const SizedBox(height: AppSpacing.xs),
                Text('Start tracking your neural performance.',
                    style: AppTextStyles.body),
                const SizedBox(height: AppSpacing.xl),
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
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: true,
                  style:
                      AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'CONFIRM PASSWORD',
                    prefixIcon: Icon(Icons.lock_outline,
                        color: AppColors.textMuted, size: 18),
                  ),
                  validator: (v) =>
                      v != _passCtrl.text ? 'Passwords do not match' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(_error!,
                      style: AppTextStyles.chipLabel
                          .copyWith(color: AppColors.red)),
                ],
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _signUp,
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text('CREATE ACCOUNT',
                            style: AppTextStyles.chipLabel.copyWith(
                                color: Colors.white, letterSpacing: 1.5)),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: TextButton(
                    onPressed: () => context.go('/auth/sign-in'),
                    child: RichText(
                      text: TextSpan(children: [
                        TextSpan(
                          text: 'Already have an account? ',
                          style: AppTextStyles.body
                              .copyWith(color: AppColors.textMuted),
                        ),
                        TextSpan(
                          text: 'Sign In',
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
