import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/contracts/runtime_contract.dart';
import '../domain/entities/user_profile.dart';
import '../domain/enums/escalation_level.dart';
import '../services/behavior_service.dart';
import '../services/xp_service.dart';
import '../platform/platform_channel.dart';

// ═══════════════════════════════════════════════
// Service Providers (singletons — injected via main.dart overrides)
// ═══════════════════════════════════════════════

final behaviorServiceProvider = Provider<BehaviorService>((ref) {
  final service = BehaviorService();
  ref.onDispose(() => service.dispose());
  return service;
});

final xpServiceProvider = Provider<XPService>((ref) {
  return XPService();
});

// ═══════════════════════════════════════════════
// System State — Flutter read model
//
// Flutter assembles a UI-facing read model from:
//   - canonical local profile/progression data
//   - authoritative native runtime snapshots
//
// Flutter is NOT the runtime authority for escalation decisions.
// ═══════════════════════════════════════════════

class SystemState {
  final UserProfile profile;
  final RuntimeStateSnapshot nativeState;
  final bool hasUsagePermission;
  final bool hasOverlayPermission;
  final bool hasNotificationPermission;

  const SystemState({
    required this.profile,
    required this.nativeState,
    this.hasUsagePermission = false,
    this.hasOverlayPermission = false,
    this.hasNotificationPermission = false,
  });

  /// Convenience: tracking active from native source of truth.
  bool get isTrackingActive => nativeState.trackingActive;

  /// Convenience: escalation stage as EscalationLevel enum.
  EscalationLevel get escalationLevel {
    final stage = nativeState.escalationStage.clamp(0, 5);
    return EscalationLevel.values[stage];
  }

  /// Convenience: distraction score from native.
  double get distractionScore => nativeState.distractionScore;

  SystemState copyWith({
    UserProfile? profile,
    RuntimeStateSnapshot? nativeState,
    bool? hasUsagePermission,
    bool? hasOverlayPermission,
    bool? hasNotificationPermission,
  }) {
    return SystemState(
      profile: profile ?? this.profile,
      nativeState: nativeState ?? this.nativeState,
      hasUsagePermission: hasUsagePermission ?? this.hasUsagePermission,
      hasOverlayPermission: hasOverlayPermission ?? this.hasOverlayPermission,
      hasNotificationPermission:
          hasNotificationPermission ?? this.hasNotificationPermission,
    );
  }
}

/// Central system notifier for the Flutter read model.
///
/// Responsibilities:
///   - Mirror authoritative native runtime snapshots
///   - Manage local profile/progression display state
///   - Provide clean state to UI
class SystemNotifier extends StateNotifier<SystemState> {
  final XPService xpService;
  final BehaviorService behaviorService;
  StreamSubscription? _nativeStateSub;

  SystemNotifier({
    required this.xpService,
    required this.behaviorService,
    required UserProfile initialProfile,
    bool subscribeToNativeState = true,
  }) : super(SystemState(
          profile: initialProfile,
          nativeState: RuntimeStateSnapshot.initial(),
        )) {
    if (subscribeToNativeState) {
      _subscribeToNativeState();
    }
    // NOTE: No one-shot getRuntimeSnapshot() call here.
    // EventChannel's onListen already sends current state as its first event.
    // Flutter mirrors runtime state only; authoritative runtime facts are
    // persisted natively for later progression handling.
  }

  /// Subscribe to real-time native state stream via EventChannel.
  void _subscribeToNativeState() {
    _nativeStateSub = PlatformChannel.instance.nativeStateStream.listen(
      (nativeState) {
        _handleNativeStateUpdate(nativeState);
      },
      onError: (error) {
        // EventChannel errors are non-fatal — state stays as-is
      },
    );
  }

  /// Handle an incoming native state update.
  void _handleNativeStateUpdate(RuntimeStateSnapshot nativeState) {
    if (!mounted) return;
    state = state.copyWith(nativeState: nativeState);
  }

  // ═══════════════════════════════════════════
  // Profile / XP Management (UI-initiated only)
  // ═══════════════════════════════════════════

  Future<void> awardXP(int amount) async {
    final updated = await xpService.awardXP(amount);
    if (mounted) state = state.copyWith(profile: updated);
  }

  /// Update permissions state after checking native readiness.
  void updatePermissions({bool? usage, bool? overlay, bool? notification}) {
    state = state.copyWith(
      hasUsagePermission: usage,
      hasOverlayPermission: overlay,
      hasNotificationPermission: notification,
    );
  }

  Future<void> updateSensitivity(double value) async {
    final updated = await xpService.updateSensitivity(value);
    if (mounted) state = state.copyWith(profile: updated);
  }

  Future<void> updateEscalationStrength(double value) async {
    final updated = await xpService.updateEscalationStrength(value);
    if (mounted) state = state.copyWith(profile: updated);
  }

  Future<void> updateNotifications(bool enabled) async {
    final updated = await xpService.updateNotifications(enabled);
    if (mounted) state = state.copyWith(profile: updated);
  }

  Future<void> updateDisplayName(String name) async {
    final updated = await xpService.updateDisplayName(name);
    if (mounted) state = state.copyWith(profile: updated);
  }

  Future<void> updateIdentity(String identity) async {
    final updated = await xpService.updateIdentity(identity);
    if (mounted) state = state.copyWith(profile: updated);
  }

  Future<void> refreshProfile() async {
    final profile = await xpService.getProfile();
    if (mounted) state = state.copyWith(profile: profile);
  }

  @override
  void dispose() {
    _nativeStateSub?.cancel();
    super.dispose();
  }
}

final systemProvider =
    StateNotifierProvider<SystemNotifier, SystemState>((ref) {
  throw UnimplementedError('systemProvider must be overridden in main.dart');
});

// ═══════════════════════════════════════════════
// Computed Providers — derived from native state
// ═══════════════════════════════════════════════

final escalationLevelProvider = Provider<EscalationLevel>((ref) {
  return ref.watch(systemProvider).escalationLevel;
});

final distractionScoreProvider = Provider<double>((ref) {
  return ref.watch(systemProvider).distractionScore;
});

final userLevelProvider = Provider<int>((ref) {
  return ref.watch(systemProvider).profile.level;
});

final selfControlProvider = Provider<int>((ref) {
  return ref.watch(systemProvider).profile.selfControlScore;
});

final nativeStateProvider = Provider<RuntimeStateSnapshot>((ref) {
  return ref.watch(systemProvider).nativeState;
});

final trackingActiveProvider = Provider<bool>((ref) {
  return ref.watch(systemProvider).nativeState.trackingActive;
});
