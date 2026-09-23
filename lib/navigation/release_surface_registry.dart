import 'package:flutter/material.dart';

import '../core/constants/app_strings.dart';
import 'app_router.dart';

enum SurfaceTier {
  releaseReady,
  futureShell,
  debugLegacy,
  internalOnly,
}

class SurfaceRegistryEntry {
  final String path;
  final SurfaceTier tier;
  final bool visibleInReleaseNavigation;

  const SurfaceRegistryEntry({
    required this.path,
    required this.tier,
    required this.visibleInReleaseNavigation,
  });
}

class ReleaseDashboardAction {
  final IconData icon;
  final String label;
  final Color color;
  final String routePath;

  const ReleaseDashboardAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.routePath,
  });
}

/// Canonical surface registry for the current product shell.
///
/// Product-intent rule:
///   - existing visible surfaces remain visible unless the product owner
///     explicitly instructs otherwise
///   - future-shell surfaces may stay visible as intentional shells
///   - debug/legacy surfaces are never shown in normal release navigation
class ReleaseSurfaceRegistry {
  ReleaseSurfaceRegistry._();

  static const entries = <SurfaceRegistryEntry>[
    SurfaceRegistryEntry(
      path: RoutePaths.boot,
      tier: SurfaceTier.internalOnly,
      visibleInReleaseNavigation: false,
    ),
    SurfaceRegistryEntry(
      path: RoutePaths.loading,
      tier: SurfaceTier.internalOnly,
      visibleInReleaseNavigation: false,
    ),
    SurfaceRegistryEntry(
      path: RoutePaths.permission,
      tier: SurfaceTier.internalOnly,
      visibleInReleaseNavigation: false,
    ),
    SurfaceRegistryEntry(
      path: RoutePaths.welcome,
      tier: SurfaceTier.releaseReady,
      visibleInReleaseNavigation: true,
    ),
    SurfaceRegistryEntry(
      path: RoutePaths.login,
      tier: SurfaceTier.releaseReady,
      visibleInReleaseNavigation: true,
    ),
    SurfaceRegistryEntry(
      path: RoutePaths.signup,
      tier: SurfaceTier.releaseReady,
      visibleInReleaseNavigation: true,
    ),
    SurfaceRegistryEntry(
      path: RoutePaths.onboarding,
      tier: SurfaceTier.releaseReady,
      visibleInReleaseNavigation: true,
    ),
    SurfaceRegistryEntry(
      path: RoutePaths.profileReview,
      tier: SurfaceTier.releaseReady,
      visibleInReleaseNavigation: true,
    ),
    SurfaceRegistryEntry(
      path: RoutePaths.setup,
      tier: SurfaceTier.releaseReady,
      visibleInReleaseNavigation: true,
    ),
    SurfaceRegistryEntry(
      path: RoutePaths.dashboard,
      tier: SurfaceTier.releaseReady,
      visibleInReleaseNavigation: true,
    ),
    SurfaceRegistryEntry(
      path: RoutePaths.habits,
      tier: SurfaceTier.releaseReady,
      visibleInReleaseNavigation: true,
    ),
    SurfaceRegistryEntry(
      path: RoutePaths.addHabit,
      tier: SurfaceTier.releaseReady,
      visibleInReleaseNavigation: true,
    ),
    SurfaceRegistryEntry(
      path: RoutePaths.habitDetails,
      tier: SurfaceTier.releaseReady,
      visibleInReleaseNavigation: true,
    ),
    SurfaceRegistryEntry(
      path: RoutePaths.ai,
      tier: SurfaceTier.releaseReady,
      visibleInReleaseNavigation: true,
    ),
    SurfaceRegistryEntry(
      path: RoutePaths.stats,
      tier: SurfaceTier.releaseReady,
      visibleInReleaseNavigation: true,
    ),
    SurfaceRegistryEntry(
      path: RoutePaths.weeklyReview,
      tier: SurfaceTier.releaseReady,
      visibleInReleaseNavigation: true,
    ),
    SurfaceRegistryEntry(
      path: RoutePaths.level,
      tier: SurfaceTier.releaseReady,
      visibleInReleaseNavigation: true,
    ),
    SurfaceRegistryEntry(
      path: RoutePaths.usageDashboard,
      tier: SurfaceTier.releaseReady,
      visibleInReleaseNavigation: true,
    ),
    SurfaceRegistryEntry(
      path: RoutePaths.focusMode,
      tier: SurfaceTier.releaseReady,
      visibleInReleaseNavigation: true,
    ),
    SurfaceRegistryEntry(
      path: RoutePaths.sessionComplete,
      tier: SurfaceTier.releaseReady,
      visibleInReleaseNavigation: false,
    ),
    SurfaceRegistryEntry(
      path: RoutePaths.settings,
      tier: SurfaceTier.releaseReady,
      visibleInReleaseNavigation: true,
    ),
    SurfaceRegistryEntry(
      path: RoutePaths.escalation,
      tier: SurfaceTier.releaseReady,
      visibleInReleaseNavigation: true,
    ),
    SurfaceRegistryEntry(
      path: RoutePaths.profile,
      tier: SurfaceTier.releaseReady,
      visibleInReleaseNavigation: true,
    ),
    SurfaceRegistryEntry(
      path: RoutePaths.habitPriority,
      tier: SurfaceTier.releaseReady,
      visibleInReleaseNavigation: true,
    ),
    SurfaceRegistryEntry(
      path: RoutePaths.helpSupport,
      tier: SurfaceTier.releaseReady,
      visibleInReleaseNavigation: true,
    ),
    SurfaceRegistryEntry(
      path: RoutePaths.appBlacklist,
      tier: SurfaceTier.releaseReady,
      visibleInReleaseNavigation: true,
    ),
    SurfaceRegistryEntry(
      path: RoutePaths.usageLimits,
      tier: SurfaceTier.releaseReady,
      visibleInReleaseNavigation: true,
    ),
    SurfaceRegistryEntry(
      path: RoutePaths.language,
      tier: SurfaceTier.releaseReady,
      visibleInReleaseNavigation: true,
    ),
    SurfaceRegistryEntry(
      path: RoutePaths.identityBuilder,
      tier: SurfaceTier.futureShell,
      visibleInReleaseNavigation: true,
    ),
    SurfaceRegistryEntry(
      path: RoutePaths.skillTrees,
      tier: SurfaceTier.futureShell,
      visibleInReleaseNavigation: true,
    ),
    SurfaceRegistryEntry(
      path: RoutePaths.dungeons,
      tier: SurfaceTier.futureShell,
      visibleInReleaseNavigation: true,
    ),
    SurfaceRegistryEntry(
      path: RoutePaths.overlayLock,
      tier: SurfaceTier.futureShell,
      visibleInReleaseNavigation: false,
    ),
    SurfaceRegistryEntry(
      path: RoutePaths.hardLock,
      tier: SurfaceTier.futureShell,
      visibleInReleaseNavigation: false,
    ),
    SurfaceRegistryEntry(
      path: RoutePaths.limitedAccess,
      tier: SurfaceTier.futureShell,
      visibleInReleaseNavigation: false,
    ),
    SurfaceRegistryEntry(
      path: RoutePaths.emptyState,
      tier: SurfaceTier.futureShell,
      visibleInReleaseNavigation: false,
    ),
    SurfaceRegistryEntry(
      path: RoutePaths.aiDebug,
      tier: SurfaceTier.debugLegacy,
      visibleInReleaseNavigation: false,
    ),
    SurfaceRegistryEntry(
      path: RoutePaths.feedbackDemo,
      tier: SurfaceTier.debugLegacy,
      visibleInReleaseNavigation: false,
    ),
  ];

