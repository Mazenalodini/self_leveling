import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../domain/entities/habit.dart';
import '../../../navigation/app_router.dart';
import '../../../providers/habit_provider.dart';
import '../../../providers/system_provider.dart';
import '../../../widgets/system_background.dart';
import '../../../widgets/glow_card.dart';
import '../../../widgets/system_decorative_line.dart';
import '../../../widgets/achievement_overlay.dart';

class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  Future<void> _handleHabitCompletion(
    BuildContext context,
    WidgetRef ref,
    Habit habit,
  ) async {
    if (!habit.canCompleteNow) return;
    final result = await ref.read(habitProvider.notifier).toggleHabit(habit.id);
    if (!context.mounted || !result.completedNow) return;

    showAchievementToast(
      context,
      title: habit.isBreak
          ? AppStrings.habitBroken
          : AppStrings.habitCompleted,
      subtitle: habit.name,
      xpEarned: result.xpEarned,
      icon: habit.isBreak ? Icons.shield_rounded : Icons.check_circle_rounded,
      color: habit.isBreak ? AppColors.danger : AppColors.success,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitState = ref.watch(habitProvider);
    final profile = ref.watch(systemProvider).profile;
    final buildHabits = habitState.buildHabits;
    final breakHabits = habitState.breakHabits;
    final identity = profile.identityStatement.isNotEmpty
        ? '"${profile.identityStatement}"'
        : AppStrings.identityQuote;

    return SystemBackground(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(
          left: AppSpacing.screenPadding,
          right: AppSpacing.screenPadding,
          top: 48,
          bottom: AppSpacing.bottomNavPaddingBottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.habitsAndIdentity, style: AppTextStyles.h2)
                .animate()
                .fadeIn()
                .slideY(begin: -0.2),
            const SizedBox(height: 8),
            Text(AppStrings.shapeWho, style: AppTextStyles.secondaryText)
                .animate()
                .fadeIn(delay: 100.ms),

            const SizedBox(height: 32),

            // Identity Card
            GlowCard(
              glowOpacity: 0.2,
              borderOpacity: 0.4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Stack(alignment: Alignment.center, children: [
                      Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(boxShadow: [
                            BoxShadow(
                                color: AppColors.primaryBlue.withOpacity(0.5),
                                blurRadius: 16)
                          ])),
                      const Icon(Icons.auto_awesome,
                          color: AppColors.primaryBlue, size: 20),
                    ]),
                    const SizedBox(width: 12),
                    Text(AppStrings.yourIdentity,
                        style: AppTextStyles.captionSmall.copyWith(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 12),
                  Text(identity,
                      style: AppTextStyles.bodyLarge
                          .copyWith(fontStyle: FontStyle.italic)),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms),

            const SizedBox(height: 32),

            // BUILD section
            _sectionDivider(AppStrings.build, AppColors.success),
            const SizedBox(height: 16),

            if (buildHabits.isEmpty)
              _emptyState(AppStrings.noBuildHabits, Icons.trending_up,
                  AppColors.success)
            else
              ...List.generate(buildHabits.length, (i) {
                final habit = buildHabits[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _HabitCard(
                    habit: habit,
                    isPositive: true,
                    onToggle: () {
                      unawaited(_handleHabitCompletion(context, ref, habit));
                    },
                    onTap: () => context
                        .push('${RoutePaths.habitDetails}?id=${habit.id}'),
                  )
                      .animate()
                      .fadeIn(delay: Duration(milliseconds: 400 + i * 100))
                      .slideX(begin: -0.2),
                );
              }),

            const SizedBox(height: 24),

            // BREAK section
            _sectionDivider(AppStrings.breakText, AppColors.danger),
            const SizedBox(height: 16),

            if (breakHabits.isEmpty)
              _emptyState(AppStrings.noBreakHabits, Icons.trending_down,
                  AppColors.danger)
            else
              ...List.generate(breakHabits.length, (i) {
                final habit = breakHabits[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _HabitCard(
                    habit: habit,
                    isPositive: false,
                    onToggle: () {
                      unawaited(_handleHabitCompletion(context, ref, habit));
                    },
                    onTap: () => context
                        .push('${RoutePaths.habitDetails}?id=${habit.id}'),
                  )
                      .animate()
                      .fadeIn(delay: Duration(milliseconds: 600 + i * 100)),
                );
              }),

            const SizedBox(height: 24),

            // Add habit button
            GestureDetector(
              onTap: () => context.push(RoutePaths.addHabit),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.primaryBlue.withOpacity(0.4), width: 2),
                ),
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.add, color: AppColors.primaryBlue, size: 20),
                  const SizedBox(width: 12),
                  Text(AppStrings.addHabit, style: AppTextStyles.button),
                ]),
              ),
            ).animate().fadeIn(delay: 800.ms),

            const SizedBox(height: 24),

            // System suggestion
            GlowCard(
              glowOpacity: 0.1,
              backgroundOpacity: 0.4,
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.psychology,
                    color: AppColors.primaryBlue, size: 20),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(AppStrings.suggestedBySystem,
                          style: AppTextStyles.captionSmall.copyWith(
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(
                        habitState.totalCount == 0
                            ? AppStrings.startByAddingHabit
                            : habitState.completedCount == habitState.totalCount
                                ? AppStrings.allHabitsCompleted
                                : AppStrings.completeRemainingHabits(
                                    habitState.totalCount -
                                        habitState.completedCount),
                        style: AppTextStyles.bodySmall,
                      ),
                    ])),
              ]),
            ).animate().fadeIn(delay: 900.ms),

            const SizedBox(height: 32),
            SystemDecorativeLine(label: AppStrings.identitySystem)
                .animate()
                .fadeIn(delay: 1000.ms),
          ],
        ),
      ),
    );
  }

  Widget _sectionDivider(String label, Color color) {
    return Row(children: [
      Expanded(
          child: Container(
              height: 1,
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Colors.transparent, color.withOpacity(0.3)])))),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label,
              style: AppTextStyles.captionSmall
                  .copyWith(color: color, fontWeight: FontWeight.w700))),
      Expanded(
          child: Container(
              height: 1,
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [color.withOpacity(0.3), Colors.transparent])))),
    ]);
  }

  Widget _emptyState(String message, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(children: [
        Icon(icon, color: color.withOpacity(0.4), size: 32),
        const SizedBox(height: 12),
        Text(message,
            style:
                AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
            textAlign: TextAlign.center),
      ]),
    );
  }
}

