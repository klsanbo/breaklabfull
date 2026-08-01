/// What came back from a purchase attempt.
enum PurchaseOutcome {
  /// Paid for, unlocked.
  purchased,

  /// The player backed out. Not an error, and never worth a message.
  cancelled,

  /// Billing is not available on this build. Today that is every build.
  unavailable,
}

/// The one place money changes hands.
///
/// Nothing else in the app knows how a purchase is made, so wiring up Play
/// Billing is one implementation of this and no edits anywhere else. That
/// matters because the store product does not exist yet: a $9.99 one-time
/// unlock has to be configured in the Play Console before any code can charge
/// for it, and there is no honest way to fake that in the meantime.
///
/// Everything around it — the trial clock, the tally, the lock on the BREAK
/// button, the upgrade screen — is real and testable today. Only the payment
/// itself is stubbed, and it says so out loud rather than pretending to
/// succeed.
abstract class PurchaseGateway {
  Future<PurchaseOutcome> buy();

  /// Play Store remembers the purchase against the player's Google account,
  /// so a new phone genuinely gets the unlock back. Their breaks do not
  /// travel — those live on the old device — but the unlock does.
  Future<PurchaseOutcome> restore();
}

/// Until the Play Console product exists. Refuses honestly instead of
/// unlocking the app for free or claiming a purchase that never happened.
class UnwiredPurchaseGateway implements PurchaseGateway {
  const UnwiredPurchaseGateway();

  static const notWiredMessage =
      'Purchases are not switched on in this build yet.';

  @override
  Future<PurchaseOutcome> buy() async => PurchaseOutcome.unavailable;

  @override
  Future<PurchaseOutcome> restore() async => PurchaseOutcome.unavailable;
}

/// For tests, and for a debug build where the lock needs exercising.
class FakePurchaseGateway implements PurchaseGateway {
  FakePurchaseGateway({this.outcome = PurchaseOutcome.purchased});

  PurchaseOutcome outcome;
  int buyCount = 0;
  int restoreCount = 0;

  @override
  Future<PurchaseOutcome> buy() async {
    buyCount++;
    return outcome;
  }

  @override
  Future<PurchaseOutcome> restore() async {
    restoreCount++;
    return outcome;
  }
}
