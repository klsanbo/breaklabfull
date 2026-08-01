import 'package:flutter/material.dart';

import '../../../models/break_outcome.dart';
import '../../../theme/breaklab_theme.dart';

/// The optional two-second card that follows a result.
///
/// Everything the microphone cannot hear lives here. Skip is always present
/// and never costs the player anything: a skipped break still counts for
/// speed, consistency and reliability — it simply has no Break Score.
class OutcomeCard extends StatefulWidget {
  const OutcomeCard({
    super.key,
    required this.onSaved,
    required this.onSkipped,
    this.initial,
  });

  final ValueChanged<BreakOutcome> onSaved;
  final VoidCallback onSkipped;

  /// The previous break's answers, so the common case is one tap or none.
  final BreakOutcome? initial;

  @override
  State<OutcomeCard> createState() => _OutcomeCardState();
}

class _OutcomeCardState extends State<OutcomeCard> {
  late int _balls = widget.initial?.ballsMade ?? 1;
  late bool _scratched = widget.initial?.scratched ?? false;
  late SpreadQuality _spread = widget.initial?.spread ?? SpreadQuality.good;
  late CueBallAfter _after =
      widget.initial?.cueBallAfter ?? CueBallAfter.stayedCenter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BreakLabColors.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 26,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                "How'd it go?",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              SizedBox(width: 6),
              Text(
                '(optional)',
                style: TextStyle(fontSize: 11, color: BreakLabColors.inkFaint),
              ),
            ],
          ),
          const _Label('Balls made'),
          Row(
            children: [
              for (var i = 0; i <= 4; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _BallChip(
                    label: i == 4 ? '4+' : '$i',
                    selected: _balls == i,
                    onTap: () => setState(() => _balls = i),
                  ),
                ),
            ],
          ),
          const _Label('Scratch?'),
          _Toggle(
            options: const ['No', 'Scratched'],
            selectedIndex: _scratched ? 1 : 0,
            dangerIndex: 1,
            onSelected: (i) => setState(() => _scratched = i == 1),
          ),
          const _Label('Spread'),
          _Toggle(
            options: SpreadQuality.values.map((s) => s.label).toList(),
            selectedIndex: SpreadQuality.values.indexOf(_spread),
            onSelected: (i) =>
                setState(() => _spread = SpreadQuality.values[i]),
          ),
          const _Label('Cue ball after the break'),
          _Toggle(
            options: CueBallAfter.values.map((c) => c.label).toList(),
            selectedIndex: CueBallAfter.values.indexOf(_after),
            onSelected: (i) => setState(() => _after = CueBallAfter.values[i]),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: widget.onSkipped,
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    color: BreakLabColors.inkFaint,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: BreakLabColors.labGreenDark,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                ),
                onPressed: () => widget.onSaved(
                  BreakOutcome(
                    ballsMade: _balls,
                    scratched: _scratched,
                    spread: _spread,
                    cueBallAfter: _after,
                  ),
                ),
                child: const Text(
                  'Save outcome',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 5),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
        color: BreakLabColors.inkFaint,
      ),
    ),
  );
}

class _BallChip extends StatelessWidget {
  const _BallChip({
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
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? BreakLabColors.labGreenDark : Colors.white,
          border: Border.all(
            color: selected
                ? BreakLabColors.labGreenDark
                : BreakLabColors.hairline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : BreakLabColors.inkSoft,
          ),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
    this.dangerIndex,
  });

  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// An option that should read as a bad outcome when chosen (a scratch).
  final int? dangerIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              onTap: () => onSelected(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: _bg(i),
                  border: Border.all(color: _border(i)),
                ),
                child: Text(
                  options[i],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selectedIndex == i
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: _fg(i),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  bool _isDanger(int i) => selectedIndex == i && dangerIndex == i;

  Color _bg(int i) {
    if (_isDanger(i)) return const Color(0xFFFCEBEB);
    if (selectedIndex == i) return const Color(0xFFDFF0E4);
    return Colors.white;
  }

  Color _border(int i) {
    if (_isDanger(i)) return const Color(0xFFE0A3A3);
    if (selectedIndex == i) return const Color(0xFF9CCBA9);
    return BreakLabColors.hairline;
  }

  Color _fg(int i) {
    if (_isDanger(i)) return const Color(0xFFA32D2D);
    if (selectedIndex == i) return BreakLabColors.labGreenDark;
    return BreakLabColors.inkSoft;
  }
}