  static final Map<String, SurfaceRegistryEntry> _byPath = {
    for (final entry in entries) entry.path: entry,
  };

  static SurfaceTier tierFor(String path) =>
      _byPath[path]?.tier ?? SurfaceTier.internalOnly;

  static bool isVisibleInReleaseNavigation(String path) =>
      _byPath[path]?.visibleInReleaseNavigation ?? false;

  static bool isFutureShell(String path) =>
      tierFor(path) == SurfaceTier.futureShell;

  static bool isReleaseReady(String path) =>
      tierFor(path) == SurfaceTier.releaseReady;

  static List<ReleaseDashboardAction> dashboardQuickActions() => [
        ReleaseDashboardAction(
          icon: Icons.person_outline,
          label: AppStrings.identityLabel,
          color: const Color(0xFF8B5CF6),
          routePath: RoutePaths.identityBuilder,
        ),
        ReleaseDashboardAction(
          icon: Icons.account_tree,
          label: AppStrings.skillsLabel,
          color: const Color(0xFF06B6D4),
          routePath: RoutePaths.skillTrees,
        ),
        ReleaseDashboardAction(
          icon: Icons.local_fire_department,
          label: AppStrings.dungeonsLabel,
          color: const Color(0xFFEF4444),
          routePath: RoutePaths.dungeons,
        ),
        ReleaseDashboardAction(
          icon: Icons.calendar_view_week,
          label: AppStrings.reviewLabel,
          color: const Color(0xFF22C55E),
          routePath: RoutePaths.weeklyReview,
        ),
      ];
}
