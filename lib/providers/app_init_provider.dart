import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/contracts/runtime_contract.dart';
import '../services/permission_manager.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/user_profile_repository.dart';

/// Riverpod provider for PermissionManager singleton.
final permissionManagerProvider = Provider<PermissionManager>((ref) {
  return PermissionManager();
});

/// Local activation state derived from readiness + runtime status.
///
/// This is Flutter's lifecycle interpretation layer. It does NOT make native
/// runtime decisions; it only describes whether the app is inactive, currently
/// activating, healthy/active, or degraded relative to the expected runtime
/// state.
enum ActivationState {
  inactive,
  activating,
  active,
  degraded,
}

/// Boot/setup routing target derived from the canonical app-init state.
enum AppEntryTarget {
  welcome,
  onboarding,
  setup,
  dashboard,
}

/// App initialization state — the single authoritative Flutter model for:
///   - auth presence
///   - canonical profile availability
///   - required permissions
///   - runtime activation intent
///   - native service running state
class AppInitState {
  final ReadinessState readiness;
  final bool usageStatsGranted;
  final bool overlayGranted;
  final bool accessibilityGranted;
  final bool notificationGranted;
  final bool hasCanonicalProfile;
  final bool wasActivated;
  final bool engineRunning;
  final ActivationState activationState;
  final bool isLoading;
  final bool isActivating;

  const AppInitState({
    this.readiness = ReadinessState.unauthenticated,
    this.usageStatsGranted = false,
    this.overlayGranted = false,
    this.accessibilityGranted = false,
    this.notificationGranted = false,
    this.hasCanonicalProfile = false,
    this.wasActivated = false,
    this.engineRunning = false,
    this.activationState = ActivationState.inactive,
    this.isLoading = true,
    this.isActivating = false,
  });

  bool get allPermissionsGranted =>
      usageStatsGranted && overlayGranted && notificationGranted;
  bool get liveDetectionEnabled => accessibilityGranted;
  bool get isReady => readiness == ReadinessState.ready;
  bool get isActive => activationState == ActivationState.active;
  bool get isDegraded => activationState == ActivationState.degraded;
  bool get isActivatable =>
      readiness == ReadinessState.ready &&
      activationState == ActivationState.inactive;
  bool get canActivateEngine =>
      readiness == ReadinessState.ready &&
      activationState != ActivationState.active &&
      activationState != ActivationState.activating;
  bool get canEnterCoreSurfaces => isReady && isActive;
  bool get requiresSetupFlow =>
      readiness == ReadinessState.permissionsMissing ||
      (readiness == ReadinessState.ready && !canEnterCoreSurfaces);
  AppEntryTarget get entryTarget {
    switch (readiness) {
      case ReadinessState.unauthenticated:
        return AppEntryTarget.welcome;
      case ReadinessState.unonboarded:
        return AppEntryTarget.onboarding;
      case ReadinessState.permissionsMissing:
        return AppEntryTarget.setup;
      case ReadinessState.ready:
        return canEnterCoreSurfaces
            ? AppEntryTarget.dashboard
            : AppEntryTarget.setup;
    }
  }

  AppInitState copyWith({
    ReadinessState? readiness,
    bool? usageStatsGranted,
    bool? overlayGranted,
    bool? accessibilityGranted,
    bool? notificationGranted,
    bool? hasCanonicalProfile,
    bool? wasActivated,
    bool? engineRunning,
    ActivationState? activationState,
    bool? isLoading,
    bool? isActivating,
  }) {
    return AppInitState(
      readiness: readiness ?? this.readiness,
      usageStatsGranted: usageStatsGranted ?? this.usageStatsGranted,
      overlayGranted: overlayGranted ?? this.overlayGranted,
      accessibilityGranted: accessibilityGranted ?? this.accessibilityGranted,
      notificationGranted: notificationGranted ?? this.notificationGranted,
      hasCanonicalProfile: hasCanonicalProfile ?? this.hasCanonicalProfile,
      wasActivated: wasActivated ?? this.wasActivated,
      engineRunning: engineRunning ?? this.engineRunning,
      activationState: activationState ?? this.activationState,
      isLoading: isLoading ?? this.isLoading,
      isActivating: isActivating ?? this.isActivating,
    );
  }
}

/// Controls the app initialization lifecycle.
class AppInitNotifier extends StateNotifier<AppInitState> {
  final PermissionManager _permManager;
  final AuthRepository _authRepo;
  final UserProfileRepository _profileRepo;
  StreamSubscription<User?>? _authStateSub;

  AppInitNotifier(this._permManager, this._authRepo, this._profileRepo)
      : super(const AppInitState()) {
    _checkInitialState();
  }

