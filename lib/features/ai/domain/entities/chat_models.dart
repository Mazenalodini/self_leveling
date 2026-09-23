import 'dart:convert';

import '../../../../domain/contracts/runtime_contract.dart';
import '../../../../domain/entities/app_settings.dart';
import '../../../../domain/entities/user_profile.dart';

enum AIChatRole {
  user('user'),
  assistant('assistant');

  final String storageValue;

  const AIChatRole(this.storageValue);

  static AIChatRole fromStorage(String? value) {
    return AIChatRole.values.firstWhere(
      (item) => item.storageValue == value,
      orElse: () => AIChatRole.assistant,
    );
  }
}

enum AIChatMessageSource {
  local('local'),
  cloud('cloud');

  final String storageValue;

  const AIChatMessageSource(this.storageValue);

  static AIChatMessageSource fromStorage(String? value) {
    return AIChatMessageSource.values.firstWhere(
      (item) => item.storageValue == value,
      orElse: () => AIChatMessageSource.local,
    );
  }
}

enum AIChatMessageStatus {
  complete('complete'),
  failed('failed');

  final String storageValue;

  const AIChatMessageStatus(this.storageValue);

  static AIChatMessageStatus fromStorage(String? value) {
    return AIChatMessageStatus.values.firstWhere(
      (item) => item.storageValue == value,
      orElse: () => AIChatMessageStatus.complete,
    );
  }
}

