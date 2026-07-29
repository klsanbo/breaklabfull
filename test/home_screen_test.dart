import 'dart:async';
import 'dart:io';

import 'package:breaklab/engine/engine_contract.dart';
import 'package:breaklab/features/home/coming_next_screen.dart';
import 'package:breaklab/features/home/home_screen.dart';
import 'package:breaklab/features/measure/measure_controller.dart';
import 'package:breaklab/models/break_position.dart';
import 'package:breaklab/models/table_size.dart';
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
      clock: () => DateTime(2026, 7, 28, 21),
    );
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: breakLabTheme(),
      home: HomeScreen(controller: controller),
    ));
    await tester.pump(); // let the post-frame stats load settle
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('lays out the dashboard from the approved wireframe',
      (tester) async {
    await pumpHome(tester);

    expect(find.text('BREAKLAB'), findsOneWidget);
    expect(find.text('Break Lab'), findsOneWidget);
    expect(find.text('TRAIN YOUR BREAK'), findsOneWidget);
    expect(find.text('Session ready.'), findsOneWidget);

    // Stat strip
    expect(find.text('BreakLab Score'), findsOneWidget);
    expect(find.text('Last session'), findsOneWidget);

    // The star
    expect(find.text('BREAK'), findsOneWidget);
    expect(find.text('READY'), findsOneWidget);

    // Setup chips
    expect(find.text('TABLE\n& SPOT'), findsOneWidget);
    expect(find.text('ENGLISH'), findsOneWidget);
    expect(find.text('Center'), findsOneWidget);

    // Five tiles — names appear in both the tiles and the bottom bar.
    for (final name in ['Sessions', 'History', 'Records', 'Score']) {
      expect(find.text(name), findsNWidgets(2));
    }
    expect(find.text('Break Map'), findsOneWidget);
    expect(find.text('STOP GUESSING. START TUNING.'), findsOneWidget);
  });

  testWidgets('shows dashes rather than invented numbers when empty',
      (tester) async {
    await pumpHome(tester);
    // Score and last session both have nothing to report yet.
    expect(find.text('—'), findsNWidgets(2));
    expect(find.text('0'), findsOneWidget); // session count
  });

  testWidgets('the distance chip reflects the current break position',
      (tester) async {
    await pumpHome(tester);
    expect(find.text('7ft · 36.8"'), findsOneWidget);

    controller.setPosition(const BreakPosition(x: 0.25, y: 0.03));
    await tester.pump();

    // A rail break is a longer trip to the rack.
    expect(find.text('7ft · 36.8"'), findsNothing);
    expect(
      controller.activeDistanceInches,
      greaterThan(TableSize.sevenFoot.travelDistanceInches),
    );
  });

  testWidgets('tapping a tile opens its destination', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.text('Break Map'));
    await tester.pumpAndSettle();

    expect(find.byType(ComingNextScreen), findsOneWidget);
    expect(
        find.text('Approved and specified — building next.'), findsOneWidget);
  });

  testWidgets('tapping BREAK arms the listener and the pill follows',
      (tester) async {
    await pumpHome(tester);
    expect(find.text('READY'), findsOneWidget);

    await tester.tap(find.text('BREAK'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(controller.phase, MeasurePhase.recording);
    expect(find.text('LISTENING'), findsOneWidget);
    expect(find.text('READY'), findsNothing);

    await controller.cancelBreak();
    await tester.pump();
  });
}
