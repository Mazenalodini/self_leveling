import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/habit.dart';
import '../domain/enums/habit_type.dart';
import '../services/habit_service.dart';
import 'report_provider.dart';
import 'system_provider.dart';

/// Habit state managed by Riverpod.
class HabitState {
  final List<Habit> habits;
  final bool isLoading;

  const HabitState({this.habits = const [], this.isLoading = false});

  List<Habit> get buildHabits => habits.where((h) => h.isBuild).toList();
  List<Habit> get breakHabits => habits.where((h) => h.isBreak).toList();
  int get completedCount => habits.where((h) => h.completedToday).length;
  int get totalCount => habits.length;

  HabitState copyWith({List<Habit>? habits, bool? isLoading}) {
    return HabitState(
      habits: habits ?? this.habits,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class HabitNotifier extends StateNotifier<HabitState> {
  final HabitService habitService;
  final Ref ref;
  StreamSubscription? _sub;

  HabitNotifier({required this.habitService, required this.ref})
      : super(const HabitState(isLoading: true)) {
    _loadHabits();
    _sub = habitService.onHabitsChanged.listen((habits) {
      state = state.copyWith(habits: habits, isLoading: false);
    });
  }

  Future<void> _loadHabits() async {
    state = state.copyWith(isLoading: true);
    final habits = await habitService.getAll();
    state = state.copyWith(habits: habits, isLoading: false);
  }

  /// Add a new habit.
  Future<void> addHabit({
    required String name,
    required HabitType type,
    HabitFrequency frequency = HabitFrequency.daily,
    String? reminderTime,
  }) async {
    await habitService.add(
      name: name,
      type: type,
      frequency: frequency,
      reminderTime: reminderTime,
    );
  }

  /// Delete a habit.
  Future<void> deleteHabit(String habitId) async {
    await habitService.delete(habitId);
  }

  /// Update habit fields.
  Future<void> updateHabit(String habitId,
      {String? name, HabitFrequency? frequency, String? reminderTime}) async {
    await habitService.updateHabit(habitId,
        name: name, frequency: frequency, reminderTime: reminderTime);
  }

  /// Bulk update habits order.
  Future<void> updateHabitsOrder(List<String> habitIds) async {
    // Optimistically update UI
    final newHabits = [...state.habits];
    newHabits.sort((a, b) {
      final aIndex = habitIds.indexOf(a.id);
      final bIndex = habitIds.indexOf(b.id);
      if (aIndex == -1 || bIndex == -1) return 0;
      return aIndex.compareTo(bIndex);
    });
    state = state.copyWith(habits: newHabits);

    // Persist to DB
    await habitService.updateHabitsOrder(habitIds);
  }

  /// Attempt a valid habit completion for the current scheduling window.
  Future<HabitCompletionResult> toggleHabit(String habitId) async {
    final result = await habitService.toggleCompletion(habitId);
    if (result.completedNow) {
      await ref.read(systemProvider.notifier).refreshProfile();
      ref.read(reportRefreshVersionProvider.notifier).markDirty();
    }
    return result;
  }

  /// Reset daily completions.
  Future<void> resetDaily() async {
    await habitService.resetDailyCompletions();
    await _loadHabits();
    ref.read(reportRefreshVersionProvider.notifier).markDirty();
  }

  /// Refresh habits from DB.
  Future<void> refresh() async {
    await _loadHabits();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final habitServiceProvider = Provider<HabitService>((ref) {
  final service = HabitService();
  ref.onDispose(() => service.dispose());
  return service;
});

final habitProvider = StateNotifierProvider<HabitNotifier, HabitState>((ref) {
  return HabitNotifier(
    habitService: ref.read(habitServiceProvider),
    ref: ref,
  );
});
