import '../entities/focus_session.dart';
import '../entities/habit.dart';
import '../entities/progression_ledger_entry.dart';
import '../entities/progression_projection.dart';
import '../entities/user_profile.dart';

abstract final class ProgressionRules {
  const ProgressionRules._();

  static ProgressionLedgerEntry buildLegacySeed(UserProfile profile) {
    return ProgressionLedgerEntry(
      eventKey: 'legacy_profile_seed_v1',
      sourceType: 'migration_seed',
      sourceId: UserProfile.canonicalLocalId,
      effectiveXpDelta: effectiveXpForProfile(profile),
      earnedXpDelta: profile.totalXPEarned,
      selfControlDelta: profile.selfControlScore - 50,
      createdAt: profile.lastActiveAt,
      metadata: {
        'level': profile.level,
        'currentXp': profile.currentXP,
      },
    );
  }

  static ProgressionLedgerEntry buildManualAdjustment({
    required String eventKey,
    required int xpDelta,
    required int selfControlDelta,
    Map<String, dynamic> metadata = const {},
  }) {
    return ProgressionLedgerEntry(
      eventKey: eventKey,
      sourceType: 'manual_adjustment',
      sourceId: eventKey,
      effectiveXpDelta: xpDelta,
      earnedXpDelta: xpDelta > 0 ? xpDelta : 0,
      selfControlDelta: selfControlDelta,
      createdAt: DateTime.now(),
      metadata: metadata,
    );
  }

  static ProgressionLedgerEntry buildHabitCompletion({
    required Habit habit,
    required String dateKey,
    required bool completed,
    required int streakAfterChange,
  }) {
    final xpReward = completed
        ? habit.xpReward + streakBonus(streakAfterChange)
        : -(habit.xpReward + streakBonus((streakAfterChange + 1)));
    final selfControlDelta =
        completed ? (habit.isBreak ? 5 : 4) : -(habit.isBreak ? 5 : 4);

    return ProgressionLedgerEntry(
      eventKey:
          'habit_toggle:${habit.id}:$dateKey:${completed ? 'complete' : 'undo'}',
      sourceType: 'habit_completion',
      sourceId: '${habit.id}:$dateKey',
      effectiveXpDelta: xpReward,
      earnedXpDelta: xpReward > 0 ? xpReward : 0,
      selfControlDelta: selfControlDelta,
      createdAt: DateTime.now(),
      metadata: {
        'habitId': habit.id,
        'habitType': habit.type.name,
        'completed': completed,
        'streakAfterChange': streakAfterChange,
      },
    );
  }

  static ProgressionLedgerEntry? buildFocusCompletion(FocusSession session) {
    if (!session.wasCompleted || session.completedAt == null) return null;
    final selfControlDelta =
        (session.durationMinutes / 10).ceil().clamp(2, 6).toInt();
    return ProgressionLedgerEntry(
      eventKey: 'focus_completion:${session.id}',
      sourceType: 'focus_completion',
      sourceId: session.id,
      effectiveXpDelta: session.xpEarned,
      earnedXpDelta: session.xpEarned > 0 ? session.xpEarned : 0,
      selfControlDelta: selfControlDelta,
      createdAt: session.completedAt!,
      metadata: {
        'durationMinutes': session.durationMinutes,
      },
    );
  }

  static ProgressionLedgerEntry? buildNativeIntervention({
    required String runtimeEventId,
    required int fromLevel,
    required int toLevel,
    required String packageName,
    required int xpPenalty,
    required double riskScore,
    required int reentryCount,
    required DateTime createdAt,
  }) {
    final selfControlDelta = selfControlPenaltyForIntervention(toLevel);
    final effectiveXpDelta = xpPenalty > 0 ? -xpPenalty : 0;

    if (effectiveXpDelta == 0 && selfControlDelta == 0) {
      return null;
    }

    return ProgressionLedgerEntry(
      eventKey: 'native_intervention:$runtimeEventId',
      sourceType: 'native_intervention',
      sourceId: runtimeEventId,
      effectiveXpDelta: effectiveXpDelta,
      earnedXpDelta: 0,
      selfControlDelta: selfControlDelta,
      createdAt: createdAt,
      metadata: {
        'fromLevel': fromLevel,
        'toLevel': toLevel,
        'packageName': packageName,
        'riskScore': riskScore,
        'reentryCount': reentryCount,
      },
    );
  }

  static int effectiveXpForProfile(UserProfile profile) {
    var total = profile.currentXP;
    for (var level = 1; level < profile.level; level++) {
      total += xpRequired(level);
    }
    return total;
  }

  static int xpRequired(int level) => 100 + (level - 1) * 50;

  static int streakBonus(int streak) {
    if (streak == 30) return 100;
    if (streak == 14) return 50;
    if (streak == 7) return 30;
    if (streak == 3) return 15;
    return 0;
  }

  static int selfControlPenaltyForIntervention(int toLevel) {
    switch (toLevel) {
      case 1:
        return -2;
      case 2:
        return -4;
      case 3:
        return -8;
      case 4:
        return -6;
      case 5:
        return -12;
      default:
        return 0;
    }
  }

  static ProgressionProjection projectLedger(
    List<ProgressionLedgerEntry> entries,
  ) {
    return ProgressionProjection.fromLedger(entries, xpRequired: xpRequired);
  }
}
