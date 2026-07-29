import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/breaklab_theme.dart';
import '../../measure/widgets/break_button.dart';

/// The centrepiece: orbital arcs around the BREAK button, flanked by the two
/// things you set before breaking.
class OrbitalBreak extends StatelessWidget {
  const OrbitalBreak({
    super.key,
    required this.onBreak,
    required this.left,
    required this.right,
    this.listening = false,
    this.heard = false,
  });

  final VoidCallback? onBreak;
  final Widget left;
  final Widget right;
  final bool listening;
  final bool heard;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 252,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IgnorePointer(
            child: CustomPaint(
              size: const Size(252, 252),
              painter: _ArcPainter(),
            ),
          ),
          BreakButton(
            onPressed: onBreak,
            listening: listening,
            heard: heard,
            diameter: 162,
          ),
          Positioned(left: 0, child: left),
          Positioned(right: 0, child: right),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    Paint stroke(double opacity) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = BreakLabColors.ink.withValues(alpha: opacity);

    canvas.drawCircle(centre, 100, stroke(0.65));
    canvas.drawCircle(centre, 92, stroke(0.4));

    // Two long arcs top-right and top-left, two fainter ones below —
    // the bracket effect from the sketch.
    final outer = Rect.fromCircle(center: centre, radius: 118);
    canvas.drawArc(outer, -math.pi / 2, math.pi / 2, false, stroke(0.45));
    canvas.drawArc(outer, math.pi, math.pi / 2, false, stroke(0.45));
    canvas.drawArc(outer, 0, math.pi / 2, false, stroke(0.22));
    canvas.drawArc(outer, math.pi / 2, math.pi / 2, false, stroke(0.22));
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) => false;
}

/// One of the two chips beside the button: a bordered icon box, a caption,
/// and the current value underneath.
class SetupChip extends StatelessWidget {
  const SetupChip({
    super.key,
    required this.child,
    required this.caption,
    required this.value,
    required this.onTap,
    this.enabled = true,
  });

  final Widget child;
  final String caption;
  final String value;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 86,
      child: Semantics(
        button: true,
        label: '$caption, currently $value',
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: Opacity(
            opacity: enabled ? 1 : 0.45,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: BreakLabColors.ink, width: 1.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: child,
                ),
                const SizedBox(height: 7),
                Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    letterSpacing: 0.4,
                  ),
                ),
                Text(
                  value,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: BreakLabColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tiny felt rectangle with the cue ball where it currently sits.
/// SUPERSEDED by the shared portrait MiniTable in
/// features/measure/widgets/mini_table.dart. Still here only because the
/// old setup chips use it; it goes when home is rebuilt.
class ChipTable extends StatelessWidget {
  const ChipTable({super.key, required this.x, required this.y});

  final double x;
  final double y;

  @override
  Widget build(BuildContext context) {
    const w = 50.0, h = 25.0;
    return SizedBox(
      width: w,
      height: h,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: BreakLabColors.felt,
          border: Border.all(color: BreakLabColors.rail, width: 2),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: w * 0.24,
              child: ColoredBox(
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            Positioned(
              left: (x * w - 3.5).clamp(0.0, w - 7),
              top: (y * h - 3.5).clamp(0.0, h - 7),
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tiny ball face showing the current contact point.
class MiniBallFace extends StatelessWidget {
  const MiniBallFace({super.key, required this.x, required this.y});

  final double x;
  final double y;

  @override
  Widget build(BuildContext context) {
    const d = 40.0;
    return SizedBox(
      width: d,
      height: d,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                center: Alignment(-0.32, -0.4),
                colors: [Colors.white, Color(0xFFDEDACE)],
              ),
              border: Border.all(color: BreakLabColors.inkFaint),
            ),
          ),
          Positioned(
            left: d / 2 + x * (d / 2) - 5,
            top: d / 2 - y * (d / 2) - 5,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: BreakLabColors.breakBlue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
