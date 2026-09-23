import '../../../../core/database/database_helper.dart';
import '../../../../data/repositories/app_policy_repository.dart';
import '../../../../data/repositories/local_profile_repository.dart';
import '../../../../data/repositories/settings_repository.dart';
import '../../../../domain/contracts/runtime_contract.dart';
import '../../../../domain/entities/app_settings.dart';
import '../../../../domain/entities/effective_app_policy.dart';
import '../../../../domain/entities/habit.dart';
import '../../../../domain/entities/user_profile.dart';
import '../../../../domain/enums/behavior_category.dart';
import '../../../../domain/enums/escalation_level.dart';
import '../../../../domain/enums/habit_type.dart';
import '../domain/entities/ai_contexts.dart';
import '../domain/entities/messaging_models.dart';

class MessageContextService {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final LocalProfileRepository _profileRepository = LocalProfileRepository();
  final SettingsRepository _settingsRepository = SettingsRepository();
  final AppPolicyRepository _appPolicyRepository = AppPolicyRepository();

  Future<CanonicalMessageContext> buildInterventionContext(
    InterventionMessageRequest request,
  ) async {
    final profile = await _profileRepository.getOrCreateCanonicalProfile();
    final settings = await _settingsRepository.getSettings();
    final policy = request.packageName.isEmpty
        ? null
        : await _appPolicyRepository.getEffectivePolicy(request.packageName);
    final pendingHabits = await _loadPendingHabits();
    final recentSummary =
        await _loadRecentInterventionSummary(request.packageName);
    final todayFocusMinutes = await _loadTodayFocusMinutes();

    return CanonicalMessageContext(
      language:
          profile.surveyLanguage.isNotEmpty ? profile.surveyLanguage : 'en',
      profile: profile,
      settings: settings,
      stage: request.interventionStage,
      lockState: _buildLockStateFromRequest(request),
      currentAppPackage: request.packageName,
      currentAppName:
          request.appName.isEmpty ? request.packageName : request.appName,
      appCategory: _resolveAppCategory(request.appCategoryCode, policy),
      effectivePolicy: policy,
      riskScore: request.distractionScore,
      ignoredWarningCount: request.ignoredWarnings,
      focusModeActive: request.focusModeActive,
      pendingHabits: pendingHabits,
      recentInterventionCount24h: recentSummary.count,
      lastInterventionStage: recentSummary.lastStage,
      todayFocusMinutes: todayFocusMinutes,
      runtimeEventId: request.runtimeEventId,
      payloadSignature: request.payloadSignature,
    );
  }

  Future<CanonicalMessageContext> buildHabitReminderContext({
    required Habit habit,
    required String language,
    required MessageRequestKind requestKind,
  }) async {
    final profile = await _profileRepository.getOrCreateCanonicalProfile();
    final settings = await _settingsRepository.getSettings();
    final pendingHabits = await _loadPendingHabits();
    final todayFocusMinutes = await _loadTodayFocusMinutes();
    final recentSummary = await _loadRecentInterventionSummary(null);
    final normalizedProfile = profile.copyWith(
      surveyLanguage: language,
    );
    final eventId =
        '${requestKind.storageValue}:${habit.id}:${DateTime.now().millisecondsSinceEpoch}';

    return CanonicalMessageContext(
      language: language,
      profile: normalizedProfile,
      settings: settings,
      stage: InterventionStage.s0,
      lockState: const LockStatePayload(),
      currentAppPackage: null,
      currentAppName: habit.name,
      appCategory: AppCategory.neutral,
      effectivePolicy: null,
      riskScore: 0,
      ignoredWarningCount: 0,
      focusModeActive: false,
      pendingHabits: pendingHabits,
      recentInterventionCount24h: recentSummary.count,
      lastInterventionStage: recentSummary.lastStage,
      todayFocusMinutes: todayFocusMinutes,
      runtimeEventId: eventId,
      payloadSignature: eventId,
    );
  }

  MessageContext toGeneratorContext(
    CanonicalMessageContext context, {
    String? taskName,
    Habit? habit,
  }) {
    return MessageContext(
      currentLanguage: context.language,
      profile: context.profile,
      currentStage: EscalationLevel.values[context.stage.code.clamp(0, 5)],
      distractionScore: context.riskScore,
      currentAppCategory: _legacyBehaviorCategory(context.appCategory),
      ignoredWarningCount: context.ignoredWarningCount,
      focusModeActive: context.focusModeActive,
      contextTaskName: taskName ?? context.primaryPendingHabitName,
      contextHabitType: habit?.type,
      currentAppPackage: context.currentAppPackage,
      currentAppName: context.currentAppName,
      recentInterventionCount24h: context.recentInterventionCount24h,
      todayFocusMinutes: context.todayFocusMinutes,
      strictnessPreference: context.profile.strictnessPreference,
      currentXP: context.profile.currentXP,
      selfControlScore: context.profile.selfControlScore,
    );
  }

