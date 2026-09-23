import '../core/database/database_helper.dart';
import '../data/repositories/app_policy_repository.dart';
import '../domain/entities/behavior_record.dart';
import '../domain/entities/report_models.dart';
import '../domain/enums/behavior_category.dart';

class StatsService {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final AppPolicyRepository _appPolicyRepository = AppPolicyRepository();

  static ({String startDateKey, String endDateKey}) usageDateKeyRangeFor(
    UsagePeriod period, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final rangeStart = switch (period) {
      UsagePeriod.today => _startOfDay(current),
      UsagePeriod.week =>
        _startOfDay(current.subtract(const Duration(days: 6))),
      UsagePeriod.month =>
        _startOfDay(current.subtract(const Duration(days: 29))),
    };
    final rangeEnd = _endExclusive(current);

    return (
      startDateKey: _dateKey(rangeStart),
      endDateKey: _dateKey(
        rangeEnd.subtract(const Duration(milliseconds: 1)),
      ),
    );
  }

  Future<DashboardReport> getDashboardReport() async {
    final today = DateTime.now();
    final todayKey = _dateKey(today);
    final behavior = await _getBehaviorForDate(todayKey);
    final habitsCompleted = await _db.count(
      'habit_completions',
      where: 'date_key = ?',
      whereArgs: [todayKey],
    );
    final focusMinutes = await _getFocusMinutesForRange(
      _startOfDay(today),
      _endExclusive(today),
    );
    final escalations = await _getEscalationSummary(
      _startOfDay(today),
      _endExclusive(today),
    );

    return buildDashboardReport(
      behavior: behavior,
      habitsCompleted: habitsCompleted,
      focusMinutes: focusMinutes,
      escalationCount: escalations.count,
      maxStage: escalations.maxStage,
    );
  }

  Future<StatsOverviewReport> getStatsOverview() async {
    final today = DateTime.now();
    final todayKey = _dateKey(today);
    final behavior = await _getBehaviorForDate(todayKey);
    final habitsCompleted = await _db.count(
      'habit_completions',
      where: 'date_key = ?',
      whereArgs: [todayKey],
    );
    final totalHabits = await _db.count(
      'habits',
      where: 'is_active = ?',
      whereArgs: [1],
    );
    final rangeStart = _startOfDay(today);
    final rangeEnd = _endExclusive(today);
    final focusMinutes = await _getFocusMinutesForRange(rangeStart, rangeEnd);
    final focusSessions = await _db.count(
      'focus_sessions',
      where: 'started_at >= ? AND started_at < ? AND was_completed = ?',
      whereArgs: [
        rangeStart.millisecondsSinceEpoch,
        rangeEnd.millisecondsSinceEpoch,
        1
      ],
    );
    final escalations = await _getEscalationSummary(rangeStart, rangeEnd);

    return buildStatsOverview(
      behavior: behavior,
      habitsCompleted: habitsCompleted,
      totalHabits: totalHabits,
      focusMinutes: focusMinutes,
      focusSessions: focusSessions,
      escalationCount: escalations.count,
      maxStage: escalations.maxStage,
    );
  }

