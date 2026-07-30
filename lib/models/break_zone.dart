import 'break_position.dart';

/// The three areas of the kitchen a player breaks from, across the table.
///
/// Three rather than five, even though [BreakPosition.label] names five spots,
/// because a zone has to reach five reliable breaks before it can be rated and
/// five zones take more than twice as long to fill as three. The rail spots
/// group with the side they belong to.
enum BreakZone {
  left('Left', 0.0, 0.35),
  center('Center', 0.35, 0.65),
  right('Right', 0.65, 1.0);

  const BreakZone(this.label, this.fromY, this.toY);

  final String label;

  /// Inclusive lower bound on [BreakPosition.y].
  final double fromY;

  /// Upper bound, exclusive except for the last zone.
  final double toY;

  static BreakZone forPosition(BreakPosition position) => forY(position.y);

  static BreakZone forY(double y) {
    for (final zone in values) {
      if (y >= zone.fromY && (y < zone.toY || zone == values.last)) return zone;
    }
    return center;
  }

  /// A zone needs this many readable breaks before it is rated. Below it the
  /// map shows the breaks themselves and no colour — a shape drawn from two
  /// breaks is noise dressed as insight.
  static const minBreaksForRating = 5;
}

/// What a zone looks like once the breaks are counted. Never stored — derived
/// from breaks every time, so it cannot drift away from the data.
class ZoneStats {
  const ZoneStats({
    required this.zone,
    required this.breakCount,
    required this.reliableCount,
    this.bestMph,
    this.averageMph,
    this.averageBreakScore,
  });

  const ZoneStats.empty(this.zone)
      : breakCount = 0,
        reliableCount = 0,
        bestMph = null,
        averageMph = null,
        averageBreakScore = null;

  final BreakZone zone;

  /// Every break taken here, readable or not.
  final int breakCount;

  /// Breaks that produced a speed. The gate counts these, not attempts.
  final int reliableCount;

  final double? bestMph;
  final double? averageMph;

  /// Average Break Score across breaks here that have one. Null when no
  /// outcome card in this zone has been filled in.
  final double? averageBreakScore;

  /// True once this zone has earned a colour on the map.
  bool get isRated => reliableCount >= BreakZone.minBreaksForRating;

  /// How many more readable breaks this zone needs. Zero once rated.
  int get breaksNeeded =>
      isRated ? 0 : BreakZone.minBreaksForRating - reliableCount;
}
