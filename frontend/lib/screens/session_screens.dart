import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_connector.dart';
import '../api/api_error.dart';
import '../api/models/intervention.dart';
import '../api/models/day.dart';
import '../api/models/session.dart';
import '../router/routes.dart';
import '../state/break_controller.dart';
import '../state/data_providers.dart';
import '../state/session_controller.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import '../ui/blocks.dart';
import '../ui/dial.dart';
import '../ui/feature_note.dart';
import '../ui/kit.dart';
import '../widgets/common.dart';
import 'auth_layout.dart' show BlocksStage, StageState;
import 'shell.dart' show FlowHeader;
import 'home_screen.dart' show demandLabel;

// ── /session/start ─────────────────────────────────────────────────────────

class ActiveSessionScreen extends ConsumerStatefulWidget {
  const ActiveSessionScreen({super.key});
  @override
  ConsumerState<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

/// Full view of a running session (the deck's session group, enlarged):
/// the dial's ring IS the session; display → read-out → controls (rule P).
class _ActiveSessionScreenState extends ConsumerState<ActiveSessionScreen> {
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
    final live = ref.watch(liveSessionProvider);
    final now = ref.watch(clockProvider).value ?? DateTime.now();

    return AsyncSection(
      value: live,
      onRetry: () => ref.invalidate(liveSessionProvider),
      builder: (l) {
        if (l == null) {
          return ListView(
            padding: const EdgeInsets.only(right: 24, bottom: 24),
            children: [
              const FlowHeader(title: 'No session running'),
              const SizedBox(height: 40),
              const SizedBox(height: 220, child: BlocksStage(state: StageState.rest, showBrand: false)),
              const SizedBox(height: 24),
              Text('The next block is yours to start.', style: FlowType.note(p, size: 15)),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Pressable(
                  tone: PressableTone.primary,
                  onPressed: () => context.go(Routes.home),
                  child: const Text('Start one from Home'),
                ),
              ),
            ],
          );
        }
        final s = l.session;
        final elapsed = s.elapsedAt(now);
        final planned = Duration(minutes: s.plannedMinutes);
        final remaining = planned - elapsed;
        final fraction = (elapsed.inSeconds / planned.inSeconds).clamp(0.0, 1.0);
        final ctl = ref.read(liveSessionProvider.notifier);
        final today = DateTime(now.year, now.month, now.day);
        final dayTl = ref.watch(dayTimelineProvider(today)).value;
        final pressure = [
          for (final pt in dayTl?.pressure ?? const <PressurePoint>[])
            if (!pt.t.isBefore(s.startedAt) && !pt.t.isAfter(now)) pt,
        ];
        final usual = (dayTl != null && dayTl.usualDays >= 10)
            ? [
                for (final b in dayTl.usualBand)
                  if (!b.t.isBefore(s.startedAt) && !b.t.isAfter(s.startedAt.add(planned))) PressurePoint(b.t, (b.lo + b.hi) / 2),
              ]
            : const <PressurePoint>[];
        final nudges = dayTl?.nudges.where((n) => !n.at.isBefore(s.startedAt)).length ?? 0;
        final breaksTaken = dayTl?.breaks.where((b) => !b.at.isBefore(s.startedAt) && b.mark == BreakMark.taken).length ?? 0;
        Widget stat(String big, String label) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            TabularNumeral(big, style: FlowType.numeral(p, 34)),
            const SizedBox(height: 4),
            Text(flowCaps(label), style: FlowType.label(p, size: 10, color: p.text3)),
          ],
        );
        const pad = EdgeInsets.symmetric(horizontal: 16, vertical: 10);
        final controls = Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            Pressable(
              padding: pad,
              onPressed: () => runGuarded(context, () => s.paused ? ctl.resume() : ctl.pause()),
              child: Text(s.paused ? 'Resume' : 'Pause'),
            ),
            Pressable(
              padding: pad,
              onPressed: () => runGuarded(context, () => ref.read(breakProvider.notifier).start()),
              child: const Text('Take a break now'),
            ),
            Pressable(padding: pad, onPressed: () => _showStuck(context, ref, s.sessionId), child: const Text("I'm stuck")),
            Pressable(padding: pad, tone: PressableTone.primary, onPressed: _end, child: const Text('End session')),
          ],
        );

        // The whole page is the session: one sage ground, filled edge to edge.
        // Left = the dial (the ring IS the session); right = what the session
        // is doing (pressure so far, live signals) and the controls.
        return LayoutBuilder(
          builder: (context, viewport) {
            final tall = viewport.maxHeight >= 600;
            final body = ColorField(
              tone: FieldTone.now,
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
              child: LayoutBuilder(
                builder: (context, box) {
                  final wide = box.maxWidth >= 860;
                  final dialSize = (wide ? math.min(box.maxWidth * 0.42, box.maxHeight - 90) : math.min(box.maxWidth - 40, 340.0)).clamp(
                    220.0,
                    460.0,
                  );
                  final display = Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DurationDial(
                        minutes: s.plannedMinutes,
                        onChanged: null,
                        size: dialSize,
                        mode: DialMode.progress,
                        fraction: fraction,
                        centerLabel: formatDuration(elapsed),
                        onCenterTap: () => runGuarded(context, () => s.paused ? ctl.resume() : ctl.pause()),
                        centerTapHint: s.paused ? 'Resume' : 'Pause',
                      ),
                      const SizedBox(height: 18),
                      ReadOut(
                        remaining.isNegative
                            ? '${formatDuration(-remaining)} past your planned ${s.plannedMinutes} min'
                            : '${formatDuration(remaining)} left of ${s.plannedMinutes} min${s.paused ? ' · paused' : ''}',
                        size: 13,
                      ),
                    ],
                  );
                  final side = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(spacing: 8, runSpacing: 8, children: [FlowStateChip(s.state), ConnectionChip(l.connection)]),
                      const SizedBox(height: 22),
                      const SectionLabel('This session · pressure'),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: wide ? math.max(140.0, box.maxHeight * 0.32) : 160,
                        child: _SessionPressure(
                          points: pressure,
                          usual: usual,
                          nowValue: l.status?.pressure,
                          start: s.startedAt,
                          plannedEnd: s.startedAt.add(planned),
                          now: now,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const SectionLabel('Live signals'),
                      const SizedBox(height: 6),
                      _LiveSignals(status: l.status),
                      if (wide) const Spacer() else const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(child: stat(formatDuration(elapsed), 'focused so far')),
                          Expanded(child: stat('$nudges', nudges == 1 ? 'nudge' : 'nudges')),
                          Expanded(child: stat('$breaksTaken', breaksTaken == 1 ? 'break taken' : 'breaks taken')),
                        ],
                      ),
                      const SizedBox(height: 22),
                      controls,
                    ],
                  );
                  if (!wide) {
                    return SingleChildScrollView(child: Column(children: [display, const SizedBox(height: 28), side]));
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 11, child: Center(child: display)),
                      const SizedBox(width: 36),
                      Expanded(flex: 9, child: side),
                    ],
                  );
                },
              ),
            );
            return Padding(
              padding: const EdgeInsets.only(right: 24, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FlowHeader(
                    title: s.taskText?.isNotEmpty == true ? s.taskText! : 'Focus session',
                    subtitle: '${demandLabel(s.demand)} demand',
                  ),
                  const SizedBox(height: 10),
                  if (tall) Expanded(child: body) else SizedBox(height: 620, child: body),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Pressure since this session started, on the session's own planned axis:
/// a filled curve rising toward the dashed nudge line; NOW is the dot.
class _SessionPressure extends StatelessWidget {
  const _SessionPressure({
    required this.points,
    required this.start,
    required this.plannedEnd,
    required this.now,
    this.usual = const [],
    this.nowValue,
  });
  final List<PressurePoint> points;
  final List<PressurePoint> usual;
  final double? nowValue;
  final DateTime start;
  final DateTime plannedEnd;
  final DateTime now;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.infinite,
    painter: _PressurePainter(
      FlowPalette.of(context),
      points,
      start,
      now.isAfter(plannedEnd) ? now : plannedEnd,
      now,
      MediaQuery.textScalerOf(context),
      usual: usual,
      nowValue: nowValue,
    ),
  );
}

class _PressurePainter extends CustomPainter {
  _PressurePainter(this.p, this.points, this.start, this.end, this.now, this.scaler, {this.usual = const [], this.nowValue});
  final List<PressurePoint> usual;
  final double? nowValue;
  final FlowPalette p;
  final List<PressurePoint> points;
  final DateTime start, end, now;
  final TextScaler scaler;

  @override
  void paint(Canvas c, Size s) {
    const top = 14.0;
    final base = s.height - 18;
    double x(DateTime t) => s.width * (t.difference(start).inSeconds / math.max(1, end.difference(start).inSeconds)).clamp(0.0, 1.0);
    double y(double v) => base - (base - top) * (v / 1.15).clamp(0.0, 1.0);
    void text(String str, Offset at, Color col, {bool right = false}) {
      final tp = TextPainter(
        text: TextSpan(
          text: str,
          style: FlowType.chart(p, size: 9.5, color: col),
        ),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      tp.paint(c, Offset(right ? at.dx - tp.width : at.dx, at.dy - tp.height / 2));
    }

    c.drawLine(
      Offset(0, base),
      Offset(s.width, base),
      Paint()
        ..color = p.text3
        ..strokeWidth = 1,
    );
    final line = y(1.0);
    for (var xx = 0.0; xx < s.width; xx += 7) {
      c.drawLine(
        Offset(xx, line),
        Offset(math.min(xx + 4, s.width), line),
        Paint()
          ..color = p.amber.withValues(alpha: 0.8)
          ..strokeWidth = 0.9,
      );
    }
    text('nudge line', Offset(s.width, line - 8), p.amber, right: true);
    final mins = end.difference(start).inMinutes;
    for (var m = 0; m <= mins; m += 10) {
      final xx = x(start.add(Duration(minutes: m)));
      c.drawLine(
        Offset(xx, base),
        Offset(xx, base + 3),
        Paint()
          ..color = p.text3
          ..strokeWidth = 0.8,
      );
      text('$m′', Offset(xx + 2, base + 10), p.text3);
    }
    // your usual for these minutes (only with enough history): the expectation
    if (usual.length > 1) {
      final u = [for (final pt in usual) Offset(x(pt.t), y(pt.v))];
      for (var i = 0; i < u.length - 1; i++) {
        final a = u[i], b = u[i + 1];
        final len = (b - a).distance;
        for (var d = 0.0; d < len; d += 7) {
          final t0 = d / len, t1 = math.min(1.0, (d + 4) / len);
          c.drawLine(
            Offset.lerp(a, b, t0)!,
            Offset.lerp(a, b, t1)!,
            Paint()
              ..color = p.text3.withValues(alpha: 0.7)
              ..strokeWidth = 0.9,
          );
        }
      }
      text('your usual', Offset(u.last.dx - 4, u.last.dy - 9), p.text3, right: true);
    }
    final all = [...points, if (nowValue != null && (points.isEmpty || points.last.t.isBefore(now))) PressurePoint(now, nowValue!)];
    if (all.length < 2) {
      if (all.length == 1) {
        final o = Offset(x(all.first.t), y(all.first.v));
        c.drawCircle(o, 3.6, Paint()..color = p.bg);
        c.drawCircle(o, 2.8, Paint()..color = p.accent);
      }
      if (usual.length < 2) text('Your pressure curve draws in as the session runs.', Offset(0, (top + base) / 2), p.text3);
      return;
    }
    // points closer than 2 px on x merge (latest wins): early in a session
    // the start point and NOW share a pixel and would draw a vertical spike
    final pts = <Offset>[];
    for (final pt in all) {
      final o = Offset(x(pt.t), y(pt.v));
      if (pts.isNotEmpty && (o.dx - pts.last.dx).abs() < 2) {
        pts[pts.length - 1] = o;
      } else {
        pts.add(o);
      }
    }
    if (pts.length < 2) {
      c.drawCircle(pts.first, 3.6, Paint()..color = p.bg);
      c.drawCircle(pts.first, 2.8, Paint()..color = p.accent);
      return;
    }
    final area = Path()..moveTo(pts.first.dx, base);
    for (final o in pts) {
      area.lineTo(o.dx, o.dy);
    }
    area
      ..lineTo(pts.last.dx, base)
      ..close();
    c.drawPath(area, Paint()..color = p.accent.withValues(alpha: 0.16));
    c.save();
    c.clipPath(area);
    c.drawRect(Rect.fromLTRB(0, y(1.2), s.width, y(0.8)), Paint()..color = p.amber.withValues(alpha: 0.35));
    c.restore();
    final stroke = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final o in pts.skip(1)) {
      stroke.lineTo(o.dx, o.dy);
    }
    c.drawPath(
      stroke,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeJoin = StrokeJoin.round
        ..color = p.accentDeep,
    );
    c.drawCircle(pts.last, 3.6, Paint()..color = p.bg);
    c.drawCircle(pts.last, 2.8, Paint()..color = p.accent);
  }

  @override
  bool shouldRepaint(_PressurePainter o) => o.points != points || o.now != now || o.nowValue != nowValue || o.usual != usual || o.p != p;
}

class _LiveSignals extends ConsumerWidget {
  const _LiveSignals({required this.status});
  final SessionStatus? status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = FlowPalette.of(context);
    final local = ref.watch(liveSignalsProvider).value;
    final st = status;
    Widget bar(String name, double? v, String trailing) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(name, style: TextStyle(color: p.text2, fontSize: 12.5)),
          ),
          Expanded(
            child: Recessed(
              radius: 3,
              child: SizedBox(
                height: 6,
                child: v == null
                    ? null
                    : FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: v.clamp(0.0, 1.0),
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: p.pastHeavy, borderRadius: BorderRadius.circular(3)),
                        ),
                      ),
              ),
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(trailing, textAlign: TextAlign.right, style: FlowType.chart(p, size: 11)),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (st != null) ...[
          bar('Break pressure', st.pressure, '${(st.pressure * 100).round()}%'),
          for (final sig in st.signals) bar(sig.name, sig.available ? sig.value : null, sig.available ? 'weight ${sig.weight}' : 'off'),
        ],
        if (local != null) ...[
          const SizedBox(height: 8),
          Text(
            'On this computer: ${local.keysPerMin} keys/min · ${local.switchesPer5Min} switches/5 min · idle ${local.idleSec}s',
            style: FlowType.chart(p, size: 11),
          ),
        ],
      ],
    );
  }
}

