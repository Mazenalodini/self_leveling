import 'package:flutter_test/flutter_test.dart';
import 'package:self_leveling/domain/contracts/runtime_contract.dart';
import 'package:self_leveling/domain/entities/app_settings.dart';
import 'package:self_leveling/domain/entities/habit.dart';
import 'package:self_leveling/domain/entities/user_profile.dart';
import 'package:self_leveling/domain/enums/escalation_level.dart';
import 'package:self_leveling/domain/enums/habit_type.dart';
import 'package:self_leveling/features/ai/domain/entities/ai_contexts.dart';
import 'package:self_leveling/features/ai/domain/entities/messaging_models.dart';
import 'package:self_leveling/features/ai/services/cloud_message_enhancer.dart';
import 'package:self_leveling/features/ai/services/local_first_messaging_service.dart';
import 'package:self_leveling/features/ai/services/local_message_generator.dart';
import 'package:self_leveling/features/ai/services/local_recommendation_engine.dart';
import 'package:self_leveling/features/ai/services/message_context_service.dart';
import 'package:self_leveling/data/repositories/message_history_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  LocalFirstMessagingService buildService({
    CloudMessageEnhancer cloudEnhancer = const NoOpCloudMessageEnhancer(),
    Duration timeout = const Duration(milliseconds: 30),
    FakeMessageHistoryRepository? historyRepository,
  }) {
    return LocalFirstMessagingService(
      contextService: FakeMessageContextService(),
      historyRepository: historyRepository ?? FakeMessageHistoryRepository(),
      localMessageGenerator: LocalMessageGenerator(),
      localRecommendationEngine: LocalRecommendationEngine(),
      cloudMessageEnhancer: cloudEnhancer,
      cloudTimeout: timeout,
    );
  }

  test('composeIntervention persists local delivered message history',
      () async {
    final historyRepository = FakeMessageHistoryRepository();
    final service = buildService(historyRepository: historyRepository);

    final result = await service.composeIntervention(
      InterventionMessageRequest(
        payloadSignature: 'sig-s2',
        runtimeEventId: 'runtime:s2',
        stage: 2,
        packageName: 'com.example.app',
        appName: 'Example App',
        reason: 'sustained_distraction',
        distractionScore: 0.84,
        ignoredWarnings: 1,
        reentryCount: 0,
        xpPenalty: 0,
        limitedAccessRemainingSec: 0,
        isLimitedAccess: false,
        focusModeActive: true,
        appCategoryCode: AppCategory.distracting.nativeValue,
        requestedAt: DateTime.now(),
      ),
    );

    expect(result.source, MessageSource.local);
    expect(result.message.headline, isNotEmpty);
    expect(result.recommendation, isNotNull);

    final history = await historyRepository.getRecentMessages();
    expect(history, hasLength(1));
    expect(history.first.requestKind, MessageRequestKind.intervention);
    expect(history.first.deliveryStatus, 'delivered');
    expect(history.first.shownAt, isNotNull);
  });

  test('composeIntervention falls back locally when cloud enhancer times out',
      () async {
    final historyRepository = FakeMessageHistoryRepository();
    final service = buildService(
      cloudEnhancer: _SlowEnhancer(),
      timeout: const Duration(milliseconds: 10),
      historyRepository: historyRepository,
    );

    final result = await service.composeIntervention(
      InterventionMessageRequest(
        payloadSignature: 'sig-timeout',
        runtimeEventId: 'runtime:timeout',
        stage: 3,
        packageName: 'com.example.app',
        appName: 'Example App',
        reason: 'temporary_block',
        distractionScore: 0.91,
        ignoredWarnings: 2,
        reentryCount: 1,
        xpPenalty: 10,
        limitedAccessRemainingSec: 0,
        isLimitedAccess: false,
        focusModeActive: false,
        appCategoryCode: AppCategory.distracting.nativeValue,
        requestedAt: DateTime.now(),
      ),
    );

    expect(result.source, MessageSource.local);
    final history = await historyRepository.getRecentMessages();
    expect(history.first.source, MessageSource.local);
  });

  test('composeIntervention uses cloud enhancement when returned in time',
      () async {
    final historyRepository = FakeMessageHistoryRepository();
    final service = buildService(
      cloudEnhancer: const _FastEnhancer(),
      timeout: const Duration(milliseconds: 50),
      historyRepository: historyRepository,
    );

    final result = await service.composeIntervention(
      InterventionMessageRequest(
        payloadSignature: 'sig-cloud',
        runtimeEventId: 'runtime:cloud',
        stage: 1,
        packageName: 'com.example.app',
        appName: 'Example App',
        reason: 'warning',
        distractionScore: 0.66,
        ignoredWarnings: 0,
        reentryCount: 0,
        xpPenalty: 0,
        limitedAccessRemainingSec: 0,
        isLimitedAccess: false,
        focusModeActive: false,
        appCategoryCode: AppCategory.distracting.nativeValue,
        requestedAt: DateTime.now(),
      ),
    );

    expect(result.source, MessageSource.cloudEnhanced);
    expect(result.message.headline, 'Cloud Headline');
    final history = await historyRepository.getRecentMessages();
    expect(history.first.source, MessageSource.cloudEnhanced);
  });

  test('habit reminder composition persists scheduled history and feedback',
      () async {
    final historyRepository = FakeMessageHistoryRepository();
    final service = buildService(historyRepository: historyRepository);
    final habit = Habit(
      id: 'habit_1',
      name: 'Read 10 pages',
      type: HabitType.build,
      frequency: HabitFrequency.daily,
      reminderTime: '09:00',
      createdAt: DateTime.now(),
    );

    final result = await service.composeHabitReminder(
      habit: habit,
      language: 'en',
      requestKind: MessageRequestKind.habitReminder,
    );

    expect(result.message.headline, contains('Read 10 pages'));

    await service.recordFeedback(
      historyKey: result.historyKey,
      feedbackType: MessageFeedbackType.helpful,
      note: 'useful prompt',
    );

    final history = await historyRepository.getRecentMessages();
    expect(history.first.deliveryStatus, 'scheduled');

    final feedback = await historyRepository.getFeedbackFor(result.historyKey);
    expect(feedback, hasLength(1));
  });
}

