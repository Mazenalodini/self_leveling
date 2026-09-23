import 'app_policy.dart';

class EffectiveAppPolicy {
  final int? policyId;
  final String packageName;
  final String name;
  final bool isEnabled;
  final bool isBlocked;
  final bool isExplicitlyAllowed;
  final bool hasUsageLimit;
  final int dailyLimitMinutes;
  final int? categoryOverride;
  final List<String> sourceTypes;
  final DateTime updatedAt;

  const EffectiveAppPolicy({
    this.policyId,
    required this.packageName,
    required this.name,
    required this.isEnabled,
    required this.isBlocked,
    required this.isExplicitlyAllowed,
    required this.hasUsageLimit,
    required this.dailyLimitMinutes,
    required this.categoryOverride,
    required this.sourceTypes,
    required this.updatedAt,
  });

  bool get isLimitOnly => hasUsageLimit && !isBlocked && !isExplicitlyAllowed;

  Map<String, dynamic> toLegacyMap() => {
        'package_name': packageName,
        'name': name,
        'id': policyId,
        'list_type': isExplicitlyAllowed
            ? AppPolicy.whitelistType
            : (isBlocked ? AppPolicy.blacklistType : AppPolicy.limitType),
        'daily_limit_minutes': dailyLimitMinutes,
        'category_override': categoryOverride,
        'is_enabled': isEnabled ? 1 : 0,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  static EffectiveAppPolicy fromPolicies(List<AppPolicy> policies) {
    assert(policies.isNotEmpty);
    final enabled = policies.where((policy) => policy.isEnabled).toList();
    final active = enabled.isNotEmpty ? enabled : policies;
    final newest = [...active]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final representative = newest.firstWhere(
      (policy) => policy.hasLimit,
      orElse: () => newest.first,
    );

    final name = newest.first.name;
    final packageName = newest.first.packageName;
    final isExplicitlyAllowed = active.any((policy) => policy.isWhitelist);
    final isExplicitlyBlocked = active.any(
      (policy) => policy.isBlockRule,
    );
    final hasUsageLimit = active.any((policy) => policy.hasLimit);
    final dailyLimitMinutes = active
        .map((policy) => policy.dailyLimitMinutes)
        .fold<int>(
            0,
            (maxMinutes, minutes) =>
                minutes > maxMinutes ? minutes : maxMinutes);
    final categoryOverride = newest
        .map((policy) => policy.categoryOverride)
        .firstWhere((override) => override != null, orElse: () => null);

    return EffectiveAppPolicy(
      packageName: packageName,
      name: name,
      policyId: representative.id,
      isEnabled: active.any((policy) => policy.isEnabled),
      isBlocked: isExplicitlyBlocked && !isExplicitlyAllowed,
      isExplicitlyAllowed: isExplicitlyAllowed,
      hasUsageLimit: hasUsageLimit,
      dailyLimitMinutes: dailyLimitMinutes,
      categoryOverride: categoryOverride,
      sourceTypes: active.map((policy) => policy.listType).toSet().toList()
        ..sort(),
      updatedAt: newest.first.updatedAt,
    );
  }
}
