import 'dart:math' as math;

/// Where the tip strikes the cue ball — the english put on the break.
///
/// This is an INPUT, not an outcome: it's what the player chose to hit, set
/// on the measure screen beside the cue ball position and sticky between
/// breaks (most players break the same way all session).
///
/// It is deliberately NOT part of the Break Score. English is a choice, not
/// a quality — scoring it would be telling the player how to break. It is an
/// analysis dimension instead: "your best breaks come from a touch of draw."
///
///   x: -1.0 full left  ->  0.0 centre  ->  +1.0 full right
///   y: -1.0 full draw  ->  0.0 centre  ->  +1.0 full follow
class CueEnglish {
  const CueEnglish({required this.x, required this.y});

  static const centre = CueEnglish(x: 0, y: 0);

  final double x;
  final double y;

  /// Offsets beyond roughly half the ball radius miscue in practice. Kept as
  /// a UI guide ring, not a hard limit — players do what players do.
  static const miscueLimit = 0.5;

  double get magnitude => math.sqrt(x * x + y * y);

  bool get isCentre => magnitude < 0.15;
  bool get beyondMiscueLimit => magnitude > miscueLimit;

  /// Human label: "Center", "Draw", "Follow right", "Left"…
  String get label {
    if (isCentre) return 'Center';
    final vertical = y > 0.3
        ? 'Follow'
        : y < -0.3
        ? 'Draw'
        : '';
    final horizontal = x > 0.3
        ? 'right'
        : x < -0.3
        ? 'left'
        : '';
    if (vertical.isEmpty && horizontal.isEmpty) return 'Center';
    if (vertical.isEmpty) {
      return horizontal[0].toUpperCase() + horizontal.substring(1);
    }
    if (horizontal.isEmpty) return vertical;
    return '$vertical $horizontal';
  }

  /// Coarse bucket used for "by english" breakdowns, so a thousand slightly
  /// different contact points still group into something readable.
  String get bucket => label;

  @override
  bool operator ==(Object other) =>
      other is CueEnglish && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() =>
      'CueEnglish(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)})';
}
