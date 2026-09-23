import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../../features/ai/domain/entities/messaging_models.dart';

class MessageHistoryRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<void> saveMessage(MessageHistoryEntry entry) async {
    final db = await _db.database;
    await db.insert(
      'message_history',
      entry.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MessageHistoryEntry>> getRecentMessages({int limit = 20}) async {
    final rows = await _db.queryWhere(
      'message_history',
      orderBy: 'generated_at DESC, id DESC',
      limit: limit,
    );
    return rows.map(MessageHistoryEntry.fromRow).toList();
  }

  Future<void> saveFeedback(MessageFeedbackEntry entry) async {
    final db = await _db.database;
    await db.insert(
      'message_feedback',
      entry.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MessageFeedbackEntry>> getFeedbackFor(
    String historyKey,
  ) async {
    final rows = await _db.queryWhere(
      'message_feedback',
      where: 'history_key = ?',
      whereArgs: [historyKey],
      orderBy: 'created_at DESC, id DESC',
    );
    return rows.map(MessageFeedbackEntry.fromRow).toList();
  }
}
