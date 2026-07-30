/// How fast a break was, in words.
///
/// These DESCRIBE a speed, they do not grade it. Speed is 10% of the Break
/// Score precisely because it is not a verdict — a player who chooses a
/// controlled break is playing the table, not failing at it — so none of these
/// words may read like a criticism.
///
/// Calibrated against real breaks rather than radar-gun folklore: a typical
/// player averages about 19 MPH and a hard breaker lands around 20-21, so the
/// old 27+ top band was unreachable and the bottom band insulted the average.
///
/// Deliberately NOT the same vocabulary as the field protocol's hard / medium /
/// soft intent tags. Those record what a player was trying to do; these record
/// what actually happened.
///
/// Provisional: set from experience while BreakLab's own engine is still
/// untuned. Once the 15-break field protocol has run, these move to whatever
/// BreakLab itself measures — they are one number each.
enum SpeedBand {
  controlled('Controlled', null, 16.0),
  solid('Solid', 16.0, 20.0),
  strong('Strong', 20.0, 23.0),
  hard('Hard', 23.0, null);

  const SpeedBand(this.label, this.fromMph, this.toMph);

  final String label;

  /// Inclusive lower bound. Null for the bottom band.
  final double? fromMph;

  /// Exclusive upper bound. Null for the top band.
  final double? toMph;

  /// The band a measured speed falls in.
  static SpeedBand forMph(double mph) {
    for (final band in values) {
      final from = band.fromMph;
      final to = band.toMph;
      if ((from == null || mph >= from) && (to == null || mph < to)) {
        return band;
      }
    }
    // Unreachable: the bands are open at both ends.
    return values.last;
  }

  /// Legend text, e.g. "20.0 - 22.9" or "23.0+".
  String get range {
    final from = fromMph;
    final to = toMph;
    if (from == null) return 'under ${to!.toStringAsFixed(1)}';
    if (to == null) return '${from.toStringAsFixed(1)}+';
    // The top of a band is the last tenth below the next band's floor.
    return '${from.toStringAsFixed(1)} - ${(to - 0.1).toStringAsFixed(1)}';
  }
}
