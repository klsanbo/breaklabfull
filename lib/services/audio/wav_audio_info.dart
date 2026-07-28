/// Parsed header facts about a PCM WAV file.
class WavAudioInfo {
  const WavAudioInfo({
    required this.filePath,
    required this.sampleRateHz,
    required this.channelCount,
    required this.bitDepth,
    required this.frameCount,
    required this.dataStartByte,
    required this.dataByteLength,
    required this.audioFormat,
  });

  final String filePath;
  final int sampleRateHz;
  final int channelCount;
  final int bitDepth;
  final int frameCount;
  final int dataStartByte;
  final int dataByteLength;
  final int audioFormat;

  double get durationMs => frameCount * 1000 / sampleRateHz;
}
