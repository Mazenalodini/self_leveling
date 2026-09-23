import 'package:equatable/equatable.dart';

/// A Focus Mode session record.
enum FocusSessionStatus {
  running,
  interrupted,
  completed,
}

class FocusSession extends Equatable {
  final String id;
  final int durationMinutes;
  final DateTime startedAt;
  final DateTime? completedAt;
  final bool wasCompleted;
  final int xpEarned;

  const FocusSession({
    required this.id,
    required this.durationMinutes,
    required this.startedAt,
    this.completedAt,
    this.wasCompleted = false,
    this.xpEarned = 0,
  });

  /// Whether the session is currently active.
  bool get isActive => completedAt == null;

  FocusSessionStatus get status {
    if (completedAt == null) return FocusSessionStatus.running;
    return wasCompleted
        ? FocusSessionStatus.completed
        : FocusSessionStatus.interrupted;
  }

  bool get isInterrupted => status == FocusSessionStatus.interrupted;

  /// Elapsed time since session started.
  Duration get elapsed => DateTime.now().difference(startedAt);

  /// Total planned duration.
  Duration get totalDuration => Duration(minutes: durationMinutes);

  /// Actual elapsed duration grounded in the recorded session facts.
  Duration get actualDuration {
    final end = completedAt ?? DateTime.now();
    final elapsed = end.difference(startedAt);
    if (elapsed.isNegative) return Duration.zero;
    final max = totalDuration;
    return elapsed > max ? max : elapsed;
  }

  int get actualFocusedSeconds => actualDuration.inSeconds;

  /// Remaining time (0 if completed).
  int get remainingSeconds {
    if (!isActive) return 0;
    final remaining = totalDuration.inSeconds - elapsed.inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  /// Progress 0.0 → 1.0.
  double get progress {
    if (totalDuration.inSeconds == 0) return 0;
    final p = elapsed.inSeconds / totalDuration.inSeconds;
    return p.clamp(0.0, 1.0);
  }

  FocusSession copyWith({
    DateTime? completedAt,
    bool? wasCompleted,
    int? xpEarned,
  }) {
    return FocusSession(
      id: id,
      durationMinutes: durationMinutes,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
      wasCompleted: wasCompleted ?? this.wasCompleted,
      xpEarned: xpEarned ?? this.xpEarned,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'durationMinutes': durationMinutes,
        'startedAt': startedAt.millisecondsSinceEpoch,
        'completedAt': completedAt?.millisecondsSinceEpoch,
        'wasCompleted': wasCompleted,
        'xpEarned': xpEarned,
      };

  factory FocusSession.fromMap(Map<dynamic, dynamic> map) => FocusSession(
        id: map['id'] as String,
        durationMinutes: map['durationMinutes'] as int,
        startedAt: DateTime.fromMillisecondsSinceEpoch(map['startedAt'] as int),
        completedAt: map['completedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'] as int)
            : null,
        wasCompleted: map['wasCompleted'] as bool? ?? false,
        xpEarned: map['xpEarned'] as int? ?? 0,
      );

  @override
  List<Object?> get props => [id, startedAt, wasCompleted];
}