class FakeMessageContextService extends MessageContextService {
  final UserProfile profile = UserProfile.create(displayName: 'User').copyWith(
    primaryIdentity: 'disciplined',
    breakTarget: 'doomscrolling',
    emotionalTrigger: 'stress',
    frustrationPoints: const ['wasted_time'],
    strictnessPreference: 'firm',
    messageStylePreference: 'philosophical',
    surveyLanguage: 'en',
  );

  @override
  Future<CanonicalMessageContext> buildInterventionContext(
    InterventionMessageRequest request,
  ) async {
    return CanonicalMessageContext(
      language: 'en',
      profile: profile,
      settings: const AppSettings(
        systemSensitivity: 0.6,
        escalationStrength: 0.7,
        notificationsEnabled: true,
      ),
      stage: request.interventionStage,
      lockState: request.interventionStage == InterventionStage.s4
          ? LockStatePayload(
              isLimitedAccess: request.isLimitedAccess,
              limitedAccessRemainingSeconds: request.limitedAccessRemainingSec,
              limitedAccessAppPackage: request.packageName,
              reentryCount: request.reentryCount,
            )
          : LockStatePayload(
              blockedAppPackage: request.interventionStage.isBlockingStage
                  ? request.packageName
                  : null,
              reentryCount: request.reentryCount,
            ),
      currentAppPackage: request.packageName,
      currentAppName: request.appName,
      appCategory: AppCategory.fromNativeValue(request.appCategoryCode),
      effectivePolicy: null,
      riskScore: request.distractionScore,
      ignoredWarningCount: request.ignoredWarnings,
      focusModeActive: request.focusModeActive,
      pendingHabits: [
        Habit(
          id: 'habit_1',
          name: 'Read 10 pages',
          type: HabitType.build,
          frequency: HabitFrequency.daily,
          reminderTime: '09:00',
          createdAt: DateTime(2026, 1, 1),
        ),
      ],
      recentInterventionCount24h: 2,
      lastInterventionStage: InterventionStage.s2,
      todayFocusMinutes: 30,
      runtimeEventId: request.runtimeEventId,
      payloadSignature: request.payloadSignature,
    );
  }

