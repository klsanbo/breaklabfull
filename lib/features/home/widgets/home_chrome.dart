import 'package:flutter/material.dart';

import '../../../theme/breaklab_theme.dart';

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

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _Rule(),
        const SizedBox(width: 10),
        const _Slashes(),
        const SizedBox(width: 10),
        Flexible(child: pill),
        const SizedBox(width: 10),
        const _Rule(),
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 1.5,
        color: BreakLabColors.ink,
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

/// The five destination tiles.
class TileRow extends StatelessWidget {
  const TileRow({super.key, required this.tiles});

  final List<HomeTile> tiles;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        // Without this the stretch has no height to stretch to and the whole
        // column collapses — the same trap the stat strip fell into.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(child: tiles[i]),
            ],
          ],
        ),
      );
}

class HomeTile extends StatelessWidget {
  const HomeTile({
    super.key,
    required this.icon,
    required this.name,
    required this.description,
    required this.onTap,
    this.locked = false,
  });

  final IconData icon;
  final String name;
  final String description;
  final VoidCallback onTap;

  /// Drawn dimmed with a padlock — a real destination that isn't in v1.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(3, 11, 3, 9),
        decoration: BoxDecoration(
          color: locked ? const Color(0xFFF3F1EC) : Colors.white,
          border: Border.all(color: BreakLabColors.ink, width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: BreakLabColors.ink, width: 1.5),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Icon(icon, size: 18, color: BreakLabColors.ink),
            ),
            const SizedBox(height: 7),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                ),
                if (locked)
                  const Icon(Icons.lock,
                      size: 9, color: BreakLabColors.inkFaint),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 9.5,
                height: 1.25,
                color: BreakLabColors.inkSoft,
              ),
            ),
            const SizedBox(height: 3),
            const Icon(Icons.chevron_right,
                size: 14, color: BreakLabColors.ink),
          ],
        ),
      ),
    );
  }
}

/// The closing banner.
class LabBanner extends StatelessWidget {
  const LabBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 78, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BreakLabColors.ink, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: BreakLabColors.ink, width: 1.5),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Icon(Icons.emoji_events_outlined, size: 21),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'STOP GUESSING. START TUNING.',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.italic,
                        letterSpacing: 0.4,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Every break is a chance to get better.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: BreakLabColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
