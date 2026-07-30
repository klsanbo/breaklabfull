import 'dart:async';
import 'dart:io';

import 'package:breaklab/engine/engine_contract.dart';
import 'package:breaklab/features/home/coming_next_screen.dart';
import 'package:breaklab/features/home/home_screen.dart';
import 'package:breaklab/features/home/widgets/bottom_nav.dart';
import 'package:breaklab/features/home/widgets/recent_session_card.dart';
import 'package:breaklab/features/home/widgets/score_card.dart';
import 'package:breaklab/features/home/widgets/setup_strip.dart';
import 'package:breaklab/features/home/widgets/stat_strip.dart';
import 'package:breaklab/features/measure/break_setup_screen.dart';
import 'package:breaklab/features/measure/measure_controller.dart';
import 'package:breaklab/models/break_position.dart';
import 'package:breaklab/scoring/breaklab_score.dart';
import 'package:breaklab/services/db/breaklab_database.dart';
import 'package:breaklab/theme/breaklab_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Minimal recorder that satisfies the interface without platform channels.
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

void main() {
  sqfliteFfiInit();

  late BreakLabDatabase db;
  late Directory tempDir;
  late MeasureController controller;
  late FakeRecorder recorder;

  setUp(() async {
    db = await BreakLabDatabase.open(inMemoryDatabasePath,
        factory: databaseFactoryFfi);
    tempDir = await Directory.systemTemp.createTemp('breaklab_home');
    recorder = FakeRecorder();
    controller = MeasureController(
      db: db,
      engine: StubbedEngine(),
      recorder: recorder,
      tempDirectoryPath: tempDir.path,
      clock: () => DateTime(2026, 7, 30, 21),
    );
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  Future<void> pumpHome(WidgetTester tester,
      {Size size = const Size(1080, 2400)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: breakLabTheme(),
      home: HomeScreen(controller: controller),
    ));
    await tester.pump(); // let the post-frame stats load settle
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('lays out the approved dashboard', (tester) async {
    await pumpHome(tester);

    expect(find.text('BREAK LAB'), findsOneWidget);
    expect(find.text('PRACTICE. MEASURE. IMPROVE.'), findsOneWidget);

    // The star.
    expect(find.text('BREAK'), findsOneWidget);
    expect(find.text('TAP TO START'), findsOneWidget);
    expect(find.text('READY'), findsOneWidget);

    // One door for setup, and the table is the button.
    expect(find.byType(SetupStrip), findsOneWidget);
    expect(find.text('7ft Bar Box · Center · 36.8"'), findsOneWidget);

    expect(find.byType(ScoreCard), findsOneWidget);
    expect(find.text('BREAKLAB\nSCORE'), findsOneWidget);
    expect(find.byType(RecentSessionCard), findsOneWidget);
    expect(find.text('RECENT SESSION'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the score bars name the components but not the weights',
      (tester) async {
    // The weights live on the Score screen. Five bars in weight order here,
    // heaviest first, and no percentages competing with the number.
    await pumpHome(tester);

    for (final label in [
      'CUE BALL\nCONTROL',
      'CONSISTENCY',
      'CLEAN\nBREAKS',
      'BALLS MADE',
      'SPEED',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    for (final weight in ['30%', '25%', '20%', '15%', '10%']) {
      expect(find.text(weight), findsNothing);
    }
  });

  testWidgets('no number appears twice with two different labels',
      (tester) async {
    // Consistency and clean breaks are bars on the score card. Printing them
    // again as totals underneath would leave a player deciding which one to
    // believe.
    await pumpHome(tester);
    expect(find.text('CONSISTENCY'), findsOneWidget);
    expect(find.text('CLEAN'), findsNothing);
    // SESSIONS is both a totals cell and a bar destination, which is fine —
    // they are in different furniture. The finder has to say which one it
    // means rather than the test asserting a magic count.
    expect(
      find.descendant(
          of: find.byType(StatStrip), matching: find.text('SESSIONS')),
      findsOneWidget,
    );
    expect(
      find.descendant(
          of: find.byType(BreakLabNav), matching: find.text('SESSIONS')),
      findsOneWidget,
    );
    expect(find.text('IN THE SCORE'), findsOneWidget);
  });

  testWidgets('the masthead gives instead of overflowing at large text',
      (tester) async {
    // It overflowed by 98 pixels the moment the type got wider: two Spacers
    // around a rigid Column left it no way to give. Anyone running a large
    // system font would have seen the name run off the edge.
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpHome(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('BREAK LAB'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('an 84 reads STRONG, not ELITE', (tester) async {
    // Elite starts at 90 and is not moved down to flatter anyone.
    expect(BreakLabScore.gradeFor(84), 'Strong');
    expect(BreakLabScore.gradeFor(90), 'Elite');
    expect(BreakLabScore.gradeFor(89), 'Strong');

    await pumpHome(tester);
    expect(find.text('NO SCORE YET'), findsOneWidget);
  });

  testWidgets('shows dashes rather than invented numbers when empty',
      (tester) async {
    await pumpHome(tester);
    // Nothing measured: no zeros pretending to be measurements.
    expect(find.text('—'), findsWidgets);
    expect(
      find.textContaining('No breaks measured yet'),
      findsOneWidget,
    );
  });

  testWidgets('the totals are the four V006 asked for, with real sources',
      (tester) async {
    // I claimed these needed queries that did not exist. personalRecords() had
    // been in the database the whole time; home simply was not loading it.
    await pumpHome(tester);

    for (final label in [
      'SESSIONS',
      'TOTAL BREAKS',
      'BEST SESSION',
      'SCRATCH',
    ]) {
      expect(
        find.descendant(of: find.byType(StatStrip), matching: find.text(label)),
        findsOneWidget,
        reason: '$label is missing from the totals row',
      );
    }
    expect(find.text('PERSONAL BEST'), findsOneWidget);
  });

  testWidgets('an unknown scratch rate is a dash, never 0%', (tester) async {
    // Nobody has filled in an outcome card, so the rate is unknown. Printing
    // 0% would be a claim that no break has ever scratched.
    await pumpHome(tester);
    expect(controller.scratchRate, isNull);
    expect(find.text('0%'), findsNothing);
  });

  testWidgets('the setup strip follows the stored position', (tester) async {
    await pumpHome(tester);
    expect(find.text('7ft Bar Box · Center · 36.8"'), findsOneWidget);

    controller.setPosition(const BreakPosition(x: 0.25, y: 0.08));
    await tester.pump();

    expect(find.text('7ft Bar Box · Center · 36.8"'), findsNothing);
    expect(find.text('7ft Bar Box · Left rail · 40.1"'), findsOneWidget);
  });

  testWidgets('tapping the strip opens the one setup screen', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.byType(SetupStrip));
    await tester.pumpAndSettle();

    expect(find.byType(BreakSetupScreen), findsOneWidget);
  });

  testWidgets('the bottom bar has five destinations with HOME in the middle',
      (tester) async {
    await pumpHome(tester);
    expect(find.byType(BreakLabNav), findsOneWidget);
    expect(NavDestination.values.length, 5);
    expect(NavDestination.values[2], NavDestination.home);
    for (final d in NavDestination.values) {
      // Scoped to the bar: SESSIONS is also a totals cell, and an unscoped
      // finder here is the same mistake twice in one file.
      expect(
        find.descendant(
            of: find.byType(BreakLabNav), matching: find.text(d.label)),
        findsOneWidget,
        reason: '${d.label} is missing from the bar',
      );
    }
  });

  testWidgets('a bar destination opens its screen, HOME does nothing',
      (tester) async {
    await pumpHome(tester);

    await tester.tap(find.text('POSITIONS'));
    await tester.pumpAndSettle();
    expect(find.byType(ComingNextScreen), findsOneWidget);
  });

  testWidgets('HOME goes nowhere, because you are already there',
      (tester) async {
    await pumpHome(tester);
    await tester.tap(find.text('HOME'));
    await tester.pumpAndSettle();
    expect(find.byType(ComingNextScreen), findsNothing);
    expect(find.text('BREAK'), findsOneWidget);
  });

  testWidgets('tapping BREAK arms the listener and the pill follows',
      (tester) async {
    await pumpHome(tester);
    expect(find.text('READY'), findsOneWidget);

    await tester.tap(find.text('BREAK'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(controller.phase, MeasurePhase.recording);
    // Status lives in the pill only; the button keeps saying BREAK.
    expect(find.text('LISTENING'), findsOneWidget);
    expect(find.text('READY'), findsNothing);
    expect(find.text('BREAK'), findsOneWidget);
    // The instruction goes away once it has been followed.
    expect(find.text('TAP TO START'), findsNothing);

    await controller.cancelBreak();
    await tester.pump();
  });

  testWidgets('lays out without overflow on a small phone', (tester) async {
    // The bug this exists to catch: an unbounded Row inside the scrolling
    // column made the whole body fail to lay out and the screen came up blank
    // on the phone while the widget tests still passed.
    await pumpHome(tester, size: const Size(1080, 1920));

    expect(tester.takeException(), isNull);
    expect(find.text('BREAK'), findsOneWidget);
    expect(find.byType(BreakLabNav), findsOneWidget);
  });

  testWidgets('lays out without overflow on a tall narrow phone',
      (tester) async {
    await pumpHome(tester, size: const Size(1080, 2400));
    expect(tester.takeException(), isNull);
    expect(find.text('READY'), findsOneWidget);
  });

  testWidgets('the status pill shows its whole label, never clipped',
      (tester) async {
    // It read "LI..." on the phone: the pill was flexible and lost the contest
    // for space against the rules beside it.
    await pumpHome(tester, size: const Size(1080, 1920));

    final pill = tester.widget<Text>(find.text('READY'));
    expect(pill.overflow, isNot(TextOverflow.ellipsis),
        reason: 'a status label that can ellipsis will eventually ellipsis');

    final painted = tester.renderObject<RenderBox>(find.text('READY'));
    expect(painted.size.width, greaterThan(40),
        reason: 'READY rendered narrower than its own text');
  });
}
