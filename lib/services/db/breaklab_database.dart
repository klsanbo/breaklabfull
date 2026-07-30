import 'package:sqflite/sqflite.dart';

import '../../engine/engine_contract.dart';
import '../../models/break_result.dart';
import '../../models/session.dart';
import '../../scoring/break_score.dart';
import '../../scoring/breaklab_score.dart';

/// Local-first storage for BreakLab v1. Guest-only: everything lives on the
/// phone; no accounts, no network.
///
/// Database versioning follows the project rule: any change bumps [dbVersion]
/// with an explicit migration in [_onUpgrade]; existing rows are migrated,
/// never silently rewritten to mean something different.
///
///   v1 — sessions + breaks
///   v2 — break position, cue english, outcome card, session game type
class BreakLabDatabase {
  BreakLabDatabase(this._db);

  static const int dbVersion = 2;

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
        game_type TEXT,
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
        start_x REAL,
        start_y REAL,
        english_x REAL,
        english_y REAL,
        balls_made INTEGER,
        scratched INTEGER,
        spread TEXT,
        cue_ball_after TEXT,
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
    if (oldVersion < 2) {
      // v1 rows keep NULL position and NULL outcome — honest, because those
      // breaks predate both features. They score speed-only forever.
      for (final column in const [
        'start_x REAL',
        'start_y REAL',
        'english_x REAL',
        'english_y REAL',
        'balls_made INTEGER',
        'scratched INTEGER',
        'spread TEXT',
        'cue_ball_after TEXT',
      ]) {
        await db.execute('ALTER TABLE breaks ADD COLUMN $column');
      }
      await db.execute('ALTER TABLE sessions ADD COLUMN game_type TEXT');
    }
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

  /// Session aggregates, computed from the stored breaks every time.
  Future<SessionStats> sessionStats(int sessionId) async {
    final breaks = await breaksForSession(sessionId);
    return statsFor(breaks);
  }

  static SessionStats statsFor(List<BreakResult> breaks) {
    final reliable = breaks.where((b) => b.hasSpeed).toList();
    final scores = breaks
        .map(BreakScore.forBreak)
        .whereType<int>()
        .toList(growable: false);
    final scored = breaks.where((b) => b.outcome != null).toList();

    double? mean(Iterable<double> xs) {
      if (xs.isEmpty) return null;
      return xs.reduce((a, b) => a + b) / xs.length;
    }

    return SessionStats(
      breakCount: breaks.length,
      reliableCount: reliable.length,
      bestMph: reliable.isEmpty
          ? null
          : reliable.map((b) => b.speedMph!).reduce((a, b) => a > b ? a : b),
      averageMph: mean(reliable.map((b) => b.speedMph!)),
      averageBreakScore: mean(scores.map((s) => s.toDouble())),
      scratches: scored.where((b) => b.outcome!.scratched).length,
      averageBallsMade:
          mean(scored.map((b) => b.outcome!.ballsMade.toDouble())),
    );
  }

  // ---------- breaks ----------

  Future<BreakResult> insertBreak(BreakResult b) async {
    final id = await _db.insert('breaks', b.toDbMap());
    return b.copyWith(id: id);
  }

  /// Attaches (or replaces) the outcome card for a break already saved.
  Future<void> updateOutcome(BreakResult b) async {
    await _db.update(
      'breaks',
      {
        'balls_made': b.outcome?.ballsMade,
        'scratched': b.outcome == null ? null : (b.outcome!.scratched ? 1 : 0),
        'spread': b.outcome?.spread.label,
        'cue_ball_after': b.outcome?.cueBallAfter.label,
      },
      where: 'id = ?',
      whereArgs: [b.id],
    );
  }

  Future<void> deleteBreak(int id) async {
    await _db.delete('breaks', where: 'id = ?', whereArgs: [id]);
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

  /// The last [BreakLabScore.sessionWindow] sessions' breaks, newest first —
  /// the input the BreakLab Score is computed from.
  Future<List<List<BreakResult>>> recentSessionBreaks(
      {int limit = BreakLabScore.sessionWindow}) async {
    final recent = await sessions(limit: limit);
    final out = <List<BreakResult>>[];
    for (final s in recent) {
      out.add(await breaksForSession(s.id!));
    }
    return out;
  }

  Future<BreakLabScore> breakLabScore() async =>
      BreakLabScore.fromSessions(await recentSessionBreaks());

  /// Personal records, computed live from stored breaks. Unreliable breaks
  /// never count toward records.
  /// Every break ever recorded, whether or not it produced a speed or an
  /// outcome. This is a count of attempts, not of measurements.
  Future<int> totalBreaks() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS n FROM breaks');
    return (rows.first['n'] as num).toInt();
  }

  /// Scratches as a share of the breaks a player actually told us about.
  ///
  /// The denominator is breaks with an outcome recorded, NOT all breaks. You
  /// cannot know whether a break scratched if nobody filled the card in, and
  /// counting those as clean would quietly flatter the number.
  ///
  /// Null when no outcome has ever been recorded — a rate over no data is not
  /// zero, it is unknown.
  Future<double?> scratchRate() async {
    final rows = await _db.rawQuery('''
      SELECT COUNT(*) AS n, SUM(scratched) AS scratches
      FROM breaks WHERE scratched IS NOT NULL
    ''');
    final n = (rows.first['n'] as num).toInt();
    if (n == 0) return null;
    final scratches = (rows.first['scratches'] as num?)?.toDouble() ?? 0;
    return scratches / n * 100;
  }

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

    // Highest Break Score has to be computed in Dart — the score isn't
    // stored, by design.
    BreakResult? bestScored;
    var bestScore = -1;
    for (final b in await allBreaks()) {
      final s = BreakScore.forBreak(b);
      if (s != null && s > bestScore) {
        bestScore = s;
        bestScored = b;
      }
    }

    return PersonalRecords(
      fastestBreak:
          fastest.isEmpty ? null : BreakResult.fromDbMap(fastest.first),
      bestSessionId:
          bestSession.isEmpty ? null : bestSession.first['session_id'] as int,
      bestSessionAverageMph: bestSession.isEmpty
          ? null
          : (bestSession.first['avg_mph'] as num).toDouble(),
      highestBreakScore: bestScore < 0 ? null : bestScore,
      highestScoredBreak: bestScored,
    );
  }
}

class PersonalRecords {
  const PersonalRecords({
    this.fastestBreak,
    this.bestSessionId,
    this.bestSessionAverageMph,
    this.highestBreakScore,
    this.highestScoredBreak,
  });

  final BreakResult? fastestBreak;
  final int? bestSessionId;

  /// Best session average, sessions with at least 3 reliable breaks.
  final double? bestSessionAverageMph;

  final int? highestBreakScore;
  final BreakResult? highestScoredBreak;
}
