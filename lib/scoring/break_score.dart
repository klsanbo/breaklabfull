import 'dart:math' as math;

import '../engine/engine_contract.dart';
import '../models/break_outcome.dart';
import '../models/break_result.dart';

/// Per-break Break Score, 0–100. Approved math spec V001 (2026-07-28).
///
/// Weights — consistency cannot exist on a single break (one break has no
/// variance), so spread quality takes its slot at this level. The 20-session
/// rollup keeps the original locked weights.
///
///   Cue ball control 30 · Clean break 20 · Spread 20 · Balls made 20 · Speed 10
///
/// Two rules that keep the score honest:
///   * An unreliable reading never produces a score.
///   * A skipped outcome card never produces a score — it does NOT renormalise
///     the remaining weights, because that would make skipping score higher
///     than answering honestly.
class BreakScore {
  const BreakScore._();

  static const controlWeight = 0.30;
  static const cleanWeight = 0.20;
  static const spreadWeight = 0.20;
  static const ballsWeight = 0.20;
  static const speedWeight = 0.10;

  /// MPH mapped to 0–100. 13 MPH and below scores 0; 24 MPH and above 100.
  ///
  /// Recalibrated 2026-07-30. The old ceiling of 26 was unreachable: a typical
  /// player averages about 19 and a hard breaker lands around 20-21, so every
  /// player was losing speed points they had no way to earn. See [SpeedBand]
  /// for the words that go with these numbers, and the same caveat — these are
  /// set from experience until the field protocol gives us our own figures.
  static const speedFloorMph = 13.0;
  static const speedCeilingMph = 24.0;

  static double speedPoints(double mph) {
    final raw = (mph - speedFloorMph) / (speedCeilingMph - speedFloorMph) * 100;
    return math.min(100.0, math.max(0.0, raw));
  }

  /// The score for one break, or null when it cannot honestly be scored.
  static int? forBreak(BreakResult b) {
    final outcome = b.outcome;
    if (outcome == null) return null;
    if (!b.hasSpeed) return null;
    return compute(
      mph: b.speedMph!,
      outcome: outcome,
      reliable: b.grade != AccuracyGrade.unreliable,
    );
  }

  static int compute({
    required double mph,
    required BreakOutcome outcome,
    bool reliable = true,
  }) {
    final clean = (!outcome.scratched && reliable) ? 100.0 : 0.0;
    final total = outcome.cueBallAfter.points * controlWeight +
        clean * cleanWeight +
        outcome.spread.points * spreadWeight +
        outcome.ballPoints * ballsWeight +
        speedPoints(mph) * speedWeight;
    return total.round();
  }
}
