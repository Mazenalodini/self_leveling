import 'package:flutter_test/flutter_test.dart';
import 'package:self_leveling/domain/entities/focus_session.dart';
import 'package:self_leveling/domain/entities/habit.dart';
import 'package:self_leveling/domain/entities/user_profile.dart';
import 'package:self_leveling/domain/enums/habit_type.dart';
import 'package:self_leveling/domain/services/progression_rules.dart';

void main() {
  test('legacy seed captures prior profile totals', () {
    final profile = UserProfile.create(displayName: 'User').copyWith(
      level: 3,
      currentXP: 25,
      totalXPEarned: 420,
      selfControlScore: 61,
    );

    final seed = ProgressionRules.buildLegacySeed(profile);

    expect(seed.eventKey, 'legacy_profile_seed_v1');
    expect(seed.effectiveXpDelta, 275);
    expect(seed.earnedXpDelta, 420);
    expect(seed.selfControlDelta, 11);
  });

  test('native intervention produces canonical penalties', () {
    final entry = ProgressionRules.buildNativeIntervention(
      runtimeEventId: 'evt-1',
      fromLevel: 2,
      toLevel: 3,
      packageName: 'com.example.app',
      xpPenalty: 10,
      riskScore: 0.9,
      reentryCount: 2,
      createdAt: DateTime(2026),
    );

    expect(entry, isNotNull);
    expect(entry!.effectiveXpDelta, -10);
    expect(entry.earnedXpDelta, 0);
    expect(entry.selfControlDelta, -8);
  });

  test('ledger projection derives level xp and self-control consistently', () {
    final now = DateTime(2026, 1, 1);
    final habit = Habit(
      id: 'habit-1',
      name: 'Read',
      type: HabitType.build,
      currentStreak: 2,
      createdAt: now,
    );
    final habitEntry = ProgressionRules.buildHabitCompletion(
      habit: habit,
      dateKey: '2026-01-01',
      completed: true,
      streakAfterChange: 3,
    );
    final focusEntry = ProgressionRules.buildFocusCompletion(
      FocusSession(
        id: 'focus-1',
        durationMinutes: 20,
        startedAt: now,
        completedAt: now.add(const Duration(minutes: 20)),
        wasCompleted: true,
        xpEarned: 20,
      ),
    )!;
    final interventionEntry = ProgressionRules.buildNativeIntervention(
      runtimeEventId: 'evt-2',
      fromLevel: 4,
      toLevel: 5,
      packageName: 'com.example.app',
      xpPenalty: 10,
      riskScore: 0.95,
      reentryCount: 3,
      createdAt: now.add(const Duration(minutes: 30)),
    )!;

    final projection = ProgressionRules.projectLedger([
      habitEntry,
      focusEntry,
      interventionEntry,
    ]);

    expect(projection.level, 1);
    expect(projection.currentXP, 35);
    expect(projection.totalEarnedXP, 45);
    expect(projection.selfControlScore, 44);
    expect(projection.lastEventAt, habitEntry.createdAt);
  });
}
