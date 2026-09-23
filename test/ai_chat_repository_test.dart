import 'package:flutter_test/flutter_test.dart';
import 'package:self_leveling/core/database/database_helper.dart';
import 'package:self_leveling/data/repositories/ai_chat_repository.dart';
import 'package:self_leveling/features/ai/domain/entities/chat_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AI chat repository persists thread and messages locally', () async {
    final repository = AIChatRepository();
    final db = await DatabaseHelper.instance.database;
    await db.delete('ai_chat_messages');
    await db.delete('ai_chat_threads');

    final now = DateTime.now();
    const threadId = 'thread-1';
    await repository.saveThread(
      AIChatThread(
        id: threadId,
        title: 'New chat',
        language: 'en',
        lastPreview: '',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repository.saveMessage(
      AIChatMessage(
        id: 'msg-user',
        threadId: threadId,
        role: AIChatRole.user,
        body: 'Hello',
        source: AIChatMessageSource.local,
        createdAt: now,
      ),
    );
    await repository.saveMessage(
      AIChatMessage(
        id: 'msg-assistant',
        threadId: threadId,
        role: AIChatRole.assistant,
        body: 'Hi back',
        source: AIChatMessageSource.cloud,
        providerName: 'fake_cloud',
        modelName: 'fake-model',
        createdAt: now.add(const Duration(seconds: 1)),
        contextJson: '{"hello":"world"}',
      ),
    );

    final thread = await repository.getLatestThread();
    final messages = await repository.getMessagesForThread(threadId);

    expect(thread, isNotNull);
    expect(thread!.id, threadId);
    expect(messages, hasLength(2));
    expect(messages.last.source, AIChatMessageSource.cloud);
    expect(messages.last.contextMap['hello'], 'world');
  });
}
