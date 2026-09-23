import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/system/screens/welcome_screen.dart';
import '../features/system/screens/login_screen.dart';
import '../features/system/screens/signup_screen.dart';
import '../features/system/screens/onboarding_screen.dart';
import '../features/system/screens/system_loading_screen.dart';
import '../features/system/screens/overlay_lock_screen.dart';
import '../features/system/screens/hard_lock_screen.dart';
import '../features/system/screens/limited_access_screen.dart';
import '../features/system/screens/empty_state_screen.dart';
import '../features/system/screens/permission_required_screen.dart';
import '../features/system/screens/feedback_demo_screen.dart';
import '../features/system/screens/setup_screen.dart';
import '../features/system/screens/boot_screen.dart';
import '../features/system/screens/profile_review_screen.dart';
import '../features/system/screens/ai_debug_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/habits/screens/habits_screen.dart';
import '../features/habits/screens/add_habit_screen.dart';
import '../features/habits/screens/habit_details_screen.dart';
import '../features/ai/screens/ai_chat_screen.dart';
import '../features/stats/screens/stats_screen.dart';
import '../features/stats/screens/level_rewards_screen.dart';
import '../features/stats/screens/weekly_review_screen.dart';
import '../features/focus/screens/focus_mode_screen.dart';
import '../features/focus/screens/session_complete_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/settings/screens/escalation_settings_screen.dart';
import '../features/settings/screens/habit_priority_screen.dart';
import '../features/settings/screens/help_support_screen.dart';
import '../features/settings/screens/app_blacklist_screen.dart';
import '../features/settings/screens/usage_limits_screen.dart';
import '../features/settings/screens/language_settings_screen.dart';
import '../features/profile/screens/profile_settings_screen.dart';
import '../features/stats/screens/usage_dashboard_screen.dart';
import '../features/identity/screens/identity_builder_screen.dart';
import '../features/identity/screens/skill_trees_screen.dart';
import '../features/dungeons/screens/dungeon_screen.dart';
import 'main_shell.dart';
import '../providers/app_init_provider.dart';

/// Route path constants.
class RoutePaths {
  RoutePaths._();
  static const welcome = '/';
  static const boot = '/boot';
  static const setup = '/setup';
  static const login = '/login';
  static const signup = '/signup';
  static const onboarding = '/onboarding';
  static const profileReview = '/profile_review';
  static const loading = '/loading';
  static const permission = '/permission';

  // Main tabs
  static const dashboard = '/dashboard';
  
  static const habits = '/habits';
  static const ai = '/ai';
  static const stats = '/stats';
  static const settings = '/settings';

  // Sub-screens
  static const addHabit = '/habits/add';
  static const habitDetails = '/habits/details';
  static const level = '/level';
  static const escalation = '/settings/escalation';
  static const profile = '/settings/profile';
  static const habitPriority = '/settings/habit-priority';
  static const helpSupport = '/settings/help-support';
  static const appBlacklist = '/settings/app-blacklist';
  static const usageLimits = '/settings/usage-limits';
  static const language = '/settings/language';
  static const usageDashboard = '/usage-dashboard';

  // Focus
  static const focusMode = '/focus-mode';
  static const sessionComplete = '/session-complete';

  // Identity & Growth
  static const identityBuilder = '/identity-builder';
  static const skillTrees = '/skill-trees';
  static const dungeons = '/dungeons';
  static const weeklyReview = '/weekly-review';

  // System overlays
  static const overlayLock = '/overlay-lock';
  static const hardLock = '/hard-lock';
  static const limitedAccess = '/limited-access';
  static const emptyState = '/empty-state';
  static const feedbackDemo = '/feedback-demo';
  static const aiDebug = '/ai-debug';
}

/// Tab index mapping.
int _tabIndex(String location) {
  if (location.startsWith(RoutePaths.habits)) return 1;
  if (location.startsWith(RoutePaths.ai)) return 2;
  if (location.startsWith(RoutePaths.stats)) return 3;
  if (location.startsWith(RoutePaths.settings)) return 4;
  return 0;
}

