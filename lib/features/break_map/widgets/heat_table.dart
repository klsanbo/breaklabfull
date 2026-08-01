import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/break_position.dart';
import '../../../models/break_zone.dart';
import '../../../models/speed_band.dart';
import '../../../models/table_size.dart';
import '../../../theme/breaklab_theme.dart';
import '../../measure/widgets/mini_table.dart';

/// The whole table, landscape, with the kitchen tinted by how fast each zone
/// breaks and every recorded position drawn on it.
///
/// The cloth is the SAME painter every other table in the app uses, turned a
/// quarter turn — head rail to the left, the breaker's left rail along the top.
/// One drawing, three presentations: portrait on setup, portrait small on home,
/// landscape here. A second cloth painter would be a second thing to keep in
/// step.
///
/// Only zones that have earned a rating get colour. Positions are always drawn,
/// rated or not — those are facts, and a player should see their own breaks
/// from the first one.
class HeatTable extends StatelessWidget {
  const HeatTable({
    super.key,
    required this.table,
    required this.zones,
    this.positions = const [],
    this.personalBest,
  });

  final TableSize table;
  final List<ZoneStats> zones;

  /// Every recorded break position. Drawn as plain dots.
  final List<BreakPosition> positions;

  /// The fastest break's position, drawn with a ring around it.
  final BreakPosition? personalBest;

  /// Tint for a speed band. Deeper blue is faster; blue because speed is the
  /// action colour and this is a map of speed.
  static Color tintFor(SpeedBand band) => switch (band) {
    SpeedBand.hard => BreakLabColors.breakBlue,
    SpeedBand.strong => BreakLabColors.breakBlueLight,
    SpeedBand.solid => const Color(0xFF7FB2EC),
    SpeedBand.controlled => const Color(0xFFC3D9F2),
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // A playing surface is 2:1, so landscape is half as tall as it is wide.
        final height = width / 2;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: BreakLabColors.rail, width: 7),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              width: width,
              height: height,
              child: CustomPaint(
                painter: _HeatPainter(
                  table: table,
                  zones: zones,
                  positions: positions,
                  personalBest: personalBest,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeatPainter extends CustomPainter {
  const _HeatPainter({
    required this.table,
    required this.zones,
    required this.positions,
    required this.personalBest,
  });

  final TableSize table;
  final List<ZoneStats> zones;
  final List<BreakPosition> positions;
  final BreakPosition? personalBest;

  /// Model position to landscape canvas point.
  ///
  ///   x 0 (head rail) -> left edge, x 1 (foot rail) -> right edge
  ///   y 0 (breaker's left rail) -> top edge, y 1 -> bottom edge
  Offset _at(BreakPosition p, Size size) =>
      Offset(p.x * size.width, p.y * size.height);

  @override
  void paint(Canvas canvas, Size size) {
    // The portrait cloth painter, rotated a quarter turn clockwise so its head
    // rail (bottom) lands on the left and its y-zero rail lands on top.
    canvas.save();
    canvas.translate(size.width, 0);
    canvas.rotate(math.pi / 2);
    const TableClothPainter(
      diamondRadius: 2.0,
      spotRadius: 2.6,
      showHeadString: true,
    ).paint(canvas, Size(size.height, size.width));
    canvas.restore();

    // Zone tints, inside the kitchen only — there is nowhere else a break can
    // legally start, so there is nowhere else to colour.
    final kitchenRight = size.width * BreakPosition.kitchenLimitX;
    for (final stats in zones) {
      final mph = stats.averageMph;
      if (!stats.isRated || mph == null) continue;
      final band = SpeedBand.forMph(mph);
      canvas.drawRect(
        Rect.fromLTRB(
          0,
          stats.zone.fromY * size.height,
          kitchenRight,
          stats.zone.toY * size.height,
        ),
        Paint()..color = HeatTable.tintFor(band).withValues(alpha: 0.55),
      );
    }

    // Every break taken, whether its zone is rated or not.
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.85);
    for (final p in positions) {
      canvas.drawCircle(_at(p, size), 2.4, dot);
    }

    final best = personalBest;
    if (best != null) {
      final centre = _at(best, size);
      canvas.drawCircle(
        centre,
        7,
        Paint()..color = Colors.white.withValues(alpha: 0.40),
      );
      canvas.drawCircle(centre, 4.2, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _HeatPainter old) =>
      old.table != table ||
      old.personalBest != personalBest ||
      old.positions.length != positions.length ||
      !_sameZones(old.zones, zones);

  bool _sameZones(List<ZoneStats> a, List<ZoneStats> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].isRated != b[i].isRated ||
          a[i].averageMph != b[i].averageMph ||
          a[i].reliableCount != b[i].reliableCount) {
        return false;
      }
    }
    return true;
  }
}
