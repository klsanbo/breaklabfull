import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../engine/engine_contract.dart';
import '../../models/break_outcome.dart';
import '../../models/break_position.dart';
import '../../models/break_result.dart';
import '../../models/break_zone.dart';
import '../../models/cue_english.dart';
import '../../models/session.dart';
import '../../models/table_size.dart';
import '../../services/audio/wav_pcm_reader.dart';
import '../../scoring/breaklab_score.dart';
import '../../services/db/breaklab_database.dart';

/// What the measure screen is currently doing.
enum MeasurePhase { idle, recording, processing }

/// Minimal recorder interface so the controller is testable without
/// platform channels. [PcmWavRecorder] satisfies it via [RecorderAdapter].
abstract class BreakRecorder {
  Future<void> start(String outputPath);
  Future<String> stop();
  Future<void> cancel();

  /// Live mic level, normalized 0..1. Used only for the auto-stop trigger;
  /// the engine never sees these values.
  Stream<double> get levels;
}

/// One-button measuring: the user taps BREAK once. We listen, the break
/// itself triggers the stop (loud transient -> short tail to catch the full
/// rack sound -> stop -> detect -> save). A silence timeout gives up
/// gracefully. This trigger only decides WHEN TO STOP RECORDING — timing
/// the two impacts inside the clip is the engine's job alone.
class MeasureController extends ChangeNotifier {
  MeasureController({
    required this.db,
    required this.engine,
    required this.recorder,
    required this.tempDirectoryPath,
    WavPcmReader reader = const WavPcmReader(),
    DateTime Function()? clock,
    this.armDelay = const Duration(milliseconds: 350),
    this.tailAfterTrigger = const Duration(milliseconds: 1500),
    this.silenceTimeout = const Duration(seconds: 30),
    this.triggerLevel = 0.55,
  })  : _reader = reader,
        _clock = clock ?? DateTime.now;

  final BreakLabDatabase db;
  final BreakLabEngine engine;
  final BreakRecorder recorder;
  final String tempDirectoryPath;
  final WavPcmReader _reader;
  final DateTime Function() _clock;

  /// Ignore the mic this long after tap — the button press and phone
  /// handling must never read as the break.
  final Duration armDelay;

  /// Keep recording this long after the trigger so the rack impact and its
  /// tail are fully inside the clip.
  final Duration tailAfterTrigger;

  /// Give up if nothing loud happens.
  final Duration silenceTimeout;

  /// Normalized level (0..1) that counts as "the break happened".
  final double triggerLevel;

  MeasurePhase phase = MeasurePhase.idle;
  TableSize tableSize = TableSize.sevenFoot;
  double customDistanceInches = 39.0;
  SensitivityPreset preset = SensitivityPreset.normal;

  /// Where the cue ball sits for the break. Sticky between breaks — set it
  /// once and it rides along until you move.
  BreakPosition position = BreakPosition.headStringCentre;

  /// The english on the break. Also sticky; an input, never scored.
  CueEnglish english = CueEnglish.centre;

  /// Applied to the session when one is opened.
  GameType gameType = GameType.eightBall;

  /// Latest saved break; null before the first one.
  BreakResult? lastBreak;
  String? errorMessage;

  // ---- the numbers the home strip shows -------------------------------

  /// Current form across the last 20 sessions. Null until first loaded.
  BreakLabScore? labScore;
  int sessionCount = 0;
  DateTime? lastSessionAt;
  SessionStats? tonight;

  /// The newest session's numbers, open or closed — what the Recent Session
  /// card on home reads. [tonight] is only ever the session still running.
  SessionStats? recent;

  /// Career bests. This query already existed; home simply was not loading it,
  /// which is why the dashboard showed placeholders for a while.
  PersonalRecords? records;

  /// Every break ever attempted, and scratches as a share of the breaks with an
  /// outcome recorded. Null scratch rate means nobody has filled a card in yet.
  int breaksAllTime = 0;
  double? scratchRate;

  /// The three break zones for Break Map, always three entries whether or not
  /// any of them has enough breaks to be rated.
  List<ZoneStats> zones = const [
    ZoneStats.empty(BreakZone.left),
    ZoneStats.empty(BreakZone.center),
    ZoneStats.empty(BreakZone.right),
  ];

  /// Recomputes everything the dashboard displays. Cheap — all of it is
  /// derived from stored breaks, nothing is cached in the database.
  Future<void> refreshStats() async {
    final all = await db.sessions();
    sessionCount = all.length;
    lastSessionAt = all.isEmpty ? null : all.first.startedAt;
    labScore = await db.breakLabScore();
    final open = await db.openSession();
    tonight = open == null ? null : await db.sessionStats(open.id!);
    recent = all.isEmpty ? null : await db.sessionStats(all.first.id!);
    records = await db.personalRecords();
    breaksAllTime = await db.totalBreaks();
    scratchRate = await db.scratchRate();
    zones = await db.zoneStats();
    notifyListeners();
  }

  StreamSubscription<double>? _levelSub;
  Timer? _armTimer;
  Timer? _tailTimer;
  Timer? _timeoutTimer;
  bool _armed = false;
  bool _triggered = false;
  Future<BreakResult?>? _autoMeasurement;

  /// Completes when the automatic measurement kicked off by the break sound
  /// has finished saving. Null until a break trips the trigger.
  ///
  /// Exists so callers never have to guess how long the work takes: the UI
  /// can await it before navigating, and tests await it instead of sleeping.
  Future<BreakResult?>? get autoMeasurement => _autoMeasurement;

