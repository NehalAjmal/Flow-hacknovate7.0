import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/models/session.dart';
import '../screens/intervention_card.dart';
import '../router/app_router.dart';
import '../router/routes.dart';
import '../state/break_controller.dart';
import '../state/session_controller.dart';
import '../ui/kit.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import '../ui/brand/wordmark.dart';
import '../widgets/common.dart';
import 'desktop_host.dart';
import 'window_controller.dart';

/// Wraps the whole app: in mini/card mode the router stays mounted but
/// offstage (no state lost, its tickers paused), and the compact view
/// cross-fades in (spec §3 fallback: FADE + one native resize).
class WindowFrame extends ConsumerWidget {
  const WindowFrame({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(windowModeProvider);
    final compact = mode == WindowMode.mini || mode == WindowMode.card;
    return Stack(
      children: [
        Offstage(
          offstage: compact,
          child: TickerMode(enabled: !compact, child: child),
        ),
        AnimatedSwitcher(
          duration: Motion.fade,
          child: switch (mode) {
            WindowMode.mini => const MiniWidget(key: ValueKey('mini')),
            WindowMode.card => const CardView(key: ValueKey('card')),
            _ => const SizedBox.shrink(key: ValueKey('none')),
          },
        ),
      ],
    );
  }
}

/// The 320×88 session widget: [dashed ring] 32:10 · Steady [⏸] [⤢].
/// Drag anywhere to move (native); it snaps to the nearest corner on release.
/// Click the time to pause/resume. The amber dot = a nudge waiting (it scales
/// in once, never pulses); click it to open the card.
class MiniWidget extends ConsumerWidget {
  const MiniWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = FlowPalette.of(context);
    final live = ref.watch(liveSessionProvider).value;
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final win = ref.read(windowModeProvider.notifier);
    if (live == null) return const SizedBox.shrink();
    final s = live.session;
    final elapsed = s.elapsedAt(now);
    final planned = Duration(minutes: s.plannedMinutes);
    final left = planned - elapsed;
    final frac = (elapsed.inSeconds / planned.inSeconds).clamp(0.0, 1.0);
    final pending = live.pendingInterventionId != null;
    final ctl = ref.read(liveSessionProvider.notifier);

