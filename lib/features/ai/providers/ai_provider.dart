import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/repositories/ai_chat_repository.dart';
import '../../../data/repositories/message_history_repository.dart';
import '../../../providers/habit_provider.dart';
import '../../../providers/locale_provider.dart';
import '../../../providers/system_provider.dart';
import '../domain/entities/ai_contexts.dart';
import '../domain/entities/ai_outputs.dart';
import '../domain/entities/chat_models.dart';
import '../domain/enums/output_channel.dart';
import '../services/ai_chat_service.dart';
import '../services/ai_cloud_provider.dart';
import '../services/chat_context_service.dart';
import '../services/cloud_message_enhancer.dart';
import '../services/local_first_messaging_service.dart';
import '../services/local_message_generator.dart';
import '../services/local_recommendation_engine.dart';
import '../services/message_context_service.dart';
import '../services/message_intent_resolver.dart';

// ── Dependency Providers ──
final localMessageGeneratorProvider = Provider<LocalMessageGenerator>((ref) {
  return LocalMessageGenerator();
});

final localRecommendationEngineProvider =
    Provider<LocalRecommendationEngine>((ref) {
  return LocalRecommendationEngine();
});

final messageHistoryRepositoryProvider = Provider<MessageHistoryRepository>(
  (ref) => MessageHistoryRepository(),
);

final aiChatRepositoryProvider = Provider<AIChatRepository>(
  (ref) => AIChatRepository(),
);

final messageContextServiceProvider = Provider<MessageContextService>(
  (ref) => MessageContextService(),
);

final chatContextServiceProvider = Provider<ChatContextService>(
  (ref) => ChatContextService(),
);

final messageIntentResolverProvider = Provider<MessageIntentResolver>(
  (ref) => const MessageIntentResolver(),
);

final aiCloudProviderConfigProvider = Provider<AICloudProviderConfig>(
  (ref) => AICloudProviderConfig.fromEnvironment(),
);

final aiCloudProviderServiceProvider = Provider<AICloudProvider>((ref) {
  final config = ref.read(aiCloudProviderConfigProvider);
  if (config.usesFirebaseAI) {
    return FirebaseAICloudProvider(config);
  }

  return OpenRouterCompatibleAICloudProvider(config);
});

final cloudMessageEnhancerProvider = Provider<CloudMessageEnhancer>((ref) {
  // ── DISABLED: Cloud enhancement for escalation/intervention messages ──
  // Runtime interventions, habit reminders, and recommendations are local.
  // Cloud calls are reserved for user-initiated AI Chat only.
  return const NoOpCloudMessageEnhancer();
});

final localFirstMessagingServiceProvider = Provider<LocalFirstMessagingService>(
  (ref) {
    return LocalFirstMessagingService(
      contextService: ref.read(messageContextServiceProvider),
      historyRepository: ref.read(messageHistoryRepositoryProvider),
      localMessageGenerator: ref.read(localMessageGeneratorProvider),
      localRecommendationEngine: ref.read(localRecommendationEngineProvider),
      cloudMessageEnhancer: ref.read(cloudMessageEnhancerProvider),
      intentResolver: ref.read(messageIntentResolverProvider),
    );
  },
);

final aiChatServiceProvider = Provider<AIChatService>((ref) {
  return AIChatService(
    repository: ref.read(aiChatRepositoryProvider),
    contextService: ref.read(chatContextServiceProvider),
    cloudProvider: ref.read(aiCloudProviderServiceProvider),
  );
});

final aiChatControllerProvider =
    StateNotifierProvider<AIChatController, AIChatState>((ref) {
  return AIChatController(
    chatService: ref.read(aiChatServiceProvider),
    repository: ref.read(aiChatRepositoryProvider),
  );
});

// ── Context Builders ──