  /// Distance the cue ball travels, computed from where the ball actually
  /// sits. A custom table has no geometry, so it keeps the manual value.
  double get activeDistanceInches => tableSize.hasGeometry
      ? position.travelDistanceInches(tableSize)
      : customDistanceInches;

  void setTableSize(TableSize size) {
    tableSize = size;
    notifyListeners();
  }

  void setCustomDistance(double inches) {
    customDistanceInches = inches;
    notifyListeners();
  }

  void setPreset(SensitivityPreset value) {
    preset = value;
    notifyListeners();
  }

  void setPosition(BreakPosition value) {
    position = value.clampedToKitchen();
    notifyListeners();
  }

  void setEnglish(CueEnglish value) {
    english = value;
    notifyListeners();
  }

  void setGameType(GameType value) {
    gameType = value;
    notifyListeners();
  }

  /// Attaches the outcome card to the break just measured. Always optional:
  /// skipping simply leaves the break without a Break Score.
  Future<void> attachOutcome(BreakOutcome outcome) async {
    final b = lastBreak;
    if (b?.id == null) return;
    final updated = b!.copyWith(outcome: outcome);
    await db.updateOutcome(updated);
    lastBreak = updated;
    await refreshStats();
  }

  /// The single tap. Everything after this is automatic.
  Future<void> startBreak() async {
    if (phase != MeasurePhase.idle) return;
    errorMessage = null;
    final stamp = _clock().millisecondsSinceEpoch;
    try {
      await recorder.start('$tempDirectoryPath/break_$stamp.wav');
      phase = MeasurePhase.recording;
      _armed = false;
      _triggered = false;
      _autoMeasurement = null;
      _armTimer = Timer(armDelay, () => _armed = true);
      _timeoutTimer = Timer(silenceTimeout, _onSilenceTimeout);
      _levelSub = recorder.levels.listen(_onLevel);
    } on Object catch (e) {
      errorMessage = e.toString();
    }
    notifyListeners();
  }

  void _onLevel(double level) {
    if (!_armed || _triggered || phase != MeasurePhase.recording) return;
    if (level >= triggerLevel) {
      _triggered = true;
      _timeoutTimer?.cancel();
      _tailTimer = Timer(tailAfterTrigger, () {
        // Errors surface through errorMessage; the future is kept so callers
        // can await completion instead of guessing at a duration.
        _autoMeasurement = measureNow();
        unawaited(_autoMeasurement!);
      });
      notifyListeners();
    }
  }

  Future<void> _onSilenceTimeout() async {
    if (phase != MeasurePhase.recording || _triggered) return;
    await cancelBreak();
    errorMessage = "Didn't hear a break — tap BREAK and try again.";
    notifyListeners();
  }

  Future<void> cancelBreak() async {
    if (phase != MeasurePhase.recording) return;
    _clearListeners();
    await recorder.cancel();
    phase = MeasurePhase.idle;
    notifyListeners();
  }

  /// Fallback for a break too soft to trip the trigger. Normal use never
  /// needs it — the trigger calls this automatically.
  Future<BreakResult?> measureNow() async {
    if (phase != MeasurePhase.recording) return null;
    _clearListeners();
    phase = MeasurePhase.processing;
    notifyListeners();

    String? wavPath;
    try {
      wavPath = await recorder.stop();
      final audio = await _reader.read(wavPath);
      final result = engine.detect(EngineInput(
        samples: audio.samples,
        sampleRateHz: audio.info.sampleRateHz,
        travelDistanceInches: activeDistanceInches,
        preset: preset,
      ));
      final session = await _ensureOpenSession();
      final saved = await db.insertBreak(BreakResult.fromEngine(
        sessionId: session.id!,
        recordedAt: _clock(),
        tableSize: tableSize,
        travelDistanceInches: activeDistanceInches,
        preset: preset,
        result: result,
        position: tableSize.hasGeometry ? position : null,
        english: english,
      ));
      lastBreak = saved;
      await refreshStats();
      return saved;
    } on Object catch (e) {
      errorMessage = e.toString();
      return null;
    } finally {
      if (wavPath != null) {
        final f = File(wavPath);
        if (await f.exists()) {
          await f.delete();
        }
      }
      phase = MeasurePhase.idle;
      notifyListeners();
    }
  }

  /// True once the break sound tripped the trigger (UI: "Got it…").
  bool get heardBreak => _triggered;

  void _clearListeners() {
    _armTimer?.cancel();
    _tailTimer?.cancel();
    _timeoutTimer?.cancel();
    _levelSub?.cancel();
    _armTimer = _tailTimer = _timeoutTimer = null;
    _levelSub = null;
  }

  Future<Session> _ensureOpenSession() async {
    final open = await db.openSession();
    if (open != null) return open;
    return db.insertSession(
        Session(startedAt: _clock(), tableSize: tableSize, gameType: gameType));
  }

  Future<void> endSession() async {
    final open = await db.openSession();
    if (open != null) {
      await db.endSession(open.id!, _clock());
      lastBreak = null;
      await refreshStats();
    }
  }

  @override
  void dispose() {
    _clearListeners();
    super.dispose();
  }

  /// Test hook: decode without touching the filesystem.
  @visibleForTesting
  PcmAudio decodeBytes(Uint8List bytes) =>
      _reader.decode(bytes, filePath: 'memory.wav');
}
