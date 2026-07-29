import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'engine/stub_engine.dart';
import 'features/home/home_screen.dart';
import 'features/measure/measure_controller.dart';
import 'features/measure/setup_sandbox_screen.dart';
import 'services/audio/pcm_wav_recorder.dart';
import 'services/db/breaklab_database.dart';
import 'theme/breaklab_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final docs = await getApplicationDocumentsDirectory();
  final temp = await getTemporaryDirectory();
  final db = await BreakLabDatabase.open(p.join(docs.path, 'breaklab.db'));

  runApp(BreakLabApp(
    controller: MeasureController(
      db: db,
      // Swapped for the ported, frozen tester engine once timing is dialed
      // in. Until then no fake speeds: the stub grades everything Unreliable.
      engine: StubEngine(),
      recorder: RecorderAdapter(PcmWavRecorder()),
      tempDirectoryPath: temp.path,
    ),
  ));
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

/// TEMPORARY — patch 1 of the V006 rebuild launches straight into the setup
/// sandbox so the table drawing and the setup sheet can be tested by hand on
/// the phone. Patch 2 sets this back to false and deletes the sandbox.
const bool kSetupSandbox = true;

/// BreakLab v1 — guest-only, local-first. Home is the whole app: setup,
/// measuring and results all happen there; the other screens hang off the
/// tiles and the bottom bar.
class BreakLabApp extends StatelessWidget {
  const BreakLabApp({super.key, required this.controller});

  final MeasureController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BreakLab',
      theme: breakLabTheme(),
      home: kSetupSandbox
          ? SetupSandboxScreen(controller: controller)
          : HomeScreen(controller: controller),
    );
  }
}
