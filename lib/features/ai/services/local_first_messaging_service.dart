import '../../../../data/repositories/message_history_repository.dart';
import '../../../../domain/contracts/runtime_contract.dart';
import '../../../../domain/entities/habit.dart';
import '../domain/entities/ai_outputs.dart';
import '../domain/entities/messaging_models.dart';
import '../domain/enums/output_channel.dart';
import '../domain/interfaces/message_generator.dart';
import '../domain/interfaces/recommendation_engine.dart';
import 'cloud_message_enhancer.dart';
import 'message_context_service.dart';
import 'message_intent_resolver.dart';

class LocalFirstMessagingService {
  final MessageContextService _contextService;
  final MessageHistoryRepository _historyRepository;
  final MessageGenerator _localMessageGenerator;
  final RecommendationEngine _localRecommendationEngine;
  final CloudMessageEnhancer _cloudMessageEnhancer;
  final MessageIntentResolver _intentResolver;
  final Duration cloudTimeout;

  LocalFirstMessagingService({
    required MessageContextService contextService,
    required MessageHistoryRepository historyRepository,
    required MessageGenerator localMessageGenerator,
    required RecommendationEngine localRecommendationEngine,
    required CloudMessageEnhancer cloudMessageEnhancer,
    MessageIntentResolver intentResolver = const MessageIntentResolver(),
    this.cloudTimeout = const Duration(milliseconds: 900),
  })  : _contextService = contextService,
        _historyRepository = historyRepository,
        _localMessageGenerator = localMessageGenerator,
        _localRecommendationEngine = localRecommendationEngine,
        _cloudMessageEnhancer = cloudMessageEnhancer,
        _intentResolver = intentResolver;

  Future<MessageCompositionResult> composeIntervention(
    InterventionMessageRequest request,
  ) async {
    final context = await _contextService.buildInterventionContext(request);
    final outputChannel = _outputChannelForStage(request.interventionStage);
    final generatorContext = _contextService.toGeneratorContext(context);
    final recommendationContext =
        _contextService.toRecommendationContext(context);

    final localMessage = await _localMessageGenerator.generateMessage(
      generatorContext,
      outputChannel,
    );
    final localRecommendation = request.stage > 0
        ? await _localRecommendationEngine.getBestAction(recommendationContext)
        : null;

    final resolved = await _resolveFinalPayload(
      historyKey: request.payloadSignature,
      requestKind: MessageRequestKind.intervention,
      outputChannel: outputChannel,
      context: context,
      localMessage: localMessage,
      localRecommendation: localRecommendation,
      deliveryStatus: 'delivered',
      shownAt: request.requestedAt,
    );
    return resolved;
  }

  Future<MessageCompositionResult> composeHabitReminder({
    required Habit habit,
    required String language,
    required MessageRequestKind requestKind,
  }) async {
    final context = await _contextService.buildHabitReminderContext(
      habit: habit,
      language: language,
      requestKind: requestKind,
    );
    final outputChannel = requestKind == MessageRequestKind.habitReminder
        ? OutputChannel.habitReminder
        : OutputChannel.missedHabitNudge;
    final generatorContext = _contextService.toGeneratorContext(
      context,
      taskName: habit.name,
      habit: habit,
    );
    final localMessage = await _localMessageGenerator.generateMessage(
      generatorContext,
      outputChannel,
    );
    final historyKey =
        '${requestKind.storageValue}:${habit.id}:${DateTime.now().toIso8601String().substring(0, 10)}:${language}';

    return _resolveFinalPayload(
      historyKey: historyKey,
      requestKind: requestKind,
      outputChannel: outputChannel,
      context: context,
      localMessage: localMessage,
      localRecommendation: null,
      deliveryStatus: 'scheduled',
      shownAt: null,
    );
  }

