import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../../data/repositories/ai_chat_repository.dart';
import '../domain/entities/chat_models.dart';
import 'ai_cloud_provider.dart';
import 'chat_context_service.dart';
import 'chat_guard.dart';

class AIChatService {
  static const _uuid = Uuid();

  final AIChatRepository _repository;
  final ChatContextService _contextService;
  final AICloudProvider _cloudProvider;
  final ChatGuard _guard;

  AIChatService({
    required AIChatRepository repository,
    required ChatContextService contextService,
    required AICloudProvider cloudProvider,
    ChatGuard guard = const ChatGuard(),
  })  : _repository = repository,
        _contextService = contextService,
        _cloudProvider = cloudProvider,
        _guard = guard;

  bool get cloudConfigured => _cloudProvider.isConfigured;

  Future<AIChatSession> loadOrCreateLatestSession() async {
    final latest = await _repository.getLatestThread();
    if (latest != null) {
      final messages = await _repository.getMessagesForThread(latest.id);
      return AIChatSession(thread: latest, messages: messages);
    }

    // The user starts the conversation; no cloud call happens on screen open.
    final context = await _contextService.buildContext();
    final now = DateTime.now();
    final thread = AIChatThread(
      id: _uuid.v4(),
      title: _defaultThreadTitle(context.language),
      language: context.language,
      lastPreview: '',
      createdAt: now,
      updatedAt: now,
    );
    await _repository.saveThread(thread);
    return AIChatSession(thread: thread, messages: const []);
  }

  Future<AIChatSession> sendMessage({
    required AIChatThread thread,
    required String text,
    required List<AIChatMessage> visibleHistory,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return AIChatSession(thread: thread, messages: visibleHistory);
    }

    // ── Input Guard: validate against prompt injection attacks ──
    final inputCheck = _guard.validateInput(trimmed);
    if (!inputCheck.allowed) {
      debugPrint('[AI] Input blocked: ${inputCheck.rejectionReason}');
      final context = await _contextService.buildContext();
      final now = DateTime.now();

      // Save the user message (so they see what they typed)
      final userMessage = AIChatMessage(
        id: _uuid.v4(),
        threadId: thread.id,
        role: AIChatRole.user,
        body: trimmed,
        source: AIChatMessageSource.local,
        createdAt: now,
        contextJson: '{}',
      );
      await _repository.saveMessage(userMessage);

      // Return a friendly redirection (not revealing why it was blocked)
      final guardReply = AIChatMessage(
        id: _uuid.v4(),
        threadId: thread.id,
        role: AIChatRole.assistant,
        body: ChatGuard.rejectionMessage(
          inputCheck.rejectionReason ?? 'unknown',
          context.language,
        ),
        source: AIChatMessageSource.local,
        createdAt: DateTime.now(),
        contextJson: '{}',
      );
      await _repository.saveMessage(guardReply);

      final messages = await _repository.getMessagesForThread(thread.id);
      return AIChatSession(thread: thread, messages: messages);
    }

    final context = await _contextService.buildContext();
    final now = DateTime.now();
    final userMessage = AIChatMessage(
      id: _uuid.v4(),
      threadId: thread.id,
      role: AIChatRole.user,
      body: trimmed,
      source: AIChatMessageSource.local,
      createdAt: now,
      contextJson: '{}',
    );
    await _repository.saveMessage(userMessage);

    final normalizedThread = _normalizeThreadTitle(
      thread: thread,
      message: trimmed,
      updatedAt: now,
    );
    await _repository.saveThread(normalizedThread);

    final history = [...visibleHistory, userMessage];
    final reply = await _resolveReply(
      threadId: thread.id,
      text: trimmed,
      history: history,
      context: context,
    );

    final assistantMessage = AIChatMessage(
      id: _uuid.v4(),
      threadId: thread.id,
      role: AIChatRole.assistant,
      body: reply.text,
      source: reply.source,
      providerName: reply.providerName,
      modelName: reply.modelName,
      createdAt: DateTime.now(),
      contextJson: reply.contextJson,
      errorText: reply.errorText,
    );
    await _repository.saveMessage(assistantMessage);

    final updatedThread = normalizedThread.copyWith(
      lastPreview: _buildPreview(assistantMessage.body),
      updatedAt: assistantMessage.createdAt,
    );
    await _repository.updateThreadPreview(
      threadId: updatedThread.id,
      title: updatedThread.title,
      lastPreview: updatedThread.lastPreview,
      updatedAt: updatedThread.updatedAt,
    );

    final messages = await _repository.getMessagesForThread(updatedThread.id);
    return AIChatSession(thread: updatedThread, messages: messages);
  }

