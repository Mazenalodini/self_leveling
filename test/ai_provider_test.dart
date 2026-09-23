import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self_leveling/domain/entities/habit.dart';
import 'package:self_leveling/domain/entities/user_profile.dart';
import 'package:self_leveling/domain/enums/escalation_level.dart';
import 'package:self_leveling/domain/enums/habit_type.dart';
import 'package:self_leveling/features/ai/domain/entities/ai_contexts.dart';
import 'package:self_leveling/features/ai/providers/ai_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AI providers produce real local guidance from canonical contexts',
      () async {
    final profile = UserProfile.create(displayName: 'User').copyWith(
      identityStatement: 'Focused and disciplined',
      selfControlScore: 62,
    );
    final container = ProviderContainer(
      overrides: [
        messageContextBuilderProvider.overrideWith(
          (ref) => MessageContext(
            currentLanguage: 'en',
            profile: profile,
            currentStage: EscalationLevel.s2,
            distractionScore: 0.72,
          ),
        ),
        recommendationContextBuilderProvider.overrideWith(
          (ref) => RecommendationContext(
            currentLanguage: 'en',
            profile: profile,
            timeOfDay: DateTime(2026, 1, 1, 9),
            currentStage: EscalationLevel.s1,
            pendingHabits: [
              Habit(
                id: 'habit_1',
                name: 'Morning Reading',
                type: HabitType.build,
                frequency: HabitFrequency.daily,
                createdAt: DateTime(2026, 1, 1, 7),
              ),
            ],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final message = await container.read(aiSystemMessageProvider.future);
    final recommendation =
        await container.read(aiRecommendationProvider.future);

    expect(message.headline, isNotEmpty);
    expect(message.body, isNotEmpty);
    expect(recommendation.title, isNotEmpty);
    expect(recommendation.confidenceScore, greaterThan(0));
  });
}
