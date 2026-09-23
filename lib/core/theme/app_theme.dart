import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

/// Centralized ThemeData for the Self Leveling system.
class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primaryBlue,
          secondary: AppColors.primaryCyan,
          surface: AppColors.cardBackground,
          error: AppColors.danger,
          onPrimary: AppColors.textPrimary,
          onSecondary: AppColors.textPrimary,
          onSurface: AppColors.textPrimary,
          onError: AppColors.textPrimary,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          titleTextStyle: AppTextStyles.h3,
          iconTheme: const IconThemeData(color: AppColors.primaryBlue),
        ),
        textTheme: TextTheme(
          displayLarge: AppTextStyles.h1,
          displayMedium: AppTextStyles.h2,
          displaySmall: AppTextStyles.h3,
          headlineMedium: AppTextStyles.h4,
          bodyLarge: AppTextStyles.bodyLarge,
          bodyMedium: AppTextStyles.bodyMedium,
          bodySmall: AppTextStyles.bodySmall,
          labelLarge: AppTextStyles.button,
          labelMedium: AppTextStyles.label,
          labelSmall: AppTextStyles.caption,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.background.withOpacity(0.7),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: AppColors.primaryBlue.withOpacity(0.2),
              width: 2,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: AppColors.primaryBlue.withOpacity(0.2),
              width: 2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: AppColors.primaryBlue,
              width: 2,
            ),
          ),
          hintStyle: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      );
}
