import 'package:equatable/equatable.dart';

/// Escalation event record read from SQLite.
/// The native EscalationEvaluator writes these; Flutter reads for display.
class EscalationEventRecord extends Equatable {
  final int fromLevel;
  final int toLevel;
  final DateTime timestamp;
  final String reason;

  const EscalationEventRecord({
    required this.fromLevel,
    required this.toLevel,
    required this.timestamp,
    required this.reason,
  });

  factory EscalationEventRecord.fromMap(Map<String, dynamic> map) =>
      EscalationEventRecord(
        fromLevel: map['from_level'] as int,
        toLevel: map['to_level'] as int,
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
        reason: map['reason'] as String? ?? '',
      );

  /// Whether this was an escalation (level went up).
  bool get isEscalation => toLevel > fromLevel;

  /// Whether this was a de-escalation (level went down).
  bool get isDeescalation => toLevel < fromLevel;

  /// Stage label for UI display (e.g., "S0 → S3").
  String get transitionLabel => 'S$fromLevel → S$toLevel';

  @override
  List<Object?> get props => [fromLevel, toLevel, timestamp];
}
