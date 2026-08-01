import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/break_position.dart';
import '../../../models/table_size.dart';
import '../../../theme/breaklab_theme.dart';
import 'mini_table.dart';

/// Place the cue ball by sliding the table under it.
///
/// The ball is pinned dead centre with crosshairs on it and the table moves
/// instead. Two things come out of that: your finger is never on top of the
/// thing you are placing, and the view can be close in, so a rail-tight spot
/// is an easy drag rather than a fight with a small target.
///
/// Past the rails you see the table's apron and the floor beyond it, never a
/// hole — the difference between this reading as a table in a room and reading
/// as a drawing that ran out.
class BreakTableView extends StatefulWidget {
  const BreakTableView({
    super.key,
    required this.table,
    required this.position,
    required this.onChanged,
    this.enabled = true,
    this.wordmark = 'BREAKLAB',
  });

  final TableSize table;
  final BreakPosition position;
  final ValueChanged<BreakPosition> onChanged;
  final bool enabled;

  /// Printed on the skirt below the head rail, and it travels with the table.
  final String wordmark;

  /// How much of the view's width the cloth takes up, measured off Break
  /// Speed's own screen.
  static const clothFraction = 0.74;

  /// Fixed length of the aim arrow, in inches. Long enough to read as a shot
  /// line, short enough that the head stays on screen when the rack does not.
  static const aimReachInches = 11.5;

  /// A wordmark cut in half looks like a defect, so it is drawn whole or not at
  /// all. There is no room under the head rail when the ball is up at the head
  /// string; pull the ball back toward the rail and the skirt comes into view.
  static bool wordmarkFits({
    required double viewHeight,
    required double top,
    required double bottom,
  }) => top >= 0 && bottom <= viewHeight;

  @override
  State<BreakTableView> createState() => _BreakTableViewState();
}

class _BreakTableViewState extends State<BreakTableView> {
  /// Where the finger was on the previous update. The delta is computed here
  /// rather than read from DragUpdateDetails.delta because a single-axis
  /// recognizer only reports its own axis, and a diagonal drag has to move the
  /// table diagonally.
  Offset? _last;

  void _start(Offset local) => _last = local;

  void _move(Offset local, double clothWidth, double clothHeight) {
    final previous = _last ?? local;
    final delta = local - previous;
    _last = local;
    if (!widget.enabled) return;

    // Drag the table right and your viewpoint moves left across it, the way a
    // map works. Drag it down and the ball ends up further up the table.
    widget.onChanged(
      BreakPosition(
        x: widget.position.x + delta.dy / clothHeight,
        y: widget.position.y - delta.dx / clothWidth,
      ).clampedToKitchen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.table.hasGeometry) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewWidth = constraints.maxWidth;
        final viewHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : viewWidth * 1.16;

        final clothWidth = viewWidth * BreakTableView.clothFraction;
        final clothHeight =
            clothWidth *
            (widget.table.playingLengthInches /
                widget.table.playingWidthInches);

        return GestureDetector(
          // Axis recognizers, not a pan: a pan needs 36 logical pixels to
          // claim a gesture and a scroll view needs 18, so a pan loses every
          // vertical drag to whatever is scrolling above it.
          onVerticalDragStart: (d) => _start(d.localPosition),
          onVerticalDragUpdate: (d) =>
              _move(d.localPosition, clothWidth, clothHeight),
          onHorizontalDragStart: (d) => _start(d.localPosition),
          onHorizontalDragUpdate: (d) =>
              _move(d.localPosition, clothWidth, clothHeight),
          child: ClipRect(
            // A CustomPaint does not clip, and the table is deliberately
            // bigger than the view — without this the apron and the wordmark
            // paint straight over whatever sits below the table.
            child: SizedBox(
              width: viewWidth,
              height: viewHeight,
              child: CustomPaint(
                painter: _RoomPainter(
                  table: widget.table,
                  position: widget.position,
                  clothWidth: clothWidth,
                  clothHeight: clothHeight,
                  wordmark: widget.wordmark,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The room: floor, table with its apron and skirt, rails, cloth, and the
/// pinned ball with its crosshairs and aim arrow.
class _RoomPainter extends CustomPainter {
  const _RoomPainter({
    required this.table,
    required this.position,
    required this.clothWidth,
    required this.clothHeight,
    required this.wordmark,
  });

  final TableSize table;
  final BreakPosition position;
  final double clothWidth;
  final double clothHeight;
  final String wordmark;

  static const _floor = Color(0xFF0B0B0A);
  static const _apronColour = Color(0xFF141310);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _floor);

    final apron = clothWidth * 0.115;
    final rail = clothWidth * 0.062;
    final skirt = clothWidth * 0.22;
    final inset = apron + rail;

    // The ball is pinned at the centre of the view; the table is placed so the
    // stored position lands there.
    final pin = Offset(size.width / 2, size.height / 2);
    final clothLeft = pin.dx - position.y * clothWidth;
    final clothTop = pin.dy - (1 - position.x) * clothHeight;

    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        clothLeft - inset,
        clothTop - inset,
        clothWidth + inset * 2,
        clothHeight + inset * 2 + skirt,
      ),
      Radius.circular(clothWidth * 0.055),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawRRect(body, Paint()..color = _apronColour);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          clothLeft - rail,
          clothTop - rail,
          clothWidth + rail * 2,
          clothHeight + rail * 2,
        ),
        Radius.circular(rail * 1.4),
      ),
      Paint()
        ..shader =
            const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [BreakLabColors.rail, Color(0xFF3E2A18)],
            ).createShader(
              Rect.fromLTWH(
                clothLeft - rail,
                clothTop - rail,
                clothWidth,
                clothHeight,
              ),
            ),
    );

    // The cloth, drawn by the same painter every other table in the app uses.
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(clothLeft, clothTop, clothWidth, clothHeight),
    );
    canvas.translate(clothLeft, clothTop);
    const TableClothPainter(
      diamondRadius: 2.4,
      spotRadius: 3.0,
      showGrid: true,
      showPockets: true,
      showHeadSpot: true,
    ).paint(canvas, Size(clothWidth, clothHeight));
    canvas.restore();

