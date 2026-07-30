import 'package:flutter/material.dart';

import '../../../theme/breaklab_theme.dart';

/// The five destinations, with HOME raised in the middle.
///
/// BREAK MAP · SESSIONS · HOME · TRENDS · RECORDS — reading order that puts
/// where-you-break-from first and the trophies last, with home dead centre
/// where a thumb lands.
///
/// This slot was called POSITIONS while Break Map was a v2 idea. They turned
/// out to be one screen, so it carries the name on it.
enum NavDestination {
  breakMap('BREAK MAP', Icons.gps_fixed),
  sessions('SESSIONS', Icons.access_time),
  home('HOME', Icons.home_outlined),
  trends('TRENDS', Icons.trending_up),
  records('RECORDS', Icons.emoji_events_outlined);

  const NavDestination(this.label, this.icon);

  final String label;
  final IconData icon;
}

class BreakLabNav extends StatelessWidget {
  const BreakLabNav({
    super.key,
    required this.current,
    required this.onSelected,
  });

  final NavDestination current;
  final ValueChanged<NavDestination> onSelected;

  /// The raised centre button needs 63 points inside the bar. It gets 70 —
  /// 62 was the two-pixel overflow that shipped once already.
  static const barHeight = 70.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: BreakLabColors.surface,
        border: Border(top: BorderSide(color: BreakLabColors.ink, width: 1.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: barHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (final destination in NavDestination.values)
                Expanded(
                  child: destination == NavDestination.home
                      ? _Raised(
                          destination: destination,
                          selected: destination == current,
                          onTap: () => onSelected(destination),
                        )
                      : _Item(
                          destination: destination,
                          selected: destination == current,
                          onTap: () => onSelected(destination),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(
                color: selected
                    ? BreakLabColors.ink
                    : BreakLabColors.ink.withValues(alpha: 0.55),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Icon(destination.icon,
                size: 14,
                color: selected ? BreakLabColors.ink : BreakLabColors.inkSoft),
          ),
          const SizedBox(height: 4),
          Text(
            destination.label,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: selected ? BreakLabColors.ink : BreakLabColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _Raised extends StatelessWidget {
  const _Raised({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: BreakLabColors.breakBlue,
              borderRadius: BorderRadius.circular(7),
              boxShadow: [
                BoxShadow(
                  color: BreakLabColors.breakBlueDark.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(destination.icon, size: 19, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            destination.label,
            style: const TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: BreakLabColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
