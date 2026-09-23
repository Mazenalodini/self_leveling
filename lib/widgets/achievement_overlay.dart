import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

/// Show an achievement toast overlay that auto-dismisses after 5 seconds.
void showAchievementToast(
  BuildContext context, {
  required String title,
  required String subtitle,
  required int xpEarned,
  IconData icon = Icons.emoji_events,
  Color color = AppColors.success,
}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  Timer? autoClose;

  entry = OverlayEntry(
    builder: (ctx) => _AchievementToast(
      title: title,
      subtitle: subtitle,
      xpEarned: xpEarned,
      icon: icon,
      color: color,
      onDismiss: () {
        autoClose?.cancel();
        entry.remove();
      },
    ),
  );

  overlay.insert(entry);
  autoClose = Timer(const Duration(seconds: 5), () {
    if (entry.mounted) entry.remove();
  });
}

class _AchievementToast extends StatelessWidget {
  final String title, subtitle;
  final int xpEarned;
  final IconData icon;
  final Color color;
  final VoidCallback onDismiss;

  const _AchievementToast({
    required this.title,
    required this.subtitle,
    required this.xpEarned,
    required this.icon,
    required this.color,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1225).withOpacity(0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.2), blurRadius: 24, spreadRadius: 2),
              BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 16),
            ],
          ),
          child: Row(children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.15),
                border: Border.all(color: color.withOpacity(0.5)),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // XP badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Text('+$xpEarned XP',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
            ),
            const SizedBox(width: 8),
            // Close
            GestureDetector(
              onTap: onDismiss,
              child: Icon(Icons.close, color: AppColors.textTertiary, size: 18),
            ),
          ]),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: -1, end: 0, duration: 400.ms, curve: Curves.easeOutBack),
      ),
    );
  }
}
