import '../../../../core/database/database_helper.dart';
import '../../../../data/repositories/progression_repository.dart';
import '../../../../data/repositories/settings_repository.dart';
import '../../../../domain/contracts/runtime_contract.dart';
import '../domain/entities/chat_models.dart';

class ChatContextService {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final ProgressionRepository _progressionRepository = ProgressionRepository();
  final SettingsRepository _settingsRepository = SettingsRepository();

  Future<CanonicalChatContext> buildContext() async {
    final profile = await _progressionRepository.getProjectedProfile();
    final settings = await _settingsRepository.getSettings();
    final habitSummary = await _loadHabitSummary();
    final focusSummary = await _loadFocusSummary();
    final interventionSummary = await _loadInterventionSummary();
    final runtimeSummary = await _loadRuntimeSummary();
    final topDistractingApp = await _loadTopDistractingApp();

    return CanonicalChatContext(
      language:
          profile.surveyLanguage.isNotEmpty ? profile.surveyLanguage : 'en',
      profile: profile,
      settings: settings,
      currentStage: runtimeSummary.stage,
      lockState: runtimeSummary.lockState,
      focusModeActive: runtimeSummary.focusModeActive,
      distractionScore: runtimeSummary.distractionScore,
      currentAppPackage: runtimeSummary.currentAppPackage,
      currentAppName: runtimeSummary.currentAppName,
      topDistractingAppName: topDistractingApp,
      recentInterventionCount24h: interventionSummary.count,
      lastInterventionStage: interventionSummary.lastStage,
      recentInterventionSummaries: interventionSummary.summaries,
      pendingHabitNames: habitSummary.pendingNames,
      completedHabitsToday: habitSummary.completedCount,
      totalHabits: habitSummary.totalCount,
      todayFocusMinutes: focusSummary.minutes,
      todayCompletedFocusSessions: focusSummary.sessionCount,
    );
  }

  Future<_HabitSummary> _loadHabitSummary() async {
    final today = _todayKey();
    final habits = await _db.queryWhere(
      'habits',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'sort_order ASC, created_at DESC',
    );
    final completions = await _db.queryWhere(
      'habit_completions',
      where: 'date_key = ?',
      whereArgs: [today],
    );
    final completedIds =
        completions.map((row) => row['habit_id'] as String).toSet();
    final pendingNames = habits
        .where((row) => !completedIds.contains(row['id']))
        .map((row) => row['name'] as String? ?? '')
        .where((name) => name.trim().isNotEmpty)
        .take(3)
        .toList();
    return _HabitSummary(
      pendingNames: pendingNames,
      completedCount: completedIds.length,
      totalCount: habits.length,
    );
  }

