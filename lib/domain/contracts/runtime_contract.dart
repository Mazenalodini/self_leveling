// Phase 1 runtime contract definitions shared conceptually with Android Native.
//
// These types freeze the semantics at the Flutter/Native boundary before
// broader data and repository unification work in later phases.

/// Contract version for runtime payloads emitted by Android Native.
const int kRuntimeContractVersion = 3;

int _asInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}

bool _asBool(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  return fallback;
}

/// Canonical platform channel names shared with Android Native.
abstract final class RuntimeChannelNames {
  static const method = 'com.selfleveling/system';
  static const stateStream = 'com.selfleveling/state_stream';

  const RuntimeChannelNames._();
}

/// Canonical method-channel command names shared with Android Native.
abstract final class RuntimeMethodNames {
  static const hasUsageStatsPermission = 'hasUsageStatsPermission';
  static const requestUsageStatsPermission = 'requestUsageStatsPermission';
  static const getUsageStats = 'getUsageStats';
  static const refreshUsageSnapshot = 'refreshUsageSnapshot';
  static const getCurrentApp = 'getCurrentApp';
  static const startEngine = 'startEngine';
  static const stopEngine = 'stopEngine';
  static const isEngineRunning = 'isEngineRunning';
  static const getRuntimeSnapshot = 'getRuntimeSnapshot';
  static const getRuntimeReadiness = 'getRuntimeReadiness';
  static const hasOverlayPermission = 'hasOverlayPermission';
  static const requestOverlayPermission = 'requestOverlayPermission';
  static const hasAccessibilityPermission = 'hasAccessibilityPermission';
  static const requestAccessibilityPermission =
      'requestAccessibilityPermission';
  static const showOverlay = 'showOverlay';
  static const hideOverlay = 'hideOverlay';
  static const hasNotificationPermission = 'hasNotificationPermission';
  static const requestNotificationPermission = 'requestNotificationPermission';
  static const refreshPolicies = 'refreshPolicies';
  static const classifyApp = 'classifyApp';
  static const setFocusMode = 'setFocusMode';
  static const generateIntervention = 'generateIntervention';

  const RuntimeMethodNames._();
}

/// Canonical app category contract shared with the native AppClassifier.
///
/// IMPORTANT:
///   0 = productive
///   1 = neutral
///   2 = distracting
///   3 = essential
///   4 = userDefined
enum AppCategory {
  productive(0, 'Productive'),
  neutral(1, 'Neutral'),
  distracting(2, 'Distracting'),
  essential(3, 'Essential'),
  userDefined(4, 'User Defined');

  final int nativeValue;
  final String label;

  const AppCategory(this.nativeValue, this.label);

  static AppCategory fromNativeValue(int nativeValue) {
    for (final value in AppCategory.values) {
      if (value.nativeValue == nativeValue) return value;
    }
    return AppCategory.neutral;
  }
}

/// Canonical intervention stage contract shared with the native state machine.
///
/// These are semantic stage meanings only. Runtime durations remain policy-owned
/// by Android Native and must not be duplicated as authoritative timing logic in
/// Flutter.
enum InterventionStage {
  s0(0, 'Monitoring'),
  s1(1, 'Warning'),
  s2(2, 'Reminder'),
  s3(3, 'Temporary Block'),
  s4(4, 'Limited Re-entry'),
  s5(5, 'Hard Lock');

  final int code;
  final String displayName;

  const InterventionStage(this.code, this.displayName);

  static InterventionStage fromCode(int code) {
    for (final value in InterventionStage.values) {
      if (value.code == code) return value;
    }
    return InterventionStage.s0;
  }

  bool get isBlockingStage =>
      this == InterventionStage.s3 || this == InterventionStage.s5;
  bool get isLimitedAccessStage => this == InterventionStage.s4;
  bool get isWarningStage =>
      this == InterventionStage.s1 || this == InterventionStage.s2;
}

/// Canonical focus mode semantics.
///
/// Focus mode is NOT a pause switch for the escalation engine. It activates a
/// stricter policy profile in Android Native.
enum FocusModeSemantics {
  stricterEscalation,
}

/// Canonical readiness contract used by startup/setup flows.
///
/// This is a derived local state. It is not a mutable runtime authority.
enum ReadinessState {
  unauthenticated,
  unonboarded,
  permissionsMissing,
  ready,
}

/// Runtime settings keys already used or required by runtime policy surfaces.
///
/// These are contract names only in Phase 1. Broader storage/data unification is
/// deferred to Phase 2.
abstract final class RuntimeSettingKeys {
  static const systemSensitivity = 'system_sensitivity';
  static const escalationStrength = 'escalation_strength';
  static const notificationsEnabled = 'notifications_enabled';

  const RuntimeSettingKeys._();
}

