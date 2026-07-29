import 'package:flutter/material.dart';

import '../../../models/break_position.dart';
import '../../../models/cue_english.dart';
import '../../../models/table_size.dart';
import '../../../theme/breaklab_theme.dart';
import '../../measure/widgets/english_picker.dart';
import '../../measure/widgets/mini_table.dart';

/// The whole break setup, one line tall and tappable.
///
/// It shows the table with the ball where it actually sits, the english face
/// beside it, and the live travel distance — then opens the setup sheet. No
/// separate Setup button anywhere in the app: you touch the thing you want to
/// change.
class SetupStrip extends StatelessWidget {
  const SetupStrip({
    super.key,
    required this.table,
    required this.position,
    required this.english,
    required this.distanceInches,
    required this.onTap,
  });

  final TableSize table;
  final BreakPosition position;
  final CueEnglish english;

  /// The active distance — geometry for a standard table, the manual figure
  /// for a custom one. Passed in rather than computed so this widget never has
  /// to know which case it is looking at.
  final double distanceInches;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: BreakLabColors.ink, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            MiniTable(
              table: table,
              position: position,
              width: 76,
              railWidth: 2.5,
              ballDiameter: 8,
              borderRadius: 3,
            ),
            const SizedBox(width: 10),
            // The face is decoration here; the sheet is where it's set.
            IgnorePointer(
              child: EnglishPicker(
                english: english,
                onChanged: (_) {},
                size: 34,
                enabled: false,
                showLabel: false,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    table.hasGeometry
                        ? '${table.label} · ${position.label} · '
                            '${distanceInches.toStringAsFixed(1)}"'
                        : '${table.label} · '
                            '${distanceInches.toStringAsFixed(1)}"',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                      color: BreakLabColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${english.label} · tap to change the ball or the english',
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.3,
                      color: BreakLabColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 20, color: BreakLabColors.inkFaint),
          ],
        ),
      ),
    );
  }
}
