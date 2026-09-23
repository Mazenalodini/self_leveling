import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../domain/contracts/runtime_contract.dart';
import '../../../domain/entities/report_models.dart';
import '../../../domain/entities/runtime_visual_summary.dart';
import '../../../navigation/app_router.dart';
import '../../../providers/system_provider.dart';
import '../../../providers/app_init_provider.dart';
import '../../../providers/report_provider.dart';
import '../../../widgets/system_background.dart';
import '../../../widgets/glow_card.dart';
import '../../../widgets/glow_button.dart';
import '../../../widgets/circular_progress_widget.dart';
import '../../../widgets/system_decorative_line.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-check all permissions when user returns from system settings
      ref.read(appInitProvider.notifier).refreshState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final system = ref.watch(systemProvider);
    final initState = ref.watch(appInitProvider);
    final profile = system.profile;
    final nativeState = system.nativeState;
    final dashboardReport = ref.watch(dashboardReportProvider).valueOrNull ??
        const DashboardReport();
    final runtimeSummary = ref.watch(runtimeVisualSummaryProvider);

    final userName = profile.displayName;
    final userLevel = profile.level;
    final selfControlLevel = profile.selfControlScore;
    final completedHabits = dashboardReport.todayHabitCompletions;
    final distractionScore = system.distractionScore;
    final statusText = _runtimeStatusText(runtimeSummary, nativeState);
    final statusColor = _runtimeStatusColor(runtimeSummary);

    // Detect if critical permissions were revoked after setup
    final permsMissing = !initState.isLoading &&
        (!initState.usageStatsGranted || !initState.overlayGranted);

    return SystemBackground(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(
          left: AppSpacing.screenPadding,
          right: AppSpacing.screenPadding,
          top: 48,
          bottom: AppSpacing.bottomNavPaddingBottom,
        ),
        child: Column(
          children: [
            // ═══ CRITICAL PERMISSIONS REVOKED BANNER ═══
            if (permsMissing)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlowCard(
                  glowColor: AppColors.danger,
                  glowOpacity: 0.2,
                  borderOpacity: 0.5,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined,
                          color: AppColors.danger, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.permissionsRevoked,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.danger,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppStrings.permissionsRevokedDesc,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 32,
                        child: ElevatedButton(
                          onPressed: () => context.push(RoutePaths.setup),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                AppColors.danger.withOpacity(0.15),
                            foregroundColor: AppColors.danger,
                            elevation: 0,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                  color: AppColors.danger.withOpacity(0.3)),
                            ),
                          ),
                          child: Text(AppStrings.fixNow,
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn().slideY(begin: -0.15),
              ),

            // ═══ NOTIFICATION READINESS BANNER ═══
            if (!initState.notificationGranted)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlowCard(
                  glowColor: AppColors.warning,
                  glowOpacity: 0.15,
                  borderOpacity: 0.4,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.notifications_off,
                          color: AppColors.warning, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          AppStrings.notifDisabledWarning,
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.warning),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 32,
                        child: ElevatedButton(
                          onPressed: () => ref
                              .read(appInitProvider.notifier)
                              .requestNotification(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                AppColors.warning.withOpacity(0.15),
                            foregroundColor: AppColors.warning,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                  color: AppColors.warning.withOpacity(0.3)),
                            ),
                          ),
                          child: Text(AppStrings.enableLabel,
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn().slideY(begin: -0.15),
              ),

            // User Identity
            GlowCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userName, style: AppTextStyles.h3),
                        const SizedBox(height: 4),
                        Row(children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: statusColor.withOpacity(0.5),
                                    blurRadius: 8)
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(statusText,
                              style: AppTextStyles.secondaryText
                                  .copyWith(color: statusColor)),
                        ]),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push(RoutePaths.level),
                    child: Row(
                      children: [
                        Text(
                          AppStrings.level,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryBlue.withOpacity(0.5),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                          child: Text('$userLevel', style: AppTextStyles.h3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2),

            const SizedBox(height: 32),

            // Self Control Level
            GlowCard(
              glowBlur: 60,
              glowOpacity: 0.15,
              child: Column(
                children: [
                  Text(
                    AppStrings.selfControlLevel,
                    style: AppTextStyles.captionSmall.copyWith(
                      color: AppColors.textSecondary,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 24),
                  CircularProgressWidget(
                    progress: selfControlLevel / 100,
                    center: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) =>
                              AppColors.primaryGradient.createShader(bounds),
                          child: Text(
                            '$selfControlLevel%',
                            style:
                                AppTextStyles.h1.copyWith(color: Colors.white),
                          ),
                        ),
                        Text(
                          AppStrings.control,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(delay: 200.ms)
                .scale(begin: const Offset(0.9, 0.9)),

            const SizedBox(height: 24),

            // Summary cards — real data
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    icon: Icons.trending_up,
                    value: '${profile.currentXP}',
                    label: AppStrings.xpLabel,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    icon: Icons.phone_android,
                    value:
                        '${dashboardReport.todayDistractionHours.toStringAsFixed(1)}h',
                    label: AppStrings.distraction,
                    color: dashboardReport.todayDistractionHours > 1
                        ? AppColors.danger
                        : AppColors.primaryCyan,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    icon: Icons.check_circle_outline,
                    value: '$completedHabits',
                    label: AppStrings.habits,
                    color: AppColors.success,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),

            const SizedBox(height: 24),

            // Quick Actions Grid
            Row(
              children: [
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.person_outline,
                    label: AppStrings.identityLabel,
                    color: const Color(0xFF8B5CF6),
                    onTap: () => context.push(RoutePaths.identityBuilder),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.account_tree,
                    label: AppStrings.skillsLabel,
                    color: const Color(0xFF06B6D4),
                    onTap: () => context.push(RoutePaths.skillTrees),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.local_fire_department,
                    label: AppStrings.dungeonsLabel,
                    color: const Color(0xFFEF4444),
                    onTap: () => context.push(RoutePaths.dungeons),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.calendar_view_week,
                    label: AppStrings.reviewLabel,
                    color: const Color(0xFF22C55E),
                    onTap: () => context.push(RoutePaths.weeklyReview),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),

            const SizedBox(height: 24),

            // AI Message Card
            GestureDetector(
              onTap: () => context.go(RoutePaths.ai),
              child: GlowCard(
                glowOpacity: 0.1,
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
                                  color: AppColors.primaryBlue.withOpacity(0.5),
                                  blurRadius: 12),
                            ],
                          ),
                        ),
                        const Icon(Icons.auto_awesome,
                            color: AppColors.primaryBlue, size: 24),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.systemMessage,
                            style: AppTextStyles.captionSmall.copyWith(
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getSystemMessage(
                                selfControlLevel, distractionScore),
                            style: AppTextStyles.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 600.ms),

            const SizedBox(height: 24),

            // Focus Mode Button
            GlowButton(
              text: AppStrings.startFocusMode,
              onPressed: () => context.push(RoutePaths.focusMode),
              glowOpacity: 0.6,
            ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.2),

            const SizedBox(height: 32),

            SystemDecorativeLine(label: AppStrings.activeSystem)
                .animate()
                .fadeIn(delay: 1000.ms),
          ],
        ),
      ),
    );
  }

  String _getSystemMessage(int selfControl, double distraction) {
    if (selfControl >= 80) return AppStrings.msgExcellent;
    if (selfControl >= 60) return AppStrings.msgImproving;
    if (distraction > 0.6) return AppStrings.msgHighDistract;
    if (selfControl >= 40) return AppStrings.msgRoomImprove;
    return AppStrings.msgNeedsAttention;
  }

  String _runtimeStatusText(
    RuntimeVisualSummary runtimeSummary,
    RuntimeStateSnapshot nativeState,
  ) {
    switch (runtimeSummary.status) {
      case RuntimeVisualStatus.inactive:
        return AppStrings.inactive;
      case RuntimeVisualStatus.focusMode:
        return AppStrings.focusModeActive;
      case RuntimeVisualStatus.monitoring:
        return AppStrings.monitoringStatus;
      case RuntimeVisualStatus.warning:
      case RuntimeVisualStatus.blocking:
      case RuntimeVisualStatus.limitedAccess:
      case RuntimeVisualStatus.hardLock:
        return nativeState.stageName;
    }
  }

  Color _runtimeStatusColor(RuntimeVisualSummary runtimeSummary) {
    switch (runtimeSummary.status) {
      case RuntimeVisualStatus.inactive:
        return AppColors.textSecondary;
      case RuntimeVisualStatus.focusMode:
        return AppColors.success;
      case RuntimeVisualStatus.monitoring:
        return AppColors.primaryBlue;
      case RuntimeVisualStatus.warning:
        return AppColors.warning;
      case RuntimeVisualStatus.blocking:
      case RuntimeVisualStatus.limitedAccess:
      case RuntimeVisualStatus.hardLock:
        return AppColors.danger;
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      glowColor: color,
      glowOpacity: 0.2,
      borderOpacity: 0.3,
      backgroundOpacity: 0.6,
      borderRadius: AppSpacing.radiusLarge,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(value, style: AppTextStyles.h3),
          const SizedBox(height: 4),
          Text(
            label,
            style:
                AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
