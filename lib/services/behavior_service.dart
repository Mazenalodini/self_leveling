import 'dart:async';
import '../core/database/database_helper.dart';
import '../domain/entities/behavior_record.dart';
import '../domain/enums/behavior_category.dart';
import '../platform/platform_channel.dart';

/// Daily usage refresh facade over the canonical native snapshot writer.
///
/// RESPONSIBILITY: Single clear role — read Android UsageStats and write
/// idempotent daily snapshots to SQLite for historical analytics.
///
/// ARCHITECTURE:
///   - Kotlin TrackingService is the SOURCE OF TRUTH for real-time behavior
///   - Kotlin NativeUsageSnapshotStore is the CANONICAL WRITER for app_usage
///     and behavior_records
///   - This service only triggers refreshes and emits change revisions to the UI
///
/// WHAT THIS SERVICE DOES NOT DO:
///   - Does not make escalation decisions
///   - Does not track real-time state (that's Kotlin)
///   - Does not derive behavioral scores (that's SystemProvider)
///   - Does not write usage rows directly anymore
class BehaviorService {
  final _db = DatabaseHelper.instance;
  final Future<bool> Function(int days) _usageSnapshotRefresher;
  Timer? _pollingTimer;
  final _usageChangedController = StreamController<int>.broadcast();
  int _usageRevision = 0;

  BehaviorService({
    Future<bool> Function(int days)? usageSnapshotRefresher,
  }) : _usageSnapshotRefresher = usageSnapshotRefresher ??
            ((days) =>
                PlatformChannel.instance.refreshUsageSnapshot(days: days));

  Stream<int> get onUsageDataChanged => _usageChangedController.stream;

  Future<void> init() async {
    // No high-water mark needed — we always query full-day totals
  }

  /// Start periodic snapshot writes.
  /// Each poll writes today's absolute totals (idempotent).
  void startPolling({int intervalSeconds = 30}) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) => refreshTodayUsage(),
    );
    // Initial snapshot
    refreshTodayUsage();
  }

  Future<void> refreshTodayUsage({int days = 1}) => _refreshUsageSnapshot(days);

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Trigger a native usage snapshot refresh and emit a revision only when the
  /// canonical local usage/history tables actually changed.
  Future<void> _refreshUsageSnapshot(int days) async {
    try {
      final changed = await _usageSnapshotRefresher(days);
      if (!changed) {
        return;
      }
      _usageRevision++;
      if (!_usageChangedController.isClosed) {
        _usageChangedController.add(_usageRevision);
      }
    } catch (_) {
      // Silently handle polling errors — non-fatal
    }
  }

  /// Get today's behavior summary.
  Future<BehaviorRecord?> getTodaySummary() async {
    final dateKey = _dateKey(DateTime.now());
    final row = await _db.queryFirst('behavior_records',
        where: 'date_key = ?', whereArgs: [dateKey]);

    if (row == null) return null;

    return BehaviorRecord(
      timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
      productiveSeconds: row['productive_seconds'] as int? ?? 0,
      neutralSeconds: row['neutral_seconds'] as int? ?? 0,
      distractingSeconds: row['distracting_seconds'] as int? ?? 0,
      sessionCount: row['session_count'] as int? ?? 0,
      topDistractingApp: row['top_distracting_app'] as String?,
    );
  }

  /// Get recent behavior records (for weekly/historical views).
  Future<List<BehaviorRecord>> getRecentRecords({int count = 10}) async {
    final rows = await _db.queryWhere('behavior_records',
        orderBy: 'timestamp DESC', limit: count);

    return rows
        .map((r) => BehaviorRecord(
              timestamp:
                  DateTime.fromMillisecondsSinceEpoch(r['timestamp'] as int),
              productiveSeconds: r['productive_seconds'] as int? ?? 0,
              neutralSeconds: r['neutral_seconds'] as int? ?? 0,
              distractingSeconds: r['distracting_seconds'] as int? ?? 0,
              sessionCount: r['session_count'] as int? ?? 0,
              topDistractingApp: r['top_distracting_app'] as String?,
            ))
        .toList();
  }

  /// Get today's per-app usage records.
  Future<List<AppUsageRecord>> getTodayUsage() async {
    final dateKey = _dateKey(DateTime.now());

    final rows = await _db
        .queryWhere('app_usage', where: 'date_key = ?', whereArgs: [dateKey]);

    return rows
        .map((r) => AppUsageRecord(
              packageName: r['package_name'] as String,
              appName: r['app_name'] as String,
              category: BehaviorCategory.values[r['category'] as int? ?? 1],
              startTime:
                  DateTime.fromMillisecondsSinceEpoch(r['start_time'] as int),
              durationSeconds: r['duration_seconds'] as int,
            ))
        .toList();
  }

  /// Get today's productive hours.
  Future<double> getTodayFocusHours() async {
    final summary = await getTodaySummary();
    if (summary == null) return 0.0;
    return summary.productiveSeconds / 3600.0;
  }

  /// Get today's distraction hours.
  Future<double> getTodayDistractionHours() async {
    final summary = await getTodaySummary();
    if (summary == null) return 0.0;
    return summary.distractingSeconds / 3600.0;
  }

  /// Clean old data (keep last 30 days for weekly review).
  Future<void> cleanup() async {
    final thirtyDaysAgo = DateTime.now()
        .subtract(const Duration(days: 30))
        .millisecondsSinceEpoch;
    await _db.delete('behavior_records',
        where: 'timestamp < ?', whereArgs: [thirtyDaysAgo]);
    await _db.delete('app_usage',
        where: 'start_time < ?', whereArgs: [thirtyDaysAgo]);
  }

  void dispose() {
    _pollingTimer?.cancel();
    _usageChangedController.close();
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