  /// Check the initial system state on app startup.
  Future<void> _checkInitialState() async {
    state = state.copyWith(isLoading: true);

    try {
      await _permManager.init();
      await _authRepo.init();
      _bindAuthStateListener();
      await refreshState();
    } catch (e, st) {
      print("Critical Init Error: $e\n$st");
      // Explicit safe fallback
      if (mounted) {
        state = state.copyWith(
          readiness: ReadinessState.unauthenticated,
          activationState: ActivationState.inactive,
        );
      }
    } finally {
      if (mounted) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  void _bindAuthStateListener() {
    _authStateSub ??= _authRepo.authStateChanges().listen((_) {
      if (!state.isLoading && mounted) {
        refreshState();
      }
    });
  }

  /// Re-check permissions and auth state.
  Future<void> refreshState() async {
    try {
      final uid = await _authRepo.getCurrentUserId();
      if (uid == null || uid.isEmpty) {
        if (!mounted) return;
        state = state.copyWith(
          readiness: ReadinessState.unauthenticated,
          hasCanonicalProfile: false,
          usageStatsGranted: false,
          overlayGranted: false,
          accessibilityGranted: false,
          notificationGranted: false,
          wasActivated: false,
          engineRunning: false,
          activationState: ActivationState.inactive,
          isActivating: false,
        );
        return;
      }

      final profile = await _profileRepo.getBootstrapProfile(uid);
      final hasCanonicalProfile = profile != null;
      if (!hasCanonicalProfile) {
        if (!mounted) return;
        state = state.copyWith(
          readiness: ReadinessState.unonboarded,
          hasCanonicalProfile: false,
          usageStatsGranted: false,
          overlayGranted: false,
          accessibilityGranted: false,
          notificationGranted: false,
          wasActivated: false,
          engineRunning: false,
          activationState: ActivationState.inactive,
          isActivating: false,
        );
        return;
      }

      final runtimeReadiness = await _permManager.getRuntimeReadiness().timeout(
            const Duration(seconds: 2),
            onTimeout: () => const RuntimeReadinessSnapshot(),
          );
      final hasUsage = runtimeReadiness.usageStatsGranted;
      final hasOverlay = runtimeReadiness.overlayGranted;
      // Always use the REAL native accessibility check — never trust cached value.
      // After app updates, Android often disables the Accessibility Service,
      // so cached SharedPreferences values would be stale and incorrect.
      final hasAccessibility = runtimeReadiness.accessibilityGranted;
      if (hasAccessibility) {
        await _permManager.rememberAccessibilityGranted();
      } else {
        // Clear stale cache so settings screen shows correct state
        await _permManager.clearAccessibilityGrantedMemory();
      }
      final hasNotification = runtimeReadiness.notificationGranted;
      final wasActivated = runtimeReadiness.activationRequested;
      final engineRunning = runtimeReadiness.engineRunning;

      final newReadiness = !hasUsage || !hasOverlay || !hasNotification
          ? ReadinessState.permissionsMissing
          : ReadinessState.ready;

      final activationState = _deriveActivationState(
        readiness: newReadiness,
        engineRunning: engineRunning,
        wasActivated: wasActivated,
        isActivating: false,
      );

      if (!mounted) return;
      state = state.copyWith(
        readiness: newReadiness,
        hasCanonicalProfile: hasCanonicalProfile,
        usageStatsGranted: hasUsage,
        overlayGranted: hasOverlay,
        accessibilityGranted: hasAccessibility,
        notificationGranted: hasNotification,
        wasActivated: wasActivated,
        engineRunning: engineRunning,
        activationState: activationState,
        isActivating: false,
      );
    } catch (e, st) {
      print("Refresh State Error: $e\n$st");
      // Safe fallback on exception
      if (mounted) {
        state = state.copyWith(
          readiness: ReadinessState.unauthenticated,
          activationState: ActivationState.inactive,
          isActivating: false,
        );
      }
    }
  }

  @override
  void dispose() {
    _authStateSub?.cancel();
    super.dispose();
  }

  /// Complete onboarding and transition to permission check.
  Future<void> completeOnboarding() async {
    await _permManager.setOnboarded();
    if (!mounted) return;
    await refreshState();
  }

  Future<void> completeLogin() async {
    await refreshState();
  }

  Future<void> requestUsageStats() async =>
      await _permManager.requestUsageStatsPermission();
  Future<void> requestOverlay() async =>
      await _permManager.requestOverlayPermission();
  Future<void> requestAccessibility() async =>
      await _permManager.requestAccessibilityPermission();

  Future<void> requestNotification() async {
    await _permManager.requestNotificationPermission();
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    await refreshState();
  }

  Future<bool> activateSystem() async {
    if (!mounted) return false;
    await refreshState();
    if (!mounted) return false;
    if (!state.canActivateEngine) {
      return false;
    }

    state = state.copyWith(
      isActivating: true,
      activationState: ActivationState.activating,
    );

    final success = await _permManager.activateSystem();
    if (success) {
      await Future.delayed(const Duration(milliseconds: 250));
    }
    await refreshState();

    return success;
  }

  ActivationState _deriveActivationState({
    required ReadinessState readiness,
    required bool engineRunning,
    required bool wasActivated,
    required bool isActivating,
  }) {
    if (isActivating) return ActivationState.activating;
    if (readiness == ReadinessState.ready) {
      if (engineRunning) return ActivationState.active;
      if (wasActivated) return ActivationState.degraded;
      return ActivationState.inactive;
    }

    if (wasActivated || engineRunning) {
      return ActivationState.degraded;
    }

    return ActivationState.inactive;
  }
}

final appInitProvider =
    StateNotifierProvider<AppInitNotifier, AppInitState>((ref) {
  final permManager = ref.read(permissionManagerProvider);
  final authRepo = ref.read(authRepositoryProvider);
  final profileRepo = ref.read(userProfileRepositoryProvider);
  return AppInitNotifier(permManager, authRepo, profileRepo);
});
