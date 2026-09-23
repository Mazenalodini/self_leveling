import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../../domain/entities/focus_session.dart';
import '../../domain/entities/habit.dart';
import '../../domain/entities/progression_ledger_entry.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/services/progression_rules.dart';
import 'local_profile_repository.dart';

class ProgressionRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final LocalProfileRepository _localProfileRepository =
      LocalProfileRepository();

  Future<UserProfile> getProjectedProfile() async {
    await _ensureLegacySeededIfNeeded();
    await syncNativeInterventionFacts();
    return _rebuildProjection();
  }

  Future<UserProfile> awardXP(int amount) async {
    await _recordManualAdjustment(
      eventKey: 'manual_xp:${DateTime.now().millisecondsSinceEpoch}:$amount',
      xpDelta: amount,
      selfControlDelta: 0,
      metadata: {'kind': 'xp_adjustment'},
    );
    return getProjectedProfile();
  }

  Future<UserProfile> penalizeXP(int amount) async {
    return awardXP(-amount.abs());
  }

  Future<UserProfile> updateSelfControlScore(int newScore) async {
    final profile = await getProjectedProfile();
    final delta = newScore.clamp(0, 100) - profile.selfControlScore;
    await _recordManualAdjustment(
      eventKey:
          'manual_self_control:${DateTime.now().millisecondsSinceEpoch}:$newScore',
      xpDelta: 0,
      selfControlDelta: delta,
      metadata: {'kind': 'self_control_adjustment'},
    );
    return getProjectedProfile();
  }

  Future<UserProfile> recordHabitCompletion({
    required Habit habit,
    required String dateKey,
    required bool completed,
    required int streakAfterChange,
  }) async {
    final entry = ProgressionRules.buildHabitCompletion(
      habit: habit,
      dateKey: dateKey,
      completed: completed,
      streakAfterChange: streakAfterChange,
    );
    await _storeLedgerEntry(entry);
    return _rebuildProjection();
  }

  Future<UserProfile> recordFocusCompletion(FocusSession session) async {
    final entry = ProgressionRules.buildFocusCompletion(session);
    if (entry != null) {
      await _storeLedgerEntry(entry);
    }
    return _rebuildProjection();
  }

  Future<void> syncNativeInterventionFacts() async {
    await _ensureLegacySeededIfNeeded();
    final db = await _db.database;
    final rows = await db.query(
      'escalation_events',
      where: 'created_by = ? AND runtime_event_id IS NOT NULL',
      whereArgs: ['native'],
      orderBy: 'timestamp ASC',
    );

    for (final row in rows) {
      final runtimeEventId = row['runtime_event_id'] as String?;
      if (runtimeEventId == null || runtimeEventId.isEmpty) continue;

      final entry = ProgressionRules.buildNativeIntervention(
        runtimeEventId: runtimeEventId,
        fromLevel: row['from_level'] as int? ?? 0,
        toLevel: row['to_level'] as int? ?? row['stage'] as int? ?? 0,
        packageName: row['package_name'] as String? ?? '',
        xpPenalty: row['xp_penalty'] as int? ?? 0,
        riskScore: (row['risk_score'] as num?)?.toDouble() ?? 0.0,
        reentryCount: row['reentry_count'] as int? ?? 0,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row['timestamp'] as int? ?? 0,
        ),
      );
      if (entry == null) continue;
      await _storeLedgerEntry(entry);
    }
  }

  Future<List<ProgressionLedgerEntry>> getLedgerEntries() async {
    await _ensureLegacySeededIfNeeded();
    final rows = await _db.queryWhere(
      'progression_ledger',
      orderBy: 'created_at ASC, id ASC',
    );
    return rows.map(ProgressionLedgerEntry.fromRow).toList();
  }

  int xpForLevel(int level) => ProgressionRules.xpRequired(level);

  Future<void> _recordManualAdjustment({
    required String eventKey,
    required int xpDelta,
    required int selfControlDelta,
    Map<String, dynamic> metadata = const {},
  }) async {
    await _ensureLegacySeededIfNeeded();
    final entry = ProgressionRules.buildManualAdjustment(
      eventKey: eventKey,
      xpDelta: xpDelta,
      selfControlDelta: selfControlDelta,
      metadata: metadata,
    );
    await _storeLedgerEntry(entry);
  }

  Future<void> _ensureLegacySeededIfNeeded() async {
    final existing = await _db.count('progression_ledger');
    if (existing > 0) return;

    final profile = await _localProfileRepository.getOrCreateCanonicalProfile();
    final seed = ProgressionRules.buildLegacySeed(profile);
    await _storeLedgerEntry(seed);
  }

  Future<void> _storeLedgerEntry(ProgressionLedgerEntry entry) async {
    final db = await _db.database;
    await db.insert(
      'progression_ledger',
      entry.toRow(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<UserProfile> _rebuildProjection() async {
    final profile = await _localProfileRepository.getOrCreateCanonicalProfile();
    final entries = await getLedgerEntries();
    final projection = ProgressionRules.projectLedger(entries);
    final updated = profile.copyWith(
      level: projection.level,
      currentXP: projection.currentXP,
      totalXPEarned: projection.totalEarnedXP,
      selfControlScore: projection.selfControlScore,
      lastActiveAt: projection.lastEventAt ?? profile.lastActiveAt,
    );
    await _localProfileRepository.saveCanonicalProfile(updated);
    return updated;
  }
}
