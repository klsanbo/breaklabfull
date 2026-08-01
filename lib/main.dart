import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'engine/stub_engine.dart';
import 'features/home/home_screen.dart';
import 'features/measure/measure_controller.dart';
import 'features/measure/phone_placement_screen.dart';
import 'features/onboarding/welcome_screen.dart';
import 'services/audio/pcm_wav_recorder.dart';
import 'services/db/breaklab_database.dart';
import 'services/entitlement/entitlement_store.dart';
import 'theme/breaklab_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final docs = await getApplicationDocumentsDirectory();
  final temp = await getTemporaryDirectory();
  final db = await BreakLabDatabase.open(p.join(docs.path, 'breaklab.db'));

  // One store, shared. The controller stamps the trial clock on the first
  // readable break; the root reads the welcome flag out of the same file.
  final store = PrefsEntitlementStore();

  runApp(
    BreakLabApp(
      controller: MeasureController(
        db: db,
        // Swapped for the ported, frozen tester engine once timing is dialed
        // in. Until then no fake speeds: the stub grades everything Unreliable.
        engine: StubEngine(),
        recorder: RecorderAdapter(PcmWavRecorder()),
        tempDirectoryPath: temp.path,
        entitlements: store,
      ),
      store: store,
    ),
  );
}

/// Adapts the ported tester recorder to the controller's small interface.
class RecorderAdapter implements BreakRecorder {
  RecorderAdapter(this._recorder);

  final PcmWavRecorder _recorder;

  @override
  Future<void> start(String outputPath) => _recorder.start(outputPath);

  @override
  Future<String> stop() => _recorder.stop();

  @override
  Future<void> cancel() => _recorder.cancelAndDeleteActiveFile();

  @override
  Stream<double> get levels =>
      _recorder.levels.map((level) => level.normalized);
}

/// BreakLab v1 — guest-only, local-first. Home is the whole app: setup,
/// measuring and results all happen there; the other screens hang off the
/// bottom bar.
class BreakLabApp extends StatelessWidget {
  const BreakLabApp({super.key, required this.controller, required this.store});

  final MeasureController controller;
  final EntitlementStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BreakLab',
      theme: breakLabTheme(),
      home: BreakLabRoot(controller: controller, store: store),
    );
  }
}

/// Decides what the app opens on: the welcome screen the very first time,
/// home every time after.
///
/// The flag is read from storage rather than inferred from whether any breaks
/// exist. Someone who installs this, reads the welcome screen and puts the
/// phone down without measuring anything must not be greeted by it again the
/// next night — they have already seen it, and being told twice is how an app
/// starts to feel like it is not paying attention.
class BreakLabRoot extends StatefulWidget {
  const BreakLabRoot({
    super.key,
    required this.controller,
    required this.store,
  });

  final MeasureController controller;
  final EntitlementStore store;

  @override
  State<BreakLabRoot> createState() => _BreakLabRootState();
}

class _BreakLabRootState extends State<BreakLabRoot> {
  /// Null while the answer is still being read off disk.
  bool? _seenWelcome;
  bool _openSetupOnStart = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final seen = await widget.store.hasSeenWelcome();
    if (!mounted) return;
    setState(() => _seenWelcome = seen);
  }

  /// Welcome -> phone placement -> home, with setup opened.
  ///
  /// Three screens on the first run only, each doing exactly one thing, in the
  /// order the welcome screen numbers them. Placement comes before setup
  /// because a player who sets the table up and then walks off with the phone
  /// in their pocket has done the work in the wrong order.
  void _startPlacement() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => PhonePlacementScreen(
          onDone: () => _finishWelcome(routeContext),
          onSkip: () => _finishWelcome(routeContext),
        ),
      ),
    );
  }

  Future<void> _finishWelcome(BuildContext routeContext) async {
    Navigator.of(routeContext).pop();
    await widget.store.markWelcomeSeen();
    if (!mounted) return;
    setState(() {
      _seenWelcome = true;
      _openSetupOnStart = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final seen = _seenWelcome;
    if (seen == null) {
      // One frame, maybe two. An empty scaffold in the app's own colour is
      // less jarring here than a spinner that flashes and vanishes.
      return const Scaffold(body: SizedBox.shrink());
    }
    if (!seen) {
      return WelcomeScreen(onContinue: _startPlacement);
    }
    return HomeScreen(
      controller: widget.controller,
      openSetupOnStart: _openSetupOnStart,
    );
  }
}
