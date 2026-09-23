import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum FeedbackType { error, success, warning, info }

/// Reusable feedback presentation layer replacing raw SnackBars.
class AppFeedback {
  static void show(BuildContext context, String message, {FeedbackType type = FeedbackType.info}) {
    Color glowColor;
    IconData icon;
    
    switch (type) {
      case FeedbackType.error:
        glowColor = AppColors.danger;
        icon = Icons.error_outline;
        break;
      case FeedbackType.success:
        glowColor = AppColors.success;
        icon = Icons.check_circle_outline;
        break;
      case FeedbackType.warning:
        glowColor = AppColors.warning;
        icon = Icons.warning_amber_rounded;
        break;
      case FeedbackType.info:
      default:
        glowColor = AppColors.primaryBlue;
        icon = Icons.info_outline;
        break;
    }

    final snackBar = SnackBar(
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: glowColor.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: glowColor.withOpacity(0.2),
              blurRadius: 12,
              spreadRadius: 1,
            )
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: glowColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
      duration: const Duration(seconds: 4),
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  static void showError(BuildContext context, String message) => show(context, message, type: FeedbackType.error);
  static void showSuccess(BuildContext context, String message) => show(context, message, type: FeedbackType.success);
  static void showWarning(BuildContext context, String message) => show(context, message, type: FeedbackType.warning);
  static void showInfo(BuildContext context, String message) => show(context, message, type: FeedbackType.info);
}
