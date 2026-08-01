import 'package:flutter/material.dart';

import '../../../models/break_result.dart';
import '../../../theme/breaklab_theme.dart';
import '../../onboarding/widgets/onboarding_chrome.dart';

/// Which way a reading failed, as far as we can tell from what came back.
enum UnreadableReason {
  /// Neither impact was found. Usually the phone, sometimes the room.
  heardNothing,

  /// The tip was clear and the rack was not, or the other way round. Without
  /// both there is no gap to time.
  heardOneImpact,

  /// Two candidates, but not a pair the engine will stand behind — most often
  /// two rack peaks read as tip-then-rack, which was the old PowerBreak
  /// detector's signature failure.
  wrongPair,
}

/// BL-024 — the break we could not read.
///
/// A state on home rather than a screen of its own, which is what the locked
/// v1 screen list calls for. A full screen after a failed break would put a
/// wall between a player and his next attempt, and a failure is the moment he
/// most wants to try again immediately.
///
/// It says what went wrong, gives one thing to change, and states plainly that
/// nothing was saved. It does not offer a number. A recording with no clear
/// pair of hits is thrown away rather than turned into a guess — that rule is
/// the entire reason to trust the ones that do come back.
class UnreadableBreakCard extends StatelessWidget {
  const UnreadableBreakCard({
    super.key,
    required this.reason,
    this.onCheckPlacement,
  });

  final UnreadableReason reason;

  /// Opens BL-006. Null hides the link.
  final VoidCallback? onCheckPlacement;

  /// Reads the failure off the break the engine handed back.
  factory UnreadableBreakCard.forBreak(
    BreakResult result, {
    Key? key,
    VoidCallback? onCheckPlacement,
  }) {
    final tip = result.tipTimestampMs;
    final rack = result.rackTimestampMs;
    final reason = switch ((tip != null, rack != null)) {
      (false, false) => UnreadableReason.heardNothing,
      (true, true) => UnreadableReason.wrongPair,
      _ => UnreadableReason.heardOneImpact,
    };
    return UnreadableBreakCard(
      key: key,
      reason: reason,
      onCheckPlacement: onCheckPlacement,
    );
  }

  static String headlineFor(UnreadableReason reason) => switch (reason) {
        UnreadableReason.heardNothing => 'WE DID NOT HEAR THE BREAK',
        UnreadableReason.heardOneImpact => 'WE HEARD ONE IMPACT, NOT TWO',
        UnreadableReason.wrongPair => 'THE TWO SOUNDS DID NOT ADD UP',
      };

  static String bodyFor(UnreadableReason reason) => switch (reason) {
        UnreadableReason.heardNothing =>
          'Neither the tip hitting the cue ball nor the cue ball hitting the '
              'rack came through. Nine times out of ten the phone is too far '
              'from the head of the table.',
        UnreadableReason.heardOneImpact =>
          'One of the two hits came through clearly and the other did not. '
              'Without both sounds there is no time to measure, and a made-up '
              'number is worse than none.',
        UnreadableReason.wrongPair =>
          'Two sounds were found but not a pair we will stand behind — often '
              'two balls off the rack read as the strike and the rack. Timing '
              'those would give a speed that looks fine and is wrong.',
      };

  static String fixFor(UnreadableReason reason) => switch (reason) {
        UnreadableReason.heardNothing =>
          'Move the phone onto the rail at the head of the table, screen up, '
              'and break normally.',
        UnreadableReason.heardOneImpact =>
          'Move the phone closer to the head of the table, screen up, and take '
              'the next one. If the room is loud, that is usually the whole '
              'story.',
        UnreadableReason.wrongPair =>
          'Nothing you did wrong. Take another one — this is the reading the '
              'engine is least sure of and it will not guess to fill the gap.',
      };

  static String impactsFor(UnreadableReason reason) => switch (reason) {
        UnreadableReason.heardNothing => '0 of 2',
        UnreadableReason.heardOneImpact => '1 of 2',
        UnreadableReason.wrongPair => '2, unusable',
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        NoteCard(
          tone: NoteTone.bad,
          title: headlineFor(reason),
          body: bodyFor(reason),
        ),
        const SizedBox(height: 9),
        NoteCard(title: 'MOST LIKELY FIX', body: fixFor(reason)),
        const SizedBox(height: 9),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: BreakLabColors.ink, width: 1.5),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Column(
            children: [
              _Row(label: 'Impacts found', value: impactsFor(reason)),
              const _Row(label: 'Saved', value: 'No', divided: true),
            ],
          ),
        ),
        if (onCheckPlacement != null) ...[
          const SizedBox(height: 4),
          QuietLink(
            label: 'Check phone placement',
            onPressed: onCheckPlacement,
          ),
        ],
        const SizedBox(height: 2),
        const FinePrint(
          'Nothing was recorded. Your session total is unchanged.',
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.divided = false});

  final String label;
  final String value;
  final bool divided;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: divided
          ? const BoxDecoration(
              border: Border(top: BorderSide(color: BreakLabColors.hairline)),
            )
          : null,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: BreakLabColors.inkSoft,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
