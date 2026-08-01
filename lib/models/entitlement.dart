/// Where a player stands with the app right now.
enum EntitlementStatus {
  /// Nothing measured yet, so the trial has not begun. Nothing is locked.
  notStarted,

  /// Inside the seven days.
  trialing,

  /// Past the seven days and not bought. Measuring stops; everything already
  /// recorded keeps working.
  expired,

  /// Bought outright. Nothing here matters again.
  owned,
}

/// What a player is entitled to, and for how much longer.
///
/// BreakLab is bought once, not rented, and the trial is seven days rather
/// than a break count — the point of the week is that the breaks pile up into
/// something a player does not want to hand back.
///
/// The clock starts on the first break we could actually read, not on install.
/// Someone who downloads this on a Tuesday and does not reach a table until
/// Friday would otherwise spend three of their seven days on an empty app and
/// hit the wall having barely used it, which is the opposite of the plan.
///
/// Breaks the engine could not read never start the clock and never cost the
/// player anything. Charging someone for a failed reading is how you earn a
/// one-star review that happens to be correct.
///
/// This class holds no clock of its own — every question takes the current
/// time. A model that reads [DateTime.now] internally cannot be tested at a
/// boundary, and every interesting case here is a boundary.
class Entitlement {
  const Entitlement({this.trialStartedAt, this.purchased = false});

  /// Nothing measured, nothing bought.
  static const fresh = Entitlement();

  /// Length of the free trial.
  static const trialDays = 7;

  /// One payment, no subscription. Shown wherever the price appears so the
  /// number lives in exactly one place.
  static const priceLabel = r'$9.99';

  /// When the first readable break was measured. Null means the week has not
  /// started yet.
  final DateTime? trialStartedAt;

  /// Bought outright.
  final bool purchased;

  DateTime? get trialEndsAt =>
      trialStartedAt?.add(const Duration(days: trialDays));

  EntitlementStatus statusAt(DateTime now) {
    if (purchased) return EntitlementStatus.owned;
    final ends = trialEndsAt;
    if (ends == null) return EntitlementStatus.notStarted;
    return now.isBefore(ends)
        ? EntitlementStatus.trialing
        : EntitlementStatus.expired;
  }

  /// The only gate in the app. Everything already recorded stays readable
  /// forever — sessions, Break Map, records, the score. The one thing that
  /// stops is measuring a new break.
  bool canMeasureAt(DateTime now) =>
      statusAt(now) != EntitlementStatus.expired;

  /// Whole days left, rounded up, so the last afternoon still reads "1 day
  /// left" rather than "0". Before the trial starts this is the full week,
  /// which is true: they have not spent any of it.
  int daysLeftAt(DateTime now) {
    final ends = trialEndsAt;
    if (purchased || ends == null) return trialDays;
    final left = ends.difference(now);
    if (left.isNegative || left == Duration.zero) return 0;
    final days = (left.inSeconds / Duration.secondsPerDay).ceil();
    return days > trialDays ? trialDays : days;
  }

  /// How much of the week is gone, 0..1, for the progress bar.
  double progressAt(DateTime now) {
    final start = trialStartedAt;
    if (start == null) return 0;
    const total = trialDays * Duration.secondsPerDay;
    final used = now.difference(start).inSeconds;
    if (used <= 0) return 0;
    if (used >= total) return 1;
    return used / total;
  }

  /// Called when a break is saved with a real speed on it. Starting the clock
  /// is a one-way door: a second readable break must not push the deadline
  /// out, so this returns the same object once the trial is under way.
  Entitlement startedAt(DateTime now) {
    if (purchased || trialStartedAt != null) return this;
    return Entitlement(trialStartedAt: now);
  }

  Entitlement asPurchased() =>
      Entitlement(trialStartedAt: trialStartedAt, purchased: true);

  @override
  String toString() =>
      'Entitlement(trialStartedAt: $trialStartedAt, purchased: $purchased)';

  @override
  bool operator ==(Object other) =>
      other is Entitlement &&
      other.trialStartedAt == trialStartedAt &&
      other.purchased == purchased;

  @override
  int get hashCode => Object.hash(trialStartedAt, purchased);
}
