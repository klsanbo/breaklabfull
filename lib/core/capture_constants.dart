/// Fixed capture constants — IDENTICAL to the BreakLab Tester's so the
/// dialed-in detection transfers exactly. Never change these without
/// changing both apps and re-validating timing.
class CaptureConstants {
  const CaptureConstants._();

  static const appName = 'BreakLab';
  static const buildVersion = '0.1.0+1';
  static const sampleRateHz = 48000;
  static const channelCount = 1;
  static const bitDepth = 16;
  static const audioEncoding = 'PCM_S16LE_WAV';
}
