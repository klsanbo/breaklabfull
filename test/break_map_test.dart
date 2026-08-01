import 'dart:async';
import 'dart:io';

import 'package:breaklab/engine/engine_contract.dart';
import 'package:breaklab/features/break_map/break_map_screen.dart';
import 'package:breaklab/features/break_map/widgets/heat_table.dart';
import 'package:breaklab/features/measure/measure_controller.dart';
import 'package:breaklab/models/break_outcome.dart';
import 'package:breaklab/models/break_position.dart';
import 'package:breaklab/models/break_result.dart';
import 'package:breaklab/models/break_zone.dart';
import 'package:breaklab/models/session.dart';
import 'package:breaklab/models/speed_band.dart';
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

  group('break zones', () {
    test('the kitchen divides into three across the table', () {
      expect(BreakZone.forY(0.0), BreakZone.left);
      expect(BreakZone.forY(0.34), BreakZone.left);
      expect(BreakZone.forY(0.35), BreakZone.center);
      expect(BreakZone.forY(0.5), BreakZone.center);
      expect(BreakZone.forY(0.64), BreakZone.center);
      expect(BreakZone.forY(0.65), BreakZone.right);
      expect(BreakZone.forY(1.0), BreakZone.right);
    });

    test('the rail spots group with the side they belong to', () {
      // BreakPosition names five spots; the map uses three, so Left rail joins
      // Left and Right rail joins Right.
      expect(BreakZone.forY(0.05), BreakZone.left);
      expect(BreakZone.forY(0.95), BreakZone.right);
    });

    test('a zone is not rated until it has five readable breaks', () {
      for (var n = 0; n < 5; n++) {
        final stats = ZoneStats(
          zone: BreakZone.center,
          breakCount: n + 3,
          reliableCount: n,
        );
        expect(stats.isRated, isFalse, reason: '$n readable breaks');
        expect(stats.breaksNeeded, 5 - n);
      }
      const rated = ZoneStats(
        zone: BreakZone.center,
        breakCount: 5,
        reliableCount: 5,
      );
      expect(rated.isRated, isTrue);
      expect(rated.breaksNeeded, 0);
    });

    test('attempts do not count toward the rating, only readable breaks', () {
      // Twenty attempts the engine could not read is still an unrated zone.
      const stats = ZoneStats(
        zone: BreakZone.left,
        breakCount: 20,
        reliableCount: 2,
      );
      expect(stats.isRated, isFalse);
    });
  });

  group('zone stats from the database', () {
    late BreakLabDatabase db;

    setUp(() async {
      db = await BreakLabDatabase.open(
        inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
    });
    tearDown(() => db.close());

    Future<BreakResult> add(
      int sessionId, {
      required double y,
      double? mph,
      BreakOutcome? outcome,
    }) => db.insertBreak(
      BreakResult(
        sessionId: sessionId,
        recordedAt: DateTime(2026, 7, 30, 20),
        tableSize: TableSize.sevenFoot,
        travelDistanceInches: 36.75,
        preset: SensitivityPreset.normal,
        engineVersion: '0.1.0',
        grade: mph == null ? AccuracyGrade.unreliable : AccuracyGrade.excellent,
        detectedPairValid: mph != null,
        position: BreakPosition(x: 0.25, y: y),
        gapMs: mph == null ? null : 500,
        speedMph: mph,
        outcome: outcome,
      ),
    );

    test('always returns all three zones, even with no breaks', () async {
      final zones = await db.zoneStats();
      expect(zones.length, 3);
      expect(zones.map((z) => z.zone), BreakZone.values);
      expect(zones.every((z) => z.isRated), isFalse);
      expect(zones.every((z) => z.averageMph == null), isTrue);
    });

    test('groups breaks by where they were taken from', () async {
      final s = await db.insertSession(
        Session(
          startedAt: DateTime(2026, 7, 30, 19),
          tableSize: TableSize.sevenFoot,
        ),
      );

      await add(s.id!, y: 0.1, mph: 19.0);
      await add(s.id!, y: 0.2, mph: 20.0);
      await add(s.id!, y: 0.5, mph: 22.0);
      await add(s.id!, y: 0.9, mph: 24.0);

      final zones = await db.zoneStats();
      final byZone = {for (final z in zones) z.zone: z};

      expect(byZone[BreakZone.left]!.reliableCount, 2);
      expect(byZone[BreakZone.left]!.averageMph, closeTo(19.5, 0.001));
      expect(byZone[BreakZone.center]!.reliableCount, 1);
      expect(byZone[BreakZone.right]!.bestMph, closeTo(24.0, 0.001));
    });

    test('a break with no recorded position belongs to no zone', () async {
      // Guessing centre would put invented data on a map that promises not to
      // guess.
      final s = await db.insertSession(
        Session(
          startedAt: DateTime(2026, 7, 30, 19),
          tableSize: TableSize.sevenFoot,
        ),
      );

      await db.insertBreak(
        BreakResult(
          sessionId: s.id!,
          recordedAt: DateTime(2026, 7, 30, 20),
          tableSize: TableSize.sevenFoot,
          travelDistanceInches: 36.75,
          preset: SensitivityPreset.normal,
          engineVersion: '0.1.0',
          grade: AccuracyGrade.excellent,
          detectedPairValid: true,
          gapMs: 500,
          speedMph: 21.0,
        ),
      );

      final zones = await db.zoneStats();
      expect(zones.fold<int>(0, (n, z) => n + z.breakCount), 0);
    });

    test(
      'unreadable breaks count as attempts but not toward the rating',
      () async {
        final s = await db.insertSession(
          Session(
            startedAt: DateTime(2026, 7, 30, 19),
            tableSize: TableSize.sevenFoot,
          ),
        );

        await add(s.id!, y: 0.5, mph: 20.0);
        await add(s.id!, y: 0.5); // no speed
        await add(s.id!, y: 0.5); // no speed

        final centre = (await db.zoneStats()).firstWhere(
          (z) => z.zone == BreakZone.center,
        );
        expect(centre.breakCount, 3);
        expect(centre.reliableCount, 1);
        expect(centre.isRated, isFalse);
      },
    );
  });

  group('break map screen', () {
    late BreakLabDatabase db;
    late Directory tempDir;
    late MeasureController controller;

    setUp(() async {
      db = await BreakLabDatabase.open(
        inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      tempDir = await Directory.systemTemp.createTemp('breaklab_map');
      controller = MeasureController(
        db: db,
        engine: StubbedEngine(),
        recorder: FakeRecorder(),
        tempDirectoryPath: tempDir.path,
        clock: () => DateTime(2026, 7, 30, 21),
      );
    });

    tearDown(() async {
      await db.close();
      await tempDir.delete(recursive: true);
    });

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: breakLabTheme(),
          home: BreakMapScreen(controller: controller),
        ),
      );
      await tester.pump();
    }

    testWidgets('says it cannot draw a map before it has the breaks', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('BREAK MAP'), findsOneWidget);
      expect(find.byType(HeatTable), findsOneWidget);
      expect(find.text('NOT ENOUGH BREAKS TO DRAW A MAP'), findsOneWidget);
      expect(find.textContaining('does not guess'), findsOneWidget);
      // Every zone reports how far off it is rather than showing nothing.
      expect(find.textContaining('0 of 5 breaks'), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the legend carries the recalibrated bands, fastest first', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('HARD'), findsOneWidget);
      expect(find.text('STRONG'), findsOneWidget);
      expect(find.text('SOLID'), findsOneWidget);
      expect(find.text('CONTROLLED'), findsOneWidget);
      expect(find.text('23.0+ MPH'), findsOneWidget);
      expect(find.text('16.0 - 19.9 MPH'), findsOneWidget);
      // Elite belongs to the BreakLab Score and appears nowhere on this screen.
      expect(find.textContaining('ELITE'), findsNothing);
    });

    testWidgets('a rated zone shows its speed, score and count', (
      tester,
    ) async {
      const outcome = BreakOutcome(
        ballsMade: 1,
        scratched: false,
        spread: SpreadQuality.good,
        cueBallAfter: CueBallAfter.stayedCenter,
      );
      // Real database work has to run inside runAsync. testWidgets bodies run
      // under a fake clock, so a sqflite future awaited directly here never
      // completes — and because the clock never advances, the test framework's
      // own timeout cannot fire either. It hangs silently rather than failing.
      await tester.runAsync(() async {
        final s = await db.insertSession(
          Session(
            startedAt: DateTime(2026, 7, 30, 19),
            tableSize: TableSize.sevenFoot,
          ),
        );
        for (var i = 0; i < 5; i++) {
          await db.insertBreak(
            BreakResult(
              sessionId: s.id!,
              recordedAt: DateTime(2026, 7, 30, 20),
              tableSize: TableSize.sevenFoot,
              travelDistanceInches: 36.75,
              preset: SensitivityPreset.normal,
              engineVersion: '0.1.0',
              grade: AccuracyGrade.excellent,
              detectedPairValid: true,
              position: const BreakPosition(x: 0.25, y: 0.5),
              gapMs: 500,
              speedMph: 21.0,
              outcome: outcome,
            ),
          );
        }
        await controller.refreshStats();
      });

      await pump(tester);

      expect(find.text('NOT ENOUGH BREAKS TO DRAW A MAP'), findsNothing);
      expect(find.text('YOUR BEST ZONE'), findsOneWidget);
      expect(find.textContaining('CENTER'), findsWidgets);
      expect(find.text('21.0'), findsOneWidget);
      expect(find.text('BEST SCORE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the break button is here and fires', (tester) async {
      var breaks = 0;
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: breakLabTheme(),
          home: BreakMapScreen(
            controller: controller,
            onBreak: () async => breaks++,
          ),
        ),
      );
      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('BREAK'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('BREAK'));
      await tester.pump();

      expect(breaks, 1);
    });

    testWidgets('lays out on a short phone without overflowing', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 1600);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: breakLabTheme(),
          home: BreakMapScreen(controller: controller),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(HeatTable), findsOneWidget);
    });
  });

  group('heat tints', () {
    test('faster bands are deeper blue, and no two share a tint', () {
      final tints = SpeedBand.values.map(HeatTable.tintFor).toList();
      expect(tints.toSet().length, SpeedBand.values.length);
    });
  });
}
