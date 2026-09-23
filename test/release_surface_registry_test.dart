import 'package:flutter_test/flutter_test.dart';
import 'package:self_leveling/navigation/app_router.dart';
import 'package:self_leveling/navigation/release_surface_registry.dart';

void main() {
  test('visible future shell surfaces remain visible in product navigation',
      () {
    expect(
      ReleaseSurfaceRegistry.tierFor(RoutePaths.identityBuilder),
      SurfaceTier.futureShell,
    );
    expect(
      ReleaseSurfaceRegistry.tierFor(RoutePaths.skillTrees),
      SurfaceTier.futureShell,
    );
    expect(
      ReleaseSurfaceRegistry.tierFor(RoutePaths.dungeons),
      SurfaceTier.futureShell,
    );
    expect(
      ReleaseSurfaceRegistry.isVisibleInReleaseNavigation(
        RoutePaths.identityBuilder,
      ),
      isTrue,
    );
    expect(
      ReleaseSurfaceRegistry.isVisibleInReleaseNavigation(
        RoutePaths.skillTrees,
      ),
      isTrue,
    );
    expect(
      ReleaseSurfaceRegistry.isVisibleInReleaseNavigation(
        RoutePaths.dungeons,
      ),
      isTrue,
    );
  });

  test('dashboard quick actions preserve visible future product surfaces', () {
    final actions = ReleaseSurfaceRegistry.dashboardQuickActions();

    final quickActionPaths = actions.map((action) => action.routePath).toSet();

    expect(quickActionPaths.contains(RoutePaths.identityBuilder), isTrue);
    expect(quickActionPaths.contains(RoutePaths.skillTrees), isTrue);
    expect(quickActionPaths.contains(RoutePaths.dungeons), isTrue);
    expect(quickActionPaths.contains(RoutePaths.weeklyReview), isTrue);
  });
}
