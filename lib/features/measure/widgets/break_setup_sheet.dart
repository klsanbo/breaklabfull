import 'package:flutter/material.dart';

import '../../../models/break_position.dart';
import '../../../models/cue_english.dart';
import '../../../models/table_size.dart';
import '../../../theme/breaklab_theme.dart';
import '../measure_controller.dart';
import 'english_picker.dart';
import 'table_position_picker.dart';

/// One door for setting up a break.
///
/// Table size, where the cue ball sits, and the english all live here, and
/// every table drawing in the app opens this same sheet. The player never has
/// to learn a second place to change the same three things.
///
/// Stateless on purpose: the controller owns the values, so dragging the ball
/// updates the screen behind the sheet at the same time and there is only ever
/// one copy of the truth.
class BreakSetupSheet extends StatelessWidget {
  const BreakSetupSheet({
    super.key,
    required this.table,
    required this.position,
    required this.english,
    required this.customDistanceInches,
    required this.onTableChanged,
    required this.onPositionChanged,
    required this.onEnglishChanged,
    required this.onCustomDistanceChanged,
    required this.onDone,
  });

  final TableSize table;
  final BreakPosition position;
  final CueEnglish english;
  final double customDistanceInches;

  final ValueChanged<TableSize> onTableChanged;
  final ValueChanged<BreakPosition> onPositionChanged;
  final ValueChanged<CueEnglish> onEnglishChanged;
  final ValueChanged<double> onCustomDistanceChanged;
  final VoidCallback onDone;

  /// Manual distance bounds — a diagonal 9ft break is about 48", so this is
  /// generous at both ends without allowing nonsense.
  static const minCustomInches = 24.0;
  static const maxCustomInches = 120.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: BreakLabColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          // A short phone in landscape still has to reach DONE.
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: BreakLabColors.inkFaint.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Set up your break',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: BreakLabColors.ink,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Drag the ball where you break from. '
                'Tap the cue ball face for english.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.3,
                  color: BreakLabColors.inkSoft,
                ),
              ),
              const SizedBox(height: 12),
              _SizeChips(selected: table, onChanged: onTableChanged),
              const SizedBox(height: 12),
              if (table.hasGeometry) ...[
                TablePositionPicker(
                  table: table,
                  position: position,
                  onChanged: onPositionChanged,
                  showCaption: false,
                ),
                const SizedBox(height: 9),
                _Readout(table: table, position: position),
              ] else
                _CustomDistance(
                  inches: customDistanceInches,
                  onChanged: onCustomDistanceChanged,
                ),
              const SizedBox(height: 12),
              _EnglishBlock(english: english, onChanged: onEnglishChanged),
              const SizedBox(height: 14),
              _DoneButton(onTap: onDone),
            ],
          ),
        ),
      ),
    );
  }
}

/// Raises the setup sheet for [controller] and returns when it is dismissed.
///
/// Every table in the app calls this — the home strip, the session preview,
/// the Positions header — so there is exactly one setup experience.
Future<void> showBreakSetupSheet(
  BuildContext context,
  MeasureController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => AnimatedBuilder(
      animation: controller,
      builder: (_, __) => BreakSetupSheet(
        table: controller.tableSize,
        position: controller.position,
        english: controller.english,
        customDistanceInches: controller.customDistanceInches,
        onTableChanged: controller.setTableSize,
        onPositionChanged: controller.setPosition,
        onEnglishChanged: controller.setEnglish,
        onCustomDistanceChanged: controller.setCustomDistance,
        onDone: () => Navigator.of(sheetContext).pop(),
      ),
    ),
  );
}

class _SizeChips extends StatelessWidget {
  const _SizeChips({required this.selected, required this.onChanged});

  final TableSize selected;
  final ValueChanged<TableSize> onChanged;

  @override
  Widget build(BuildContext context) {
    // Wrap rather than Row: five chips have to survive a narrow phone and a
    // large system font without overflowing.
    return Wrap(
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

/// Where you're breaking from on the left, how far the ball travels on the
/// right. The left side is [Expanded] so a long label wraps instead of
/// overflowing — two fixed-width Texts in a Row is exactly the bug that put
/// a 412 pixel overflow on the measure screen.
class _Readout extends StatelessWidget {
  const _Readout({required this.table, required this.position});

  final TableSize table;
  final BreakPosition position;

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(fontSize: 12.5, color: BreakLabColors.inkSoft);
    const strong = TextStyle(
      fontWeight: FontWeight.w800,
      color: BreakLabColors.ink,
    );

    final inches = position.travelDistanceInches(table).toStringAsFixed(1);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              text: 'Breaking from ',
              children: [TextSpan(text: position.label, style: strong)],
            ),
            style: base,
          ),
        ),
        const SizedBox(width: 8),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '$inches"', style: strong),
              const TextSpan(text: ' to the rack'),
            ],
          ),
          style: base,
        ),
      ],
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
          BreakSetupSheet.minCustomInches,
          BreakSetupSheet.maxCustomInches,
        )
        .toDouble();
    if (next != inches) onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'No drawing for a custom table — measure the cue ball to the '
          'rack apex once and it sticks.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            height: 1.3,
            color: BreakLabColors.inkSoft,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Nudge(icon: Icons.remove, onTap: () => _nudge(-1)),
            const SizedBox(width: 18),
            Text(
              '${inches.toStringAsFixed(0)}"',
              style: const TextStyle(
                fontSize: 30,
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
        width: 40,
        height: 40,
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
    return GestureDetector(
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
    );
  }
}
