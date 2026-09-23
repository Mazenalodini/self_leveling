import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../core/database/database_helper.dart';
import '../data/repositories/progression_repository.dart';
import '../domain/entities/habit.dart';
import '../domain/enums/habit_type.dart';
import '../domain/services/progression_rules.dart';

enum HabitCompletionStatus {
  completed,
  alreadyCompleted,
  unavailable,
}

class HabitCompletionResult {
  final HabitCompletionStatus status;
  final int xpEarned;
  final DateTime? completedAt;
  final DateTime? nextEligibleAt;

  const HabitCompletionResult({
    required this.status,
    this.xpEarned = 0,
    this.completedAt,
    this.nextEligibleAt,
  });

  bool get completedNow => status == HabitCompletionStatus.completed;
}

class _HabitCompletionState {
  final DateTime? lastCompletedAt;
  final bool completedToday;
  final DateTime? nextEligibleAt;

  const _HabitCompletionState({
    required this.lastCompletedAt,
    required this.completedToday,
    required this.nextEligibleAt,
  });
}

/// Service for habit CRUD operations with SQLite.
class HabitService {
  final _db = DatabaseHelper.instance;
  final _uuid = const Uuid();
  final ProgressionRepository _progressionRepository = ProgressionRepository();

  final _habitsController = StreamController<List<Habit>>.broadcast();
  Stream<List<Habit>> get onHabitsChanged => _habitsController.stream;

  Future<void> init() async {
    // DB is lazy-initialized, nothing special needed
  }

  /// Get all active habits.
  Future<List<Habit>> getAll() async {
    final rows = await _db.queryWhere('habits',
        where: 'is_active = ?',
        whereArgs: [1],
        orderBy: 'sort_order ASC, created_at DESC');

    return Future.wait(rows.map(_rowToHabit));
  }

  /// Add a new habit.
  Future<Habit> add({
    required String name,
    required HabitType type,
    HabitFrequency frequency = HabitFrequency.daily,
    String? reminderTime,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    await _db.insert('habits', {
      'id': id,
      'name': name,
      'type': type.index,
      'frequency': frequency.index,
      'current_streak': 0,
      'longest_streak': 0,
      'xp_reward': 10,
      'reminder_time': reminderTime,
      'sort_order': 0,
      'created_at': now.millisecondsSinceEpoch,
      'is_active': 1,
    });

    final habit = Habit(
      id: id,
      name: name,
      type: type,
      frequency: frequency,
      reminderTime: reminderTime,
      createdAt: now,
    );

    _notify();
    return habit;
  }

  /// Delete a habit (soft delete).
  Future<void> delete(String habitId) async {
    await _db.update('habits', {'is_active': 0},
        where: 'id = ?', whereArgs: [habitId]);
    _notify();
  }

  /// Update habit fields (name, frequency, reminderTime, sortOrder)
  Future<void> updateHabit(String habitId,
      {String? name,
      HabitFrequency? frequency,
      String? reminderTime,
      int? sortOrder}) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (frequency != null) updates['frequency'] = frequency.index;
    if (reminderTime != null) updates['reminder_time'] = reminderTime;
    if (sortOrder != null) updates['sort_order'] = sortOrder;
    if (updates.isNotEmpty) {
      await _db
          .update('habits', updates, where: 'id = ?', whereArgs: [habitId]);
      _notify();
    }
  }

  /// Bulk update habit orders
  Future<void> updateHabitsOrder(List<String> habitIds) async {
    for (int i = 0; i < habitIds.length; i++) {
      await _db.update('habits', {'sort_order': i},
          where: 'id = ?', whereArgs: [habitIds[i]]);
    }
    _notify();
  }

