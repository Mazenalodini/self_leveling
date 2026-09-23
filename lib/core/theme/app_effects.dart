import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Glow effects, shadows, and decoration presets.
class AppEffects {
  AppEffects._();

  // ── Box Shadows (Glows) ──
  static List<BoxShadow> glowBlue({double blur = 40, double opacity = 0.2}) => [
        BoxShadow(
          color: AppColors.primaryBlue.withOpacity(opacity),
          blurRadius: blur,
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> glowCyan({double blur = 40, double opacity = 0.2}) => [
        BoxShadow(
          color: AppColors.primaryCyan.withOpacity(opacity),
          blurRadius: blur,
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> glowGreen({double blur = 40, double opacity = 0.2}) => [
        BoxShadow(
          color: AppColors.success.withOpacity(opacity),
          blurRadius: blur,
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> glowRed({double blur = 40, double opacity = 0.2}) => [
        BoxShadow(
          color: AppColors.danger.withOpacity(opacity),
          blurRadius: blur,
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> glowAmber({double blur = 40, double opacity = 0.2}) => [
        BoxShadow(
          color: AppColors.warning.withOpacity(opacity),
          blurRadius: blur,
          spreadRadius: 0,
        ),
      ];

  // ── Card Decorations ──
  static BoxDecoration cardDecoration({
    Color? borderColor,
    double borderOpacity = 0.3,
    double backgroundOpacity = 0.5,
    double borderRadius = 24.0,
  }) =>
      BoxDecoration(
        color: AppColors.cardBackground.withOpacity(backgroundOpacity),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: (borderColor ?? AppColors.primaryBlue).withOpacity(borderOpacity),
          width: 1,
        ),
      );

  static BoxDecoration cardDecorationThick({
    Color? borderColor,
    double borderOpacity = 0.3,
    double backgroundOpacity = 0.6,
    double borderRadius = 16.0,
  }) =>
      BoxDecoration(
        color: AppColors.cardBackground.withOpacity(backgroundOpacity),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: (borderColor ?? AppColors.primaryBlue).withOpacity(borderOpacity),
          width: 2,
        ),
      );

  // ── Gradient Decorations ──
  static BoxDecoration gradientGlowDecoration({
    double opacity = 0.15,
    double blur = 40,
    double borderRadius = 24.0,
  }) =>
      BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(opacity),
            blurRadius: blur,
          ),
          BoxShadow(
            color: AppColors.primaryCyan.withOpacity(opacity * 0.7),
            blurRadius: blur,
          ),
        ],
      );
}
