import 'dart:convert';

class ProgressionLedgerEntry {
  final String eventKey;
  final String sourceType;
  final String sourceId;
  final int effectiveXpDelta;
  final int earnedXpDelta;
  final int selfControlDelta;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  const ProgressionLedgerEntry({
    required this.eventKey,
    required this.sourceType,
    required this.sourceId,
    required this.effectiveXpDelta,
    required this.earnedXpDelta,
    required this.selfControlDelta,
    required this.createdAt,
    this.metadata = const {},
  });

  factory ProgressionLedgerEntry.fromRow(Map<String, dynamic> row) {
    return ProgressionLedgerEntry(
      eventKey: row['event_key'] as String? ?? '',
      sourceType: row['source_type'] as String? ?? '',
      sourceId: row['source_id'] as String? ?? '',
      effectiveXpDelta: row['effective_xp_delta'] as int? ?? 0,
      earnedXpDelta: row['earned_xp_delta'] as int? ?? 0,
      selfControlDelta: row['self_control_delta'] as int? ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row['created_at'] as int? ?? 0,
      ),
      metadata: _decodeMetadata(row['metadata_json']),
    );
  }

  Map<String, dynamic> toRow() => {
        'event_key': eventKey,
        'source_type': sourceType,
        'source_id': sourceId,
        'effective_xp_delta': effectiveXpDelta,
        'earned_xp_delta': earnedXpDelta,
        'self_control_delta': selfControlDelta,
        'created_at': createdAt.millisecondsSinceEpoch,
        'metadata_json': jsonEncode(metadata),
      };

  static Map<String, dynamic> _decodeMetadata(dynamic raw) {
    if (raw == null || raw.toString().isEmpty) return const {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw as String));
    } catch (_) {
      return const {};
    }
  }
}
