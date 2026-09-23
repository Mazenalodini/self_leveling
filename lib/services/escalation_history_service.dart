import '../core/database/database_helper.dart';
import '../domain/entities/escalation_event_record.dart';

/// Read-only service for querying escalation events from SQLite.
///
/// The native EscalationEvaluator writes escalation events.
/// This service ONLY reads them for Flutter UI display (history, stats).
/// It never makes escalation decisions.
class EscalationHistoryService {
  final _db = DatabaseHelper.instance;

  /// Get today's escalation events.
  Future<List<EscalationEventRecord>> getTodayEvents() async {
    final todayStart = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    final rows = await _db.queryWhere('escalation_events',
        where: 'timestamp > ?',
        whereArgs: [todayStart.millisecondsSinceEpoch],
        orderBy: 'timestamp DESC');

    return rows.map((r) => EscalationEventRecord.fromMap(r)).toList();
  }

  /// Get recent escalation events (last N).
  Future<List<EscalationEventRecord>> getRecentEvents({int count = 20}) async {
    final rows = await _db.queryWhere('escalation_events',
        orderBy: 'timestamp DESC', limit: count);

    return rows.map((r) => EscalationEventRecord.fromMap(r)).toList();
  }

  /// Get today's highest escalation level reached.
  Future<int> getTodayMaxLevel() async {
    final events = await getTodayEvents();
    if (events.isEmpty) return 0;
    return events.fold<int>(0, (max, e) => e.toLevel > max ? e.toLevel : max);
  }

  /// Get today's escalation count (how many times escalation happened).
  Future<int> getTodayEscalationCount() async {
    final events = await getTodayEvents();
    return events.where((e) => e.isEscalation).length;
  }

  /// Clean old events (keep last 30 days).
  Future<void> cleanup() async {
    final thirtyDaysAgo =
        DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch;
    await _db.delete('escalation_events',
        where: 'timestamp < ?', whereArgs: [thirtyDaysAgo]);
  }
}
