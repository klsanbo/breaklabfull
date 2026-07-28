/// Standard pool table sizes and their break travel distances.
///
/// Travel distance = (playing surface length / 2) - one ball diameter (2.25"),
/// because the cue ball starts on the head string, the rack apex sits on the
/// foot spot (half the playing length away), and impact occurs when the ball
/// surfaces touch, not when centers meet.
///
/// These values are shared verbatim with the BreakLab Tester so tuning
/// transfers exactly.
enum TableSize {
  sevenFoot('7ft', '7ft Bar Box', 78.0, 36.75),
  eightFoot('8ft', '8ft Home', 88.0, 41.75),
  proEight('pro8', '8ft Pro / Oversize', 92.0, 43.75),
  nineFoot('9ft', '9ft Regulation', 100.0, 47.75),
  custom('custom', 'Custom distance', 0.0, 0.0);

  const TableSize(
      this.id, this.label, this.playingLengthInches, this.travelDistanceInches);

  /// Stable string id stored in the database ("7ft" | "8ft" | "pro8" |
  /// "9ft" | "custom"). Matches the tester's input.tableSizePreset values.
  final String id;
  final String label;
  final double playingLengthInches;

  /// Cue-ball travel distance for this preset. Zero for [custom]; callers
  /// must supply the manual distance instead.
  final double travelDistanceInches;

  static TableSize fromId(String id) => TableSize.values.firstWhere(
        (t) => t.id == id,
        orElse: () => TableSize.custom,
      );
}
