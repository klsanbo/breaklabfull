/// Standard pool table sizes.
///
/// [travelDistanceInches] is the distance for a break from the CENTRE of the
/// head string — the classic default. It is not special-cased anywhere: the
/// same number falls out of [BreakPosition] geometry when the cue ball sits
/// at (0.25, 0.5). It is kept here as the default and as the value shared
/// verbatim with the BreakLab Tester.
enum TableSize {
  sevenFoot('7ft', '7ft Bar Box', 78.0, 39.0, 36.75),
  eightFoot('8ft', '8ft Home', 88.0, 44.0, 41.75),
  proEight('pro8', '8ft Pro / Oversize', 92.0, 46.0, 43.75),
  nineFoot('9ft', '9ft Regulation', 100.0, 50.0, 47.75),
  custom('custom', 'Custom distance', 0.0, 0.0, 0.0);

  const TableSize(
    this.id,
    this.label,
    this.playingLengthInches,
    this.playingWidthInches,
    this.travelDistanceInches,
  );

  /// Stable string id stored in the database ("7ft" | "8ft" | "pro8" |
  /// "9ft" | "custom"). Matches the tester's input.tableSizePreset values.
  final String id;
  final String label;
  final double playingLengthInches;
  final double playingWidthInches;

  /// Head-string-centre travel distance. Zero for [custom]; callers must
  /// supply the manual distance instead.
  final double travelDistanceInches;

  /// True when the cue ball can be positioned on a scale drawing of this
  /// table. [custom] has no known dimensions, so it keeps manual entry.
  bool get hasGeometry => playingLengthInches > 0;

  static TableSize fromId(String id) => TableSize.values.firstWhere(
        (t) => t.id == id,
        orElse: () => TableSize.custom,
      );
}
