import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/models/agent.dart';
import '../api/models/consent.dart';
import '../api/models/day.dart';
import '../api/models/schedule.dart';
import '../api/models/session.dart';
import '../desktop/window_controller.dart';
import '../router/routes.dart';
import '../state/account_controllers.dart';
import '../state/auth_controller.dart';
import '../state/data_providers.dart';
import '../state/session_controller.dart';
import '../theme/tokens.dart';
import '../ui/dial.dart';
import '../ui/drum_wheel.dart';
import '../ui/iso/month_terrain.dart';
import '../ui/feature_note.dart';
import '../ui/kit.dart';
import '../ui/loading_blocks.dart';
import '../ui/score/day_score.dart';
import '../widgets/common.dart' show errorText, runGuarded, showError;
import 'shell.dart' show FlowHeader;

String demandLabel(Demand d) => switch (d) {
  Demand.light => 'Light',
  Demand.moderate => 'Moderate',
  Demand.heavy => 'Heavy',
};

const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _hm(DateTime t) => '${(t.hour - 1) % 12 + 1}:${t.minute.toString().padLeft(2, '0')}';
String _dur(int m) => m >= 60 ? '${m ~/ 60} h ${(m % 60).toString().padLeft(2, '0')} min' : '$m min';
DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

/// Home (DESIGN_SPEC §6): DISPLAY (Day Score) → READ-OUT → CONTROL DECK
/// [look back: wheel + terrain] [start: presets, task, demand, dial, Start].
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late DateTime _selected = _day(DateTime.now());
  DateTime _now = DateTime.now();
  Timer? _tick;
  int? _minutes; // null until the suggestion arrives
  Demand _demand = Demand.moderate;
  bool _shareAi = false;
  bool _busy = false;
  bool _explain = false; // "How to read this" layer
  final _task = TextEditingController();

  @override
  void initState() {
    super.initState();
    // the Score moves with the clock; once every 30 s is plenty for minutes
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _task.dispose();
    super.dispose();
  }

  bool get _isToday => DateUtils.isSameDay(_selected, _now);

  Future<void> _start(int minutes) async {
    setState(() => _busy = true);
    final ok = await runGuarded(
      context,
      () => ref
          .read(liveSessionProvider.notifier)
          .start(StartSessionRequest(taskText: _task.text, demand: _demand, plannedMinutes: minutes, shareTaskWithLlm: _shareAi)),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) {
        _selected = _day(DateTime.now());
        _task.clear();
      }
    });
  }

  Future<void> _end() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('End this session?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep going')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('End session')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final summary = await ref.read(liveSessionProvider.notifier).end();
      if (mounted) context.go(Routes.sessionEndFor(summary.sessionId), extra: summary);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    final user = ref.watch(currentUserProvider);
    final day = ref.watch(dayTimelineProvider(_selected));
    final live = ref.watch(liveSessionProvider).value;
    final suggested = ref.watch(preCheckProvider).value?.suggestedMinutes;
    final minutes = _minutes ?? suggested ?? 50;
    final hour = _now.hour;
    final greet = hour < 12 ? 'Good morning' : (hour < 18 ? 'Good afternoon' : 'Good evening');
    final first = user?.name.trim().split(' ').first ?? '';

    return LayoutBuilder(
      builder: (context, viewport) {
        // Rule B: never look empty. The Score takes the room the window has.
        final scoreH = (viewport.maxHeight - 96 - 52 - 300).clamp(320.0, 420.0);
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            FlowHeader(
              title: first.isEmpty ? greet : '$greet, $first',
              subtitle: '${_weekdays[_now.weekday - 1].substring(0, 3)} ${_now.day} ${_months[_now.month - 1]}',
              action: _ExplainToggle(on: _explain, onChanged: (v) => setState(() => _explain = v)),
            ),
            const _AgentBanner(),
            const SizedBox(height: 8),
            _ExplainRow(
              on: _explain,
              notes: const [
                (
                  1,
                  'Your day, as blocks',
                  'Each session rises from the hour line. Taller = more demanding. Fresh ones start green and dry to stone.',
                ),
                (2, 'Pressure', 'How close you are to needing a break. It turns amber as it nears the dashed nudge line.'),
                (3, 'Now', 'The green line. Dashed blocks to its right are planned, not yet happened.'),
              ],
            ),
            // ── DISPLAY ─────────────────────────────────────────────────────
            switch (day) {
              AsyncData(:final value) => _Display(
                height: scoreH,
                day: value,
                now: _now,
                ghost: live == null && _isToday ? minutes : 0,
                onGhost: (m) => setState(() => _minutes = m),
                onSession: (s) => s.id == null ? null : context.go(Routes.sessionEndFor(s.id!)),
              ),
              AsyncError(:final error) => _Inline(text: errorText(error), onRetry: () => ref.invalidate(dayTimelineProvider(_selected))),
              _ => SizedBox(
                height: scoreH,
                child: Padding(
                  padding: const EdgeInsets.only(right: 24),
                  child: Center(
                    child: LoadingBlocks(height: scoreH * 0.55, count: 8, label: 'Loading your day'),
                  ),
                ),
              ),
            },
            // ── READ-OUT ───────────────────────────────────────────────────
            Padding(padding: const EdgeInsets.only(right: 24, top: 2, bottom: 14), child: ReadOut(_readout(day.value))),
            Divider(height: 1, thickness: 1, color: p.hairline, endIndent: 24),
            const SizedBox(height: 16),
            _ExplainRow(
              on: _explain,
              notes: const [
                (4, 'Look back', 'Your last four weeks as a little city. Scroll the wheel or click a day to see it above.'),
                (5, 'Start', 'Pick a length on the dial (drag it, or use the presets). The ghost block above shows where it would land.'),
              ],
            ),
            // ── CONTROL DECK ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(right: 24),
              child: LayoutBuilder(
                builder: (context, box) {
                  final lookBack = ColorField(
                    tone: FieldTone.past,
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    child: _LookBack(selected: _selected, today: _day(_now), onSelect: (d) => setState(() => _selected = _day(d))),
                  );
                  // about to start = planned (ultramarine); running = now (green)
                  final start = ColorField(
                    tone: live == null ? FieldTone.planned : FieldTone.now,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: live == null
                        ? _StartGroup(
                            minutes: minutes,
                            suggestion: suggested,
                            demand: _demand,
                            task: _task,
                            shareAi: _shareAi,
                            busy: _busy,
                            now: _now,
                            onMinutes: (m) => setState(() => _minutes = m),
                            onDemand: (d) => setState(() => _demand = d),
                            onShareAi: (v) => setState(() => _shareAi = v),
                            onStart: () => _start(minutes),
                          )
                        : _SessionGroup(live: live, onEnd: _end),
                  );
                  // below ~1100 px the two groups stack; the order stays display → read-out → deck
                  if (box.maxWidth < 860) {
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [start, const SizedBox(height: 20), lookBack]);
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 4, child: lookBack),
                      const SizedBox(width: 24),
                      Expanded(flex: 6, child: start),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  String _readout(DayTimeline? d) {
    final name = _weekdays[_selected.weekday - 1];
    final parts = <String>['$name ${_selected.day}'];
    if (d != null) {
      parts.add(_dur(d.totals.focusMinutes));
      if (_isToday) {
        final next = d.meetings.where((m) => m.start.isAfter(_now)).toList()..sort((a, b) => a.start.compareTo(b.start));
        if (next.isNotEmpty) parts.add('next meeting ${_hm(next.first.start)}');
      } else {
        parts.add('${d.totals.breaksTaken} of ${d.totals.breaksSuggested} breaks');
      }
    }
    return parts.join(' · ');
  }
}

class _Inline extends StatelessWidget {
  const _Inline({required this.text, this.onRetry});
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    return SizedBox(
      height: 300,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 16, color: p.problem),
            const SizedBox(width: 8),
            Text(text, style: TextStyle(color: p.text2)),
            if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _AgentBanner extends ConsumerWidget {
  const _AgentBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = FlowPalette.of(context);
    final a = ref.watch(agentStatusProvider);
    final consent = ref.watch(consentProvider).value;
    if (a.connection == AgentConnection.connected || consent == null || !consent.granted(ConsentScope.behavior)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(right: 24, bottom: 4),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: p.text3),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Behavior sensing isn\'t connected, so Flow can only nudge on timing for now.',
              style: TextStyle(fontSize: 12.5, color: p.text2),
            ),
          ),
          TextButton(onPressed: () => context.go(Routes.settings), child: const Text('Connect the agent')),
        ],
      ),
    );
  }
}

