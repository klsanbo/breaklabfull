import 'package:flutter/material.dart';

void main() => runApp(const BreakLabApp());

/// BreakLab v1 — guest-only, local-first. Screens arrive in build order:
/// measure, sessions, history, records, stats, progress, settings.
class BreakLabApp extends StatelessWidget {
  const BreakLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BreakLab',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A7F37)),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(child: Text('BreakLab — foundation build')),
      ),
    );
  }
}
