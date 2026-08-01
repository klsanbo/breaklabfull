import 'package:flutter/material.dart';

import '../../../theme/breaklab_theme.dart';

/// How loudly a note wants to be read.
enum NoteTone {
  /// Ordinary emphasis — a boxed aside.
  plain,

  /// Quieter than the surrounding text. Explanations nobody has to read.
  soft,

  /// Something that will cost the player a reading if ignored.
  warn,

  /// Something already went wrong.
  bad,
}

/// A boxed note, used across BL-002, BL-006, BL-010, BL-021 and BL-024.
///
/// The tone carries the meaning, so a warning and an aside are told apart at a
/// glance rather than by reading them both first.
class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    this.title,
    required this.body,
    this.tone = NoteTone.plain,
  });

  final String? title;
  final String body;
  final NoteTone tone;

  static const _warnBg = Color(0xFFFAEEDA);
  static const _warnBorder = Color(0xFFE8C48A);
  static const _warnInk = Color(0xFF6E4406);
  static const _badBg = Color(0xFFFBE9E7);
  static const _badBorder = Color(0xFFE9B6B1);
  static const _badInk = Color(0xFF7A1C16);

  Color get _background => switch (tone) {
    NoteTone.warn => _warnBg,
    NoteTone.bad => _badBg,
    NoteTone.plain || NoteTone.soft => Colors.white,
  };

  Color get _border => switch (tone) {
    NoteTone.warn => _warnBorder,
    NoteTone.bad => _badBorder,
    NoteTone.plain => BreakLabColors.ink,
    NoteTone.soft => BreakLabColors.hairline,
  };

  double get _borderWidth => tone == NoteTone.soft ? 1.0 : 1.5;

  Color get _titleInk => switch (tone) {
    NoteTone.warn => _warnInk,
    NoteTone.bad => _badInk,
    NoteTone.plain || NoteTone.soft => BreakLabColors.ink,
  };

  Color get _bodyInk => switch (tone) {
    NoteTone.warn => _warnInk,
    NoteTone.bad => _badInk,
    NoteTone.plain || NoteTone.soft => BreakLabColors.inkSoft,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
      decoration: BoxDecoration(
        color: _background,
        border: Border.all(color: _border, width: _borderWidth),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: _titleInk,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            body,
            style: TextStyle(fontSize: 12, height: 1.45, color: _bodyInk),
          ),
        ],
      ),
    );
  }
}

/// Blue owns the action everywhere in BreakLab, so the one thing to do on a
/// screen is the one blue thing on it.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled
                ? BreakLabColors.breakBlue
                : BreakLabColors.breakBlue.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(13),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: BreakLabColors.breakBlueDark.withValues(
                        alpha: 0.32,
                      ),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ),
    );
  }
}

/// The second thing to do on a screen, when there is one. Outlined rather than
/// filled so it never competes with the blue.
class GhostButton extends StatelessWidget {
  const GhostButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: BreakLabColors.ink, width: 1.5),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

/// A third option that should be available without being offered — "not now",
/// "restore a purchase". Underlined text, no box.
class QuietLink extends StatelessWidget {
  const QuietLink({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          color: Colors.transparent,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: BreakLabColors.inkSoft,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ),
    );
  }
}

/// Small print under a button. Never load-bearing — anything a player must
/// know to make the decision belongs above the button, not below it.
class FinePrint extends StatelessWidget {
  const FinePrint(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 10.5,
        height: 1.5,
        color: BreakLabColors.inkFaint,
      ),
    );
  }
}
