import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/constants/app_strings.dart';
import '../domain/contracts/runtime_contract.dart';
import '../domain/enums/escalation_level.dart';
import '../providers/system_provider.dart';
import '../providers/app_init_provider.dart';
import '../widgets/bottom_nav_bar.dart';
import '../core/localization/app_localizations.dart';

/// Shell wrapper for main tab screens with persistent bottom nav.
/// Listens to escalation changes from native state and reacts with UI overlays.
class MainShell extends ConsumerStatefulWidget {
  final int currentIndex;
  final Widget child;
  final void Function(int) onTabChanged;

  const MainShell({
    super.key,
    required this.currentIndex,
    required this.child,
    required this.onTabChanged,
  });

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  bool _showWarningBanner = false;

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

  /// Re-check all permissions when user returns to the app.
  /// This handles the case where user grants notification permission
  /// from system settings and returns — the banner disappears immediately.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(appInitProvider.notifier).refreshState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final escalationLevel = ref.watch(escalationLevelProvider);
    final distractionScore = ref.watch(distractionScoreProvider);
    final nativeState = ref.watch(nativeStateProvider);
    final s = S.of(ref);

    // Listen for escalation changes — INFORMATIONAL reactions only.
    //
    // ARCHITECTURE NOTE: Kotlin native overlay handles blocking distracting
    // EXTERNAL apps (Instagram, TikTok, etc.). Flutter must NEVER block
    // the Self Leveling app itself with full-screen lock routes.
    // Flutter only shows escalation state as banners/cards/dialogs.
    ref.listen<EscalationLevel>(escalationLevelProvider, (prev, next) {
      if (prev == next) return;

      // S2 → Show warning dialog (non-blocking, dismissible)
      if (next == EscalationLevel.s2 && prev != EscalationLevel.s2) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showWarningDialog(s);
        });
      }

      // S1 → Show/hide warning banner
      if (next == EscalationLevel.s1) {
        setState(() => _showWarningBanner = true);
        Future.delayed(const Duration(seconds: 10), () {
          if (mounted) setState(() => _showWarningBanner = false);
        });
      } else if (next == EscalationLevel.s0) {
        setState(() => _showWarningBanner = false);
      }
    });

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          widget.child,

          // Bottom navbar — always visible
          BottomNavBar(
            currentIndex: widget.currentIndex,
            onTap: widget.onTabChanged,
            labels: [s.home, s.habits, s.ai, s.stats, s.settings],
          ),

          // S1: Soft warning banner at top
          if (_showWarningBanner || escalationLevel == EscalationLevel.s1)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _WarningBanner(
                score: distractionScore,
                label: s.distractionDetected,
                sublabel: s.refocusToAvoid,
                onDismiss: () => setState(() => _showWarningBanner = false),
              ),
            ),

          // S3+ (severe): Informational escalation status banner at top
          // Shows what app is blocked and time remaining — NOT a blocker
          if (escalationLevel.isSevere)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _EscalationInfoBanner(
                nativeState: nativeState,
                escalationLevel: escalationLevel,
              ),
            ),
        ],
      ),
    );
  }

  void _showWarningDialog(AppLocalizations s) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1225),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.warning.withOpacity(0.4), width: 2),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: AppColors.warning, size: 28),
            const SizedBox(width: 12),
            Text(s.strongWarning,
                style: AppTextStyles.h3.copyWith(color: AppColors.warning)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.sustainedDistraction,
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              s.continueWillEscalate,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Text(
              s.xpPenaltyLabel('-2'),
              style: AppTextStyles.caption.copyWith(
                  color: AppColors.danger, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.iUnderstand,
                style: AppTextStyles.button.copyWith(color: AppColors.warning)),
          ),
        ],
      ),
    );
  }
}

/// S1 warning banner — slides down from top.
class _WarningBanner extends StatelessWidget {
  final double score;
  final String label;
  final String sublabel;
  final VoidCallback onDismiss;

  const _WarningBanner({
    required this.score,
    required this.label,
    required this.sublabel,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.warning.withOpacity(0.15),
              AppColors.warning.withOpacity(0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.warning.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
                color: AppColors.warning.withOpacity(0.2), blurRadius: 20),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: AppColors.warning, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.warning, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '$sublabel — ${(score * 100).round()}%',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onDismiss,
              child:
                  Icon(Icons.close, color: AppColors.textSecondary, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

/// S3+ informational banner — shown inside the app during escalation.
/// Non-blocking: user can still access all app features.
class _EscalationInfoBanner extends StatelessWidget {
  final RuntimeStateSnapshot nativeState;
  final EscalationLevel escalationLevel;

  const _EscalationInfoBanner({
    required this.nativeState,
    required this.escalationLevel,
  });

  @override
  Widget build(BuildContext context) {
    final blockedApp = nativeState.blockedApp;
    final effectiveRemainingSeconds = nativeState.isInLimitedAccess
        ? nativeState.limitedAccessRemainingSec
        : nativeState.lockRemainingSeconds;
    final remainingMin = (effectiveRemainingSeconds / 60).ceil();
    final stageColor = escalationLevel == EscalationLevel.s5
        ? AppColors.danger
        : escalationLevel == EscalationLevel.s4
            ? AppColors.danger.withOpacity(0.85)
            : AppColors.warning;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              stageColor.withOpacity(0.18),
              stageColor.withOpacity(0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: stageColor.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(color: stageColor.withOpacity(0.15), blurRadius: 20),
          ],
        ),
        child: Row(
          children: [
            Icon(
              escalationLevel == EscalationLevel.s5
                  ? Icons.lock
                  : Icons.shield_outlined,
              color: stageColor,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    blockedApp != null
                        ? AppStrings.appRestricted(blockedApp)
                        : AppStrings.lockActiveLabel,
                    style: AppTextStyles.caption.copyWith(
                      color: stageColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    effectiveRemainingSeconds > 0
                        ? '${AppStrings.currentStageLabel(nativeState.stageName)} · ${AppStrings.minutesRemaining(remainingMin)}'
                        : AppStrings.systemHandlingLabel,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
