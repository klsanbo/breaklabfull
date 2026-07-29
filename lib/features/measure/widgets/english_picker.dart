import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/cue_english.dart';
import '../../../theme/breaklab_theme.dart';

/// A cue ball face: drag the contact point to say where you hit it.
///
/// English is an input, not an outcome — it rides beside the table position
/// and stays put between breaks. It is never scored; it only ever explains
/// results ("your best breaks come from a touch of draw").
class EnglishPicker extends StatelessWidget {
  const EnglishPicker({
    super.key,
    required this.english,
    required this.onChanged,
    this.size = 74,
    this.enabled = true,
  });

  final CueEnglish english;
  final ValueChanged<CueEnglish> onChanged;
  final double size;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final radius = size / 2;

    void handle(Offset local) {
      if (!enabled) return;
      var dx = (local.dx - radius) / radius;
      var dy = (local.dy - radius) / radius;
      // Screen y grows downward; follow is up.
      dy = -dy;
      final mag = math.sqrt(dx * dx + dy * dy);
      if (mag > 1) {
        dx /= mag;
        dy /= mag;
      }
      onChanged(CueEnglish(x: dx, y: dy));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onPanStart: (d) => handle(d.localPosition),
          onPanUpdate: (d) => handle(d.localPosition),
          onTapDown: (d) => handle(d.localPosition),
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(painter: _BallFacePainter(english)),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          english.label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: BreakLabColors.inkSoft,
          ),
        ),
      ],
    );
  }
}

class _BallFacePainter extends CustomPainter {
  const _BallFacePainter(this.english);

  final CueEnglish english;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final centre = Offset(r, r);

    canvas.drawCircle(
      centre,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.4),
          colors: [Colors.white, Color(0xFFDDD9CD)],
        ).createShader(Rect.fromCircle(center: centre, radius: r)),
    );
    canvas.drawCircle(
      centre,
      r - 0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = BreakLabColors.hairline,
    );

    // Crosshairs and the miscue limit ring — the practical edge of playable
    // english, drawn as guidance rather than a fence.
    final guide = Paint()
      ..color = BreakLabColors.inkFaint.withValues(alpha: 0.35)
      ..strokeWidth = 0.8;
    canvas.drawLine(
        Offset(r * 0.35, r), Offset(size.width - r * 0.35, r), guide);
    canvas.drawLine(
        Offset(r, r * 0.35), Offset(r, size.height - r * 0.35), guide);
    canvas.drawCircle(
      centre,
      r * CueEnglish.miscueLimit,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = BreakLabColors.inkFaint.withValues(alpha: 0.45),
    );

    // The contact point.
    final dot = Offset(r + english.x * r, r - english.y * r);
    canvas.drawCircle(dot, 7, Paint()..color = BreakLabColors.breakBlue);
    canvas.drawCircle(
      dot,
      7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _BallFacePainter old) => old.english != english;
}
