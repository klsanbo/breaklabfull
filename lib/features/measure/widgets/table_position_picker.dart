import 'package:flutter/material.dart';

import '../../../models/break_position.dart';
import '../../../models/table_size.dart';
import '../../../theme/breaklab_theme.dart';

/// A scale drawing of the table with a draggable cue ball.
///
/// Drag the ball anywhere in the kitchen and the exact travel distance to
/// the rack falls out of the geometry — no presets, no measuring tape. The
/// position is sticky, so a player sets it once and breaks all night.
class TablePositionPicker extends StatelessWidget {
  const TablePositionPicker({
    super.key,
    required this.table,
    required this.position,
    required this.onChanged,
    this.enabled = true,
  });

  final TableSize table;
  final BreakPosition position;
  final ValueChanged<BreakPosition> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!table.hasGeometry) return const SizedBox.shrink();

    const railWidth = 5.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // The rail frame sits outside the cloth, so every coordinate below
        // is in cloth space — otherwise the ball lands a few pixels from
        // where it was dropped.
        final clothWidth = constraints.maxWidth - railWidth * 2;
        final clothHeight = clothWidth / 2; // playing surfaces are 2:1

        void handle(Offset local) {
          if (!enabled) return;
          onChanged(BreakPosition(
            x: local.dx / clothWidth,
            y: local.dy / clothHeight,
          ).clampedToKitchen());
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: BreakLabColors.rail, width: railWidth),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: GestureDetector(
                  onPanStart: (d) => handle(d.localPosition),
                  onPanUpdate: (d) => handle(d.localPosition),
                  onTapDown: (d) => handle(d.localPosition),
                  child: SizedBox(
                    width: clothWidth,
                    height: clothHeight,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(painter: _TablePainter()),
                        ),
                        Positioned(
                          left: position.x * clothWidth - 11,
                          top: position.y * clothHeight - 11,
                          child: _CueBall(active: enabled),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            DefaultTextStyle(
              style: const TextStyle(
                fontSize: 12,
                color: BreakLabColors.inkSoft,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(enabled
                      ? 'Drag the cue ball to where you break from · '
                      : 'Breaking from ${position.label} · '),
                  Text(
                    '${position.travelDistanceInches(table).toStringAsFixed(1)}"'
                    ' to the rack',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: BreakLabColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CueBall extends StatelessWidget {
  const _CueBall({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            center: Alignment(-0.3, -0.4),
            colors: [Colors.white, Color(0xFFD8D4C8)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
          border: active
              ? Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1)
              : null,
        ),
      ),
    );
  }
}

class _TablePainter extends CustomPainter {
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
      Rect.fromLTWH(0, 0, size.width * BreakPosition.kitchenLimitX, size.height),
      kitchen,
    );

    // Head string.
    final headString = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 1.5;
    final hx = size.width * BreakPosition.kitchenLimitX;
    canvas.drawLine(Offset(hx, 0), Offset(hx, size.height), headString);

    // Rail diamonds.
    final diamond = Paint()..color = BreakLabColors.diamond;
    for (final f in const [0.25, 0.5, 0.75]) {
      canvas.drawCircle(Offset(size.width * f, 2.5), 2.5, diamond);
      canvas.drawCircle(
          Offset(size.width * f, size.height - 2.5), 2.5, diamond);
    }

    // Foot spot and a suggestion of the rack.
    final spot = Paint()..color = Colors.white.withValues(alpha: 0.5);
    final fx = size.width * BreakPosition.footSpotX;
    final fy = size.height * BreakPosition.footSpotY;
    canvas.drawCircle(Offset(fx, fy), 3, spot);

    // The rack: apex ball sits on the foot spot, widening toward the foot
    // rail — so the triangle points back at the breaker.
    final rack = Paint()..color = Colors.white.withValues(alpha: 0.22);
    final path = Path()
      ..moveTo(fx, fy)
      ..lineTo(fx + size.width * 0.13, fy - size.height * 0.22)
      ..lineTo(fx + size.width * 0.13, fy + size.height * 0.22)
      ..close();
    canvas.drawPath(path, rack);
  }

  @override
  bool shouldRepaint(covariant _TablePainter oldDelegate) => false;
}
