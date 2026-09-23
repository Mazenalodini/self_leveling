import 'dart:convert';

import '../../../../domain/contracts/runtime_contract.dart';
import '../../../../domain/entities/app_settings.dart';
import '../../../../domain/entities/effective_app_policy.dart';
import '../../../../domain/entities/habit.dart';
import '../../../../domain/entities/user_profile.dart';
import '../../domain/entities/ai_outputs.dart';
import '../../domain/enums/output_channel.dart';

enum MessageSource {
  local('local'),
  cloudEnhanced('cloud_enhanced');

  final String storageValue;

  const MessageSource(this.storageValue);

  static MessageSource fromStorage(String? value) {
    return MessageSource.values.firstWhere(
      (item) => item.storageValue == value,
      orElse: () => MessageSource.local,
    );
  }
}

enum MessageIntent {
  warning('warning'),
  reminder('reminder'),
  encouragement('encouragement'),
  advice('advice'),
  blockNotice('block_notice'),
  chatReply('chat_reply');

  final String storageValue;

  const MessageIntent(this.storageValue);
}

enum MessageRequestKind {
  intervention('intervention'),
  habitReminder('habit_reminder'),
  missedHabitNudge('missed_habit_nudge');

  final String storageValue;

  const MessageRequestKind(this.storageValue);

  static MessageRequestKind fromStorage(String? value) {
    return MessageRequestKind.values.firstWhere(
      (item) => item.storageValue == value,
      orElse: () => MessageRequestKind.intervention,
    );
  }
}

enum MessageFeedbackType {
  acknowledged('acknowledged'),
  helpful('helpful'),
  dismissed('dismissed'),
  notHelpful('not_helpful');

  final String storageValue;

  const MessageFeedbackType(this.storageValue);

  static MessageFeedbackType fromStorage(String? value) {
    return MessageFeedbackType.values.firstWhere(
      (item) => item.storageValue == value,
      orElse: () => MessageFeedbackType.acknowledged,
    );
  }
}

class InterventionMessageRequest {
  final int contractVersion;
  final String payloadSignature;
  final String runtimeEventId;
  final int stage;
  final String packageName;
  final String appName;
  final String reason;
  final double distractionScore;
  final int ignoredWarnings;
  final int reentryCount;
  final int xpPenalty;
  final int limitedAccessRemainingSec;
  final bool isLimitedAccess;
  final bool focusModeActive;
  final int appCategoryCode;
  final DateTime requestedAt;

  const InterventionMessageRequest({
    this.contractVersion = kRuntimeContractVersion,
    required this.payloadSignature,
    required this.runtimeEventId,
    required this.stage,
    required this.packageName,
    required this.appName,
    required this.reason,
    required this.distractionScore,
    required this.ignoredWarnings,
    required this.reentryCount,
    required this.xpPenalty,
    required this.limitedAccessRemainingSec,
    required this.isLimitedAccess,
    required this.focusModeActive,
    required this.appCategoryCode,
    required this.requestedAt,
  });

