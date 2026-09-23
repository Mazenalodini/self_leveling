import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../navigation/app_router.dart';
import '../../../providers/app_init_provider.dart';
import '../../../widgets/system_background.dart';
import '../../../widgets/glow_button.dart';
import '../../../widgets/glow_card.dart';

/// Multi-step setup screen for system initialization.
/// Steps: 0) Welcome  1) Usage Stats  2) Overlay  3) Notifications  4) Accessibility  5) Activate
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen>
    with WidgetsBindingObserver {
  int _currentStep = 0;

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

  /// Re-check permissions when returning from system settings.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(appInitProvider.notifier).refreshState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final initState = ref.watch(appInitProvider);
    _handleInitStateTransitions(initState);

    return Scaffold(
      body: SystemBackground(
        particleCount: 12,
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _StepProgress(currentStep: _currentStep, totalSteps: 5)
                    .animate()
                    .fadeIn(),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: _buildCurrentStep(initState),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleInitStateTransitions(AppInitState initState) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || initState.isLoading) return;

      if (initState.canEnterCoreSurfaces) {
        context.go(RoutePaths.dashboard);
        return;
      }

      switch (initState.entryTarget) {
        case AppEntryTarget.welcome:
          context.go(RoutePaths.welcome);
          return;
        case AppEntryTarget.onboarding:
          context.go(RoutePaths.onboarding);
          return;
        case AppEntryTarget.setup:
          final targetStep = _setupStepForState(initState);
          if (_currentStep != targetStep) {
            setState(() => _currentStep = targetStep);
          }
          return;
        case AppEntryTarget.dashboard:
          context.go(RoutePaths.dashboard);
          return;
      }
    });
  }

  int _setupStepForState(AppInitState initState) {
    final noPermissionsGranted = !initState.usageStatsGranted &&
        !initState.overlayGranted &&
        !initState.notificationGranted;
    if (_currentStep == 0 &&
        noPermissionsGranted &&
        !initState.wasActivated &&
        !initState.engineRunning) {
      return 0;
    }
    if (!initState.usageStatsGranted) return 1;
    if (!initState.overlayGranted) return 2;
    if (!initState.notificationGranted) return 3;
    if (!initState.accessibilityGranted) return 4;
    return 5;
  }

  Widget _buildCurrentStep(AppInitState initState) {
    switch (_currentStep) {
      case 0:
        return _IntroStep(
          key: const ValueKey(0),
          onNext: () => setState(() => _currentStep = 1),
        );
      case 1:
        return _UsageStatsStep(
          key: const ValueKey(1),
          isGranted: initState.usageStatsGranted,
          onRequest: () =>
              ref.read(appInitProvider.notifier).requestUsageStats(),
          onRefresh: () => ref.read(appInitProvider.notifier).refreshState(),
          onNext: () => setState(() => _currentStep = 2),
        );
      case 2:
        return _OverlayStep(
          key: const ValueKey(2),
          isGranted: initState.overlayGranted,
          onRequest: () => ref.read(appInitProvider.notifier).requestOverlay(),
          onRefresh: () => ref.read(appInitProvider.notifier).refreshState(),
          onNext: () => setState(() => _currentStep = 3),
        );
      case 3:
        return _NotificationStep(
          key: const ValueKey(3),
          isGranted: initState.notificationGranted,
          onRequest: () =>
              ref.read(appInitProvider.notifier).requestNotification(),
          onRefresh: () => ref.read(appInitProvider.notifier).refreshState(),
          onNext: () => setState(() => _currentStep = 4),
        );
      case 4:
        return _AccessibilityStep(
          key: const ValueKey(4),
          isGranted: initState.accessibilityGranted,
          onRequest: () =>
              ref.read(appInitProvider.notifier).requestAccessibility(),
          onRefresh: () => ref.read(appInitProvider.notifier).refreshState(),
          onNext: () => setState(() => _currentStep = 5),
        );
      case 5:
        return _ActivateStep(
          key: const ValueKey(5),
          isActivating: initState.isActivating,
          isActivatable: initState.canActivateEngine,
          isDegraded: initState.isDegraded,
          engineRunning: initState.engineRunning,
          accessibilityGranted: initState.accessibilityGranted,
          onRequestAccessibility: () =>
              ref.read(appInitProvider.notifier).requestAccessibility(),
          onActivate: () => _handleActivation(),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _handleActivation() async {
    final notifier = ref.read(appInitProvider.notifier);
    await notifier.refreshState();
    if (!mounted) return;

    final initState = ref.read(appInitProvider);
    if (initState.canEnterCoreSurfaces) {
      context.go(RoutePaths.dashboard);
      return;
    }
    if (!initState.canActivateEngine) {
      setState(() => _currentStep = _setupStepForState(initState));
      return;
    }

    final success = await notifier.activateSystem();
    if (!mounted) return;

    final updatedState = ref.read(appInitProvider);
    if (success && updatedState.canEnterCoreSurfaces) {
      context.go(RoutePaths.dashboard);
      return;
    }

    setState(() => _currentStep = _setupStepForState(updatedState));
  }
}

// ═══════════════════════════════════════════
// Step 0: Introduction
// ═══════════════════════════════════════════
class _IntroStep extends StatelessWidget {
  final VoidCallback onNext;
  const _IntroStep({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
              boxShadow: [
                BoxShadow(
                    color: AppColors.primaryBlue.withOpacity(0.4),
                    blurRadius: 40),
              ],
            ),
            child: const Icon(Icons.shield, color: Colors.white, size: 48),
          ).animate().scale(duration: 800.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 32),
          Text('System Initialization',
                  style: AppTextStyles.h2, textAlign: TextAlign.center)
              .animate()
              .fadeIn(delay: 300.ms),
          const SizedBox(height: 16),
          Text(
            'Self Leveling needs to understand your behavior to help you grow.',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 500.ms),
          const SizedBox(height: 32),
          GlowCard(
            glowOpacity: 0.1,
            backgroundOpacity: 0.4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(Icons.visibility, 'Monitor screen usage'),
                const SizedBox(height: 12),
                _InfoRow(Icons.shield, 'Enforce focus discipline'),
                const SizedBox(height: 12),
                _InfoRow(
                    Icons.notifications_active, 'Deliver behavioral warnings'),
                const SizedBox(height: 12),
                _InfoRow(Icons.trending_up, 'Reward positive behavior'),
              ],
            ),
          ).animate().fadeIn(delay: 700.ms),
          const SizedBox(height: 48),
          GlowButton(
            text: 'Begin Setup',
            icon: Icons.arrow_forward,
            onPressed: onNext,
            glowOpacity: 0.6,
          ).animate().fadeIn(delay: 900.ms).slideY(begin: 0.3),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Step 1: Usage Stats Permission
// ═══════════════════════════════════════════
class _UsageStatsStep extends StatelessWidget {
  final bool isGranted;
  final VoidCallback onRequest;
  final VoidCallback onRefresh;
  final VoidCallback onNext;

  const _UsageStatsStep({
    super.key,
    required this.isGranted,
    required this.onRequest,
    required this.onRefresh,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return _PermissionStep(
      icon: isGranted ? Icons.check_circle : Icons.bar_chart,
      iconColor: isGranted ? AppColors.success : AppColors.warning,
      title: AppStrings.usageAnalytics,
      description: isGranted
          ? AppStrings.permissionGranted
          : AppStrings.usagePermissionDesc,
      isGranted: isGranted,
      reason: AppStrings.usagePermissionReason,
      reasonColor: AppColors.warning,
      onRequest: onRequest,
      onRefresh: onRefresh,
      onNext: onNext,
      nextLabel: AppStrings.continueBtn,
    );
  }
}

// ═══════════════════════════════════════════
// Step 2: Overlay Permission
// ═══════════════════════════════════════════
class _OverlayStep extends StatelessWidget {
  final bool isGranted;
  final VoidCallback onRequest;
  final VoidCallback onRefresh;
  final VoidCallback onNext;

  const _OverlayStep({
    super.key,
    required this.isGranted,
    required this.onRequest,
    required this.onRefresh,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return _PermissionStep(
      icon: isGranted ? Icons.check_circle : Icons.layers,
      iconColor: isGranted ? AppColors.success : AppColors.primaryCyan,
      title: AppStrings.displayOverlay,
      description: isGranted
          ? AppStrings.permissionGranted
          : AppStrings.overlayPermissionDesc,
      isGranted: isGranted,
      reason: AppStrings.overlayPermissionReason,
      reasonColor: AppColors.primaryCyan,
      onRequest: onRequest,
      onRefresh: onRefresh,
      onNext: onNext,
      nextLabel: AppStrings.continueBtn,
    );
  }
}

// ═══════════════════════════════════════════
// Step 3: Notification Permission (NEW)
// ═══════════════════════════════════════════
class _NotificationStep extends StatelessWidget {
  final bool isGranted;
  final VoidCallback onRequest;
  final VoidCallback onRefresh;
  final VoidCallback onNext;

  const _NotificationStep({
    super.key,
    required this.isGranted,
    required this.onRequest,
    required this.onRefresh,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return _PermissionStep(
      icon: isGranted ? Icons.check_circle : Icons.notifications_active,
      iconColor: isGranted ? AppColors.success : AppColors.primaryBlue,
      title: 'Notifications',
      description: isGranted
          ? AppStrings.permissionGranted
          : 'Allow Self Leveling to send behavioral warnings and reminders.',
      isGranted: isGranted,
      reason:
          'Notifications are essential for the escalation system. When you spend too much time on a distracting app, Self Leveling will warn you before taking stronger action. Without this permission, you will only see overlay blocks without prior warnings.',
      reasonColor: AppColors.primaryBlue,
      onRequest: onRequest,
      onRefresh: onRefresh,
      onNext: onNext,
      nextLabel: AppStrings.continueBtn,
      requestLabel: 'Allow Notifications',
      requestIcon: Icons.notifications_active,
    );
  }
}

// ═══════════════════════════════════════════
// Step 4: Accessibility Service Permission
// ═══════════════════════════════════════════
class _AccessibilityStep extends StatelessWidget {
  final bool isGranted;
  final VoidCallback onRequest;
  final VoidCallback onRefresh;
  final VoidCallback onNext;

  const _AccessibilityStep({
    super.key,
    required this.isGranted,
    required this.onRequest,
    required this.onRefresh,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = AppStrings.isArabic;
    return _PermissionStep(
      icon: isGranted ? Icons.check_circle : Icons.settings_accessibility,
      iconColor: isGranted ? AppColors.success : AppColors.primaryCyan,
      title: isAr ? 'خدمة إمكانية الوصول' : 'Accessibility Service',
      description: isGranted
          ? AppStrings.permissionGranted
          : isAr
              ? 'فعّل خدمة إمكانية الوصول للكشف المباشر عن التطبيقات'
              : 'Enable Accessibility Service for live app detection',
      isGranted: isGranted,
      reason: isAr
          ? 'خدمة إمكانية الوصول تمكّن النظام من كشف التطبيق الذي تستخدمه فوراً وتفعيل نظام التصعيد في الوقت الحقيقي. بدون هذا الإذن، لن يعمل الكشف المباشر وسيعتمد النظام على بيانات الاستخدام المتأخرة فقط.\n\nملاحظة: عند تحديث التطبيق قد يتم تعطيل هذا الإذن تلقائياً من قبل النظام. يرجى إعادة تفعيله.'
          : 'Accessibility Service enables real-time detection of which app you are using, powering the escalation engine instantly. Without it, live detection won\'t work and the system will rely on delayed usage data only.\n\nNote: After app updates, Android may automatically disable this permission. Please re-enable it.',
      reasonColor: AppColors.primaryCyan,
      onRequest: onRequest,
      onRefresh: onRefresh,
      onNext: onNext,
      nextLabel: AppStrings.continueBtn,
      requestLabel: isAr ? 'تفعيل الخدمة' : 'Enable Service',
      requestIcon: Icons.settings_accessibility,
    );
  }
}

// ═══════════════════════════════════════════
// Step 5: System Activation
// ═══════════════════════════════════════════
class _ActivateStep extends StatelessWidget {
  final bool isActivating;
  final bool isActivatable;
  final bool isDegraded;
  final bool engineRunning;
  final bool accessibilityGranted;
  final VoidCallback onRequestAccessibility;
  final VoidCallback onActivate;

  const _ActivateStep({
    super.key,
    required this.isActivating,
    required this.isActivatable,
    required this.isDegraded,
    required this.engineRunning,
    required this.accessibilityGranted,
    required this.onRequestAccessibility,
    required this.onActivate,
  });

  @override
  Widget build(BuildContext context) {
    final title = isActivating
        ? 'Activating System...'
        : isDegraded
            ? 'Repair Runtime'
            : engineRunning
                ? 'Runtime Already Active'
                : 'Ready to Launch';
    final description = isActivating
        ? 'Starting behavioral tracking service...'
        : !isActivatable
            ? 'Complete the required permissions first. The runtime engine only becomes activatable after the system is fully ready.'
            : isDegraded
                ? 'Your profile and permissions are available, but the runtime engine is not currently healthy. Re-activate it to restore monitoring.'
                : engineRunning
                    ? 'The runtime engine is already running. Returning to the dashboard will resume the live system view.'
                    : 'Your system is configured and ready. Once activated, it will begin monitoring and guiding your behavior.';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
              boxShadow: [
                BoxShadow(
                    color: AppColors.success.withOpacity(0.3), blurRadius: 40),
              ],
            ),
            child: isActivating
                ? const Padding(
                    padding: EdgeInsets.all(28),
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 3),
                  )
                : const Icon(Icons.rocket_launch,
                    color: Colors.white, size: 48),
          ).animate().scale(duration: 800.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 32),
          Text(title, style: AppTextStyles.h2, textAlign: TextAlign.center)
              .animate()
              .fadeIn(delay: 300.ms),
          const SizedBox(height: 16),
          Text(
            description,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 500.ms),
          if (!accessibilityGranted) ...[
            const SizedBox(height: 20),
            GlowCard(
              glowColor: AppColors.primaryCyan,
              glowOpacity: 0.1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.flash_on,
                          color: AppColors.primaryCyan, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppStrings.liveDetectionRecommended,
                          style: AppTextStyles.label
                              .copyWith(color: AppColors.primaryCyan),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.accessibilityPermissionReason,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: onRequestAccessibility,
                      icon: const Icon(Icons.settings_accessibility,
                          color: AppColors.primaryCyan, size: 18),
                      label: Text(
                        AppStrings.enableLiveDetection,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.primaryCyan),
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 620.ms),
          ],
          const SizedBox(height: 32),
          GlowCard(
            glowColor: AppColors.success,
            glowOpacity: 0.1,
            child: Column(children: [
              _ActivateRow(Icons.bar_chart, 'Usage monitoring'),
              const SizedBox(height: 10),
              _ActivateRow(Icons.flash_on, 'Live app detection'),
              const SizedBox(height: 10),
              _ActivateRow(Icons.shield, 'Escalation engine'),
              const SizedBox(height: 10),
              _ActivateRow(Icons.notifications_active, 'Warning notifications'),
              const SizedBox(height: 10),
              _ActivateRow(Icons.trending_up, 'XP & leveling system'),
              const SizedBox(height: 10),
              _ActivateRow(Icons.auto_awesome, 'Behavior analysis'),
            ]),
          ).animate().fadeIn(delay: 700.ms),
          const SizedBox(height: 48),
          if (!isActivating)
            SizedBox(
              width: double.infinity,
              child: GlowButton(
                text: engineRunning
                    ? 'Return to Dashboard'
                    : isDegraded
                        ? 'Repair Activation'
                        : 'Activate System',
                icon: engineRunning ? Icons.home : Icons.power_settings_new,
                onPressed: isActivatable || isDegraded || engineRunning
                    ? onActivate
                    : null,
                glowOpacity: 0.8,
              ),
            ).animate().fadeIn(delay: 900.ms).slideY(begin: 0.3),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _ActivateRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ActivateRow(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: AppColors.success, size: 18),
      const SizedBox(width: 12),
      Expanded(
          child: Text(label,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary))),
      Icon(Icons.check, color: AppColors.success.withOpacity(0.6), size: 16),
    ]);
  }
}