/// Custom fade transition page.
CustomTransitionPage<void> _fadePage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

/// Custom slide-up transition for modal-type screens.
CustomTransitionPage<void> _slideUpPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 400),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final tween = Tween(begin: const Offset(0, 0.3), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeOut));
      return SlideTransition(
        position: animation.drive(tween),
        child: FadeTransition(opacity: animation, child: child),
      );
    },
  );
}

/// Custom slide-right for push-type screens.
CustomTransitionPage<void> _slideRightPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final tween = Tween(begin: const Offset(1, 0), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeOut));
      return SlideTransition(
        position: animation.drive(tween),
        child: child,
      );
    },
  );
}

String? _guardRedirectPath(AppInitState initState) {
  if (initState.isLoading || initState.canEnterCoreSurfaces) return null;

  switch (initState.entryTarget) {
    case AppEntryTarget.welcome:
      return RoutePaths.welcome;
    case AppEntryTarget.onboarding:
      return RoutePaths.onboarding;
    case AppEntryTarget.setup:
      return RoutePaths.setup;
    case AppEntryTarget.dashboard:
      return RoutePaths.dashboard;
  }
}

class _CoreReleaseGate extends ConsumerStatefulWidget {
  final Widget child;

  const _CoreReleaseGate({required this.child});

  @override
  ConsumerState<_CoreReleaseGate> createState() => _CoreReleaseGateState();
}

class _CoreReleaseGateState extends ConsumerState<_CoreReleaseGate> {
  @override
  Widget build(BuildContext context) {
    final initState = ref.watch(appInitProvider);

    ref.listen<AppInitState>(appInitProvider, (_, next) {
      _redirectIfNeeded(next);
    });

    if (initState.isLoading) {
      return const SystemLoadingScreen();
    }

    final redirectPath = _guardRedirectPath(initState);
    if (redirectPath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _redirectIfNeeded(initState);
      });
      return const SystemLoadingScreen();
    }

    return widget.child;
  }

  void _redirectIfNeeded(AppInitState initState) {
    if (!mounted || initState.isLoading) return;

    final redirectPath = _guardRedirectPath(initState);
    if (redirectPath == null) return;

    final currentLocation = GoRouterState.of(context).uri.toString();
    if (currentLocation != redirectPath) {
      context.go(redirectPath);
    }
  }
}

