import 'package:flutter/material.dart';

import '../../models/break_outcome.dart';
import '../../models/break_result.dart';
import '../../models/speed_band.dart';
import '../../scoring/break_score.dart';
import '../../theme/breaklab_theme.dart';
import '../break_map/break_map_screen.dart';
import '../measure/break_setup_screen.dart';
import '../measure/measure_controller.dart';
import '../measure/phone_placement_screen.dart';
import '../measure/widgets/break_button.dart';
import '../measure/widgets/outcome_card.dart';
import '../measure/widgets/reading_review_sheet.dart';
import '../measure/widgets/unreadable_break_card.dart';
import '../upgrade/upgrade_screen.dart';
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
  const HomeScreen({
    super.key,
    required this.controller,
    this.openSetupOnStart = false,
  });

  final MeasureController controller;

  /// Straight into setup on arrival. True exactly once, coming off the
  /// welcome flow — the last thing that screen promises is that they set the
  /// table up, so landing on home and making them find the strip would be a
  /// small broken promise on the first screen they ever see.
  final bool openSetupOnStart;

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.openSetupOnStart && mounted) {
        await _editSetup();
      }
      await c.refreshStats();
    });
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
    // The gate lives here and in the controller. Home opens the upgrade
    // screen so the player is told why nothing happened; the controller
    // refuses regardless, so no other route into the recorder can slip past.
    if (!c.canMeasure) return _openUpgrade();
    setState(() {
      _showing = null;
      _outcomeDone = false;
    });
    await c.startBreak();
  }

  Future<void> _openUpgrade() async {
    await openUpgrade(context, c);
    if (mounted) setState(() {});
  }

  /// From the reading review sheet: close it, then open the one setup screen.
  /// The distance is the only number a player sets by hand, so it is the only
  /// thing they can act on when a reading looks wrong.
  Future<void> _fixSetupFromSheet() async {
    Navigator.of(context).pop();
    await _editSetup();
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
      case NavDestination.breakMap:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BreakMapScreen(controller: c, onBreak: _break),
          ),
        );
        return;
      case NavDestination.sessions:
        _open(
          'Sessions',
          'Every night at the table, with its own averages, best break and Break Score, and every break inside it.',
        );
        return;
      case NavDestination.trends:
        _open(
          'Trends',
          'Whether speed, control and consistency are moving the right way across your last twenty sessions.',
        );
        return;
      case NavDestination.records:
        _open(
          'Records',
          'Fastest break, highest Break Score, best session average, and the milestones you are closing in on.',
        );
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = c.phase == MeasurePhase.idle ? _showing : null;
    final idle = c.phase == MeasurePhase.idle;
    final locked = !c.canMeasure;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HomeHeader(
                onSettings: () => _open(
                  'Settings',
                  'Units, sensitivity, and what BreakLab keeps on your phone. Nothing leaves the device.',
                ),
              ),
              const SizedBox(height: 14),
              if (result == null) ...[
                Center(
                  child: BreakButton(
                    diameter: 216,
                    listening: c.phase == MeasurePhase.recording,
                    heard: c.heardBreak,
                    locked: locked,
                    subtitle: locked
                        ? 'TAP TO UNLOCK'
                        : idle
                            ? 'TAP TO START'
                            : null,
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
                  UnreadableBreakCard.forBreak(
                    result,
                    onCheckPlacement: () => openPhonePlacement(context),
                  ),
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
    if (!c.canMeasure) {
      // A locked button with no way out is an uninstall. There is always a
      // second door to the upgrade screen on this row.
      return StatusPill(
        label: 'TRIAL ENDED',
        icon: Icons.lock_outline,
        onTap: _openUpgrade,
      );
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
          // The grade is the door to BL-010. Tapping it says how the reading
          // was made; most players never will, and that is the point.
          onTap: () => showReadingReview(
            context,
            result,
            onFixSetup: _fixSetupFromSheet,
          ),
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
        caption: fastest == null
            ? null
            : SpeedBand.forMph(fastest).label.toUpperCase(),
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