  factory InterventionMessageRequest.fromMap(Map<dynamic, dynamic> map) {
    final packageName = map['packageName'] as String? ?? '';
    final stage = (map['stage'] as int?) ?? 0;
    final requestedAtMs =
        (map['requestedAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch;
    final payloadSignature = map['payloadSignature'] as String? ??
        '$stage:$packageName:$requestedAtMs';
    return InterventionMessageRequest(
      contractVersion:
          (map['contractVersion'] as int?) ?? kRuntimeContractVersion,
      payloadSignature: payloadSignature,
      runtimeEventId:
          map['runtimeEventId'] as String? ?? 'runtime:$payloadSignature',
      stage: stage,
      packageName: packageName,
      appName: map['appName'] as String? ?? packageName,
      reason: map['reason'] as String? ?? '',
      distractionScore: (map['distractionScore'] as num?)?.toDouble() ?? 0.0,
      ignoredWarnings: (map['ignoredWarnings'] as int?) ?? 0,
      reentryCount: (map['reentryCount'] as int?) ?? 0,
      xpPenalty: (map['xpPenalty'] as int?) ?? 0,
      limitedAccessRemainingSec:
          (map['limitedAccessRemainingSec'] as int?) ?? 0,
      isLimitedAccess: (map['isLimitedAccess'] as bool?) ?? false,
      focusModeActive: (map['focusModeActive'] as bool?) ?? false,
      appCategoryCode:
          (map['appCategory'] as int?) ?? AppCategory.neutral.nativeValue,
      requestedAt: DateTime.fromMillisecondsSinceEpoch(requestedAtMs),
    );
  }

  InterventionStage get interventionStage => InterventionStage.fromCode(stage);
}

class CanonicalMessageContext {
  final String language;
  final UserProfile profile;
  final AppSettings settings;
  final InterventionStage stage;
  final LockStatePayload lockState;
  final String? currentAppPackage;
  final String? currentAppName;
  final AppCategory appCategory;
  final EffectiveAppPolicy? effectivePolicy;
  final double riskScore;
  final int ignoredWarningCount;
  final bool focusModeActive;
  final List<Habit> pendingHabits;
  final int recentInterventionCount24h;
  final InterventionStage? lastInterventionStage;
  final int todayFocusMinutes;
  final String runtimeEventId;
  final String payloadSignature;

  const CanonicalMessageContext({
    required this.language,
    required this.profile,
    required this.settings,
    required this.stage,
    required this.lockState,
    required this.currentAppPackage,
    required this.currentAppName,
    required this.appCategory,
    required this.effectivePolicy,
    required this.riskScore,
    required this.ignoredWarningCount,
    required this.focusModeActive,
    required this.pendingHabits,
    required this.recentInterventionCount24h,
    required this.lastInterventionStage,
    required this.todayFocusMinutes,
    required this.runtimeEventId,
    required this.payloadSignature,
  });

  String? get primaryPendingHabitName =>
      pendingHabits.isEmpty ? null : pendingHabits.first.name;

  Map<String, dynamic> toStorageMap() => {
        'language': language,
        'stage': stage.code,
        'runtimeEventId': runtimeEventId,
        'payloadSignature': payloadSignature,
        'currentAppPackage': currentAppPackage,
        'currentAppName': currentAppName,
        'appCategory': appCategory.nativeValue,
        'riskScore': riskScore,
        'ignoredWarningCount': ignoredWarningCount,
        'focusModeActive': focusModeActive,
        'recentInterventionCount24h': recentInterventionCount24h,
        'lastInterventionStage': lastInterventionStage?.code,
        'todayFocusMinutes': todayFocusMinutes,
        'pendingHabitNames': pendingHabits.map((habit) => habit.name).toList(),
        'profile': {
          'identityStatement': profile.identityStatement,
          'primaryIdentity': profile.primaryIdentity,
          'breakTarget': profile.breakTarget,
          'emotionalTrigger': profile.emotionalTrigger,
          'messageStylePreference': profile.messageStylePreference,
          'interventionPreference': profile.interventionPreference,
          'strictnessPreference': profile.strictnessPreference,
          'selfControlScore': profile.selfControlScore,
          'currentXP': profile.currentXP,
          'notificationsEnabled': profile.notificationsEnabled,
        },
        'settings': {
          'systemSensitivity': settings.systemSensitivity,
          'escalationStrength': settings.escalationStrength,
          'notificationsEnabled': settings.notificationsEnabled,
        },
        'policy': effectivePolicy == null
            ? null
            : {
                'isBlocked': effectivePolicy!.isBlocked,
                'isExplicitlyAllowed': effectivePolicy!.isExplicitlyAllowed,
                'hasUsageLimit': effectivePolicy!.hasUsageLimit,
                'dailyLimitMinutes': effectivePolicy!.dailyLimitMinutes,
                'categoryOverride': effectivePolicy!.categoryOverride,
                'sourceTypes': effectivePolicy!.sourceTypes,
              },
        'lockState': lockState.toMap(),
      };

  String toStorageJson() => jsonEncode(toStorageMap());
}

class MessageHistoryEntry {
  final int? id;
  final String historyKey;
  final String runtimeEventId;
  final MessageSource source;
  final MessageRequestKind requestKind;
  final OutputChannel outputChannel;
  final InterventionStage stage;
  final String packageName;
  final String appName;
  final AppCategory appCategory;
  final String headline;
  final String body;
  final String? actionLabel;
  final String? recommendationTitle;
  final String? recommendationText;
  final String tone;
  final String language;
  final String deliveryStatus;
  final DateTime generatedAt;
  final DateTime? shownAt;
  final String contextJson;

  const MessageHistoryEntry({
    this.id,
    required this.historyKey,
    required this.runtimeEventId,
    required this.source,
    required this.requestKind,
    required this.outputChannel,
    required this.stage,
    required this.packageName,
    required this.appName,
    required this.appCategory,
    required this.headline,
    required this.body,
    this.actionLabel,
    this.recommendationTitle,
    this.recommendationText,
    required this.tone,
    required this.language,
    required this.deliveryStatus,
    required this.generatedAt,
    this.shownAt,
    required this.contextJson,
  });

  factory MessageHistoryEntry.fromRow(Map<String, dynamic> row) {
    return MessageHistoryEntry(
      id: row['id'] as int?,
      historyKey: row['history_key'] as String? ?? '',
      runtimeEventId: row['runtime_event_id'] as String? ?? '',
      source: MessageSource.fromStorage(row['source'] as String?),
      requestKind:
          MessageRequestKind.fromStorage(row['request_kind'] as String?),
      outputChannel: OutputChannel.values.firstWhere(
        (value) => value.name == row['output_channel'],
        orElse: () => OutputChannel.notification,
      ),
      stage: InterventionStage.fromCode(row['stage'] as int? ?? 0),
      packageName: row['package_name'] as String? ?? '',
      appName: row['app_name'] as String? ?? '',
      appCategory:
          AppCategory.fromNativeValue(row['app_category'] as int? ?? 1),
      headline: row['headline'] as String? ?? '',
      body: row['body'] as String? ?? '',
      actionLabel: row['action_label'] as String?,
      recommendationTitle: row['recommendation_title'] as String?,
      recommendationText: row['recommendation_text'] as String?,
      tone: row['tone'] as String? ?? '',
      language: row['language'] as String? ?? 'en',
      deliveryStatus: row['delivery_status'] as String? ?? 'generated',
      generatedAt: DateTime.fromMillisecondsSinceEpoch(
        row['generated_at'] as int? ?? 0,
      ),
      shownAt: (row['shown_at'] as int?) == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row['shown_at'] as int),
      contextJson: row['context_json'] as String? ?? '{}',
    );
  }

  Map<String, dynamic> toRow() => {
        'id': id,
        'history_key': historyKey,
        'runtime_event_id': runtimeEventId,
        'source': source.storageValue,
        'request_kind': requestKind.storageValue,
        'output_channel': outputChannel.name,
        'stage': stage.code,
        'package_name': packageName,
        'app_name': appName,
        'app_category': appCategory.nativeValue,
        'headline': headline,
        'body': body,
        'action_label': actionLabel,
        'recommendation_title': recommendationTitle,
        'recommendation_text': recommendationText,
        'tone': tone,
        'language': language,
        'delivery_status': deliveryStatus,
        'generated_at': generatedAt.millisecondsSinceEpoch,
        'shown_at': shownAt?.millisecondsSinceEpoch,
        'context_json': contextJson,
      };
}

class MessageFeedbackEntry {
  final int? id;
  final String historyKey;
  final MessageFeedbackType feedbackType;
  final String note;
  final DateTime createdAt;

