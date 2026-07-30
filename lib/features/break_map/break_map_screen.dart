import 'package:flutter/material.dart';

import '../../models/break_zone.dart';
import '../../models/speed_band.dart';
import '../../theme/breaklab_theme.dart';
import '../measure/measure_controller.dart';
import '../measure/widgets/break_button.dart';
import 'widgets/heat_table.dart';

/// Break Map — where you break from, and where it works.
///
/// The map is coloured by speed and ranked by Break Score, and those are
/// usually different answers. That gap is the most useful thing on the screen:
/// the zone you hit hardest from is often not the zone you break best from.
///
/// Nothing here is drawn from data that cannot support it. A zone stays
/// uncoloured until it has five readable breaks, and until then the screen says
/// how far off it is rather than showing a shape.
class BreakMapScreen extends StatelessWidget {
  const BreakMapScreen({super.key, required this.controller, this.onBreak});

  final MeasureController controller;

  /// Tapping BREAK here arms the same one-tap capture as home.
  final Future<void> Function()? onBreak;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'BREAK MAP',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              'Find your best break position',
              style: TextStyle(fontSize: 9.5, color: BreakLabColors.inkSoft),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final zones = controller.zones;
          final rated = zones.where((z) => z.isRated).toList();
          final best = _bestScoring(rated);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TablePicker(controller: controller),
                const SizedBox(height: 10),
                HeatTable(
                  table: controller.tableSize,
                  zones: zones,
                  positions: const [],
                ),
                const SizedBox(height: 10),
                if (rated.isEmpty)
                  _NotYet(zones: zones)
                else
                  _BestZone(best: best!),
                const SizedBox(height: 10),
                const _Legend(),
                const SizedBox(height: 10),
                _ZoneRows(zones: zones, bestScoring: best?.zone),
                const SizedBox(height: 14),
                Center(
                  child: BreakButton(
                    diameter: 132,
                    subtitle: 'MAKE SURE IT IS QUIET',
                    onPressed: onBreak == null ? null : () => onBreak!(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// The rated zone with the highest average Break Score. Speed decides the
  /// colour; the score decides which zone is actually best.
  static ZoneStats? _bestScoring(List<ZoneStats> rated) {
    ZoneStats? best;
    for (final z in rated) {
      final score = z.averageBreakScore;
      if (score == null) continue;
      if (best == null || score > best.averageBreakScore!) best = z;
    }
    // No outcome cards filled in anywhere: fall back to the fastest, and the
    // copy says so rather than claiming a best.
    if (best == null && rated.isNotEmpty) {
      best = rated.reduce(
          (a, b) => (b.averageMph ?? 0) > (a.averageMph ?? 0) ? b : a);
    }
    return best;
  }
}

class _TablePicker extends StatelessWidget {
  const _TablePicker({required this.controller});

  final MeasureController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 6, 11, 7),
      decoration: BoxDecoration(
        border: Border.all(color: BreakLabColors.ink, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Text(
            'TABLE',
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: BreakLabColors.inkFaint,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              controller.tableSize.label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _BestZone extends StatelessWidget {
  const _BestZone({required this.best});

  final ZoneStats best;

  @override
  Widget build(BuildContext context) {
    final mph = best.averageMph;
    final band = mph == null ? null : SpeedBand.forMph(mph);
    final score = best.averageBreakScore;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BreakLabColors.ink, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: band == null
                  ? BreakLabColors.inkFaint
                  : HeatTable.tintFor(band),
            ),
            child: Container(
              width: 13,
              height: 13,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  score == null ? 'YOUR FASTEST ZONE' : 'YOUR BEST ZONE',
                  style: const TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: BreakLabColors.inkFaint,
                  ),
                ),
                Text(
                  score == null
                      ? best.zone.label.toUpperCase()
                      : '${best.zone.label.toUpperCase()} · SCORE '
                          '${score.round()}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _blurb(mph, band, score),
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: BreakLabColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _blurb(double? mph, SpeedBand? band, double? score) {
    if (mph == null) return 'Not enough readable breaks here yet.';
    final speed = '${mph.toStringAsFixed(1)} MPH — '
        '${band!.label.toLowerCase()}';
    if (score == null) {
      return 'Averages $speed. Fill in an outcome card and this becomes your '
          'best zone rather than just your fastest.';
    }
    return 'Averages $speed, and your highest Break Score of the zones you '
        'have enough breaks in.';
  }
}

class _NotYet extends StatelessWidget {
  const _NotYet({required this.zones});

  final List<ZoneStats> zones;

  @override
  Widget build(BuildContext context) {
    final closest = zones.reduce(
        (a, b) => b.reliableCount > a.reliableCount ? b : a);

    return Container(
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BreakLabColors.ink, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'NOT ENOUGH BREAKS TO DRAW A MAP',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Every break you take is on the table above. A zone gets coloured '
            'once it has five readable breaks behind it — before that a map '
            'would be guessing, and this one does not guess.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.45,
              color: BreakLabColors.inkSoft,
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              for (var i = 0; i < BreakZone.minBreaksForRating; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: i < closest.reliableCount
                          ? BreakLabColors.breakBlue
                          : const Color(0xFFE4E1D9),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 8, 11, 9),
      decoration: BoxDecoration(
        border: Border.all(color: BreakLabColors.hairline),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'SPEED BAND',
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: BreakLabColors.inkFaint,
            ),
          ),
          const SizedBox(height: 5),
          for (final band in SpeedBand.values.toList().reversed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1.5),
              child: Row(
                children: [
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: HeatTable.tintFor(band),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      band.label.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  Text(
                    '${band.range} MPH',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: BreakLabColors.inkSoft,
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

class _ZoneRows extends StatelessWidget {
  const _ZoneRows({required this.zones, required this.bestScoring});

  final List<ZoneStats> zones;
  final BreakZone? bestScoring;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BreakLabColors.ink, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          for (var i = 0; i < zones.length; i++) ...[
            if (i > 0)
              const Divider(
                  height: 1, thickness: 1, color: BreakLabColors.hairline),
            _ZoneRow(
              stats: zones[i],
              isBest: zones[i].zone == bestScoring,
            ),
          ],
        ],
      ),
    );
  }
}

class _ZoneRow extends StatelessWidget {
  const _ZoneRow({required this.stats, required this.isBest});

  final ZoneStats stats;
  final bool isBest;

  @override
  Widget build(BuildContext context) {
    final mph = stats.averageMph;
    final band = mph == null ? null : SpeedBand.forMph(mph);

    return Padding(
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: stats.isRated && band != null
                  ? HeatTable.tintFor(band)
                  : const Color(0xFFE4E1D9),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              stats.zone.label.toUpperCase(),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ),
          if (isBest) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: BreakLabColors.labGreen,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'BEST SCORE',
                style: TextStyle(
                  fontSize: 7.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (!stats.isRated)
            Text(
              '${stats.reliableCount} of '
              '${BreakZone.minBreaksForRating} breaks',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: BreakLabColors.inkFaint,
              ),
            )
          else ...[
            _Num(value: mph!.toStringAsFixed(1), unit: 'MPH'),
            _Num(
              value: stats.averageBreakScore?.round().toString() ?? '—',
              unit: 'SCORE',
            ),
            _Num(value: '${stats.reliableCount}', unit: 'BREAKS'),
          ],
        ],
      ),
    );
  }
}

class _Num extends StatelessWidget {
  const _Num({required this.value, required this.unit});

  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          Text(
            unit,
            style: const TextStyle(
              fontSize: 8,
              letterSpacing: 0.4,
              color: BreakLabColors.inkFaint,
            ),
          ),
        ],
      ),
    );
  }
}
