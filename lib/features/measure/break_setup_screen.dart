import 'package:flutter/material.dart';

import '../../models/break_position.dart';
import '../../models/cue_english.dart';
import '../../models/table_size.dart';
import '../../theme/breaklab_theme.dart';
import 'measure_controller.dart';
import 'widgets/break_table_view.dart';
import 'widgets/english_picker.dart';

/// One door for setting up a break: table size, where the cue ball sits, and
/// the english. Every table drawing in the app opens this screen, so a player
/// never has to learn a second place to change the same three things.
///
/// It is a screen rather than a sheet because a portrait table needs the
/// height — the table is the point, and a panel starves it.
class BreakSetupScreen extends StatelessWidget {
  const BreakSetupScreen({super.key, required this.controller});

  final MeasureController controller;

  /// Manual distance bounds — a diagonal 9ft break is about 54", so this is
  /// generous at both ends without allowing nonsense.
  static const minCustomInches = 24.0;
  static const maxCustomInches = 120.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Set up your break',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text(
              'Done',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: BreakLabColors.labGreenDark,
              ),
            ),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final table = controller.tableSize;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The table takes whatever is left after the controls, so a short
              // phone loses table height rather than overflowing.
              Expanded(
                child: table.hasGeometry
                    ? BreakTableView(
                        table: table,
                        position: controller.position,
                        onChanged: controller.setPosition,
                      )
                    : _CustomDistance(
                        inches: controller.customDistanceInches,
                        onChanged: controller.setCustomDistance,
                      ),
              ),
              if (table.hasGeometry)
                _Readout(
                  table: table,
                  position: controller.position,
                  distanceInches: controller.activeDistanceInches,
                ),
              _SizeChips(selected: table, onChanged: controller.setTableSize),
              _EnglishBlock(
                english: controller.english,
                onChanged: controller.setEnglish,
              ),
              _DoneButton(onTap: () => Navigator.of(context).maybePop()),
            ],
          );
        },
      ),
    );
  }
}

/// Pushes the setup screen for [controller] and returns when it closes.
Future<void> openBreakSetup(
  BuildContext context,
  MeasureController controller,
) {
  return Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => BreakSetupScreen(controller: controller),
  ));
}

/// Where you're breaking from on the left, how far the ball travels on the
/// right. The left side is [Expanded] so a long label wraps instead of
/// overflowing — two fixed-width Texts in a Row is exactly the bug that put a
/// 412 pixel overflow on the measure screen.
class _Readout extends StatelessWidget {
  const _Readout({
    required this.table,
    required this.position,
    required this.distanceInches,
  });

  final TableSize table;
  final BreakPosition position;
  final double distanceInches;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: BreakLabColors.ink, width: 1.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text.rich(
                  TextSpan(
                    text: 'Breaking from ',
                    children: [
                      TextSpan(
                        text: position.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: BreakLabColors.ink,
                        ),
                      ),
                    ],
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    color: BreakLabColors.inkSoft,
                  ),
                ),
                Text(
                  table.label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: BreakLabColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${distanceInches.toStringAsFixed(1)}"',
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: BreakLabColors.ink,
                ),
              ),
              const Text(
                'TO THE RACK',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: BreakLabColors.inkFaint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SizeChips extends StatelessWidget {
  const _SizeChips({required this.selected, required this.onChanged});

  final TableSize selected;
  final ValueChanged<TableSize> onChanged;

  @override
  Widget build(BuildContext context) {
    // Wrap rather than Row: five chips have to survive a narrow phone and a
    // large system font without overflowing.
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 0),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final size in TableSize.values)
            _Chip(
              label: size.shortLabel,
              selected: size == selected,
              onTap: () => onChanged(size),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFDDF0E2) : Colors.white,
          border: Border.all(
            color: selected ? BreakLabColors.labGreen : BreakLabColors.hairline,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? BreakLabColors.labGreenDark : BreakLabColors.ink,
          ),
        ),
      ),
    );
  }
}

class _CustomDistance extends StatelessWidget {
  const _CustomDistance({required this.inches, required this.onChanged});

  final double inches;
  final ValueChanged<double> onChanged;

  void _nudge(double by) {
    final next = (inches + by)
        .clamp(
          BreakSetupScreen.minCustomInches,
          BreakSetupScreen.maxCustomInches,
        )
        .toDouble();
    if (next != inches) onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'No drawing for a custom table — measure the cue ball to the '
            'rack apex once and it sticks.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: BreakLabColors.inkSoft,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Nudge(icon: Icons.remove, onTap: () => _nudge(-1)),
              const SizedBox(width: 18),
              Text(
                '${inches.toStringAsFixed(0)}"',
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: BreakLabColors.ink,
                ),
              ),
              const SizedBox(width: 18),
              _Nudge(icon: Icons.add, onTap: () => _nudge(1)),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'TO THE RACK',
            style: TextStyle(
              fontSize: 9.5,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w700,
              color: BreakLabColors.inkFaint,
            ),
          ),
        ],
      ),
    );
  }
}

class _Nudge extends StatelessWidget {
  const _Nudge({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: BreakLabColors.ink, width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: BreakLabColors.ink),
      ),
    );
  }
}

class _EnglishBlock extends StatelessWidget {
  const _EnglishBlock({required this.english, required this.onChanged});

  final CueEnglish english;
  final ValueChanged<CueEnglish> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 11, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: BreakLabColors.hairline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          EnglishPicker(
            english: english,
            onChanged: onChanged,
            size: 66,
            showLabel: false,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'English · ${english.label}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: BreakLabColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Drag the blue dot to where your tip strikes the ball. '
                  'Recorded with every break — never scored.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
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

class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: BreakLabColors.labGreenDark,
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Text(
              'DONE',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
