import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../domain/entities/report_models.dart';
import '../../../widgets/system_background.dart';
import '../../../widgets/glow_card.dart';

import '../../../widgets/progress_bar_widget.dart';
import '../../../widgets/system_decorative_line.dart';
import '../../../providers/system_provider.dart';
import '../../../providers/habit_provider.dart';
import '../../../providers/focus_provider.dart';
import '../../../providers/report_provider.dart';

class LevelRewardsScreen extends ConsumerWidget {
  const LevelRewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(systemProvider).profile;
    final habitState = ref.watch(habitProvider);
    final focusState = ref.watch(focusProvider);
    final levelOverview = ref.watch(levelOverviewProvider).valueOrNull ??
        const LevelOverviewReport();

    final currentLevel = profile.level;
    final currentXP = profile.currentXP;
    final requiredXP = profile.xpForNextLevel;
    final xpProgress = profile.levelProgress;

    final achievements = [
      (
        AppStrings.achTitle1,
        Icons.flash_on,
        focusState.history.isNotEmpty,
        AppStrings.achDesc1
      ),
      (
        AppStrings.achTitle2,
        Icons.star,
        habitState.habits.any((h) => h.currentStreak >= 3),
        AppStrings.achDesc2
      ),
      (
        AppStrings.achTitle3,
        Icons.emoji_events,
        profile.selfControlScore >= 70,
        AppStrings.achDesc3
      ),
      (
        AppStrings.achTitle4,
        Icons.military_tech,
        currentLevel >= 5,
        AppStrings.achDesc4
      ),
      (
        AppStrings.achTitle5,
        Icons.star,
        habitState.habits.any((h) => h.currentStreak >= 7),
        AppStrings.achDesc5
      ),
      (
        AppStrings.achTitle6,
        Icons.psychology,
        focusState.history.where((s) => s.wasCompleted).length >= 20,
        AppStrings.achDesc6
      ),
    ];

    return SystemBackground(
      particleCount: 15,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(
            left: AppSpacing.screenPadding,
            right: AppSpacing.screenPadding,
            top: 48,
            bottom: AppSpacing.bottomNavPaddingBottom),
        child: Column(
          children: [
            // Decorative line
            Container(
                height: 1,
                decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                  Colors.transparent,
                  AppColors.primaryBlue.withOpacity(0.5),
                  Colors.transparent
                ]))),
            const SizedBox(height: 32),

            // Level label
            Text(AppStrings.yourLevel.toUpperCase(),
                style: AppTextStyles.captionSmall.copyWith(
                    color: AppColors.textSecondary, letterSpacing: 2)),
            const SizedBox(height: 16),

            // Level number with glow
            ShaderMask(
              shaderCallback: (bounds) =>
                  AppColors.primaryGradient.createShader(bounds),
              child: Text('$currentLevel',
                  style:
                      AppTextStyles.levelDisplay.copyWith(color: Colors.white)),
            )
                .animate()
                .fadeIn(duration: 800.ms)
                .scale(begin: const Offset(0.8, 0.8)),
            const SizedBox(height: 8),
            Text(AppStrings.growthInProgress, style: AppTextStyles.bodyLarge),
            const SizedBox(height: 24),

