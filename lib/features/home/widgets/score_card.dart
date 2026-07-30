import 'package:flutter/material.dart';

import '../../../scoring/breaklab_score.dart';
import '../../../theme/breaklab_theme.dart';

/// The BreakLab Score: one number, the grade word under it, and the five
/// components that produced it.
///
/// The weights are deliberately not printed here — they live on the Score
/// screen. The bars are in weight order all the same, heaviest first, so the
/// arrangement still tells you what matters most.
class ScoreCard extends StatelessWidget {
  const ScoreCard({super.key, required this.score, this.onTap});

  final BreakLabScore? score;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = score;
    final ready = s != null && s.isReady;
    // Dart promotes s through `ready`, so no ! is needed or wanted here.
    final bigNumber = ready ? '${s.score}' : '—';
    final gradeLine =
        ready ? '${s.grade.toUpperCase()} BREAKER' : 'NO SCORE YET';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: BreakLabColors.ink, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 104,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'BREAKLAB\nSCORE',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      border: Border.all(color: BreakLabColors.ink, width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          bigNumber,
                          style: const TextStyle(
                            fontSize: 40,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          gradeLine,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: BreakLabColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Heaviest component first. The numbers behind the order are
                  // on the Score screen, not here.
                  _Bar(label: 'CUE BALL\nCONTROL', value: s?.control),
                  _Bar(label: 'CONSISTENCY', value: s?.consistency),
                  _Bar(label: 'CLEAN\nBREAKS', value: s?.clean),
                  _Bar(label: 'BALLS MADE', value: s?.balls),
                  _Bar(label: 'SPEED', value: s?.speed, last: true),
                  if (s?.needMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      s!.needMessage!,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 10.5,
                        height: 1.35,
                        color: BreakLabColors.inkFaint,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.label, required this.value, this.last = false});

  final String label;

  /// 0-100, or null when there is not enough data to have an opinion.
  final double? value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final v = value;
    final filled = ((v ?? 0) / 100).clamp(0.0, 1.0).toDouble();

    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 34,
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 9.5,
                height: 1.2,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: BreakLabColors.inkSoft,
              ),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            flex: 52,
            child: Container(
              height: 13,
              decoration: BoxDecoration(
                color: const Color(0xFFF1EFE9),
                border: Border.all(color: BreakLabColors.hairline),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: filled,
                  child: Container(
                    decoration: BoxDecoration(
                      color: BreakLabColors.breakBlue.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 7),
          SizedBox(
            width: 26,
            child: Text(
              v == null ? '—' : v.round().toString(),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
