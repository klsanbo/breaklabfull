import 'engine_contract.dart';

/// Placeholder engine used ONLY until the dialed-in detection logic is
/// ported from the BreakLab Tester. It never fabricates a speed: every
/// detection returns [AccuracyGrade.unreliable] so no fake MPH can ever be
/// mistaken for a real measurement during development.
///
/// Version "0.0.0-stub" makes any result produced by this engine
/// permanently identifiable in stored history.
class StubEngine implements BreakLabEngine {
  @override
  String get version => '0.0.0-stub';

  @override
  EngineResult detect(EngineInput input) {
    return EngineResult(
      engineVersion: version,
      grade: AccuracyGrade.unreliable,
      detectedPairValid: false,
      gradeReasons: const ['stub_engine_no_detection'],
    );
  }
}
