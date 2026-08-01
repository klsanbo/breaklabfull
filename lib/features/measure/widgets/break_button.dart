import 'package:flutter/material.dart';

import '../../../theme/breaklab_theme.dart';

/// The star of the app: one big blue circle.
///
/// Idle it invites the tap. Listening, a ring breathes around it so you can
/// tell from across the table that the phone is armed. It never changes
/// colour to mean something else — blue is the action and only the action.
class BreakButton extends StatefulWidget {
  const BreakButton({
    super.key,
    required this.onPressed,
    this.listening = false,
    this.heard = false,
    this.locked = false,
    this.diameter = 224,
    this.subtitle,
  });

  final VoidCallback? onPressed;

  /// Armed and waiting for the break.
  final bool listening;

  /// The break was heard; the tail is still recording.
  final bool heard;

  /// The trial is over and nothing was bought. The button greys out and wears
  /// a lock; tapping it opens the upgrade screen rather than doing nothing.
  /// A dead control with no explanation is how a player decides the app is
  /// broken instead of deciding to buy it.
  final bool locked;

  final double diameter;

  /// A small line under BREAK, e.g. "TAP TO START". An instruction, never a
  /// status — the pill owns status and the button must not echo it.
  final String? subtitle;

  @override
  State<BreakButton> createState() => _BreakButtonState();
}

class _BreakButtonState extends State<BreakButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.listening) _pulse.repeat();
  }

  @override
  void didUpdateWidget(BreakButton old) {
    super.didUpdateWidget(old);
    if (widget.listening && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!widget.listening && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The button says one word, always. State lives in the pill below it,
    // so the two never say the same thing twice.
    final ringSize = widget.diameter + 42;

    return SizedBox(
      width: ringSize,
      height: ringSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final t = _pulse.value;
              final scale = widget.listening ? 0.86 + t * 0.14 : 1.0;
              final opacity = widget.listening ? (1 - t) * 0.55 : 0.35;
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: ringSize,
                  height: ringSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: BreakLabColors.breakBlue
                          .withValues(alpha: opacity.clamp(0.0, 1.0)),
                      width: 1.5,
                    ),
                  ),
                ),
              );
            },
          ),
          Semantics(
            button: true,
            label: widget.locked
                ? 'Break — locked, tap to unlock BreakLab'
                : widget.listening
                    ? 'Listening for your break'
                    : 'Break — start measuring',
            child: GestureDetector(
              onTap: widget.onPressed,
              child: Container(
                width: widget.diameter,
                height: widget.diameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.35, -0.45),
                    radius: 1.0,
                    colors: widget.locked
                        ? const [
                            Color(0xFFB9B7B0),
                            Color(0xFF9C9A93),
                            Color(0xFF7E7C76),
                          ]
                        : const [
                            BreakLabColors.breakBlueLight,
                            BreakLabColors.breakBlue,
                            BreakLabColors.breakBlueDark,
                          ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (widget.locked
                              ? BreakLabColors.ink
                              : BreakLabColors.breakBlueDark)
                          .withValues(alpha: widget.locked ? 0.22 : 0.45),
                      blurRadius: 40,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.locked) ...[
                          Icon(
                            Icons.lock_outline,
                            color: Colors.white,
                            size: widget.diameter * 0.14,
                          ),
                          SizedBox(height: widget.diameter * 0.02),
                        ],
                        Text(
                          'BREAK',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: widget.diameter * 0.21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                        if (widget.subtitle != null) ...[
                          SizedBox(height: widget.diameter * 0.035),
                          Text(
                            widget.subtitle!,
                            style: TextStyle(
                              color: const Color(0xFFCFE3FA),
                              fontSize: widget.diameter * 0.058,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.6,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
