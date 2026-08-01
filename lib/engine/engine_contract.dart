/// The BreakLab engine contract (locked, resolves RB-002).
///
/// In:  raw immutable audio samples, travel distance in inches (app-supplied),
///      sensitivity preset (default normal).
/// Out: tip timestamp, rack timestamp, gap ms, MPH, self-assessed accuracy
///      grade, engine version stamp.
///
/// The engine knows nothing about sessions, history, or screens.
library;

/// Self-assessed accuracy grade. The engine grades ITSELF from signal
/// quality; manual-marker validation in the tester keeps these honest:
/// excellent must mean actual error <= 0.5 MPH, target <= 1.0, fallback
/// <= 2.0. unreliable = wrong sound pair or invalid ordering.
enum AccuracyGrade {
  excellent('Excellent'),
  target('Target'),
  fallback('Fallback'),
  unreliable('Unreliable');

  const AccuracyGrade(this.label);
  final String label;

  static AccuracyGrade fromLabel(String label) =>
      AccuracyGrade.values.firstWhere(
        (g) => g.label == label,
        orElse: () => AccuracyGrade.unreliable,
      );
}

enum SensitivityPreset {
  normal('Normal'),
  quietRoom('Quiet Room'),
  loudRoom('Loud Room');

  const SensitivityPreset(this.label);
  final String label;

  static SensitivityPreset fromLabel(String label) =>
      SensitivityPreset.values.firstWhere(
        (p) => p.label == label,
        orElse: () => SensitivityPreset.normal,
      );
}

/// Input to a detection run.
class EngineInput {
  const EngineInput({
    required this.samples,
    required this.sampleRateHz,
    required this.travelDistanceInches,
    this.preset = SensitivityPreset.normal,
  });

  /// Raw PCM samples, mono, 16-bit signed, never modified.
  final List<int> samples;
  final int sampleRateHz;
  final double travelDistanceInches;
  final SensitivityPreset preset;
}

/// Output of a detection run. All timing derives from sample indexes.
class EngineResult {
  const EngineResult({
    required this.engineVersion,
    required this.grade,
    required this.detectedPairValid,
    this.tipSampleIndex,
    this.rackSampleIndex,
    this.tipTimestampMs,
    this.rackTimestampMs,
    this.gapMs,
    this.speedMph,
    this.confidence,
    this.gradeReasons = const [],
  });

  final String engineVersion;
  final AccuracyGrade grade;
  final bool detectedPairValid;

  /// Null when detection failed (grade == unreliable). A failed detection is
  /// still a saved result — never a crash, never a blocked save.
  final int? tipSampleIndex;
  final int? rackSampleIndex;
  final double? tipTimestampMs;
  final double? rackTimestampMs;
  final double? gapMs;
  final double? speedMph;
  final double? confidence;
  final List<String> gradeReasons;
}

/// The engine interface Break Lab codes against. The production
/// implementation is ported, frozen and version-stamped, from the BreakLab
/// Tester once timing is dialed in. The app NEVER modifies engine internals —
/// improvements arrive as new frozen versions with a bumped version string.
abstract class BreakLabEngine {
  String get version;
  EngineResult detect(EngineInput input);
}

/// Speed math shared by every engine version.
///
/// MPH = (inches / ms) * (3600000 ms/hr) / (63360 in/mile)
double speedMph({required double travelDistanceInches, required double gapMs}) {
  if (gapMs <= 0) {
    throw ArgumentError.value(gapMs, 'gapMs', 'must be positive');
  }
  return (travelDistanceInches / gapMs) * 3600000 / 63360;
}
