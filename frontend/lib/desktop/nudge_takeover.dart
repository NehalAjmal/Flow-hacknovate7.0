import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/models/intervention.dart';
import '../screens/intervention_card.dart' show showReportDialog;
import '../state/account_controllers.dart';
import '../state/break_controller.dart';
import '../state/session_controller.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import '../ui/kit.dart';
import '../widgets/common.dart';
import 'window_controller.dart';

/// A break suggestion that takes the screen (or a floating window: the same
/// view, it scales with its size).
///
/// What you see, in order:
///  1. an amber tide rises from the bottom edge to *your break line* and
///     calms (its surface ripples with its speed, like the launch's liquid):
///     the day's pressure has reached the line;
///  2. the question lands above it, then its reason;
///  3. the controls arrive last (display → read-out → controls).
///
/// Mouse first: the keyboard is ignored for [armAfter], because this appears
/// while you are typing somewhere else. After that Enter takes the break and
/// Esc snoozes. Nobody answers for a minute → it steps back and waits as a
/// small card / notification.
class NudgeTakeover extends ConsumerStatefulWidget {
  const NudgeTakeover({super.key, required this.interventionId});
  final String interventionId;

  /// Keys do nothing until the view has been up this long.
  static const armAfter = Duration(milliseconds: 1500);

  @override
  ConsumerState<NudgeTakeover> createState() => _NudgeTakeoverState();
}

class _NudgeTakeoverState extends ConsumerState<NudgeTakeover> with TickerProviderStateMixin {
  late final _in = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  late final _hold = AnimationController(vsync: this, duration: WindowModeController.takeoverHold);
  late final ValueNotifier<int> _popped = ref.read(windowModeProvider.notifier).popped;
  Timer? _armTimer;
  bool _armed = false;
  bool _why = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    _popped.addListener(_start);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  /// Runs on mount and again when the native window has just popped into
  /// place (the first run may have played while it was still hidden).
  void _start() {
    if (!mounted) return;
    _armTimer?.cancel();
    setState(() => _armed = false);
    _armTimer = Timer(NudgeTakeover.armAfter, () {
      if (mounted) setState(() => _armed = true);
    });
    if (Motion.reduced(context)) {
      _in.value = 1;
    } else {
      _in.forward(from: 0);
    }
    _hold.forward(from: 0);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _popped.removeListener(_start);
    _armTimer?.cancel();
    _in.dispose();
    _hold.dispose();
    super.dispose();
  }