Future<void> _showStuck(BuildContext context, WidgetRef ref, String sessionId) async {
  final future = ref.read(sessionApiProvider).stuck(sessionId);
  await showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Break it down'),
      content: SizedBox(
        width: 420,
        child: FutureBuilder<StuckHelp>(
          future: future,
          builder: (c, snap) {
            if (snap.hasError) {
              final e = snap.error;
              if (e is ApiError && e.code == ApiError.llmConsentRequired) {
                return const Text(
                  'The AI assistant is off. Turn on "AI assistant" in Privacy to get task-specific help. '
                  'Only your task text is sent.',
                );
              }
              return Text(errorText(e!));
            }
            final h = snap.data;
            if (h == null) return const LinearProgressIndicator();
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (h.fromCache) const Text('(General suggestions — the assistant is unavailable right now.)'),
                Text('Smallest next step: ${h.nextStep}', style: Theme.of(c).textTheme.titleSmall),
                const SizedBox(height: 8),
                for (final step in h.breakdown) Text('• $step'),
                const SizedBox(height: 8),
                for (final q in h.questions) Text('? $q'),
              ],
            );
          },
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))],
    ),
  );
}

// ── /session/break ─────────────────────────────────────────────────────────

class BreakScreen extends ConsumerStatefulWidget {
  const BreakScreen({super.key});
  @override
  ConsumerState<BreakScreen> createState() => _BreakScreenState();
}

