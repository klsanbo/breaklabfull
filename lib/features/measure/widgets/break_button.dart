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
    this.diameter = 224,
  });

  final VoidCallback? onPressed;

  /// Armed and waiting for the break.
  final bool listening;

  /// The break was heard; the tail is still recording.
  final bool heard;

  final double diameter;

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
    final label = widget.heard
        ? 'GOT IT'
        : widget.listening
            ? 'LISTENING'
            : 'BREAK';
    final sub = widget.heard
        ? 'MEASURING THE BREAK'
        : widget.listening
            ? 'BREAK WHEN READY'
            : 'TAP ONCE · THEN JUST BREAK';

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
            label: widget.listening
                ? 'Listening for your break'
                : 'Break — start measuring',
            child: GestureDetector(
              onTap: widget.onPressed,
              child: Container(
                width: widget.diameter,
                height: widget.diameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    center: Alignment(-0.35, -0.45),
                    radius: 1.0,
                    colors: [
                      BreakLabColors.breakBlueLight,
                      BreakLabColors.breakBlue,
                      BreakLabColors.breakBlueDark,
                    ],
                    stops: [0.0, 0.45, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          BreakLabColors.breakBlueDark.withValues(alpha: 0.45),
                      blurRadius: 40,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFBBD8F7),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
