import 'package:flutter/material.dart';

/// Core color palette for Self Leveling system.
/// All values extracted from the Figma/React design system.
class AppColors {
  AppColors._();

  // ── Backgrounds ──
  static const Color background = Color(0xFF0A0F1C);
  static const Color cardBackground = Color(0xFF121A2B);
  static const Color surfaceDark = Color(0xFF0D1424);

  // ── Primary Accent ──
  static const Color primaryBlue = Color(0xFF3B82F6);
  static const Color primaryCyan = Color(0xFF22D3EE);

  // ── Semantic Colors ──
  static const Color success = Color(0xFF22C55E);
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerDeep = Color(0xFFDC2626);
  static const Color warning = Color(0xFFF59E0B);

  // ── Text Colors ──
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textTertiary = Color(0xFF6B7280);

  // ── Gradient Definitions ──
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryBlue, primaryCyan],
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [success, primaryBlue],
  );

  static const LinearGradient dangerGradient = LinearGradient(
    colors: [danger, dangerDeep],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [background, cardBackground, background],
  );

  // ── Opacity helpers ──
  static Color primaryBlueWithOpacity(double opacity) =>
      primaryBlue.withOpacity(opacity);
  static Color primaryCyanWithOpacity(double opacity) =>
      primaryCyan.withOpacity(opacity);
  static Color cardBackgroundWithOpacity(double opacity) =>
      cardBackground.withOpacity(opacity);
}
