import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/formatters.dart';
import '../../../platform/platform_channel.dart';
import '../../../providers/focus_provider.dart';
import '../../../widgets/system_background.dart';

class FocusModeScreen extends ConsumerStatefulWidget {
  const FocusModeScreen({super.key});

  @override
  ConsumerState<FocusModeScreen> createState() => _FocusModeScreenState();
}

class _FocusModeScreenState extends ConsumerState<FocusModeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Keep screen on during focus session via native FLAG_KEEP_SCREEN_ON
    PlatformChannel.instance.setKeepScreenOn(enable: true);

    // Start a real focus session if not already active
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final focusState = ref.read(focusProvider);
      if (!focusState.isActive) {
        ref.read(focusProvider.notifier).startSession(durationMinutes: 25);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    // Release screen-on flag when leaving focus screen
    PlatformChannel.instance.setKeepScreenOn(enable: false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // DO NOT interrupt the session when the app goes to background.
    // The timer uses wall-clock time (_sessionEndsAt), so it will
    // automatically calculate the correct remaining time when resumed.
    // The native TrackingService already has focusMode active, which
    // applies stricter escalation if the user opens distracting apps.
    if (state == AppLifecycleState.resumed) {
      // Re-enable keep-screen-on when coming back
      final focusState = ref.read(focusProvider);
      if (focusState.isActive) {
        PlatformChannel.instance.setKeepScreenOn(enable: true);
      }
    }
  }

  void _confirmEndSession() {
    final isAr = AppStrings.isArabic;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1726),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.warning.withOpacity(0.3)),
        ),
        title: Row(children: [
          const Icon(Icons.warning_amber, color: AppColors.warning, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text(isAr ? 'إنهاء الجلسة؟' : 'End Session?',
            style: AppTextStyles.h3.copyWith(color: Colors.white))),
        ]),
        content: Text(
          isAr
            ? 'إذا أنهيت الجلسة الآن لن تحصل على أي نقاط أو مكافآت. الجلسة لن تُحتسب.'
            : 'If you end the session now, you won\'t earn any XP or rewards. The session won\'t count.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isAr ? 'متابعة التركيز' : 'Keep Focusing',
              style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(focusProvider.notifier).interruptSession();
              PlatformChannel.instance.setKeepScreenOn(enable: false);
              if (mounted) context.pop();
            },
            child: Text(isAr ? 'إنهاء' : 'End',
              style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final focusState = ref.watch(focusProvider);
    final timeRemaining = focusState.remainingSeconds;
    final phase = focusState.phase;
    final isActive = focusState.isActive;
    final completedSession =
        focusState.hasCompletedSession ? focusState.lastFinishedSession : null;
    final isAr = AppStrings.isArabic;

    final statusColor = switch (phase) {
      FocusSessionPhase.running => AppColors.primaryBlue,
      FocusSessionPhase.completed => AppColors.success,
      FocusSessionPhase.interrupted => AppColors.warning,
      FocusSessionPhase.idle => AppColors.primaryBlue,
    };
    final statusLabel = switch (phase) {
      FocusSessionPhase.running => AppStrings.focusModeActive.toUpperCase(),
      FocusSessionPhase.completed => AppStrings.sessionCompleteTitle,
      FocusSessionPhase.interrupted => AppStrings.sessionInterruptedTitle,
      FocusSessionPhase.idle => AppStrings.focusModeActive.toUpperCase(),
    };
    final messagePrefix = switch (phase) {
      FocusSessionPhase.running => AppStrings.stayFocusedSystem,
      FocusSessionPhase.completed => AppStrings.wellDoneEarned,
      FocusSessionPhase.interrupted => AppStrings.sessionInterruptedBody,
      FocusSessionPhase.idle => AppStrings.stayFocusedSystem,
    };
    final messageAccent = switch (phase) {
      FocusSessionPhase.running => AppStrings.withYou,
      FocusSessionPhase.completed =>
        '+${completedSession?.xpEarned ?? 0} ${AppStrings.xpLabel}',
      FocusSessionPhase.interrupted => AppStrings.noRewardGranted,
      FocusSessionPhase.idle => AppStrings.withYou,
    };

    // When session completes, release wakelock
    if (phase == FocusSessionPhase.completed || phase == FocusSessionPhase.interrupted) {
      PlatformChannel.instance.setKeepScreenOn(enable: false);
    }

    return PopScope(
      // Block back button during active session — user must use End Session button
      canPop: !isActive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isActive) {
          _confirmEndSession();
        }
      },
      child: Scaffold(
        body: SystemBackground(
          particleCount: 8,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Status badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (_, __) => Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: statusColor.withOpacity(0.8),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      statusLabel,
                      style: AppTextStyles.captionSmall.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(width: 12),
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (_, __) => Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: statusColor.withOpacity(0.8),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 600.ms),

                const SizedBox(height: 48),

                // Timer display
                Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (_, __) {
                        final opacity = 0.3 + _pulseController.value * 0.3;
                        return Container(
                          width: 300,
                          height: 120,
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: statusColor.withOpacity(opacity),
                                blurRadius: 80,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          AppColors.primaryGradient.createShader(bounds),
                      child: Text(
                        Formatters.formatMinSec(timeRemaining),
                        style: AppTextStyles.displayLarge
                            .copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(delay: 300.ms)
                    .scale(begin: const Offset(0.8, 0.8)),

                const SizedBox(height: 24),

                // Stricter policy warning — shown during active session
                if (isActive)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryCyan.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primaryCyan.withOpacity(0.2)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.shield, color: AppColors.primaryCyan, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        isAr
                          ? 'سياسة تصعيد أكثر صرامة مفعّلة (50% أسرع)'
                          : 'Stricter escalation policy active (50% faster)',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primaryCyan, fontSize: 10, fontWeight: FontWeight.w500),
                      )),
                    ]),
                  ).animate().fadeIn(delay: 500.ms),

                const SizedBox(height: 40),

                // Motivational message
                RichText(
                  text: TextSpan(
                    style: AppTextStyles.bodyLarge
                        .copyWith(color: AppColors.textSecondary),
                    children: [
                      TextSpan(text: messagePrefix),
                      TextSpan(
                        text: messageAccent,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(
                        text: phase == FocusSessionPhase.interrupted ? '' : '.',
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 600.ms),

                const SizedBox(height: 64),

                // End session / Back button
                GestureDetector(
                  onTap: () async {
                    if (isActive) {
                      _confirmEndSession();
                    } else if (phase == FocusSessionPhase.completed &&
                        completedSession != null) {
                      context.push(
                        '/session-complete',
                        extra: completedSession,
                      );
                    } else {
                      context.pop();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withOpacity(0.2),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: Text(
                      switch (phase) {
                        FocusSessionPhase.running => AppStrings.endSession,
                        FocusSessionPhase.completed =>
                          AppStrings.viewCompletionSummary,
                        FocusSessionPhase.interrupted =>
                          AppStrings.returnToDashboard,
                        FocusSessionPhase.idle => AppStrings.returnToDashboard,
                      },
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ).animate().fadeIn(delay: 900.ms),

                const SizedBox(height: 48),

                // Decorative line
                Opacity(
                  opacity: 0.1,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                          width: 64, height: 1, color: AppColors.primaryBlue),
                      const SizedBox(width: 8),
                      const Icon(Icons.shield,
                          color: AppColors.primaryBlue, size: 16),
                      const SizedBox(width: 8),
                      Container(
                          width: 64, height: 1, color: AppColors.primaryBlue),
                    ],
                  ),
                ).animate().fadeIn(delay: 1200.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
