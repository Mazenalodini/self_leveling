import 'package:flutter_test/flutter_test.dart';
import 'package:self_leveling/domain/contracts/runtime_contract.dart';
import 'package:self_leveling/domain/entities/app_settings.dart';
import 'package:self_leveling/domain/entities/user_profile.dart';
import 'package:self_leveling/features/ai/domain/entities/chat_models.dart';
import 'package:self_leveling/features/ai/domain/entities/messaging_models.dart';
import 'package:self_leveling/features/ai/services/ai_chat_service.dart';
import 'package:self_leveling/features/ai/services/ai_cloud_provider.dart';
import 'package:self_leveling/features/ai/services/chat_context_service.dart';
import 'package:self_leveling/data/repositories/ai_chat_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loadOrCreateLatestSession creates an empty chat session', () async {
    final repository = _FakeAIChatRepository();
    final service = AIChatService(
      repository: repository,
      contextService: _FakeChatContextService(),
      cloudProvider: const _UnavailableCloudProvider(),
    );

    final session = await service.loadOrCreateLatestSession();

    expect(session.thread.id, isNotEmpty);
    expect(session.messages, isEmpty);
  });

  test('sendMessage uses cloud reply when provider is configured', () async {
    final repository = _FakeAIChatRepository();
    final service = AIChatService(
      repository: repository,
      contextService: _FakeChatContextService(),
      cloudProvider: const _CloudReplyProvider(),
    );

    final initial = await service.loadOrCreateLatestSession();
    final session = await service.sendMessage(
      thread: initial.thread,
      text: 'How am I doing today?',
      visibleHistory: initial.messages,
    );

    expect(session.messages.last.role, AIChatRole.assistant);
    expect(session.messages.last.source, AIChatMessageSource.cloud);
    expect(session.messages.last.body, 'Cloud grounded reply');
    expect(session.thread.lastPreview, contains('Cloud grounded reply'));
  });

  test('sendMessage returns a chat cloud error when provider is unavailable',
      () async {
    final repository = _FakeAIChatRepository();
    final service = AIChatService(
      repository: repository,
      contextService: _FakeChatContextService(),
      cloudProvider: const _UnavailableCloudProvider(),
    );

    final initial = await service.loadOrCreateLatestSession();
    final session = await service.sendMessage(
      thread: initial.thread,
      text: 'What should I focus on?',
      visibleHistory: initial.messages,
    );

    expect(session.messages.last.role, AIChatRole.assistant);
    expect(session.messages.last.source, AIChatMessageSource.cloud);
    expect(session.messages.last.body, isNotEmpty);
    expect(session.messages.last.errorText, 'provider_not_configured');
  });
}

class _FakeChatContextService extends ChatContextService {
  @override
  Future<CanonicalChatContext> buildContext() async {
    final profile = UserProfile.create(displayName: 'User').copyWith(
      surveyLanguage: 'en',
      primaryIdentity: 'disciplined',
      targetHabits: const ['read', 'train'],
      currentXP: 120,
      totalXPEarned: 240,
      level: 2,
      selfControlScore: 61,
    );
    return CanonicalChatContext(
      language: 'en',
      profile: profile,
      settings: const AppSettings(),
      currentStage: InterventionStage.s2,
      lockState: const LockStatePayload(),
      focusModeActive: false,
      distractionScore: 0.42,
      currentAppPackage: 'com.example.app',
      currentAppName: 'Example App',
      topDistractingAppName: 'Instagram',
      recentInterventionCount24h: 2,
      lastInterventionStage: InterventionStage.s2,
      recentInterventionSummaries: const ['S2 • Instagram'],
      pendingHabitNames: const ['Read 10 pages'],
      completedHabitsToday: 1,
      totalHabits: 3,
      todayFocusMinutes: 25,
      todayCompletedFocusSessions: 1,
    );
  }
}

class _FakeAIChatRepository extends AIChatRepository {
  final Map<String, AIChatThread> _threads = {};
  final Map<String, List<AIChatMessage>> _messages = {};

  @override
  Future<AIChatThread?> getLatestThread() async {
    if (_threads.isEmpty) return null;
    final sorted = _threads.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted.first;
  }

  @override
  Future<void> saveThread(AIChatThread thread) async {
    _threads[thread.id] = thread;
  }

  @override
  Future<void> saveMessage(AIChatMessage message) async {
    _messages.putIfAbsent(message.threadId, () => <AIChatMessage>[]);
    final list = _messages[message.threadId]!;
    list.removeWhere((item) => item.id == message.id);
    list.add(message);
  }

  @override
  Future<List<AIChatMessage>> getMessagesForThread(
    String threadId, {
    int? limit,
  }) async {
    final values = List<AIChatMessage>.from(_messages[threadId] ?? const []);
    values.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (limit == null || values.length <= limit) {
      return values;
    }
    return values.sublist(values.length - limit);
  }

  @override
  Future<void> updateThreadPreview({
    required String threadId,
    required String title,
    required String lastPreview,
    required DateTime updatedAt,
  }) async {
    final current = _threads[threadId];
    if (current == null) return;
    _threads[threadId] = current.copyWith(
      title: title,
      lastPreview: lastPreview,
      updatedAt: updatedAt,
    );
  }
}

class _CloudReplyProvider extends AICloudProvider {
  const _CloudReplyProvider();

  @override
  bool get isConfigured => true;

  @override
  String get providerName => 'fake_cloud';

  @override
  String? get modelName => 'fake-model';

  @override
  Future<AIChatReply> generateChatReply(CloudChatRequest request) async {
    return AIChatReply(
      text: 'Cloud grounded reply',
      source: AIChatMessageSource.cloud,
      providerName: providerName,
      modelName: modelName,
      contextJson: request.context.toStorageJson(),
    );
  }

  @override
  Future<CloudMessageEnhancement?> enhanceMessage(
    CloudMessageRequest request,
  ) async {
    return null;
  }
}

class _UnavailableCloudProvider extends AICloudProvider {
  const _UnavailableCloudProvider();

  @override
  bool get isConfigured => false;

  @override
  String get providerName => 'none';

  @override
  String? get modelName => null;

  @override
  Future<AIChatReply> generateChatReply(CloudChatRequest request) {
    throw const AICloudUnavailableException('provider_not_configured');
  }

  @override
  Future<CloudMessageEnhancement?> enhanceMessage(
    CloudMessageRequest request,
  ) async {
    return null;
  }
}
