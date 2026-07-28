import '../engine/engine_contract.dart';
import 'table_size.dart';

/// One measured break, as stored in the local database.
///
/// Schema discipline (same rule as the tester): [schemaVersion] bumps on any
/// field change; old rows are never rewritten; readers handle every version
/// that has ever existed.
class BreakResult {
  static const int currentSchemaVersion = 1;

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
  final double travelDistanceInches;
  final SensitivityPreset preset;
  final String engineVersion;
  final AccuracyGrade grade;
  final bool detectedPairValid;
  final double? tipTimestampMs;
  final double? rackTimestampMs;
  final double? gapMs;

  /// Null when the engine graded the break unreliable.
  final double? speedMph;
  final double? confidence;
  final int schemaVersion;

  /// Whether this break carries a speed the user can trust.
  bool get hasSpeed => speedMph != null && grade != AccuracyGrade.unreliable;

  BreakResult copyWith({int? id}) => BreakResult(
        id: id ?? this.id,
        sessionId: sessionId,
        recordedAt: recordedAt,
        tableSize: tableSize,
        travelDistanceInches: travelDistanceInches,
        preset: preset,
        engineVersion: engineVersion,
        grade: grade,
        detectedPairValid: detectedPairValid,
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
  }) =>
      BreakResult(
        sessionId: sessionId,
        recordedAt: recordedAt,
        tableSize: tableSize,
        travelDistanceInches: travelDistanceInches,
        preset: preset,
        engineVersion: result.engineVersion,
        grade: result.grade,
        detectedPairValid: result.detectedPairValid,
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
        'tip_timestamp_ms': tipTimestampMs,
        'rack_timestamp_ms': rackTimestampMs,
        'gap_ms': gapMs,
        'speed_mph': speedMph,
        'confidence': confidence,
        'schema_version': schemaVersion,
      };

  factory BreakResult.fromDbMap(Map<String, Object?> map) => BreakResult(
        id: map['id'] as int?,
        sessionId: map['session_id'] as int,
        recordedAt: DateTime.parse(map['recorded_at'] as String),
        tableSize: TableSize.fromId(map['table_size'] as String),
        travelDistanceInches: (map['travel_distance_inches'] as num).toDouble(),
        preset: SensitivityPreset.fromLabel(map['preset'] as String),
        engineVersion: map['engine_version'] as String,
        grade: AccuracyGrade.fromLabel(map['grade'] as String),
        detectedPairValid: (map['detected_pair_valid'] as int) == 1,
        tipTimestampMs: (map['tip_timestamp_ms'] as num?)?.toDouble(),
        rackTimestampMs: (map['rack_timestamp_ms'] as num?)?.toDouble(),
        gapMs: (map['gap_ms'] as num?)?.toDouble(),
        speedMph: (map['speed_mph'] as num?)?.toDouble(),
        confidence: (map['confidence'] as num?)?.toDouble(),
        schemaVersion: map['schema_version'] as int? ?? 1,
      );
}
