import 'package:breaklab/features/home/widgets/setup_strip.dart';
import 'package:breaklab/features/measure/widgets/break_setup_sheet.dart';
import 'package:breaklab/features/measure/widgets/english_picker.dart';
import 'package:breaklab/features/measure/widgets/mini_table.dart';
import 'package:breaklab/features/measure/widgets/table_position_picker.dart';
import 'package:breaklab/models/break_position.dart';
import 'package:breaklab/models/cue_english.dart';
import 'package:breaklab/models/table_size.dart';
import 'package:breaklab/theme/breaklab_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget wrap(Widget child, {double width = 340}) => MaterialApp(
      theme: breakLabTheme(),
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, child: child),
        ),
      ),
    );

/// The painted surface belonging to [T] — never Material's own chrome.
Finder paintOf<T extends Widget>() => find.descendant(
      of: find.byType(T),
      matching: find.byType(CustomPaint),
    );

void main() {
  group('mini table', () {
    testWidgets('draws the ball where the position says it is',
        (tester) async {
      await tester.pumpWidget(wrap(const Center(
        child: MiniTable(
          table: TableSize.sevenFoot,
          position: BreakPosition.headStringCentre,
          width: 100,
          railWidth: 3,
          ballDiameter: 10,
        ),
      )));

      expect(tester.takeException(), isNull);

      // 100 outer - 3 rail each side = 94 cloth wide, 47 tall. Head string
      // centre is a quarter along and halfway down.
      final table = tester.getRect(find.byType(MiniTable));
      final ball = tester.getRect(
        find.descendant(
          of: find.byType(MiniTable),
          matching: find.byType(Container),
        ).last,
      );
      final clothLeft = table.left + 3;
      final clothTop = table.top + 3;
      expect(ball.center.dx - clothLeft, closeTo(94 * 0.25, 1.0));
      expect(ball.center.dy - clothTop, closeTo(47 * 0.5, 1.0));
    });

    testWidgets('is 2:1 whatever width it is given', (tester) async {
      await tester.pumpWidget(wrap(const Center(
        child: MiniTable(
          table: TableSize.nineFoot,
          position: BreakPosition.headStringCentre,
          width: 200,
          railWidth: 4,
        ),
      )));
      final size = tester.getSize(find.byType(MiniTable));
      expect(size.width, 200);
      // 192 cloth wide -> 96 cloth tall, plus the rail top and bottom.
      expect(size.height, closeTo(96 + 8, 0.5));
    });

    testWidgets('shows no ball on a custom table', (tester) async {
      // A custom table has no known dimensions, so a spot on it would be a
      // fiction — better to draw nothing than to draw a lie.
      await tester.pumpWidget(wrap(const Center(
        child: MiniTable(
          table: TableSize.custom,
          position: BreakPosition.headStringCentre,
          width: 100,
        ),
      )));
      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byType(MiniTable),
          matching: find.byType(Container),
        ),
        findsOneWidget, // the rail frame, and nothing inside it
      );
    });
  });

  group('setup strip', () {
    Widget strip({
      TableSize table = TableSize.sevenFoot,
      BreakPosition position = BreakPosition.headStringCentre,
      CueEnglish english = CueEnglish.centre,
      double distance = 36.75,
      VoidCallback? onTap,
    }) =>
        SetupStrip(
          table: table,
          position: position,
          english: english,
          distanceInches: distance,
          onTap: onTap ?? () {},
        );

    testWidgets('says the table, the spot and the distance', (tester) async {
      await tester.pumpWidget(wrap(strip()));
      expect(find.text('7ft Bar Box · Center · 36.8"'), findsOneWidget);
      expect(find.textContaining('tap to change'), findsOneWidget);
    });

    testWidgets('a rail break reads as a rail break', (tester) async {
      await tester.pumpWidget(wrap(strip(
        position: const BreakPosition(x: 0.25, y: 0.08),
        distance: 40.1,
      )));
      expect(find.text('7ft Bar Box · Left rail · 40.1"'), findsOneWidget);
    });

    testWidgets('leads with the english it will record', (tester) async {
      await tester.pumpWidget(wrap(strip(
        english: const CueEnglish(x: 0, y: -0.45),
      )));
      expect(find.textContaining('Draw · tap to change'), findsOneWidget);
    });

    testWidgets('a custom table drops the spot but keeps the distance',
        (tester) async {
      await tester.pumpWidget(wrap(strip(
        table: TableSize.custom,
        distance: 44,
      )));
      expect(find.text('Custom distance · 44.0"'), findsOneWidget);
    });

    testWidgets('tapping anywhere on it opens setup', (tester) async {
      var taps = 0;
      await tester.pumpWidget(wrap(strip(onTap: () => taps++)));
      // The point of the strip is that the table itself is the button.
      await tester.tap(find.byType(MiniTable));
      expect(taps, 1);
      await tester.tap(find.textContaining('tap to change'));
      expect(taps, 2);
    });

    testWidgets('fits a narrow phone without overflowing', (tester) async {
      await tester.pumpWidget(wrap(strip(), width: 300));
      expect(tester.takeException(), isNull);
    });
  });

  group('setup sheet', () {
    /// Holds the values the way the controller does, so the sheet under test
    /// behaves exactly as it will in the app.
    Widget sheet({
      TableSize table = TableSize.sevenFoot,
      BreakPosition position = BreakPosition.headStringCentre,
      CueEnglish english = CueEnglish.centre,
      double custom = 44,
      ValueChanged<TableSize>? onTable,
      ValueChanged<BreakPosition>? onPosition,
      ValueChanged<CueEnglish>? onEnglish,
      ValueChanged<double>? onCustom,
      VoidCallback? onDone,
      double width = 340,
    }) =>
        wrap(
          BreakSetupSheet(
            table: table,
            position: position,
            english: english,
            customDistanceInches: custom,
            onTableChanged: onTable ?? (_) {},
            onPositionChanged: onPosition ?? (_) {},
            onEnglishChanged: onEnglish ?? (_) {},
            onCustomDistanceChanged: onCustom ?? (_) {},
            onDone: onDone ?? () {},
          ),
          width: width,
        );

    testWidgets('puts the ball, the distance and the english in one place',
        (tester) async {
      await tester.pumpWidget(sheet());

      expect(find.text('Set up your break'), findsOneWidget);
      for (final chip in ['7ft', '8ft', 'Pro 8', '9ft', 'Custom']) {
        expect(find.text(chip), findsOneWidget);
      }
      expect(find.byType(TablePositionPicker), findsOneWidget);
      expect(find.byType(EnglishPicker), findsOneWidget);
      expect(find.textContaining('Breaking from'), findsOneWidget);
      expect(find.textContaining('36.8"'), findsOneWidget);
      expect(find.text('English · Center'), findsOneWidget);
      expect(find.textContaining('never scored'), findsOneWidget);
      expect(find.text('DONE'), findsOneWidget);
    });

    testWidgets('the readout follows the ball', (tester) async {
      await tester.pumpWidget(sheet(
        position: const BreakPosition(x: 0.25, y: 0.08),
      ));
      expect(find.textContaining('Left rail'), findsOneWidget);
      // 7ft, on the rail, off the head string: about 40 inches of travel.
      expect(find.textContaining('40.1"'), findsOneWidget);
    });

    testWidgets('choosing a table size reports it', (tester) async {
      TableSize? picked;
      await tester.pumpWidget(sheet(onTable: (t) => picked = t));
      await tester.tap(find.text('9ft'));
      expect(picked, TableSize.nineFoot);
    });

    testWidgets('dragging the ball reports a new position', (tester) async {
      BreakPosition? moved;
      await tester.pumpWidget(sheet(onPosition: (p) => moved = p));

      final cloth = tester.getRect(paintOf<TablePositionPicker>());
      await tester.tapAt(Offset(cloth.left + 12, cloth.top + 8));
      await tester.pump();

      expect(moved, isNotNull);
      expect(moved!.isLegal, isTrue);
      expect(moved!.y, lessThan(0.2));
    });

    testWidgets('tapping the ball face reports english', (tester) async {
      CueEnglish? picked;
      await tester.pumpWidget(sheet(onEnglish: (e) => picked = e));

      final face = tester.getRect(paintOf<EnglishPicker>());
      // Below centre on the face is draw.
      await tester.tapAt(Offset(face.center.dx, face.bottom - 8));
      await tester.pump();

      expect(picked, isNotNull);
      expect(picked!.y, lessThan(-0.3));
      expect(picked!.label, 'Draw');
    });

    testWidgets('a custom table trades the drawing for a distance',
        (tester) async {
      double? set;
      await tester.pumpWidget(sheet(
        table: TableSize.custom,
        custom: 44,
        onCustom: (d) => set = d,
      ));

      // No geometry means no drawing — and no invented spot.
      expect(find.byType(TablePositionPicker), findsNothing);
      expect(find.text('44"'), findsOneWidget);
      expect(find.text('TO THE RACK'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add));
      expect(set, 45);
      await tester.tap(find.byIcon(Icons.remove));
      expect(set, 43);
    });

    testWidgets('the custom distance cannot run off either end',
        (tester) async {
      double? set;
      await tester.pumpWidget(sheet(
        table: TableSize.custom,
        custom: BreakSetupSheet.minCustomInches,
        onCustom: (d) => set = d,
      ));
      await tester.tap(find.byIcon(Icons.remove));
      expect(set, isNull, reason: 'clamped at the bottom, so nothing changed');

      await tester.pumpWidget(sheet(
        table: TableSize.custom,
        custom: BreakSetupSheet.maxCustomInches,
        onCustom: (d) => set = d,
      ));
      await tester.tap(find.byIcon(Icons.add));
      expect(set, isNull, reason: 'clamped at the top, so nothing changed');
    });

    testWidgets('DONE closes it', (tester) async {
      var done = false;
      await tester.pumpWidget(sheet(onDone: () => done = true));
      await tester.tap(find.text('DONE'));
      expect(done, isTrue);
    });

    testWidgets('lays out on a small phone without overflowing',
        (tester) async {
      // Every layout bug on this app so far has been a Row or a Column that
      // fitted the test surface and not the phone.
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(sheet(width: 320));
      expect(tester.takeException(), isNull);
      expect(find.text('DONE'), findsOneWidget);
    });
  });
}