/// Composes the current MessageContext instantly across domain services.
final messageContextBuilderProvider = Provider<MessageContext>((ref) {
  final systemState = ref.watch(systemProvider);
  final locale = ref.watch(localeProvider);

  return MessageContext(
    currentLanguage: locale.languageCode,
    profile: systemState.profile,
    currentStage: systemState.escalationLevel,
    distractionScore: systemState.distractionScore,
    focusModeActive: systemState.nativeState.focusModeActive,
    currentAppPackage: systemState.nativeState.currentAppPackage,
    recentInterventionCount24h: 0,
    todayFocusMinutes: 0,
    currentXP: systemState.profile.currentXP,
    selfControlScore: systemState.profile.selfControlScore,
    strictnessPreference: systemState.profile.strictnessPreference,
  );
});

/// Composes the current RecommendationContext instantly across domain services.
final recommendationContextBuilderProvider =
    Provider<RecommendationContext>((ref) {
  final systemState = ref.watch(systemProvider);
  final habitState = ref.watch(habitProvider);
  final pending = habitState.habits.where((h) => !h.completedToday).toList();
  final locale = ref.watch(localeProvider);

  return RecommendationContext(
    currentLanguage: locale.languageCode,
    profile: systemState.profile,
    timeOfDay: DateTime.now(),
    pendingHabits: pending,
    currentStage: systemState.escalationLevel,
    currentAppPackage: systemState.nativeState.currentAppPackage,
    currentAppName: systemState.nativeState.currentAppPackage,
  );
});

final aiSystemMessageProvider = FutureProvider<GeneratedMessage>((ref) async {
  final generator = ref.watch(localMessageGeneratorProvider);
  final context = ref.watch(messageContextBuilderProvider);
  return generator.generateMessage(context, OutputChannel.floatingCard);
});

final aiRecommendationProvider =
    FutureProvider<RecommendationResult>((ref) async {
  final engine = ref.watch(localRecommendationEngineProvider);
  final context = ref.watch(recommendationContextBuilderProvider);
  return engine.getBestAction(context);
});

class AIChatState {
  final bool isLoading;
  final bool isSending;
  final AIChatThread? thread;
  final List<AIChatMessage> messages;
  final List<AIChatThread> allThreads;
  final bool cloudConfigured;
  final String? lastError;
  /// Accumulated text from streaming response (null when not streaming).
  final String? streamingText;

  const AIChatState({
    this.isLoading = true,
    this.isSending = false,
    this.thread,
    this.messages = const [],
    this.allThreads = const [],
    this.cloudConfigured = false,
    this.lastError,
    this.streamingText,
  });

  AIChatState copyWith({
    bool? isLoading,
    bool? isSending,
    AIChatThread? thread,
    List<AIChatMessage>? messages,
    List<AIChatThread>? allThreads,
    bool? cloudConfigured,
    String? lastError,
    String? streamingText,
    bool clearError = false,
    bool clearStreaming = false,
  }) {
    return AIChatState(
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      thread: thread ?? this.thread,
      messages: messages ?? this.messages,
      allThreads: allThreads ?? this.allThreads,
      cloudConfigured: cloudConfigured ?? this.cloudConfigured,
      lastError: clearError ? null : (lastError ?? this.lastError),
      streamingText:
          clearStreaming ? null : (streamingText ?? this.streamingText),
    );
  }
}

class AIChatController extends StateNotifier<AIChatState> {
  static const _uuid = Uuid();

  final AIChatService _chatService;
  final AIChatRepository _repository;
  Future<void>? _loadingFuture;

  AIChatController({
    required AIChatService chatService,
    required AIChatRepository repository,
  })  : _chatService = chatService,
        _repository = repository,
        super(AIChatState(cloudConfigured: chatService.cloudConfigured)) {
    _loadingFuture = _loadSession();
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isSending) return;
    if (_loadingFuture != null) {
      await _loadingFuture;
    }
    final thread = state.thread;
    if (thread == null) return;

    final optimisticUser = AIChatMessage(
      id: _uuid.v4(),
      threadId: thread.id,
      role: AIChatRole.user,
      body: trimmed,
      source: AIChatMessageSource.local,
      createdAt: DateTime.now(),
    );

