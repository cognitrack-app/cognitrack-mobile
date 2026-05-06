/// CogniTrack design system — full Material 3 theme configuration.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

abstract final class AppTheme {
  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          primaryContainer: AppColors.primaryContainer,
          secondary: AppColors.primary,
          surface: AppColors.surface,
          error: AppColors.critical,
          onPrimary: AppColors.bg,
          onSurface: AppColors.textPrimary,
        ),
        fontFamily: GoogleFonts.inter().fontFamily,
        textTheme: TextTheme(
          displayLarge: AppTextStyles.displayLg,
          displayMedium: AppTextStyles.display,
          headlineMedium: AppTextStyles.sectionHead,
          titleMedium: AppTextStyles.cardTitle,
          bodyLarge: AppTextStyles.body,
          bodyMedium: AppTextStyles.body,
          labelSmall: AppTextStyles.chipLabel,
        ),
        // The "No-Line" Rule for Cards
        cardTheme: const CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppSpacing.cardR)),
            side: BorderSide.none, // Explicitly no borders
          ),
        ),
        // M01 FIX: divider must use outlineVariant so row separators in
        // Recovery break-quality list are visible.
        dividerTheme: const DividerThemeData(
          color: AppColors.outlineVariant,
          space: 24,
          thickness: 0.5,
        ),
        // The "No-Line" Rule for Inputs (Ghost Border on focus)
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.cardR),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.cardR),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.cardR),
            borderSide: BorderSide(
              color: AppColors.outlineVariant.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.cardR),
            borderSide: const BorderSide(color: AppColors.critical, width: 1),
          ),
          labelStyle: AppTextStyles.labelSm,
          hintStyle: AppTextStyles.body.copyWith(height: 1.0),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryContainer,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.cardR),
              side: BorderSide(
                color:
                    AppColors.primary.withValues(alpha: 0.15), // Ghost Border
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: AppTextStyles.cardTitle,
            elevation: 0,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.navBg,
          indicatorColor: Colors.transparent,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: Colors.white, size: 22);
            }
            return const IconThemeData(color: AppColors.textMuted, size: 22);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppTextStyles.chipLabel.copyWith(color: AppColors.primary);
            }
            return AppTextStyles.chipLabel;
          }),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.bg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: AppColors.textPrimary),
        ),
      );
}
