import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self_leveling/features/ai/providers/ai_provider.dart';
import 'package:self_leveling/features/ai/services/ai_bridge_service.dart';
import 'package:self_leveling/features/ai/services/cloud_message_enhancer.dart';
import 'package:self_leveling/features/ai/services/local_first_messaging_service.dart';
import 'package:self_leveling/features/ai/services/local_message_generator.dart';
import 'package:self_leveling/features/ai/services/local_recommendation_engine.dart';

import 'local_first_messaging_service_test.dart'
    show FakeMessageContextService, FakeMessageHistoryRepository;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AI bridge returns local intervention payload for native bridge calls',
      () async {
    final container = ProviderContainer(
      overrides: [
        localFirstMessagingServiceProvider.overrideWith(
          (ref) => LocalFirstMessagingService(
            contextService: FakeMessageContextService(),
            historyRepository: FakeMessageHistoryRepository(),
            localMessageGenerator: LocalMessageGenerator(),
            localRecommendationEngine: LocalRecommendationEngine(),
            cloudMessageEnhancer: const NoOpCloudMessageEnhancer(),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final bridge = container.read(aiBridgeServiceProvider);
    final payload = await bridge.generateInterventionPayloadForNative({
      'contractVersion': 2,
      'payloadSignature': 'bridge-s1',
      'runtimeEventId': 'runtime:bridge:s1',
      'stage': 1,
      'packageName': 'com.example.app',
      'appName': 'Example App',
      'reason': 'warning',
      'distractionScore': 0.61,
      'ignoredWarnings': 0,
      'reentryCount': 0,
      'xpPenalty': 0,
      'limitedAccessRemainingSec': 0,
      'isLimitedAccess': false,
      'focusModeActive': false,
      'appCategory': 2,
      'requestedAt': DateTime.now().millisecondsSinceEpoch,
    });

    expect(payload['headline'], isNotEmpty);
    expect(payload['body'], isNotEmpty);
    expect(payload['messageSource'], 'local');
    expect(payload['historyKey'], 'bridge-s1');
    expect(payload['hasRecommendation'], isTrue);
  });
}
