import 'package:flutter/material.dart';

import '../../theme/breaklab_theme.dart';
import '../home/widgets/setup_strip.dart';
import 'break_setup_screen.dart';
import 'measure_controller.dart';
import 'widgets/mini_table.dart';

/// TEMPORARY — patch 1 of the V006 rebuild.
///
/// This exists so the strip and the setup sheet can be dragged on a real phone
/// before home is rebuilt around them. Dragging a ball on glass either feels
/// right or it doesn't, and no rendering or widget test can answer that.
///
/// Patch 2 deletes this file and flips [kSetupSandbox] off in main.dart.
class SetupSandboxScreen extends StatelessWidget {
  const SetupSandboxScreen({super.key, required this.controller});

  final MeasureController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SETUP SANDBOX',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'This is the strip that replaces the setup line on home. '
              'Tap it.',
              style: TextStyle(fontSize: 12.5, color: BreakLabColors.inkSoft),
            ),
            const SizedBox(height: 10),
            SetupStrip(
              table: controller.tableSize,
              position: controller.position,
              english: controller.english,
              distanceInches: controller.activeDistanceInches,
              onTap: () => openBreakSetup(context, controller),
            ),
            const SizedBox(height: 26),
            const Text(
              'The same drawing at three sizes. The ball must sit in the same '
              'place on all of them.',
              style: TextStyle(fontSize: 12.5, color: BreakLabColors.inkSoft),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final w in const [32.0, 60.0, 96.0])
                  MiniTable(
                    table: controller.tableSize,
                    position: controller.position,
                    width: w,
                  ),
              ],
            ),
            const SizedBox(height: 26),
            _Values(controller: controller),
          ],
        ),
      ),
    );
  }
}

/// The raw numbers, so a wrong-looking drawing can be told apart from a wrong
/// stored value.
class _Values extends StatelessWidget {
  const _Values({required this.controller});

  final MeasureController controller;

  @override
  Widget build(BuildContext context) {
    final p = controller.position;
    final e = controller.english;
    final rows = <(String, String)>[
      ('Table', controller.tableSize.label),
      ('Position', 'x ${p.x.toStringAsFixed(3)} · y ${p.y.toStringAsFixed(3)}'),
      ('Reads as', p.label),
      ('Distance', '${controller.activeDistanceInches.toStringAsFixed(2)}"'),
      ('English', 'x ${e.x.toStringAsFixed(2)} · y ${e.y.toStringAsFixed(2)}'),
      ('Reads as', e.label),
      ('Miscue', e.beyondMiscueLimit ? 'past the limit' : 'inside the limit'),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BreakLabColors.hairline),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 76,
                    child: Text(
                      label.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 9.5,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w700,
                        color: BreakLabColors.inkFaint,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: BreakLabColors.ink,
                      ),
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