    state = state.copyWith(
      isSending: true,
      messages: [...state.messages, optimisticUser],
      clearError: true,
      clearStreaming: true,
    );

    try {
      final persistedHistory = state.messages
          .where((message) => message.id != optimisticUser.id)
          .toList();
      final session = await _chatService.sendMessageStreaming(
        thread: thread,
        text: trimmed,
        visibleHistory: persistedHistory,
        onChunk: (accumulated) {
          // Update streaming text in real-time
          state = state.copyWith(streamingText: accumulated);
        },
      );
      final threads = await _repository.getRecentThreads(limit: 50);
      state = state.copyWith(
        isSending: false,
        thread: session.thread,
        messages: session.messages,
        allThreads: threads,
        cloudConfigured: _chatService.cloudConfigured,
        clearError: true,
        clearStreaming: true,
      );
    } catch (error) {
      final session = await _chatService.loadOrCreateLatestSession();
      state = state.copyWith(
        isSending: false,
        thread: session.thread,
        messages: session.messages,
        cloudConfigured: _chatService.cloudConfigured,
        lastError: error.toString(),
        clearStreaming: true,
      );
    }
  }

  /// Returns the body text of the last user message (for retry/edit).
  String? get lastUserMessageText {
    try {
      return state.messages
          .lastWhere((m) => m.role == AIChatRole.user)
          .body;
    } catch (_) {
      return null;
    }
  }

  /// Create a brand new chat thread.
  Future<void> createNewThread() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // Force new session by creating a fresh thread
      final session = await _chatService.loadOrCreateLatestSession();
      // Create new thread on top
      final now = DateTime.now();
      final newThread = AIChatThread(
        id: _uuid.v4(),
        title: '',
        language: session.thread.language,
        lastPreview: '',
        createdAt: now,
        updatedAt: now,
      );
      await _repository.saveThread(newThread);
      final freshSession = await _chatService.loadOrCreateLatestSession();
      final threads = await _repository.getRecentThreads(limit: 50);
      state = state.copyWith(
        isLoading: false,
        thread: freshSession.thread,
        messages: freshSession.messages,
        allThreads: threads,
        cloudConfigured: _chatService.cloudConfigured,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        lastError: error.toString(),
      );
    }
  }

  /// Switch to an existing thread.
  Future<void> switchToThread(String threadId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final threads = await _repository.getRecentThreads(limit: 50);
      final target = threads.firstWhere((t) => t.id == threadId);
      final messages = await _repository.getMessagesForThread(threadId);
      state = state.copyWith(
        isLoading: false,
        thread: target,
        messages: messages,
        allThreads: threads,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        lastError: error.toString(),
      );
    }
  }

  /// Delete a thread.
  Future<void> deleteThread(String threadId) async {
    try {
      await _repository.deleteThread(threadId);
      final isCurrentThread = state.thread?.id == threadId;
      if (isCurrentThread) {
        await _loadSession();
      } else {
        final threads = await _repository.getRecentThreads(limit: 50);
        state = state.copyWith(allThreads: threads);
      }
    } catch (error) {
      state = state.copyWith(lastError: error.toString());
    }
  }

  Future<void> _loadSession() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      var session = await _chatService.loadOrCreateLatestSession();

      // One-time migration: clean up old local-only welcome messages.
      // If the current thread has exactly 1 message and it's a local
      // assistant message, it's the old welcome. Delete it for a fresh start.
      if (session.messages.length == 1 &&
          session.messages.first.role == AIChatRole.assistant &&
          session.messages.first.source == AIChatMessageSource.local) {
        await _repository.deleteThread(session.thread.id);
        session = await _chatService.loadOrCreateLatestSession();
      }

      final threads = await _repository.getRecentThreads(limit: 50);
      state = state.copyWith(
        isLoading: false,
        thread: session.thread,
        messages: session.messages,
        allThreads: threads,
        cloudConfigured: _chatService.cloudConfigured,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        cloudConfigured: _chatService.cloudConfigured,
        lastError: error.toString(),
      );
    }
  }
}
