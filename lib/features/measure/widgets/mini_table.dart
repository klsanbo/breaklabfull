import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/break_position.dart';
import '../../../models/table_size.dart';
import '../../../theme/breaklab_theme.dart';

/// The one table drawing in BreakLab, drawn the way a player sees it.
///
/// Portrait, head rail at the bottom: you are standing where you break from,
/// looking up the table at the rack. Every table in the app is this painter at
/// a different size, so a spot looks identical everywhere and there is never a
/// table pointing the other way.
///
/// Model to screen, for every caller:
///   x 0 (head rail) -> bottom of the cloth, x 1 (foot rail) -> top
///   y 0 (breaker's left rail) -> left of the cloth, y 1 -> right
class TableClothPainter extends CustomPainter {
  const TableClothPainter({
    this.diamondRadius = 2.5,
    this.spotRadius = 3.0,
    this.showDiamonds = true,
    this.showRack = true,
    this.showGrid = false,
    this.showPockets = false,
    this.showHeadSpot = false,
    this.showHeadString = true,
  });

  final double diamondRadius;
  final double spotRadius;
  final bool showDiamonds;
  final bool showRack;

  /// Square cells a quarter of the table's width across. Without them the
  /// cloth is a flat colour and a player cannot see it move under the ball.
  final bool showGrid;
  final bool showPockets;

  /// The dot on the head string a quarter of the way up, centre width.
  final bool showHeadSpot;
  final bool showHeadString;

  static const _kitchenTop = 1 - BreakPosition.kitchenLimitX;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [BreakLabColors.feltDark, BreakLabColors.felt],
        ).createShader(Offset.zero & size),
    );

    if (showGrid) {
      final cell = w / 4;
      final line = Paint()
        ..color = Colors.black.withValues(alpha: 0.10)
        ..strokeWidth = 1;
      for (var x = cell; x < w; x += cell) {
        canvas.drawLine(Offset(x, 0), Offset(x, h), line);
      }
      for (var y = h - cell; y > 0; y -= cell) {
        canvas.drawLine(Offset(0, y), Offset(w, y), line);
      }
    }

    // The kitchen — the legal break area — is the bottom quarter here.
    final kitchenTop = h * _kitchenTop;
    canvas.drawRect(
      Rect.fromLTWH(0, kitchenTop, w, h - kitchenTop),
      Paint()..color = Colors.white.withValues(alpha: 0.07),
    );

    if (showHeadString) {
      _dashedLine(
        canvas,
        Offset(0, kitchenTop),
        Offset(w, kitchenTop),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.45)
          ..strokeWidth = 1.5,
      );
    }

    if (showPockets) {
      final r = w * 0.072;
      final dark = Paint()..color = const Color(0xFF0C0B0A);
      for (final corner in const [Offset(0, 0), Offset(1, 0), Offset(0, 1), Offset(1, 1)]) {
        canvas.drawCircle(Offset(corner.dx * w, corner.dy * h), r, dark);
      }
      // Side pockets sit halfway up the long rails.
      canvas.drawCircle(Offset(0, h / 2), r * 0.9, dark);
      canvas.drawCircle(Offset(w, h / 2), r * 0.9, dark);
    }

    if (showDiamonds && diamondRadius > 0) {
      final diamond = Paint()..color = BreakLabColors.diamond;
      final inset = diamondRadius + 1;
      for (final f in const [0.25, 0.5, 0.75]) {
        canvas.drawCircle(Offset(w * f, inset), diamondRadius, diamond);
        canvas.drawCircle(Offset(w * f, h - inset), diamondRadius, diamond);
      }
      for (final f in const [0.125, 0.25, 0.375, 0.625, 0.75, 0.875]) {
        canvas.drawCircle(Offset(inset, h * f), diamondRadius, diamond);
        canvas.drawCircle(Offset(w - inset, h * f), diamondRadius, diamond);
      }
    }

    final footX = w * BreakPosition.footSpotY;
    final footY = h * (1 - BreakPosition.footSpotX);

    if (spotRadius > 0) {
      canvas.drawCircle(
        Offset(footX, footY),
        spotRadius,
        Paint()..color = Colors.white.withValues(alpha: 0.6),
      );
    }

    if (showHeadSpot) {
      canvas.drawCircle(
        Offset(w * 0.5, kitchenTop),
        spotRadius * 0.9,
        Paint()..color = const Color(0xFF14130F),
      );
    }

    if (showRack) {
      // The apex ball sits ON the foot spot and the rack widens toward the
      // foot rail, which is up the screen — so it points back at the breaker.
      final rack = Paint()..color = Colors.white.withValues(alpha: 0.22);
      canvas.drawPath(
        Path()
          ..moveTo(footX, footY)
          ..lineTo(footX - w * 0.22, footY - h * 0.13)
          ..lineTo(footX + w * 0.22, footY - h * 0.13)
          ..close(),
        rack,
      );
    }
  }

  void _dashedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
    const dash = 5.0, gap = 4.0;
    final total = (to - from).distance;
    if (total <= 0) return;
    final step = (to - from) / total;
    var travelled = 0.0;
    while (travelled < total) {
      final end = math.min(travelled + dash, total);
      canvas.drawLine(from + step * travelled, from + step * end, paint);
      travelled = end + gap;
    }
  }

  @override
  bool shouldRepaint(covariant TableClothPainter old) =>
      old.diamondRadius != diamondRadius ||
      old.spotRadius != spotRadius ||
      old.showDiamonds != showDiamonds ||
      old.showRack != showRack ||
      old.showGrid != showGrid ||
      old.showPockets != showPockets ||
      old.showHeadSpot != showHeadSpot ||
      old.showHeadString != showHeadString;
}