/// Local lifecycle flags used by setup/activation flows.
abstract final class LocalFlagKeys {
  static const onboarded = 'onboarded';
  static const trackingStarted = 'tracking_started';
  static const accessibilityGrantedRemembered =
      'accessibility_granted_remembered';

  const LocalFlagKeys._();
}

/// Canonical lock-state payload embedded in the runtime snapshot.
///
/// `reentryCount` is the number of repeated returns detected by the native
/// engine for the active intervention context. It is NOT "locks triggered
/// today".
class LockStatePayload {
  final String? blockedAppPackage;
  final int remainingLockSeconds;
  final int reentryCount;
  final bool isLimitedAccess;
  final int limitedAccessRemainingSeconds;
  final String? limitedAccessAppPackage;

  const LockStatePayload({
    this.blockedAppPackage,
    this.remainingLockSeconds = 0,
    this.reentryCount = 0,
    this.isLimitedAccess = false,
    this.limitedAccessRemainingSeconds = 0,
    this.limitedAccessAppPackage,
  });

  bool get isActive =>
      remainingLockSeconds > 0 ||
      isLimitedAccess ||
      limitedAccessRemainingSeconds > 0 ||
      blockedAppPackage != null ||
      limitedAccessAppPackage != null;
  bool get hasBlockingLock =>
      blockedAppPackage != null && remainingLockSeconds > 0;
  bool get hasLimitedAccessWindow =>
      isLimitedAccess &&
      limitedAccessAppPackage != null &&
      limitedAccessRemainingSeconds > 0;
  String? get targetAppPackage => blockedAppPackage ?? limitedAccessAppPackage;

  factory LockStatePayload.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const LockStatePayload();
    return LockStatePayload(
      blockedAppPackage: map['blockedAppPackage'] as String?,
      remainingLockSeconds: _asInt(map['remainingLockSeconds']),
      reentryCount: _asInt(map['reentryCount']),
      isLimitedAccess: _asBool(map['isLimitedAccess']),
      limitedAccessRemainingSeconds:
          _asInt(map['limitedAccessRemainingSeconds']),
      limitedAccessAppPackage: map['limitedAccessAppPackage'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'blockedAppPackage': blockedAppPackage,
        'remainingLockSeconds': remainingLockSeconds,
        'reentryCount': reentryCount,
        'isLimitedAccess': isLimitedAccess,
        'limitedAccessRemainingSeconds': limitedAccessRemainingSeconds,
        'limitedAccessAppPackage': limitedAccessAppPackage,
      };
}

/// Typed payload returned by the native readiness/read-model command.
class RuntimeReadinessSnapshot {
  final int contractVersion;
  final bool usageStatsGranted;
  final bool overlayGranted;
  final bool accessibilityGranted;
  final bool notificationGranted;
  final bool activationRequested;
  final bool engineRunning;

  const RuntimeReadinessSnapshot({
    this.contractVersion = kRuntimeContractVersion,
    this.usageStatsGranted = false,
    this.overlayGranted = false,
    this.accessibilityGranted = false,
    this.notificationGranted = false,
    this.activationRequested = false,
    this.engineRunning = false,
  });

  bool get allRequiredGranted =>
      usageStatsGranted && overlayGranted && notificationGranted;
  bool get liveDetectionAvailable => accessibilityGranted;
  bool get isSupportedVersion => contractVersion == kRuntimeContractVersion;

  factory RuntimeReadinessSnapshot.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const RuntimeReadinessSnapshot();
    return RuntimeReadinessSnapshot(
      contractVersion:
          _asInt(map['contractVersion'], fallback: kRuntimeContractVersion),
      usageStatsGranted: _asBool(map['usageStatsGranted']),
      overlayGranted: _asBool(map['overlayGranted']),
      accessibilityGranted: _asBool(map['accessibilityGranted']),
      notificationGranted: _asBool(map['notificationGranted']),
      activationRequested: _asBool(map['activationRequested']),
      engineRunning: _asBool(map['engineRunning']),
    );
  }

  Map<String, dynamic> toMap() => {
        'contractVersion': contractVersion,
        'usageStatsGranted': usageStatsGranted,
        'overlayGranted': overlayGranted,
        'accessibilityGranted': accessibilityGranted,
        'notificationGranted': notificationGranted,
        'activationRequested': activationRequested,
        'engineRunning': engineRunning,
      };
}

/// Authoritative runtime snapshot emitted by Android Native.
///
/// Flutter consumes this as a read-only view of the live enforcement system.
class RuntimeStateSnapshot {
  final int contractVersion;
  final bool trackingActive;
  final InterventionStage stage;
  final String? currentAppPackage;
  final bool overlayVisible;
  final double riskScore;
  final bool focusModeActive;
  final LockStatePayload lockState;
  final int lastUpdatedAt;

