import 'package:shared_preferences/shared_preferences.dart';

import '../../models/entitlement.dart';

/// The two things BreakLab has to remember between launches: how far into the
/// trial the player is, and whether they have seen the welcome screen.
///
/// The welcome flag rides along here rather than in a store of its own. It is
/// one boolean in the same preferences file, read at the same moment, on the
/// same launch path — a second abstraction for it would be more code than the
/// thing it stores.
///
/// Everything else in the app lives in sqflite. This is deliberately the only
/// preferences surface, so there is one place to look when a setting fails to
/// survive a restart.
abstract class EntitlementStore {
  Future<Entitlement> load();
  Future<void> save(Entitlement value);

  Future<bool> hasSeenWelcome();
  Future<void> markWelcomeSeen();
}

class PrefsEntitlementStore implements EntitlementStore {
  PrefsEntitlementStore();

  static const trialKey = 'breaklab.trialStartedAtMillis';
  static const purchasedKey = 'breaklab.purchased';
  static const welcomeKey = 'breaklab.seenWelcome';

  @override
  Future<Entitlement> load() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(trialKey);
    return Entitlement(
      trialStartedAt: millis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(millis),
      purchased: prefs.getBool(purchasedKey) ?? false,
    );
  }

  @override
  Future<void> save(Entitlement value) async {
    final prefs = await SharedPreferences.getInstance();
    final started = value.trialStartedAt;
    if (started == null) {
      await prefs.remove(trialKey);
    } else {
      await prefs.setInt(trialKey, started.millisecondsSinceEpoch);
    }
    await prefs.setBool(purchasedKey, value.purchased);
  }

  @override
  Future<bool> hasSeenWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(welcomeKey) ?? false;
  }

  @override
  Future<void> markWelcomeSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(welcomeKey, true);
  }
}

/// For tests and for the first run of a widget test that must not touch
/// platform channels.
class InMemoryEntitlementStore implements EntitlementStore {
  InMemoryEntitlementStore({
    Entitlement entitlement = Entitlement.fresh,
    bool seenWelcome = false,
  }) : _entitlement = entitlement,
       _seenWelcome = seenWelcome;

  Entitlement _entitlement;
  bool _seenWelcome;

  int saveCount = 0;

  @override
  Future<Entitlement> load() async => _entitlement;

  @override
  Future<void> save(Entitlement value) async {
    _entitlement = value;
    saveCount++;
  }

  @override
  Future<bool> hasSeenWelcome() async => _seenWelcome;

  @override
  Future<void> markWelcomeSeen() async => _seenWelcome = true;
}
