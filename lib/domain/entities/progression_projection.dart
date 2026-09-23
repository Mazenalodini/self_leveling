import 'progression_ledger_entry.dart';

class ProgressionProjection {
  final int level;
  final int currentXP;
  final int totalEarnedXP;
  final int selfControlScore;
  final DateTime? lastEventAt;

  const ProgressionProjection({
    required this.level,
    required this.currentXP,
    required this.totalEarnedXP,
    required this.selfControlScore,
    required this.lastEventAt,
  });

  static const baseline = ProgressionProjection(
    level: 1,
    currentXP: 0,
    totalEarnedXP: 0,
    selfControlScore: 50,
    lastEventAt: null,
  );

  factory ProgressionProjection.fromLedger(
    List<ProgressionLedgerEntry> entries, {
    required int Function(int level) xpRequired,
  }) {
    var effectiveXp = 0;
    var totalEarnedXp = 0;
    var selfControl = 50;
    DateTime? lastEventAt;

    for (final entry in entries) {
      effectiveXp += entry.effectiveXpDelta;
      totalEarnedXp += entry.earnedXpDelta;
      selfControl += entry.selfControlDelta;
      if (lastEventAt == null || entry.createdAt.isAfter(lastEventAt)) {
        lastEventAt = entry.createdAt;
      }
    }

    effectiveXp = effectiveXp.clamp(0, 1 << 30);
    totalEarnedXp = totalEarnedXp.clamp(0, 1 << 30);
    selfControl = selfControl.clamp(0, 100);

    var level = 1;
    var currentXP = effectiveXp;
    while (currentXP >= xpRequired(level)) {
      currentXP -= xpRequired(level);
      level++;
    }

    return ProgressionProjection(
      level: level,
      currentXP: currentXP,
      totalEarnedXP: totalEarnedXp,
      selfControlScore: selfControl,
      lastEventAt: lastEventAt,
    );
  }
}