  const RuntimeStateSnapshot({
    this.contractVersion = kRuntimeContractVersion,
    this.trackingActive = false,
    this.stage = InterventionStage.s0,
    this.currentAppPackage,
    this.overlayVisible = false,
    this.riskScore = 0.0,
    this.focusModeActive = false,
    this.lockState = const LockStatePayload(),
    this.lastUpdatedAt = 0,
  });

  factory RuntimeStateSnapshot.fromMap(Map<dynamic, dynamic> map) {
    return RuntimeStateSnapshot(
      contractVersion:
          _asInt(map['contractVersion'], fallback: kRuntimeContractVersion),
      trackingActive: _asBool(map['trackingActive']),
      stage: InterventionStage.fromCode(_asInt(map['stage'])),
      currentAppPackage: map['currentAppPackage'] as String?,
      overlayVisible: _asBool(map['overlayVisible']),
      riskScore: (map['riskScore'] as num?)?.toDouble() ?? 0.0,
      focusModeActive: _asBool(map['focusModeActive']),
      lockState: LockStatePayload.fromMap(
        map['lockState'] as Map<dynamic, dynamic>?,
      ),
      lastUpdatedAt: _asInt(map['lastUpdatedAt']),
    );
  }

  factory RuntimeStateSnapshot.initial() => const RuntimeStateSnapshot();

  int get escalationStage => stage.code;
  String get stageName => stage.displayName;
  double get distractionScore => riskScore;

  String? get currentApp => currentAppPackage;
  String? get blockedApp => lockState.blockedAppPackage;
  int get lockRemainingSeconds => lockState.remainingLockSeconds;
  int get reentryCount => lockState.reentryCount;
  bool get isLimitedAccess => lockState.isLimitedAccess;
  int get limitedAccessRemainingSec => lockState.limitedAccessRemainingSeconds;
  String? get limitedAccessApp => lockState.limitedAccessAppPackage;

  bool get isLocked => stage.isBlockingStage && overlayVisible;
  bool get isSevere => escalationStage >= InterventionStage.s3.code;
  bool get isWarning => stage.isWarningStage;
  bool get isNormal => stage == InterventionStage.s0;
  bool get isInLimitedAccess => stage.isLimitedAccessStage && isLimitedAccess;
  bool get hasActiveLockState => lockState.isActive;
  bool get isSupportedVersion => contractVersion == kRuntimeContractVersion;

  RuntimeStateSnapshot copyWith({
    int? contractVersion,
    bool? trackingActive,
    InterventionStage? stage,
    String? currentAppPackage,
    bool? overlayVisible,
    double? riskScore,
    bool? focusModeActive,
    LockStatePayload? lockState,
    int? lastUpdatedAt,
  }) {
    return RuntimeStateSnapshot(
      contractVersion: contractVersion ?? this.contractVersion,
      trackingActive: trackingActive ?? this.trackingActive,
      stage: stage ?? this.stage,
      currentAppPackage: currentAppPackage ?? this.currentAppPackage,
      overlayVisible: overlayVisible ?? this.overlayVisible,
      riskScore: riskScore ?? this.riskScore,
      focusModeActive: focusModeActive ?? this.focusModeActive,
      lockState: lockState ?? this.lockState,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'contractVersion': contractVersion,
        'trackingActive': trackingActive,
        'stage': stage.code,
        'currentAppPackage': currentAppPackage,
        'overlayVisible': overlayVisible,
        'riskScore': riskScore,
        'focusModeActive': focusModeActive,
        'lockState': lockState.toMap(),
        'lastUpdatedAt': lastUpdatedAt,
      };
}

/// Append-only intervention event contract for later native event history work.
///
/// Phase 1 defines the shape only. Emission/storage wiring comes later.
class InterventionEvent {
  final int contractVersion;
  final InterventionStage stage;
  final String packageName;
  final String reason;
  final double riskScore;
  final int reentryCount;
  final int timestamp;

  const InterventionEvent({
    this.contractVersion = kRuntimeContractVersion,
    required this.stage,
    required this.packageName,
    required this.reason,
    required this.riskScore,
    this.reentryCount = 0,
    required this.timestamp,
  });

  factory InterventionEvent.fromMap(Map<dynamic, dynamic> map) {
    return InterventionEvent(
      contractVersion:
          _asInt(map['contractVersion'], fallback: kRuntimeContractVersion),
      stage: InterventionStage.fromCode(_asInt(map['stage'])),
      packageName: map['packageName'] as String? ?? '',
      reason: map['reason'] as String? ?? '',
      riskScore: (map['riskScore'] as num?)?.toDouble() ?? 0.0,
      reentryCount: _asInt(map['reentryCount']),
      timestamp: _asInt(map['timestamp']),
    );
  }

  Map<String, dynamic> toMap() => {
        'contractVersion': contractVersion,
        'stage': stage.code,
        'packageName': packageName,
        'reason': reason,
        'riskScore': riskScore,
        'reentryCount': reentryCount,
        'timestamp': timestamp,
      };
}
