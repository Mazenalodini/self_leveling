import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzData;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/habit.dart';
import '../domain/entities/user_profile.dart';
import '../domain/enums/habit_type.dart';
import '../domain/services/habit_reminder_policy.dart';
import '../data/repositories/settings_repository.dart';
import '../features/ai/providers/ai_provider.dart';
import '../features/ai/domain/entities/messaging_models.dart';
import '../providers/habit_provider.dart';
import '../providers/system_provider.dart';
import '../providers/locale_provider.dart';

import 'package:flutter_timezone/flutter_timezone.dart';

final habitReminderServiceProvider = Provider<HabitReminderService>((ref) {
  return HabitReminderService(ref);
});

/// Watches state changes across habits, profile, and locale and triggers resync.
final habitReminderOrchestratorProvider = Provider<void>((ref) {
  final service = ref.watch(habitReminderServiceProvider);
  final habitState = ref.watch(habitProvider);
  final profile = ref.watch(systemProvider).profile;
  final lang = ref.watch(localeProvider).languageCode;

  // This will automatically re-run whenever habits, profile, or lang changes.
  if (profile != null) {
    service.syncHabits(habitState.habits, profile, lang);
  }
});

class HabitReminderService {
  final Ref _ref;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final SettingsRepository _settingsRepository = SettingsRepository();
  bool _initialized = false;

  /// Track which notification IDs are currently scheduled.
  /// This lets us cancel only removed/changed habits instead of cancelAll().
  final Set<int> _activeNotificationIds = {};

  HabitReminderService(this._ref);

  /// Generate a stable notification ID from a habit's UUID.
  /// Offset 0 = primary reminder, offset 1 = missed habit nudge.
  static int _stableId(String habitId, int offset) {
    // Use hashCode and clamp to a safe positive range (avoid Android limits)
    return (habitId.hashCode.abs() % 50000) + offset;
  }

  Future<void> initialize() async {
    if (_initialized) return;

    tzData.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _notificationsPlugin.initialize(initSettings);

    _initialized = true;
  }

  /// Syncs notifications with current habit list.
  /// Only cancels removed/changed habits and schedules new/changed ones.
  Future<void> syncHabits(
      List<Habit> habits, UserProfile profile, String lang) async {
    if (!_initialized) await initialize();
    final settings = await _settingsRepository.getSettings();

    // Compute which IDs the current habit list should have
    final Set<int> desiredIds = {};
    for (final habit in habits) {
      final plan = HabitReminderPolicy.buildPlan(
        habit: habit,
        profile: profile,
        settings: settings,
      );
      if (!plan.shouldScheduleAnything) continue;
      if (habit.reminderTime == null) continue;

      if (plan.schedulePrimaryReminder) {
        desiredIds.add(_stableId(habit.id, 0));
      }
      if (plan.scheduleMissedHabitNudge) {
        desiredIds.add(_stableId(habit.id, 50000));
      }
    }

    if (!settings.notificationsEnabled) {
      // Cancel all active and clear tracking
      for (final id in _activeNotificationIds) {
        await _notificationsPlugin.cancel(id);
      }
      _activeNotificationIds.clear();
      return;
    }

    // Cancel IDs that are no longer needed (habit was deleted or reminder removed)
    final idsToCancel = _activeNotificationIds.difference(desiredIds);
    for (final id in idsToCancel) {
      await _notificationsPlugin.cancel(id);
    }

    // Schedule new/updated habits
    final messaging = _ref.read(localFirstMessagingServiceProvider);

    for (final habit in habits) {
      final plan = HabitReminderPolicy.buildPlan(
        habit: habit,
        profile: profile,
        settings: settings,
      );
      if (!plan.shouldScheduleAnything) continue;

      final parts = habit.reminderTime!.split(':');
      if (parts.length != 2) continue;

      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) continue;

      // Determine the next valid time
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate =
          tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      DateTimeComponents matchComp = habit.frequency == HabitFrequency.daily
          ? DateTimeComponents.time
          : DateTimeComponents.dayOfWeekAndTime;

      const androidDetails = AndroidNotificationDetails(
        'habit_reminders_channel_v3',
        'Habit Reminders',
        channelDescription: 'Scheduled habit reminders to maintain discipline',
        importance: Importance.high,
        priority: Priority.high,
      );
      const details = NotificationDetails(android: androidDetails);

      // Schedule primary reminder
      if (plan.schedulePrimaryReminder) {
        final primaryId = _stableId(habit.id, 0);

        final generatedResult = await messaging.composeHabitReminder(
          habit: habit,
          language: lang,
          requestKind: MessageRequestKind.habitReminder,
        );

        await _notificationsPlugin.zonedSchedule(
          primaryId,
          generatedResult.message.headline,
          generatedResult.message.body,
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: matchComp,
        );
        _activeNotificationIds.add(primaryId);
      }

      // Schedule missed habit follow-up at 23:00
      if (plan.scheduleMissedHabitNudge) {
        final missedId = _stableId(habit.id, 50000);
        final missedDate =
            tz.TZDateTime(tz.local, now.year, now.month, now.day, 23, 0);
        tz.TZDateTime validMissed = missedDate.isBefore(now)
            ? missedDate.add(const Duration(days: 1))
            : missedDate;

        final missedResult = await messaging.composeHabitReminder(
          habit: habit,
          language: lang,
          requestKind: MessageRequestKind.missedHabitNudge,
        );

        await _notificationsPlugin.zonedSchedule(
          missedId,
          missedResult.message.headline,
          missedResult.message.body,
          validMissed,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: matchComp,
        );
        _activeNotificationIds.add(missedId);
      }
    }

    // Update tracking to reflect current state
    _activeNotificationIds
      ..removeAll(idsToCancel)
      ..addAll(desiredIds);
  }
}
