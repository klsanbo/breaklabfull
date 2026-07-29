import 'package:flutter/material.dart';

import '../../../models/break_position.dart';
import '../../../models/table_size.dart';
import '../../../theme/breaklab_theme.dart';
import 'mini_table.dart';

/// A scale drawing of the table with a draggable cue ball.
///
/// Drag the ball anywhere in the kitchen — up, down, or diagonally, not just
/// along the head string — and the exact travel distance to the rack falls out
/// of the geometry. No presets, no measuring tape. The position is sticky, so
/// a player sets it once and breaks all night.
class TablePositionPicker extends StatelessWidget {
  const TablePositionPicker({
    super.key,
    required this.table,
    required this.position,
    required this.onChanged,
    this.enabled = true,
    this.showCaption = true,
  });

  final TableSize table;
  final BreakPosition position;
  final ValueChanged<BreakPosition> onChanged;
  final bool enabled;

  /// The built-in line under the table. The setup sheet draws its own
  /// two-ended readout instead, so it turns this off.
  final bool showCaption;

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
                  // Two axis recognizers, not one pan recognizer. A pan
                  // needs 36 logical pixels before it claims the gesture
                  // while the scroll view underneath needs only 18, so a
                  // pan always lost every vertical drag to the scroll and
                  // the ball could only be moved left and right. Axis
                  // recognizers share the scroll view's threshold and sit
                  // deeper in the tree, so they win. Both handlers read the
                  // full local position rather than a single-axis delta,
                  // which is why a diagonal drag still lands where the
                  // finger actually is.
                  onVerticalDragStart: (d) => handle(d.localPosition),
                  onVerticalDragUpdate: (d) => handle(d.localPosition),
                  onHorizontalDragStart: (d) => handle(d.localPosition),
                  onHorizontalDragUpdate: (d) => handle(d.localPosition),
                  onTapDown: (d) => handle(d.localPosition),
                  child: SizedBox(
                    width: clothWidth,
                    height: clothHeight,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(painter: TableClothPainter()),
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
            if (showCaption) const SizedBox(height: 6),
            if (showCaption)
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: enabled
                          ? 'Drag the cue ball to where you break from · '
                          : 'Breaking from ${position.label} · ',
                    ),
                    TextSpan(
                      text:
                          '${position.travelDistanceInches(table).toStringAsFixed(1)}"'
                          ' to the rack',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: BreakLabColors.ink,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: BreakLabColors.inkSoft,
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