class AIChatThread {
  final String id;
  final String title;
  final String language;
  final String lastPreview;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AIChatThread({
    required this.id,
    required this.title,
    required this.language,
    required this.lastPreview,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AIChatThread.fromRow(Map<String, dynamic> row) {
    return AIChatThread(
      id: row['id'] as String? ?? '',
      title: row['title'] as String? ?? '',
      language: row['language'] as String? ?? 'en',
      lastPreview: row['last_preview'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row['created_at'] as int? ?? 0,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row['updated_at'] as int? ?? 0,
      ),
    );
  }

  Map<String, dynamic> toRow() => {
        'id': id,
        'title': title,
        'language': language,
        'last_preview': lastPreview,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  AIChatThread copyWith({
    String? id,
    String? title,
    String? language,
    String? lastPreview,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AIChatThread(
      id: id ?? this.id,
      title: title ?? this.title,
      language: language ?? this.language,
      lastPreview: lastPreview ?? this.lastPreview,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class AIChatMessage {
  final String id;
  final String threadId;
  final AIChatRole role;
  final String body;
  final AIChatMessageSource source;
  final String? providerName;
  final String? modelName;
  final AIChatMessageStatus status;
  final DateTime createdAt;
  final String contextJson;
  final String? errorText;

  const AIChatMessage({
    required this.id,
    required this.threadId,
    required this.role,
    required this.body,
    required this.source,
    this.providerName,
    this.modelName,
    this.status = AIChatMessageStatus.complete,
    required this.createdAt,
    this.contextJson = '{}',
    this.errorText,
  });

  bool get isUser => role == AIChatRole.user;

  Map<String, dynamic> get contextMap {
    try {
      return jsonDecode(contextJson) as Map<String, dynamic>;
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  factory AIChatMessage.fromRow(Map<String, dynamic> row) {
    return AIChatMessage(
      id: row['id'] as String? ?? '',
      threadId: row['thread_id'] as String? ?? '',
      role: AIChatRole.fromStorage(row['role'] as String?),
      body: row['body'] as String? ?? '',
      source: AIChatMessageSource.fromStorage(row['source'] as String?),
      providerName: row['provider_name'] as String?,
      modelName: row['model_name'] as String?,
      status: AIChatMessageStatus.fromStorage(row['status'] as String?),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row['created_at'] as int? ?? 0,
      ),
      contextJson: row['context_json'] as String? ?? '{}',
      errorText: row['error_text'] as String?,
    );
  }

  Map<String, dynamic> toRow() => {
        'id': id,
        'thread_id': threadId,
        'role': role.storageValue,
        'body': body,
        'source': source.storageValue,
        'provider_name': providerName,
        'model_name': modelName,
        'status': status.storageValue,
        'created_at': createdAt.millisecondsSinceEpoch,
        'context_json': contextJson,
        'error_text': errorText,
      };

  AIChatMessage copyWith({
    String? id,
    String? threadId,
    AIChatRole? role,
    String? body,
    AIChatMessageSource? source,
    String? providerName,
    String? modelName,
    AIChatMessageStatus? status,
    DateTime? createdAt,
    String? contextJson,
    String? errorText,
  }) {
    return AIChatMessage(
      id: id ?? this.id,
      threadId: threadId ?? this.threadId,
      role: role ?? this.role,
      body: body ?? this.body,
      source: source ?? this.source,
      providerName: providerName ?? this.providerName,
      modelName: modelName ?? this.modelName,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      contextJson: contextJson ?? this.contextJson,
      errorText: errorText ?? this.errorText,
    );
  }
}

class AIChatSession {
  final AIChatThread thread;
  final List<AIChatMessage> messages;

  const AIChatSession({
    required this.thread,
    required this.messages,
  });
}

class CanonicalChatContext {
  final String language;
  final UserProfile profile;
  final AppSettings settings;
  final InterventionStage currentStage;
  final LockStatePayload lockState;
  final bool focusModeActive;
  final double distractionScore;
  final String? currentAppPackage;
  final String? currentAppName;
  final String? topDistractingAppName;
  final int recentInterventionCount24h;
  final InterventionStage? lastInterventionStage;
  final List<String> recentInterventionSummaries;
  final List<String> pendingHabitNames;
  final int completedHabitsToday;
  final int totalHabits;
  final int todayFocusMinutes;
  final int todayCompletedFocusSessions;

  const CanonicalChatContext({
    required this.language,
    required this.profile,
    required this.settings,
    required this.currentStage,
    required this.lockState,
    required this.focusModeActive,
    required this.distractionScore,
    required this.currentAppPackage,
    required this.currentAppName,
    required this.topDistractingAppName,
    required this.recentInterventionCount24h,
    required this.lastInterventionStage,
    required this.recentInterventionSummaries,
    required this.pendingHabitNames,
    required this.completedHabitsToday,
    required this.totalHabits,
    required this.todayFocusMinutes,
    required this.todayCompletedFocusSessions,
  });

  Map<String, dynamic> toStorageMap() => {
        'language': language,
        'currentStage': currentStage.code,
        'focusModeActive': focusModeActive,
        'distractionScore': distractionScore,
        'currentAppPackage': currentAppPackage,
        'currentAppName': currentAppName,
        'topDistractingAppName': topDistractingAppName,
        'recentInterventionCount24h': recentInterventionCount24h,
        'lastInterventionStage': lastInterventionStage?.code,
        'recentInterventionSummaries': recentInterventionSummaries,
        'pendingHabitNames': pendingHabitNames,
        'completedHabitsToday': completedHabitsToday,
        'totalHabits': totalHabits,
        'todayFocusMinutes': todayFocusMinutes,
        'todayCompletedFocusSessions': todayCompletedFocusSessions,
        'profile': {
          'displayName': profile.displayName,
          'identityStatement': profile.identityStatement,
          'primaryIdentity': profile.primaryIdentity,
          'breakTarget': profile.breakTarget,
          'strictnessPreference': profile.strictnessPreference,
          'messageStylePreference': profile.messageStylePreference,
          'interventionPreference': profile.interventionPreference,
          'currentXP': profile.currentXP,
          'totalXPEarned': profile.totalXPEarned,
          'level': profile.level,
          'selfControlScore': profile.selfControlScore,
          'targetHabits': profile.targetHabits,
        },
        'settings': {
          'systemSensitivity': settings.systemSensitivity,
          'escalationStrength': settings.escalationStrength,
          'warningDelayMinutes': settings.warningDelayMinutes,
          'overlayDurationMinutes': settings.overlayDurationMinutes,
          'hardLockDurationMinutes': settings.hardLockDurationMinutes,
        },
        'lockState': lockState.toMap(),
      };

  String toStorageJson() => jsonEncode(toStorageMap());

  Map<String, dynamic> toPromptFacts() => {
        'userName': profile.displayName,
        'language': language,
        'identityStatement': profile.identityStatement,
        'primaryIdentity': profile.primaryIdentity,
        'targetHabits': profile.targetHabits,
        'breakTarget': profile.breakTarget,
        'strictnessPreference': profile.strictnessPreference,
        'messageStylePreference': profile.messageStylePreference,
        'interventionPreference': profile.interventionPreference,
        'level': profile.level,
        'currentXP': profile.currentXP,
        'totalXPEarned': profile.totalXPEarned,
        'selfControlScore': profile.selfControlScore,
        'systemSensitivity': settings.systemSensitivity,
        'escalationStrength': settings.escalationStrength,
        'currentStage': currentStage.displayName,
        'focusModeActive': focusModeActive,
        'distractionScore': distractionScore,
        'currentAppPackage': currentAppPackage,
        'currentAppName': currentAppName,
        'topDistractingAppName': topDistractingAppName,
        'recentInterventionCount24h': recentInterventionCount24h,
        'lastInterventionStage': lastInterventionStage?.displayName,
        'recentInterventionSummaries': recentInterventionSummaries,
        'pendingHabitNames': pendingHabitNames,
        'completedHabitsToday': completedHabitsToday,
        'totalHabits': totalHabits,
        'todayFocusMinutes': todayFocusMinutes,
        'todayCompletedFocusSessions': todayCompletedFocusSessions,
        'lockState': lockState.toMap(),
      };
}

class CloudChatRequest {
  final String threadId;
  final String userMessage;
  final List<AIChatMessage> conversationHistory;
  final CanonicalChatContext context;

  const CloudChatRequest({
    required this.threadId,
    required this.userMessage,
    required this.conversationHistory,
    required this.context,
  });
}

class AIChatReply {
  final String text;
  final AIChatMessageSource source;
  final String? providerName;
  final String? modelName;
  final String contextJson;
  final String? errorText;

  const AIChatReply({
    required this.text,
    required this.source,
    this.providerName,
    this.modelName,
    required this.contextJson,
    this.errorText,
  });
}