final GoRouter appRouter = GoRouter(
  initialLocation: RoutePaths.boot,
  routes: [
    // ── Boot Screen (entry point — decides where to go) ──
    GoRoute(
      path: RoutePaths.boot,
      pageBuilder: (_, state) => _fadePage(
        key: state.pageKey,
        child: const BootScreen(),
      ),
    ),

    // ── Setup Flow (permissions + activation) ──
    GoRoute(
      path: RoutePaths.setup,
      pageBuilder: (_, state) => _fadePage(
        key: state.pageKey,
        child: const SetupScreen(),
      ),
    ),

    // ── Auth Flow (no bottom nav) ──
    GoRoute(
      path: RoutePaths.welcome,
      pageBuilder: (_, state) => _fadePage(
        key: state.pageKey,
        child: const WelcomeScreen(),
      ),
    ),
    GoRoute(
      path: RoutePaths.login,
      pageBuilder: (_, state) => _slideRightPage(
        key: state.pageKey,
        child: const LoginScreen(),
      ),
    ),
    GoRoute(
      path: RoutePaths.signup,
      pageBuilder: (_, state) => _slideRightPage(
        key: state.pageKey,
        child: const SignUpScreen(),
      ),
    ),
    GoRoute(
      path: RoutePaths.onboarding,
      pageBuilder: (_, state) => _slideRightPage(
        key: state.pageKey,
        child: const OnboardingScreen(),
      ),
    ),
    GoRoute(
      path: RoutePaths.loading,
      pageBuilder: (_, state) => _fadePage(
        key: state.pageKey,
        child: const SystemLoadingScreen(),
      ),
    ),
    GoRoute(
      path: RoutePaths.profileReview,
      pageBuilder: (_, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final answers = extra['answers'] as Map<String, dynamic>? ?? {};
        final otherTexts = extra['otherTexts'] as Map<String, String>? ?? {};
        final surveyLanguage = extra['surveyLanguage'] as String? ?? 'en';
        return _slideRightPage(
          key: state.pageKey,
          child: ProfileReviewScreen(
            answers: answers,
            otherTexts: otherTexts,
            surveyLanguage: surveyLanguage,
          ),
        );
      },
    ),
    GoRoute(
      path: RoutePaths.permission,
      pageBuilder: (_, state) => _fadePage(
        key: state.pageKey,
        child: const PermissionRequiredScreen(),
      ),
    ),

    if (kDebugMode)
      GoRoute(
        path: RoutePaths.aiDebug,
        pageBuilder: (_, state) => _slideRightPage(
          key: state.pageKey,
          child: const AIDebugScreen(),
        ),
      ),

    // ── Main Tabs (core release surfaces) ──
    ShellRoute(
      builder: (context, state, child) {
        final index = _tabIndex(state.uri.toString());
        return _CoreReleaseGate(
          child: MainShell(
            currentIndex: index,
            onTabChanged: (i) {
              switch (i) {
                case 0:
                  context.go(RoutePaths.dashboard);
                case 1:
                  context.go(RoutePaths.habits);
                case 2:
                  context.go(RoutePaths.ai);
                case 3:
                  context.go(RoutePaths.stats);
                case 4:
                  context.go(RoutePaths.settings);
              }
            },
            child: child,
          ),
        );
      },
      routes: [
        GoRoute(
          path: RoutePaths.dashboard,
          pageBuilder: (_, state) => _fadePage(
            key: state.pageKey,
            child: const DashboardScreen(),
          ),
        ),
        GoRoute(
          path: RoutePaths.habits,
          pageBuilder: (_, state) => _fadePage(
            key: state.pageKey,
            child: const HabitsScreen(),
          ),
          routes: [
            GoRoute(
              path: 'add',
              pageBuilder: (_, state) => _slideUpPage(
                key: state.pageKey,
                child: const AddHabitScreen(),
              ),
            ),
            GoRoute(
              path: 'details',
              pageBuilder: (_, state) {
                final habitId = state.uri.queryParameters['id'] ?? '';
                return _slideRightPage(
                  key: state.pageKey,
                  child: HabitDetailsScreen(habitId: habitId),
                );
              },
            ),
          ],
        ),
        GoRoute(
          path: RoutePaths.ai,
          pageBuilder: (_, state) => _fadePage(
            key: state.pageKey,
            child: const AIChatScreen(),
          ),
        ),
        GoRoute(
          path: RoutePaths.stats,
          pageBuilder: (_, state) => _fadePage(
            key: state.pageKey,
            child: const StatsScreen(),
          ),
        ),
        GoRoute(
          path: RoutePaths.settings,
          pageBuilder: (_, state) => _fadePage(
            key: state.pageKey,
            child: const SettingsScreen(),
          ),
          routes: [
            GoRoute(
              path: 'escalation',
              pageBuilder: (_, state) => _slideRightPage(
                key: state.pageKey,
                child: const EscalationSettingsScreen(),
              ),
            ),
            GoRoute(
              path: 'profile',
              pageBuilder: (_, state) => _slideRightPage(
                key: state.pageKey,
                child: const ProfileSettingsScreen(),
              ),
            ),
            GoRoute(
              path: 'habit-priority',
              pageBuilder: (_, state) => _slideRightPage(
                key: state.pageKey,
                child: const HabitPriorityScreen(),
              ),
            ),
            GoRoute(
              path: 'help-support',
              pageBuilder: (_, state) => _slideRightPage(
                key: state.pageKey,
                child: const HelpSupportScreen(),
              ),
            ),
            GoRoute(
              path: 'app-blacklist',
              pageBuilder: (_, state) => _slideRightPage(
                key: state.pageKey,
                child: const AppBlacklistScreen(),
              ),
            ),
            GoRoute(
              path: 'usage-limits',
              pageBuilder: (_, state) => _slideRightPage(
                key: state.pageKey,
                child: const UsageLimitsScreen(),
              ),
            ),
            GoRoute(
              path: 'language',
              pageBuilder: (_, state) => _slideRightPage(
                key: state.pageKey,
                child: const LanguageSettingsScreen(),
              ),
            ),
          ],
        ),
        GoRoute(
          path: RoutePaths.level,
          pageBuilder: (_, state) => _slideRightPage(
            key: state.pageKey,
            child: const LevelRewardsScreen(),
          ),
        ),
        GoRoute(
          path: RoutePaths.usageDashboard,
          pageBuilder: (_, state) => _slideRightPage(
            key: state.pageKey,
            child: const UsageDashboardScreen(),
          ),
        ),
      ],
    ),

    // ── Focus Mode (core release surface) ──
    GoRoute(
      path: RoutePaths.focusMode,
      pageBuilder: (_, state) => _fadePage(
        key: state.pageKey,
        child: const _CoreReleaseGate(child: FocusModeScreen()),
      ),
    ),
    // ── Identity & Growth (future-shell surfaces intentionally kept visible in
    // normal product navigation unless the product owner explicitly says
    // otherwise) ──
    GoRoute(
      path: RoutePaths.identityBuilder,
      pageBuilder: (_, state) => _slideUpPage(
        key: state.pageKey,
        child: const IdentityBuilderScreen(),
      ),
    ),
    GoRoute(
      path: RoutePaths.skillTrees,
      pageBuilder: (_, state) => _slideRightPage(
        key: state.pageKey,
        child: const SkillTreesScreen(),
      ),
    ),
    GoRoute(
      path: RoutePaths.dungeons,
      pageBuilder: (_, state) => _slideRightPage(
        key: state.pageKey,
        child: const DungeonScreen(),
      ),
    ),
    GoRoute(
      path: RoutePaths.weeklyReview,
      pageBuilder: (_, state) => _slideRightPage(
        key: state.pageKey,
        child: const WeeklyReviewScreen(),
      ),
    ),
    GoRoute(
      path: RoutePaths.sessionComplete,
      pageBuilder: (_, state) => _slideUpPage(
        key: state.pageKey,
        child: const _CoreReleaseGate(child: SessionCompleteScreen()),
      ),
    ),

    // ── System/Overlay Surfaces ────────────────────────────────────────────
    // These Flutter screens are preserved as future-shell or diagnostic
    // surfaces. The actual enforcement runtime remains native.
    GoRoute(
      path: RoutePaths.overlayLock,
      pageBuilder: (_, state) => _fadePage(
        key: state.pageKey,
        child: const OverlayLockScreen(),
      ),
    ),
    GoRoute(
      path: RoutePaths.hardLock,
      pageBuilder: (_, state) => _fadePage(
        key: state.pageKey,
        child: const HardLockScreen(),
      ),
    ),
    GoRoute(
      path: RoutePaths.limitedAccess,
      pageBuilder: (_, state) => _fadePage(
        key: state.pageKey,
        child: const LimitedAccessScreen(),
      ),
    ),
    GoRoute(
      path: RoutePaths.emptyState,
      pageBuilder: (_, state) => _fadePage(
        key: state.pageKey,
        child: const EmptyStateScreen(),
      ),
    ),
    if (kDebugMode)
      GoRoute(
        path: RoutePaths.feedbackDemo,
        pageBuilder: (_, state) => _fadePage(
          key: state.pageKey,
          child: const FeedbackDemoScreen(),
        ),
      ),
  ],
);
