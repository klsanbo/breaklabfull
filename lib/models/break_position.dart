import 'dart:math' as math;

import 'table_size.dart';

/// Where the cue ball sits when the break is struck.
///
/// Stored as fractions of the playing surface rather than inches so a spot
/// means the same thing on any table and so positions stay comparable when
/// Break Map aggregates across table sizes.
///
///   x: 0.0 at the head rail  ->  1.0 at the foot rail
///   y: 0.0 at one long rail  ->  1.0 at the other
///
/// The kitchen (legal break area) is x <= 0.25. The rack apex sits on the
/// foot spot at (0.75, 0.5).
class BreakPosition {
  const BreakPosition({required this.x, required this.y});

  /// The classic break spot: centre of the head string. Reproduces every
  /// locked table preset exactly.
  static const headStringCentre = BreakPosition(x: 0.25, y: 0.5);

  final double x;
  final double y;

  /// Diameter of a regulation ball. The cue ball stops travelling when the
  /// surfaces touch, not when the centres meet.
  static const ballDiameterInches = 2.25;

  static const footSpotX = 0.75;
  static const footSpotY = 0.5;

  /// Furthest legal x for a break (the head string).
  static const kitchenLimitX = 0.25;

  bool get isLegal => x >= 0 && x <= kitchenLimitX && y >= 0 && y <= 1;

  BreakPosition clampedToKitchen() => BreakPosition(
        x: math.min(kitchenLimitX, math.max(0.0, x)),
        y: math.min(1.0, math.max(0.0, y)),
      );

  /// Cue-ball travel distance to the rack apex, in inches, for [table].
  ///
  /// Throws if the table has no known dimensions ([TableSize.custom]) —
  /// those breaks carry a manually entered distance instead.
  double travelDistanceInches(TableSize table) {
    if (!table.hasGeometry) {
      throw ArgumentError.value(
          table, 'table', 'has no dimensions; use a manual distance');
    }
    final dx = (footSpotX - x) * table.playingLengthInches;
    final dy = (footSpotY - y) * table.playingWidthInches;
    return math.sqrt(dx * dx + dy * dy) - ballDiameterInches;
  }

  /// Short human label for history rows and break detail, e.g. "Right rail".
  String get label {
    if (y < 0.12) return 'Left rail';
    if (y < 0.35) return 'Left';
    if (y <= 0.65) return 'Center';
    if (y <= 0.88) return 'Right';
    return 'Right rail';
  }

  /// True when the ball is close enough to a long rail to be a rail break.
  bool get isRailBreak => y < 0.12 || y > 0.88;

  @override
  bool operator ==(Object other) =>
      other is BreakPosition && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() =>
      'BreakPosition(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)})';
}
