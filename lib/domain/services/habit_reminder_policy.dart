import '../entities/app_settings.dart';
import '../entities/habit.dart';
import '../entities/user_profile.dart';

class HabitReminderPlan {
  final bool schedulePrimaryReminder;
  final bool scheduleMissedHabitNudge;

  const HabitReminderPlan({
    required this.schedulePrimaryReminder,
    required this.scheduleMissedHabitNudge,
  });

  bool get shouldScheduleAnything =>
      schedulePrimaryReminder || scheduleMissedHabitNudge;
}

abstract final class HabitReminderPolicy {
  const HabitReminderPolicy._();

  static HabitReminderPlan buildPlan({
    required Habit habit,
    required UserProfile profile,
    required AppSettings settings,
  }) {
    final hasReminderTime =
        habit.reminderTime != null && habit.reminderTime!.trim().isNotEmpty;
    if (!settings.notificationsEnabled || !hasReminderTime) {
      return const HabitReminderPlan(
        schedulePrimaryReminder: false,
        scheduleMissedHabitNudge: false,
      );
    }

    final suppressMissedNudge =
        profile.interventionPreference == 'block_after_repetition';
    return HabitReminderPlan(
      schedulePrimaryReminder: true,
      scheduleMissedHabitNudge: !suppressMissedNudge,
    );
  }
}
