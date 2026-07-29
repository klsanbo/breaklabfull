import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/break_outcome.dart';
import '../../models/break_result.dart';
import '../../models/table_size.dart';
import '../../scoring/break_score.dart';
import '../../theme/breaklab_theme.dart';
import '../measure/measure_controller.dart';
import '../measure/widgets/english_picker.dart';
import '../measure/widgets/outcome_card.dart';
import '../measure/widgets/table_position_picker.dart';
import 'coming_next_screen.dart';
import 'widgets/home_chrome.dart';
import 'widgets/orbital_break.dart';
import 'widgets/stat_strip.dart';

/// Break Lab — the whole app's front door.
///
/// Setup lives in two chips beside the button so nothing competes with it;
/// results land in the same furniture rather than on a separate screen, so a
/// player never leaves home during a session.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});

  final MeasureController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  BreakResult? _showing;
  BreakOutcome? _lastOutcome;
  bool _outcomeDone = false;

  MeasureController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => c.refreshStats());
  }

  @override
  void dispose() {
    c.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    final latest = c.lastBreak;
    setState(() {
      if (latest == null) {
        _showing = null;
      } else if (latest.id != _showing?.id) {
        _showing = latest;
        _outcomeDone = false;
      } else {
        _showing = latest;
      }
    });
  }

  Future<void> _break() async {
    setState(() {
      _showing = null;
      _outcomeDone = false;
    });
    await c.startBreak();
  }

  void _open(String title, String blurb) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ComingNextScreen(title: title, blurb: blurb),
        ),
      );

  Future<void> _editPosition() async {
    if (!c.tableSize.hasGeometry) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: BreakLabColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SheetTitle('Where do you break from?'),
              Wrap(
                spacing: 6,
                children: [
                  for (final size in TableSize.values)
                    ChoiceChip(
                      label: Text(size == TableSize.custom
                          ? 'Custom'
                          : size.label.split(' ').first),
                      selected: c.tableSize == size,
                      onSelected: (_) {
                        c.setTableSize(size);
                        setSheet(() {});
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TablePositionPicker(
                table: c.tableSize,
                position: c.position,
                onChanged: (p) {
                  c.setPosition(p);
                  setSheet(() {});
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: BreakLabColors.labGreenDark,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editEnglish() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: BreakLabColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SheetTitle('Where are you hitting it?'),
              const Text(
                'Recorded with every break so the lab can tell you which '
                'english actually works for you. It never affects your score.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12.5, color: BreakLabColors.inkSoft, height: 1.4),
              ),
              const SizedBox(height: 16),
              Center(
                child: EnglishPicker(
                  english: c.english,
                  size: 150,
                  onChanged: (e) {
                    c.setEnglish(e);
                    setSheet(() {});
                  },
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: BreakLabColors.labGreenDark,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = c.phase == MeasurePhase.idle ? _showing : null;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Masthead(),
              const SizedBox(height: 10),
              const Text(
                'Break Lab',
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: -1.4,
                ),
              ),
              const SizedBox(height: 9),
              const _Tagline(),
              const SizedBox(height: 6),
              _StatusLine(controller: c),
              const SizedBox(height: 14),
              StatStrip(cells: _cells(result)),
              if (result == null) ...[
                const SizedBox(height: 4),
                OrbitalBreak(
                  listening: c.phase == MeasurePhase.recording,
                  heard: c.heardBreak,
                  onBreak: c.phase == MeasurePhase.idle ? _break : null,
                  left: SetupChip(
                    caption: 'TABLE\n& SPOT',
                    value: c.tableSize.hasGeometry
                        ? '${c.tableSize.label.split(' ').first} · '
                            '${c.activeDistanceInches.toStringAsFixed(1)}"'
                        : 'Custom',
                    enabled: c.phase == MeasurePhase.idle,
                    onTap: _editPosition,
                    child: MiniTable(x: c.position.x, y: c.position.y),
                  ),
                  right: SetupChip(
                    caption: 'ENGLISH',
                    value: c.english.label,
                    enabled: c.phase == MeasurePhase.idle,
                    onTap: _editEnglish,
                    child: MiniBallFace(x: c.english.x, y: c.english.y),
                  ),
                ),
                const SizedBox(height: 2),
                _statusPill(),
              ] else ...[
                const SizedBox(height: 14),
                if (result.hasSpeed && !_outcomeDone)
                  OutcomeCard(
                    initial: _lastOutcome,
                    onSaved: (o) async {
                      await c.attachOutcome(o);
                      setState(() {
                        _lastOutcome = o;
                        _outcomeDone = true;
                      });
                    },
                    onSkipped: () => setState(() => _outcomeDone = true),
                  )
                else if (!result.hasSpeed)
                  const _RetryTip(),
                const SizedBox(height: 14),
                StatusPill(
                  label: result.hasSpeed ? 'BREAK AGAIN' : 'TRY AGAIN',
                  icon: Icons.fiber_manual_record,
                  filled: true,
                  onTap: _break,
                ),
              ],
              if (c.errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  c.errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TileRow(tiles: _tiles()),
              const SizedBox(height: 12),
              const LabBanner(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _BottomBar(onOpen: _open),
    );
  }

  Widget _statusPill() {
    if (c.phase == MeasurePhase.recording) {
      return StatusPill(
        label: c.heardBreak ? 'GOT IT' : 'LISTENING',
        icon: c.heardBreak ? Icons.graphic_eq : Icons.mic,
      );
    }
    if (c.phase == MeasurePhase.processing) {
      return const StatusPill(label: 'MEASURING', icon: Icons.timelapse);
    }
    return const StatusPill(label: 'READY');
  }

  List<StatCell> _cells(BreakResult? result) {
    if (result != null) {
      final score = BreakScore.forBreak(result);
      final avg = c.tonight?.averageMph;
      return [
        StatCell(
          icon: Icons.speed,
          label: 'This break',
          value: result.hasSpeed ? result.speedMph!.toStringAsFixed(1) : '—',
          unit: result.hasSpeed ? 'MPH' : null,
          round: true,
        ),
        StatCell(
          icon: Icons.workspace_premium_outlined,
          label: 'Break Score',
          value: score?.toString() ?? '—',
          caption: score == null ? null : result.grade.label.toUpperCase(),
          captionColor: BreakLabColors.forGrade(result.grade).$2,
        ),
        StatCell(
          icon: Icons.bar_chart,
          label: 'Tonight',
          value: avg == null ? '—' : avg.toStringAsFixed(1),
          unit: avg == null ? null : 'avg',
        ),
      ];
    }

    final s = c.labScore;
    final last = c.lastSessionAt;
    return [
      StatCell(
        icon: Icons.adjust,
        label: 'BreakLab Score',
        value: s?.score?.toString() ?? '—',
        caption: s == null || !s.isReady ? null : s.grade.toUpperCase(),
        round: true,
      ),
      StatCell(
        icon: Icons.calendar_today_outlined,
        label: 'Last session',
        value: last == null ? '—' : DateFormat('MMM d').format(last),
      ),
      StatCell(
        icon: Icons.bar_chart,
        label: '',
        value: '${c.sessionCount}',
        unit: c.sessionCount == 1 ? 'session' : 'sessions',
      ),
    ];
  }

  List<HomeTile> _tiles() => [
        HomeTile(
          icon: Icons.access_time,
          name: 'Sessions',
          description: 'Review &\nanalyze',
          onTap: () => _open('Sessions',
              'Every night at the table, with its own averages, best break and Break Score.'),
        ),
        HomeTile(
          icon: Icons.list,
          name: 'History',
          description: 'Every\nbreak',
          onTap: () => _open('History',
              'Every break you have ever measured, newest first, filterable by table and grade.'),
        ),
        HomeTile(
          icon: Icons.emoji_events_outlined,
          name: 'Records',
          description: 'Personal\nbests',
          onTap: () => _open('Records',
              'Fastest break, highest Break Score, best session average, and the milestones you are closing in on.'),
        ),
        HomeTile(
          icon: Icons.trending_up,
          name: 'Score',
          description: 'Form &\ntrends',
          onTap: () => _open('BreakLab Score',
              'Your current form across the last 20 sessions, and whether speed, control and consistency are moving the right way.'),
        ),
        HomeTile(
          icon: Icons.blur_on,
          name: 'Break Map',
          description: 'Coming\nin v2',
          locked: true,
          onTap: () => _open('Break Map',
              'Where you break from, and where it works. Every break already records its start position, so this arrives with real data behind it.'),
        ),
      ];
}

class _Masthead extends StatelessWidget {
  const _Masthead();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 29,
          decoration: BoxDecoration(
            border: Border.all(color: BreakLabColors.ink, width: 1.5),
            borderRadius: BorderRadius.circular(2),
          ),
          child: CustomPaint(painter: _CrossPainter()),
        ),
        const SizedBox(width: 11),
        const Text(
          'BREAKLAB',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const Spacer(),
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: BreakLabColors.ink, width: 1.5),
          ),
          child: const Icon(Icons.settings_outlined, size: 19),
        ),
      ],
    );
  }
}

class _CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = BreakLabColors.ink
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset.zero, Offset(size.width, size.height), p);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, 0), p);
  }

  @override
  bool shouldRepaint(covariant _CrossPainter oldDelegate) => false;
}

