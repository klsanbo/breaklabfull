import 'package:flutter/material.dart';

import '../../theme/breaklab_theme.dart';

/// A destination that is approved and specified but not built yet.
///
/// Deliberately honest rather than a fake screen: the layout is real, the
/// navigation is real, and this says plainly what is coming instead of
/// showing invented data.
class ComingNextScreen extends StatelessWidget {
  const ComingNextScreen({
    super.key,
    required this.title,
    required this.blurb,
  });

  final String title;
  final String blurb;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: BreakLabColors.ink, width: 1.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.architecture_outlined, size: 28),
              ),
              const SizedBox(height: 18),
              Text(
                blurb,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.5,
                  color: BreakLabColors.inkSoft,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Approved and specified — building next.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: BreakLabColors.inkFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
