import 'package:breaklab/engine/engine_contract.dart';
import 'package:breaklab/features/measure/widgets/break_button.dart';
import 'package:breaklab/features/measure/widgets/english_picker.dart';
import 'package:breaklab/features/measure/widgets/outcome_card.dart';
import 'package:breaklab/features/measure/widgets/table_position_picker.dart';
import 'package:breaklab/models/break_outcome.dart';
import 'package:breaklab/models/break_position.dart';
import 'package:breaklab/models/cue_english.dart';
import 'package:breaklab/models/table_size.dart';
import 'package:breaklab/theme/breaklab_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget wrap(Widget child, {double width = 320}) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, child: child),
        ),
      ),
    );

void main() {
  group('break button', () {
    testWidgets('reads BREAK when idle and LISTENING when armed',
        (tester) async {
      await tester.pumpWidget(wrap(BreakButton(onPressed: () {})));
      expect(find.text('BREAK'), findsOneWidget);
      expect(find.text('TAP ONCE · THEN JUST BREAK'), findsOneWidget);

      await tester.pumpWidget(
          wrap(BreakButton(onPressed: () {}, listening: true)));
      await tester.pump();
      expect(find.text('LISTENING'), findsOneWidget);

      await tester.pumpWidget(wrap(
          BreakButton(onPressed: () {}, listening: true, heard: true)));
      await tester.pump();
      expect(find.text('GOT IT'), findsOneWidget);
    });

    testWidgets('fires once when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(wrap(BreakButton(onPressed: () => taps++)));
      await tester.tap(find.text('BREAK'));
      expect(taps, 1);
    });
  });

  group('table position picker', () {
    testWidgets('shows the head-string-centre distance by default',
        (tester) async {
      await tester.pumpWidget(wrap(TablePositionPicker(
        table: TableSize.sevenFoot,
        position: BreakPosition.headStringCentre,
        onChanged: (_) {},
      )));
      expect(find.textContaining('36.8'), findsOneWidget);
      expect(find.textContaining('to the rack'), findsOneWidget);
    });

    testWidgets('dragging toward a rail reports a longer distance',
        (tester) async {
      BreakPosition? moved;
      await tester.pumpWidget(wrap(
        TablePositionPicker(
          table: TableSize.sevenFoot,
          position: BreakPosition.headStringCentre,
          onChanged: (p) => moved = p,
        ),
        width: 300,
      ));

      // 300 wide -> 150 tall. Tap near the top rail, well back in the kitchen.
      await tester.tapAt(tester.getTopLeft(find.byType(CustomPaint).first) +
          const Offset(20, 8));
      await tester.pump();

      expect(moved, isNotNull);
      expect(moved!.isLegal, isTrue);
      expect(moved!.y, lessThan(0.2));
      expect(
        moved!.travelDistanceInches(TableSize.sevenFoot),
        greaterThan(BreakPosition.headStringCentre
            .travelDistanceInches(TableSize.sevenFoot)),
      );
    });

    testWidgets('a tap past the head string is pulled back into the kitchen',
        (tester) async {
      BreakPosition? moved;
      await tester.pumpWidget(wrap(
        TablePositionPicker(
          table: TableSize.sevenFoot,
          position: BreakPosition.headStringCentre,
          onChanged: (p) => moved = p,
        ),
        width: 300,
      ));

      await tester.tapAt(tester.getTopLeft(find.byType(CustomPaint).first) +
          const Offset(260, 75));
      await tester.pump();

      expect(moved!.x, BreakPosition.kitchenLimitX);
      expect(moved!.isLegal, isTrue);
    });

    testWidgets('draws nothing for a table with no dimensions',
        (tester) async {
      await tester.pumpWidget(wrap(TablePositionPicker(
        table: TableSize.custom,
        position: BreakPosition.headStringCentre,
        onChanged: (_) {},
      )));
      expect(find.textContaining('to the rack'), findsNothing);
    });
  });

  group('english picker', () {
    testWidgets('starts at centre and names where you hit it',
        (tester) async {
      CueEnglish? picked;
      await tester.pumpWidget(wrap(
        EnglishPicker(english: CueEnglish.centre, onChanged: (e) => picked = e),
        width: 120,
      ));
      expect(find.text('Center'), findsOneWidget);

      final topLeft = tester.getTopLeft(find.byType(CustomPaint).first);
      // Left of centre on a 74pt face.
      await tester.tapAt(topLeft + const Offset(8, 37));
      await tester.pump();

      expect(picked, isNotNull);
      expect(picked!.x, lessThan(-0.3));
      expect(picked!.label, 'Left');
    });

    testWidgets('a tap below centre is draw, not follow', (tester) async {
      CueEnglish? picked;
      await tester.pumpWidget(wrap(
        EnglishPicker(english: CueEnglish.centre, onChanged: (e) => picked = e),
        width: 120,
      ));
      final topLeft = tester.getTopLeft(find.byType(CustomPaint).first);
      await tester.tapAt(topLeft + const Offset(37, 66));
      await tester.pump();

      expect(picked!.y, lessThan(-0.3));
      expect(picked!.label, 'Draw');
    });
  });

  group('outcome card', () {
    testWidgets('saves exactly what was tapped', (tester) async {
      BreakOutcome? saved;
      await tester.pumpWidget(wrap(
        OutcomeCard(onSaved: (o) => saved = o, onSkipped: () {}),
        width: 340,
      ));

      await tester.tap(find.text('2'));
      await tester.tap(find.text('Scratched'));
      await tester.tap(find.text('Excellent'));
      await tester.tap(find.text('Wild'));
      await tester.pump();
      await tester.tap(find.text('Save outcome'));

      expect(saved, isNotNull);
      expect(saved!.ballsMade, 2);
      expect(saved!.scratched, isTrue);
      expect(saved!.spread, SpreadQuality.excellent);
      expect(saved!.cueBallAfter, CueBallAfter.wild);
    });

    testWidgets('skip is always available and saves nothing', (tester) async {
      var skipped = false;
      BreakOutcome? saved;
      await tester.pumpWidget(wrap(
        OutcomeCard(onSaved: (o) => saved = o, onSkipped: () => skipped = true),
        width: 340,
      ));
      await tester.tap(find.text('Skip'));
      expect(skipped, isTrue);
      expect(saved, isNull);
    });

    testWidgets('starts from the previous break so most breaks are one tap',
        (tester) async {
      BreakOutcome? saved;
      await tester.pumpWidget(wrap(
        OutcomeCard(
          initial: const BreakOutcome(
            ballsMade: 3,
            scratched: false,
            spread: SpreadQuality.excellent,
            cueBallAfter: CueBallAfter.drifted,
          ),
          onSaved: (o) => saved = o,
          onSkipped: () {},
        ),
        width: 340,
      ));
      await tester.tap(find.text('Save outcome'));
      expect(saved!.ballsMade, 3);
      expect(saved!.spread, SpreadQuality.excellent);
      expect(saved!.cueBallAfter, CueBallAfter.drifted);
    });
  });

  group('grade colours', () {
    test('no two grades share a pill colour', () {
      final backgrounds = <Color>[];
      for (final g in AccuracyGrade.values) {
        final (bg, fg) = BreakLabColors.forGrade(g);
        expect(backgrounds.contains(bg), isFalse,
            reason: '\${g.label} reuses another grade colour');
        expect(bg, isNot(fg));
        backgrounds.add(bg);
      }
      expect(backgrounds.length, AccuracyGrade.values.length);
    });
  });
}
