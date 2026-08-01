import 'package:breaklab/models/entitlement.dart';
import 'package:breaklab/services/entitlement/entitlement_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Tuesday evening, the first break of the week.
  final started = DateTime(2026, 8, 4, 21, 30);

  group('Entitlement', () {
    test('nothing is locked before the first readable break', () {
      const fresh = Entitlement.fresh;
      expect(fresh.statusAt(started), EntitlementStatus.notStarted);
      expect(fresh.canMeasureAt(started), isTrue);
      expect(fresh.trialEndsAt, isNull);
      // The whole week is still theirs — they have not spent any of it.
      expect(fresh.daysLeftAt(started), Entitlement.trialDays);
      expect(fresh.progressAt(started), 0);
    });

    test('the week runs seven days from the first break, not from install',
        () {
      final e = Entitlement(trialStartedAt: started);
      expect(e.trialEndsAt, DateTime(2026, 8, 11, 21, 30));
      expect(e.statusAt(started), EntitlementStatus.trialing);
      expect(e.daysLeftAt(started), 7);
    });

    test('a second readable break does not push the deadline out', () {
      // Starting the clock is a one-way door. If every break restarted it the
      // trial would never end for anyone who kept playing, which is exactly
      // the player you most want to convert.
      final first = Entitlement.fresh.startedAt(started);
      final later = first.startedAt(started.add(const Duration(days: 3)));
      expect(later.trialStartedAt, started);
      expect(identical(first, later), isTrue);
    });

    test('a purchase never starts a trial clock', () {
      final owned = Entitlement.fresh.asPurchased();
      final after = owned.startedAt(started);
      expect(after.trialStartedAt, isNull);
      expect(after.statusAt(started), EntitlementStatus.owned);
      expect(after.canMeasureAt(started.add(const Duration(days: 900))),
          isTrue);
    });

    test('the last afternoon still reads one day left, never zero', () {
      // Rounding down here would tell someone with thirteen hours to play that
      // they had no time left. Days remaining is a promise, not a measurement.
      final e = Entitlement(trialStartedAt: started);
      expect(e.daysLeftAt(DateTime(2026, 8, 11, 8)), 1);
      expect(e.daysLeftAt(DateTime(2026, 8, 11, 21, 29, 59)), 1);
      expect(e.statusAt(DateTime(2026, 8, 11, 21, 29, 59)),
          EntitlementStatus.trialing);
    });

    test('day eight locks measuring and nothing else', () {
      final e = Entitlement(trialStartedAt: started);
      final dayEight = DateTime(2026, 8, 11, 21, 30);
      expect(e.statusAt(dayEight), EntitlementStatus.expired);
      expect(e.canMeasureAt(dayEight), isFalse);
      expect(e.daysLeftAt(dayEight), 0);
      // Everything already recorded stays readable forever; nothing in this
      // model can express deleting it, which is the point.
      expect(e.trialStartedAt, started);
    });

    test('buying it back unlocks immediately and keeps the history', () {
      final e = Entitlement(trialStartedAt: started).asPurchased();
      final dayForty = DateTime(2026, 9, 13);
      expect(e.statusAt(dayForty), EntitlementStatus.owned);
      expect(e.canMeasureAt(dayForty), isTrue);
      expect(e.trialStartedAt, started, reason: 'the week that was is a fact');
    });

    test('progress runs 0 to 1 and stops there', () {
      final e = Entitlement(trialStartedAt: started);
      expect(e.progressAt(started), 0);
      expect(e.progressAt(started.add(const Duration(days: 5))),
          closeTo(5 / 7, 0.0001));
      expect(e.progressAt(started.add(const Duration(days: 40))), 1);
      // A clock that went backwards — timezone change, manual clock set —
      // must not produce a negative bar.
      expect(e.progressAt(started.subtract(const Duration(days: 2))), 0);
    });

    test('a backwards clock cannot resurrect an expired trial into the future',
        () {
      final e = Entitlement(trialStartedAt: started);
      final wayBack = DateTime(2020, 1, 1);
      expect(e.statusAt(wayBack), EntitlementStatus.trialing);
      expect(e.daysLeftAt(wayBack), Entitlement.trialDays,
          reason: 'capped at the length of the trial, not 2400 days');
    });

    test('the price lives in exactly one place', () {
      expect(Entitlement.priceLabel, r'$9.99');
      expect(Entitlement.trialDays, 7);
    });

    test('value equality, so a save can be skipped when nothing changed', () {
      expect(Entitlement(trialStartedAt: started),
          Entitlement(trialStartedAt: started));
      expect(Entitlement(trialStartedAt: started),
          isNot(Entitlement(trialStartedAt: started).asPurchased()));
    });
  });

  group('InMemoryEntitlementStore', () {
    test('round-trips a started trial and a purchase', () async {
      final store = InMemoryEntitlementStore();
      expect(await store.load(), Entitlement.fresh);
      expect(await store.hasSeenWelcome(), isFalse);

      await store.save(Entitlement(trialStartedAt: started));
      expect((await store.load()).trialStartedAt, started);

      await store.save(Entitlement(trialStartedAt: started).asPurchased());
      expect((await store.load()).purchased, isTrue);

      await store.markWelcomeSeen();
      expect(await store.hasSeenWelcome(), isTrue);
      expect(store.saveCount, 2);
    });
  });
}
