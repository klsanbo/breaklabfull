import 'package:flutter/material.dart';

import '../../engine/engine_contract.dart';
import '../../models/break_result.dart';
import '../../models/table_size.dart';
import 'measure_controller.dart';

/// Main screen: pick table size, record a break, see MPH big.
class MeasureScreen extends StatelessWidget {
  const MeasureScreen({super.key, required this.controller});

  final MeasureController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        return Scaffold(
          appBar: AppBar(title: const Text('BreakLab')),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _TableSizePicker(controller: c),
                  const Spacer(),
                  _SpeedDisplay(
                      lastBreak: c.lastBreak,
                      phase: c.phase,
                      heardBreak: c.heardBreak),
                  if (c.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(c.errorMessage!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ),
                  const Spacer(),
                  _RecordControls(controller: c),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TableSizePicker extends StatelessWidget {
  const _TableSizePicker({required this.controller});

  final MeasureController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TABLE', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            for (final size in TableSize.values)
              ChoiceChip(
                label: Text(size == TableSize.custom
                    ? 'Custom'
                    : size.label.split(' ').first),
                selected: controller.tableSize == size,
                onSelected: (_) => controller.setTableSize(size),
              ),
          ],
        ),
        if (controller.tableSize == TableSize.custom)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextFormField(
              initialValue: controller.customDistanceInches.toString(),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Cue ball travel distance (inches)',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                final parsed = double.tryParse(v);
                if (parsed != null && parsed > 0) {
                  controller.setCustomDistance(parsed);
                }
              },
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${controller.activeDistanceInches}" cue ball travel',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _SpeedDisplay extends StatelessWidget {
  const _SpeedDisplay(
      {required this.lastBreak,
      required this.phase,
      this.heardBreak = false});

  final BreakResult? lastBreak;
  final MeasurePhase phase;
  final bool heardBreak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (phase == MeasurePhase.recording) {
      return Column(children: [
        Icon(heardBreak ? Icons.graphic_eq : Icons.mic,
            size: 48, color: theme.colorScheme.primary),
        const SizedBox(height: 8),
        Text(heardBreak ? 'Got it…' : 'Listening — break when ready',
            style: theme.textTheme.titleMedium),
      ]);
    }
    if (phase == MeasurePhase.processing) {
      return const Column(children: [
        SizedBox(
            width: 48, height: 48, child: CircularProgressIndicator()),
        SizedBox(height: 8),
        Text('Measuring…'),
      ]);
    }
    final b = lastBreak;
    if (b == null) {
      return Text('Record your first break',
          style: theme.textTheme.titleMedium);
    }
    if (!b.hasSpeed) {
      return Column(children: [
        Text('—', style: theme.textTheme.displayLarge),
        const SizedBox(height: 4),
        Text("Couldn't read that break — try again",
            style: theme.textTheme.titleSmall),
      ]);
    }
    return Column(children: [
      Text(
        b.speedMph!.toStringAsFixed(1),
        style: theme.textTheme.displayLarge
            ?.copyWith(fontSize: 96, fontWeight: FontWeight.w800),
      ),
      Text('MPH', style: theme.textTheme.titleMedium),
      const SizedBox(height: 6),
      _GradeChip(grade: b.grade),
    ]);
  }
}

class _GradeChip extends StatelessWidget {
  const _GradeChip({required this.grade});

  final AccuracyGrade grade;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (grade) {
      AccuracyGrade.excellent => (const Color(0xFFEAF3DE), const Color(0xFF3B6D11)),
      AccuracyGrade.target => (const Color(0xFFE6F1FB), const Color(0xFF185FA5)),
      AccuracyGrade.fallback => (const Color(0xFFFAEEDA), const Color(0xFF854F0B)),
      AccuracyGrade.unreliable => (const Color(0xFFFCEBEB), const Color(0xFFA32D2D)),
    };
    return Chip(
      label: Text(grade.label,
          style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
      backgroundColor: bg,
      side: BorderSide.none,
    );
  }
}

class _RecordControls extends StatelessWidget {
  const _RecordControls({required this.controller});

  final MeasureController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return switch (c.phase) {
      MeasurePhase.idle => FilledButton.icon(
          style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(64)),
          onPressed: c.startBreak,
          icon: const Icon(Icons.fiber_manual_record),
          label: const Text('BREAK'),
        ),
      MeasurePhase.recording => Column(children: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(64)),
            onPressed: c.cancelBreak,
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: c.measureNow,
            child: const Text('Measure now'),
          ),
        ]),
      MeasurePhase.processing => const FilledButton(
          onPressed: null,
          child: Text('Measuring…'),
        ),
    };
  }
}
