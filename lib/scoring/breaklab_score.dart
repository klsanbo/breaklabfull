import 'dart:math' as math;

import '../engine/engine_contract.dart';
import '../models/break_result.dart';
import 'break_score.dart';

/// The 20-session BreakLab Score, 0–100. Approved math spec V001.
///
/// Keeps the originally locked weights:
///   Control 30 · Consistency 25 · Clean breaks 20 · Balls made 15 · Speed 10
///
/// Current form, never a lifetime average. Computed live from stored breaks
/// and never persisted, so it can't drift out of sync with history.
class BreakLabScore {
  const BreakLabScore({
    required this.score,
    required this.grade,
    required this.sessionsCounted,
    required this.scoredBreaks,
    required this.control,
    required this.consistency,
    required this.clean,
    required this.balls,
    required this.speed,
    this.needMessage,
  });

  /// Null until the minimums are met; [needMessage] then says what's missing.
  final int? score;
  final String grade;
  final int sessionsCounted;
  final int scoredBreaks;

  /// Component values, 0–100, for the trend rows.
  final double control;
  final double consistency;
  final double clean;
  final double balls;
  final double speed;

  final String? needMessage;

  bool get isReady => score != null;

  static const sessionWindow = 20;
  static const minSessions = 3;
  static const minScoredBreaks = 20;

  /// A session needs this many reliable speeds before its spread means
  /// anything — otherwise a one-break night would score perfect consistency.
  static const minBreaksForConsistency = 3;

  static const controlWeight = 0.30;
  static const consistencyWeight = 0.25;
  static const cleanWeight = 0.20;
  static const ballsWeight = 0.15;
  static const speedWeight = 0.10;

  static String gradeFor(int score) {
    if (score >= 90) return 'Elite';
    if (score >= 75) return 'Strong';
    if (score >= 60) return 'Developing';
    return 'Building';
  }

  /// Consistency for one session, from the spread of its reliable speeds.
  /// Returns null when the session has too few breaks to judge.
  static double? sessionConsistency(List<BreakResult> breaks) {
    final speeds = breaks
        .where((b) => b.hasSpeed)
        .map((b) => b.speedMph!)
        .toList(growable: false);
    if (speeds.length < minBreaksForConsistency) return null;
    final mean = speeds.reduce((a, b) => a + b) / speeds.length;
    if (mean <= 0) return null;
    final variance =
        speeds.map((s) => (s - mean) * (s - mean)).reduce((a, b) => a + b) /
            speeds.length;
    final spread = math.sqrt(variance) / mean;
    return math.min(100.0, math.max(0.0, 100 * (1 - spread * 5)));
  }

  /// [sessionsNewestFirst] is every session's breaks, newest session first.
  /// Only the most recent [sessionWindow] sessions are considered.
  factory BreakLabScore.fromSessions(
      List<List<BreakResult>> sessionsNewestFirst) {
    final window = sessionsNewestFirst.take(sessionWindow).toList();

    final scored = <BreakResult>[];
    final withSpeed = <BreakResult>[];
    final consistencies = <double>[];

    for (final session in window) {
      for (final b in session) {
        if (b.hasSpeed) withSpeed.add(b);
        if (BreakScore.forBreak(b) != null) scored.add(b);
      }
      final c = sessionConsistency(session);
      if (c != null) consistencies.add(c);
    }

    double mean(Iterable<double> xs) =>
        xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;

    final control =
        mean(scored.map((b) => b.outcome!.cueBallAfter.points.toDouble()));
    final consistency = mean(consistencies);
    final clean = scored.isEmpty
        ? 0.0
        : 100 *
            scored
                .where((b) =>
                    !b.outcome!.scratched &&
                    b.grade != AccuracyGrade.unreliable)
                .length /
            scored.length;
    final balls = mean(scored.map((b) => b.outcome!.ballPoints.toDouble()));
    final speed =
        mean(withSpeed.map((b) => BreakScore.speedPoints(b.speedMph!)));

    final enoughSessions = window.length >= minSessions;
    final enoughBreaks = scored.length >= minScoredBreaks;

    if (!enoughSessions || !enoughBreaks) {
      final needs = <String>[];
      if (!enoughSessions) {
        final n = minSessions - window.length;
        needs.add('$n more ${n == 1 ? 'session' : 'sessions'}');
      }
      if (!enoughBreaks) {
        final n = minScoredBreaks - scored.length;
        needs.add('$n more scored ${n == 1 ? 'break' : 'breaks'}');
      }
      return BreakLabScore(
        score: null,
        grade: '',
        sessionsCounted: window.length,
        scoredBreaks: scored.length,
        control: control,
        consistency: consistency,
        clean: clean,
        balls: balls,
        speed: speed,
        needMessage: '${needs.join(' and ')} and your Score unlocks',
      );
    }

    final total = control * controlWeight +
        consistency * consistencyWeight +
        clean * cleanWeight +
        balls * ballsWeight +
        speed * speedWeight;
    final rounded = total.round();

    return BreakLabScore(
      score: rounded,
      grade: gradeFor(rounded),
      sessionsCounted: window.length,
      scoredBreaks: scored.length,
      control: control,
      consistency: consistency,
      clean: clean,
      balls: balls,
      speed: speed,
    );
  }
}
