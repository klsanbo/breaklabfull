import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/break_position.dart';
import '../../../models/session.dart';
import '../../../models/table_size.dart';
import '../../../theme/breaklab_theme.dart';
import '../../measure/widgets/mini_table.dart';

/// The last night at the table: when it was, how many breaks, and the three
/// numbers worth a glance.
///
/// The table preview is portrait like every other table in the app, which is
/// why it stands beside the numbers rather than above them.
class RecentSessionCard extends StatelessWidget {
  const RecentSessionCard({
    super.key,
    required this.table,
    required this.position,
    this.stats,
    this.date,
    this.onTap,
  });

  final TableSize table;

  /// Where the breaks came from. Until per-break positions are aggregated this
  /// is the current spot, which is the one the player just used.
  final BreakPosition position;

  final SessionStats? stats;
  final DateTime? date;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = stats;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: BreakLabColors.ink, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'RECENT SESSION',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 11),
            // Passed as a non-nullable to the filled body rather than leaning
            // on flow analysis to promote it through a bool.
            if (s == null || s.breakCount == 0)
              const Text(
                'No breaks measured yet. Tap BREAK and this fills itself in.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: BreakLabColors.inkSoft,
                ),
              )
            else
              _Filled(table: table, position: position, stats: s, date: date),
          ],
        ),
      ),
    );
  }
}

/// The card once there is something in it.
class _Filled extends StatelessWidget {
  const _Filled({
    required this.table,
    required this.position,
    required this.stats,
    required this.date,
  });

  final TableSize table;
  final BreakPosition position;
  final SessionStats stats;
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final when = date;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MiniTable(table: table, position: position, width: 56, railWidth: 2.5),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      when == null
                          ? 'This session'
                          : DateFormat('MMMM d, y').format(when),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${s.breakCount} '
                    '${s.breakCount == 1 ? 'BREAK' : 'BREAKS'}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: BreakLabColors.inkSoft,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: BreakLabColors.inkFaint,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Sub(
                    label: 'BEST',
                    value: s.bestMph?.toStringAsFixed(1),
                    unit: 'MPH',
                  ),
                  _Sub(
                    label: 'AVERAGE',
                    value: s.averageMph?.toStringAsFixed(1),
                    unit: 'MPH',
                  ),
                  _Sub(
                    label: 'SCORE',
                    value: s.averageBreakScore?.round().toString(),
                    unit: 'AVG',
                    last: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Sub extends StatelessWidget {
  const _Sub({
    required this.label,
    required this.value,
    required this.unit,
    this.last = false,
  });

  final String label;

  /// Null means there is nothing to report, which prints as a dash rather than
  /// a zero — a zero is a claim.
  final String? value;
  final String unit;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: last
            ? null
            : const BoxDecoration(
                border: Border(
                  right: BorderSide(color: BreakLabColors.hairline),
                ),
              ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: BreakLabColors.inkFaint,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value ?? '—',
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                height: 1.1,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              unit,
              style: const TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: BreakLabColors.inkFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
