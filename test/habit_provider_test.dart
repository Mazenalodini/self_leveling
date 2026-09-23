import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self_leveling/domain/entities/habit.dart';
import 'package:self_leveling/domain/entities/user_profile.dart';
import 'package:self_leveling/domain/enums/habit_type.dart';
import 'package:self_leveling/providers/habit_provider.dart';
import 'package:self_leveling/providers/system_provider.dart';
import 'package:self_leveling/services/behavior_service.dart';
import 'package:self_leveling/services/habit_service.dart';
import 'package:self_leveling/services/xp_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('habit provider refreshes canonical profile after toggling', () async {
    final fakeHabitService = FakeHabitService();
    final fakeXpService = FakeXPService(
      UserProfile.create(displayName: 'User').copyWith(
        level: 2,
        currentXP: 5,
      ),
    );

    final container = ProviderContainer(
      overrides: [
        habitServiceProvider.overrideWithValue(fakeHabitService),
        systemProvider.overrideWith(
          (ref) => SystemNotifier(
            xpService: fakeXpService,
            behaviorService: FakeBehaviorService(),
            initialProfile: UserProfile.create(displayName: 'User'),
            subscribeToNativeState: false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await Future<void>.delayed(Duration.zero);
    await container.read(habitProvider.notifier).toggleHabit('habit-1');
    await Future<void>.delayed(Duration.zero);

    expect(fakeHabitService.toggleCalls, 1);
    expect(container.read(habitProvider).completedCount, 1);
    expect(container.read(userLevelProvider), 2);
    expect(fakeXpService.getProfileCalls, greaterThanOrEqualTo(1));
  });

  test('habit provider does not refresh progression on duplicate completion',
      () async {
    final fakeHabitService = FakeHabitService()
      ..nextResult = const HabitCompletionResult(
        status: HabitCompletionStatus.alreadyCompleted,
      );
    final fakeXpService = FakeXPService(
      UserProfile.create(displayName: 'User').copyWith(
        level: 2,
        currentXP: 5,
      ),
    );

    final container = ProviderContainer(
      overrides: [
        habitServiceProvider.overrideWithValue(fakeHabitService),
        systemProvider.overrideWith(
          (ref) => SystemNotifier(
            xpService: fakeXpService,
            behaviorService: FakeBehaviorService(),
            initialProfile: UserProfile.create(displayName: 'User'),
            subscribeToNativeState: false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await Future<void>.delayed(Duration.zero);
    final result =
        await container.read(habitProvider.notifier).toggleHabit('habit-1');
    await Future<void>.delayed(Duration.zero);

    expect(result.completedNow, isFalse);
    expect(fakeHabitService.toggleCalls, 1);
    expect(fakeXpService.getProfileCalls, 0);
  });
}

class FakeHabitService extends HabitService {
  final _controller = StreamController<List<Habit>>.broadcast();
  int toggleCalls = 0;
  HabitCompletionResult nextResult = const HabitCompletionResult(
    status: HabitCompletionStatus.completed,
    xpEarned: 25,
  );
  List<Habit> _habits = [
    Habit(
      id: 'habit-1',
      name: 'Read',
      type: HabitType.build,
      createdAt: DateTime(2026),
    ),
  ];

  @override
  Stream<List<Habit>> get onHabitsChanged => _controller.stream;

  @override
  Future<List<Habit>> getAll() async => _habits;

  @override
  Future<HabitCompletionResult> toggleCompletion(String habitId) async {
    toggleCalls++;
    if (!nextResult.completedNow) {
      return nextResult;
    }
    _habits = [
      _habits.first.copyWith(
        completedToday: true,
        currentStreak: 1,
        longestStreak: 1,
        lastCompletedAt: DateTime.now(),
        nextEligibleAt: DateTime.now().add(const Duration(days: 1)),
      ),
    ];
    _controller.add(_habits);
    return nextResult;
  }

  @override
  void dispose() {
    _controller.close();
  }
}

class FakeXPService extends XPService {
  UserProfile profile;
  int getProfileCalls = 0;

  FakeXPService(this.profile);

  @override
  Future<UserProfile> getProfile() async {
    getProfileCalls++;
    return profile;
  }
}

class FakeBehaviorService extends BehaviorService {}
