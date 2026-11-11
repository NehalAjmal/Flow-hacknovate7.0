import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/models/session.dart';
import '../screens/intervention_card.dart';
import '../router/app_router.dart';
import '../router/routes.dart';
import '../state/break_controller.dart';
import '../state/session_controller.dart';
import '../ui/feature_note.dart' show ColorField, FieldTone;
import '../ui/kit.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import '../ui/brand/wordmark.dart';
import '../widgets/common.dart';
import 'desktop_host.dart';
import 'nudge_takeover.dart';
import 'window_controller.dart';

/// Wraps the whole app: in mini/card mode the router stays mounted but
/// offstage (no state lost, its tickers paused), and the compact view
/// cross-fades in (spec §3 fallback: FADE + one native resize).
///
/// This sits in MaterialApp.builder, i.e. ABOVE the router's Navigator, so the
/// compact views get their own Overlay: tooltips, ink and text selection need
/// one, and the Navigator's is offstage here.
class WindowFrame extends ConsumerStatefulWidget {
  const WindowFrame({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<WindowFrame> createState() => _WindowFrameState();
}

class _WindowFrameState extends ConsumerState<WindowFrame> {
  // One persistent entry: Overlay reads initialEntries only once, so the
  // entry's content watches the mode itself instead of capturing it.
  final _entry = OverlayEntry(builder: (_) => const _CompactSwitcher());
  Size _full = const Size(1280, 800); // until the first full layout

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  /// Esc in the widget or card: back to the full app. A way out that needs
  /// no pointer target.
  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent || e.logicalKey != LogicalKeyboardKey.escape) return false;
    final mode = ref.read(windowModeProvider);
    if (!mode.isCompact) return false; // a takeover handles its own keys
    ref.read(windowModeProvider.notifier).expand();
    return true;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _entry.remove();
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(windowModeProvider);
    // The app steps offstage under anything that covers the window. In a
    // browser (no native window to reshape) a windowed takeover is a panel
    // over the dimmed app instead.
    final desktop = ref.watch(desktopHostProvider).isDesktop;
    final compact = mode.isCompact || mode == WindowMode.nudgeFull || (mode == WindowMode.nudge && desktop);
    // expand: the parent's constraints are loose, and while compact the
    // offstage app sizes to nothing, so a plain Stack collapsed to 0×0 and
    // the widget painted into an empty (black) window.
    return Stack(
      fit: StackFit.expand,
      children: [
        // Offstage still lays its child out. At 320×88 the full app would
        // overflow everywhere, so while compact it keeps the last full size.
        LayoutBuilder(
          builder: (context, box) {
            if (!compact) _full = box.biggest;
            final keep = compact ? _full : null;
            return Offstage(
              offstage: compact,
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: keep?.width,
                maxWidth: keep?.width,
                minHeight: keep?.height,
                maxHeight: keep?.height,
                // hidden also means out of the focus order: a key pressed over
                // the widget or a takeover must never reach a control in the app
                child: ExcludeFocus(
                  excluding: compact,
                  child: TickerMode(enabled: !compact, child: widget.child),
                ),
              ),
            );
          },
        ),
        // Empty in full mode: nothing in it hit-tests, so input reaches the app.
        Positioned.fill(child: Overlay(initialEntries: [_entry])),
      ],
    );
  }
}

class _CompactSwitcher extends ConsumerWidget {
  const _CompactSwitcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Pop(
      trigger: ref.read(windowModeProvider.notifier).popped,
      child: AnimatedSwitcher(
        duration: Motion.fade,
        child: switch (ref.watch(windowModeProvider)) {
          WindowMode.mini => const MiniWidget(key: ValueKey('mini')),
          WindowMode.card => const CardView(key: ValueKey('card')),
          WindowMode.nudge || WindowMode.nudgeFull => _takeover(context, ref),
          _ => const SizedBox.shrink(key: ValueKey('none')),
        },
      ),
    );
  }
}

Widget _takeover(BuildContext context, WidgetRef ref) {
  final id = ref.watch(liveSessionProvider).value?.pendingInterventionId;
  if (id == null) return const SizedBox.shrink(key: ValueKey('none'));
  final view = NudgeTakeover(key: ValueKey('nudge-$id'), interventionId: id);
  final floating = ref.watch(windowModeProvider) == WindowMode.nudge && !ref.watch(desktopHostProvider).isDesktop;
  if (!floating) return view;
  // browser preview of the floating window: a panel over the dimmed app
  final p = FlowPalette.of(context);
  return ColoredBox(
    key: ValueKey('nudge-panel-$id'),
    color: const Color(0x99000000),
    child: Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 480),
        margin: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.amber.withValues(alpha: 0.4)),
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 40, offset: Offset(0, 16))],
        ),
        child: view,
      ),
    ),
  );
}

/// The pop-in: when the native window has just appeared in its compact shape
/// ([trigger] bumps), the content springs up from 88% with a small overshoot.
/// It rests at full size, so a missed trigger can never leave it hidden.
class _Pop extends StatefulWidget {
  const _Pop({required this.trigger, required this.child});
  final ValueListenable<int> trigger;
  final Widget child;
  @override
  State<_Pop> createState() => _PopState();
}

class _PopState extends State<_Pop> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 460), value: 1);

  @override
  void initState() {
    super.initState();
    widget.trigger.addListener(_go);
  }

  void _go() {
    if (!mounted || Motion.reduced(context)) return;
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    widget.trigger.removeListener(_go);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) {
      final t = Curves.easeOutBack.transform(_c.value);
      return Opacity(
        opacity: Curves.easeOut.transform((_c.value * 2.5).clamp(0.0, 1.0)),
        child: Transform.scale(scale: 0.88 + 0.12 * t, child: child),
      );
    },
  );
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
    // a waiting nudge warms the whole card window (amber = break)
    return Material(
      color: id != null ? ColorField.colorOf(p, FieldTone.rest) : p.bg,
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: id != null ? p.amber.withValues(alpha: 0.5) : p.hairline)),
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