/// Full-screen, outside the shell (no navigation during a break). The dial's
/// dashes drain as the break runs; one suggestion in Flow's voice; one action.
/// Lock mode: a slide-to-override instead of a button (spec §3 Lock).
class _BreakScreenState extends ConsumerState<BreakScreen> {
  BreakResult? _ended;
  int? _focus;
  int? _fatigue;

  static const _ideas = [
    'Look at something far away for a minute. Then stand, stretch, and drink some water.',
    'Walk to a window. Let your eyes rest on the farthest thing you can see.',
    'Roll your shoulders, unclench your jaw, and take five slow breaths.',
  ];

  Future<void> _finish() async {
    try {
      final r = await ref.read(breakProvider.notifier).end();
      if (mounted) setState(() => _ended = r);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _override(String interventionId) async {
    final reason = await showDialog<OverrideReason>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Skip this break because…'),
        children: [for (final r in OverrideReason.values) SimpleDialogOption(onPressed: () => Navigator.pop(c, r), child: Text(r.label))],
      ),
    );
    if (reason == null || !mounted) return;
    final ok = await runGuarded(context, () => ref.read(interventionActionsProvider).overrideLock(interventionId, reason));
    if (ok && mounted) _leave();
  }

  void _leave() => context.canPop() ? context.pop() : context.go(Routes.home);