  Future<void> recordFeedback({
    required String historyKey,
    required MessageFeedbackType feedbackType,
    String note = '',
  }) {
    return _historyRepository.saveFeedback(
      MessageFeedbackEntry(
        historyKey: historyKey,
        feedbackType: feedbackType,
        note: note,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<MessageCompositionResult> _resolveFinalPayload({
    required String historyKey,
    required MessageRequestKind requestKind,
    required OutputChannel outputChannel,
    required CanonicalMessageContext context,
    required GeneratedMessage localMessage,
    required RecommendationResult? localRecommendation,
    required String deliveryStatus,
    required DateTime? shownAt,
  }) async {
    var source = MessageSource.local;
    var finalMessage = localMessage;
    var finalRecommendation = localRecommendation;

    final cloudResult = await _tryCloudEnhancement(
      historyKey: historyKey,
      requestKind: requestKind,
      intent: _intentResolver.resolveForRequest(
        requestKind: requestKind,
        stage: context.stage,
      ),
      outputChannel: outputChannel,
      context: context,
      localMessage: localMessage,
      localRecommendation: localRecommendation,
    );

    if (cloudResult != null) {
      source = MessageSource.cloudEnhanced;
      finalMessage = GeneratedMessage(
        headline: cloudResult.headline ?? localMessage.headline,
        body: cloudResult.body ?? localMessage.body,
        tone: cloudResult.tone ?? localMessage.tone,
        channel: localMessage.channel,
        actionLabel: cloudResult.actionLabel ?? localMessage.actionLabel,
        reasoningTags: localMessage.reasoningTags,
        language: localMessage.language,
      );
      final hasCloudRecommendationTitle =
          cloudResult.recommendationTitle?.isNotEmpty == true;
      final hasCloudRecommendationText =
          cloudResult.recommendationText?.isNotEmpty == true;
      if (localRecommendation != null &&
          (hasCloudRecommendationTitle || hasCloudRecommendationText)) {
        finalRecommendation = RecommendationResult(
          actionType: localRecommendation.actionType,
          title: cloudResult.recommendationTitle ?? localRecommendation.title,
          subtitle:
              cloudResult.recommendationText ?? localRecommendation.subtitle,
          reasoningTags: localRecommendation.reasoningTags,
          confidenceScore: localRecommendation.confidenceScore,
          targetId: localRecommendation.targetId,
        );
      }
    }

    await _historyRepository.saveMessage(
      MessageHistoryEntry(
        historyKey: historyKey,
        runtimeEventId: context.runtimeEventId,
        source: source,
        requestKind: requestKind,
        outputChannel: outputChannel,
        stage: context.stage,
        packageName: context.currentAppPackage ?? '',
        appName: context.currentAppName ?? '',
        appCategory: context.appCategory,
        headline: finalMessage.headline,
        body: finalMessage.body,
        actionLabel: finalMessage.actionLabel,
        recommendationTitle: finalRecommendation?.title,
        recommendationText: finalRecommendation?.subtitle,
        tone: finalMessage.tone,
        language: finalMessage.language,
        deliveryStatus: deliveryStatus,
        generatedAt: DateTime.now(),
        shownAt: shownAt,
        contextJson: context.toStorageJson(),
      ),
    );

    return MessageCompositionResult(
      historyKey: historyKey,
      context: context,
      message: finalMessage,
      recommendation: finalRecommendation,
      source: source,
    );
  }

  Future<CloudMessageEnhancement?> _tryCloudEnhancement({
    required String historyKey,
    required MessageRequestKind requestKind,
    required MessageIntent intent,
    required OutputChannel outputChannel,
    required CanonicalMessageContext context,
    required GeneratedMessage localMessage,
    required RecommendationResult? localRecommendation,
  }) async {
    try {
      return await _cloudMessageEnhancer
          .enhance(
            CloudMessageRequest(
              historyKey: historyKey,
              requestKind: requestKind,
              intent: intent,
              outputChannel: outputChannel,
              context: context,
              localMessage: localMessage,
              recommendation: localRecommendation,
            ),
          )
          .timeout(
            cloudTimeout,
            onTimeout: () => null,
          );
    } catch (_) {
      return null;
    }
  }

  OutputChannel _outputChannelForStage(InterventionStage stage) {
    switch (stage) {
      case InterventionStage.s1:
      case InterventionStage.s2:
      case InterventionStage.s4:
        return OutputChannel.notification;
      case InterventionStage.s3:
      case InterventionStage.s5:
        return OutputChannel.fullOverlay;
      case InterventionStage.s0:
        return OutputChannel.floatingCard;
    }
  }
}