  @override
  Future<CanonicalMessageContext> buildHabitReminderContext({
    required Habit habit,
    required String language,
    required MessageRequestKind requestKind,
  }) async {
    return CanonicalMessageContext(
      language: language,
      profile: profile,
      settings: const AppSettings(notificationsEnabled: true),
      stage: InterventionStage.s0,
      lockState: const LockStatePayload(),
      currentAppPackage: null,
      currentAppName: habit.name,
      appCategory: AppCategory.neutral,
      effectivePolicy: null,
      riskScore: 0,
      ignoredWarningCount: 0,
      focusModeActive: false,
      pendingHabits: [habit],
      recentInterventionCount24h: 1,
      lastInterventionStage: InterventionStage.s1,
      todayFocusMinutes: 20,
      runtimeEventId: '${requestKind.storageValue}:${habit.id}',
      payloadSignature: '${requestKind.storageValue}:${habit.id}',
    );
  }

  @override
  MessageContext toGeneratorContext(
    CanonicalMessageContext context, {
    String? taskName,
    Habit? habit,
  }) {
    return MessageContext(
      currentLanguage: context.language,
      profile: context.profile,
      currentStage: EscalationLevel.values[context.stage.code.clamp(0, 5)],
      distractionScore: context.riskScore,
      focusModeActive: context.focusModeActive,
      contextTaskName: taskName ?? context.primaryPendingHabitName,
      contextHabitType: habit?.type,
      currentAppPackage: context.currentAppPackage,
      currentAppName: context.currentAppName,
      recentInterventionCount24h: context.recentInterventionCount24h,
      todayFocusMinutes: context.todayFocusMinutes,
      strictnessPreference: context.profile.strictnessPreference,
      currentXP: context.profile.currentXP,
      selfControlScore: context.profile.selfControlScore,
    );
  }

  @override
  RecommendationContext toRecommendationContext(
      CanonicalMessageContext context) {
    return RecommendationContext(
      currentLanguage: context.language,
      profile: context.profile,
      timeOfDay: DateTime(2026, 1, 1, 9),
      pendingHabits: context.pendingHabits,
      currentStage: EscalationLevel.values[context.stage.code.clamp(0, 5)],
      settings: context.settings,
      currentAppPackage: context.currentAppPackage,
      currentAppName: context.currentAppName,
      appCategory: context.appCategory,
      recentInterventionCount24h: context.recentInterventionCount24h,
      todayFocusMinutes: context.todayFocusMinutes,
    );
  }
}

class FakeMessageHistoryRepository extends MessageHistoryRepository {
  final List<MessageHistoryEntry> _messages = [];
  final List<MessageFeedbackEntry> _feedback = [];

  @override
  Future<void> saveMessage(MessageHistoryEntry entry) async {
    _messages.removeWhere((item) => item.historyKey == entry.historyKey);
    _messages.insert(0, entry);
  }

  @override
  Future<List<MessageHistoryEntry>> getRecentMessages({int limit = 20}) async {
    return _messages.take(limit).toList();
  }

  @override
  Future<void> saveFeedback(MessageFeedbackEntry entry) async {
    _feedback.removeWhere(
      (item) =>
          item.historyKey == entry.historyKey &&
          item.feedbackType == entry.feedbackType,
    );
    _feedback.add(entry);
  }

  @override
  Future<List<MessageFeedbackEntry>> getFeedbackFor(String historyKey) async {
    return _feedback.where((item) => item.historyKey == historyKey).toList();
  }
}

class _SlowEnhancer extends CloudMessageEnhancer {
  @override
  Future<CloudMessageEnhancement?> enhance(CloudMessageRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 40));
    return const CloudMessageEnhancement(headline: 'Slow Headline');
  }
}

class _FastEnhancer extends CloudMessageEnhancer {
  const _FastEnhancer();

  @override
  Future<CloudMessageEnhancement?> enhance(CloudMessageRequest request) async {
    return const CloudMessageEnhancement(
      headline: 'Cloud Headline',
      body: 'Cloud body',
      recommendationTitle: 'Cloud Recommendation',
      recommendationText: 'Take one deliberate pause.',
    );
  }
}
