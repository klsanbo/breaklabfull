import 'package:flutter/material.dart';

import '../../models/entitlement.dart';
import '../../theme/breaklab_theme.dart';
import 'widgets/onboarding_chrome.dart';

/// BL-002 — the first thing anyone sees, once.
///
/// It asks for nothing. No account, no email, and no permission prompt on
/// arrival: the microphone is requested when the player first taps BREAK,
/// after they have read why it is needed. "An app that listens" is the single
/// biggest reason someone backs out of an install, so the mic gets its own
/// paragraph in plain words rather than a line of fine print.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'BREAK LAB',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'PRACTICE. MEASURE. IMPROVE.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                  color: BreakLabColors.inkSoft,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Your phone can hear how fast you break.\n'
                'No radar gun, no attachments.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: BreakLabColors.ink,
                ),
              ),
              const SizedBox(height: 20),
              const _Step(
                number: '1',
                title: 'SET THE TABLE UP ONCE',
                body:
                    'Table size, and where on the cloth you break from. Drag '
                    'the ball to your spot — the reading depends on it.',
              ),
              const _Step(
                number: '2',
                title: 'PUT THE PHONE ON THE RAIL',
                body:
                    'We show you exactly where. It listens for the tip '
                    'hitting the cue ball, then the cue ball hitting the rack.',
              ),
              const _Step(
                number: '3',
                title: 'BREAK',
                body:
                    'The gap between those two sounds, over the distance you '
                    'set, is your speed.',
                last: true,
              ),
              const SizedBox(height: 16),
              const NoteCard(
                title: 'ABOUT THE MICROPHONE',
                body:
                    'BreakLab needs the mic to hear the break, and asks for '
                    'it the first time you tap BREAK. Recordings stay on this '
                    'phone, are never uploaded, and there is no account to '
                    'sign into.',
              ),
              const SizedBox(height: 18),
              PrimaryButton(label: 'GET STARTED', onPressed: onContinue),
              const SizedBox(height: 12),
              const FinePrint(
                'Free for 7 days from your first break, then '
                '${Entitlement.priceLabel} once. No subscription, no card up '
                'front, nothing to cancel.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.body,
    this.last = false,
  });

  final String number;
  final String title;
  final String body;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: last
          ? null
          : const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: BreakLabColors.hairline),
              ),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: BreakLabColors.breakBlue,
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.45,
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