  Intervention? get _iv => ref.read(interventionProvider(widget.interventionId)).value;

  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent || !_armed || _busy) return false;
    if (e.logicalKey == LogicalKeyboardKey.enter || e.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _take();
      return true;
    }
    if (e.logicalKey == LogicalKeyboardKey.escape) {
      _snooze(_snoozeOptions.first);
      return true;
    }
    return false;
  }

  List<int> get _snoozeOptions {
    final o = ref.read(settingsProvider).value?.snoozeOptions ?? const [5, 10, 20];
    return o.isEmpty ? const [5] : o;
  }

  Future<void> _act(Future<void> Function(Intervention iv) run) async {
    final iv = _iv;
    if (iv == null || _busy) return;
    setState(() => _busy = true);
    await runGuarded(context, () => run(iv));
    if (mounted) setState(() => _busy = false);
  }

  void _take() => _act((iv) => ref.read(interventionActionsProvider).accept(iv));
  void _snooze(int m) => _act((iv) => ref.read(interventionActionsProvider).snooze(iv, m));
  void _dismiss() => _act((iv) => ref.read(interventionActionsProvider).dismiss(iv));

  /// 0..1 for the [i]-th piece of content: each lands a beat after the last.
  double _land(int i) => Curves.easeOutCubic.transform(((_in.value - 0.32 - i * 0.09) / 0.3).clamp(0.0, 1.0));

  Widget _piece(int i, Widget child) => AnimatedBuilder(
    animation: _in,
    child: child,
    builder: (context, child) {
      final t = _land(i);
      return Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 18 * (1 - t)), child: child),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    final iv = ref.watch(interventionProvider(widget.interventionId)).value;
    final live = ref.watch(liveSessionProvider).value;
    final minutes = iv == null ? 5 : (iv.suggestedBreakSec / 60).round().clamp(1, 99);
    final elapsed = live?.session.elapsedAt(DateTime.now()).inMinutes;
    final why = _why ? ref.watch(explanationProvider((widget.interventionId, ExplainDetail.short))).value : null;
    final snooze = _snoozeOptions;

    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Break suggestion',
      child: Material(
        color: p.bg,
        child: LayoutBuilder(
          builder: (context, box) {
            // Smaller than the design can hold: lay it out at the floating
            // window's size and scale the whole view down, rather than squeeze.
            const design = Size(760, 480);
            final tiny = box.maxWidth < 620 || box.maxHeight < 400;
            final view = _view(context, tiny ? design : box.biggest, p, iv, elapsed, minutes, why, snooze);
            if (!tiny) return view;
            return FittedBox(
              fit: BoxFit.contain,
              child: SizedBox.fromSize(size: design, child: view),
            );
          },
        ),
      ),
    );
  }

  Widget _view(
    BuildContext context,
    Size s,
    FlowPalette p,
    Intervention? iv,
    int? elapsed,
    int minutes,
    Explanation? why,
    List<int> snooze,
  ) {
    final u = s.shortestSide; // everything scales from this
    final pad = (s.width * 0.08).clamp(24.0, 140.0);
    final headline = (u * 0.19).clamp(44.0, 170.0);
    final body = (u * 0.034).clamp(15.0, 26.0);
    final small = (u * 0.022).clamp(12.0, 16.0);
    final roomy = u >= 420;
    return Stack(
      children: [
        // 1. the tide and the break line
        Positioned.fill(
          child: RepaintBoundary(child: CustomPaint(painter: _TidePainter(p, _in, MediaQuery.textScalerOf(context)))),
        ),
        // 2 + 3. the question, its reason, the controls
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, pad * 0.5, pad, pad * 0.45),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _piece(
                  0,
                  Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(color: p.amber, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          flowCaps(elapsed == null || elapsed < 1 ? 'Break suggestion' : 'Break suggestion · $elapsed min in'),
                          style: FlowType.label(p, size: small * 0.8, color: p.text2),
                        ),
                      ),
                      IconButton(
                        tooltip: 'This suggestion was wrong',
                        icon: Icon(Icons.flag_outlined, size: 18, color: p.text3),
                        onPressed: iv == null ? null : () => showReportDialog(context, ref, iv.id),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
                _piece(
                  1,
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text('Take $minutes?', style: FlowType.headline(p, size: headline).copyWith(height: 0.95)),
                  ),
                ),
                SizedBox(height: u * 0.03),
                _piece(
                  2,
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: math.min(s.width - pad * 2, 760)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          iv?.message ?? 'A good moment for a short break.',
                          maxLines: roomy ? 3 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: FlowType.note(p, size: body, color: p.text1),
                        ),
                        if (iv != null && iv.shortReason.isNotEmpty && !_why) ...[
                          const SizedBox(height: 6),
                          Text(
                            iv.shortReason,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: FlowType.note(p, size: body * 0.82),
                          ),
                        ],
                        AnimatedSize(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topLeft,
                          child: !_why
                              ? const SizedBox(width: double.infinity)
                              : Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: _Why(
                                    bars: why == null
                                        ? const []
                                        : [
                                            for (final c in why.contributions)
                                              (
                                                name: c.name,
                                                share: why.combinedScore <= 0 ? 0.0 : (c.contribution / why.combinedScore).clamp(0.0, 1.0),
                                              ),
                                          ],
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(flex: 3),
                _piece(
                  3,
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Pressable(
                        tone: PressableTone.primary,
                        onPressed: iv == null || _busy ? null : _take,
                        padding: EdgeInsets.symmetric(horizontal: roomy ? 26 : 16, vertical: roomy ? 16 : 10),
                        child: Text('Take a $minutes min break', style: TextStyle(fontSize: roomy ? 16 : 13.5)),
                      ),
                      for (final m in snooze.take(3))
                        Pressable(
                          onPressed: iv == null || _busy ? null : () => _snooze(m),
                          padding: EdgeInsets.symmetric(horizontal: roomy ? 16 : 12, vertical: roomy ? 14 : 9),
                          semanticLabel: 'Snooze $m minutes',
                          child: Text(m == snooze.first ? 'Snooze $m min' : '$m min'),
                        ),
                      _Quiet(_why ? 'Hide why' : 'Why?', () => setState(() => _why = !_why)),
                      _Quiet('Dismiss', iv == null || _busy ? null : _dismiss),
                      _Quiet('Not now', () => ref.read(windowModeProvider.notifier).retreat()),
                    ],
                  ),
                ),
                SizedBox(height: roomy ? 18 : 10),
                // keys, once they are live; and when it will step back
                _piece(
                  4,
                  Row(
                    children: [
                      Expanded(
                        child: AnimatedOpacity(
                          opacity: _armed ? 1 : 0,
                          duration: Motion.fade,
                          child: Text(
                            'Enter takes the break · Esc snoozes ${snooze.first} min',
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            style: FlowType.chart(p, size: small * 0.82),
                          ),
                        ),
                      ),
                      Text('steps back by itself', style: FlowType.chart(p, size: small * 0.82)),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 72,
                        height: 3,
                        child: AnimatedBuilder(
                          animation: _hold,
                          builder: (context, _) => ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(value: 1 - _hold.value, backgroundColor: p.hairline, color: p.text2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Quiet extends StatelessWidget {
  const _Quiet(this.label, this.onTap);
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: p.text1,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        minimumSize: Size.zero,
      ),
      child: Text(label, style: TextStyle(fontSize: 13, color: onTap == null ? p.text3 : p.text1)),
    );
  }
}

/// What drove the suggestion: one line per driver, share as a bar.
class _Why extends StatelessWidget {
  const _Why({required this.bars});
  final List<({String name, double share})> bars;
  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    if (bars.isEmpty) return Text('Working out why…', style: FlowType.chart(p, size: 12));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, b) in bars.take(3).indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Text('${(b.share * 100).round()}%', style: FlowType.chart(p, size: 12, color: p.text1)),
                ),
                SizedBox(
                  width: 140,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: b.share),
                      duration: Duration(milliseconds: 500 + i * 120),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => LinearProgressIndicator(
                        value: v,
                        minHeight: 6,
                        backgroundColor: p.hairline,
                        color: i == 0 ? p.amber : p.pastHeavy,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    b.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: p.text1),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The amber tide. It rises from the bottom edge to the break line with a
/// critically damped spring; the surface ripples in proportion to how fast it
/// is moving, so it is lively on the way up and flat once it has arrived.
/// The dashed line it reaches is the Score's nudge line.
class _TidePainter extends CustomPainter {
  _TidePainter(this.p, this.anim, this.scaler) : super(repaint: anim);
  final FlowPalette p;
  final Animation<double> anim;
  final TextScaler scaler;

  /// Where the tide rests, as a fraction of the height from the bottom.
  static const level = 0.36;

  @override
  void paint(Canvas c, Size s) {
    // seconds on the entrance clock (controller is 1.5 s long)
    final t = anim.value * 1.5;
    final rise = anim.isCompleted ? 1.0 : Motion.settleAt(t, response: 0.62);
    final speed = anim.isCompleted ? 0.0 : (Motion.settleAt(t + 0.016, response: 0.62) - rise) / 0.016; // 1/s
    final rest = s.height * (1 - level);
    final y = s.height - (s.height - rest) * rise;
    final amp = math.min(speed, 2.6) * s.height * 0.012;

    final tide = Path()..moveTo(0, s.height);
    const seg = 28;
    for (var i = 0; i <= seg; i++) {
      final x = s.width * i / seg;
      tide.lineTo(x, y + amp * math.sin(i / seg * math.pi * 3.2 + t * 7));
    }
    tide
      ..lineTo(s.width, s.height)
      ..close();
    c.drawPath(
      tide,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(p.amberTint, p.bg, 0.2)!, Color.lerp(p.amberTint, p.bg, 0.55)!],
        ).createShader(Rect.fromLTWH(0, rest, s.width, s.height - rest)),
    );

    // the break line: dashed until the tide reaches it, then it is the surface
    final reach = ((rise - 0.9) / 0.1).clamp(0.0, 1.0);
    final dash = Paint()
      ..color = p.amber.withValues(alpha: 0.35 + 0.45 * reach)
      ..strokeWidth = 1.4;
    for (var x = 0.0; x < s.width; x += 12) {
      c.drawLine(Offset(x, rest), Offset(math.min(x + 6, s.width), rest), dash);
    }
    final tp = TextPainter(
      text: TextSpan(
        text: flowCaps('your break line'),
        style: FlowType.label(p, size: 9.5, color: p.amber.withValues(alpha: 0.5 + 0.5 * reach)),
      ),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    tp.paint(c, Offset(s.width - tp.width - 18, rest - tp.height - 6));
  }

  @override
  bool shouldRepaint(_TidePainter o) => o.p != p || o.scaler != scaler;
}