  RecommendationContext toRecommendationContext(
    CanonicalMessageContext context,
  ) {
    return RecommendationContext(
      currentLanguage: context.language,
      profile: context.profile,
      timeOfDay: DateTime.now(),
      pendingHabits: context.pendingHabits,
      currentStage: EscalationLevel.values[context.stage.code.clamp(0, 5)],
      settings: context.settings,
      currentAppPackage: context.currentAppPackage,
      currentAppName: context.currentAppName,
      appCategory: context.appCategory,
      recentInterventionCount24h: context.recentInterventionCount24h,
      todayFocusMinutes: context.todayFocusMinutes,
    );
  }

  Future<List<Habit>> _loadPendingHabits() async {
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
    return habits
        .map(
          (row) => Habit(
            id: row['id'] as String,
            name: row['name'] as String,
            type: HabitType.values[row['type'] as int? ?? 0],
            frequency: HabitFrequency.values[row['frequency'] as int? ?? 0],
            currentStreak: row['current_streak'] as int? ?? 0,
            longestStreak: row['longest_streak'] as int? ?? 0,
            completedToday: completedIds.contains(row['id']),
            xpReward: row['xp_reward'] as int? ?? 10,
            sortOrder: row['sort_order'] as int? ?? 0,
            reminderTime: row['reminder_time'] as String?,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              row['created_at'] as int? ??
                  DateTime.now().millisecondsSinceEpoch,
            ),
          ),
        )
        .where((habit) => !habit.completedToday)
        .take(3)
        .toList();
  }

  Future<_RecentInterventionSummary> _loadRecentInterventionSummary(
    String? packageName,
  ) async {
    final since = DateTime.now()
        .subtract(const Duration(hours: 24))
        .millisecondsSinceEpoch;
    final rows = await _db.queryWhere(
      'escalation_events',
      where: packageName == null || packageName.isEmpty
          ? 'timestamp >= ?'
          : 'timestamp >= ? AND package_name = ?',
      whereArgs: packageName == null || packageName.isEmpty
          ? [since]
          : [since, packageName],
      orderBy: 'timestamp DESC',
      limit: 20,
    );
    final count = rows.length;
    final lastStage = rows.isEmpty
        ? null
        : InterventionStage.fromCode(
            rows.first['stage'] as int? ?? rows.first['to_level'] as int? ?? 0,
          );
    return _RecentInterventionSummary(count: count, lastStage: lastStage);
  }

  Future<int> _loadTodayFocusMinutes() async {
    final startOfDay = DateTime.now();
    final since = DateTime(
      startOfDay.year,
      startOfDay.month,
      startOfDay.day,
    ).millisecondsSinceEpoch;
    final rows = await _db.queryWhere(
      'focus_sessions',
      where: 'was_completed = ? AND completed_at >= ?',
      whereArgs: [1, since],
    );
    return rows.fold<int>(
      0,
      (total, row) => total + (row['duration_minutes'] as int? ?? 0),
    );
  }

  LockStatePayload _buildLockStateFromRequest(
    InterventionMessageRequest request,
  ) {
    if (request.interventionStage == InterventionStage.s4) {
      return LockStatePayload(
        reentryCount: request.reentryCount,
        isLimitedAccess: request.isLimitedAccess,
        limitedAccessRemainingSeconds: request.limitedAccessRemainingSec,
        limitedAccessAppPackage: request.packageName,
      );
    }
    if (request.interventionStage.isBlockingStage) {
      return LockStatePayload(
        blockedAppPackage: request.packageName,
        reentryCount: request.reentryCount,
      );
    }
    return LockStatePayload(reentryCount: request.reentryCount);
  }

  AppCategory _resolveAppCategory(
    int appCategoryCode,
    EffectiveAppPolicy? policy,
  ) {
    if (policy?.categoryOverride != null) {
      return AppCategory.fromNativeValue(policy!.categoryOverride!);
    }
    return AppCategory.fromNativeValue(appCategoryCode);
  }

  BehaviorCategory _legacyBehaviorCategory(AppCategory appCategory) {
    switch (appCategory) {
      case AppCategory.productive:
        return BehaviorCategory.productive;
      case AppCategory.distracting:
        return BehaviorCategory.distracting;
      case AppCategory.essential:
        return BehaviorCategory.essential;
      case AppCategory.neutral:
      case AppCategory.userDefined:
        return BehaviorCategory.neutral;
    }
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}

class _RecentInterventionSummary {
  final int count;
  final InterventionStage? lastStage;

  const _RecentInterventionSummary({
    required this.count,
    required this.lastStage,
  });
}
