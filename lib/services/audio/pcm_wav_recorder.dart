import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../core/capture_constants.dart';

/// Live microphone level in dBFS plus normalized UI value.
class MicLevel {
  const MicLevel({required this.decibels, required this.normalized});

  factory MicLevel.silent() {
    return const MicLevel(decibels: -80, normalized: 0);
  }

  final double decibels;
  final double normalized;
}

/// Recorder wrapper that only captures uncompressed 48 kHz mono PCM WAV.
class PcmWavRecorder {
  PcmWavRecorder({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  final _levelController = StreamController<MicLevel>.broadcast();
  StreamSubscription<Amplitude>? _levelSubscription;
  String? _activePath;

  Stream<MicLevel> get levels => _levelController.stream;

  Future<PermissionStatus> microphonePermissionStatus() {
    return Permission.microphone.status;
  }

  Future<bool> requestMicrophonePermission() async {
    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      return false;
    }
    return _recorder.hasPermission();
  }

  Future<bool> supportsRequiredPcmWav() {
    return _recorder.isEncoderSupported(AudioEncoder.wav);
  }

  Future<void> start(String outputPath) async {
    final supported = await supportsRequiredPcmWav();
    if (!supported) {
      throw StateError(
        'This device cannot capture uncompressed PCM WAV through the active recorder path.',
      );
    }

    final permitted = await requestMicrophonePermission();
    if (!permitted) {
      throw StateError('Microphone permission is required.');
    }

    final outputFile = File(outputPath);
    if (!await outputFile.parent.exists()) {
      await outputFile.parent.create(recursive: true);
    }

    _activePath = outputPath;
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: CaptureConstants.sampleRateHz,
        numChannels: CaptureConstants.channelCount,
        bitRate:
            CaptureConstants.sampleRateHz *
            CaptureConstants.channelCount *
            CaptureConstants.bitDepth,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
      ),
      path: outputPath,
    );

    _levelSubscription = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 80))
        .listen(_emitLevel);
  }

  Future<String> stop() async {
    await _levelSubscription?.cancel();
    _levelSubscription = null;
    final stoppedPath = await _recorder.stop();
    final resolvedPath = stoppedPath ?? _activePath;
    _activePath = null;
    if (resolvedPath == null) {
      throw StateError('Recorder did not return a file path.');
    }
    return resolvedPath;
  }

  Future<void> cancelAndDeleteActiveFile() async {
    await _levelSubscription?.cancel();
    _levelSubscription = null;
    await _recorder.cancel();
    final path = _activePath;
    _activePath = null;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<bool> isRecording() {
    return _recorder.isRecording();
  }

  Future<void> dispose() async {
    await _levelSubscription?.cancel();
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    await _levelController.close();
    await _recorder.dispose();
  }

  void _emitLevel(Amplitude amplitude) {
    final decibels = amplitude.current.clamp(-80.0, 0.0);
    final normalized = math.pow(10, decibels / 40).toDouble().clamp(0.0, 1.0);
    _levelController.add(MicLevel(decibels: decibels, normalized: normalized));
  }
}
