import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/break_position.dart';
import '../../../models/table_size.dart';
import '../../../theme/breaklab_theme.dart';

/// The one table drawing in BreakLab.
///
/// Every table a player sees is this painter at a different size: the home
/// setup strip, the Recent Session preview, the Positions header, and the big
/// draggable picker inside the setup sheet. One drawing means a spot looks
/// identical everywhere, and there is never a table that behaves differently
/// from the last one.
class TableClothPainter extends CustomPainter {
  const TableClothPainter({
    this.diamondRadius = 2.5,
    this.spotRadius = 3.0,
    this.showDiamonds = true,
    this.showRack = true,
  });

  final double diamondRadius;
  final double spotRadius;
  final bool showDiamonds;
  final bool showRack;

  @override
  void paint(Canvas canvas, Size size) {
    final felt = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [BreakLabColors.felt, BreakLabColors.feltDark],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, felt);

    // The kitchen — the legal break area, behind the head string.
    final kitchen = Paint()..color = Colors.white.withValues(alpha: 0.08);
    canvas.drawRect(
      Rect.fromLTWH(
          0, 0, size.width * BreakPosition.kitchenLimitX, size.height),
      kitchen,
    );

    // Head string.
    final headString = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 1.5;
    final hx = size.width * BreakPosition.kitchenLimitX;
    canvas.drawLine(Offset(hx, 0), Offset(hx, size.height), headString);

    if (showDiamonds && diamondRadius > 0) {
      final diamond = Paint()..color = BreakLabColors.diamond;
      for (final f in const [0.25, 0.5, 0.75]) {
        canvas.drawCircle(
            Offset(size.width * f, diamondRadius), diamondRadius, diamond);
        canvas.drawCircle(Offset(size.width * f, size.height - diamondRadius),
            diamondRadius, diamond);
      }
    }

    final fx = size.width * BreakPosition.footSpotX;
    final fy = size.height * BreakPosition.footSpotY;

    if (spotRadius > 0) {
      final spot = Paint()..color = Colors.white.withValues(alpha: 0.5);
      canvas.drawCircle(Offset(fx, fy), spotRadius, spot);
    }

    if (showRack) {
      // The apex ball sits ON the foot spot and the rack widens toward the
      // foot rail — so the triangle points back at the breaker, not away.
      final rack = Paint()..color = Colors.white.withValues(alpha: 0.22);
      final path = Path()
        ..moveTo(fx, fy)
        ..lineTo(fx + size.width * 0.13, fy - size.height * 0.22)
        ..lineTo(fx + size.width * 0.13, fy + size.height * 0.22)
        ..close();
      canvas.drawPath(path, rack);
    }
  }

  @override
  bool shouldRepaint(covariant TableClothPainter old) =>
      old.diamondRadius != diamondRadius ||
      old.spotRadius != spotRadius ||
      old.showDiamonds != showDiamonds ||
      old.showRack != showRack;
}

/// A small, non-interactive scale table with the cue ball where it sits.
///
/// Sized by [width] when given, otherwise it fills whatever width it is
/// handed. The cloth is always 2:1 like a real playing surface, so the height
/// follows from the width and callers never have to guess it.
class MiniTable extends StatelessWidget {
  const MiniTable({
    super.key,
    required this.table,
    required this.position,
    this.width,
    this.railWidth = 3.0,
    this.ballDiameter = 9.0,
    this.ghostPosition,
    this.caption,
    this.borderRadius = 5.0,
  });

  final TableSize table;
  final BreakPosition position;

  /// Outer width including the rail frame. Null means fill the parent.
  final double? width;
  final double railWidth;
  final double ballDiameter;

  /// A second, dimmer ball — used to show a previous break behind the current
  /// one on the session preview.
  final BreakPosition? ghostPosition;

  /// Optional line across the bottom of the cloth, e.g. "WHERE YOU BROKE FROM".
  final String? caption;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final fixed = width;
    if (fixed != null) return _frame(fixed);
    return LayoutBuilder(builder: (_, c) => _frame(c.maxWidth));
  }

  Widget _frame(double outerWidth) {
    final clothWidth = math.max(0.0, outerWidth - railWidth * 2);
    final clothHeight = clothWidth / 2;

    // Dot sizes are relative to the drawing, or a 70px strip gets the same
    // fat diamonds as a 320px picker.
    final scale = (clothWidth / 300).clamp(0.3, 1.0).toDouble();

    // Custom has no known dimensions, so a spot on it would be a fiction.
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
                    diamondRadius: 2.5 * scale,
                    spotRadius: 3.0 * scale,
                    showDiamonds: clothWidth > 110,
                  ),
                ),
              ),
              if (showBall && ghost != null)
                _dot(ghost, clothWidth, clothHeight, faded: true),
              if (showBall) _dot(position, clothWidth, clothHeight),
              if (caption != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 3,
                  child: Text(
                    caption!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 8.5,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(BreakPosition at, double w, double h, {bool faded = false}) {
    return Positioned(
      left: at.x * w - ballDiameter / 2,
      top: at.y * h - ballDiameter / 2,
      child: Container(
        width: ballDiameter,
        height: ballDiameter,
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