    return Material(
      color: p.raised,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => ref.read(desktopHostProvider).startDrag(),
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: p.hairline)),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              SizedBox(width: 54, height: 54, child: CustomPaint(painter: _MiniRing(p, frac, s.paused))),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  button: true,
                  label: s.paused ? 'Resume session' : 'Pause session',
                  child: GestureDetector(
                    onTap: () => runGuarded(context, () => s.paused ? ctl.resume() : ctl.pause()),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TabularNumeral(formatDuration(left.isNegative ? -left : left), style: FlowType.numeral(p, 26)),
                        const SizedBox(height: 3),
                        Text(
                          flowCaps(
                            s.paused
                                ? 'Paused'
                                : switch (s.state) {
                                    FlowState.approachingBreak => 'Break soon',
                                    FlowState.breakDue => 'Break due',
                                    _ => left.isNegative ? 'Past plan' : 'Steady',
                                  },
                          ),
                          style: FlowType.label(p, size: 9.5, color: p.text2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (pending)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOutBack,
                  builder: (context, v, _) => Transform.scale(
                    scale: v,
                    child: IconButton(
                      tooltip: 'A break suggestion is waiting',
                      onPressed: win.openCard,
                      icon: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: p.amber, shape: BoxShape.circle),
                      ),
                    ),
                  ),
                ),
              IconButton(
                tooltip: s.paused ? 'Resume' : 'Pause',
                onPressed: () => runGuarded(context, () => s.paused ? ctl.resume() : ctl.pause()),
                icon: Icon(s.paused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 18, color: p.text1),
              ),
              IconButton(
                tooltip: 'Open Flow',
                onPressed: win.expand,
                icon: Icon(Icons.open_in_full_rounded, size: 16, color: p.text2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The session ring at widget size: dashes for the plan, filled as it runs.
class _MiniRing extends CustomPainter {
  _MiniRing(this.p, this.frac, this.paused);
  final FlowPalette p;
  final double frac;
  final bool paused;

  @override
  void paint(Canvas c, Size s) {
    final ctr = s.center(Offset.zero);
    final r = s.shortestSide / 2 - 3;
    const n = 36;
    for (var i = 0; i < n; i++) {
      final a = -math.pi / 2 + 2 * math.pi * i / n;
      final done = i / n < frac;
      final o1 = ctr + Offset(math.cos(a), math.sin(a)) * (r - (done ? 6 : 4));
      final o2 = ctr + Offset(math.cos(a), math.sin(a)) * r;
      c.drawLine(
        o1,
        o2,
        Paint()
          ..color = done ? (paused ? p.text3 : p.accent) : p.hairline
          ..strokeWidth = done ? 1.8 : 1.2
          ..strokeCap = StrokeCap.round,
      );
    }
    c.drawCircle(ctr, r - 10, Paint()..color = p.bg);
  }

  @override
  bool shouldRepaint(_MiniRing o) => o.frac != frac || o.paused != paused || o.p != p;
}

/// The widget grown into a card: a waiting nudge, or the session's controls.
/// It folds back into the widget after 60 s, or when answered.
class CardView extends ConsumerWidget {
  const CardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = FlowPalette.of(context);
    final live = ref.watch(liveSessionProvider).value;
    final win = ref.read(windowModeProvider.notifier);
    final id = live?.pendingInterventionId;
    return Material(
      color: p.bg,
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: p.hairline)),
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => ref.read(desktopHostProvider).startDrag(),
              child: Row(
                children: [
                  const FlowWordmark(capHeight: 12),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Back to the widget',
                    onPressed: win.collapseCard,
                    icon: Icon(Icons.expand_more_rounded, size: 18, color: p.text2),
                  ),
                  IconButton(
                    tooltip: 'Open Flow',
                    onPressed: win.expand,
                    icon: Icon(Icons.open_in_full_rounded, size: 16, color: p.text2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: SingleChildScrollView(
                child: id != null
                    ? InterventionCard(interventionId: id)
                    : (live == null ? const SizedBox.shrink() : _SessionCard(live: live)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The card without a nudge: the session itself, large, with its controls.
/// End opens the summary in the full window.
class _SessionCard extends ConsumerWidget {
  const _SessionCard({required this.live});
  final LiveSession live;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = FlowPalette.of(context);
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final s = live.session;
    final elapsed = s.elapsedAt(now);
    final planned = Duration(minutes: s.plannedMinutes);
    final left = planned - elapsed;
    final ctl = ref.read(liveSessionProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (s.taskText?.isNotEmpty == true)
          Text(
            s.taskText!,
            style: TextStyle(color: p.text1, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        const SizedBox(height: 6),
        TabularNumeral(formatDuration(elapsed), style: FlowType.numeral(p, 44)),
        const SizedBox(height: 4),
        Text(
          flowCaps(left.isNegative ? '${formatDuration(-left)} past plan' : '${formatDuration(left)} left of ${s.plannedMinutes} min'),
          style: FlowType.label(p, size: 10, color: p.text2),
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: (elapsed.inSeconds / planned.inSeconds).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: p.recess,
            color: s.paused ? p.text3 : p.accent,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Pressable(
              onPressed: () => runGuarded(context, () => s.paused ? ctl.resume() : ctl.pause()),
              child: Text(s.paused ? 'Resume' : 'Pause'),
            ),
            Pressable(
              onPressed: () => runGuarded(context, () => ref.read(breakProvider.notifier).start()),
              child: const Text('Take a break'),
            ),
            Pressable(
              tone: PressableTone.primary,
              onPressed: () async {
                try {
                  final summary = await ctl.end();
                  ref.read(appRouterProvider).go(Routes.sessionEndFor(summary.sessionId), extra: summary);
                } catch (e) {
                  if (context.mounted) showError(context, e);
                }
              },
              child: const Text('End'),
            ),
          ],
        ),
      ],
    );
  }
}
