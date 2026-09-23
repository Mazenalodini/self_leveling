import 'package:flutter_test/flutter_test.dart';
import 'package:self_leveling/domain/entities/app_settings.dart';
import 'package:self_leveling/domain/entities/habit.dart';
import 'package:self_leveling/domain/entities/user_profile.dart';
import 'package:self_leveling/domain/enums/habit_type.dart';
import 'package:self_leveling/domain/services/habit_reminder_policy.dart';

void main() {
  final habit = Habit(
    id: 'habit-1',
    name: 'Read',
    type: HabitType.build,
    reminderTime: '09:00',
    createdAt: DateTime(2026),
  );

  test('notifications disabled prevents all scheduling', () {
    final plan = HabitReminderPolicy.buildPlan(
      habit: habit,
      profile: UserProfile.create(displayName: 'User'),
      settings: const AppSettings(notificationsEnabled: false),
    );

    expect(plan.schedulePrimaryReminder, isFalse);
    expect(plan.scheduleMissedHabitNudge, isFalse);
  });

  test('block after repetition suppresses missed-habit nudge', () {
    final plan = HabitReminderPolicy.buildPlan(
      habit: habit,
      profile: UserProfile.create(displayName: 'User').copyWith(
        interventionPreference: 'block_after_repetition',
      ),
      settings: const AppSettings(),
    );

    expect(plan.schedulePrimaryReminder, isTrue);
    expect(plan.scheduleMissedHabitNudge, isFalse);
  });

  test('standard preferences schedule both reminder and nudge', () {
    final plan = HabitReminderPolicy.buildPlan(
      habit: habit,
      profile: UserProfile.create(displayName: 'User').copyWith(
        interventionPreference: 'remind_gently',
      ),
      settings: const AppSettings(),
    );

    expect(plan.schedulePrimaryReminder, isTrue);
    expect(plan.scheduleMissedHabitNudge, isTrue);
  });
}
