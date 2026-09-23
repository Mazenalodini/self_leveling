import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self_leveling/domain/contracts/runtime_contract.dart';
import 'package:self_leveling/domain/entities/focus_session.dart';
import 'package:self_leveling/domain/entities/user_profile.dart';
import 'package:self_leveling/providers/focus_provider.dart';
import 'package:self_leveling/providers/system_provider.dart';
import 'package:self_leveling/services/behavior_service.dart';
import 'package:self_leveling/services/focus_service.dart';
import 'package:self_leveling/services/xp_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(RuntimeChannelNames.method);

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case RuntimeMethodNames.setFocusMode:
          return null;
        default:
          return false;
      }
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('focus provider persists completion and refreshes progression profile',
      () async {
    final fakeFocusService = FakeFocusService();
    final fakeXpService = FakeXPService(
      UserProfile.create(displayName: 'User').copyWith(
        currentXP: 20,
        selfControlScore: 56,
      ),
    );

    final container = ProviderContainer(
      overrides: [
        focusServiceProvider.overrideWithValue(fakeFocusService),
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
    final notifier = container.read(focusProvider.notifier);

    notifier.startSession(durationMinutes: 1);
    await notifier.completeSession();
    await Future<void>.delayed(Duration.zero);

    final state = container.read(focusProvider);
    expect(state.activeSession, isNull);
    expect(state.phase, FocusSessionPhase.completed);
    expect(state.hasCompletedSession, isTrue);
    expect(state.history, hasLength(1));
    expect(state.history.single.wasCompleted, isTrue);
    expect(fakeFocusService.savedSessions, hasLength(1));
    expect(fakeXpService.getProfileCalls, greaterThanOrEqualTo(1));
  });

  test('focus provider persists interruption without awarding completion XP',
      () async {
    final fakeFocusService = FakeFocusService();
    final fakeXpService = FakeXPService(
      UserProfile.create(displayName: 'User').copyWith(
        currentXP: 20,
        selfControlScore: 56,
      ),
    );

    final container = ProviderContainer(
      overrides: [
        focusServiceProvider.overrideWithValue(fakeFocusService),
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
    final notifier = container.read(focusProvider.notifier);

    notifier.startSession(durationMinutes: 1);
    await notifier.interruptSession();
    await Future<void>.delayed(Duration.zero);

    final state = container.read(focusProvider);
    expect(state.activeSession, isNull);
    expect(state.phase, FocusSessionPhase.interrupted);
    expect(state.hasInterruptedSession, isTrue);
    expect(state.todaySessionCount, 0);
    expect(state.lastFinishedSession, isNotNull);
    expect(state.lastFinishedSession!.wasCompleted, isFalse);
    expect(state.lastFinishedSession!.xpEarned, 0);
    expect(fakeFocusService.savedSessions, hasLength(1));
    expect(fakeFocusService.savedSessions.single.wasCompleted, isFalse);
    expect(fakeFocusService.savedSessions.single.xpEarned, 0);
    expect(fakeXpService.getProfileCalls, 0);
  });
}

class FakeFocusService extends FocusService {
  final List<FocusSession> savedSessions = [];

  @override
  Future<void> saveSession(FocusSession session) async {
    savedSessions.add(session);
  }

  @override
  Future<List<FocusSession>> getTodaySessions() async => [];
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