    _paintWordmark(
      canvas,
      viewHeight: size.height,
      centre: Offset(
        clothLeft + clothWidth / 2,
        clothTop + clothHeight + rail + skirt * 0.40,
      ),
      size: clothWidth * 0.10,
    );

    _paintAim(canvas, pin, clothLeft, clothTop);
    _paintBall(canvas, pin);
  }

  void _paintWordmark(
    Canvas canvas, {
    required double viewHeight,
    required Offset centre,
    required double size,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: wordmark,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          letterSpacing: size * 0.18,
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final origin = centre - Offset(painter.width / 2, painter.height / 2);
    if (!BreakTableView.wordmarkFits(
      viewHeight: viewHeight,
      top: origin.dy,
      bottom: origin.dy + painter.height,
    )) {
      return;
    }
    painter.paint(canvas, origin);
  }

  /// A fixed-length arrow toward the rack. Drawing a line all the way there
  /// puts the arrowhead off screen, which is where Break Speed's is not.
  void _paintAim(Canvas canvas, Offset pin, double clothLeft, double clothTop) {
    final foot = Offset(
      clothLeft + BreakPosition.footSpotY * clothWidth,
      clothTop + (1 - BreakPosition.footSpotX) * clothHeight,
    );
    final v = foot - pin;
    final length = v.distance;
    if (length <= 0) return;

    final pxPerInch = clothHeight / table.playingLengthInches;
    final reach = BreakTableView.aimReachInches * pxPerInch;
    final unit = v / length;
    final tip = pin + unit * reach;

    final stroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(pin, tip, stroke);

    // Arrowhead: two short strokes back along the shaft.
    final head = reach * 0.16;
    final angle = math.atan2(unit.dy, unit.dx);
    for (final spread in const [2.7, -2.7]) {
      canvas.drawLine(
        tip,
        tip + Offset(math.cos(angle + spread), math.sin(angle + spread)) * head,
        stroke,
      );
    }
  }

  void _paintBall(Canvas canvas, Offset pin) {
    final pxPerInch = clothHeight / table.playingLengthInches;
    final radius = math.max(
      4.0,
      BreakPosition.ballDiameterInches * pxPerInch / 2,
    );

    final guide = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    final cross = radius * 2.4;
    canvas.drawLine(pin - Offset(cross, 0), pin + Offset(cross, 0), guide);
    canvas.drawLine(pin - Offset(0, cross), pin + Offset(0, cross), guide);

    _dashedCircle(
      canvas,
      pin,
      radius * 3.1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.6),
    );

    canvas.drawCircle(
      pin + const Offset(0, 2),
      radius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(
      pin,
      radius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Colors.white, Color(0xFFD8D4C8)],
        ).createShader(Rect.fromCircle(center: pin, radius: radius)),
    );
  }

  void _dashedCircle(Canvas canvas, Offset centre, double radius, Paint paint) {
    const segments = 24;
    const sweep = math.pi * 2 / segments;
    for (var i = 0; i < segments; i += 2) {
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: radius),
        i * sweep,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RoomPainter old) =>
      old.table != table ||
      old.position != position ||
      old.clothWidth != clothWidth ||
      old.clothHeight != clothHeight ||
      old.wordmark != wordmark;
}