  /// Attempt a valid completion for the current scheduling window.
  /// Repeated completion inside the same valid window is ignored.
  Future<HabitCompletionResult> toggleCompletion(String habitId) async {
    final today = _todayKey();
    final db = await _db.database;
    final habitRow =
        await _db.queryFirst('habits', where: 'id = ?', whereArgs: [habitId]);
    if (habitRow == null) {
      return const HabitCompletionResult(
        status: HabitCompletionStatus.unavailable,
      );
    }

    final habit = await _rowToHabit(habitRow);
    if (!habit.canCompleteNow) {
      return HabitCompletionResult(
        status: HabitCompletionStatus.alreadyCompleted,
        nextEligibleAt: habit.nextEligibleAt,
      );
    }

    final completedAt = DateTime.now();
    final nextEligibleAt = _computeNextEligibleAt(
      completedAt: completedAt,
      frequency: habit.frequency,
      reminderTime: habit.reminderTime,
    );

    int currentStreak = habitRow['current_streak'] as int;
    int longestStreak = habitRow['longest_streak'] as int;
    currentStreak++;
    if (currentStreak > longestStreak) longestStreak = currentStreak;

    try {
      await db.insert(
        'habit_completions',
        {
          'habit_id': habitId,
          'completed_at': completedAt.millisecondsSinceEpoch,
          'date_key': today,
        },
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    } on DatabaseException {
      final lockedHabit = await _rowToHabit(habitRow);
      return HabitCompletionResult(
        status: HabitCompletionStatus.alreadyCompleted,
        nextEligibleAt: lockedHabit.nextEligibleAt,
      );
    }

    await _db.update(
      'habits',
      {
        'current_streak': currentStreak,
        'longest_streak': longestStreak,
      },
      where: 'id = ?',
      whereArgs: [habitId],
    );

    final progressionEvent = ProgressionRules.buildHabitCompletion(
      habit: habit,
      dateKey: today,
      completed: true,
      streakAfterChange: currentStreak,
    );

    await _progressionRepository.recordHabitCompletion(
      habit: habit,
      dateKey: today,
      completed: true,
      streakAfterChange: currentStreak,
    );

    _notify();
    return HabitCompletionResult(
      status: HabitCompletionStatus.completed,
      xpEarned: progressionEvent.effectiveXpDelta,
      completedAt: completedAt,
      nextEligibleAt: nextEligibleAt,
    );
  }

  /// Reset daily completions — check for broken streaks.
  Future<void> resetDailyCompletions() async {
    final yesterday =
        _dateKey(DateTime.now().subtract(const Duration(days: 1)));

    // Get all daily habits
    final habits = await _db.queryWhere('habits',
        where: 'is_active = ? AND frequency = ?', whereArgs: [1, 0]);

    for (final habit in habits) {
      final habitId = habit['id'] as String;
      final currentStreak = habit['current_streak'] as int;

      if (currentStreak > 0) {
        // Check if completed yesterday
        final yesterdayCompletion = await _db.queryWhere('habit_completions',
            where: 'habit_id = ? AND date_key = ?',
            whereArgs: [habitId, yesterday]);

        if (yesterdayCompletion.isEmpty) {
          // Streak broken!
          await _db.update('habits', {'current_streak': 0},
              where: 'id = ?', whereArgs: [habitId]);
        }
      }
    }
  }

  /// Get completion count today.
  Future<int> getCompletedCount() async {
    return await _db.count('habit_completions',
        where: 'date_key = ?', whereArgs: [_todayKey()]);
  }

  /// Get total active habits count.
  Future<int> getTotalCount() async {
    return await _db.count('habits', where: 'is_active = ?', whereArgs: [1]);
  }

  /// Get completion history for a specific habit (last N days).
  Future<List<DateTime>> getCompletionHistory(String habitId,
      {int days = 30}) async {
    final since = DateTime.now().subtract(Duration(days: days));
    final rows = await _db.queryWhere('habit_completions',
        where: 'habit_id = ? AND completed_at > ?',
        whereArgs: [habitId, since.millisecondsSinceEpoch],
        orderBy: 'completed_at DESC');

    return rows
        .map((r) =>
            DateTime.fromMillisecondsSinceEpoch(r['completed_at'] as int))
        .toList();
  }

  void _notify() async {
    final habits = await getAll();
    _habitsController.add(habits);
  }

  String _todayKey() => _dateKey(DateTime.now());

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<Habit> _rowToHabit(Map<dynamic, dynamic> row) async {
    final frequency = HabitFrequency.values[row['frequency'] as int? ?? 0];
    final reminderTime = row['reminder_time'] as String?;
    final completionState = await _loadCompletionState(
      habitId: row['id'] as String,
      frequency: frequency,
      reminderTime: reminderTime,
    );

    return Habit(
      id: row['id'] as String,
      name: row['name'] as String,
      type: HabitType.values[row['type'] as int],
      frequency: frequency,
      currentStreak: row['current_streak'] as int,
      longestStreak: row['longest_streak'] as int,
      completedToday: completionState.completedToday,
      xpReward: row['xp_reward'] as int,
      sortOrder: row['sort_order'] as int? ?? 0,
      reminderTime: reminderTime,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      lastCompletedAt: completionState.lastCompletedAt,
      nextEligibleAt: completionState.nextEligibleAt,
    );
  }

  Future<_HabitCompletionState> _loadCompletionState({
    required String habitId,
    required HabitFrequency frequency,
    required String? reminderTime,
  }) async {
    final rows = await _db.queryWhere(
      'habit_completions',
      where: 'habit_id = ?',
      whereArgs: [habitId],
      orderBy: 'completed_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return const _HabitCompletionState(
        lastCompletedAt: null,
        completedToday: false,
        nextEligibleAt: null,
      );
    }

    final lastCompletedAt = DateTime.fromMillisecondsSinceEpoch(
      rows.first['completed_at'] as int,
    );
    final nextEligibleAt = _computeNextEligibleAt(
      completedAt: lastCompletedAt,
      frequency: frequency,
      reminderTime: reminderTime,
    );
    return _HabitCompletionState(
      lastCompletedAt: lastCompletedAt,
      completedToday: _isSameDate(lastCompletedAt, DateTime.now()),
      nextEligibleAt:
          DateTime.now().isBefore(nextEligibleAt) ? nextEligibleAt : null,
    );
  }

  DateTime _computeNextEligibleAt({
    required DateTime completedAt,
    required HabitFrequency frequency,
    required String? reminderTime,
  }) {
    final nextDate = frequency == HabitFrequency.daily
        ? completedAt.add(const Duration(days: 1))
        : completedAt.add(const Duration(days: 7));
    final parsedTime = _parseReminderTime(reminderTime);
    if (parsedTime == null) {
      return DateTime(nextDate.year, nextDate.month, nextDate.day);
    }
    return DateTime(
      nextDate.year,
      nextDate.month,
      nextDate.day,
      parsedTime.$1,
      parsedTime.$2,
    );
  }

  (int, int)? _parseReminderTime(String? reminderTime) {
    if (reminderTime == null || reminderTime.trim().isEmpty) return null;
    final parts = reminderTime.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return (hour, minute);
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void dispose() {
    _habitsController.close();
  }
}