  /// Streaming variant — calls [onChunk] with accumulated text as it arrives.
  /// Returns the final session once complete.
  Future<AIChatSession> sendMessageStreaming({
    required AIChatThread thread,
    required String text,
    required List<AIChatMessage> visibleHistory,
    required void Function(String accumulatedText) onChunk,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return AIChatSession(thread: thread, messages: visibleHistory);
    }

    // ── Input Guard ──
    final inputCheck = _guard.validateInput(trimmed);
    if (!inputCheck.allowed) {
      debugPrint('[AI] Input blocked: ${inputCheck.rejectionReason}');
      final context = await _contextService.buildContext();
      final now = DateTime.now();

      final userMessage = AIChatMessage(
        id: _uuid.v4(),
        threadId: thread.id,
        role: AIChatRole.user,
        body: trimmed,
        source: AIChatMessageSource.local,
        createdAt: now,
        contextJson: '{}',
      );
      await _repository.saveMessage(userMessage);

      final guardReply = AIChatMessage(
        id: _uuid.v4(),
        threadId: thread.id,
        role: AIChatRole.assistant,
        body: ChatGuard.rejectionMessage(
          inputCheck.rejectionReason ?? 'unknown',
          context.language,
        ),
        source: AIChatMessageSource.local,
        createdAt: DateTime.now(),
        contextJson: '{}',
      );
      await _repository.saveMessage(guardReply);

      final messages = await _repository.getMessagesForThread(thread.id);
      return AIChatSession(thread: thread, messages: messages);
    }

    final context = await _contextService.buildContext();
    final now = DateTime.now();
    final userMessage = AIChatMessage(
      id: _uuid.v4(),
      threadId: thread.id,
      role: AIChatRole.user,
      body: trimmed,
      source: AIChatMessageSource.local,
      createdAt: now,
      contextJson: '{}',
    );
    await _repository.saveMessage(userMessage);

    final normalizedThread = _normalizeThreadTitle(
      thread: thread,
      message: trimmed,
      updatedAt: now,
    );
    await _repository.saveThread(normalizedThread);

    final history = [...visibleHistory, userMessage];
    String finalText = '';

    try {
      if (_cloudProvider.isConfigured) {
        final request = CloudChatRequest(
          threadId: thread.id,
          userMessage: trimmed,
          conversationHistory: history,
          context: context,
        );

        await for (final accumulated
            in _cloudProvider.generateChatReplyStream(request)) {
          finalText = accumulated;
          onChunk(accumulated);
        }

        // ── Output Guard ──
        final outputCheck =
            _guard.validateOutput(finalText, context.language);
        if (!outputCheck.allowed) {
          finalText = ChatGuard.rejectionMessage(
            outputCheck.rejectionReason ?? 'unknown',
            context.language,
          );
        }
      } else {
        finalText = context.language == 'ar'
            ? 'الذكاء الاصطناعي غير متصل. تأكد من الإنترنت وإعدادات مزود الذكاء الاصطناعي.'
            : 'AI Chat is offline. Check your internet connection.';
      }
    } catch (e) {
      debugPrint('[AI] Streaming error: $e');
      finalText = context.language == 'ar'
          ? 'حدث خطأ أثناء الاتصال بالذكاء الاصطناعي. حاول مرة أخرى.'
          : 'An error occurred while connecting to AI. Please try again.';
    }

    final assistantMessage = AIChatMessage(
      id: _uuid.v4(),
      threadId: thread.id,
      role: AIChatRole.assistant,
      body: finalText.trim(),
      source: AIChatMessageSource.cloud,
      createdAt: DateTime.now(),
      contextJson: context.toStorageJson(),
    );
    await _repository.saveMessage(assistantMessage);

    final updatedThread = normalizedThread.copyWith(
      lastPreview: _buildPreview(assistantMessage.body),
      updatedAt: assistantMessage.createdAt,
    );
    await _repository.updateThreadPreview(
      threadId: updatedThread.id,
      title: updatedThread.title,
      lastPreview: updatedThread.lastPreview,
      updatedAt: updatedThread.updatedAt,
    );

    final messages = await _repository.getMessagesForThread(updatedThread.id);
    return AIChatSession(thread: updatedThread, messages: messages);
  }

