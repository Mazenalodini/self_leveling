import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/entities/report_models.dart';
import '../../../providers/report_provider.dart';
import '../../../widgets/glow_card.dart';
import '../../../widgets/system_background.dart';
import '../../../widgets/system_decorative_line.dart';

class WeeklyReviewScreen extends ConsumerWidget {
  const WeeklyReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewAsync = ref.watch(weeklyReviewProvider);

    return reviewAsync.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryBlue),
        ),
      ),
      error: (_, __) => Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text(
            AppStrings.statistics,
            style: AppTextStyles.bodyMedium,
          ),
        ),
      ),
      data: (report) {
        final focusTotal = report.focusHours
            .fold<double>(0, (sum, val) => sum + val)
            .toStringAsFixed(1);
        final distractTotal = report.distractHours
            .fold<double>(0, (sum, val) => sum + val)
            .toStringAsFixed(1);
        final changeLabel = report.productiveChangePercent >= 0
            ? '+${report.productiveChangePercent.toStringAsFixed(1)}%'
            : '${report.productiveChangePercent.toStringAsFixed(1)}%';

        return Scaffold(
          resizeToAvoidBottomInset: false,
          body: SystemBackground(
            child: Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.cardBackground.withOpacity(0.5),
                            ),
                            child: const Icon(
                              Icons.arrow_back,
                              color: AppColors.primaryBlue,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.weeklyReview,
                                style: AppTextStyles.h2,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                AppStrings.weeklyOverview,
                                style: AppTextStyles.secondaryText,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 1,
                                    color: AppColors.primaryCyan,
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.calendar_view_week,
                                    color: AppColors.primaryCyan,
                                    size: 12,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primaryBlue.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            AppStrings.weekNum(_isoWeekNumber()),
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn().slideY(begin: -0.2),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                title: AppStrings.focusTime,
                                value: '${focusTotal}h',
                                change: changeLabel,
                                isPositive: report.productiveChangePercent >= 0,
                                icon: Icons.center_focus_strong,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                title: AppStrings.distraction,
                                value: '${distractTotal}h',
                                change: AppStrings.tracking,
                                isPositive: true,
                                icon: Icons.phone_android,
                                color: AppColors.danger,
                              ),
                            ),
                          ],
                        ).animate().fadeIn(delay: 200.ms),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                title: AppStrings.habitsDone,
                                value: '${report.totalHabitsCompleted}',
                                change: AppStrings.weekly,
                                isPositive: true,
                                icon: Icons.check_circle_outline,
                                color: AppColors.success,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                title: AppStrings.xpEarned,
                                value: '+${report.weeklyXpEarned}',
                                change: AppStrings.growing,
                                isPositive: report.weeklyXpEarned >= 0,
                                icon: Icons.stars,
                                color: AppColors.warning,
                              ),
                            ),
                          ],
                        ).animate().fadeIn(delay: 300.ms),
                        const SizedBox(height: 16),
                        // Focus vs Distraction ratio bar
                        _FocusDistractRatio(
                          focusHours: double.tryParse(focusTotal) ?? 0,
                          distractHours: double.tryParse(distractTotal) ?? 0,
                        ).animate().fadeIn(delay: 350.ms),
                        const SizedBox(height: 24),
                        Text(
                          AppStrings.dailyBreakdown,
                          style: AppTextStyles.h3,
                        ).animate().fadeIn(delay: 400.ms),
                        const SizedBox(height: 12),
                        _DailyBreakdown(report: report)
                            .animate()
                            .fadeIn(delay: 500.ms),
                        const SizedBox(height: 24),
                        Text(
                          AppStrings.systemAnalysis,
                          style: AppTextStyles.h3,
                        ).animate().fadeIn(delay: 600.ms),
                        const SizedBox(height: 12),
                        GlowCard(
                          glowOpacity: 0.08,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _AnalysisRow(
                                label: AppStrings.focusSessions,
                                value: '${report.totalFocusSessions}',
                                color: AppColors.primaryBlue,
                              ),
                              _AnalysisRow(
                                label: AppStrings.escalationToday,
                                value:
                                    '${report.weeklyEscalationCount}x · S${report.weeklyMaxStage}',
                                color: report.weeklyEscalationCount > 0
                                    ? AppColors.warning
                                    : AppColors.textSecondary,
                              ),
                              if ((report.topDistractingApp ?? '').isNotEmpty)
                                _AnalysisRow(
                                  label: AppStrings.topApp,
                                  value: report.topDistractingApp!,
                                  color: AppColors.danger,
                                ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 700.ms),
                        const SizedBox(height: 16),
                        GlowCard(
                          glowColor: AppColors.warning,
                          borderOpacity: 0.35,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.insights,
                                color: AppColors.warning,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppStrings.systemAnalysis,
                                      style:
                                          AppTextStyles.captionSmall.copyWith(
                                        color: AppColors.warning,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _systemNote(report),
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 760.ms),
                        const SizedBox(height: 24),
                        SystemDecorativeLine(label: AppStrings.analyticsActive)
                            .animate()
                            .fadeIn(delay: 820.ms),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  int _isoWeekNumber() {
    final now = DateTime.now();
    final jan1 = DateTime(now.year, 1, 1);
    final dayOfYear = now.difference(jan1).inDays + 1;
    return ((dayOfYear - now.weekday + 10) / 7).floor();
  }

  String _systemNote(WeeklyReviewReport report) {
    if (report.weeklyEscalationCount == 0 && report.totalHabitsCompleted > 0) {
      return AppStrings.insightAllDone;
    }
    if (report.weeklyMaxStage >= 4) {
      return AppStrings.insightHighDistraction;
    }
    if (report.totalHabitsCompleted == 0) {
      return AppStrings.insightUncompleted;
    }
    return AppStrings.insightProgress;
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String change;
  final bool isPositive;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.change,
    required this.isPositive,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.h3.copyWith(
              color: Colors.white,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            change,
            style: AppTextStyles.caption.copyWith(
              color: isPositive ? AppColors.success : AppColors.danger,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyBreakdown extends StatelessWidget {
  final WeeklyReviewReport report;

  const _DailyBreakdown({required this.report});

  @override
  Widget build(BuildContext context) {
    var maxVal = 1.0;
    for (var i = 0; i < report.days.length; i++) {
      final total = report.focusHours[i] + report.distractHours[i];
      if (total > maxVal) maxVal = total;
    }

    return GlowCard(
      child: Column(
        children: List.generate(report.days.length, (index) {
          final focus = report.focusHours[index];
          final distract = report.distractHours[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 42,
                  child: Text(
                    report.days[index],
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      _BreakdownBar(
                        value: focus / maxVal,
                        color: AppColors.primaryBlue,
                        label: '${focus.toStringAsFixed(1)}h',
                      ),
                      const SizedBox(height: 6),
                      _BreakdownBar(
                        value: distract / maxVal,
                        color: AppColors.danger,
                        label: '${distract.toStringAsFixed(1)}h',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _BreakdownBar extends StatelessWidget {
  final double value;
  final Color color;
  final String label;

  const _BreakdownBar({
    required this.value,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: value.clamp(0.0, 1.0),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              backgroundColor: AppColors.cardBackground.withOpacity(0.4),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 44,
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: AppTextStyles.caption.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _AnalysisRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _AnalysisRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
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
              textAlign: TextAlign.end,
              style: AppTextStyles.bodySmall.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Visual focus-vs-distraction ratio bar for the weekly review.
class _FocusDistractRatio extends StatelessWidget {
  final double focusHours;
  final double distractHours;

  const _FocusDistractRatio({
    required this.focusHours,
    required this.distractHours,
  });

  @override
  Widget build(BuildContext context) {
    final total = focusHours + distractHours;
    final focusRatio = total > 0 ? focusHours / total : 0.5;

    return GlowCard(
      glowOpacity: 0.06,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${AppStrings.focus} ${focusHours.toStringAsFixed(1)}h',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${AppStrings.distraction} ${distractHours.toStringAsFixed(1)}h',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(
                    flex: (focusRatio * 100).round().clamp(1, 99),
                    child: Container(color: AppColors.primaryBlue),
                  ),
                  Expanded(
                    flex: ((1 - focusRatio) * 100).round().clamp(1, 99),
                    child: Container(color: AppColors.danger),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
