import 'package:flutter/material.dart';

import '../../../theme/breaklab_theme.dart';

/// The three-cell strip under the title.
///
/// Before a break it reads current form; right after one it flips to that
/// break's numbers, so the same furniture answers both "how am I doing?"
/// and "how was that?".
class StatStrip extends StatelessWidget {
  const StatStrip({super.key, required this.cells});

  final List<StatCell> cells;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BreakLabColors.ink, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < cells.length; i++) ...[
              if (i > 0)
                const VerticalDivider(
                  width: 1.5,
                  thickness: 1.5,
                  color: BreakLabColors.hairline,
                ),
              Expanded(child: cells[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class StatCell extends StatelessWidget {
  const StatCell({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
    this.caption,
    this.captionColor,
    this.round = false,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Small trailing word, e.g. "MPH" or "sessions".
  final String? unit;

  /// Small line under the value, e.g. "STRONG".
  final String? caption;
  final Color? captionColor;
  final bool round;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(11, 10, 8, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: BreakLabColors.ink, width: 1.5),
                  borderRadius: BorderRadius.circular(round ? 11 : 4),
                ),
                child: Icon(icon, size: 12, color: BreakLabColors.ink),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 11.5, height: 1.15),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    unit!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: BreakLabColors.inkSoft,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (caption != null)
            Text(
              caption!,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.3,
                color: captionColor ?? BreakLabColors.labGreen,
              ),
            ),
        ],
      ),
    );
  }
}