  Future<void> _submitRatings() async {
    final actions = ref.read(interventionActionsProvider);
    final ctx = _ended?.breakId;
    await runGuarded(context, () async {
      if (_focus != null) await actions.rate(RatingKind.postBreakFocus, _focus!, contextId: ctx);
      if (_fatigue != null) await actions.rate(RatingKind.fatigue, _fatigue!, contextId: ctx);
    });
    if (mounted) _leave();
  }

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    // the break owns the whole screen, on the amber "rest" ground
    Widget frame(List<Widget> children) => Scaffold(
      backgroundColor: ColorField.colorOf(p, FieldTone.rest),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      ),
    );

    // Post-break: two optional taps (doc §6.5 step 5).
    if (_ended != null) {
      return frame([
        Text('Welcome back', style: FlowType.headline(p, size: 32)),
        const SizedBox(height: 10),
        Text(
          'Two quick taps help Flow time the next one. Both are optional.',
          textAlign: TextAlign.center,
          style: FlowType.note(p, size: 14),
        ),
        const SizedBox(height: 26),
        DotRating(label: 'How focused do you feel?', value: _focus, onChanged: (v) => setState(() => _focus = v)),
        const SizedBox(height: 12),
        DotRating(label: 'How tired do you feel?   ', value: _fatigue, onChanged: (v) => setState(() => _fatigue = v)),
        const SizedBox(height: 28),
        SizedBox(
          width: 240,
          child: _Primary(label: 'Back to work', onPressed: _submitRatings),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: _leave,
          child: Text('Skip', style: TextStyle(color: p.text2)),
        ),
      ]);
    }

    final b = ref.watch(breakProvider);
    if (b == null) {
      return frame([
        Text('No break running', style: FlowType.headline(p, size: 28)),
        const SizedBox(height: 18),
        SizedBox(
          width: 200,
          child: _Primary(label: 'Back', onPressed: _leave),
        ),
      ]);
    }
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final total = Duration(seconds: b.plannedSec);
    final left = b.endsAt.difference(now);
    final frac = total.inSeconds == 0 ? 0.0 : (left.inSeconds / total.inSeconds).clamp(0.0, 1.0);
    final interventionId = b.interventionId;
    final idea = _ideas[b.startedAt.minute % _ideas.length];

    return frame([
      Text(flowCaps(left.isNegative ? 'Break time is up' : 'On a break'), style: FlowType.label(p, size: 11, color: p.text3)),
      const SizedBox(height: 18),
      DurationDial(
        minutes: (total.inSeconds / 60).ceil().clamp(1, 180),
        onChanged: null,
        size: 260,
        mode: DialMode.drain,
        fraction: frac,
        centerLabel: left.isNegative ? '0:00' : formatDuration(left),
      ),
      const SizedBox(height: 22),
      Text(
        idea,
        textAlign: TextAlign.center,
        style: FlowType.note(p, size: 15, color: p.text1),
      ),
      const SizedBox(height: 26),
      if (b.lock && interventionId != null) ...[
        if (left.isNegative)
          SizedBox(
            width: 240,
            child: _Primary(label: "I'm back", onPressed: _finish),
          ),
        const SizedBox(height: 14),
        // Lock mode always offers a visible emergency override (doc §6.1).
        SlideToOverride(onConfirmed: () => _override(interventionId)),
      ] else
        SizedBox(
          width: 240,
          child: _Primary(label: left.isNegative ? "I'm back" : 'End break early', onPressed: _finish),
        ),
    ]);
  }
}

