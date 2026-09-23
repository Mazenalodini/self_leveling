import 'package:flutter/services.dart';
import '../domain/contracts/runtime_contract.dart';
import '../domain/entities/behavior_record.dart';
import '../domain/enums/behavior_category.dart';

/// Flutter-side platform channel for communicating with Android native layer.
///
/// Two channels:
///   - MethodChannel — request/response commands using RuntimeMethodNames
///   - EventChannel — RuntimeStateSnapshot stream only
///
/// Android Native is the authoritative runtime engine.
/// Flutter consumes runtime snapshots and issues user-driven commands.
class PlatformChannel {
  static const _methodChannel = MethodChannel(RuntimeChannelNames.method);
  static const _eventChannel = EventChannel(RuntimeChannelNames.stateStream);

  /// Expose method channel for AI Bridge handler
  static MethodChannel get methodChannel => _methodChannel;

  /// Singleton instance.
  static final PlatformChannel instance = PlatformChannel._();
  PlatformChannel._();

  // ═══════════════════════════════════════════
  // Native State Stream (EventChannel)
  // ═══════════════════════════════════════════

  /// Real-time stream of authoritative native runtime snapshots.
  Stream<RuntimeStateSnapshot> get nativeStateStream {
    return _eventChannel.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return RuntimeStateSnapshot.fromMap(event);
      }
      return RuntimeStateSnapshot.initial();
    });
  }

  /// One-shot read of the current native runtime snapshot.
  Future<RuntimeStateSnapshot> getRuntimeSnapshot() async {
    try {
      final result = await _methodChannel.invokeMethod<Map>(
        RuntimeMethodNames.getRuntimeSnapshot,
      );
      if (result == null) return RuntimeStateSnapshot.initial();
      return RuntimeStateSnapshot.fromMap(result);
    } on PlatformException {
      return RuntimeStateSnapshot.initial();
    }
  }

  // ═══════════════════════════════════════════
  // App Classification (delegates to Kotlin)
  // ═══════════════════════════════════════════

  /// Classify an app using Kotlin's canonical AppCategory contract.
  Future<AppCategory> classifyApp(String packageName) async {
    try {
      final categoryCode = await _methodChannel.invokeMethod<int>(
            RuntimeMethodNames.classifyApp,
            {
              'packageName': packageName,
            },
          ) ??
          AppCategory.neutral.nativeValue;
      return AppCategory.fromNativeValue(categoryCode);
    } on PlatformException {
      return AppCategory.neutral;
    }
  }

  /// Convert a native category int into the canonical AppCategory contract.
  static AppCategory categoryFromNative(int nativeCategory) {
    return AppCategory.fromNativeValue(nativeCategory);
  }

  // ═══════════════════════════════════════════
  // Runtime Readiness / Permissions
  // ═══════════════════════════════════════════

  Future<RuntimeReadinessSnapshot> getRuntimeReadiness() async {
    try {
      final result = await _methodChannel.invokeMethod<Map>(
        RuntimeMethodNames.getRuntimeReadiness,
      );
      return RuntimeReadinessSnapshot.fromMap(result);
    } on PlatformException {
      return const RuntimeReadinessSnapshot();
    }
  }

  Future<bool> hasUsageStatsPermission() async {
    try {
      return await _methodChannel.invokeMethod<bool>(
            RuntimeMethodNames.hasUsageStatsPermission,
          ) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> requestUsageStatsPermission() async {
    try {
      await _methodChannel.invokeMethod(
        RuntimeMethodNames.requestUsageStatsPermission,
      );
    } on PlatformException {/* user sees settings */}
  }

  Future<bool> hasOverlayPermission() async {
    try {
      return await _methodChannel.invokeMethod<bool>(
            RuntimeMethodNames.hasOverlayPermission,
          ) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> requestOverlayPermission() async {
    try {
      await _methodChannel
          .invokeMethod(RuntimeMethodNames.requestOverlayPermission);
    } on PlatformException {/* silently fail */}
  }

  Future<bool> hasNotificationPermission() async {
    try {
      return await _methodChannel.invokeMethod<bool>(
            RuntimeMethodNames.hasNotificationPermission,
          ) ??
          true;
    } on PlatformException {
      return true;
    }
  }

  Future<void> requestNotificationPermission() async {
    try {
      await _methodChannel.invokeMethod(
        RuntimeMethodNames.requestNotificationPermission,
      );
    } on PlatformException {/* silently fail */}
  }

  Future<bool> hasAccessibilityPermission() async {
    try {
      return await _methodChannel.invokeMethod<bool>(
            RuntimeMethodNames.hasAccessibilityPermission,
          ) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> requestAccessibilityPermission() async {
    try {
      await _methodChannel.invokeMethod(
        RuntimeMethodNames.requestAccessibilityPermission,
      );
    } on PlatformException {/* silently fail */}
  }

  // ═══════════════════════════════════════════
  // Usage Stats
  // ═══════════════════════════════════════════

  Future<List<AppUsageRecord>> getUsageStats({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>(
        RuntimeMethodNames.getUsageStats,
        {
          'startTime': start.millisecondsSinceEpoch,
          'endTime': end.millisecondsSinceEpoch,
        },
      );
      if (result == null) return [];

      final records = <AppUsageRecord>[];
      for (final item in result) {
        final map = Map<String, dynamic>.from(item as Map);
        final pkgName = map['packageName'] as String;
        final nativeCategory = map['category'];
        final boundedCategoryIndex = nativeCategory is int
            ? nativeCategory.clamp(0, BehaviorCategory.values.length - 1) as int
            : null;
        final resolvedCategory = nativeCategory is int
            ? BehaviorCategory.values[boundedCategoryIndex!]
            : _fastClassify(pkgName);
        // For bulk stats, use a lightweight local fallback to avoid N
        // method-channel calls when the native payload does not include a
        // category. Native classification remains authoritative.
        records.add(AppUsageRecord(
          packageName: pkgName,
          appName: map['appName'] as String? ?? pkgName,
          category: resolvedCategory,
          startTime:
              DateTime.fromMillisecondsSinceEpoch(map['startTime'] as int),
          durationSeconds: (map['durationMs'] as int) ~/ 1000,
        ));
      }
      return records.where((r) => r.durationSeconds > 0).toList();
    } on PlatformException {
      return [];
    }
  }

  Future<bool> refreshUsageSnapshot({int days = 1}) async {
    try {
      final result = await _methodChannel.invokeMethod<Map>(
        RuntimeMethodNames.refreshUsageSnapshot,
        {
          'days': days,
          'endTime': DateTime.now().millisecondsSinceEpoch,
        },
      );
      if (result == null) return false;
      final changed = result['changed'];
      return changed is bool ? changed : false;
    } on PlatformException {
      return false;
    }
  }

  Future<String?> getCurrentApp() async {
    try {
      return await _methodChannel.invokeMethod<String>(
        RuntimeMethodNames.getCurrentApp,
      );
    } on PlatformException {
      return null;
    }
  }

  // ═══════════════════════════════════════════
  // Foreground Service (Runtime Engine)
  // ═══════════════════════════════════════════

  Future<bool> startEngine() async {
    try {
      return await _methodChannel.invokeMethod<bool>(
            RuntimeMethodNames.startEngine,
          ) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> stopEngine() async {
    try {
      return await _methodChannel.invokeMethod<bool>(
            RuntimeMethodNames.stopEngine,
          ) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> isEngineRunning() async {
    try {
      return await _methodChannel.invokeMethod<bool>(
            RuntimeMethodNames.isEngineRunning,
          ) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  // ═══════════════════════════════════════════
  // Overlay Control
  // ═══════════════════════════════════════════

  Future<void> showOverlay({required String message}) async {
    try {
      await _methodChannel.invokeMethod(
        RuntimeMethodNames.showOverlay,
        {'message': message},
      );
    } on PlatformException {/* silently fail */}
  }

  Future<void> hideOverlay() async {
    try {
      await _methodChannel.invokeMethod(RuntimeMethodNames.hideOverlay);
    } on PlatformException {/* silently fail */}
  }

  // ═══════════════════════════════════════════
  // Policy / Focus Mode
  // ═══════════════════════════════════════════

  Future<void> refreshPolicies() async {
    try {
      await _methodChannel.invokeMethod(RuntimeMethodNames.refreshPolicies);
    } on PlatformException {/* silently fail */}
  }

  /// Notify the native TrackingService that focus mode has started or stopped.
  /// Focus mode activates a stricter native escalation policy; it does not
  /// pause the runtime engine.
  Future<void> setFocusMode({required bool active}) async {
    try {
      await _methodChannel.invokeMethod(
        RuntimeMethodNames.setFocusMode,
        {'active': active},
      );
    } on PlatformException {/* silently fail */}
  }

  /// Keep the screen on during focus sessions using native FLAG_KEEP_SCREEN_ON.
  Future<void> setKeepScreenOn({required bool enable}) async {
    try {
      await _methodChannel.invokeMethod(
        'setKeepScreenOn',
        {'enable': enable},
      );
    } on PlatformException {/* silently fail */}
  }

  // ═══════════════════════════════════════════
  // Lightweight Classification for Bulk Stats
  // ═══════════════════════════════════════════
  //
  // Used ONLY for coloring usage stats in the UI.
  // Enforcement decisions always use Kotlin's AppClassifier.
  // This is aligned with the Kotlin lists as closely as possible.

  static BehaviorCategory _fastClassify(String packageName) {
    final pkg = packageName.toLowerCase();

    // Games (almost always distracting)
    if (pkg.contains('.games.') || pkg.contains('.game.')) {
      return BehaviorCategory.distracting;
    }

    // Known distracting apps
    const distracting = [
      'tiktok',
      'instagram',
      'facebook.katana',
      'facebook.lite',
      'twitter',
      'snapchat',
      'reddit',
      'twitch',
      'netflix',
      'pinterest',
      'tumblr',
      'pubg',
      'fortnite',
      'roblox',
      'candycrush',
      'clashofclans',
      'brawlstars',
    ];
    for (final keyword in distracting) {
      if (pkg.contains(keyword)) return BehaviorCategory.distracting;
    }

    // Known productive
    const productive = [
      'calculator',
      'calendar',
      'clock',
      'notes',
      'docs',
      'sheets',
      'slides',
      'drive',
      'notion',
      'todoist',
      'trello',
      'slack',
      'teams',
      'zoom',
      'books',
      'kindle',
      'reader',
      'duolingo',
      'education',
      'school',
      'academy',
      'coursera',
      'udemy',
    ];
    for (final keyword in productive) {
      if (pkg.contains(keyword)) return BehaviorCategory.productive;
    }

    // Neutral by default (browsers, messaging, etc.)
    return BehaviorCategory.neutral;
  }
}
