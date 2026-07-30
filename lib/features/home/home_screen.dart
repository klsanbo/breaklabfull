import 'package:flutter/material.dart';

import '../../models/break_outcome.dart';
import '../../models/break_result.dart';
import '../../models/speed_band.dart';
import '../../scoring/break_score.dart';
import '../../theme/breaklab_theme.dart';
import '../measure/break_setup_screen.dart';
import '../measure/measure_controller.dart';
import '../measure/widgets/break_button.dart';
import '../measure/widgets/outcome_card.dart';
import 'coming_next_screen.dart';
import 'widgets/bottom_nav.dart';
import 'widgets/home_chrome.dart';
import 'widgets/recent_session_card.dart';
import 'widgets/score_card.dart';
import 'widgets/setup_strip.dart';
import 'widgets/stat_strip.dart';

/// BreakLab — the whole app's front door.
///
/// The big blue button is the star and nothing on the screen competes with it.
/// Setup is one tappable strip under it, results land in the same furniture
/// rather than on a separate screen, and everything below is what the breaks
/// added up to.
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

  /// The one door for table size, cue ball and english. A second place to
  /// change the same three things is how two versions of one screen drift.
  Future<void> _editSetup() => openBreakSetup(context, c);

  void _navigate(NavDestination destination) {
    switch (destination) {
      case NavDestination.home:
        return;
      case NavDestination.positions:
        _open('Positions',
            'Your break spots ranked by Break Score — breaks taken, average speed, scratch rate and best break for each one. A spot needs five reliable breaks before it earns a ranking.');
        return;
      case NavDestination.sessions:
        _open('Sessions',
            'Every night at the table, with its own averages, best break and Break Score, and every break inside it.');
        return;
      case NavDestination.trends:
        _open('Trends',
            'Whether speed, control and consistency are moving the right way across your last twenty sessions.');
        return;
      case NavDestination.records:
        _open('Records',
            'Fastest break, highest Break Score, best session average, and the milestones you are closing in on.');
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = c.phase == MeasurePhase.idle ? _showing : null;
    final idle = c.phase == MeasurePhase.idle;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HomeHeader(
                onSettings: () => _open('Settings',
                    'Units, sensitivity, and what BreakLab keeps on your phone. Nothing leaves the device.'),
              ),
              const SizedBox(height: 14),
              if (result == null) ...[
                Center(
                  child: BreakButton(
                    diameter: 216,
                    listening: c.phase == MeasurePhase.recording,
                    heard: c.heardBreak,
                    subtitle: idle ? 'TAP TO START' : null,
                    onPressed: idle ? _break : null,
                  ),
                ),
                const SizedBox(height: 12),
                _statusPill(),
              ] else ...[
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
              const SizedBox(height: 12),
              SetupStrip(
                table: c.tableSize,
                position: c.position,
                english: c.english,
                distanceInches: c.activeDistanceInches,
                onTap: _editSetup,
              ),
              const SizedBox(height: 10),
              StatStrip(cells: _speedCells(result)),
              const SizedBox(height: 10),
              ScoreCard(
                score: c.labScore,
                onTap: () => _navigate(NavDestination.trends),
              ),
              const SizedBox(height: 10),
              StatStrip(cells: _sessionCells()),
              const SizedBox(height: 10),
              RecentSessionCard(
                table: c.tableSize,
                position: c.position,
                stats: c.recent,
                date: c.lastSessionAt,
                onTap: () => _navigate(NavDestination.sessions),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BreakLabNav(
        current: NavDestination.home,
        onSelected: _navigate,
      ),
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

  /// The three speed cells. Right after a break they flip to that break's
  /// numbers, so the same furniture answers both "how am I doing?" and "how
  /// was that?".
  List<StatCell> _speedCells(BreakResult? result) {
    if (result != null) {
      final score = BreakScore.forBreak(result);
      return [
        StatCell(
          icon: Icons.speed,
          label: 'THIS BREAK',
          value: result.hasSpeed ? result.speedMph!.toStringAsFixed(1) : '—',
          unit: result.hasSpeed ? 'MPH' : null,
          round: true,
        ),
        StatCell(
          icon: Icons.workspace_premium_outlined,
          label: 'BREAK SCORE',
          value: score?.toString() ?? '—',
          caption: score == null ? null : result.grade.label.toUpperCase(),
          captionColor: BreakLabColors.forGrade(result.grade).$2,
        ),
        StatCell(
          icon: Icons.bar_chart,
          label: 'SESSION AVG',
          value: c.tonight?.averageMph?.toStringAsFixed(1) ?? '—',
          unit: c.tonight?.averageMph == null ? null : 'MPH',
        ),
      ];
    }

    final s = c.recent;
    final fastest = c.records?.fastestBreak?.speedMph;
    return [
      StatCell(
        icon: Icons.speed,
        label: 'SESSION BEST',
        value: s?.bestMph?.toStringAsFixed(1) ?? '—',
        unit: s?.bestMph == null ? null : 'MPH',
        round: true,
      ),
      StatCell(
        icon: Icons.workspace_premium_outlined,
        label: 'PERSONAL BEST',
        value: fastest?.toStringAsFixed(1) ?? '—',
        unit: fastest == null ? null : 'MPH',
        caption: fastest == null ? null : SpeedBand.forMph(fastest).label.toUpperCase(),
      ),
      StatCell(
        icon: Icons.bar_chart,
        label: 'SESSION AVG',
        value: s?.averageMph?.toStringAsFixed(1) ?? '—',
        unit: s?.averageMph == null ? null : 'MPH',
      ),
    ];
  }

  /// The totals under the score: the four V006 asked for.
  ///
  /// Deliberately NOT the score's own components — consistency and clean breaks
  /// are already bars two rows up, and the same number printed twice on one
  /// screen invites the reader to wonder which one is the real one.
  ///
  /// The scratch rate is a share of the breaks with an outcome recorded, not of
  /// all breaks, and it reads a dash rather than 0% until at least one card has
  /// been filled in. A rate over no data is unknown, not zero.
  List<StatCell> _sessionCells() {
    final best = c.records?.bestSessionAverageMph;
    final scratch = c.scratchRate;
    return [
      StatCell(
        showIcon: false,
        icon: Icons.calendar_today_outlined,
        label: 'SESSIONS',
        value: '${c.sessionCount}',
      ),
      StatCell(
        showIcon: false,
        icon: Icons.format_list_numbered,
        label: 'TOTAL BREAKS',
        value: '${c.breaksAllTime}',
      ),
      StatCell(
        showIcon: false,
        icon: Icons.trending_up,
        label: 'BEST SESSION',
        value: best?.toStringAsFixed(1) ?? '—',
        unit: best == null ? null : 'MPH',
      ),
      StatCell(
        showIcon: false,
        icon: Icons.error_outline,
        label: 'SCRATCH',
        value: scratch == null ? '—' : '${scratch.round()}%',
      ),
    ];
  }
}

class _RetryTip extends StatelessWidget {
  const _RetryTip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BreakLabColors.ink, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "COULDN'T READ THAT ONE",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Set the phone on the rail, close to where the cue ball starts, '
            'and break normally. A recording with no clear pair of hits is '
            'thrown away rather than turned into a number.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: BreakLabColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}