// ── DISPLAY: margin numbers + the Day Score ───────────────────────────────

class _Display extends StatelessWidget {
  const _Display({
    required this.height,
    required this.day,
    required this.now,
    required this.ghost,
    required this.onGhost,
    required this.onSession,
  });
  final double height;
  final DayTimeline day;
  final DateTime now;
  final int ghost;
  final ValueChanged<int> onGhost;
  final void Function(TimelineSession) onSession;

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    final t = day.totals;
    final delta = t.usualFocusMinutes == null ? null : t.focusMinutes - t.usualFocusMinutes!;
    Widget margin(String big, String label, String? sub, {Color? subColor}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TabularNumeral(big, style: FlowType.numeral(p, 28)),
        const SizedBox(height: 3),
        Text(flowCaps(label), style: FlowType.label(p, size: 9, color: p.text3)),
        if (sub != null) Text(sub, style: FlowType.chart(p, size: 10, color: subColor ?? p.text3)),
      ],
    );
    final h = height;
    return SizedBox(
      height: h,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Stack(
              children: [
                Positioned(
                  top: (h * 0.40).clamp(0, 112.0) - 52,
                  child: margin(
                    '${t.focusMinutes ~/ 60}h${(t.focusMinutes % 60).toString().padLeft(2, '0')}',
                    'focused',
                    delta == null ? null : '${delta >= 0 ? '+' : '−'}${_dur(delta.abs())} vs usual',
                  ),
                ),
                Positioned(
                  top: (h * 0.40).clamp(0, 112.0) + 76,
                  child: margin(
                    '${t.breaksTaken}/${t.breaksSuggested}',
                    'breaks',
                    t.breaksSkipped > 0 ? '${t.breaksSkipped} skipped' : null,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 24),
              child: DayScore(
                day: day,
                now: now,
                ghostMinutes: ghost,
                height: h,
                onGhostDrag: ghost > 0 ? onGhost : null,
                onSessionTap: onSession,
                // drag across the future to plan a session on this weekday
                onScheduleDraft: (a, b) => _scheduleFromDraft(context, a, b),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── DECK: look back (wheel flush with terrain) ───────────────────────────

class _LookBack extends ConsumerWidget {
  const _LookBack({required this.selected, required this.today, required this.onSelect});
  final DateTime selected;
  final DateTime today;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = FlowPalette.of(context);
    final mins = ref.watch(rollingMinutesProvider);
    final offset = selected.difference(today).inDays; // 0 = today, -27 = four weeks back
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Look back'),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            DrumWheel(
              value: offset,
              min: -27,
              max: 0,
              length: 200,
              onChanged: (d) => onSelect(today.add(Duration(days: d))),
              semanticLabel: 'Day',
              semanticValue: (d) => d == 0 ? 'today' : '${-d} days ago',
            ),
            const SizedBox(width: 6),
            Expanded(
              child: switch (mins) {
                AsyncData(:final value) => LayoutBuilder(
                  builder: (context, box) => MonthTerrain(
                    month: today,
                    minutes: value,
                    selected: selected,
                    onSelect: onSelect,
                    size: Size(box.maxWidth.clamp(220, 440), 220),
                  ),
                ),
                AsyncError() => Text('Couldn\'t load the last 4 weeks.', style: TextStyle(color: p.text3, fontSize: 12)),
                _ => const SizedBox(height: 220, child: Center(child: LoadingBlocks(height: 110, count: 5))),
              },
            ),
          ],
        ),
      ],
    );
  }
}

