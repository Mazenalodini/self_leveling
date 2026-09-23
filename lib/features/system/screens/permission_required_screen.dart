import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_init_provider.dart';
import '../../../widgets/system_background.dart';
import '../../../widgets/glow_button.dart';
import '../../../widgets/system_decorative_line.dart';
import '../../../core/constants/app_strings.dart';
import '../../../navigation/app_router.dart';

/// Permission Required screen for usage tracking and overlay permissions.
class PermissionRequiredScreen extends StatelessWidget {
  const PermissionRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SystemBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.primaryBlue.withOpacity(0.4),
                        blurRadius: 40)
                  ],
                ),
                child:
                    const Icon(Icons.security, color: Colors.white, size: 48),
              )
                  .animate()
                  .fadeIn(duration: 600.ms)
                  .scale(begin: const Offset(0, 0), curve: Curves.easeOut),
              const SizedBox(height: 32),
              Text(AppStrings.permissionRequired, style: AppTextStyles.h2)
                  .animate()
                  .fadeIn(delay: 300.ms),
              const SizedBox(height: 12),
              Text(AppStrings.systemNeedsAccess,
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary),
                      textAlign: TextAlign.center)
                  .animate()
                  .fadeIn(delay: 400.ms),
              const SizedBox(height: 40),
              ...[
                (
                  AppStrings.usageAccess,
                  AppStrings.monitorAppUsage,
                  Icons.phone_android,
                  500
                ),
                (
                  AppStrings.overlayPermission,
                  AppStrings.displaySystemInterventions,
                  Icons.layers,
                  650
                ),
                (
                  AppStrings.notificationAccess,
                  AppStrings.sendBehavioralAlerts,
                  Icons.notifications_active,
                  800
                ),
              ].map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppColors.primaryBlue.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primaryBlue.withOpacity(0.1)),
                            child: Icon(p.$3,
                                color: AppColors.primaryBlue, size: 24)),
                        const SizedBox(width: 16),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(p.$1,
                                  style: AppTextStyles.bodySmall
                                      .copyWith(fontWeight: FontWeight.w600)),
                              Text(p.$2,
                                  style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textSecondary)),
                            ])),
                      ]),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: Duration(milliseconds: p.$4))
                      .slideX(begin: -0.2)),
              const SizedBox(height: 32),
              Consumer(builder: (context, ref, child) {
                return GlowButton(
                    text: AppStrings.grantPermissions,
                    onPressed: () async {
                      final notifier = ref.read(appInitProvider.notifier);
                      await notifier.requestUsageStats();
                      await notifier.requestOverlay();
                      await notifier.requestNotification();
                      await notifier.refreshState();
                      final initState = ref.read(appInitProvider);
                      if (initState.canActivateEngine) {
                        await notifier.activateSystem();
                      }
                      if (context.mounted) {
                        context.go(RoutePaths.boot);
                      }
                    }).animate().fadeIn(delay: 900.ms);
              }),
              const SizedBox(height: 48),
              SystemDecorativeLine(label: AppStrings.systemAccess)
                  .animate()
                  .fadeIn(delay: 1100.ms),
            ]),
          ),
        ),
      ),
    );
  }
}
