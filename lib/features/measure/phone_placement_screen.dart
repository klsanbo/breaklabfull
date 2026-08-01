import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/breaklab_theme.dart';
import '../onboarding/widgets/onboarding_chrome.dart';
import 'widgets/mini_table.dart';

/// BL-006 — where to put the phone.
///
/// Placement is the one setup mistake that quietly ruins every reading after
/// it, which is RISK-005 in the project record. A player who props the phone
/// on the far rail will get readings that look fine and are wrong, and will
/// blame the app rather than the rail. So this is a picture with four rules,
/// not a paragraph.
class PhonePlacementScreen extends StatelessWidget {
  const PhonePlacementScreen({
    super.key,
    required this.onDone,
    this.onSkip,
    this.doneLabel = 'IT IS IN PLACE',
  });

  /// Placement confirmed. The caller decides where that goes next.
  final VoidCallback onDone;

  /// Null hides the skip action. Present during onboarding, absent when the
  /// screen was opened deliberately from a failed reading.
  final VoidCallback? onSkip;

  final String doneLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'PHONE PLACEMENT',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 1),
            Text(
              'It hears the break — put it where it can',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: BreakLabColors.inkSoft,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (onSkip != null)
            TextButton(
              onPressed: onSkip,
              child: const Text(
                'Skip',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: BreakLabColors.inkFaint,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PlacementDiagram(),
              const SizedBox(height: 14),
              const _Rule(
                good: true,
                title: 'On the rail at the head of the table',
                body: 'Near where you break from. Both sounds reach it '
                    'clearly.',
              ),
              const _Rule(
                good: true,
                title: 'Screen up, mic uncovered',
                body: 'Not in a pocket, not face down, nothing sitting on it.',
              ),
              const _Rule(
                good: true,
                title: 'Leave it there for the whole session',
                body: 'Moving it between breaks changes what it hears.',
              ),
              const _Rule(
                good: false,
                title: 'Not on the far rail or in your hand',
                body: 'Too far away and the rack impact gets lost in the room.',
                last: true,
              ),
              const SizedBox(height: 14),
              const NoteCard(
                tone: NoteTone.warn,
                title: 'ONE HONEST WARNING',
                body: 'A loud room — a jukebox, a nearby table breaking — will '
                    'cost you readings. BreakLab will tell you it could not '
                    'read one rather than guess at it.',
              ),
              const SizedBox(height: 16),
              PrimaryButton(label: doneLabel, onPressed: onDone),
            ],
          ),
        ),
      ),
    );
  }
}

/// The table, seen from above, with the phone on it.
///
/// Landscape, because the rack has to be in frame for the aim to read
/// properly. It is the same cloth drawing as everywhere else in the app,
/// turned a quarter turn — one painter, three presentations, so the cloth can
/// never drift between screens.
class PlacementDiagram extends StatelessWidget {
  const PlacementDiagram({super.key});

  /// Fractions of the cloth. x runs head rail -> foot rail, y runs the
  /// breaker's left rail -> right rail.
  static const phoneAt = Offset(0.09, 0.13);
  static const cueBallAt = Offset(0.14, 0.5);

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2.0,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: BreakLabColors.rail, width: 8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              final ball = w * 0.038;
              final phoneW = w * 0.046;
              final phoneH = w * 0.080;

              Widget at(Offset f, double cw, double ch, Widget child) =>
                  Positioned(
                    left: w * f.dx - cw / 2,
                    top: h * f.dy - ch / 2,
                    width: cw,
                    height: ch,
                    child: child,
                  );

              Widget ring(double diameter) => at(
                    phoneAt,
                    diameter,
                    diameter,
                    DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.55),
                          width: 1.4,
                        ),
                      ),
                    ),
                  );

              return Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: const _LandscapeClothPainter(),
                      isComplex: true,
                    ),
                  ),
                  ring(w * 0.17),
                  ring(w * 0.28),
                  at(
                    cueBallAt,
                    ball,
                    ball,
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(color: Color(0x80000000), blurRadius: 3),
                        ],
                      ),
                    ),
                  ),
                  at(
                    phoneAt,
                    phoneW,
                    phoneH,
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF111111),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: Colors.white, width: 1.4),
                      ),
                    ),
                  ),
                  // Both markers sit in the left sixth of the cloth, so their
                  // labels hang off to the right where there is room. Centring
                  // a label on a marker that close to the edge only buys a
                  // clipped word.
                  _Label(
                    text: 'PHONE HERE',
                    left: w * phoneAt.dx + phoneW / 2 + 6,
                    top: h * phoneAt.dy - 7,
                  ),
                  _Label(
                    text: 'YOU BREAK FROM HERE',
                    left: w * cueBallAt.dx + ball / 2 + 6,
                    top: h * cueBallAt.dy - 7,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A caption pinned over the cloth, its left edge at [left].
///
/// Deliberately not text-scaled: this is a label inside a diagram, and a
/// system font at 1.6x would cover the table it is labelling.
class _Label extends StatelessWidget {
  const _Label({required this.text, required this.left, required this.top});

  final String text;
  final double left;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0x8C000000),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          textScaler: TextScaler.noScaling,
          maxLines: 1,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

/// The portrait cloth, turned a quarter turn clockwise.
///
/// Same trick [HeatTable] uses, and for the same reason: there is one drawing
/// of a pool table in this app. Model x 0 (the head rail) lands on the left
/// edge, model y 0 (the breaker's left rail) on the top edge.
class _LandscapeClothPainter extends CustomPainter {
  const _LandscapeClothPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width, 0);
    canvas.rotate(math.pi / 2);
    const TableClothPainter(
      diamondRadius: 2.0,
      spotRadius: 2.6,
      showHeadString: true,
    ).paint(canvas, Size(size.height, size.width));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LandscapeClothPainter old) => false;
}

class _Rule extends StatelessWidget {
  const _Rule({
    required this.good,
    required this.title,
    required this.body,
    this.last = false,
  });

  final bool good;
  final String title;
  final String body;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: last
          ? null
          : const BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: BreakLabColors.hairline)),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: good
                  ? BreakLabColors.labGreen
                  : const Color(0xFFB3261E),
            ),
            child: Icon(
              good ? Icons.check : Icons.close,
              size: 12,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
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

/// Opens BL-006 as its own screen and returns when the player dismisses it.
Future<void> openPhonePlacement(BuildContext context) {
  return Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (routeContext) => PhonePlacementScreen(
      onDone: () => Navigator.of(routeContext).maybePop(),
    ),
  ));
}
