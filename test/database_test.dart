import 'package:breaklab/engine/engine_contract.dart';
import 'package:breaklab/engine/stub_engine.dart';
import 'package:breaklab/models/break_result.dart';
import 'package:breaklab/models/session.dart';
import 'package:breaklab/models/table_size.dart';
import 'package:breaklab/services/db/breaklab_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late BreakLabDatabase db;

  setUp(() async {
    db = await BreakLabDatabase.open(inMemoryDatabasePath,
        factory: databaseFactoryFfi);
  });

  tearDown(() => db.close());

  BreakResult sampleBreak(int sessionId,
          {double? mph,
          AccuracyGrade grade = AccuracyGrade.target,
          DateTime? at}) =>
      BreakResult(
        sessionId: sessionId,
        recordedAt: at ?? DateTime(2026, 7, 28, 19),
        tableSize: TableSize.sevenFoot,
        travelDistanceInches: TableSize.sevenFoot.travelDistanceInches,
        preset: SensitivityPreset.normal,
        engineVersion: '0.1.0',
        grade: grade,
        detectedPairValid: grade != AccuracyGrade.unreliable,
        gapMs: mph == null ? null : 500,
        speedMph: mph,
      );

  test('speed math: 36.75 inches in 500 ms is ~4.18 mph', () {
    final mph = speedMph(travelDistanceInches: 36.75, gapMs: 500);
    expect(mph, closeTo(4.176, 0.001));
  });

  test('table size travel distances match the tester presets', () {
    expect(TableSize.sevenFoot.travelDistanceInches, 36.75);
    expect(TableSize.eightFoot.travelDistanceInches, 41.75);
    expect(TableSize.proEight.travelDistanceInches, 43.75);
    expect(TableSize.nineFoot.travelDistanceInches, 47.75);
    expect(TableSize.fromId('pro8'), TableSize.proEight);
    expect(TableSize.fromId('unknown'), TableSize.custom);
  });

  test('session lifecycle: open, insert breaks, stats, end', () async {
    final s = await db.insertSession(Session(
        startedAt: DateTime(2026, 7, 28, 19),
        tableSize: TableSize.sevenFoot));
    expect(s.id, isNotNull);
    expect((await db.openSession())!.id, s.id);

    await db.insertBreak(sampleBreak(s.id!, mph: 18.2));
    await db.insertBreak(sampleBreak(s.id!, mph: 21.4));
    await db.insertBreak(
        sampleBreak(s.id!, grade: AccuracyGrade.unreliable));

    final stats = await db.sessionStats(s.id!);
    expect(stats.breakCount, 3);
    expect(stats.reliableCount, 2);
    expect(stats.bestMph, closeTo(21.4, 0.001));
    expect(stats.averageMph, closeTo(19.8, 0.001));

    await db.endSession(s.id!, DateTime(2026, 7, 28, 21));
    expect(await db.openSession(), isNull);
  });

  test('break round-trips through the database unchanged', () async {
    final s = await db.insertSession(Session(
        startedAt: DateTime(2026, 7, 28), tableSize: TableSize.nineFoot));
    final saved = await db.insertBreak(sampleBreak(s.id!, mph: 19.75));
    final loaded = (await db.breaksForSession(s.id!)).single;
    expect(loaded.id, saved.id);
    expect(loaded.speedMph, 19.75);
    expect(loaded.grade, AccuracyGrade.target);
    expect(loaded.tableSize, TableSize.sevenFoot);
    expect(loaded.engineVersion, '0.1.0');
    expect(loaded.schemaVersion, BreakResult.currentSchemaVersion);
  });

  test('unreliable breaks never count toward records', () async {
    final s = await db.insertSession(Session(
        startedAt: DateTime(2026, 7, 28), tableSize: TableSize.sevenFoot));
    await db.insertBreak(sampleBreak(s.id!, mph: 17.0));
    await db.insertBreak(sampleBreak(s.id!, mph: 22.3));
    await db.insertBreak(
        sampleBreak(s.id!, grade: AccuracyGrade.unreliable));

    final records = await db.personalRecords();
    expect(records.fastestBreak!.speedMph, 22.3);
    // best-session average needs >= 3 reliable breaks; only 2 exist.
    expect(records.bestSessionAverageMph, isNull);

    await db.insertBreak(sampleBreak(s.id!, mph: 18.0));
    final after = await db.personalRecords();
    expect(after.bestSessionAverageMph, closeTo(19.1, 0.001));
  });

  test('stub engine always reports unreliable and never a speed', () {
    final result = StubEngine().detect(const EngineInput(
      samples: [0, 1, 2],
      sampleRateHz: 48000,
      travelDistanceInches: 36.75,
    ));
    expect(result.grade, AccuracyGrade.unreliable);
    expect(result.speedMph, isNull);
    expect(result.engineVersion, '0.0.0-stub');
  });

  test('fromEngine maps a failed detection to a saveable break', () async {
    final s = await db.insertSession(Session(
        startedAt: DateTime(2026, 7, 28), tableSize: TableSize.sevenFoot));
    final result = StubEngine().detect(const EngineInput(
      samples: [],
      sampleRateHz: 48000,
      travelDistanceInches: 36.75,
    ));
    final b = BreakResult.fromEngine(
      sessionId: s.id!,
      recordedAt: DateTime(2026, 7, 28),
      tableSize: TableSize.sevenFoot,
      travelDistanceInches: 36.75,
      preset: SensitivityPreset.normal,
      result: result,
    );
    final saved = await db.insertBreak(b);
    expect(saved.id, isNotNull);
    expect(saved.hasSpeed, isFalse);
  });
}
