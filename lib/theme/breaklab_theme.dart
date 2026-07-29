import 'package:flutter/material.dart';

import '../engine/engine_contract.dart';

/// BreakLab's colours, in one place.
///
/// Blue belongs to the action — the BREAK button and nothing else, so a
/// player's eye always knows where to go. Green carries identity: grades,
/// records, The Lab. Felt green is reserved for table drawings.
class BreakLabColors {
  const BreakLabColors._();

  static const breakBlue = Color(0xFF1E6FD9);
  static const breakBlueLight = Color(0xFF3E8EE8);
  static const breakBlueDark = Color(0xFF124F9E);

  static const labGreen = Color(0xFF1A7F37);
  static const labGreenDark = Color(0xFF14632B);
  static const labGreenDeep = Color(0xFF123B22);

  static const felt = Color(0xFF1F8A5B);
  static const feltDark = Color(0xFF1A7A50);
  static const rail = Color(0xFF6B4A2B);
  static const diamond = Color(0xFFE8DFC8);

  static const surface = Color(0xFFFAFAF7);
  static const ink = Color(0xFF1A1A18);
  static const inkSoft = Color(0xFF5F5E5A);
  static const inkFaint = Color(0xFF8A8880);
  static const hairline = Color(0x1F000000);

  /// Grade pill colours — background then foreground.
  static (Color, Color) forGrade(AccuracyGrade grade) => switch (grade) {
        AccuracyGrade.excellent => (
            const Color(0xFFEAF3DE),
            const Color(0xFF3B6D11)
          ),
        AccuracyGrade.target => (
            const Color(0xFFE6F1FB),
            const Color(0xFF185FA5)
          ),
        AccuracyGrade.fallback => (
            const Color(0xFFFAEEDA),
            const Color(0xFF854F0B)
          ),
        AccuracyGrade.unreliable => (
            const Color(0xFFFCEBEB),
            const Color(0xFFA32D2D)
          ),
      };
}

ThemeData breakLabTheme() {
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: BreakLabColors.labGreen,
      surface: BreakLabColors.surface,
    ),
    useMaterial3: true,
  );
  return base.copyWith(
    scaffoldBackgroundColor: BreakLabColors.surface,
    appBarTheme: const AppBarTheme(
      backgroundColor: BreakLabColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
  );
}
