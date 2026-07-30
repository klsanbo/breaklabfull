import 'package:breaklab/engine/engine_contract.dart';
import 'package:breaklab/models/break_outcome.dart';
import 'package:breaklab/models/break_position.dart';
import 'package:breaklab/models/break_result.dart';
import 'package:breaklab/models/cue_english.dart';
import 'package:breaklab/models/speed_band.dart';
import 'package:breaklab/models/table_size.dart';
import 'package:breaklab/scoring/break_score.dart';
import 'package:breaklab/scoring/breaklab_score.dart';
import 'package:flutter_test/flutter_test.dart';

BreakResult mk({
  double? mph = 21.4,
  BreakOutcome? outcome,
  AccuracyGrade grade = AccuracyGrade.excellent,
  int sessionId = 1,
}) =>
    BreakResult(
      sessionId: sessionId,
      recordedAt: DateTime(2026, 7, 28, 20),
      tableSize: TableSize.sevenFoot,
      travelDistanceInches: 36.75,
      preset: SensitivityPreset.normal,
      engineVersion: '1.0.0',
      grade: grade,
      detectedPairValid: grade != AccuracyGrade.unreliable,
      position: BreakPosition.headStringCentre,
      english: CueEnglish.centre,
      outcome: outcome,
      speedMph: mph,
    );

const goodOutcome = BreakOutcome(
  ballsMade: 1,
  scratched: false,
  spread: SpreadQuality.good,
  cueBallAfter: CueBallAfter.stayedCenter,
);

