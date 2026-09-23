import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Typography system matching the Figma/React design.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle get _base => GoogleFonts.inter(color: AppColors.textPrimary);

  // ── Display ──
  static TextStyle get displayLarge => _base.copyWith(
        fontSize: 96,
        fontWeight: FontWeight.w700,
        height: 1.0,
      );

  // ── Timer Display ──
  static TextStyle get timer => _base.copyWith(
        fontSize: 72,
        fontWeight: FontWeight.w700,
        height: 1.0,
      );

  // ── Level Display ──
  static TextStyle get levelDisplay => _base.copyWith(
        fontSize: 80,
        fontWeight: FontWeight.w700,
        height: 1.0,
      );

  // ── Headings ──
  static TextStyle get h1 => _base.copyWith(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        height: 1.2,
      );

  static TextStyle get h2 => _base.copyWith(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        height: 1.3,
      );

  static TextStyle get h3 => _base.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.3,
      );

  static TextStyle get h4 => _base.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.4,
      );

  // ── Body ──
  static TextStyle get bodyLarge => _base.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  static TextStyle get bodyMedium => _base.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  static TextStyle get bodySmall => _base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.5,
      );

  // ── Labels / Captions ──
  static TextStyle get label => _base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.5,
      );

  static TextStyle get caption => _base.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.5,
      );

  static TextStyle get captionSmall => _base.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.5,
        letterSpacing: 1.5,
      );

  // ── System Tag ──
  static TextStyle get systemTag => _base.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 2.0,
        color: AppColors.primaryBlue,
      );

  // ── Button ──
  static TextStyle get button => _base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.5,
      );

  static TextStyle get buttonLarge => _base.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      );

  // ── Helpers ──
  static TextStyle get secondaryText =>
      bodyMedium.copyWith(color: AppColors.textSecondary);

  static TextStyle get tertiaryText =>
      bodySmall.copyWith(color: AppColors.textTertiary);
}
