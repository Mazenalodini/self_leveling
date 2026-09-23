import 'package:equatable/equatable.dart';
import '../enums/habit_type.dart';

/// A tracked habit entity.
class Habit extends Equatable {
  final String id;
  final String name;
  final HabitType type;
  final HabitFrequency frequency;
  final int currentStreak;
  final int longestStreak;
  final bool completedToday;
  final int xpReward;
  final int sortOrder;
  final String? reminderTime; // "09:00" format
  final DateTime createdAt;
  final List<DateTime> completionHistory;
  final DateTime? lastCompletedAt;
  final DateTime? nextEligibleAt;

  const Habit({
    required this.id,
    required this.name,
    required this.type,
    this.frequency = HabitFrequency.daily,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.completedToday = false,
    this.xpReward = 10,
    this.sortOrder = 0,
    this.reminderTime,
    required this.createdAt,
    this.completionHistory = const [],
    this.lastCompletedAt,
    this.nextEligibleAt,
  });

  /// Whether this is a "build" habit.
  bool get isBuild => type == HabitType.build;

  /// Whether this is a "break" habit.
  bool get isBreak => type == HabitType.breakHabit;

  /// Completion label based on habit type.
  String get completionLabel => isBuild ? 'Done' : 'Avoided';

  bool get isCompletionLocked =>
      nextEligibleAt != null && DateTime.now().isBefore(nextEligibleAt!);

  bool get canCompleteNow => !isCompletionLocked;

  Habit copyWith({
    String? name,
    HabitType? type,
    HabitFrequency? frequency,
    int? currentStreak,
    int? longestStreak,
    bool? completedToday,
    int? xpReward,
    int? sortOrder,
    String? reminderTime,
    List<DateTime>? completionHistory,
    DateTime? lastCompletedAt,
    DateTime? nextEligibleAt,
  }) {
    return Habit(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      frequency: frequency ?? this.frequency,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      completedToday: completedToday ?? this.completedToday,
      xpReward: xpReward ?? this.xpReward,
      sortOrder: sortOrder ?? this.sortOrder,
      reminderTime: reminderTime ?? this.reminderTime,
      createdAt: createdAt,
      completionHistory: completionHistory ?? this.completionHistory,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
      nextEligibleAt: nextEligibleAt ?? this.nextEligibleAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type.index,
        'frequency': frequency.index,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'completedToday': completedToday,
        'xpReward': xpReward,
        'sortOrder': sortOrder,
        'reminderTime': reminderTime,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'completionHistory':
            completionHistory.map((d) => d.millisecondsSinceEpoch).toList(),
        'lastCompletedAt': lastCompletedAt?.millisecondsSinceEpoch,
        'nextEligibleAt': nextEligibleAt?.millisecondsSinceEpoch,
      };

  factory Habit.fromMap(Map<dynamic, dynamic> map) => Habit(
        id: map['id'] as String,
        name: map['name'] as String,
        type: HabitType.values[map['type'] as int],
        frequency: HabitFrequency.values[map['frequency'] as int? ?? 0],
        currentStreak: map['currentStreak'] as int? ?? 0,
        longestStreak: map['longestStreak'] as int? ?? 0,
        completedToday: map['completedToday'] as bool? ?? false,
        xpReward: map['xpReward'] as int? ?? 10,
        sortOrder: map['sortOrder'] as int? ?? 0,
        reminderTime: map['reminderTime'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
        completionHistory: (map['completionHistory'] as List<dynamic>?)
                ?.map((e) => DateTime.fromMillisecondsSinceEpoch(e as int))
                .toList() ??
            [],
        lastCompletedAt: map['lastCompletedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['lastCompletedAt'] as int)
            : null,
        nextEligibleAt: map['nextEligibleAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['nextEligibleAt'] as int)
            : null,
      );

  @override
  List<Object?> get props => [id, name, completedToday, currentStreak];
}
