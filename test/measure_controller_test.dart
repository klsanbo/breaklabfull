import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:breaklab/engine/engine_contract.dart';
import 'package:breaklab/features/measure/measure_controller.dart';
import 'package:breaklab/models/table_size.dart';
import 'package:breaklab/services/db/breaklab_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Builds a minimal valid 48kHz/16-bit/mono PCM WAV.
Uint8List buildWav(List<int> samples, {int sampleRateHz = 48000}) {
  final dataLength = samples.length * 2;
  final bytes = BytesBuilder();
  void ascii(String s) => bytes.add(s.codeUnits);
  void u32(int v) => bytes
      .add((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
  void u16(int v) => bytes
      .add((ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List());

  ascii('RIFF');
  u32(36 + dataLength);
  ascii('WAVE');
  ascii('fmt ');
  u32(16);
  u16(1); // PCM
  u16(1); // mono
  u32(sampleRateHz);
  u32(sampleRateHz * 2); // byte rate
  u16(2); // block align
  u16(16); // bit depth
  ascii('data');
  u32(dataLength);
  for (final s in samples) {
    u16(s & 0xFFFF);
  }
  return bytes.toBytes();
}

class FakeRecorder implements BreakRecorder {
  FakeRecorder(this.wavBytes);

  final Uint8List wavBytes;
  final levelController = StreamController<double>.broadcast();
  String? path;
  bool cancelled = false;

  @override
  Future<void> start(String outputPath) async {
    path = outputPath;
  }

  @override
  Future<String> stop() async {
    await File(path!).writeAsBytes(wavBytes);
    return path!;
  }

  @override
  Future<void> cancel() async {
    cancelled = true;
  }

  @override
  Stream<double> get levels => levelController.stream;
}

class FixedEngine implements BreakLabEngine {
  FixedEngine(this.result);

  final EngineResult result;
  EngineInput? lastInput;

  @override
  String get version => result.engineVersion;

  @override
  EngineResult detect(EngineInput input) {
    lastInput = input;
    return result;
  }
}

void main() {
  sqfliteFfiInit();

  late BreakLabDatabase db;
  late Directory tempDir;

  setUp(() async {
    db = await BreakLabDatabase.open(inMemoryDatabasePath,
        factory: databaseFactoryFfi);
    tempDir = await Directory.systemTemp.createTemp('breaklab_test');
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  MeasureController makeController({
    required BreakRecorder recorder,
    required BreakLabEngine engine,
    Duration armDelay = const Duration(milliseconds: 20),
    Duration tail = const Duration(milliseconds: 40),
    Duration timeout = const Duration(milliseconds: 300),
  }) =>
      MeasureController(
        db: db,
        engine: engine,
        recorder: recorder,
        tempDirectoryPath: tempDir.path,
        clock: () => DateTime(2026, 7, 28, 20),
        armDelay: armDelay,
        tailAfterTrigger: tail,
        silenceTimeout: timeout,
      );

  const goodResult = EngineResult(
    engineVersion: '0.1.0',
    grade: AccuracyGrade.target,
    detectedPairValid: true,
    tipTimestampMs: 800,
    rackTimestampMs: 1240,
    gapMs: 440,
    speedMph: 4.75,
    confidence: 0.9,
  );

  Future<void> pump(Duration d) => Future<void>.delayed(d);

  test('one tap: loud level auto-stops, measures, saves, deletes temp wav',
      () async {
    final recorder = FakeRecorder(buildWav(List.filled(4800, 100)));
    final engine = FixedEngine(goodResult);
    final c = makeController(recorder: recorder, engine: engine);

    await c.startBreak();
    expect(c.phase, MeasurePhase.recording);

    await pump(const Duration(milliseconds: 30)); // past arm delay
    recorder.levelController.add(0.9); // the break
    await pump(const Duration(milliseconds: 10));
    expect(c.heardBreak, isTrue);

    await pump(const Duration(milliseconds: 60)); // past the tail
    await c.autoMeasurement; // then wait for the work itself, don't guess
    expect(c.phase, MeasurePhase.idle);
    expect(c.lastBreak, isNotNull);
    expect(c.lastBreak!.speedMph, 4.75);
    expect(engine.lastInput!.travelDistanceInches, 36.75);
    expect(engine.lastInput!.sampleRateHz, 48000);

    final session = await db.openSession();
    expect(session, isNotNull);
    expect((await db.breaksForSession(session!.id!)).length, 1);
    expect(File(recorder.path!).existsSync(), isFalse);
  });

  test('levels during arm delay are ignored (button tap is not a break)',
      () async {
    final recorder = FakeRecorder(buildWav(List.filled(4800, 100)));
    final c = makeController(
        recorder: recorder,
        engine: FixedEngine(goodResult),
        armDelay: const Duration(milliseconds: 100));

    await c.startBreak();
    recorder.levelController.add(0.9); // immediate tap noise
    await pump(const Duration(milliseconds: 30));
    expect(c.heardBreak, isFalse);
    expect(c.phase, MeasurePhase.recording);
    await c.cancelBreak();
  });

  test('quiet levels never trigger; silence timeout cancels with message',
      () async {
    final recorder = FakeRecorder(buildWav(List.filled(4800, 100)));
    final c =
        makeController(recorder: recorder, engine: FixedEngine(goodResult));

    await c.startBreak();
    await pump(const Duration(milliseconds: 30));
    recorder.levelController.add(0.2);
    recorder.levelController.add(0.3);
    await pump(const Duration(milliseconds: 350)); // past timeout
    expect(c.phase, MeasurePhase.idle);
    expect(c.lastBreak, isNull);
    expect(recorder.cancelled, isTrue);
    expect(c.errorMessage, contains("Didn't hear a break"));
  });

  test('manual measureNow fallback works without a trigger', () async {
    final recorder = FakeRecorder(buildWav(List.filled(4800, 100)));
    final c =
        makeController(recorder: recorder, engine: FixedEngine(goodResult));
    await c.startBreak();
    final saved = await c.measureNow();
    expect(saved, isNotNull);
    expect(saved!.speedMph, 4.75);
  });

  test('custom table size feeds the manual distance to the engine', () async {
    final recorder = FakeRecorder(buildWav(List.filled(4800, 100)));
    final engine = FixedEngine(goodResult);
    final c = makeController(recorder: recorder, engine: engine);
    c.setTableSize(TableSize.custom);
    c.setCustomDistance(38.0);

    await c.startBreak();
    await c.measureNow();
    expect(engine.lastInput!.travelDistanceInches, 38.0);
  });

  test('bad audio (wrong sample rate) reports error and saves nothing',
      () async {
    final recorder =
        FakeRecorder(buildWav(List.filled(4410, 100), sampleRateHz: 44100));
    final c =
        makeController(recorder: recorder, engine: FixedEngine(goodResult));

    await c.startBreak();
    final saved = await c.measureNow();
    expect(saved, isNull);
    expect(c.errorMessage, contains('48000'));
    expect(c.phase, MeasurePhase.idle);
    expect(await db.openSession(), isNull);
    expect(File(recorder.path!).existsSync(), isFalse);
  });

  test('cancel discards the recording and stays idle-safe', () async {
    final recorder = FakeRecorder(buildWav(List.filled(480, 0)));
    final c =
        makeController(recorder: recorder, engine: FixedEngine(goodResult));
    await c.startBreak();
    await c.cancelBreak();
    expect(recorder.cancelled, isTrue);
    expect(c.phase, MeasurePhase.idle);
  });

  test('second break reuses the open session', () async {
    final recorder = FakeRecorder(buildWav(List.filled(4800, 100)));
    final c =
        makeController(recorder: recorder, engine: FixedEngine(goodResult));
    await c.startBreak();
    await c.measureNow();
    await c.startBreak();
    await c.measureNow();

    final sessions = await db.sessions();
    expect(sessions.length, 1);
    expect((await db.breaksForSession(sessions.single.id!)).length, 2);
  });
}
