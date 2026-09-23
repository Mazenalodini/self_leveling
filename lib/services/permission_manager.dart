import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../domain/contracts/runtime_contract.dart';
import '../platform/platform_channel.dart';

/// Manages Android permissions and system initialization state.
///
/// Tracks three permission types:
///   - Usage Stats (required) — system settings, must be manually toggled
///   - Overlay (required) — system settings, must be manually toggled
///   - Notification (required) — runtime request on Android 13+
class PermissionManager {
  static const _keyOnboarded = LocalFlagKeys.onboarded;
  static const _keyAccessibilityGrantedRemembered =
      LocalFlagKeys.accessibilityGrantedRemembered;

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  bool get isOnboarded => _prefs?.getBool(_keyOnboarded) ?? false;

  Future<void> setOnboarded() async {
    await _prefs?.setBool(_keyOnboarded, true);
  }

  bool get rememberedAccessibilityGranted =>
      _prefs?.getBool(_keyAccessibilityGrantedRemembered) ?? false;

  Future<void> rememberAccessibilityGranted() async {
    await _prefs?.setBool(_keyAccessibilityGrantedRemembered, true);
  }

  Future<void> clearAccessibilityGrantedMemory() async {
    await _prefs?.remove(_keyAccessibilityGrantedRemembered);
  }

  // ═══════════════════════════════════════════
  // Individual Permission Checks
  // ═══════════════════════════════════════════

  Future<bool> hasUsageStatsPermission() =>
      PlatformChannel.instance.hasUsageStatsPermission();

  Future<bool> hasOverlayPermission() =>
      PlatformChannel.instance.hasOverlayPermission();

  Future<bool> hasAccessibilityPermission() =>
      PlatformChannel.instance.hasAccessibilityPermission();

  Future<bool> hasNotificationPermission() =>
      PlatformChannel.instance.hasNotificationPermission();

  // ═══════════════════════════════════════════
  // Individual Permission Requests
  // ═══════════════════════════════════════════

  Future<void> requestUsageStatsPermission() =>
      PlatformChannel.instance.requestUsageStatsPermission();

  Future<void> requestOverlayPermission() =>
      PlatformChannel.instance.requestOverlayPermission();

  Future<void> requestAccessibilityPermission() =>
      PlatformChannel.instance.requestAccessibilityPermission();

  /// Request notification permission. On Android 13+ this shows the system
  /// runtime permission dialog. On older versions it's a no-op (always granted).
  Future<void> requestNotificationPermission() =>
      PlatformChannel.instance.requestNotificationPermission();

  /// Request exact alarms permission strictly for scheduling custom habit reminders.
  /// This takes the user to settings on Android 14+ if not already granted.
  Future<void> requestExactAlarmsPermission() async {
    final notificationsPlugin = FlutterLocalNotificationsPlugin();
    final androidPlugin =
        notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestExactAlarmsPermission();
    }
  }

  // ═══════════════════════════════════════════
  // Permission / Activation Status
  // ═══════════════════════════════════════════
  //
  // Phase 3 note:
  // App readiness is derived centrally by AppInitNotifier. PermissionManager
  // exposes raw permission and activation-intent signals only; it is not a
  // competing readiness authority.

  /// Returns all permission states in a single check.
  Future<Map<String, bool>> getPermissionStatus() async {
    final readiness = await PlatformChannel.instance.getRuntimeReadiness();
    return {
      'usageStats': readiness.usageStatsGranted,
      'overlay': readiness.overlayGranted,
      'accessibility': readiness.accessibilityGranted,
      'notification': readiness.notificationGranted,
    };
  }

  Future<RuntimeReadinessSnapshot> getRuntimeReadiness() =>
      PlatformChannel.instance.getRuntimeReadiness();

  Future<bool> activateSystem() async {
    return PlatformChannel.instance.startEngine();
  }

  Future<void> deactivateSystem() async {
    await PlatformChannel.instance.stopEngine();
  }

  Future<bool> isTrackingActive() => PlatformChannel.instance.isEngineRunning();
}
