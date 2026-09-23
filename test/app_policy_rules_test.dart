import 'package:flutter_test/flutter_test.dart';
import 'package:self_leveling/domain/entities/app_policy.dart';
import 'package:self_leveling/domain/entities/effective_app_policy.dart';

void main() {
  final now = DateTime(2026, 1, 1);

  AppPolicy buildPolicy({
    required String listType,
    int dailyLimitMinutes = 0,
    int? categoryOverride,
    DateTime? updatedAt,
  }) {
    return AppPolicy(
      name: 'Example',
      packageName: 'com.example.app',
      listType: listType,
      dailyLimitMinutes: dailyLimitMinutes,
      categoryOverride: categoryOverride,
      createdAt: now,
      updatedAt: updatedAt ?? now,
    );
  }

  test('limit-only policies do not imply blacklist semantics', () {
    final effective = EffectiveAppPolicy.fromPolicies([
      buildPolicy(
        listType: AppPolicy.limitType,
        dailyLimitMinutes: 30,
      ),
    ]);

    expect(effective.hasUsageLimit, isTrue);
    expect(effective.isBlocked, isFalse);
    expect(effective.isExplicitlyAllowed, isFalse);
    expect(effective.isLimitOnly, isTrue);
  });

  test('blacklist plus limit merges to blocked with a limit', () {
    final effective = EffectiveAppPolicy.fromPolicies([
      buildPolicy(listType: AppPolicy.blacklistType),
      buildPolicy(
        listType: AppPolicy.limitType,
        dailyLimitMinutes: 45,
        updatedAt: now.add(const Duration(minutes: 1)),
      ),
    ]);

    expect(effective.isBlocked, isTrue);
    expect(effective.hasUsageLimit, isTrue);
    expect(effective.dailyLimitMinutes, 45);
  });

  test('whitelist overrides blocking while preserving limits and overrides',
      () {
    final effective = EffectiveAppPolicy.fromPolicies([
      buildPolicy(listType: AppPolicy.blacklistType),
      buildPolicy(
        listType: AppPolicy.whitelistType,
        updatedAt: now.add(const Duration(minutes: 1)),
      ),
      buildPolicy(
        listType: AppPolicy.limitType,
        dailyLimitMinutes: 20,
        categoryOverride: 3,
        updatedAt: now.add(const Duration(minutes: 2)),
      ),
    ]);

    expect(effective.isBlocked, isFalse);
    expect(effective.isExplicitlyAllowed, isTrue);
    expect(effective.hasUsageLimit, isTrue);
    expect(effective.dailyLimitMinutes, 20);
    expect(effective.categoryOverride, 3);
  });
}