// ── DECK: start group ──────────────────────────────────────────────────────

class _StartGroup extends ConsumerWidget {
  const _StartGroup({
    required this.minutes,
    required this.suggestion,
    required this.demand,
    required this.task,
    required this.shareAi,
    required this.busy,
    required this.now,
    required this.onMinutes,
    required this.onDemand,
    required this.onShareAi,
    required this.onStart,
  });

  final int minutes;
  final int? suggestion;
  final Demand demand;
  final TextEditingController task;
  final bool shareAi;
  final bool busy;
  final DateTime now;
  final ValueChanged<int> onMinutes;
  final ValueChanged<Demand> onDemand;
  final ValueChanged<bool> onShareAi;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = FlowPalette.of(context);
    final llm = ref.watch(consentProvider).value?.granted(ConsentScope.llm) ?? false;
    final ends = now.add(Duration(minutes: minutes));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Start'),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, box) {
            // Too narrow for controls · dial · button side by side: the Start
            // button moves under the controls instead of being squeezed.
            final tight = box.maxWidth < 660;
            final start = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Pressable(
                  tone: PressableTone.primary,
                  onPressed: busy ? null : onStart,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  // shrinks a little before it would ever clip
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(busy ? 'Starting…' : 'Start · ends ${_hm(ends)}', maxLines: 1, softWrap: false),
                  ),
                ),
                if (suggestion != null) ...[
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '✦ $suggestion min suggested',
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(fontSize: 11, color: p.text3),
                    ),
                  ),
                ],
              ],
            );
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // controls keep a slim width so the dial sits near the middle of
                // the deck instead of being pushed to the far edge; they give way
                // first when the window narrows
                SizedBox(
                  width: (tight ? box.maxWidth - 204 - 24 : box.maxWidth - 204 - 32 - 28 - 240).clamp(160.0, 320.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final m in const [25, 50, 90])
                              Pressable(
                                selected: minutes == m,
                                onPressed: () => onMinutes(m),
                                semanticLabel: '$m minutes',
                                child: Text('$m'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FlowTextField(controller: task, hint: 'What are you working on? (optional)'),
                        const SizedBox(height: 14),
                        SnapSlider(
                          steps: 3,
                          index: demand.index,
                          width: 200,
                          labels: const ['light', 'moderate', 'heavy'],
                          semanticLabel: 'How demanding',
                          onChanged: (i) => onDemand(Demand.values[i]),
                        ),
                        if (llm) ...[
                          const SizedBox(height: 10),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PillToggle(value: shareAi, onChanged: onShareAi, semanticLabel: 'Share task with the AI assistant'),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text('Let the AI assistant see this task', style: TextStyle(fontSize: 12, color: p.text2)),
                              ),
                            ],
                          ),
                        ],
                        if (tight) ...[const SizedBox(height: 14), start],
                      ],
                    ),
                  ),
                ),
                SizedBox(width: tight ? 24 : 32),
                DurationDial(minutes: minutes, suggestion: suggestion, size: 204, onChanged: onMinutes, onCenterTap: busy ? null : onStart),
                if (!tight) ...[const SizedBox(width: 28), Flexible(flex: 3, child: start)],
                const Spacer(),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ── DECK: session group (replaces start, same width) ──────────────────────

