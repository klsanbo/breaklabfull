import 'dart:async';
import 'dart:io';

import 'package:breaklab/engine/engine_contract.dart';
import 'package:breaklab/features/home/home_screen.dart';
import 'package:breaklab/features/measure/break_setup_screen.dart';
import 'package:breaklab/features/measure/measure_controller.dart';
import 'package:breaklab/features/measure/phone_placement_screen.dart';
import 'package:breaklab/features/onboarding/welcome_screen.dart';
import 'package:breaklab/main.dart';
import 'package:breaklab/services/db/breaklab_database.dart';
import 'package:breaklab/services/entitlement/entitlement_store.dart';
import 'package:breaklab/theme/breaklab_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

  setUp(() async {
    db = await BreakLabDatabase.open(inMemoryDatabasePath,
        factory: databaseFactoryFfi);
    tempDir = await Directory.systemTemp.createTemp('breaklab_onboarding');
    controller = MeasureController(
      db: db,
      engine: StubbedEngine(),
      recorder: FakeRecorder(),
      tempDirectoryPath: tempDir.path,
      clock: () => DateTime(2026, 8, 4, 21),
    );
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  void sizePhone(WidgetTester tester, {Size size = const Size(1080, 2400)}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpRoot(WidgetTester tester, EntitlementStore store) async {
    sizePhone(tester);
    await tester.pumpWidget(MaterialApp(
      theme: breakLabTheme(),
      home: BreakLabRoot(controller: controller, store: store),
    ));
    await tester.pump(); // the store read resolves
    await tester.pump(const Duration(milliseconds: 50));
  }

  group('BL-002 Welcome', () {
    testWidgets('asks for nothing and explains the microphone before using it',
        (tester) async {
      sizePhone(tester);
      var continued = 0;
      await tester.pumpWidget(MaterialApp(
        theme: breakLabTheme(),
        home: WelcomeScreen(onContinue: () => continued++),
      ));

      expect(find.text('BREAK LAB'), findsOneWidget);
      expect(find.text('PRACTICE. MEASURE. IMPROVE.'), findsOneWidget);
      expect(find.text('ABOUT THE MICROPHONE'), findsOneWidget);
      expect(find.textContaining('never uploaded'), findsOneWidget);
      expect(find.textContaining(r'$9.99'), findsOneWidget);
      expect(find.textContaining('7 days from your first break'),
          findsOneWidget);

      // No account, no email, no permission dialog on arrival. If any of these
      // ever appear here, someone has quietly added a signup to the first
      // screen a player sees.
      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('Sign in'), findsNothing);
      expect(find.textContaining('email'), findsNothing);

      await tester.tap(find.text('GET STARTED'));
      await tester.pump();
      expect(continued, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('survives a large system font instead of overflowing',
        (tester) async {
      // The masthead on home overflowed by 98 pixels the moment the type got
      // wider. This screen is longer and gets the same check.
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      sizePhone(tester);

      await tester.pumpWidget(MaterialApp(
        theme: breakLabTheme(),
        home: WelcomeScreen(onContinue: () {}),
      ));

      expect(tester.takeException(), isNull);
      expect(find.text('BREAK LAB'), findsOneWidget);
    });
  });

  group('BL-006 Phone placement', () {
    testWidgets('shows the table, three rules and the one that is not',
        (tester) async {
      sizePhone(tester);
      var done = 0;
      await tester.pumpWidget(MaterialApp(
        theme: breakLabTheme(),
        home: PhonePlacementScreen(onDone: () => done++),
      ));

      expect(find.byType(PlacementDiagram), findsOneWidget);
      expect(find.text('PHONE HERE'), findsOneWidget);
      expect(find.text('YOU BREAK FROM HERE'), findsOneWidget);

      expect(find.text('On the rail at the head of the table'), findsOneWidget);
      expect(find.text('Screen up, mic uncovered'), findsOneWidget);
      expect(
          find.text('Leave it there for the whole session'), findsOneWidget);
      expect(find.text('Not on the far rail or in your hand'), findsOneWidget);

      // The room warning is on the screen before the first break, not after a
      // failed one — by then it is an excuse rather than advice.
      expect(find.text('ONE HONEST WARNING'), findsOneWidget);

      await tester.tap(find.text('IT IS IN PLACE'));
      await tester.pump();
      expect(done, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('skip only exists when someone is being walked through it',
        (tester) async {
      sizePhone(tester);
      await tester.pumpWidget(MaterialApp(
        theme: breakLabTheme(),
        home: PhonePlacementScreen(onDone: () {}),
      ));
      expect(find.text('Skip'), findsNothing);

      await tester.pumpWidget(MaterialApp(
        theme: breakLabTheme(),
        home: PhonePlacementScreen(onDone: () {}, onSkip: () {}),
      ));
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('lays out on a short phone without overflowing',
        (tester) async {
      sizePhone(tester, size: const Size(1080, 1920));
      await tester.pumpWidget(MaterialApp(
        theme: breakLabTheme(),
        home: PhonePlacementScreen(onDone: () {}),
      ));
      expect(tester.takeException(), isNull);
    });
  });

  group('first run', () {
    testWidgets('a fresh install opens on the welcome screen', (tester) async {
      await pumpRoot(tester, InMemoryEntitlementStore());
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('welcome leads to placement, then setup', (tester) async {
      // The order is deliberate: a player who sets the table up and then walks
      // off with the phone in their pocket has done the work backwards.
      final store = InMemoryEntitlementStore();
      await pumpRoot(tester, store);

      await tester.tap(find.text('GET STARTED'));
      await tester.pumpAndSettle();
      expect(find.byType(PhonePlacementScreen), findsOneWidget);

      await tester.tap(find.text('IT IS IN PLACE'));
      await tester.pumpAndSettle();

      expect(await store.hasSeenWelcome(), isTrue);
      expect(find.byType(BreakSetupScreen), findsOneWidget,
          reason: 'the welcome screen promised they would set the table up');
    });

    testWidgets('skipping placement still finishes onboarding',
        (tester) async {
      final store = InMemoryEntitlementStore();
      await pumpRoot(tester, store);

      await tester.tap(find.text('GET STARTED'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(await store.hasSeenWelcome(), isTrue);
      expect(find.byType(PhonePlacementScreen), findsNothing);
    });

    testWidgets('someone who read it and never measured is not asked twice',
        (tester) async {
      // The flag is stored, not inferred from whether any breaks exist. An app
      // that greets you again the next night is an app that was not paying
      // attention.
      await pumpRoot(tester, InMemoryEntitlementStore(seenWelcome: true));

      expect(find.byType(WelcomeScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(BreakSetupScreen), findsNothing,
          reason: 'setup opens itself once, coming off welcome, and no more');
      expect(find.text('BREAK'), findsOneWidget);
    });
  });
}
