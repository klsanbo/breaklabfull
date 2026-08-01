import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:breaklab/engine/engine_contract.dart';
import 'package:breaklab/features/home/home_screen.dart';
import 'package:breaklab/features/measure/measure_controller.dart';
import 'package:breaklab/features/measure/widgets/break_button.dart';
import 'package:breaklab/features/measure/widgets/reading_review_sheet.dart';
import 'package:breaklab/features/measure/widgets/unreadable_break_card.dart';
import 'package:breaklab/features/upgrade/upgrade_screen.dart';
import 'package:breaklab/models/break_result.dart';
import 'package:breaklab/models/entitlement.dart';
import 'package:breaklab/models/session.dart';
import 'package:breaklab/models/table_size.dart';
import 'package:breaklab/services/db/breaklab_database.dart';
import 'package:breaklab/services/entitlement/entitlement_store.dart';
import 'package:breaklab/services/purchase/purchase_gateway.dart';
import 'package:breaklab/theme/breaklab_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Minimal valid 48kHz/16-bit/mono PCM WAV.
Uint8List buildWav(List<int> samples, {int sampleRateHz = 48000}) {
  final dataLength = samples.length * 2;
  final bytes = BytesBuilder();
  void ascii(String s) => bytes.add(s.codeUnits);
  void u32(int v) => bytes.add(
        (ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List(),
      );
  void u16(int v) => bytes.add(
        (ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List(),
      );

  ascii('RIFF');
  u32(36 + dataLength);
  ascii('WAVE');
  ascii('fmt ');
  u32(16);
  u16(1);
  u16(1);
  u32(sampleRateHz);
  u32(sampleRateHz * 2);
  u16(2);
  u16(16);
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

  @override
  Future<void> start(String outputPath) async => path = outputPath;

  @override
  Future<String> stop() async {
    await File(path!).writeAsBytes(wavBytes);
    return path!;
  }

  @override
  Future<void> cancel() async {}

  @override
  Stream<double> get levels => levelController.stream;
}

class FixedEngine implements BreakLabEngine {
  FixedEngine(this.result);

  final EngineResult result;

  @override
  String get version => result.engineVersion;

  @override
  EngineResult detect(EngineInput input) => result;
}

const readable = EngineResult(
  engineVersion: '0.1.0',
  grade: AccuracyGrade.target,
  detectedPairValid: true,
  tipTimestampMs: 800,
  rackTimestampMs: 1240,
  gapMs: 440,
  speedMph: 21.4,
  confidence: 0.9,
);

const unreadable = EngineResult(
  engineVersion: '0.1.0',
  grade: AccuracyGrade.unreliable,
  detectedPairValid: false,
);

BreakResult sampleBreak({
  double? tip = 800,
  double? rack = 1240,
  double? gap = 412,
  double? speed = 21.4,
  AccuracyGrade grade = AccuracyGrade.target,
}) =>
    BreakResult(
      id: 1,
      sessionId: 1,
      recordedAt: DateTime(2026, 8, 4, 21),
      tableSize: TableSize.sevenFoot,
      travelDistanceInches: 40.1,
      preset: SensitivityPreset.normal,
      engineVersion: '0.1.0',
      grade: grade,
      detectedPairValid: grade != AccuracyGrade.unreliable,
      tipTimestampMs: tip,
      rackTimestampMs: rack,
      gapMs: gap,
      speedMph: speed,
    );

void main() {
  sqfliteFfiInit();

  late BreakLabDatabase db;
  late Directory tempDir;

  // Tuesday night, first break. The week is up the following Tuesday.
  final firstBreak = DateTime(2026, 8, 4, 21);
  final dayEight = DateTime(2026, 8, 12, 20);

  setUp(() async {
    db = await BreakLabDatabase.open(
      inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    tempDir = await Directory.systemTemp.createTemp('breaklab_paywall');
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  MeasureController makeController({
    required EngineResult result,
    required EntitlementStore store,
    DateTime? now,
  }) =>
      MeasureController(
        db: db,
        engine: FixedEngine(result),
        recorder: FakeRecorder(buildWav(List<int>.filled(4800, 0))),
        tempDirectoryPath: tempDir.path,
        entitlements: store,
        clock: () => now ?? firstBreak,
      );

  group('the trial clock, from the controller', () {
    test('a readable break starts the seven days, once', () async {
      final store = InMemoryEntitlementStore();
      final c = makeController(result: readable, store: store);

      expect(c.entitlement.trialStartedAt, isNull);
      await c.startBreak();
      await c.measureNow();

      expect(c.entitlement.trialStartedAt, firstBreak);
      expect(
        (await store.load()).trialStartedAt,
        firstBreak,
        reason: 'the clock has to survive the app being killed',
      );

      // A second break must not push the deadline out, or the trial never
      // ends for the player most likely to buy.
      await c.startBreak();
      await c.measureNow();
      expect(c.entitlement.trialStartedAt, firstBreak);
      expect(store.saveCount, 1);
    });

    test('a break we could not read never starts the clock', () async {
      // Spending someone's week on a reading we refused to give them is how
      // an app earns a one-star review that happens to be correct.
      final store = InMemoryEntitlementStore();
      final c = makeController(result: unreadable, store: store);

      await c.startBreak();
      final saved = await c.measureNow();

      expect(saved, isNotNull);
      expect(saved!.hasSpeed, isFalse);
      expect(c.entitlement.trialStartedAt, isNull);
      expect(store.saveCount, 0);
    });

    test('day eight stops measuring and nothing else', () async {
      final store = InMemoryEntitlementStore(
        entitlement: Entitlement(trialStartedAt: firstBreak),
      );
      final c = makeController(result: readable, store: store, now: dayEight);
      await c.refreshStats();

      expect(c.canMeasure, isFalse);
      await c.startBreak();
      expect(
        c.phase,
        MeasurePhase.idle,
        reason: 'the recorder must not arm once the week is up',
      );

      // Everything already recorded is still readable. Nothing about the lock
      // touches the database.
      expect(c.breaksAllTime, 0);
      expect(await db.sessions(), isEmpty);
    });

    test('buying it unlocks immediately and keeps the week that was', () async {
      final store = InMemoryEntitlementStore(
        entitlement: Entitlement(trialStartedAt: firstBreak),
      );
      final c = makeController(result: readable, store: store, now: dayEight);
      await c.refreshStats();
      expect(c.canMeasure, isFalse);

      await c.markPurchased();

      expect(c.canMeasure, isTrue);
      expect((await store.load()).purchased, isTrue);
      expect(
        (await store.load()).trialStartedAt,
        firstBreak,
        reason: 'the week that was is a fact, not something to erase',
      );
    });
  });

  group('BL-021 Upgrade', () {
    Future<MeasureController> seeded(
      WidgetTester tester, {
      required Entitlement entitlement,
    }) async {
      final store = InMemoryEntitlementStore(entitlement: entitlement);
      final c = makeController(result: readable, store: store, now: dayEight);
      await tester.runAsync(() async {
        final s = await db.insertSession(
          Session(startedAt: firstBreak, tableSize: TableSize.sevenFoot),
        );
        await db.insertBreak(
          BreakResult(
            sessionId: s.id!,
            recordedAt: firstBreak,
            tableSize: TableSize.sevenFoot,
            travelDistanceInches: 36.75,
            preset: SensitivityPreset.normal,
            engineVersion: '0.1.0',
            grade: AccuracyGrade.excellent,
            detectedPairValid: true,
            gapMs: 440,
            speedMph: 22.8,
          ),
        );
        await c.refreshStats();
      });
      return c;
    }

    Future<void> pumpUpgrade(
      WidgetTester tester,
      MeasureController c, {
      PurchaseGateway gateway = const UnwiredPurchaseGateway(),
      required DateTime now,
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: breakLabTheme(),
          home: UpgradeScreen(controller: c, gateway: gateway, now: now),
        ),
      );
      await tester.pump();
    }

    Future<void> tapVisible(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pump();
      await tester.tap(finder);
    }

    testWidgets('mid-trial, it leads with the pile and not with the price', (
      tester,
    ) async {
      final c = await seeded(
        tester,
        entitlement: Entitlement(trialStartedAt: firstBreak),
      );
      await pumpUpgrade(tester, c, now: DateTime(2026, 8, 9, 21));

      expect(find.text('FREE TRIAL'), findsOneWidget);
      expect(find.text('2 days left'), findsOneWidget);
      expect(find.text('WHAT YOU HAVE BUILT SO FAR'), findsOneWidget);
      expect(find.text('BREAKS MEASURED'), findsOneWidget);
      expect(find.text('YOUR BEST'), findsOneWidget);
      expect(find.text('22.8'), findsOneWidget);
      expect(find.text('ZONES RATED'), findsOneWidget);

      expect(find.text(r'$9.99'), findsOneWidget);
      expect(find.text('ONE TIME · NOT A SUBSCRIPTION'), findsOneWidget);
      expect(find.text(r'UNLOCK BREAKLAB — $9.99'), findsOneWidget);
      expect(find.text('Not now — I have 2 days left'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'on day eight it says what is still theirs, and how to get '
        'back in', (tester) async {
      final c = await seeded(
        tester,
        entitlement: Entitlement(trialStartedAt: firstBreak),
      );
      await pumpUpgrade(tester, c, now: dayEight);

      expect(find.text('YOUR TRIAL HAS ENDED'), findsOneWidget);
      expect(find.text('YOURS, AND STILL OPEN TO YOU'), findsOneWidget);
      expect(
        find.text('NOTHING IS LOCKED BUT THE BREAK BUTTON'),
        findsOneWidget,
      );
      expect(find.textContaining('all still work'), findsOneWidget);
      expect(find.text(r'START MEASURING AGAIN — $9.99'), findsOneWidget);

      // Two doors out, always. A screen that walls a player off from his own
      // breaks with no visible way back gets deleted, not bought.
      expect(find.text('Restore'), findsOneWidget);
      expect(find.text('Restore a purchase'), findsOneWidget);
      expect(find.text('FREE TRIAL'), findsNothing);
    });

    testWidgets(
        'a purchase that cannot happen yet says so, and unlocks '
        'nothing', (tester) async {
      // Billing is not wired: the Play Console product does not exist. The
      // screen refuses honestly rather than unlocking the app for free.
      final c = await seeded(
        tester,
        entitlement: Entitlement(trialStartedAt: firstBreak),
      );
      await pumpUpgrade(tester, c, now: dayEight);

      await tapVisible(
        tester,
        find.text(r'START MEASURING AGAIN — $9.99'),
      );
      await tester.pumpAndSettle();

      expect(find.text(UnwiredPurchaseGateway.notWiredMessage), findsOneWidget);
      expect(c.entitlement.purchased, isFalse);
      expect(c.canMeasure, isFalse);
    });

    testWidgets('a real purchase unlocks measuring', (tester) async {
      final gateway = FakePurchaseGateway();
      final c = await seeded(
        tester,
        entitlement: Entitlement(trialStartedAt: firstBreak),
      );
      await pumpUpgrade(tester, c, gateway: gateway, now: dayEight);

      await tapVisible(
        tester,
        find.text(r'START MEASURING AGAIN — $9.99'),
      );
      await tester.pumpAndSettle();

      expect(gateway.buyCount, 1);
      expect(c.entitlement.purchased, isTrue);
      expect(c.canMeasure, isTrue);
    });
  });

  group('BL-024 the break we could not read', () {
    testWidgets('names the failure it can actually tell apart', (tester) async {
      expect(
        UnreadableBreakCard.forBreak(
          sampleBreak(tip: null, rack: null, speed: null),
        ).reason,
        UnreadableReason.heardNothing,
      );
      expect(
        UnreadableBreakCard.forBreak(
          sampleBreak(rack: null, speed: null),
        ).reason,
        UnreadableReason.heardOneImpact,
      );
      expect(
        UnreadableBreakCard.forBreak(sampleBreak(speed: null)).reason,
        UnreadableReason.wrongPair,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: breakLabTheme(),
          home: const Scaffold(
            body: UnreadableBreakCard(reason: UnreadableReason.heardOneImpact),
          ),
        ),
      );

      expect(find.text('WE HEARD ONE IMPACT, NOT TWO'), findsOneWidget);
      expect(find.text('MOST LIKELY FIX'), findsOneWidget);
      expect(find.text('1 of 2'), findsOneWidget);
      expect(find.text('No'), findsOneWidget);
      // No speed is offered, ever. That rule is the whole reason to trust the
      // readings that do come back.
      expect(find.textContaining('MPH'), findsNothing);
    });
  });

  group('BL-010 how the reading was made', () {
    testWidgets(
        'prints both impacts, the gap and the distance behind the '
        'number', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: breakLabTheme(),
          home: Scaffold(body: ReadingReviewSheet(result: sampleBreak())),
        ),
      );

      expect(find.text('HOW THIS READING WAS MADE'), findsOneWidget);
      expect(find.text('TARGET'), findsOneWidget);
      expect(find.text('Cue strike'), findsOneWidget);
      expect(find.text('0.000 s'), findsOneWidget);
      expect(find.text('Rack impact'), findsOneWidget);
      expect(
        find.text('0.440 s'),
        findsOneWidget,
        reason: 'the rack is shown relative to the strike, not as a raw '
            'offset into the clip',
      );
      expect(find.text('412 ms'), findsOneWidget);
      expect(find.text('40.1 in'), findsOneWidget);
      expect(find.text('21.4 MPH'), findsOneWidget);
      expect(find.text('IF THIS LOOKS WRONG'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an unreadable break says no speed was saved', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: breakLabTheme(),
          home: Scaffold(
            body: ReadingReviewSheet(
              result: sampleBreak(
                tip: null,
                rack: null,
                gap: null,
                speed: null,
                grade: AccuracyGrade.unreliable,
              ),
            ),
          ),
        ),
      );

      expect(find.text('UNRELIABLE'), findsOneWidget);
      expect(find.textContaining('worse than none'), findsOneWidget);
      // Cue strike, rack impact, time between and speed. Only the travel
      // distance survives, because that one is the player's own number.
      expect(find.text('—'), findsNWidgets(4));
      expect(find.text('40.1 in'), findsOneWidget);
    });
  });

  group('the gate on home', () {
    testWidgets('day eight greys the button and still offers a way out', (
      tester,
    ) async {
      final store = InMemoryEntitlementStore(
        entitlement: Entitlement(trialStartedAt: firstBreak),
      );
      final c = makeController(result: readable, store: store, now: dayEight);

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      // Load the entitlement before the first frame rather than racing the
      // post-frame refresh. Real database work in a widget test belongs in
      // runAsync — the fake clock never resolves it otherwise.
      await tester.runAsync(c.refreshStats);
      await tester.pumpWidget(
        MaterialApp(
          theme: breakLabTheme(),
          home: HomeScreen(controller: c),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(c.canMeasure, isFalse);
      expect(
        tester.widget<BreakButton>(find.byType(BreakButton)).locked,
        isTrue,
      );
      expect(find.text('TAP TO UNLOCK'), findsOneWidget);
      expect(find.text('TAP TO START'), findsNothing);
      expect(find.text('TRIAL ENDED'), findsOneWidget);
      expect(find.text('READY'), findsNothing);

      await tester.tap(find.text('BREAK'));
      await tester.pumpAndSettle();

      expect(
        find.byType(UpgradeScreen),
        findsOneWidget,
        reason: 'a dead control with no explanation reads as broken',
      );
      expect(c.phase, MeasurePhase.idle);
    });

    testWidgets('inside the week the button is the button', (tester) async {
      final store = InMemoryEntitlementStore(
        entitlement: Entitlement(trialStartedAt: firstBreak),
      );
      final c = makeController(
        result: readable,
        store: store,
        now: DateTime(2026, 8, 6, 20),
      );

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      // Load the entitlement before the first frame rather than racing the
      // post-frame refresh. Real database work in a widget test belongs in
      // runAsync — the fake clock never resolves it otherwise.
      await tester.runAsync(c.refreshStats);
      await tester.pumpWidget(
        MaterialApp(
          theme: breakLabTheme(),
          home: HomeScreen(controller: c),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(c.canMeasure, isTrue);
      expect(
        tester.widget<BreakButton>(find.byType(BreakButton)).locked,
        isFalse,
      );
      expect(find.text('TAP TO START'), findsOneWidget);
      expect(find.text('READY'), findsOneWidget);
      expect(find.text('TRIAL ENDED'), findsNothing);
    });
  });
}
