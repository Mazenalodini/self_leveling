import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self_leveling/domain/entities/user_profile.dart';
import 'package:self_leveling/providers/system_provider.dart';
import 'package:self_leveling/services/behavior_service.dart';
import 'package:self_leveling/services/xp_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('system provider derives progression state from xp service', () async {
    final fakeXpService = FakeXPService(
      initial: UserProfile.create(displayName: 'User'),
      awarded: UserProfile.create(displayName: 'User').copyWith(
        level: 2,
        currentXP: 15,
        selfControlScore: 58,
      ),
    );

    final container = ProviderContainer(
      overrides: [
        systemProvider.overrideWith(
          (ref) => SystemNotifier(
            xpService: fakeXpService,
            behaviorService: FakeBehaviorService(),
            initialProfile: fakeXpService.initial,
            subscribeToNativeState: false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(systemProvider.notifier).awardXP(30);

    expect(container.read(userLevelProvider), 2);
    expect(container.read(selfControlProvider), 58);
    expect(fakeXpService.awardCalls, 1);
  });
}

class FakeXPService extends XPService {
  final UserProfile initial;
  final UserProfile awarded;
  int awardCalls = 0;

  FakeXPService({
    required this.initial,
    required this.awarded,
  });

  @override
  Future<UserProfile> awardXP(int amount) async {
    awardCalls++;
    return awarded;
  }

  @override
  Future<UserProfile> getProfile() async => awarded;
}

class FakeBehaviorService extends BehaviorService {}