void main() {
  group('break position geometry', () {
    test('centre of the head string reproduces every locked preset', () {
      const p = BreakPosition.headStringCentre;
      expect(
          p.travelDistanceInches(TableSize.sevenFoot), closeTo(36.75, 0.001));
      expect(
          p.travelDistanceInches(TableSize.eightFoot), closeTo(41.75, 0.001));
      expect(p.travelDistanceInches(TableSize.proEight), closeTo(43.75, 0.001));
      expect(p.travelDistanceInches(TableSize.nineFoot), closeTo(47.75, 0.001));
    });

    test('a rail break is measurably longer than a centre break', () {
      const rail = BreakPosition(x: 0.25, y: 1.125 / 39);
      final d = rail.travelDistanceInches(TableSize.sevenFoot);
      expect(d, closeTo(40.86, 0.05));
      expect(d, greaterThan(36.75));
      expect(rail.isRailBreak, isTrue);
      expect(rail.label, 'Left rail');
    });

    test('position labels band across the table', () {
      expect(const BreakPosition(x: .25, y: .5).label, 'Center');
      expect(const BreakPosition(x: .25, y: .95).label, 'Right rail');
      expect(const BreakPosition(x: .25, y: .75).label, 'Right');
      expect(const BreakPosition(x: .25, y: .2).label, 'Left');
    });

    test('kitchen clamping keeps a break legal', () {
      const outside = BreakPosition(x: 0.9, y: 1.4);
      expect(outside.isLegal, isFalse);
      final fixed = outside.clampedToKitchen();
      expect(fixed.isLegal, isTrue);
      expect(fixed.x, 0.25);
      expect(fixed.y, 1.0);
    });

    test('a custom table has no geometry to measure from', () {
      expect(TableSize.custom.hasGeometry, isFalse);
      expect(
          () => BreakPosition.headStringCentre
              .travelDistanceInches(TableSize.custom),
          throwsArgumentError);
    });
  });

  group('cue english', () {
    test('is labelled in plain pool language', () {
      expect(CueEnglish.centre.label, 'Center');
      expect(const CueEnglish(x: 0, y: -0.6).label, 'Draw');
      expect(const CueEnglish(x: 0.5, y: 0.5).label, 'Follow right');
      expect(const CueEnglish(x: -0.6, y: 0).label, 'Left');
    });

    test('flags contact points past the miscue limit', () {
      expect(const CueEnglish(x: 0, y: -0.3).beyondMiscueLimit, isFalse);
      expect(const CueEnglish(x: 0, y: -0.8).beyondMiscueLimit, isTrue);
    });
  });

  group('speed bands', () {
    test('the band a speed falls in', () {
      expect(SpeedBand.forMph(12).label, 'Controlled');
      expect(SpeedBand.forMph(15.9).label, 'Controlled');
      expect(SpeedBand.forMph(16).label, 'Solid');
      expect(SpeedBand.forMph(18).label, 'Solid',
          reason: '18 MPH is not a soft break');
      expect(SpeedBand.forMph(19).label, 'Solid',
          reason: 'the average break must not read as a shortfall');
      expect(SpeedBand.forMph(19.9).label, 'Solid');
      expect(SpeedBand.forMph(20).label, 'Strong');
      expect(SpeedBand.forMph(21).label, 'Strong');
      expect(SpeedBand.forMph(22.9).label, 'Strong');
      expect(SpeedBand.forMph(23).label, 'Hard');
      expect(SpeedBand.forMph(31).label, 'Hard');
    });

    test('every band is reachable and none of them overlap', () {
      // A band nobody can reach is the bug this replaced: the old top band
      // started at 27 MPH.
      for (final band in SpeedBand.values) {
        final from = band.fromMph ?? 10.0;
        expect(SpeedBand.forMph(from), band);
      }
      expect(SpeedBand.values.length, 4);
    });

    test('legend text reads the way a legend should', () {
      expect(SpeedBand.controlled.range, 'under 16.0');
      expect(SpeedBand.solid.range, '16.0 - 19.9');
      expect(SpeedBand.strong.range, '20.0 - 22.9');
      expect(SpeedBand.hard.range, '23.0+');
    });

    test('no band name grades the player', () {
      // Speed is 10% of the score because it is not a verdict. These words
      // describe what happened; POOR and AVERAGE would judge it.
      final words = SpeedBand.values.map((b) => b.label.toLowerCase());
      for (final judgement in ['poor', 'bad', 'weak', 'average', 'soft']) {
        expect(words, isNot(contains(judgement)));
      }
    });
  });

  group('break score', () {
    test('speed maps 13 MPH to 0 and 24 MPH to 100, clamped', () {
      // The old scale topped out at 26, which nobody reaches: average is about
      // 19 and a hard breaker is 20-21. Everyone was losing points they could
      // not earn.
      expect(BreakScore.speedPoints(13), 0);
      expect(BreakScore.speedPoints(18.5), closeTo(50, 0.001));
      expect(BreakScore.speedPoints(24), 100);
      expect(BreakScore.speedPoints(30), 100);
      expect(BreakScore.speedPoints(9), 0);
    });

    test('a real-world break is no longer punished by the scale', () {
      // 19 MPH is an ordinary break. On the old scale it scored 41 of 100 on
      // speed; it should sit around the middle, not near the bottom.
      expect(BreakScore.speedPoints(19), greaterThan(50));
      expect(BreakScore.speedPoints(21), greaterThan(70));
    });

    test('a controlled break scores well', () {
      expect(BreakScore.forBreak(mk(outcome: goodOutcome)), 83);
    });

    test('a great break scores in the nineties', () {
      const outcome = BreakOutcome(
        ballsMade: 2,
        scratched: false,
        spread: SpreadQuality.excellent,
        cueBallAfter: CueBallAfter.stayedCenter,
      );
      expect(BreakScore.forBreak(mk(mph: 24.7, outcome: outcome)), 96);
    });

    test('power without control scores badly — the whole point', () {
      const outcome = BreakOutcome(
        ballsMade: 0,
        scratched: true,
        spread: SpreadQuality.poor,
        cueBallAfter: CueBallAfter.wild,
      );
      final wild = BreakScore.forBreak(mk(mph: 28.0, outcome: outcome))!;
      final controlled = BreakScore.forBreak(mk(
          mph: 24.7,
          outcome: const BreakOutcome(
              ballsMade: 2,
              scratched: false,
              spread: SpreadQuality.excellent,
              cueBallAfter: CueBallAfter.stayedCenter)))!;
      expect(wild, 24);
      expect(controlled, greaterThan(wild));
    });

    test('a skipped outcome never produces a score', () {
      expect(BreakScore.forBreak(mk()), isNull);
    });

    test('skipping can never out-score answering honestly', () {
      // The exploit this rule exists to kill: renormalising the remaining
      // weights would have scored the skipped break 87 vs 81 for the honest
      // one. No score at all is the only safe answer.
      final honest = BreakScore.forBreak(mk(outcome: goodOutcome));
      final skipped = BreakScore.forBreak(mk());
      expect(honest, isNotNull);
      expect(skipped, isNull);
    });

    test('an unreliable reading never produces a score', () {
      final b =
          mk(mph: null, grade: AccuracyGrade.unreliable, outcome: goodOutcome);
      expect(BreakScore.forBreak(b), isNull);
    });
  });

  group('breaklab score', () {
    List<BreakResult> session(int id, {int count = 7, double mph = 21.4}) =>
        List.generate(
            count, (_) => mk(mph: mph, outcome: goodOutcome, sessionId: id));

    test('needs three sessions and twenty scored breaks', () {
      final short = BreakLabScore.fromSessions([session(1), session(2)]);
      expect(short.isReady, isFalse);
      expect(short.score, isNull);
      expect(short.needMessage, contains('more'));
    });

    test('computes from the locked weights once there is enough data', () {
      final s =
          BreakLabScore.fromSessions([session(1), session(2), session(3)]);
      expect(s.isReady, isTrue);
      expect(s.scoredBreaks, 21);
      expect(s.sessionsCounted, 3);
      // control 100·.30 + consistency 100·.25 + clean 100·.20
      //   + balls 60·.15 + speed 76.36·.10 = 91.64
      expect(s.score, 92);
      expect(s.grade, 'Elite');
    });

    test('only the most recent twenty sessions count', () {
      final many = List.generate(30, (i) => session(i));
      expect(BreakLabScore.fromSessions(many).sessionsCounted, 20);
    });

    test('a tight session scores far higher consistency than a loose one', () {
      final tight = BreakLabScore.sessionConsistency(
          [21.4, 20.9, 21.8, 21.1, 21.5].map((m) => mk(mph: m)).toList())!;
      final loose = BreakLabScore.sessionConsistency(
          [18.0, 24.0, 20.0, 26.0, 19.0].map((m) => mk(mph: m)).toList())!;
      expect(tight, closeTo(92.65, 0.1));
      expect(loose, closeTo(28.2, 0.5));
      expect(tight, greaterThan(loose));
    });

    test('a one-break night earns no free consistency', () {
      expect(BreakLabScore.sessionConsistency([mk()]), isNull);
      expect(BreakLabScore.sessionConsistency([mk(), mk()]), isNull);
      expect(BreakLabScore.sessionConsistency([mk(), mk(), mk()]), isNotNull);
    });

    test('grade bands match the approved spec', () {
      expect(BreakLabScore.gradeFor(95), 'Elite');
      expect(BreakLabScore.gradeFor(90), 'Elite');
      expect(BreakLabScore.gradeFor(89), 'Strong');
      expect(BreakLabScore.gradeFor(75), 'Strong');
      expect(BreakLabScore.gradeFor(74), 'Developing');
      expect(BreakLabScore.gradeFor(60), 'Developing');
      expect(BreakLabScore.gradeFor(59), 'Building');
    });

    test('skipped-outcome breaks still feed speed and consistency', () {
      final mixed = List.generate(
          21,
          (i) => mk(
              mph: 21.4, outcome: i.isEven ? goodOutcome : null, sessionId: 1));
      final s = BreakLabScore.fromSessions([mixed, mixed, mixed]);
      // 11 scored per session x3 = 33 scored, all 63 feed speed.
      expect(s.scoredBreaks, 33);
      // Derived from the scale rather than hardcoded: this test is about
      // skipped breaks still feeding the speed average, not about where the
      // scale happens to sit. Recalibrating should not require editing it.
      expect(s.speed, closeTo(BreakScore.speedPoints(21.4), 0.1));
    });
  });
}