  Future<_FocusSummary> _loadFocusSummary() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final rows = await _db.queryWhere(
      'focus_sessions',
      where: 'was_completed = ? AND completed_at >= ?',
      whereArgs: [1, startOfDay.millisecondsSinceEpoch],
      orderBy: 'completed_at DESC',
    );
    final minutes = rows.fold<int>(
      0,
      (total, row) => total + (row['duration_minutes'] as int? ?? 0),
    );
    return _FocusSummary(minutes: minutes, sessionCount: rows.length);
  }

  Future<_InterventionSummary> _loadInterventionSummary() async {
    final since = DateTime.now()
        .subtract(const Duration(hours: 24))
        .millisecondsSinceEpoch;
    final rows = await _db.queryWhere(
      'escalation_events',
      where: 'timestamp >= ?',
      whereArgs: [since],
      orderBy: 'timestamp DESC',
      limit: 6,
    );
    final lastStage = rows.isEmpty
        ? null
        : InterventionStage.fromCode(
            rows.first['stage'] as int? ?? rows.first['to_level'] as int? ?? 0,
          );
    final summaries = rows.map((row) {
      final packageName = row['package_name'] as String? ?? '';
      final stage = InterventionStage.fromCode(
        row['stage'] as int? ?? row['to_level'] as int? ?? 0,
      );
      if (packageName.isEmpty) {
        return 'S${stage.code}';
      }
      return 'S${stage.code} • $packageName';
    }).toList();
    return _InterventionSummary(
      count: rows.length,
      lastStage: lastStage,
      summaries: summaries,
    );
  }

  Future<_RuntimeSummary> _loadRuntimeSummary() async {
    final row = await _db.queryFirst(
      'runtime_active_state',
      where: 'id = ?',
      whereArgs: ['singleton'],
    );
    final runtimeRow = row ??
        await _db.queryFirst(
          'runtime_active_state',
        );
    if (runtimeRow == null) {
      return const _RuntimeSummary(
        stage: InterventionStage.s0,
        lockState: LockStatePayload(),
        focusModeActive: false,
        distractionScore: 0,
        currentAppPackage: null,
        currentAppName: null,
      );
    }

    final currentAppPackage = runtimeRow['current_app_package'] as String?;
    return _RuntimeSummary(
      stage:
          InterventionStage.fromCode(runtimeRow['current_stage'] as int? ?? 0),
      lockState: LockStatePayload(
        blockedAppPackage: runtimeRow['blocked_app_package'] as String?,
        remainingLockSeconds: _remainingSeconds(
          runtimeRow['lock_until_ms'] as int?,
        ),
        reentryCount: runtimeRow['reentry_count'] as int? ?? 0,
        isLimitedAccess: (runtimeRow['is_limited_access'] as int? ?? 0) == 1,
        limitedAccessRemainingSeconds: _remainingSeconds(
          runtimeRow['limited_access_until_ms'] as int?,
        ),
        limitedAccessAppPackage:
            runtimeRow['limited_access_app_package'] as String?,
      ),
      focusModeActive: (runtimeRow['focus_mode_active'] as int? ?? 0) == 1,
      distractionScore: (runtimeRow['risk_score'] as num?)?.toDouble() ?? 0.0,
      currentAppPackage: currentAppPackage,
      currentAppName: await _resolveAppName(currentAppPackage),
    );
  }

  Future<String?> _loadTopDistractingApp() async {
    final end = DateTime.now();
    final start = end.subtract(const Duration(days: 6));
    final rows = await (await _db.database).rawQuery(
      '''
      SELECT app_name,
             SUM(duration_seconds) AS total_seconds,
             MAX(last_time_used) AS max_last_time_used
      FROM app_usage
      WHERE category = ? AND date_key BETWEEN ? AND ?
      GROUP BY package_name, app_name
      ORDER BY total_seconds DESC, max_last_time_used DESC
      LIMIT 1
      ''',
      [
        AppCategory.distracting.nativeValue,
        _dateKey(start),
        _dateKey(end),
      ],
    );
    if (rows.isEmpty) return null;
    return rows.first['app_name'] as String?;
  }

  Future<String?> _resolveAppName(String? packageName) async {
    if (packageName == null || packageName.isEmpty) return null;
    final row = await _db.queryFirst(
      'app_usage',
      where: 'package_name = ?',
      whereArgs: [packageName],
    );
    return row?['app_name'] as String? ?? packageName;
  }

  int _remainingSeconds(int? untilMs) {
    if (untilMs == null || untilMs <= 0) return 0;
    final deltaMs = untilMs - DateTime.now().millisecondsSinceEpoch;
    if (deltaMs <= 0) return 0;
    return (deltaMs / 1000).ceil();
  }

  String _todayKey() => _dateKey(DateTime.now());

  String _dateKey(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}

class _HabitSummary {
  final List<String> pendingNames;
  final int completedCount;
  final int totalCount;

  const _HabitSummary({
    required this.pendingNames,
    required this.completedCount,
    required this.totalCount,
  });
}

class _FocusSummary {
  final int minutes;
  final int sessionCount;

  const _FocusSummary({
    required this.minutes,
    required this.sessionCount,
  });
}

class _InterventionSummary {
  final int count;
  final InterventionStage? lastStage;
  final List<String> summaries;

  const _InterventionSummary({
    required this.count,
    required this.lastStage,
    required this.summaries,
  });
}

class _RuntimeSummary {
  final InterventionStage stage;
  final LockStatePayload lockState;
  final bool focusModeActive;
  final double distractionScore;
  final String? currentAppPackage;
  final String? currentAppName;

  const _RuntimeSummary({
    required this.stage,
    required this.lockState,
    required this.focusModeActive,
    required this.distractionScore,
    required this.currentAppPackage,
    required this.currentAppName,
  });
}
