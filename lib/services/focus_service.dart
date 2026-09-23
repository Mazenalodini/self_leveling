import '../core/database/database_helper.dart';
import '../data/repositories/progression_repository.dart';
import '../domain/entities/focus_session.dart';

/// Service for focus session persistence with SQLite.
class FocusService {
  final _db = DatabaseHelper.instance;
  final ProgressionRepository _progressionRepository = ProgressionRepository();

  Future<void> init() async {}

  /// Save a completed focus session.
  Future<void> saveSession(FocusSession session) async {
    await _db.insert('focus_sessions', {
      'id': session.id,
      'duration_minutes': session.durationMinutes,
      'started_at': session.startedAt.millisecondsSinceEpoch,
      'completed_at': session.completedAt?.millisecondsSinceEpoch,
      'was_completed': session.wasCompleted ? 1 : 0,
      'xp_earned': session.xpEarned,
    });
    await _progressionRepository.recordFocusCompletion(session);
  }

  /// Get all sessions.
  Future<List<FocusSession>> getAll() async {
    final rows =
        await _db.queryWhere('focus_sessions', orderBy: 'started_at DESC');
    return rows.map(_fromRow).toList();
  }

  /// Get today's sessions.
  Future<List<FocusSession>> getTodaySessions() async {
    final todayStart = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    final rows = await _db.queryWhere('focus_sessions',
        where: 'started_at > ?',
        whereArgs: [todayStart.millisecondsSinceEpoch],
        orderBy: 'started_at DESC');
    return rows.map(_fromRow).toList();
  }

  /// Get today's completed session count.
  Future<int> getTodayCompletedCount() async {
    final todayStart = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    return await _db.count('focus_sessions',
        where: 'started_at > ? AND was_completed = ?',
        whereArgs: [todayStart.millisecondsSinceEpoch, 1]);
  }

  /// Get today's total focus minutes.
  Future<int> getTodayFocusMinutes() async {
    final sessions = await getTodaySessions();
    return sessions
        .where((s) => s.wasCompleted)
        .fold<int>(0, (sum, s) => sum + s.durationMinutes);
  }

  FocusSession _fromRow(Map<String, dynamic> row) {
    return FocusSession(
      id: row['id'] as String,
      durationMinutes: row['duration_minutes'] as int,
      startedAt: DateTime.fromMillisecondsSinceEpoch(row['started_at'] as int),
      completedAt: row['completed_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['completed_at'] as int)
          : null,
      wasCompleted: (row['was_completed'] as int?) == 1,
      xpEarned: row['xp_earned'] as int? ?? 0,
    );
  }
}
