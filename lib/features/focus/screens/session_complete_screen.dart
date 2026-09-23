import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../widgets/system_background.dart';
import '../../../widgets/glow_card.dart';
import '../../../widgets/glow_button.dart';
import '../../../widgets/system_decorative_line.dart';
import '../../../navigation/app_router.dart';
import '../../../domain/entities/focus_session.dart';
import '../../../providers/focus_provider.dart';

class SessionCompleteScreen extends ConsumerWidget {
  const SessionCompleteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focusState = ref.watch(focusProvider);
    final extra = GoRouterState.of(context).extra;
    FocusSession? completedSession;

    if (extra is FocusSession && extra.wasCompleted) {
      completedSession = extra;
    } else if (extra is Map<String, dynamic>) {
      final maybeCompleted = FocusSession(
        id: extra['id'] as String? ?? '',
        durationMinutes: extra['durationMinutes'] as int? ?? 0,
        startedAt: extra['startedAt'] is DateTime
            ? extra['startedAt'] as DateTime
            : DateTime.now(),
        completedAt: extra['completedAt'] is DateTime
            ? extra['completedAt'] as DateTime
            : DateTime.now(),
        wasCompleted: extra['wasCompleted'] as bool? ?? false,
        xpEarned: extra['xpEarned'] as int? ?? 0,
      );
      if (maybeCompleted.wasCompleted) {
        completedSession = maybeCompleted;
      }
    }
    completedSession ??= focusState.latestCompletedSession;

    if (completedSession == null) {
      return Scaffold(
        body: SystemBackground(
          particleCount: 20,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppStrings.sessionSummaryUnavailable,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.h2,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppStrings.sessionSummaryUnavailableBody,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 32),
                  GlowButton(
                    text: AppStrings.returnToDashboard,
                    gradient: AppColors.primaryGradient,
                    onPressed: () => context.go(RoutePaths.dashboard),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final focusTime = completedSession.actualDuration.inMinutes;
    final xpGained = completedSession.xpEarned;
    final todaySessions = focusState.todaySessionCount;
    final progressFraction = (todaySessions / 4.0).clamp(0.0, 1.0);

    return Scaffold(
      body: SystemBackground(
        particleCount: 30,
        child: SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Success icon
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      gradient: AppColors.successGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.success.withOpacity(0.4),
                            blurRadius: 40,
                            spreadRadius: 8),
                        BoxShadow(
                            color: AppColors.primaryBlue.withOpacity(0.3),
                            blurRadius: 40,
                            spreadRadius: 8),
                      ],
                    ),
                    child: const Icon(Icons.check_circle_outline,
                        color: Colors.white, size: 56),
                  ).animate().fadeIn(duration: 600.ms).scale(
                      begin: const Offset(0, 0),
                      end: const Offset(1, 1),
                      curve: Curves.elasticOut,
                      duration: 800.ms),

                  const SizedBox(height: 32),

                  // Title
                  Text(AppStrings.sessionCompleteTitle,
                          style: AppTextStyles.h1.copyWith(fontSize: 40))
                      .animate()
                      .fadeIn(delay: 300.ms)
                      .slideY(begin: 0.2),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                        width: 64,
                        height: 1,
                        decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                          Colors.transparent,
                          AppColors.success
                        ]))),
                    const SizedBox(width: 12),
                    const Icon(Icons.auto_awesome,
                        color: AppColors.success, size: 16),
                    const SizedBox(width: 12),
                    Container(
                        width: 64,
                        height: 1,
                        decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                          AppColors.success,
                          Colors.transparent
                        ]))),
                  ]).animate().fadeIn(delay: 400.ms),

                  const SizedBox(height: 40),

                  // Stat cards — REAL values from session
                  Row(children: [
                    Expanded(
                        child: GlowCard(
                      glowColor: AppColors.primaryBlue,
                      borderRadius: 16,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.trending_up,
                                  color: AppColors.primaryBlue, size: 16),
                              const SizedBox(width: 8),
                              Text(AppStrings.focusTimeLabel,
                                  style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textSecondary)),
                            ]),
                            const SizedBox(height: 8),
                            Text('${focusTime}m', style: AppTextStyles.h2),
                            Text(AppStrings.completedLabel,
                                style: AppTextStyles.caption
                                    .copyWith(color: AppColors.primaryBlue)),
                          ]),
                    )),
                    const SizedBox(width: 16),
                    Expanded(
                        child: GlowCard(
                      glowColor: AppColors.success,
                      borderRadius: 16,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.emoji_events,
                                  color: AppColors.success, size: 16),
                              const SizedBox(width: 8),
                              Text(AppStrings.xpGainedLabel,
                                  style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textSecondary)),
                            ]),
                            const SizedBox(height: 8),
                            Text('+$xpGained',
                                style: AppTextStyles.h2
                                    .copyWith(color: AppColors.success)),
                            Text(AppStrings.experienceLabel,
                                style: AppTextStyles.caption
                                    .copyWith(color: AppColors.success)),
                          ]),
                    )),
                  ]).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),

                  const SizedBox(height: 32),

                  // Achievement message
                  GlowCard(
                    glowColor: AppColors.success,
                    backgroundOpacity: 0.5,
                    borderOpacity: 0.3,
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.textSecondary),
                          children: [
                            TextSpan(text: AppStrings.greatJobYoure),
                            TextSpan(
                                text: AppStrings.improvingLabel,
                                style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w600)),
                            const TextSpan(text: '.'),
                          ]),
                    ),
                  ).animate().fadeIn(delay: 700.ms),

                  const SizedBox(height: 32),

                  // Progress bar — REAL session count
                  GlowCard(
                    backgroundOpacity: 0.4,
                    borderOpacity: 0.2,
                    padding: const EdgeInsets.all(20),
                    child: Column(children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(AppStrings.todaysProgress,
                                style: AppTextStyles.caption
                                    .copyWith(color: AppColors.textSecondary)),
                            Text(
                                '$todaySessions / 4 ${AppStrings.focusSessions.toLowerCase()}',
                                style: AppTextStyles.caption.copyWith(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w600)),
                          ]),
                      const SizedBox(height: 12),
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(4)),
                        child: FractionallySizedBox(
                          widthFactor: progressFraction,
                          alignment: Alignment.centerLeft,
                          child: Container(
                              decoration: BoxDecoration(
                            gradient: AppColors.successGradient,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                  color: AppColors.success.withOpacity(0.6),
                                  blurRadius: 12)
                            ],
                          )),
                        ),
                      ),
                    ]),
                  ).animate().fadeIn(delay: 900.ms),

                  const SizedBox(height: 40),

                  // Continue button
                  GlowButton(
                    text: AppStrings.continueBtn,
                    gradient: AppColors.successGradient,
                    onPressed: () => context.go(RoutePaths.dashboard),
                  ).animate().fadeIn(delay: 1100.ms).slideY(begin: 0.2),

                  const SizedBox(height: 48),
                  SystemDecorativeLine(
                          label: AppStrings.success, color: AppColors.success)
                      .animate()
                      .fadeIn(delay: 1300.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
