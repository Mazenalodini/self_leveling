import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import 'package:go_router/go_router.dart';
import '../../../navigation/app_router.dart';
import '../../../providers/system_provider.dart';
import '../../../providers/app_init_provider.dart';
import '../../../widgets/system_background.dart';
import '../../../widgets/glow_card.dart';
import '../../../widgets/toggle_switch.dart';
import '../../../widgets/system_decorative_line.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Refresh permissions when settings screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appInitProvider.notifier).refreshState();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-check permissions when returning from system settings.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(appInitProvider.notifier).refreshState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final system = ref.watch(systemProvider);
    final initState = ref.watch(appInitProvider);
    final profile = system.profile;

    final sensitivityLabel = profile.systemSensitivity < 0.35
        ? AppStrings.lowLabel
        : profile.systemSensitivity < 0.65
            ? AppStrings.mediumLabel
            : AppStrings.highLabel;

    final escalationLabel = profile.escalationStrength < 0.35
        ? AppStrings.softLabel
        : profile.escalationStrength < 0.65
            ? AppStrings.balancedLabel
            : AppStrings.strictLabel;

    return SystemBackground(
      particleCount: 8,
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
            // Header
            Row(
              children: [
                Stack(alignment: Alignment.center, children: [
                  Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(boxShadow: [
                        BoxShadow(
                            color: AppColors.primaryBlue.withOpacity(0.5),
                            blurRadius: 16)
                      ])),
                  const Icon(Icons.settings,
                      color: AppColors.primaryBlue, size: 24),
                ]),
                const SizedBox(width: 12),
                Text(AppStrings.settings, style: AppTextStyles.h2),
              ],
            ).animate().fadeIn().slideY(begin: -0.2),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Text(AppStrings.customizeSystem,
                  style: AppTextStyles.secondaryText),
            ),
            const SizedBox(height: 8),
            Container(
                height: 1,
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [
                  AppColors.primaryBlue,
                  AppColors.primaryCyan,
                  Colors.transparent
                ].map((c) => c.withOpacity(0.3)).toList()))),

            const SizedBox(height: 24),

            // ═══ NOTIFICATION PERMISSION BANNER ═══
            // Show if notification permission is missing
            if (!initState.notificationGranted)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: GlowCard(
                  glowColor: AppColors.warning,
                  glowOpacity: 0.2,
                  borderOpacity: 0.5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.warning.withOpacity(0.15),
                            ),
                            child: const Icon(Icons.notifications_off,
                                color: AppColors.warning, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(AppStrings.notificationsDisabledTitle,
                                    style: AppTextStyles.label
                                        .copyWith(color: AppColors.warning)),
                                const SizedBox(height: 2),
                                Text(
                                  AppStrings.cannotDeliverWarnings,
                                  style: AppTextStyles.caption
                                      .copyWith(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => ref
                              .read(appInitProvider.notifier)
                              .requestNotification(),
                          icon:
                              const Icon(Icons.notifications_active, size: 18),
                          label: Text(AppStrings.enableNotifications),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                AppColors.warning.withOpacity(0.15),
                            foregroundColor: AppColors.warning,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                  color: AppColors.warning.withOpacity(0.3)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn().slideY(begin: -0.1),
              ),

            // System Sensitivity
            GlowCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.radio,
                        color: AppColors.primaryBlue, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(AppStrings.systemSensitivity,
                              style: AppTextStyles.label),
                          Text(AppStrings.howQuicklySystemDetects,
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.textSecondary)),
                        ])),
                  ]),
                  const SizedBox(height: 16),
                  Row(
                      children: [
                    (AppStrings.lowLabel, 0.2),
                    (AppStrings.mediumLabel, 0.5),
                    (AppStrings.highLabel, 0.8),
                  ]
                          .map((o) => Expanded(
                              child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: _OptionButton(
                                    label: o.$1,
                                    selected: sensitivityLabel == o.$1,
                                    onTap: () => ref
                                        .read(systemProvider.notifier)
                                        .updateSensitivity(o.$2),
                                  ))))
                          .toList()),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms),

            const SizedBox(height: 16),

            // Escalation Strength
            GlowCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.shield,
                        color: AppColors.primaryBlue, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(AppStrings.escalationStrength,
                              style: AppTextStyles.label),
                          Text(AppStrings.howStrictSystemResponds,
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.textSecondary)),
                        ])),
                  ]),
                  const SizedBox(height: 16),
                  Row(
                      children: [
                    (AppStrings.softLabel, 0.2),
                    (AppStrings.balancedLabel, 0.5),
                    (AppStrings.strictLabel, 0.8),
                  ]
                          .map((o) => Expanded(
                              child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: _OptionButton(
                                    label: o.$1,
                                    selected: escalationLabel == o.$1,
                                    onTap: () => ref
                                        .read(systemProvider.notifier)
                                        .updateEscalationStrength(o.$2),
                                  ))))
                          .toList()),
                ],
              ),
            ).animate().fadeIn(delay: 300.ms),

            const SizedBox(height: 16),

            // Notifications toggle
            GlowCard(
              child: Row(children: [
                const Icon(Icons.notifications_outlined,
                    color: AppColors.primaryBlue, size: 20),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(AppStrings.notifications,
                          style: AppTextStyles.label),
                      Text(AppStrings.receiveAlertsReminders,
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textSecondary)),
                    ])),
                ToggleSwitch(
                  value: profile.notificationsEnabled,
                  onChanged: (val) => ref
                      .read(systemProvider.notifier)
                      .updateNotifications(val),
                ),
              ]),
            ).animate().fadeIn(delay: 400.ms),

            const SizedBox(height: 16),

            // System status card — now includes notification permission
            GlowCard(
              glowOpacity: 0.1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.systemStatus, style: AppTextStyles.label),
                  const SizedBox(height: 12),
                  _StatusRow(
                      AppStrings.tracking,
                      system.isTrackingActive
                          ? AppStrings.active
                          : AppStrings.inactive,
                      system.isTrackingActive
                          ? AppColors.success
                          : AppColors.textTertiary),
                  _StatusRow(
                      AppStrings.usagePermission,
                      initState.usageStatsGranted
                          ? AppStrings.granted
                          : AppStrings.requiredStr,
                      initState.usageStatsGranted
                          ? AppColors.success
                          : AppColors.warning),
                  _StatusRow(
                      AppStrings.overlayPermission,
                      initState.overlayGranted
                          ? AppStrings.granted
                          : AppStrings.requiredStr,
                      initState.overlayGranted
                          ? AppColors.success
                          : AppColors.warning),
                  _StatusRow(
                      AppStrings.liveDetectionPermission,
                      initState.accessibilityGranted
                          ? AppStrings.granted
                          : AppStrings.recommendedLabel,
                      initState.accessibilityGranted
                          ? AppColors.success
                          : AppColors.primaryCyan),
                  _StatusRow(
                      'Notification',
                      initState.notificationGranted
                          ? AppStrings.granted
                          : 'Missing',
                      initState.notificationGranted
                          ? AppColors.success
                          : AppColors.warning),
                  _StatusRow(
                      AppStrings.currentLevel,
                      'S${system.nativeState.escalationStage}',
                      AppColors.primaryBlue),
                ],
              ),
            ).animate().fadeIn(delay: 450.ms),

            const SizedBox(height: 16),

            // Settings links
            ...[
              (
                Icons.apps,
                AppStrings.appManagement,
                500,
                RoutePaths.appBlacklist
              ),
              (
                Icons.timer,
                AppStrings.usageLimits,
                520,
                RoutePaths.usageLimits
              ),
              (
                Icons.analytics,
                AppStrings.usageDashboard,
                540,
                RoutePaths.usageDashboard
              ),
              (
                Icons.track_changes,
                AppStrings.habitPriority,
                560,
                RoutePaths.habitPriority
              ),
              (
                Icons.shield,
                AppStrings.escalationSettings,
                580,
                RoutePaths.escalation
              ),
              (
                Icons.person_outline,
                AppStrings.profileSettings,
                600,
                RoutePaths.profile
              ),
              (Icons.language, AppStrings.language, 620, RoutePaths.language),
              (
                Icons.help_outline,
                AppStrings.helpAndSupport,
                640,
                RoutePaths.helpSupport
              ),
            ].map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SettingsLink(
                      icon: item.$1,
                      label: item.$2,
                      onTap: () {
                        if (item.$4.isNotEmpty) context.push(item.$4);
                      }),
                ).animate().fadeIn(delay: Duration(milliseconds: item.$3))),

            const SizedBox(height: 16),

            // Logout removed for Single-Account mode (moved to debug view)
            const SizedBox(height: 24),

            Center(
                child: Column(children: [
              GestureDetector(
                onLongPress:
                    kDebugMode ? () => context.push(RoutePaths.aiDebug) : null,
                child: Text('${AppStrings.appName} ${AppStrings.appVersion}',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary)),
              ),
              const SizedBox(height: 4),
              Opacity(
                  opacity: 0.6,
                  child: Text(AppStrings.systemInterfaceActive,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary))),
            ])).animate().fadeIn(delay: 800.ms),

            const SizedBox(height: 24),
            SystemDecorativeLine(label: AppStrings.settingsPanel)
                .animate()
                .fadeIn(delay: 900.ms),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatusRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary)),
          Row(children: [
            Container(
                width: 6,
                height: 6,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(value,
                style: AppTextStyles.caption
                    .copyWith(color: color, fontWeight: FontWeight.w600)),
          ]),
        ],
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OptionButton(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(clipBehavior: Clip.none, children: [
        if (selected)
          Positioned(
              left: -2,
              right: -2,
              top: -2,
              bottom: -2,
              child: Container(
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primaryBlue.withOpacity(0.3),
                          blurRadius: 8)
                    ]),
              )),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primaryBlue.withOpacity(0.2)
                : AppColors.background.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppColors.primaryBlue.withOpacity(selected ? 0.6 : 0.2)),
          ),
          child: Center(
              child: Text(
            label[0].toUpperCase() + label.substring(1),
            style: AppTextStyles.caption.copyWith(
                color:
                    selected ? AppColors.primaryBlue : AppColors.textSecondary,
                fontWeight: FontWeight.w500),
          )),
        ),
      ]),
    );
  }
}

class _SettingsLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SettingsLink(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      glowOpacity: 0.1,
      backgroundOpacity: 0.4,
      borderOpacity: 0.2,
      padding: const EdgeInsets.all(20),
      onTap: onTap,
      child: Row(children: [
        Icon(icon, color: AppColors.primaryBlue, size: 20),
        const SizedBox(width: 12),
        Expanded(
            child: Text(label,
                style: AppTextStyles.bodySmall
                    .copyWith(fontWeight: FontWeight.w500))),
        const Icon(Icons.chevron_right,
            color: AppColors.textSecondary, size: 20),
      ]),
    );
  }
}
