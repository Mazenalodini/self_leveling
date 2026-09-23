import 'package:flutter_test/flutter_test.dart';
import 'package:self_leveling/domain/entities/user_profile.dart';
import 'package:self_leveling/domain/enums/escalation_level.dart';
import 'package:self_leveling/domain/enums/behavior_category.dart';
import 'package:self_leveling/domain/enums/habit_type.dart';
import 'package:self_leveling/features/ai/domain/entities/ai_contexts.dart';
import 'package:self_leveling/features/ai/domain/enums/output_channel.dart';
import 'package:self_leveling/features/ai/services/local_message_generator.dart';

void main() {
  final generator = LocalMessageGenerator();
  final profile = UserProfile.create(displayName: 'User').copyWith(
    primaryIdentity: 'disciplined',
    breakTarget: 'doomscrolling',
    emotionalTrigger: 'stress',
    frustrationPoints: const ['wasted_time'],
    messageStylePreference: 'philosophical',
    strictnessPreference: 'firm',
    surveyLanguage: 'en',
  );

  MessageContext contextFor(EscalationLevel stage) {
    return MessageContext(
      currentLanguage: 'en',
      profile: profile,
      currentStage: stage,
      currentAppCategory: BehaviorCategory.distracting,
      distractionScore: 0.82,
      ignoredWarningCount: 1,
      focusModeActive: stage.index >= 1,
      currentAppName: 'Distracting App',
      currentAppPackage: 'com.example.distracting',
      recentInterventionCount24h: 3,
      currentXP: 120,
      selfControlScore: 58,
    );
  }

  test('generates habit reminder for S0', () async {
    final result = await generator.generateMessage(
      contextFor(EscalationLevel.s0).copyWithContextTask('Morning Walk'),
      OutputChannel.habitReminder,
    );

    expect(result.headline, contains('complete Morning Walk'));
    expect(result.body, isNotEmpty);
  });

  test('generates break-habit reminder with avoid/resist semantics', () async {
    final result = await generator.generateMessage(
      contextFor(EscalationLevel.s0).copyWithContextTask(
        'Late-night scrolling',
        habitType: HabitType.breakHabit,
      ),
      OutputChannel.habitReminder,
    );

    expect(result.headline, contains('Keep away from Late-night scrolling'));
    expect(result.body, contains('keep resisting Late-night scrolling'));
  });

  test('generates awareness message for S1', () async {
    final result = await generator.generateMessage(
      contextFor(EscalationLevel.s1),
      OutputChannel.notification,
    );

    expect(result.headline, isNotEmpty);
    expect(result.body, contains('strict focus mode'));
  });

  test('generates strict warning for S2', () async {
    final result = await generator.generateMessage(
      contextFor(EscalationLevel.s2),
      OutputChannel.fullOverlay,
    );

    expect(result.body, contains('Distracting App'));
    expect(result.tone, 'strict');
  });

  test('generates interruption message for S3', () async {
    final result = await generator.generateMessage(
      contextFor(EscalationLevel.s3),
      OutputChannel.fullOverlay,
    );

    expect(result.headline, isNotEmpty);
    expect(result.body, contains('Force quit'));
  });

  test('generates monitored message for S4', () async {
    final result = await generator.generateMessage(
      contextFor(EscalationLevel.s4),
      OutputChannel.notification,
    );

    expect(result.headline, isNotEmpty);
    expect(result.body, contains('Monitored'));
  });

  test('generates hard lock message for S5', () async {
    final result = await generator.generateMessage(
      contextFor(EscalationLevel.s5),
      OutputChannel.fullOverlay,
    );

    expect(result.headline, isNotEmpty);
    expect(result.body, contains('System locked'));
  });
}

extension on MessageContext {
  MessageContext copyWithContextTask(
    String taskName, {
    HabitType? habitType,
  }) {
    return MessageContext(
      currentLanguage: currentLanguage,
      profile: profile,
      currentStage: currentStage,
      distractionScore: distractionScore,
      currentAppCategory: currentAppCategory,
      ignoredWarningCount: ignoredWarningCount,
      focusModeActive: focusModeActive,
      contextTaskName: taskName,
      contextHabitType: habitType,
      currentAppPackage: currentAppPackage,
      currentAppName: currentAppName,
      recentInterventionCount24h: recentInterventionCount24h,
      todayFocusMinutes: todayFocusMinutes,
      strictnessPreference: strictnessPreference,
      currentXP: currentXP,
      selfControlScore: selfControlScore,
    );
  }
}
