import '../data/repositories/app_policy_repository.dart';
import '../domain/entities/app_policy.dart';
import '../platform/platform_channel.dart';

/// Service for App Blacklist/Whitelist + Usage Limits with SQLite.
///
/// Every mutation (add, toggle, update, delete) signals the native
/// TrackingService to re-evaluate limits immediately.
class AppListService {
  final AppPolicyRepository _policyRepository = AppPolicyRepository();

  /// Get all entries by type ('blacklist' or 'whitelist').
  Future<List<Map<String, dynamic>>> getByType(String listType) async {
    final policies = await _policyRepository.getByType(listType);
    return policies.map((policy) => policy.toLegacyMap()).toList();
  }

  /// Add an app to the list.
  Future<void> addApp({
    required String name,
    required String listType,
    String packageName = '',
    String tag = '',
    int dailyLimitMinutes = 0,
  }) async {
    final now = DateTime.now();
    await _policyRepository.savePolicy(
      AppPolicy(
        name: name,
        packageName: packageName,
        listType: listType,
        tag: tag,
        dailyLimitMinutes: dailyLimitMinutes,
        createdAt: now,
        updatedAt: now,
      ),
    );
    _notifyNative();
  }

  /// Toggle app enabled/disabled.
  Future<void> toggleApp(int id, bool enabled) async {
    await _policyRepository.togglePolicy(id, enabled);
    _notifyNative();
  }

  /// Update daily limit for an app.
  Future<void> updateLimit(int id, int minutes) async {
    await _policyRepository.updateLimit(id, minutes);
    _notifyNative();
  }

  /// Delete an app from the list.
  Future<void> deleteApp(int id) async {
    await _policyRepository.deletePolicy(id);
    _notifyNative();
  }

  /// Get all apps with limits > 0.
  Future<List<Map<String, dynamic>>> getAppsWithLimits() async {
    final policies = await _policyRepository.getEffectivePoliciesWithLimits();
    return policies.map((policy) => policy.toLegacyMap()).toList();
  }

  /// Signal the native TrackingService that limits have changed.
  void _notifyNative() {
    PlatformChannel.instance.refreshPolicies();
  }
}