class _Primary extends StatelessWidget {
  const _Primary({required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Pressable(
    tone: PressableTone.primary,
    onPressed: onPressed,
    padding: const EdgeInsets.symmetric(vertical: 11),
    child: SizedBox(
      width: double.infinity,
      child: Text(label, textAlign: TextAlign.center),
    ),
  );
}

/// Slide to override (spec §3 Lock): the knob FOLLOWs the pointer, rubber
/// bands past the end, confirms at ≥ 90%, otherwise SETTLEs back with the
/// release velocity. Keyboard: Enter/Space opens the same confirm.
class SlideToOverride extends StatefulWidget {
  const SlideToOverride({super.key, required this.onConfirmed, this.width = 280});
  final VoidCallback onConfirmed;
  final double width;

  @override
  State<SlideToOverride> createState() => _SlideToOverrideState();
}

class _SlideToOverrideState extends State<SlideToOverride> with SingleTickerProviderStateMixin {
  late final _x = SpringValue(vsync: this, initial: 0);
  double _raw = 0;
  static const _knob = 36.0;

  double get _track => widget.width - _knob - 4;

  void _release(double velocity) {
    if (_x.value / _track >= 0.9) {
      _x.animateTo(_track, spring: Motion.snap, velocity: velocity);
      widget.onConfirmed();
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _x.animateTo(0, spring: Motion.settle);
      });
    } else {
      _x.animateTo(0, spring: Motion.settle, velocity: velocity);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    return Semantics(
      button: true,
      label: 'Slide to override the break',
      onTap: widget.onConfirmed,
      child: Focus(
        onKeyEvent: (n, e) {
          if (e is KeyDownEvent && (e.logicalKey == LogicalKeyboardKey.enter || e.logicalKey == LogicalKeyboardKey.space)) {
            widget.onConfirmed();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onHorizontalDragStart: (_) => _raw = _x.value,
          onHorizontalDragUpdate: (d) {
            _raw += d.delta.dx;
            // rubber band at both ends (mouse-drag c), FOLLOW otherwise
            final over = _raw > _track ? _raw - _track : (_raw < 0 ? _raw : 0.0);
            _x.value = _raw.clamp(0.0, _track) + RubberBand.offset(over, widget.width, 0.4);
          },
          onHorizontalDragEnd: (d) => _release(d.velocity.pixelsPerSecond.dx),
          child: SizedBox(
            width: widget.width,
            height: _knob + 4,
            child: Recessed(
              radius: (_knob + 4) / 2,
              child: AnimatedBuilder(
                animation: _x.animation,
                builder: (context, _) => Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Center(
                      child: Opacity(
                        opacity: (1 - _x.value / _track).clamp(0.2, 1.0),
                        child: Text('slide to override  ›', style: TextStyle(color: p.text2, fontSize: 12.5)),
                      ),
                    ),
                    Positioned(
                      left: 2 + _x.value,
                      child: Container(
                        width: _knob,
                        height: _knob,
                        decoration: BoxDecoration(
                          color: p.raised,
                          shape: BoxShape.circle,
                          border: Border.all(color: p.hairline),
                          boxShadow: [BoxShadow(color: Faces.ground(p.raised), offset: const Offset(0, 2))],
                        ),
                        child: Icon(Icons.chevron_right, size: 18, color: p.text2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── /session/end/:id ───────────────────────────────────────────────────────

class SessionEndScreen extends ConsumerStatefulWidget {
  const SessionEndScreen({super.key, required this.sessionId, this.summary});
  final String sessionId;

  /// Passed from the end action; null when opened from history.
  final SessionSummary? summary;

  @override
  ConsumerState<SessionEndScreen> createState() => _SessionEndScreenState();
}

/// Session summary (spec §7): display = the session's blocks rising from its
/// own axis, with breaks as gaps and nudges marked; read-out; what Flow
/// learned (Cutive); deck = 5-dot rating · Done.
class _SessionEndScreenState extends ConsumerState<SessionEndScreen> {
  int? _rating;

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    final s = widget.summary;
    final replay = ref.watch(replayProvider(widget.sessionId));
    final title = s?.taskText?.isNotEmpty == true ? s!.taskText! : 'Session summary';
    return ListView(
      padding: const EdgeInsets.only(right: 24, bottom: 32),
      children: [
        FlowHeader(title: title, subtitle: s == null ? null : '${demandLabel(s.demand)} demand'),
        const SizedBox(height: 18),
        AsyncSection(
          lines: 5,
          value: replay,
          onRetry: () => ref.invalidate(replayProvider(widget.sessionId)),
          builder: (r) {
            // without a summary (opened by link), run the axis a little past the last event
            final lastMin = r.events.isEmpty ? 0 : r.events.last.minute;
            final total = s == null ? lastMin + 8 : math.max(s.focusMinutes, lastMin);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ColorField(
                  tone: FieldTone.past,
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 12),
                  child: SessionAxis(
                    events: r.events,
                    totalMinutes: total,
                    height: 240,
                    plannedMinutes: s?.plannedMinutes,
                    demand: s?.demand ?? Demand.moderate,
                  ),
                ),
                const SizedBox(height: 14),
                if (s != null)
                  ReadOut(
                    '${s.focusMinutes} of ${s.plannedMinutes} min focused · '
                    '${s.breaksTaken} of ${s.breaksSuggested} breaks taken',
                  ),
                const SizedBox(height: 22),
                Divider(height: 1, color: p.hairline),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionLabel('What happened'),
                          const SizedBox(height: 10),
                          for (final e in r.events)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 44,
                                    child: Text('${e.minute}′', style: FlowType.chart(p, size: 12, color: p.text3)),
                                  ),
                                  Expanded(
                                    child: Text(e.text, style: TextStyle(color: p.text1, fontSize: 13, height: 1.4)),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionLabel('What Flow learned'),
                          const SizedBox(height: 10),
                          if (r.whatFlowLearned.isEmpty)
                            Text('Nothing new yet. A few more sessions and patterns start to show.', style: FlowType.note(p, size: 14))
                          else
                            for (final l in r.whatFlowLearned)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(l, style: FlowType.note(p, size: 14.5, color: p.text1)),
                              ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Divider(height: 1, color: p.hairline),
        const SizedBox(height: 16),
        // ── DECK ──
        Row(
          children: [
            if (s != null)
              DotRating(
                label: 'How focused was this session?',
                value: _rating,
                onChanged: (v) {
                  setState(() => _rating = v);
                  unawaited(
                    runGuarded(
                      context,
                      () => ref.read(breakApiProvider).rate(sessionId: widget.sessionId, kind: RatingKind.focus, value: v),
                    ),
                  );
                },
              ),
            const Spacer(),
            Pressable(tone: PressableTone.primary, onPressed: () => context.go(Routes.home), child: const Text('Done')),
          ],
        ),
      ],
    );
  }
}

/// The session on its own axis: focus blocks rise from the line (SETTLE,
/// staggered), breaks are gaps, nudges ▼ and "approaching" ticks sit above.
class SessionAxis extends StatefulWidget {
  const SessionAxis({
    super.key,
    required this.events,
    required this.totalMinutes,
    required this.demand,
    this.plannedMinutes,
    this.height = 200,
  });
  final List<ReplayEvent> events;
  final int totalMinutes;
  final int? plannedMinutes;
  final Demand demand;
  final double height;

  @override
  State<SessionAxis> createState() => _SessionAxisState();
}

class _SessionAxisState extends State<SessionAxis> with SingleTickerProviderStateMixin {
  late final _rise = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));

  @override
  void initState() {
    super.initState();
    Motion.enterOnMount(context, _rise, () => mounted);
  }

  @override
  void dispose() {
    _rise.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _rise,
    builder: (context, _) => CustomPaint(
      size: Size(double.infinity, widget.height),
      painter: _AxisPainter(
        p: FlowPalette.of(context),
        events: widget.events,
        total: math.max(1, math.max(widget.totalMinutes, widget.plannedMinutes ?? 0)),
        planned: widget.plannedMinutes,
        demand: widget.demand,
        rise: _rise.isCompleted ? 1e9 : _rise.value * 2.0,
        scaler: MediaQuery.textScalerOf(context),
      ),
    ),
  );
}

class _AxisPainter extends CustomPainter {
  _AxisPainter({
    required this.p,
    required this.events,
    required this.total,
    required this.planned,
    required this.demand,
    required this.rise,
    required this.scaler,
  });
  final FlowPalette p;
  final List<ReplayEvent> events;
  final int total;
  final int? planned;
  final Demand demand;
  final double rise;
  final TextScaler scaler;

  void _t(Canvas c, String s, Offset at, {Color? color, double size = 10, bool center = true}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: FlowType.chart(p, size: size, color: color),
      ),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    tp.paint(c, Offset(center ? at.dx - tp.width / 2 : at.dx, at.dy - tp.height / 2));
  }

  @override
  void paint(Canvas c, Size s) {
    const left = 4.0;
    final right = s.width - 16;
    final base = s.height - 26;
    final maxH = s.height * 0.55;
    double x(num m) => left + (right - left) * m / total;

    // focus segments: breaks (intervention→resume, break→resume) are gaps
    final segs = <(int, int)>[];
    var from = 0;
    int? gapStart;
    for (final e in events) {
      if ((e.kind == 'intervention' || e.kind == 'break') && e.text.toLowerCase().contains('took') || e.kind == 'break') {
        gapStart ??= e.minute;
      }
      if (e.kind == 'resume' && gapStart != null) {
        if (gapStart > from) segs.add((from, gapStart));
        from = e.minute;
        gapStart = null;
      }
    }
    if (total > from) segs.add((from, gapStart ?? total));

    final h =
        maxH *
        switch (demand) {
          Demand.light => 0.55,
          Demand.moderate => 0.78,
          Demand.heavy => 1.0,
        };
    final stone = p.pastByDemand[demand.index];
    final depth = (h * 0.12).clamp(5.0, 12.0);

    // axis + minute ticks every 10
    c.drawLine(
      Offset(left, base),
      Offset(right + 8, base),
      Paint()
        ..color = p.text3
        ..strokeWidth = 1,
    );
    for (var m = 0; m <= total; m += 10) {
      c.drawLine(
        Offset(x(m), base),
        Offset(x(m), base + 4),
        Paint()
          ..color = p.text3
          ..strokeWidth = 0.8,
      );
      _t(c, '$m′', Offset(x(m), base + 13), size: 9.5);
    }
    if (planned != null && planned! <= total) {
      final px = x(planned!);
      for (var y = base - maxH - 10; y < base; y += 6) {
        c.drawLine(
          Offset(px, y),
          Offset(px, y + 3),
          Paint()
            ..color = p.text3
            ..strokeWidth = 0.8,
        );
      }
      _t(c, 'planned', Offset(px, base - maxH - 18), size: 9, color: p.text3);
    }

    for (final (i, seg) in segs.indexed) {
      final tt = rise >= 1e8 ? 1e9 : rise - i * 0.1;
      final r = tt >= 1e8 ? 1.0 : Motion.settleAt(tt);
      final x0 = x(seg.$1) + 1.5, x1 = x(seg.$2) - 1.5;
      final top = base - h * r;
      if (r > 0.004) paintSolidBlock(c, x0, x1, base, h * r, depth, stone);
      if (r < 0.999) continue;
      // 10-minute seams so a long block keeps the rhythm of the axis
      for (var m = ((seg.$1 ~/ 10) + 1) * 10; m < seg.$2; m += 10) {
        c.drawLine(
          Offset(x(m), top + 1),
          Offset(x(m), base),
          Paint()
            ..color = Faces.side(stone).withValues(alpha: 0.35)
            ..strokeWidth = 1,
        );
      }
    }

    // markers above the blocks
    final markY = base - maxH - 2;
    for (final e in events) {
      final ex = x(e.minute);
      if (e.kind == 'intervention') {
        c.drawPath(
          Path()
            ..moveTo(ex - 4, markY - 8)
            ..lineTo(ex + 4, markY - 8)
            ..lineTo(ex, markY - 2)
            ..close(),
          Paint()..color = p.amber,
        );
      } else if (e.kind == 'approaching') {
        c.drawLine(
          Offset(ex, markY - 8),
          Offset(ex, markY),
          Paint()
            ..color = p.amber.withValues(alpha: 0.7)
            ..strokeWidth = 1.2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_AxisPainter o) => o.rise != rise || o.events != events || o.p != p || o.total != total;
}