  Future<WeeklyReviewReport> getWeeklyReview() async {
    final now = DateTime.now();
    final weekStart = _startOfDay(now.subtract(const Duration(days: 6)));
    final currentWeekDays = <String>[];
    final focusHours = List<double>.filled(7, 0);
    final distractHours = List<double>.filled(7, 0);
    var totalHabitsCompleted = 0;

    for (var i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      currentWeekDays.add(_getDayShortcut(date.weekday));
      final behavior = await _getBehaviorForDate(_dateKey(date));
      focusHours[i] = (behavior?.productiveSeconds ?? 0) / 3600.0;
      distractHours[i] = (behavior?.distractingSeconds ?? 0) / 3600.0;
      totalHabitsCompleted += await _db.count(
        'habit_completions',
        where: 'date_key = ?',
        whereArgs: [_dateKey(date)],
      );
    }

    final currentWeekStartMs = weekStart.millisecondsSinceEpoch;
    final currentWeekEnd = _endExclusive(now);
    final previousWeekStart = weekStart.subtract(const Duration(days: 7));
    final previousWeekEnd = weekStart;

    final currentProductive =
        focusHours.fold<double>(0, (sum, value) => sum + value);
    final previousProductive = await _getProductiveHoursForRange(
      previousWeekStart,
      previousWeekEnd,
    );
    final productiveChange = calculateProductiveChangePercent(
      currentWeekHours: currentProductive,
      previousWeekHours: previousProductive,
    );

    final focusSessions = await _db.count(
      'focus_sessions',
      where: 'started_at >= ? AND started_at < ? AND was_completed = ?',
      whereArgs: [currentWeekStartMs, currentWeekEnd.millisecondsSinceEpoch, 1],
    );
    final weeklyXp = await _sumIntColumn(
      'progression_ledger',
      'earned_xp_delta',
      where: 'created_at >= ? AND created_at < ?',
      whereArgs: [currentWeekStartMs, currentWeekEnd.millisecondsSinceEpoch],
    );
    final escalations = await _getEscalationSummary(weekStart, currentWeekEnd);

    return WeeklyReviewReport(
      days: currentWeekDays,
      focusHours: focusHours,
      distractHours: distractHours,
      totalHabitsCompleted: totalHabitsCompleted,
      totalFocusSessions: focusSessions,
      weeklyXpEarned: weeklyXp,
      weeklyEscalationCount: escalations.count,
      weeklyMaxStage: escalations.maxStage,
      productiveChangePercent: productiveChange,
      topDistractingApp: await _getTopDistractingAppForRange(
        weekStart,
        currentWeekEnd,
      ),
    );
  }

  Future<UsageReport> getUsageReport(UsagePeriod period) async {
    final dateRange = usageDateKeyRangeFor(period);
    final db = await _db.database;
    final rows = await db.rawQuery(
      '''
      SELECT
        package_name,
        MAX(app_name) AS app_name,
        MAX(category) AS category,
        SUM(duration_seconds) AS total_duration_seconds,
        SUM(launch_count) AS total_launch_count,
        MAX(last_time_used) AS max_last_time_used
      FROM app_usage
      WHERE date_key >= ? AND date_key <= ?
      GROUP BY package_name
      ORDER BY
        total_duration_seconds DESC,
        total_launch_count DESC,
        max_last_time_used DESC,
        app_name COLLATE NOCASE ASC
      ''',
      [dateRange.startDateKey, dateRange.endDateKey],
    );
    final policies = await _appPolicyRepository.getEffectivePolicies();
    final categoryOverrides = <String, int?>{
      for (final policy in policies)
        policy.packageName: policy.categoryOverride,
    };
    return buildUsageReport(
      period: period,
      rows: rows,
      categoryOverrides: categoryOverrides,
    );
  }

  Future<LevelOverviewReport> getLevelOverview() async {
    final today = DateTime.now();
    final rangeStart = _startOfDay(today);
    final rangeEnd = _endExclusive(today);
    final startMs = rangeStart.millisecondsSinceEpoch;
    final endMs = rangeEnd.millisecondsSinceEpoch;

    final focusXp = await _sumIntColumn(
      'progression_ledger',
      'earned_xp_delta',
      where: 'source_type = ? AND created_at >= ? AND created_at < ?',
      whereArgs: ['focus_completion', startMs, endMs],
    );
    final habitXp = await _sumIntColumn(
      'progression_ledger',
      'earned_xp_delta',
      where: 'source_type = ? AND created_at >= ? AND created_at < ?',
      whereArgs: ['habit_completion', startMs, endMs],
    );
    final interventionXp = await _sumIntColumn(
      'progression_ledger',
      'effective_xp_delta',
      where: 'source_type = ? AND created_at >= ? AND created_at < ?',
      whereArgs: ['native_intervention', startMs, endMs],
    );
    final levelUps = await _db.count(
      'escalation_events',
      where:
          'event_type = ? AND timestamp >= ? AND timestamp < ? AND to_level > from_level',
      whereArgs: ['level_up', startMs, endMs],
    );

    return LevelOverviewReport(
      focusXpToday: focusXp,
      habitXpToday: habitXp,
      interventionXpToday: interventionXp,
      recentLevelUps: levelUps,
    );
  }

