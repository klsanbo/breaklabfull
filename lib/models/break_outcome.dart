/// What the player reports after a break, from the optional outcome card.
///
/// Every field the microphone cannot hear lives here. The card is always
/// skippable: a break with no [BreakOutcome] still counts for speed,
/// consistency and reliability — it simply has no Break Score.
library;

enum SpreadQuality {
  poor('Poor', 25),
  good('Good', 65),
  excellent('Excellent', 100);

  const SpreadQuality(this.label, this.points);
  final String label;
  final int points;

  static SpreadQuality fromLabel(String label) => SpreadQuality.values
      .firstWhere((s) => s.label == label, orElse: () => SpreadQuality.good);
}

enum CueBallAfter {
  stayedCenter('Stayed center', 100),
  drifted('Drifted', 55),
  wild('Wild', 15);

  const CueBallAfter(this.label, this.points);
  final String label;
  final int points;

  static CueBallAfter fromLabel(String label) => CueBallAfter.values
      .firstWhere((c) => c.label == label, orElse: () => CueBallAfter.drifted);
}

enum GameType {
  eightBall('8-Ball'),
  nineBall('9-Ball'),
  tenBall('10-Ball');

  const GameType(this.label);
  final String label;

  static GameType fromLabel(String label) => GameType.values
      .firstWhere((g) => g.label == label, orElse: () => GameType.eightBall);
}

class BreakOutcome {
  const BreakOutcome({
    required this.ballsMade,
    required this.scratched,
    required this.spread,
    required this.cueBallAfter,
  });

  /// 0–4, where 4 means "4 or more".
  final int ballsMade;
  final bool scratched;
  final SpreadQuality spread;
  final CueBallAfter cueBallAfter;

  /// Points for balls made. A dry break scores 20, not 0 — a dry break with
  /// a good spread is a real break, just an unlucky one.
  static const _ballPoints = [20, 60, 80, 92, 100];

  int get ballPoints => _ballPoints[ballsMade.clamp(0, 4)];
}