// ═══════════════════════════════════════════
// Shared Reusable Permission Step Widget
// ═══════════════════════════════════════════

class _PermissionStep extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final bool isGranted;
  final String reason;
  final Color reasonColor;
  final VoidCallback onRequest;
  final VoidCallback onRefresh;
  final VoidCallback onNext;
  final String nextLabel;
  final String requestLabel;
  final IconData requestIcon;

  const _PermissionStep({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.isGranted,
    required this.reason,
    required this.reasonColor,
    required this.onRequest,
    required this.onRefresh,
    required this.onNext,
    required this.nextLabel,
    this.requestLabel = 'Open Settings',
    this.requestIcon = Icons.settings,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isGranted
                  ? AppColors.success.withOpacity(0.15)
                  : iconColor.withOpacity(0.15),
              border: Border.all(
                color: (isGranted ? AppColors.success : iconColor)
                    .withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Icon(icon,
                color: isGranted ? AppColors.success : iconColor, size: 40),
          ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 24),
          Text(title, style: AppTextStyles.h3, textAlign: TextAlign.center)
              .animate()
              .fadeIn(delay: 200.ms),
          const SizedBox(height: 8),
          Text(
            description,
            style: AppTextStyles.bodySmall.copyWith(
              color: isGranted ? AppColors.success : AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 400.ms),
          const SizedBox(height: 24),
          if (!isGranted) ...[
            GlowCard(
              glowColor: reasonColor,
              glowOpacity: 0.1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.info_outline, color: reasonColor, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppStrings.whyIsThisNeeded,
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.primaryCyan,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text(reason,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ).animate().fadeIn(delay: 500.ms),
            const SizedBox(height: 16),
            GlowButton(
              text: requestLabel,
              icon: requestIcon,
              onPressed: onRequest,
              glowOpacity: 0.5,
            ).animate().fadeIn(delay: 600.ms),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh,
                  color: AppColors.primaryBlue, size: 18),
              label: Text(AppStrings.iveGrantedPermission,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.primaryBlue)),
            ).animate().fadeIn(delay: 700.ms),
          ],
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: GlowButton(
              text: nextLabel,
              icon: Icons.arrow_forward,
              onPressed: onNext,
              glowOpacity: isGranted ? 0.6 : 0.2,
            ),
          ).animate().fadeIn(delay: 800.ms),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Shared Widgets
// ═══════════════════════════════════════════

class _StepProgress extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  const _StepProgress({required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (i) {
        final isActive = i <= currentStep;
        final isCurrent = i == currentStep;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            height: isCurrent ? 4 : 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: isActive
                  ? AppColors.primaryBlue
                  : AppColors.primaryBlue.withOpacity(0.15),
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                          color: AppColors.primaryBlue.withOpacity(0.5),
                          blurRadius: 8)
                    ]
                  : null,
            ),
          ),
        );
      }),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: AppColors.primaryBlue, size: 18),
      const SizedBox(width: 12),
      Expanded(child: Text(text, style: AppTextStyles.bodySmall)),
    ]);
  }
}