class _SessionGroup extends ConsumerWidget {
  const _SessionGroup({required this.live, required this.onEnd});
  final LiveSession live;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = FlowPalette.of(context);
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final s = live.session;
    final elapsed = s.elapsedAt(now);
    final total = Duration(minutes: s.plannedMinutes);
    final left = total - elapsed;
    final frac = (elapsed.inSeconds / total.inSeconds).clamp(0.0, 1.0);
    final ends = s.startedAt.add(total + Duration(seconds: s.pausedSeconds));
    String mmss(Duration d) => '${d.inMinutes.abs()}:${(d.inSeconds.abs() % 60).toString().padLeft(2, '0')}';
    final notifier = ref.read(liveSessionProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Session'),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            DurationDial(
              minutes: s.plannedMinutes,
              onChanged: null,
              mode: DialMode.progress,
              fraction: frac,
              size: 196,
              centerLabel: left.isNegative ? '+${mmss(left)}' : mmss(left),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.taskText?.isNotEmpty == true ? s.taskText! : 'Focus session', style: TextStyle(fontSize: 16, color: p.text1)),
                  const SizedBox(height: 4),
                  Text('ends ${_hm(ends)} · ${demandLabel(s.demand).toLowerCase()}', style: FlowType.label(p, size: 10.5)),
                  const SizedBox(height: 4),
                  Text(switch (live.connection) {
                    LiveConnection.live => '',
                    LiveConnection.polling => 'Updating every few seconds',
                    LiveConnection.offline => 'Offline: keeping time on this computer',
                  }, style: TextStyle(fontSize: 11, color: live.connection == LiveConnection.offline ? p.problem : p.text3)),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Pressable(
                        onPressed: () => runGuarded(context, () => notifier.extend(15)),
                        tooltip: 'Extend by 15 minutes',
                        child: const Text('+15'),
                      ),
                      Pressable(
                        onPressed: () => runGuarded(context, () => s.paused ? notifier.resume() : notifier.pause()),
                        child: Text(s.paused ? 'Resume' : 'Pause'),
                      ),
                      // desktop only, and only during a session: shrink to the widget
                      if (ref.watch(desktopHostProvider).isDesktop)
                        ValueListenableBuilder(
                          valueListenable: ref.read(windowModeProvider.notifier).widgetUnavailable,
                          builder: (context, unavailable, _) => Pressable(
                            onPressed: unavailable ? null : ref.read(windowModeProvider.notifier).shrink,
                            tooltip: unavailable
                                ? "The small widget couldn't open on this computer, so Flow stays in its window"
                                : 'Pop the session out into a small always-on-top widget',
                            child: const Text('Pop out'),
                          ),
                        ),
                      Pressable(tone: PressableTone.primary, onPressed: onEnd, child: const Text('End')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Header action: "How to read this" toggles numbered captions over Home.
class _ExplainToggle extends StatelessWidget {
  const _ExplainToggle({required this.on, required this.onChanged});
  final bool on;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    return Pressable(
      selected: on,
      onPressed: () => onChanged(!on),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      semanticLabel: on ? 'Hide explanations' : 'How to read this screen',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: on ? p.onSelected : p.text2, width: 1.2),
            ),
            child: Text(
              '?',
              style: TextStyle(fontSize: 10, color: on ? p.onSelected : p.text2, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 7),
          Text(on ? 'Hide' : 'How to read this', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

/// A row of numbered captions that grows in (and out) above a section.
class _ExplainRow extends StatelessWidget {
  const _ExplainRow({required this.on, required this.notes});
  final bool on;
  final List<(int, String, String)> notes;

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: const Duration(milliseconds: 280),
    curve: Curves.easeOutCubic,
    alignment: Alignment.topLeft,
    child: !on
        ? const SizedBox(width: double.infinity)
        : Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (n, t, b) in notes)
                  Expanded(
                    child: ExplainCaption(number: n, title: t, body: b),
                  ),
              ],
            ),
          ),
  );
}

/// Turns a drag on Home's future into a schedule for that weekday, with Undo.
Future<void> _scheduleFromDraft(BuildContext context, DateTime a, DateTime b) async {
  final container = ProviderScope.containerOf(context);
  final hm = Schedule.hm;
  try {
    final saved = await container
        .read(schedulesProvider.notifier)
        .add(Schedule(name: 'Planned session', start: hm(a.hour * 60 + a.minute), end: hm(b.hour * 60 + b.minute), weekdays: [a.weekday]));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Planned ${saved.start}–${saved.end} every ${const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][a.weekday - 1]}. Edit it in Settings.',
        ),
        action: SnackBarAction(label: 'Undo', onPressed: () => container.read(schedulesProvider.notifier).remove(saved.id!)),
      ),
    );
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}
