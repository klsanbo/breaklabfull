# BreakLab

Measure your pool break speed from sound. Guest-only, local-first — all data stays on the phone.

Companion repo: `breaklab` (BreakLab Tester — dials in the detection timing; its frozen engine versions are ported here).

## Dev setup
This repo carries the Dart code (`lib/`, `test/`, `pubspec.yaml`). To generate platform folders after a fresh clone:

    flutter create . --org com.breaklab --project-name breaklab --platforms android,ios
    flutter pub get
    flutter test
