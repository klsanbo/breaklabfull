import 'package:flutter/material.dart';

import '../../models/entitlement.dart';
import '../../services/purchase/purchase_gateway.dart';
import '../../theme/breaklab_theme.dart';
import '../measure/measure_controller.dart';
import '../onboarding/widgets/onboarding_chrome.dart';

/// What the week actually built, counted out loud.
///
/// This is the whole argument. A seven-day trial only works if the player
/// finishes it holding something they do not want to hand back, so both states
/// of this screen lead with these four numbers and put the price underneath
/// them. The ask is not "buy the app" — it is "keep your 63 breaks".
class TrialTally {
  const TrialTally({
    required this.breaks,
    required this.sessions,
    required this.bestMph,
    required this.zonesRated,
    required this.zonesTotal,
  });

  factory TrialTally.of(MeasureController c) => TrialTally(
        breaks: c.breaksAllTime,
        sessions: c.sessionCount,
        bestMph: c.records?.fastestBreak?.speedMph,
        zonesRated: c.zones.where((z) => z.isRated).length,
        zonesTotal: c.zones.length,
      );

  final int breaks;
  final int sessions;
  final double? bestMph;
  final int zonesRated;
  final int zonesTotal;
}

/// BL-021 — the trial meter, and the morning after it runs out.
///
/// One price, paid once. A subscription for an app with no server and no
/// account invites the "why is this a subscription" review, and a one-time
/// unlock also makes Restore Purchase a real feature rather than a fig leaf:
/// Play Store remembers the purchase against the player's Google account.
///
/// The locked state is deliberately not a wall. Home, sessions, Break Map,
/// records and the score all keep working on real data after day seven; the
/// only thing that stops is measuring a new break. A screen that shut a player
/// out of his own 63 breaks with no visible way back would be uninstalled, not
/// bought.
class UpgradeScreen extends StatefulWidget {
  const UpgradeScreen({
    super.key,
    required this.controller,
    this.gateway = const UnwiredPurchaseGateway(),
    this.now,
  });

  final MeasureController controller;
  final PurchaseGateway gateway;

  /// Injected in tests. Null means the real clock.
  final DateTime? now;

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  bool _busy = false;
  String? _message;

  MeasureController get c => widget.controller;
  DateTime get _now => widget.now ?? DateTime.now();