class _Tagline extends StatelessWidget {
  const _Tagline();

  @override
  Widget build(BuildContext context) => const Row(
        children: [
          Text('///',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                letterSpacing: -2,
              )),
          SizedBox(width: 9),
          Text('TRAIN YOUR BREAK',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic,
                letterSpacing: 1.2,
              )),
        ],
      );
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.controller});

  final MeasureController controller;

  @override
  Widget build(BuildContext context) {
    final tonight = controller.tonight;
    final text = tonight == null || tonight.breakCount == 0
        ? 'Session ready.'
        : 'This session · ${tonight.breakCount} '
            '${tonight.breakCount == 1 ? 'break' : 'breaks'}.';
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: const BoxDecoration(
            color: BreakLabColors.ink,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(fontSize: 13.5, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }
}

class _RetryTip extends StatelessWidget {
  const _RetryTip();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFAEEDA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          "Couldn't read that break. Set the phone on the rail near the head "
          'string, screen up — music and chatter are the usual culprits.',
          style: TextStyle(fontSize: 12.5, color: Color(0xFF854F0B)),
        ),
      );
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.onOpen});

  final void Function(String, String) onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: BreakLabColors.hairline, width: 1.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _NavItem(
                icon: Icons.access_time,
                label: 'Sessions',
                onTap: () => onOpen('Sessions', 'Every night at the table.'),
              ),
              _NavItem(
                icon: Icons.list,
                label: 'History',
                onTap: () =>
                    onOpen('History', 'Every break you have measured.'),
              ),
              const _HomeNavItem(),
              _NavItem(
                icon: Icons.emoji_events_outlined,
                label: 'Records',
                onTap: () =>
                    onOpen('Records', 'Personal bests and milestones.'),
              ),
              _NavItem(
                icon: Icons.trending_up,
                label: 'Score',
                onTap: () =>
                    onOpen('BreakLab Score', 'Your current form and trends.'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 21, color: BreakLabColors.ink),
              const SizedBox(height: 3),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: BreakLabColors.inkSoft)),
            ],
          ),
        ),
      );
}

class _HomeNavItem extends StatelessWidget {
  const _HomeNavItem();

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.translate(
              offset: const Offset(0, -16),
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: BreakLabColors.ink, width: 1.5),
                ),
                child: const Icon(Icons.home_outlined, size: 22),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -12),
              child: const Text(
                'Break',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: BreakLabColors.ink,
                ),
              ),
            ),
          ],
        ),
      );
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            width: 34,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFD5D2C8),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
        ],
      );
}