  Future<AIChatReply> _resolveReply({
    required String threadId,
    required String text,
    required List<AIChatMessage> history,
    required CanonicalChatContext context,
  }) async {
    final request = CloudChatRequest(
      threadId: threadId,
      userMessage: text,
      conversationHistory: history,
      context: context,
    );

    debugPrint('[AI] isConfigured=${_cloudProvider.isConfigured} '
        'provider=${_cloudProvider.providerName} '
        'model=${_cloudProvider.modelName}');

    try {
      if (_cloudProvider.isConfigured) {
        debugPrint('[AI] Calling chat cloud provider...');
        final reply = await _cloudProvider.generateChatReply(request);
        debugPrint(
          '[AI] Chat provider responded: '
          '${reply.text.substring(0, reply.text.length.clamp(0, 80))}...',
        );

        // ── Output Guard: validate AI response for leakage ──
        final outputCheck = _guard.validateOutput(reply.text, context.language);
        if (!outputCheck.allowed) {
          debugPrint('[AI] Output blocked: ${outputCheck.rejectionReason}');
          return AIChatReply(
            text: ChatGuard.rejectionMessage(
              outputCheck.rejectionReason ?? 'unknown',
              context.language,
            ),
            source: AIChatMessageSource.cloud,
            providerName: reply.providerName,
            modelName: reply.modelName,
            contextJson: reply.contextJson,
            errorText: 'output_guard_blocked',
          );
        }

        return reply;
      }

      debugPrint('[AI] Provider not configured; chat cloud is unavailable');
      debugPrint(
        '[AI] Hint: enable Firebase AI Logic or launch with '
        '--dart-define-from-file=.env/ai_chat.json.',
      );
      return _cloudErrorReply(
        context: context,
        message: context.language == 'ar'
            ? 'الذكاء الاصطناعي غير متصل. تأكد من الإنترنت وإعدادات مزود الذكاء الاصطناعي.'
            : 'AI Chat is offline. Check your internet connection and AI provider configuration.',
        errorText: 'provider_not_configured',
      );
    } on AICloudUnavailableException catch (error) {
      debugPrint('[AI] Cloud unavailable: ${error.message}');
      return _cloudErrorReply(
        context: context,
        message: _messageForCloudError(context.language, error.message),
        errorText: error.message,
      );
    } on SocketException catch (error) {
      debugPrint('[AI] Network error: ${error.message}');
      return _cloudErrorReply(
        context: context,
        message: 'Network error: ${error.message}',
        errorText: error.message,
      );
    } on HttpException catch (error) {
      debugPrint('[AI] HTTP error: ${error.message}');
      return _cloudErrorReply(
        context: context,
        message: 'API error: ${error.message}',
        errorText: error.message,
      );
    } catch (error, stack) {
      debugPrint('[AI] Unexpected error: $error');
      debugPrint('[AI] Stack: $stack');
      return _cloudErrorReply(
        context: context,
        message: 'AI Chat error: $error',
        errorText: error.toString(),
      );
    }
  }

  AIChatReply _cloudErrorReply({
    required CanonicalChatContext context,
    required String message,
    required String errorText,
  }) {
    return AIChatReply(
      text: message,
      source: AIChatMessageSource.cloud,
      contextJson: context.toStorageJson(),
      errorText: errorText,
    );
  }

  String _messageForCloudError(String language, String error) {
    final isAr = language == 'ar';
    switch (error) {
      case 'rate_limited':
        return isAr
            ? 'عدد الطلبات كثير الآن. انتظر دقيقة ثم حاول مرة أخرى.'
            : 'Too many requests right now. Wait a minute and try again.';
      case 'invalid_api_key':
        return isAr
            ? 'مفتاح مزود الذكاء الاصطناعي غير صالح أو غير مفعل.'
            : 'The AI provider API key is invalid or inactive.';
      case 'timeout':
        return isAr
            ? 'انتهت مهلة الاتصال. حاول مرة أخرى.'
            : 'Connection timed out. Please try again.';
      case 'service_api_not_enabled':
        return isAr
            ? 'Firebase AI Logic غير مفعل لهذا المشروع. فعله من Firebase Console ثم حاول مرة أخرى.'
            : 'Firebase AI Logic is not enabled for this project. Enable it in Firebase Console and try again.';
      case 'unsupported_location':
        return isAr
            ? 'خدمة Firebase AI Logic غير متاحة من موقعك الحالي.'
            : 'Firebase AI Logic is not available from your current location.';
      case 'empty_response':
        return isAr
            ? 'لم يصل رد من نموذج الذكاء الاصطناعي. حاول مرة أخرى.'
            : 'The AI model returned an empty response. Please try again.';
      default:
        return isAr
            ? 'الدردشة غير متاحة حاليًا من مزود الذكاء الاصطناعي.'
            : 'AI Chat is currently unavailable from the configured AI provider.';
    }
  }

  AIChatThread _normalizeThreadTitle({
    required AIChatThread thread,
    required String message,
    required DateTime updatedAt,
  }) {
    final currentTitle = thread.title.trim();
    final defaultTitle = _defaultThreadTitle(thread.language);
    final shouldReplace = currentTitle.isEmpty || currentTitle == defaultTitle;
    final nextTitle = shouldReplace ? _shortTitle(message) : currentTitle;
    return thread.copyWith(
      title: nextTitle,
      updatedAt: updatedAt,
    );
  }

  String _shortTitle(String value) {
    final trimmed = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (trimmed.length <= 42) return trimmed;
    return '${trimmed.substring(0, 42).trim()}...';
  }

  String _buildPreview(String value) {
    final trimmed = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (trimmed.length <= 80) return trimmed;
    return '${trimmed.substring(0, 80).trim()}...';
  }

  String _defaultThreadTitle(String language) {
    return language == 'ar' ? 'محادثة جديدة' : 'New chat';
  }
}
