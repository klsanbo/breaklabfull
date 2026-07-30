import 'package:flutter/material.dart';

import '../../../theme/breaklab_theme.dart';

/// The masthead: the BreakLab mark, the name, and settings.
///
/// The mark replaced a Profile box that had nothing to open — v1 is guest-only,
/// and setup is reached by tapping the table rather than a button up here.
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, this.onSettings});

  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const _Glyph(),
        const Spacer(),
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'BREAK LAB',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                height: 1.05,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'PRACTICE. MEASURE. IMPROVE.',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: BreakLabColors.inkSoft,
              ),
            ),
          ],
        ),
        const Spacer(),
        GestureDetector(
          onTap: onSettings,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              border: Border.all(color: BreakLabColors.ink, width: 1.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Settings',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _Glyph extends StatelessWidget {
  const _Glyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 30,
      decoration: BoxDecoration(
        border: Border.all(color: BreakLabColors.ink, width: 1.5),
        borderRadius: BorderRadius.circular(3),
      ),
      child: CustomPaint(painter: _CrossPainter()),
    );
  }
}

class _CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = BreakLabColors.ink
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset.zero, Offset(size.width, size.height), line);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, 0), line);
  }

  @override
  bool shouldRepaint(covariant _CrossPainter oldDelegate) => false;
}

/// The /// READY pill, flanked by rules — also the LISTENING and MEASURING
/// states, so one piece of furniture carries the whole status.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.icon = Icons.check,
    this.filled = false,
    this.onTap,
  });

  final String label;
  final IconData icon;

  /// Filled means it's an action (BREAK AGAIN), not a status.
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : BreakLabColors.ink;
    final pill = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
        decoration: BoxDecoration(
          color: filled ? BreakLabColors.breakBlue : const Color(0xFFEFEDE7),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: filled ? Colors.white : BreakLabColors.labGreen,
                  width: 1.5,
                ),
              ),
              child: Icon(icon,
                  size: 12,
                  color: filled ? Colors.white : BreakLabColors.labGreen),
            ),
            const SizedBox(width: 9),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: filled ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: 0.5,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );

    // The pill is sized by its content and laid out first; the rules take
    // whatever is left. Making the pill flexible too meant it competed with
    // the rules for the same space and got clipped to "LI...".
    return Row(
      children: [
        const Expanded(child: _Rule(alignRight: true)),
        const SizedBox(width: 10),
        const _Slashes(),
        const SizedBox(width: 10),
        pill,
        const SizedBox(width: 10),
        const Expanded(child: _Rule()),
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({this.alignRight = false});

  /// Which end of the leftover space the visible line hugs.
  final bool alignRight;

  @override
  Widget build(BuildContext context) => Align(
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 44,
          height: 1.5,
          color: BreakLabColors.ink,
        ),
      );
}

class _Slashes extends StatelessWidget {
  const _Slashes();

  @override
  Widget build(BuildContext context) => const Text(
        '///',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          letterSpacing: -2,
        ),
      );
}
