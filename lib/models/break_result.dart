import '../engine/engine_contract.dart';
import 'break_outcome.dart';
import 'break_position.dart';
import 'cue_english.dart';
import 'table_size.dart';

/// One measured break, as stored in the local database.
///
/// Schema discipline (same rule as the tester): [schemaVersion] bumps on any
/// field change; old rows are never rewritten; readers handle every version
/// that has ever existed.
///
/// v1 → v2 (2026-07-28) added the break position, the english put on the
/// ball, and the optional outcome card. v1 rows keep nulls for all three,
/// which is honest: those breaks were recorded before any of it existed.
class BreakResult {
  static const int currentSchemaVersion = 2;

  const BreakResult({
    this.id,
    required this.sessionId,
    required this.recordedAt,
    required this.tableSize,
    required this.travelDistanceInches,
    required this.preset,
    required this.engineVersion,
    required this.grade,
    required this.detectedPairValid,
    this.position,
    this.english,
    this.outcome,
    this.tipTimestampMs,
    this.rackTimestampMs,
    this.gapMs,
    this.speedMph,
    this.confidence,
    this.schemaVersion = currentSchemaVersion,
  });

  /// Database row id; null until inserted.
  final int? id;
  final int sessionId;
  final DateTime recordedAt;
  final TableSize tableSize;

  /// The distance actually handed to the engine — derived from [position]
  /// when there is one, or the head-string-centre preset / manual value.
  final double travelDistanceInches;
  final SensitivityPreset preset;
  final String engineVersion;
  final AccuracyGrade grade;
  final bool detectedPairValid;

  /// Where the cue ball sat when the break was struck. Null on v1 rows.
  final BreakPosition? position;

  /// The english the player put on the ball. An input, not an outcome, and
  /// never part of the score — an analysis dimension only.
  final CueEnglish? english;

  /// The optional outcome card. Null when skipped — such a break still counts
  /// for speed, consistency and reliability, but has no Break Score.
  final BreakOutcome? outcome;

  final double? tipTimestampMs;
  final double? rackTimestampMs;
  final double? gapMs;

  /// Null when the engine graded the break unreliable.
  final double? speedMph;
  final double? confidence;
  final int schemaVersion;

  /// Whether this break carries a speed the user can trust.
  bool get hasSpeed => speedMph != null && grade != AccuracyGrade.unreliable;

  /// Short label for the break position, e.g. "Right rail".
  String? get positionLabel => position?.label;

  /// Short label for the english, e.g. "Draw left".
  String? get englishLabel => english?.label;

  BreakResult copyWith({int? id, BreakOutcome? outcome}) => BreakResult(
    id: id ?? this.id,
    sessionId: sessionId,
    recordedAt: recordedAt,
    tableSize: tableSize,
    travelDistanceInches: travelDistanceInches,
    preset: preset,
    engineVersion: engineVersion,
    grade: grade,
    detectedPairValid: detectedPairValid,
    position: position,
    english: english,
    outcome: outcome ?? this.outcome,
    tipTimestampMs: tipTimestampMs,
    rackTimestampMs: rackTimestampMs,
    gapMs: gapMs,
    speedMph: speedMph,
    confidence: confidence,
    schemaVersion: schemaVersion,
  );

  factory BreakResult.fromEngine({
    required int sessionId,
    required DateTime recordedAt,
    required TableSize tableSize,
    required double travelDistanceInches,
    required SensitivityPreset preset,
    required EngineResult result,
    BreakPosition? position,
    CueEnglish? english,
    BreakOutcome? outcome,
  }) => BreakResult(
    sessionId: sessionId,
    recordedAt: recordedAt,
    tableSize: tableSize,
    travelDistanceInches: travelDistanceInches,
    preset: preset,
    engineVersion: result.engineVersion,
    grade: result.grade,
    detectedPairValid: result.detectedPairValid,
    position: position,
    english: english,
    outcome: outcome,
    tipTimestampMs: result.tipTimestampMs,
    rackTimestampMs: result.rackTimestampMs,
    gapMs: result.gapMs,
    speedMph: result.speedMph,
    confidence: result.confidence,
  );

  Map<String, Object?> toDbMap() => {
    if (id != null) 'id': id,
    'session_id': sessionId,
    'recorded_at': recordedAt.toIso8601String(),
    'table_size': tableSize.id,
    'travel_distance_inches': travelDistanceInches,
    'preset': preset.label,
    'engine_version': engineVersion,
    'grade': grade.label,
    'detected_pair_valid': detectedPairValid ? 1 : 0,
    'start_x': position?.x,
    'start_y': position?.y,
    'english_x': english?.x,
    'english_y': english?.y,
    'balls_made': outcome?.ballsMade,
    'scratched': outcome == null ? null : (outcome!.scratched ? 1 : 0),
    'spread': outcome?.spread.label,
    'cue_ball_after': outcome?.cueBallAfter.label,
    'tip_timestamp_ms': tipTimestampMs,
    'rack_timestamp_ms': rackTimestampMs,
    'gap_ms': gapMs,
    'speed_mph': speedMph,
    'confidence': confidence,
    'schema_version': schemaVersion,
  };

  factory BreakResult.fromDbMap(Map<String, Object?> map) {
    final sx = (map['start_x'] as num?)?.toDouble();
    final sy = (map['start_y'] as num?)?.toDouble();
    final ex = (map['english_x'] as num?)?.toDouble();
    final ey = (map['english_y'] as num?)?.toDouble();
    final balls = map['balls_made'] as int?;
    final scratched = map['scratched'] as int?;
    final spread = map['spread'] as String?;
    final after = map['cue_ball_after'] as String?;

    // An outcome exists only when the card was actually filled in.
    final hasOutcome =
        balls != null && scratched != null && spread != null && after != null;

    return BreakResult(
      id: map['id'] as int?,
      sessionId: map['session_id'] as int,
      recordedAt: DateTime.parse(map['recorded_at'] as String),
      tableSize: TableSize.fromId(map['table_size'] as String),
      travelDistanceInches: (map['travel_distance_inches'] as num).toDouble(),
      preset: SensitivityPreset.fromLabel(map['preset'] as String),
      engineVersion: map['engine_version'] as String,
      grade: AccuracyGrade.fromLabel(map['grade'] as String),
      detectedPairValid: (map['detected_pair_valid'] as int) == 1,
      position: (sx == null || sy == null) ? null : BreakPosition(x: sx, y: sy),
      english: (ex == null || ey == null) ? null : CueEnglish(x: ex, y: ey),
      outcome: hasOutcome
          ? BreakOutcome(
              ballsMade: balls,
              scratched: scratched == 1,
              spread: SpreadQuality.fromLabel(spread),
              cueBallAfter: CueBallAfter.fromLabel(after),
            )
          : null,
      tipTimestampMs: (map['tip_timestamp_ms'] as num?)?.toDouble(),
      rackTimestampMs: (map['rack_timestamp_ms'] as num?)?.toDouble(),
      gapMs: (map['gap_ms'] as num?)?.toDouble(),
      speedMph: (map['speed_mph'] as num?)?.toDouble(),
      confidence: (map['confidence'] as num?)?.toDouble(),
      schemaVersion: map['schema_version'] as int? ?? 1,
    );
  }
}
