import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../../features/ai/domain/entities/chat_models.dart';

class AIChatRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<AIChatThread?> getLatestThread() async {
    final rows = await _db.queryWhere(
      'ai_chat_threads',
      orderBy: 'updated_at DESC, created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AIChatThread.fromRow(rows.first);
  }

  Future<List<AIChatThread>> getRecentThreads({int limit = 20}) async {
    final rows = await _db.queryWhere(
      'ai_chat_threads',
      orderBy: 'updated_at DESC, created_at DESC',
      limit: limit,
    );
    return rows.map(AIChatThread.fromRow).toList();
  }

  Future<void> saveThread(AIChatThread thread) async {
    final db = await _db.database;
    await db.insert(
      'ai_chat_threads',
      thread.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveMessage(AIChatMessage message) async {
    final db = await _db.database;
    await db.insert(
      'ai_chat_messages',
      message.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveMessages(List<AIChatMessage> messages) async {
    if (messages.isEmpty) return;
    final db = await _db.database;
    final batch = db.batch();
    for (final message in messages) {
      batch.insert(
        'ai_chat_messages',
        message.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<AIChatMessage>> getMessagesForThread(
    String threadId, {
    int? limit,
  }) async {
    final rows = await _db.queryWhere(
      'ai_chat_messages',
      where: 'thread_id = ?',
      whereArgs: [threadId],
      orderBy: 'created_at ASC, id ASC',
      limit: limit,
    );
    return rows.map(AIChatMessage.fromRow).toList();
  }

  Future<void> updateThreadPreview({
    required String threadId,
    required String title,
    required String lastPreview,
    required DateTime updatedAt,
  }) async {
    await _db.update(
      'ai_chat_threads',
      {
        'title': title,
        'last_preview': lastPreview,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [threadId],
    );
  }

  Future<void> deleteThread(String threadId) async {
    final db = await _db.database;
    await db.delete('ai_chat_messages',
        where: 'thread_id = ?', whereArgs: [threadId]);
    await db.delete('ai_chat_threads',
        where: 'id = ?', whereArgs: [threadId]);
  }
}
