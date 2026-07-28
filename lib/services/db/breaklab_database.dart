import 'package:sqflite/sqflite.dart';

import '../../engine/engine_contract.dart';
import '../../models/break_result.dart';
import '../../models/session.dart';

/// Local-first storage for BreakLab v1. Guest-only: everything lives on the
/// phone; no accounts, no network.
///
/// Database schema versioning follows the project rule: any change bumps
/// [dbVersion] with an explicit migration in [_onUpgrade]; existing rows are
/// migrated, never silently rewritten to mean something different.
class BreakLabDatabase {
  BreakLabDatabase(this._db);

  static const int dbVersion = 1;

  final Database _db;

  static Future<BreakLabDatabase> open(
    String path, {
    DatabaseFactory? factory,
  }) async {
    final f = factory ?? databaseFactory;
    final db = await f.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
    return BreakLabDatabase(db);
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        started_at TEXT NOT NULL,
        ended_at TEXT,
        table_size TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        schema_version INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE breaks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL REFERENCES sessions(id),
        recorded_at TEXT NOT NULL,
        table_size TEXT NOT NULL,
        travel_distance_inches REAL NOT NULL,
        preset TEXT NOT NULL,
        engine_version TEXT NOT NULL,
        grade TEXT NOT NULL,
        detected_pair_valid INTEGER NOT NULL,
        tip_timestamp_ms REAL,
        rack_timestamp_ms REAL,
        gap_ms REAL,
        speed_mph REAL,
        confidence REAL,
        schema_version INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_breaks_session ON breaks(session_id)');
    await db
        .execute('CREATE INDEX idx_breaks_recorded_at ON breaks(recorded_at)');
  }

  static Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    // v1 is the first schema. Future migrations stack here, in order:
    // if (oldVersion < 2) { ... }
  }

  Future<void> close() => _db.close();

  // ---------- sessions ----------

  Future<Session> insertSession(Session session) async {
    final id = await _db.insert('sessions', session.toDbMap());
    return session.copyWith(id: id);
  }

  Future<void> endSession(int sessionId, DateTime endedAt) async {
    await _db.update(
      'sessions',
      {'ended_at': endedAt.toIso8601String()},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<Session?> openSession() async {
    final rows = await _db.query(
      'sessions',
      where: 'ended_at IS NULL',
      orderBy: 'started_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : Session.fromDbMap(rows.first);
  }

  Future<List<Session>> sessions({int? limit}) async {
    final rows =
        await _db.query('sessions', orderBy: 'started_at DESC', limit: limit);
    return rows.map(Session.fromDbMap).toList();
  }

  Future<SessionStats> sessionStats(int sessionId) async {
    final rows = await _db.rawQuery('''
      SELECT COUNT(*) AS n,
             SUM(CASE WHEN speed_mph IS NOT NULL
                       AND grade != 'Unreliable' THEN 1 ELSE 0 END) AS reliable,
             MAX(CASE WHEN grade != 'Unreliable' THEN speed_mph END) AS best,
             AVG(CASE WHEN grade != 'Unreliable' THEN speed_mph END) AS avg
      FROM breaks WHERE session_id = ?
    ''', [sessionId]);
    final row = rows.first;
    return SessionStats(
      breakCount: row['n'] as int? ?? 0,
      reliableCount: row['reliable'] as int? ?? 0,
      bestMph: (row['best'] as num?)?.toDouble(),
      averageMph: (row['avg'] as num?)?.toDouble(),
    );
  }

  // ---------- breaks ----------

  Future<BreakResult> insertBreak(BreakResult b) async {
    final id = await _db.insert('breaks', b.toDbMap());
    return b.copyWith(id: id);
  }

  Future<List<BreakResult>> breaksForSession(int sessionId) async {
    final rows = await _db.query(
      'breaks',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'recorded_at ASC',
    );
    return rows.map(BreakResult.fromDbMap).toList();
  }

  Future<List<BreakResult>> allBreaks(
      {int? limit, AccuracyGrade? gradeAtLeast}) async {
    final rows = await _db.query(
      'breaks',
      orderBy: 'recorded_at DESC',
      limit: limit,
    );
    var results = rows.map(BreakResult.fromDbMap);
    if (gradeAtLeast != null) {
      results = results
          .where((b) => b.grade.index <= gradeAtLeast.index && b.hasSpeed);
    }
    return results.toList();
  }

  /// Personal records, computed live from stored breaks. Unreliable breaks
  /// never count toward records.
  Future<PersonalRecords> personalRecords() async {
    final fastest = await _db.rawQuery('''
      SELECT * FROM breaks
      WHERE grade != 'Unreliable' AND speed_mph IS NOT NULL
      ORDER BY speed_mph DESC LIMIT 1
    ''');
    final bestSession = await _db.rawQuery('''
      SELECT session_id, AVG(speed_mph) AS avg_mph, COUNT(*) AS n
      FROM breaks
      WHERE grade != 'Unreliable' AND speed_mph IS NOT NULL
      GROUP BY session_id HAVING n >= 3
      ORDER BY avg_mph DESC LIMIT 1
    ''');
    return PersonalRecords(
      fastestBreak:
          fastest.isEmpty ? null : BreakResult.fromDbMap(fastest.first),
      bestSessionId:
          bestSession.isEmpty ? null : bestSession.first['session_id'] as int,
      bestSessionAverageMph: bestSession.isEmpty
          ? null
          : (bestSession.first['avg_mph'] as num).toDouble(),
    );
  }
}

class PersonalRecords {
  const PersonalRecords({
    this.fastestBreak,
    this.bestSessionId,
    this.bestSessionAverageMph,
  });

  final BreakResult? fastestBreak;
  final int? bestSessionId;

  /// Best session average, sessions with at least 3 reliable breaks.
  final double? bestSessionAverageMph;
}
