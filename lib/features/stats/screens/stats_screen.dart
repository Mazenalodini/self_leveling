import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/entities/report_models.dart';
import '../../../domain/entities/runtime_visual_summary.dart';
import '../../../providers/report_provider.dart';
import '../../../providers/system_provider.dart';
import '../../../widgets/glow_card.dart';
import '../../../widgets/system_background.dart';
import '../../../widgets/system_decorative_line.dart';
import '../../../widgets/circular_progress_widget.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final system = ref.watch(systemProvider);
    final profile = system.profile;
    final nativeState = system.nativeState;
    final distractionScore = system.distractionScore;
    final runtimeSummary = ref.watch(runtimeVisualSummaryProvider);
    final statsAsync = ref.watch(statsOverviewProvider);

    final stats = statsAsync.valueOrNull ?? const StatsOverviewReport();
    final todayFocusHours = stats.todayFocusMinutes / 60.0;

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
            Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryBlue.withOpacity(0.5),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.trending_up,
                      color: AppColors.primaryBlue,
                      size: 24,
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Text(AppStrings.statistics, style: AppTextStyles.h2),
              ],
            ).animate().fadeIn().slideY(begin: -0.2),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Text(
                AppStrings.progressInsights,
                style: AppTextStyles.secondaryText,
              ),
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: _MiniCard(
                    icon: Icons.schedule,
                    value: '${todayFocusHours.toStringAsFixed(1)}h',
                    label: AppStrings.focusToday,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniCard(
                    icon: Icons.flash_on,
                    value: '${stats.todayDistractionHours.toStringAsFixed(1)}h',
                    label: AppStrings.distracted,
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniCard(
                    icon: Icons.check_circle_outline,
                    value: '${stats.completionRate}%',
                    label: AppStrings.complete,
                    color: AppColors.success,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
            const SizedBox(height: 32),
            GlowCard(
              glowBlur: 40,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.systemOverview, style: AppTextStyles.h4),
                  const SizedBox(height: 20),
                  _StatRow(AppStrings.level, '${profile.level}',
                      AppColors.primaryBlue),
                  _StatRow(
                    AppStrings.totalXpEarned,
                    '${profile.totalXPEarned}',
                    AppColors.primaryCyan,
                  ),
                  _StatRow(
                    AppStrings.currentXp,
                    '${profile.currentXP} / ${profile.xpForNextLevel}',
                    AppColors.success,
                    progress: profile.levelProgress.clamp(0.0, 1.0),
                  ),
                  _StatRow(
                    AppStrings.selfControl,
                    '${profile.selfControlScore}%',
                    _selfControlColor(profile.selfControlScore),
                    progress: profile.selfControlScore / 100.0,
                  ),
                  _StatRow(
                    AppStrings.distractionScore,
                    '${(distractionScore * 100).round()}%',
                    distractionScore > 0.5
                        ? AppColors.danger
                        : AppColors.success,
                    progress: distractionScore.clamp(0.0, 1.0),
                  ),
                  _StatRow(
                    AppStrings.escalationToday,
                    '${stats.todayEscalationCount}x · S${stats.todayMaxStage}',
                    stats.todayEscalationCount > 0
                        ? AppColors.warning
                        : AppColors.textSecondary,
                  ),
                  _StatRow(
                    AppStrings.focusSessions,
                    '${stats.todayFocusSessions}',
                    AppColors.primaryBlue,
                  ),
                  _StatRow(
                    AppStrings.systemStatus,
                    _runtimeLabel(runtimeSummary, nativeState.stageName),
                    _runtimeColor(runtimeSummary),
                  ),
                  if ((stats.topDistractingApp ?? '').isNotEmpty)
                    _StatRow(
                      AppStrings.topApp,
                      stats.topDistractingApp!,
                      AppColors.danger,
                    ),
                ],
              ),
            ).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: 24),
            GlowCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.habitProgress, style: AppTextStyles.h4),
                  const SizedBox(height: 20),
                  if (stats.totalHabits == 0)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          AppStrings.noHabitsYetAdd,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    )
                  else ...[
                    Center(
                      child: SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressWidget(
                          progress: stats.totalHabits > 0
                              ? stats.todayHabitCompletions / stats.totalHabits
                              : 0,
                          size: 100,
                          strokeWidth: 8,
                          center: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${stats.completionRate}%',
                                style: AppTextStyles.h3.copyWith(
                                  color: stats.completionRate == 100
                                      ? AppColors.success
                                      : AppColors.primaryBlue,
                                ),
                              ),
                              Text(
                                '${stats.todayHabitCompletions}/${stats.totalHabits}',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ).animate().fadeIn(delay: 600.ms),
            const SizedBox(height: 24),
            GlowCard(
              glowColor: AppColors.warning,
              borderOpacity: 0.4,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.warning.withOpacity(0.5),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.analytics_outlined,
                        color: AppColors.warning,
                        size: 24,
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.systemAnalysis,
                          style: AppTextStyles.captionSmall.copyWith(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _buildSystemNote(
                            stats: stats,
                            runtimeSummary: runtimeSummary,
                            selfControlScore: profile.selfControlScore,
                            distractionScore: distractionScore,
                          ),
                          style: AppTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 800.ms),
            const SizedBox(height: 32),
            SystemDecorativeLine(label: AppStrings.analyticsActive)
                .animate()
                .fadeIn(delay: 1000.ms),
          ],
        ),
      ),
    );
  }

  String _buildSystemNote({
    required StatsOverviewReport stats,
    required RuntimeVisualSummary runtimeSummary,
    required int selfControlScore,
    required double distractionScore,
  }) {
    switch (runtimeSummary.status) {
      case RuntimeVisualStatus.blocking:
      case RuntimeVisualStatus.limitedAccess:
      case RuntimeVisualStatus.hardLock:
        return AppStrings.insightHighDistraction;
      case RuntimeVisualStatus.warning:
        return AppStrings.msgHighDistract;
      case RuntimeVisualStatus.focusMode:
      case RuntimeVisualStatus.monitoring:
      case RuntimeVisualStatus.inactive:
        break;
    }

    if (stats.completionRate == 100 && stats.todayEscalationCount == 0) {
      return AppStrings.insightAllDone;
    }
    if (distractionScore > 0.7 || stats.todayMaxStage >= 3) {
      return AppStrings.insightHighDistraction;
    }
    if (selfControlScore < 40) {
      return AppStrings.insightLowControl;
    }
    if (stats.totalHabits > 0 && stats.completionRate < 50) {
      return AppStrings.insightUncompleted;
    }
    return AppStrings.insightProgress;
  }

  String _runtimeLabel(
    RuntimeVisualSummary runtimeSummary,
    String stageName,
  ) {
    switch (runtimeSummary.status) {
      case RuntimeVisualStatus.inactive:
        return AppStrings.inactive;
      case RuntimeVisualStatus.monitoring:
        return AppStrings.monitoringStatus;
      case RuntimeVisualStatus.focusMode:
        return AppStrings.focusModeActive;
      case RuntimeVisualStatus.warning:
      case RuntimeVisualStatus.blocking:
      case RuntimeVisualStatus.limitedAccess:
      case RuntimeVisualStatus.hardLock:
        return stageName;
    }
  }

  Color _runtimeColor(RuntimeVisualSummary runtimeSummary) {
    switch (runtimeSummary.status) {
      case RuntimeVisualStatus.inactive:
        return AppColors.textSecondary;
      case RuntimeVisualStatus.monitoring:
        return AppColors.primaryBlue;
      case RuntimeVisualStatus.focusMode:
        return AppColors.success;
      case RuntimeVisualStatus.warning:
        return AppColors.warning;
      case RuntimeVisualStatus.blocking:
      case RuntimeVisualStatus.limitedAccess:
      case RuntimeVisualStatus.hardLock:
        return AppColors.danger;
    }
  }

  Color _selfControlColor(int score) {
    if (score >= 70) return AppColors.success;
    if (score >= 40) return AppColors.warning;
    return AppColors.danger;
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final double? progress;

  const _StatRow(this.label, this.value, this.color, {this.progress});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Flexible(
                child: Text(
                  value,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress!.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: color.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _MiniCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      glowColor: color,
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 10),
          Text(value, style: AppTextStyles.h3),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