  static DashboardReport buildDashboardReport({
    required BehaviorRecord? behavior,
    required int habitsCompleted,
    required int focusMinutes,
    required int escalationCount,
    required int maxStage,
  }) {
    return DashboardReport(
      todayHabitCompletions: habitsCompleted,
      todayFocusMinutes: focusMinutes,
      todayDistractionHours: (behavior?.distractingSeconds ?? 0) / 3600.0,
      todayEscalationCount: escalationCount,
      todayMaxStage: maxStage,
      topDistractingApp: behavior?.topDistractingApp,
    );
  }

  static UsageReport buildUsageReport({
    required UsagePeriod period,
    required List<Map<String, Object?>> rows,
    Map<String, int?> categoryOverrides = const {},
  }) {
    final maxRangeSeconds = usageMaxDurationFor(period);
    var apps = rows
        .map((row) {
          final packageName = row['package_name'] as String? ?? '';
          final categoryIndex = categoryOverrides[packageName] ??
              (row['category'] as int? ?? BehaviorCategory.neutral.index);
          return UsageAppSummary(
            packageName: packageName,
            appName: row['app_name'] as String? ?? packageName,
            category: categoryIndex >= 0 &&
                    categoryIndex < BehaviorCategory.values.length
                ? BehaviorCategory.values[categoryIndex]
                : BehaviorCategory.neutral,
            durationSeconds:
                ((row['total_duration_seconds'] as num?)?.toInt() ?? 0)
                    .clamp(0, maxRangeSeconds),
            launchCount: (row['total_launch_count'] as num?)?.toInt() ?? 0,
            lastTimeUsed: (row['max_last_time_used'] as num?)?.toInt() ?? 0,
          );
        })
        .where((app) => app.durationSeconds > 0 || app.launchCount > 0)
        .toList()
      ..sort((a, b) {
        final durationCompare = b.durationSeconds.compareTo(a.durationSeconds);
        if (durationCompare != 0) return durationCompare;
        final launchCompare = b.launchCount.compareTo(a.launchCount);
        if (launchCompare != 0) return launchCompare;
        return b.lastTimeUsed.compareTo(a.lastTimeUsed);
      });

    final rawTotalDurationSeconds = apps.fold<int>(
      0,
      (sum, app) => sum + app.durationSeconds,
    );
    if (rawTotalDurationSeconds > maxRangeSeconds &&
        rawTotalDurationSeconds > 0) {
      final scale = maxRangeSeconds / rawTotalDurationSeconds;
      var scaledTotal = 0;
      apps = apps.map((app) {
        final scaledDuration = (app.durationSeconds * scale).floor();
        scaledTotal += scaledDuration;
        return UsageAppSummary(
          packageName: app.packageName,
          appName: app.appName,
          category: app.category,
          durationSeconds: scaledDuration,
          launchCount: app.launchCount,
          lastTimeUsed: app.lastTimeUsed,
        );
      }).toList();
      if (scaledTotal < maxRangeSeconds && apps.isNotEmpty) {
        final head = apps.first;
        apps[0] = UsageAppSummary(
          packageName: head.packageName,
          appName: head.appName,
          category: head.category,
          durationSeconds:
              head.durationSeconds + (maxRangeSeconds - scaledTotal),
          launchCount: head.launchCount,
          lastTimeUsed: head.lastTimeUsed,
        );
      }
    }

    final totalDurationSeconds = apps.fold<int>(
      0,
      (sum, app) => sum + app.durationSeconds,
    );
    final totalLaunchCount = apps.fold<int>(
      0,
      (sum, app) => sum + app.launchCount,
    );

    return UsageReport(
      period: period,
      totalDurationSeconds: totalDurationSeconds,
      totalLaunchCount: totalLaunchCount,
      apps: apps,
    );
  }

  static int usageMaxDurationFor(UsagePeriod period) {
    return switch (period) {
      UsagePeriod.today => 24 * 60 * 60,
      UsagePeriod.week => 7 * 24 * 60 * 60,
      UsagePeriod.month => 30 * 24 * 60 * 60,
    };
  }

