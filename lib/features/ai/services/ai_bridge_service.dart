import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/entities/app_settings.dart';
import '../../../../domain/enums/behavior_category.dart';
import '../../../../domain/enums/escalation_level.dart';
import '../domain/entities/messaging_models.dart';
import '../domain/entities/ai_contexts.dart';
import '../domain/enums/output_channel.dart';
import '../providers/ai_provider.dart';
import '../../../providers/system_provider.dart';
import '../../../platform/platform_channel.dart';
import '../../../domain/contracts/runtime_contract.dart';

/// Provider for the AI Bridge Service
final aiBridgeServiceProvider = Provider<AIBridgeService>((ref) {
  final service = AIBridgeService(ref);
  service.initialize();
  return service;
});

/// Bridge service that listens for Kotlin (Native) requests
/// and returns the structured generated wording.
class AIBridgeService {
  final Ref _ref;
  bool _initialized = false;

  AIBridgeService(this._ref);

  void initialize() {
    if (_initialized) return;
    _initialized = true;

    PlatformChannel.methodChannel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == RuntimeMethodNames.generateIntervention) {
      try {
        final args = call.arguments as Map<dynamic, dynamic>;
        return await generateInterventionPayloadForNative(args);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> generateInterventionPayloadForNative(
      Map<dynamic, dynamic> args) async {
    final request = InterventionMessageRequest.fromMap(args);
    MessageCompositionResult generated;
    try {
      final messaging = _ref.read(localFirstMessagingServiceProvider);
      generated = await messaging.composeIntervention(request);
    } catch (_) {
      final systemState = _ref.read(systemProvider);
      final generator = _ref.read(localMessageGeneratorProvider);
      final recommendationEngine = _ref.read(localRecommendationEngineProvider);
      final stageIndex = request.interventionStage.code.clamp(0, 5).toInt();
      final stage = EscalationLevel.values[stageIndex];
      final category = request.appCategoryCode
          .clamp(
            0,
            BehaviorCategory.values.length - 1,
          )
          .toInt();
      final messageContext = MessageContext(
        currentLanguage: systemState.profile.surveyLanguage.isNotEmpty
            ? systemState.profile.surveyLanguage
            : 'ar',
        profile: systemState.profile,
        currentStage: stage,
        distractionScore: request.distractionScore,
        currentAppCategory: BehaviorCategory.values[category],
        ignoredWarningCount: request.ignoredWarnings,
        focusModeActive: request.focusModeActive,
        currentAppPackage: request.packageName,
        currentAppName: request.appName,
        recentInterventionCount24h: 0,
        todayFocusMinutes: 0,
        strictnessPreference: systemState.profile.strictnessPreference,
        currentXP: systemState.profile.currentXP,
        selfControlScore: systemState.profile.selfControlScore,
      );
      final recommendationContext = RecommendationContext(
        currentLanguage: messageContext.currentLanguage,
        profile: systemState.profile,
        timeOfDay: DateTime.now(),
        pendingHabits: const [],
        currentStage: stage,
        currentAppPackage: request.packageName,
        currentAppName: request.appName,
        appCategory: AppCategory.fromNativeValue(request.appCategoryCode),
      );
      final outputChannel = request.interventionStage.isBlockingStage
          ? OutputChannel.fullOverlay
          : request.interventionStage.isLimitedAccessStage
              ? OutputChannel.notification
              : OutputChannel.notification;
      final message = await generator.generateMessage(
        messageContext,
        outputChannel,
      );
      final recommendation = request.stage > 0
          ? await recommendationEngine.getBestAction(recommendationContext)
          : null;
      generated = MessageCompositionResult(
        historyKey: request.payloadSignature,
        context: CanonicalMessageContext(
          language: messageContext.currentLanguage,
          profile: systemState.profile,
          settings: const AppSettings(),
          stage: request.interventionStage,
          lockState: const LockStatePayload(),
          currentAppPackage: request.packageName,
          currentAppName: request.appName,
          appCategory: AppCategory.fromNativeValue(request.appCategoryCode),
          effectivePolicy: null,
          riskScore: request.distractionScore,
          ignoredWarningCount: request.ignoredWarnings,
          focusModeActive: request.focusModeActive,
          pendingHabits: const [],
          recentInterventionCount24h: 0,
          lastInterventionStage: null,
          todayFocusMinutes: 0,
          runtimeEventId: request.runtimeEventId,
          payloadSignature: request.payloadSignature,
        ),
        message: message,
        recommendation: recommendation,
        source: MessageSource.local,
      );
    }
    final payload = {
      'headline': generated.message.headline,
      'body': generated.message.body,
      'actionLabel': generated.message.actionLabel,
      'tone': generated.message.tone,
      'language': generated.message.language,
      'reasoningTags': generated.message.reasoningTags,
      'messageSource': generated.source.storageValue,
      'historyKey': generated.historyKey,
      'hasRecommendation': generated.recommendation != null,
      if (generated.recommendation != null) ...{
        'recommendationTitle': generated.recommendation!.title,
        'recommendationText': generated.recommendation!.subtitle ?? '',
      },
    };
    return payload;
  }
}