class _HabitCard extends StatelessWidget {
  final Habit habit;
  final bool isPositive;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  const _HabitCard(
      {required this.habit,
      required this.isPositive,
      required this.onToggle,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isLocked = habit.isCompletionLocked;
    final color = isPositive
        ? (isLocked ? AppColors.success : AppColors.primaryBlue)
        : AppColors.danger;

    return GestureDetector(
      onTap: onTap,
      child: GlowCard(
        glowColor: isLocked ? color : AppColors.primaryBlue,
        glowOpacity: isLocked ? 0.2 : 0.05,
        borderRadius: 16,
        borderWidth: 2,
        borderOpacity: isLocked ? 0.6 : 0.2,
        backgroundOpacity: 0.6,
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          GestureDetector(
            onTap: habit.canCompleteNow ? onToggle : null,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: isLocked ? color : Colors.transparent,
                border: Border.all(
                    color: isLocked ? color : color.withOpacity(0.4), width: 2),
              ),
              child: isLocked
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color.withOpacity(isLocked ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(isPositive ? Icons.trending_up : Icons.trending_down,
                color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(habit.name,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isLocked ? Colors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                    decoration: (!isPositive && isLocked)
                        ? TextDecoration.lineThrough
                        : null,
                  )),
              if (habit.currentStreak > 0)
                Text('🔥 ${AppStrings.dayStreak(habit.currentStreak)}',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.warning, fontSize: 11)),
            ],
          )),
          if (isLocked)
            Text(habit.completionLabel,
                style: AppTextStyles.caption
                    .copyWith(color: color, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}