            Container(
                height: 1,
                decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                  Colors.transparent,
                  AppColors.primaryBlue.withOpacity(0.5),
                  Colors.transparent
                ]))),
            const SizedBox(height: 32),

            // XP Progress
            GlowCard(
              glowOpacity: 0.2,
              child: Column(
                children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(AppStrings.experiencePoints,
                            style: AppTextStyles.label),
                        Text('$currentXP / $requiredXP XP',
                            style: AppTextStyles.label
                                .copyWith(color: AppColors.primaryBlue)),
                      ]),
                  const SizedBox(height: 16),
                  ProgressBarWidget(progress: xpProgress),
                  const SizedBox(height: 12),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Level $currentLevel',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textSecondary)),
                        Text(
                            '${requiredXP - currentXP} XP ${AppStrings.toLevel} ${currentLevel + 1}',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textSecondary)),
                      ]),
                ],
              ),
            ).animate().fadeIn(delay: 300.ms),

            const SizedBox(height: 24),

            // Recent Changes — real canonical progression facts
            Row(children: [
              const Icon(Icons.trending_up,
                  color: AppColors.primaryBlue, size: 20),
              const SizedBox(width: 8),
              Text(AppStrings.recentChanges, style: AppTextStyles.h4),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                  child: _StatCard(
                      icon: Icons.center_focus_strong,
                      value: _signedValue(levelOverview.focusXpToday),
                      label: AppStrings.focus,
                      color: AppColors.success)),
              const SizedBox(width: 12),
              Expanded(
                  child: _StatCard(
                      icon: Icons.schedule,
                      value: _signedValue(levelOverview.interventionXpToday),
                      label: AppStrings.distracted,
                      color: AppColors.danger)),
              const SizedBox(width: 12),
              Expanded(
                  child: _StatCard(
                      icon: Icons.track_changes,
                      value: _signedValue(levelOverview.habitXpToday),
                      label: AppStrings.habit,
                      color: AppColors.success)),
            ]).animate().fadeIn(delay: 500.ms),

            const SizedBox(height: 32),

            // Achievements
            Row(children: [
              const Icon(Icons.military_tech,
                  color: AppColors.primaryBlue, size: 20),
              const SizedBox(width: 8),
              Text(AppStrings.achievements, style: AppTextStyles.h4),
            ]),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: achievements
                  .map((a) => _AchievementCard(
                      title: a.$1,
                      icon: a.$2,
                      unlocked: a.$3,
                      description: a.$4))
                  .toList(),
            ).animate().fadeIn(delay: 700.ms),

            const SizedBox(height: 24),

            // Motivational card
            GlowCard(
              backgroundOpacity: 0.4,
              borderOpacity: 0.2,
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                const Icon(Icons.star, color: AppColors.primaryBlue, size: 24),
                const SizedBox(height: 8),
                Text(AppStrings.keepLevelingUp,
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(AppStrings.everySmallStep,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary)),
              ]),
            ).animate().fadeIn(delay: 900.ms),

            const SizedBox(height: 32),
            SystemDecorativeLine(label: AppStrings.levelSystem)
                .animate()
                .fadeIn(delay: 1000.ms),
          ],
        ),
      ),
    );
  }
}

String _signedValue(int value) {
  if (value > 0) return '+$value';
  return '$value';
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatCard(
      {required this.icon,
      required this.value,
      required this.label,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      glowColor: color,
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(value, style: AppTextStyles.h4.copyWith(color: color)),
        const SizedBox(height: 4),
        Text(label,
            style:
                AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
      ]),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool unlocked;
  final String description;
  const _AchievementCard(
      {required this.title,
      required this.icon,
      required this.unlocked,
      required this.description});

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      glowColor: unlocked ? AppColors.primaryBlue : AppColors.textTertiary,
      glowOpacity: unlocked ? 0.2 : 0,
      borderRadius: 16,
      borderOpacity: unlocked ? 0.3 : 0.1,
      backgroundOpacity: unlocked ? 0.6 : 0.3,
      padding: const EdgeInsets.all(16),
      child: Opacity(
        opacity: unlocked ? 1.0 : 0.5,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Stack(alignment: Alignment.center, children: [
            if (unlocked)
              Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(boxShadow: [
                    BoxShadow(
                        color: AppColors.primaryBlue.withOpacity(0.4),
                        blurRadius: 16)
                  ])),
            Icon(icon,
                color:
                    unlocked ? AppColors.primaryBlue : AppColors.textSecondary,
                size: 32),
          ]),
          const SizedBox(height: 12),
          Text(title,
              style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: unlocked ? Colors.white : AppColors.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(description,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary, fontSize: 10),
              textAlign: TextAlign.center,
              maxLines: 2),
        ]),
      ),
    );
  }
}