  const MessageFeedbackEntry({
    this.id,
    required this.historyKey,
    required this.feedbackType,
    this.note = '',
    required this.createdAt,
  });

  factory MessageFeedbackEntry.fromRow(Map<String, dynamic> row) {
    return MessageFeedbackEntry(
      id: row['id'] as int?,
      historyKey: row['history_key'] as String? ?? '',
      feedbackType:
          MessageFeedbackType.fromStorage(row['feedback_type'] as String?),
      note: row['feedback_note'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row['created_at'] as int? ?? 0,
      ),
    );
  }

  Map<String, dynamic> toRow() => {
        'id': id,
        'history_key': historyKey,
        'feedback_type': feedbackType.storageValue,
        'feedback_note': note,
        'created_at': createdAt.millisecondsSinceEpoch,
      };
}

class CloudMessageRequest {
  final String historyKey;
  final MessageRequestKind requestKind;
  final MessageIntent intent;
  final OutputChannel outputChannel;
  final CanonicalMessageContext context;
  final GeneratedMessage localMessage;
  final RecommendationResult? recommendation;

  const CloudMessageRequest({
    required this.historyKey,
    required this.requestKind,
    required this.intent,
    required this.outputChannel,
    required this.context,
    required this.localMessage,
    required this.recommendation,
  });
}

class CloudMessageEnhancement {
  final String? headline;
  final String? body;
  final String? actionLabel;
  final String? tone;
  final String? recommendationTitle;
  final String? recommendationText;

  const CloudMessageEnhancement({
    this.headline,
    this.body,
    this.actionLabel,
    this.tone,
    this.recommendationTitle,
    this.recommendationText,
  });
}

class MessageCompositionResult {
  final String historyKey;
  final CanonicalMessageContext context;
  final GeneratedMessage message;
  final RecommendationResult? recommendation;
  final MessageSource source;

  const MessageCompositionResult({
    required this.historyKey,
    required this.context,
    required this.message,
    required this.recommendation,
    required this.source,
  });
}
