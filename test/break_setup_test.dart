import 'dart:async';
import 'dart:io';

import 'package:breaklab/engine/engine_contract.dart';
import 'package:breaklab/features/home/widgets/setup_strip.dart';
import 'package:breaklab/features/measure/break_setup_screen.dart';
import 'package:breaklab/features/measure/measure_controller.dart';
import 'package:breaklab/features/measure/widgets/break_table_view.dart';
import 'package:breaklab/features/measure/widgets/english_picker.dart';
import 'package:breaklab/features/measure/widgets/mini_table.dart';
import 'package:breaklab/models/break_position.dart';
import 'package:breaklab/models/cue_english.dart';
import 'package:breaklab/models/table_size.dart';
import 'package:breaklab/services/db/breaklab_database.dart';
import 'package:breaklab/theme/breaklab_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Widget wrap(Widget child, {double width = 340}) => MaterialApp(
      theme: breakLabTheme(),
      home: Scaffold(
        body: Center(child: SizedBox(width: width, child: child)),
      ),
    );

/// The painted surface belonging to [T] — never Material's own chrome.
Finder paintOf<T extends Widget>() => find.descendant(
      of: find.byType(T),
      matching: find.byType(CustomPaint),
    );

class FakeRecorder implements BreakRecorder {
  final controller = StreamController<double>.broadcast();
  String? path;

  @override
  Future<void> start(String outputPath) async => path = outputPath;

  @override
  Future<String> stop() async => path!;

  @override
  Future<void> cancel() async {}

  @override
  Stream<double> get levels => controller.stream;
}

class StubbedEngine implements BreakLabEngine {
  @override
  String get version => '0.0.0-stub';

  @override
  EngineResult detect(EngineInput input) => EngineResult(
        engineVersion: version,
        grade: AccuracyGrade.unreliable,
        detectedPairValid: false,
      );
}

/// Drags from [from] by [by] in several steps, so the gesture arena resolves
/// the way it does under a real thumb rather than in one teleporting jump.
Future<void> slowDrag(WidgetTester tester, Offset from, Offset by,
    {int steps = 5}) async {
  final gesture = await tester.startGesture(from);
  await tester.pump();
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(Offset(by.dx / steps, by.dy / steps));
    await tester.pump();
  }
  await gesture.up();
  await tester.pump();
}

/// The ball inside a [MiniTable] — the last Container in its subtree, since the
/// first is the rail frame.
Finder miniBall() => find
    .descendant(of: find.byType(MiniTable), matching: find.byType(Container))
    .last;