  static StatsOverviewReport buildStatsOverview({
    required BehaviorRecord? behavior,
    required int habitsCompleted,
    required int totalHabits,
    required int focusMinutes,
    required int focusSessions,
    required int escalationCount,
    required int maxStage,
  }) {
    final completionRate =
        totalHabits == 0 ? 0 : ((habitsCompleted / totalHabits) * 100).round();
    return StatsOverviewReport(
      todayHabitCompletions: habitsCompleted,
      totalHabits: totalHabits,
      completionRate: completionRate,
      todayFocusMinutes: focusMinutes,
      todayFocusSessions: focusSessions,
      todayDistractionHours: (behavior?.distractingSeconds ?? 0) / 3600.0,
      todayEscalationCount: escalationCount,
      todayMaxStage: maxStage,
      topDistractingApp: behavior?.topDistractingApp,
    );
  }

  static double calculateProductiveChangePercent({
    required double currentWeekHours,
    required double previousWeekHours,
  }) {
    if (previousWeekHours <= 0) {
      return currentWeekHours > 0 ? 100.0 : 0.0;
    }
    return ((currentWeekHours - previousWeekHours) / previousWeekHours) * 100.0;
  }

  Future<BehaviorRecord?> _getBehaviorForDate(String dateKey) async {
    final row = await _db.queryFirst(
      'behavior_records',
      where: 'date_key = ?',
      whereArgs: [dateKey],
    );
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

  Future<int> _getFocusMinutesForRange(DateTime start, DateTime end) async {
    final rows = await _db.queryWhere(
      'focus_sessions',
      where: 'started_at >= ? AND started_at < ? AND was_completed = ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch, 1],
    );
    return rows.fold<int>(
      0,
      (sum, row) => sum + (row['duration_minutes'] as int? ?? 0),
    );
  }

  Future<_EscalationSummary> _getEscalationSummary(
    DateTime start,
    DateTime end,
  ) async {
    final rows = await _db.queryWhere(
      'escalation_events',
      where: 'timestamp >= ? AND timestamp < ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    );
    var count = 0;
    var maxStage = 0;
    for (final row in rows) {
      final fromLevel = row['from_level'] as int? ?? 0;
      final toLevel = row['to_level'] as int? ?? row['stage'] as int? ?? 0;
      if (toLevel > fromLevel) {
        count++;
      }
      if (toLevel > maxStage) {
        maxStage = toLevel;
      }
    }
    return _EscalationSummary(count: count, maxStage: maxStage);
  }

  Future<double> _getProductiveHoursForRange(
      DateTime start, DateTime end) async {
    final rows = await _db.queryWhere(
      'behavior_records',
      where: 'timestamp >= ? AND timestamp < ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    );
    var productiveSeconds = 0;
    for (final row in rows) {
      productiveSeconds += row['productive_seconds'] as int? ?? 0;
    }
    return productiveSeconds / 3600.0;
  }

  Future<String?> _getTopDistractingAppForRange(
      DateTime start, DateTime end) async {
    final rows = await _db.queryWhere(
      'app_usage',
      where: 'start_time >= ? AND start_time < ? AND category = ?',
      whereArgs: [
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
        BehaviorCategory.distracting.index,
      ],
    );
    if (rows.isEmpty) return null;

    final totals = <String, int>{};
    for (final row in rows) {
      final name =
          row['app_name'] as String? ?? row['package_name'] as String? ?? '';
      totals[name] =
          (totals[name] ?? 0) + (row['duration_seconds'] as int? ?? 0);
    }
    if (totals.isEmpty) return null;

    return totals.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  Future<int> _sumIntColumn(
    String table,
    String column, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM($column), 0) AS total FROM $table${where != null ? ' WHERE $where' : ''}',
      whereArgs,
    );
    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

  static DateTime _startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime _endExclusive(DateTime date) =>
      DateTime(date.year, date.month, date.day).add(const Duration(days: 1));

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _getDayShortcut(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
        return 'Sun';
      default:
        return '';
    }
  }
}

class _EscalationSummary {
  final int count;
  final int maxStage;

  const _EscalationSummary({
    required this.count,
    required this.maxStage,
  });
}
