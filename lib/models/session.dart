import 'table_size.dart';

/// One visit to the table: a group of breaks recorded together.
class Session {
  static const int currentSchemaVersion = 1;

  const Session({
    this.id,
    required this.startedAt,
    this.endedAt,
    required this.tableSize,
    this.notes = '',
    this.schemaVersion = currentSchemaVersion,
  });

  final int? id;
  final DateTime startedAt;

  /// Null while the session is still open.
  final DateTime? endedAt;
  final TableSize tableSize;
  final String notes;
  final int schemaVersion;

  bool get isOpen => endedAt == null;

  Session copyWith({int? id, DateTime? endedAt, String? notes}) => Session(
        id: id ?? this.id,
        startedAt: startedAt,
        endedAt: endedAt ?? this.endedAt,
        tableSize: tableSize,
        notes: notes ?? this.notes,
        schemaVersion: schemaVersion,
      );

  Map<String, Object?> toDbMap() => {
        if (id != null) 'id': id,
        'started_at': startedAt.toIso8601String(),
        'ended_at': endedAt?.toIso8601String(),
        'table_size': tableSize.id,
        'notes': notes,
        'schema_version': schemaVersion,
      };

  factory Session.fromDbMap(Map<String, Object?> map) => Session(
        id: map['id'] as int?,
        startedAt: DateTime.parse(map['started_at'] as String),
        endedAt: map['ended_at'] == null
            ? null
            : DateTime.parse(map['ended_at'] as String),
        tableSize: TableSize.fromId(map['table_size'] as String),
        notes: map['notes'] as String? ?? '',
        schemaVersion: map['schema_version'] as int? ?? 1,
      );
}

/// Aggregate numbers for a session, computed from its stored breaks —
/// never stored, so they can't drift out of sync with the data.
class SessionStats {
  const SessionStats({
    required this.breakCount,
    required this.reliableCount,
    this.bestMph,
    this.averageMph,
  });

  final int breakCount;
  final int reliableCount;
  final double? bestMph;
  final double? averageMph;
}
