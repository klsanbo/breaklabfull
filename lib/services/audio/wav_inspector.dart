import 'dart:io';
import 'dart:typed_data';

import '../../core/capture_constants.dart';
import 'wav_audio_info.dart';

/// Parses and validates uncompressed PCM WAV originals.
class WavInspector {
  const WavInspector();

  Future<WavAudioInfo> inspectFile(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    return inspectBytes(bytes, filePath: filePath);
  }

  WavAudioInfo inspectBytes(Uint8List bytes, {required String filePath}) {
    if (bytes.length < 44) {
      throw const FormatException('WAV file is too small to contain a header.');
    }

    final data = ByteData.sublistView(bytes);
    if (_ascii(bytes, 0, 4) != 'RIFF' || _ascii(bytes, 8, 4) != 'WAVE') {
      throw const FormatException('Recording is not a RIFF/WAVE file.');
    }

    var audioFormat = 0;
    var channelCount = 0;
    var sampleRateHz = 0;
    var bitDepth = 0;
    var dataStartByte = -1;
    var dataByteLength = 0;

    var cursor = 12;
    while (cursor + 8 <= bytes.length) {
      final chunkId = _ascii(bytes, cursor, 4);
      final chunkSize = data.getUint32(cursor + 4, Endian.little);
      final chunkStart = cursor + 8;

      if (chunkStart + chunkSize > bytes.length) {
        throw const FormatException('WAV chunk extends past end of file.');
      }

      if (chunkId == 'fmt ') {
        if (chunkSize < 16) {
          throw const FormatException('WAV fmt chunk is too short.');
        }
        audioFormat = data.getUint16(chunkStart, Endian.little);
        channelCount = data.getUint16(chunkStart + 2, Endian.little);
        sampleRateHz = data.getUint32(chunkStart + 4, Endian.little);
        bitDepth = data.getUint16(chunkStart + 14, Endian.little);
      } else if (chunkId == 'data') {
        dataStartByte = chunkStart;
        dataByteLength = chunkSize;
      }

      cursor = chunkStart + chunkSize + (chunkSize.isOdd ? 1 : 0);
    }

    if (audioFormat != 1) {
      throw FormatException(
        'Recording must be uncompressed PCM WAV. Found format code $audioFormat.',
      );
    }
    if (sampleRateHz != CaptureConstants.sampleRateHz) {
      throw FormatException(
        'Recording sample rate must be ${CaptureConstants.sampleRateHz} Hz. '
        'Found $sampleRateHz Hz.',
      );
    }
    if (channelCount != CaptureConstants.channelCount) {
      throw FormatException(
        'Recording must be mono. Found $channelCount channels.',
      );
    }
    if (bitDepth != CaptureConstants.bitDepth) {
      throw FormatException(
        'Recording bit depth must be ${CaptureConstants.bitDepth}. '
        'Found $bitDepth.',
      );
    }
    if (dataStartByte < 0 || dataByteLength <= 0) {
      throw const FormatException('WAV file does not contain audio data.');
    }

    final bytesPerFrame = channelCount * (bitDepth ~/ 8);
    final frameCount = dataByteLength ~/ bytesPerFrame;
    return WavAudioInfo(
      filePath: filePath,
      sampleRateHz: sampleRateHz,
      channelCount: channelCount,
      bitDepth: bitDepth,
      frameCount: frameCount,
      dataStartByte: dataStartByte,
      dataByteLength: dataByteLength,
      audioFormat: audioFormat,
    );
  }

  String _ascii(Uint8List bytes, int offset, int length) {
    return String.fromCharCodes(bytes.sublist(offset, offset + length));
  }
}
