import '../../core/database/database_helper.dart';
import '../../domain/entities/app_policy.dart';
import '../../domain/entities/effective_app_policy.dart';

class AppPolicyRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<List<AppPolicy>> getByType(String listType) async {
    final rows = await _db.queryWhere(
      'app_list',
      where: 'list_type = ?',
      whereArgs: [listType],
      orderBy: 'updated_at DESC, created_at DESC',
    );
    return rows.map(AppPolicy.fromMap).toList();
  }

  Future<List<AppPolicy>> getAppsWithLimits() async {
    final rows = await _db.queryWhere(
      'app_list',
      where: 'daily_limit_minutes > 0',
      orderBy: 'daily_limit_minutes DESC, updated_at DESC',
    );
    return rows.map(AppPolicy.fromMap).toList();
  }

  Future<List<AppPolicy>> getAllPolicies() async {
    final rows = await _db.queryWhere(
      'app_list',
      orderBy: 'updated_at DESC, created_at DESC',
    );
    return rows.map(AppPolicy.fromMap).toList();
  }

  Future<List<EffectiveAppPolicy>> getEffectivePolicies() async {
    final policies = await getAllPolicies();
    final byPackage = <String, List<AppPolicy>>{};
    for (final policy in policies) {
      if (policy.packageName.isEmpty) continue;
      byPackage.putIfAbsent(policy.packageName, () => []).add(policy);
    }

    final effective = byPackage.values
        .map(EffectiveAppPolicy.fromPolicies)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return effective;
  }

  Future<List<EffectiveAppPolicy>> getEffectivePoliciesWithLimits() async {
    final policies = await getEffectivePolicies();
    return policies.where((policy) => policy.hasUsageLimit).toList();
  }

  Future<EffectiveAppPolicy?> getEffectivePolicy(String packageName) async {
    final policies = await getAllPolicies();
    final matching =
        policies.where((policy) => policy.packageName == packageName);
    if (matching.isEmpty) return null;
    return EffectiveAppPolicy.fromPolicies(matching.toList());
  }

  Future<void> savePolicy(AppPolicy policy) async {
    final existing = await _db.queryFirst(
      'app_list',
      where: 'package_name = ? AND list_type = ?',
      whereArgs: [policy.packageName, policy.listType],
    );

    final now = DateTime.now();
    final persisted = existing == null
        ? policy.copyWith(createdAt: now, updatedAt: now)
        : policy.copyWith(
            id: existing['id'] as int?,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              existing['created_at'] as int? ?? now.millisecondsSinceEpoch,
            ),
            updatedAt: now,
          );

    await _db.insert('app_list', persisted.toDbMap());
  }

  Future<void> togglePolicy(int id, bool enabled) async {
    await _db.update(
      'app_list',
      {
        'is_enabled': enabled ? 1 : 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateLimit(int id, int minutes) async {
    await _db.update(
      'app_list',
      {
        'daily_limit_minutes': minutes,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deletePolicy(int id) async {
    await _db.delete('app_list', where: 'id = ?', whereArgs: [id]);
  }
}