  Future<void> _run(Future<PurchaseOutcome> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final outcome = await action();
    if (!mounted) return;
    switch (outcome) {
      case PurchaseOutcome.purchased:
        await c.markPurchased();
        if (!mounted) return;
        Navigator.of(context).maybePop();
      case PurchaseOutcome.cancelled:
        setState(() => _busy = false);
      case PurchaseOutcome.unavailable:
        setState(() {
          _busy = false;
          _message = UnwiredPurchaseGateway.notWiredMessage;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final entitlement = c.entitlement;
    final now = _now;
    final locked = entitlement.statusAt(now) == EntitlementStatus.expired;
    final tally = TrialTally.of(c);
    final daysLeft = entitlement.daysLeftAt(now);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              locked ? 'YOUR TRIAL HAS ENDED' : 'BREAKLAB',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            if (!locked) ...[
              const SizedBox(height: 1),
              const Text(
                'Free trial',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: BreakLabColors.inkSoft,
                ),
              ),
            ],
          ],
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _busy ? null : () => _run(widget.gateway.restore),
            child: const Text(
              'Restore',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: BreakLabColors.inkSoft,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (locked) ...[
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFE7F0FC),
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      size: 30,
                      color: BreakLabColors.breakBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your week is up. Everything you built still works — you '
                  'just cannot add to it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: BreakLabColors.inkSoft,
                  ),
                ),
              ] else
                _TrialMeter(
                  daysLeft: daysLeft,
                  progress: entitlement.progressAt(now),
                ),
              const SizedBox(height: 12),
              _Tally(
                tally: tally,
                heading: locked
                    ? 'YOURS, AND STILL OPEN TO YOU'
                    : 'WHAT YOU HAVE BUILT SO FAR',
              ),
              const SizedBox(height: 12),
              if (locked)
                const NoteCard(
                  title: 'NOTHING IS LOCKED BUT THE BREAK BUTTON',
                  body: 'Your sessions, your Break Map, your records — all '
                      'still there, all still work. The one thing '
                      '${Entitlement.priceLabel} buys back is measuring the '
                      'next one.',
                )
              else
                _UnlockList(breaks: tally.breaks),
              const SizedBox(height: 14),
              const _PriceBlock(),
              if (_message != null) ...[
                const SizedBox(height: 12),
                NoteCard(tone: NoteTone.warn, body: _message!),
              ],
              const SizedBox(height: 14),
              PrimaryButton(
                label: locked
                    ? 'START MEASURING AGAIN — ${Entitlement.priceLabel}'
                    : 'UNLOCK BREAKLAB — ${Entitlement.priceLabel}',
                onPressed: _busy ? null : () => _run(widget.gateway.buy),
              ),
              const SizedBox(height: 4),
              QuietLink(
                label: locked
                    ? 'Restore a purchase'
                    : 'Not now — I have ${_days(daysLeft)} left',
                onPressed: _busy
                    ? null
                    : locked
                        ? () => _run(widget.gateway.restore)
                        : () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(height: 6),
              FinePrint(
                locked
                    ? 'Bought this already, or on a new phone? Restore brings '
                        'it back.'
                    : 'No account. Your breaks stay on this phone.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _days(int n) => n == 1 ? '1 day' : '$n days';
}

class _TrialMeter extends StatelessWidget {
  const _TrialMeter({required this.daysLeft, required this.progress});

  final int daysLeft;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BreakLabColors.ink, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                'FREE TRIAL',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              Text(
                daysLeft == 1 ? '1 day left' : '$daysLeft days left',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: BreakLabColors.inkSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: const Color(0xFFE4E1D9),
              valueColor: const AlwaysStoppedAnimation<Color>(
                BreakLabColors.breakBlue,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Everything is unlocked until the week is up. Measure as much as '
            'you want.',
            style: TextStyle(
              fontSize: 10.5,
              height: 1.45,
              color: BreakLabColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tally extends StatelessWidget {
  const _Tally({required this.tally, required this.heading});

  final TrialTally tally;
  final String heading;

  @override
  Widget build(BuildContext context) {
    final best = tally.bestMph;
    final cells = <(String, String, String)>[
      ('${tally.breaks}', '', 'BREAKS MEASURED'),
      ('${tally.sessions}', '', 'SESSIONS'),
      (best == null ? '—' : best.toStringAsFixed(1), best == null ? '' : ' MPH',
          'YOUR BEST'),
      ('${tally.zonesRated}', ' of ${tally.zonesTotal}', 'ZONES RATED'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BreakLabColors.ink, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: BreakLabColors.hairline),
              ),
            ),
            child: Text(
              heading,
              style: const TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
                color: BreakLabColors.inkFaint,
              ),
            ),
          ),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _Cell(cell: cells[0])),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: BreakLabColors.hairline,
                ),
                Expanded(child: _Cell(cell: cells[1])),
              ],
            ),
          ),
          const Divider(
            height: 1,
            thickness: 1,
            color: BreakLabColors.hairline,
          ),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _Cell(cell: cells[2])),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: BreakLabColors.hairline,
                ),
                Expanded(child: _Cell(cell: cells[3])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.cell});

  final (String, String, String) cell;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  cell.$1,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    height: 1.05,
                  ),
                ),
                if (cell.$2.isNotEmpty)
                  Text(
                    cell.$2,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: BreakLabColors.inkFaint,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            cell.$3,
            style: const TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: BreakLabColors.inkFaint,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnlockList extends StatelessWidget {
  const _UnlockList({required this.breaks});

  final int breaks;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Keep measuring', 'the speed number, every break, no limit.'),
      (
        'Keep what you have already built',
        breaks == 0
            ? 'whatever you record this week stays live, not frozen.'
            : 'the $breaks breaks above stay live, not frozen.',
      ),
      ('Break Map', 'which spot on the cloth actually works for you.'),
      ('Trends and records', 'speed over weeks, not just tonight.'),
      (
        'The BreakLab Score',
        'all five components, and what moves them.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: i == 0
                ? null
                : const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: BreakLabColors.hairline),
                    ),
                  ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  alignment: Alignment.center,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: BreakLabColors.breakBlue,
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 11,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: rows[i].$1,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      TextSpan(text: ' — ${rows[i].$2}'),
                    ]),
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: BreakLabColors.inkSoft,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PriceBlock extends StatelessWidget {
  const _PriceBlock();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 15, 14, 15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BreakLabColors.breakBlue, width: 2.5),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: BreakLabColors.breakBlue.withValues(alpha: 0.14),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              Entitlement.priceLabel,
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.6,
                height: 1,
              ),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'ONE TIME · NOT A SUBSCRIPTION',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: BreakLabColors.breakBlue,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Pay once and it is yours. Nothing renews, nothing to cancel, no '
            'bill next month.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.45,
              color: BreakLabColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens BL-021.
Future<void> openUpgrade(
  BuildContext context,
  MeasureController controller, {
  PurchaseGateway gateway = const UnwiredPurchaseGateway(),
}) {
  return Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => UpgradeScreen(controller: controller, gateway: gateway),
  ));
}
