import 'break_outcome.dart';
import 'table_size.dart';

/// One visit to the table: a group of breaks recorded together.
///
/// v1 → v2 (2026-07-28) added [gameType]. v1 rows default to 8-ball.
class Session {
  static const int currentSchemaVersion = 2;

  const Session({
    this.id,
    required this.startedAt,
    this.endedAt,
    required this.tableSize,
    this.gameType = GameType.eightBall,
    this.notes = '',
    this.schemaVersion = currentSchemaVersion,
  });

  final int? id;
  final DateTime startedAt;

  /// Null while the session is still open.
  final DateTime? endedAt;
  final TableSize tableSize;
  final GameType gameType;
  final String notes;
  final int schemaVersion;

  bool get isOpen => endedAt == null;

  Session copyWith({
    int? id,
    DateTime? endedAt,
    GameType? gameType,
    String? notes,
  }) =>
      Session(
        id: id ?? this.id,
        startedAt: startedAt,
        endedAt: endedAt ?? this.endedAt,
        tableSize: tableSize,
        gameType: gameType ?? this.gameType,
        notes: notes ?? this.notes,
        schemaVersion: schemaVersion,
      );

  Map<String, Object?> toDbMap() => {
        if (id != null) 'id': id,
        'started_at': startedAt.toIso8601String(),
        'ended_at': endedAt?.toIso8601String(),
        'table_size': tableSize.id,
        'game_type': gameType.label,
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
        gameType: map['game_type'] == null
            ? GameType.eightBall
            : GameType.fromLabel(map['game_type'] as String),
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
    this.averageBreakScore,
    this.scratches = 0,
    this.averageBallsMade,
  });

  final int breakCount;
  final int reliableCount;
  final double? bestMph;
  final double? averageMph;

  /// Average Break Score across breaks that have one. Null when no break in
  /// the session had its outcome card filled in.
  final double? averageBreakScore;
  final int scratches;
  final double? averageBallsMade;
}