void main() {
  sqfliteFfiInit();

  group('mini table', () {
    testWidgets('is portrait, twice as long as it is wide', (tester) async {
      await tester.pumpWidget(wrap(const Center(
        child: MiniTable(
          table: TableSize.sevenFoot,
          position: BreakPosition.headStringCentre,
          width: 40,
          railWidth: 2,
        ),
      )));
      expect(tester.takeException(), isNull);

      final size = tester.getSize(find.byType(MiniTable));
      // 36 of cloth across, twice that up the table, plus the rail both ends.
      expect(size.width, 40);
      expect(size.height, closeTo(36 * 2 + 4, 0.5));
    });

    testWidgets('puts the ball a quarter up from the bottom, centre width',
        (tester) async {
      await tester.pumpWidget(wrap(const Center(
        child: MiniTable(
          table: TableSize.sevenFoot,
          position: BreakPosition.headStringCentre,
          width: 60,
          railWidth: 3,
        ),
      )));

      final table = tester.getRect(find.byType(MiniTable));
      final ball = tester.getRect(miniBall());

      // Cloth is 54 across and 108 up, starting 3 in from the frame.
      expect(ball.center.dx - (table.left + 3), closeTo(54 * 0.5, 1.0));
      // x 0.25 is a quarter up from the BOTTOM, so three quarters down.
      expect(ball.center.dy - (table.top + 3), closeTo(108 * 0.75, 1.0));
    });

    testWidgets('a rail break sits at the side, not the end', (tester) async {
      await tester.pumpWidget(wrap(const Center(
        child: MiniTable(
          table: TableSize.sevenFoot,
          position: BreakPosition(x: 0.25, y: 0.0),
          width: 60,
          railWidth: 3,
        ),
      )));
      final table = tester.getRect(find.byType(MiniTable));
      final ball = tester.getRect(miniBall());
      // y 0 is the breaker's left, which is the left of the drawing.
      expect(ball.center.dx - (table.left + 3), closeTo(0, 1.5));
    });

    testWidgets('shows no ball on a custom table', (tester) async {
      // No known dimensions, so a spot on it would be a fiction.
      await tester.pumpWidget(wrap(const Center(
        child: MiniTable(
          table: TableSize.custom,
          position: BreakPosition.headStringCentre,
          width: 40,
        ),
      )));
      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
            of: find.byType(MiniTable), matching: find.byType(Container)),
        findsOneWidget, // the rail frame, and nothing inside it
      );
    });
  });

  group('break table view', () {
    Widget view({
      TableSize table = TableSize.sevenFoot,
      BreakPosition position = BreakPosition.headStringCentre,
      ValueChanged<BreakPosition>? onChanged,
    }) =>
        wrap(SizedBox(
          height: 400,
          child: BreakTableView(
            table: table,
            position: position,
            onChanged: onChanged ?? (_) {},
          ),
        ));

    testWidgets('fills what it is given and draws without exploding',
        (tester) async {
      await tester.pumpWidget(view());
      expect(tester.takeException(), isNull);
      final size = tester.getSize(find.byType(BreakTableView));
      expect(size.width, 340);
      expect(size.height, 400);
    });

    testWidgets('clips its drawing so nothing bleeds onto what is below it',
        (tester) async {
      // On the phone the apron and the wordmark were painted over the readout
      // row beneath the table: dark ink on near-black, unreadable. A
      // CustomPaint does not clip and the table is deliberately bigger than
      // the view it sits in.
      await tester.pumpWidget(wrap(Column(
        children: [
          SizedBox(
            height: 300,
            child: BreakTableView(
              table: TableSize.sevenFoot,
              position: BreakPosition.headStringCentre,
              onChanged: (_) {},
            ),
          ),
          const Text('under the table'),
        ],
      )));

      expect(
        find.descendant(
            of: find.byType(BreakTableView), matching: find.byType(ClipRect)),
        findsOneWidget,
        reason: 'nothing is stopping the painter drawing outside its box',
      );

      final view = tester.getRect(find.byType(BreakTableView));
      final below = tester.getRect(find.text('under the table'));
      expect(below.top, greaterThanOrEqualTo(view.bottom - 0.5),
          reason: 'the readout would be underneath the table drawing');
    });

    test('the wordmark is drawn whole or not at all', () {
      // It was being cut in half by the clip, which reads as a defect. It has
      // to fit entirely inside the view or stay off.
      expect(
        BreakTableView.wordmarkFits(viewHeight: 300, top: 250, bottom: 280),
        isTrue,
      );
      expect(
        BreakTableView.wordmarkFits(viewHeight: 300, top: 290, bottom: 320),
        isFalse,
        reason: 'the bottom of the word is past the bottom of the view',
      );
      expect(
        BreakTableView.wordmarkFits(viewHeight: 300, top: -5, bottom: 25),
        isFalse,
        reason: 'the top of the word is above the view',
      );
    });

    testWidgets('dragging down moves the ball up the table', (tester) async {
      BreakPosition? moved;
      await tester.pumpWidget(view(
        position: const BreakPosition(x: 0.05, y: 0.5),
        onChanged: (p) => moved = p,
      ));

      await slowDrag(tester, tester.getCenter(find.byType(BreakTableView)),
          const Offset(0, 60));

      expect(moved, isNotNull, reason: 'the drag never reached the table');
      expect(moved!.x, greaterThan(0.05),
          reason: 'dragging the table down moves the ball up the table');
    });

    testWidgets('dragging up moves the ball back toward the head rail',
        (tester) async {
      BreakPosition? moved;
      await tester.pumpWidget(view(
        position: const BreakPosition(x: 0.2, y: 0.5),
        onChanged: (p) => moved = p,
      ));

      await slowDrag(tester, tester.getCenter(find.byType(BreakTableView)),
          const Offset(0, -50));

      expect(moved!.x, lessThan(0.2));
      expect(moved!.isLegal, isTrue);
    });

    testWidgets('dragging sideways moves the ball toward a rail',
        (tester) async {
      BreakPosition? moved;
      await tester.pumpWidget(view(onChanged: (p) => moved = p));

      // Drag the table right; your viewpoint moves left across it.
      await slowDrag(tester, tester.getCenter(find.byType(BreakTableView)),
          const Offset(70, 0));

      expect(moved, isNotNull);
      expect(moved!.y, lessThan(0.5));
      expect(moved!.isLegal, isTrue);
    });

    testWidgets('the ball stops at the head string', (tester) async {
      BreakPosition? moved;
      await tester.pumpWidget(view(
        position: const BreakPosition(x: 0.24, y: 0.5),
        onChanged: (p) => moved = p,
      ));

      // Far more than enough to push past the line.
      await slowDrag(tester, tester.getCenter(find.byType(BreakTableView)),
          const Offset(0, 400));

      expect(moved!.x, BreakPosition.kitchenLimitX);
      expect(moved!.isLegal, isTrue);
    });

    testWidgets('the ball cannot leave the cloth sideways', (tester) async {
      BreakPosition? moved;
      await tester.pumpWidget(view(
        position: const BreakPosition(x: 0.25, y: 0.05),
        onChanged: (p) => moved = p,
      ));

      await slowDrag(tester, tester.getCenter(find.byType(BreakTableView)),
          const Offset(600, 0));

      expect(moved!.y, 0.0);
      expect(moved!.isLegal, isTrue);
    });

    testWidgets('a diagonal drag moves both axes', (tester) async {
      // Kept vertical-dominant so the vertical recognizer is the one that
      // claims it — the case where reporting only that axis's delta would lose
      // the sideways half of the movement.
      BreakPosition? moved;
      await tester.pumpWidget(view(
        position: const BreakPosition(x: 0.05, y: 0.5),
        onChanged: (p) => moved = p,
      ));

      await slowDrag(tester, tester.getCenter(find.byType(BreakTableView)),
          const Offset(-25, 60));

      expect(moved!.x, greaterThan(0.05), reason: 'the vertical half was lost');
      expect(moved!.y, greaterThan(0.5), reason: 'the sideways half was lost');
    });

    testWidgets('survives a drag inside a scrolling list', (tester) async {
      // A pan recognizer loses every vertical drag to a scroll view above it;
      // axis recognizers share its threshold and sit deeper, so they win.
      final scroll = ScrollController();
      BreakPosition? moved;

      await tester.pumpWidget(MaterialApp(
        theme: breakLabTheme(),
        home: Scaffold(
          body: SizedBox(
            width: 340,
            child: ListView(
              controller: scroll,
              children: [
                const SizedBox(height: 40),
                SizedBox(
                  height: 380,
                  child: BreakTableView(
                    table: TableSize.sevenFoot,
                    position: const BreakPosition(x: 0.05, y: 0.5),
                    onChanged: (p) => moved = p,
                  ),
                ),
                const SizedBox(height: 1200),
              ],
            ),
          ),
        ),
      ));

      await slowDrag(tester, tester.getCenter(find.byType(BreakTableView)),
          const Offset(0, 55));

      expect(moved, isNotNull, reason: 'the scroll swallowed the drag');
      expect(scroll.offset, 0, reason: 'the list scrolled instead');
    });

    testWidgets('draws nothing for a table with no dimensions', (tester) async {
      await tester.pumpWidget(view(table: TableSize.custom));
      expect(paintOf<BreakTableView>(), findsNothing);
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

    testWidgets('the table itself is the button', (tester) async {
      var taps = 0;
      await tester.pumpWidget(wrap(strip(onTap: () => taps++)));
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

  group('setup screen', () {
    late BreakLabDatabase db;
    late Directory tempDir;
    late MeasureController controller;

    setUp(() async {
      db = await BreakLabDatabase.open(inMemoryDatabasePath,
          factory: databaseFactoryFfi);
      tempDir = await Directory.systemTemp.createTemp('breaklab_setup');
      controller = MeasureController(
        db: db,
        engine: StubbedEngine(),
        recorder: FakeRecorder(),
        tempDirectoryPath: tempDir.path,
        clock: () => DateTime(2026, 7, 29, 21),
      );
    });

    tearDown(() async {
      await db.close();
      await tempDir.delete(recursive: true);
    });

    Future<void> pumpScreen(WidgetTester tester,
        {Size size = const Size(1080, 2400)}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: breakLabTheme(),
        home: BreakSetupScreen(controller: controller),
      ));
      await tester.pump();
    }

    testWidgets('puts the table, the distance and the english in one place',
        (tester) async {
      await pumpScreen(tester);

      expect(find.text('Set up your break'), findsOneWidget);
      expect(find.byType(BreakTableView), findsOneWidget);
      for (final chip in ['7ft', '8ft', 'Pro 8', '9ft', 'Custom']) {
        expect(find.text(chip), findsOneWidget);
      }
      expect(find.textContaining('Breaking from'), findsOneWidget);
      expect(find.text('36.8"'), findsOneWidget);
      expect(find.text('TO THE RACK'), findsOneWidget);
      expect(find.text('English · Center'), findsOneWidget);
      expect(find.textContaining('never scored'), findsOneWidget);
      expect(find.text('DONE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the readout follows the ball', (tester) async {
      await pumpScreen(tester);
      controller.setPosition(const BreakPosition(x: 0.25, y: 0.08));
      await tester.pump();

      expect(find.textContaining('Left rail'), findsOneWidget);
      expect(find.text('40.1"'), findsOneWidget);
    });

    testWidgets('choosing a table size changes the distance', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.text('9ft'));
      await tester.pump();

      expect(controller.tableSize, TableSize.nineFoot);
      expect(find.text('47.8"'), findsOneWidget);
    });

    testWidgets('a custom table trades the drawing for a distance',
        (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.text('Custom'));
      await tester.pump();

      expect(find.byType(BreakTableView), findsNothing);
      expect(find.text('39"'), findsOneWidget); // the controller's default
      expect(find.text('TO THE RACK'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(controller.customDistanceInches, 40);

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
      expect(controller.customDistanceInches, 39);
    });

    testWidgets('the custom distance cannot run off either end',
        (tester) async {
      await pumpScreen(tester);
      controller.setTableSize(TableSize.custom);
      controller.setCustomDistance(BreakSetupScreen.minCustomInches);
      await tester.pump();

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
      expect(controller.customDistanceInches, BreakSetupScreen.minCustomInches);

      controller.setCustomDistance(BreakSetupScreen.maxCustomInches);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(controller.customDistanceInches, BreakSetupScreen.maxCustomInches);
    });

    testWidgets('the english face writes back to the controller',
        (tester) async {
      await pumpScreen(tester);
      final face = tester.getRect(paintOf<EnglishPicker>());
      // Below centre on the face is draw.
      await tester.tapAt(Offset(face.center.dx, face.bottom - 7));
      await tester.pump();

      expect(controller.english.y, lessThan(-0.3));
      expect(find.text('English · Draw'), findsOneWidget);
    });

    testWidgets('DONE closes the screen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: breakLabTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => openBreakSetup(context, controller),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(BreakSetupScreen), findsOneWidget);

      await tester.tap(find.text('DONE'));
      await tester.pumpAndSettle();
      expect(find.byType(BreakSetupScreen), findsNothing);
    });

    testWidgets('lays out on a short phone without overflowing',
        (tester) async {
      // The table gives up height to the controls rather than the column
      // overflowing — the failure mode that put a blank screen on the phone.
      await pumpScreen(tester, size: const Size(1080, 1600));

      expect(tester.takeException(), isNull);
      expect(find.text('DONE'), findsOneWidget);
      expect(find.byType(BreakTableView), findsOneWidget);
    });
  });
}
