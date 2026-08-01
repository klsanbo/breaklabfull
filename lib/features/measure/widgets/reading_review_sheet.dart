import 'package:flutter/material.dart';

import '../../../engine/engine_contract.dart';
import '../../../models/break_result.dart';
import '../../../theme/breaklab_theme.dart';
import '../../onboarding/widgets/onboarding_chrome.dart';

/// BL-010 — how a reading was made.
///
/// A sheet rather than a screen, pulled up by tapping the grade on a break,
/// and never opened on its own. Most players will accept the number: a breaker
/// knows roughly how hard he hits, and if a reading comes back wildly high he
/// already knows it misread. Putting this in front of every break would put a
/// wall between a player and his next one, and by the fourth rack he would be
/// tapping through it without reading.
///
/// For the player who does doubt a number, it prints the two timestamps, the
/// gap between them, and the travel distance that turned that gap into MPH —
/// so the wrong input is visible rather than inferred. It is almost always the
/// distance, which is the one thing set by hand.
class ReadingReviewSheet extends StatelessWidget {
  const ReadingReviewSheet({super.key, required this.result, this.onFixSetup});

  final BreakResult result;

  /// Straight to the one setup screen. Null hides the button.
  final VoidCallback? onFixSetup;

  /// Why the engine graded it the way it did, in words a player can act on.
  static String explanationFor(AccuracyGrade grade) => switch (grade) {
    AccuracyGrade.excellent =>
      'Two clean impacts, well separated, with quiet either side. Nothing '
          'about this reading needed a guess.',
    AccuracyGrade.target =>
      'Both impacts came through clearly enough to time. Some room noise, '
          'not enough to move the number.',
    AccuracyGrade.fallback =>
      'The impacts were there but not clean. Treat this one as close '
          'rather than exact.',
    AccuracyGrade.unreliable =>
      'No pair of impacts we would stand behind, so no speed was saved. A '
          'made-up number is worse than none.',
  };

  static String _ms(double? value) =>
      value == null ? '—' : '${value.toStringAsFixed(0)} ms';

  static String _seconds(double? value) =>
      value == null ? '—' : '${(value / 1000).toStringAsFixed(3)} s';

  @override
  Widget build(BuildContext context) {
    final (pillBg, pillInk) = BreakLabColors.forGrade(result.grade);

    // The engine reports both impacts on one timeline. Showing the cue strike
    // at its raw offset into the clip would be noise, so the pair is shown
    // relative to the strike — that is the only reading that means anything.
    final tip = result.tipTimestampMs;
    final rack = result.rackTimestampMs;
    final rackRelative = (tip == null || rack == null)
        ? null
        : (rack - tip).abs();

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD7D4CC),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const Text(
              'HOW THIS READING WAS MADE',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: BreakLabColors.inkFaint,
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: pillBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  result.grade.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: pillInk,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 11),
            NoteCard(tone: NoteTone.soft, body: explanationFor(result.grade)),
            const SizedBox(height: 12),
            _Rows(
              rows: [
                ('Cue strike', tip == null ? '—' : '0.000 s'),
                ('Rack impact', _seconds(rackRelative)),
                ('Time between', _ms(result.gapMs ?? rackRelative)),
                (
                  'Travel distance',
                  '${result.travelDistanceInches.toStringAsFixed(1)} in',
                ),
                (
                  'Speed',
                  result.hasSpeed
                      ? '${result.speedMph!.toStringAsFixed(1)} MPH'
                      : '—',
                ),
              ],
            ),
            const SizedBox(height: 12),
            const NoteCard(
              title: 'IF THIS LOOKS WRONG',
              body:
                  'The distance is the only number you set by hand. If the '
                  'ball was not where the setup says it was, the speed is off '
                  'by the same proportion.',
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                if (onFixSetup != null) ...[
                  Expanded(
                    child: GhostButton(
                      label: 'FIX MY SETUP',
                      onPressed: onFixSetup,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: PrimaryButton(
                    label: 'DONE',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Rows extends StatelessWidget {
  const _Rows({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BreakLabColors.ink, width: 1.5),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: i == 0
                  ? null
                  : const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: BreakLabColors.hairline),
                      ),
                    ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      rows[i].$1,
                      style: const TextStyle(
                        fontSize: 12,
                        color: BreakLabColors.inkSoft,
                      ),
                    ),
                  ),
                  Text(
                    rows[i].$2,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Raises BL-010 over whatever is on screen.
Future<void> showReadingReview(
  BuildContext context,
  BreakResult result, {
  VoidCallback? onFixSetup,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => ReadingReviewSheet(result: result, onFixSetup: onFixSetup),
  );
}