/// A small, non-interactive portrait table with the cue ball where it sits.
///
/// Sized by [width]; the cloth's height follows from the table's real
/// proportions, so callers never have to work it out.
class MiniTable extends StatelessWidget {
  const MiniTable({
    super.key,
    required this.table,
    required this.position,
    this.width = 34,
    this.railWidth = 2.5,
    this.ghostPosition,
    this.borderRadius = 3.5,
  });

  final TableSize table;
  final BreakPosition position;

  /// Outer width including the rail frame.
  final double width;
  final double railWidth;

  /// A second, dimmer ball — a previous break shown behind the current one.
  final BreakPosition? ghostPosition;
  final double borderRadius;

  /// Length-to-width ratio of the playing surface. Every preset is 2:1, but
  /// take it from the table rather than assuming.
  double get _ratio => table.hasGeometry
      ? table.playingLengthInches / table.playingWidthInches
      : 2.0;

  @override
  Widget build(BuildContext context) {
    final clothWidth = math.max(0.0, width - railWidth * 2);
    final clothHeight = clothWidth * _ratio;

    // Dot sizes follow the drawing, or a 30px table gets a 320px table's
    // diamonds. A ball is 2.25 inches — drawn that big and no bigger.
    final pxPerInch = table.hasGeometry
        ? clothHeight / table.playingLengthInches
        : clothHeight / 78.0;
    final ballDiameter =
        math.max(3.0, BreakPosition.ballDiameterInches * pxPerInch);
    final scale = (clothWidth / 150).clamp(0.25, 1.0).toDouble();

    final showBall = table.hasGeometry;
    final ghost = ghostPosition;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius + railWidth),
        border: Border.all(color: BreakLabColors.rail, width: railWidth),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: SizedBox(
          width: clothWidth,
          height: clothHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: TableClothPainter(
                    diamondRadius: 2.0 * scale,
                    spotRadius: 2.4 * scale,
                    showDiamonds: clothWidth > 80,
                    showHeadString: clothWidth > 50,
                  ),
                ),
              ),
              if (showBall && ghost != null)
                _dot(ghost, clothWidth, clothHeight, ballDiameter, faded: true),
              if (showBall)
                _dot(position, clothWidth, clothHeight, ballDiameter),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(
    BreakPosition at,
    double w,
    double h,
    double diameter, {
    bool faded = false,
  }) {
    return Positioned(
      // Portrait: y across, x up from the bottom.
      left: at.y * w - diameter / 2,
      top: (1 - at.x) * h - diameter / 2,
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: faded ? Colors.white.withValues(alpha: 0.55) : Colors.white,
          boxShadow: faded
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
      ),
    );
  }
}
