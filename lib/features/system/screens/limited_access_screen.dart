import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../widgets/system_background.dart';
import '../../../widgets/glow_card.dart';
import '../../../core/constants/app_strings.dart';
import '../../../widgets/system_decorative_line.dart';

/// Limited Access screen (S4 escalation) — controlled usage state.
class LimitedAccessScreen extends StatelessWidget {
  const LimitedAccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SystemBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 96, height: 96,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.warning, AppColors.danger]),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppColors.warning.withOpacity(0.4), blurRadius: 40)],
                ),
                child: const Icon(Icons.block, color: Colors.white, size: 48),
              ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0, 0), curve: Curves.easeOut),

              const SizedBox(height: 32),
              Text(AppStrings.limitedAccess, style: AppTextStyles.h2).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 12),
              Text(AppStrings.accessRestricted, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)).animate().fadeIn(delay: 400.ms),

              const SizedBox(height: 32),
              GlowCard(
                glowColor: AppColors.warning, borderOpacity: 0.4,
                child: Column(children: [
                  Text(AppStrings.excessiveDistractionDetected, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Text(AppStrings.onlyEssentialFeatures, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.warning, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                ]),
              ).animate().fadeIn(delay: 500.ms),

              const SizedBox(height: 24),
              GlowCard(
                backgroundOpacity: 0.4, borderOpacity: 0.2, padding: const EdgeInsets.all(20),
                child: Column(children: [
                  _AccessRow(icon: Icons.track_changes, label: AppStrings.habitsLabel, allowed: true),
                  const SizedBox(height: 12),
                  _AccessRow(icon: Icons.psychology, label: AppStrings.aiChatLabel, allowed: true),
                  const SizedBox(height: 12),
                  _AccessRow(icon: Icons.bar_chart, label: AppStrings.statisticsLabel, allowed: false),
                  const SizedBox(height: 12),
                  _AccessRow(icon: Icons.settings, label: AppStrings.settingsLabel, allowed: false),
                ]),
              ).animate().fadeIn(delay: 700.ms),

              const SizedBox(height: 32),
              Text(AppStrings.completeHabitsToRestore, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)).animate().fadeIn(delay: 900.ms),

              const SizedBox(height: 48),
              SystemDecorativeLine(label: AppStrings.controlledAccess, color: AppColors.warning).animate().fadeIn(delay: 1100.ms),
            ]),
          ),
        ),
      ),
    );
  }
}

class _AccessRow extends StatelessWidget {
  final IconData icon; final String label; final bool allowed;
  const _AccessRow({required this.icon, required this.label, required this.allowed});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: allowed ? AppColors.success : AppColors.danger, size: 20),
      const SizedBox(width: 12),
      Expanded(child: Text(label, style: AppTextStyles.bodySmall.copyWith(color: allowed ? Colors.white : AppColors.textTertiary))),
      Icon(allowed ? Icons.check_circle : Icons.cancel, color: allowed ? AppColors.success : AppColors.danger, size: 20),
    ]);
  }
}
