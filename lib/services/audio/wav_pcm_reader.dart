import 'dart:io';
import 'dart:typed_data';

import 'wav_audio_info.dart';
import 'wav_inspector.dart';

/// Decoded PCM audio ready for the engine.
class PcmAudio {
  const PcmAudio({required this.info, required this.samples});

  final WavAudioInfo info;
  final Int16List samples;
}

/// Decodes PCM WAV recordings into raw samples for detection.
/// Verbatim decode logic from the BreakLab Tester's reader.
class WavPcmReader {
  const WavPcmReader({WavInspector inspector = const WavInspector()})
      : _inspector = inspector;

  final WavInspector _inspector;

  Future<PcmAudio> read(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    return decode(bytes, filePath: filePath);
  }

  PcmAudio decode(Uint8List bytes, {required String filePath}) {
    final info = _inspector.inspectBytes(bytes, filePath: filePath);
    final samples = Int16List(info.frameCount);
    final data = ByteData.sublistView(bytes);

    var offset = info.dataStartByte;
    for (var index = 0; index < info.frameCount; index++) {
      samples[index] = data.getInt16(offset, Endian.little);
      offset += 2;
    }
    return PcmAudio(info: info, samples: samples);
  }
}
