import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/motion.dart';
import '../theme/tokens.dart';

enum DialMode {
  /// Choosing a duration before a session.
  pick,

  /// Session running: the dashed ring IS the progress ring (fills with the clock).
  progress,

  /// Break running: dashes drain with the clock.
  drain,
}

/// The dashed-ring duration dial (DESIGN_SPEC §2, BlockIt-style).
///
/// - Ticks every 5 min, longer every 15, longest every 60; ✦ mark at the suggestion.
/// - 0→value dashes filled (dark neutral), the rest faint; accent indicator dot.
/// - Dashes near the dot grow/darken with distance falloff while turning.
/// - Each 5-min step pops the dash under the dot (+ selection haptic).
/// - Rubber band beyond [min]/[max]; notched mouse wheel = one step per notch.
/// - One turn is 3 h. Past it the dial keeps going on a **second, outer ring**
///   (amber: this long, breaks are part of it) up to [max], 4 h by default:
///   the most Flow plans in one go. The outer ring fades in as you near a
///   full turn so you can see there is more; crossing it sends a ripple out
///   from the ring and the handle hops outward onto the new one. A stop mark
///   shows where it ends.
/// - In [DialMode.progress]/[DialMode.drain] the same ring shows elapsed/remaining.
class DurationDial extends StatefulWidget {
  const DurationDial({
    super.key,
    required this.minutes,
    required this.onChanged,
    this.suggestion,
    this.min = 15,
    this.max = healthyMax,
    this.size = 168,
    this.mode = DialMode.pick,
    this.fraction = 0,
    this.centerLabel,
    this.onCenterTap,
    this.centerTapHint = 'Start',
  });

  final int minutes;
  final ValueChanged<int>? onChanged;
  final int? suggestion;
  final int min;
  final int max;
  final double size;
  final DialMode mode;

  /// 0..1 for progress (elapsed) or drain (remaining).
  final double fraction;

  /// Overrides the centre text (e.g. a countdown).
  final String? centerLabel;
  final VoidCallback? onCenterTap;
  final String centerTapHint;

  static const step = 5;
  static const fullTurn = 180; // minutes per revolution

  /// The longest single session Flow will plan. Longer than this is better
  /// as two sessions with a real break between (the dial says so at the stop).
  static const healthyMax = 240;

  @override
  State<DurationDial> createState() => _DurationDialState();
}

class _DurationDialState extends State<DurationDial> with TickerProviderStateMixin {
  late final _v = SpringValue(vsync: this, initial: widget.minutes.toDouble());
  late final _pop = SpringValue(vsync: this, initial: 0);
  // 0 = on the first turn, 1 = on the second: moves the handle outward
  late final _lap = SpringValue(vsync: this, initial: widget.minutes > DurationDial.fullTurn ? 1 : 0);
  // the ripple sent out when a full turn is crossed
  late final _ripple = AnimationController(vsync: this, duration: const Duration(milliseconds: 620), value: 1);
  bool _over = false;
  late final _drawIn = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  double _finger = 0;
  bool _dragging = false;
  bool _hoverCenter = false;
  int _lastStep = 0;

  @override
  void initState() {
    super.initState();
    _lastStep = widget.minutes ~/ DurationDial.step;
    _over = widget.minutes > DurationDial.fullTurn;
    Motion.enterOnMount(context, _drawIn, () => mounted);
  }

  @override
  void didUpdateWidget(DurationDial old) {
    super.didUpdateWidget(old);
    if (!_dragging && old.minutes != widget.minutes) {
      _v.animateTo(widget.minutes.toDouble(), spring: Motion.settle, reduced: Motion.reduced(context));
      _crossed(widget.minutes.toDouble());
    }
  }

  @override
  void dispose() {
    _v.dispose();
    _pop.dispose();
    _lap.dispose();
    _ripple.dispose();
    _drawIn.dispose();
    super.dispose();
  }

  double _angleOf(Offset local) {
    final c = Offset(widget.size / 2, widget.size / 2);
    final d = local - c;
    var a = math.atan2(d.dx, -d.dy); // 0 at top, clockwise
    if (a < 0) a += 2 * math.pi;
    return a;
  }

  double _minutesAt(double angle) => angle / (2 * math.pi) * DurationDial.fullTurn;

  /// Entering or leaving the second turn: the handle changes ring, and going
  /// up a ripple leaves the first one (so it is felt as "another lap").
  void _crossed(double v) {
    final over = v > DurationDial.fullTurn + 0.01;
    if (over == _over) return;
    _over = over;
    final reduced = Motion.reduced(context);
    _lap.animateTo(over ? 1 : 0, spring: Motion.snap, reduced: reduced);
    if (over && !reduced) {
      HapticFeedback.mediumImpact();
      _ripple.forward(from: 0);
    }
  }

  void _tickPop(double v) {
    final s = (v / DurationDial.step).round();
    if (s != _lastStep) {
      _lastStep = s;
      HapticFeedback.selectionClick();
      _pop.value = 1;
      _pop.animateTo(0, spring: Motion.snap);
    }
  }

  void _show(double raw) {
    // rubber band past min/max, ceiling = 30 minutes of travel
    double v = raw;
    final lo = widget.min.toDouble(), hi = widget.max.toDouble();
    if (raw < lo) v = lo - RubberBand.offset(lo - raw, 30, 0.4);
    if (raw > hi) v = hi + RubberBand.offset(raw - hi, 30, 0.4);
    _v.value = v; // 1:1 with the hand while dragging
    _tickPop(v.clamp(lo, hi));
    _crossed(v.clamp(lo, hi));
  }

  void _commit() {
    final snapped = ((_v.value / DurationDial.step).round() * DurationDial.step).clamp(widget.min, widget.max);
    _v.animateTo(snapped.toDouble(), spring: Motion.snap, reduced: Motion.reduced(context));
    if (snapped != widget.minutes) widget.onChanged?.call(snapped);
  }

  void _stepBy(int n) {
    if (widget.onChanged == null) return;
    final next = (widget.minutes + n * DurationDial.step).clamp(widget.min, widget.max);
    if (next == widget.minutes) {
      // refused at the limit: rubber band out and back (no shake)
      _v.animateTo(widget.minutes + n * 2.5, spring: Motion.follow);
      Future.delayed(const Duration(milliseconds: 90), () {
        if (mounted) _v.animateTo(widget.minutes.toDouble(), spring: Motion.snap);
      });
      return;
    }
    _tickPop(next.toDouble());
    _crossed(next.toDouble());
    widget.onChanged!(next);
  }

  bool _inCenter(Offset local) => (local - Offset(widget.size / 2, widget.size / 2)).distance < widget.size * 0.28;

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    final interactive = widget.mode == DialMode.pick && widget.onChanged != null;
    Widget dial = AnimatedBuilder(
      animation: Listenable.merge([_v.animation, _pop.animation, _drawIn, _lap.animation, _ripple]),
      builder: (context, _) => CustomPaint(
        size: Size.square(widget.size),
        painter: _DialPainter(
          p: p,
          value: _v.value,
          min: widget.min,
          max: widget.max,
          lap: _lap.value.clamp(0.0, 1.2),
          ripple: _ripple.value,
          suggestion: widget.suggestion,
          pop: _pop.value,
          drawIn: Curves.easeOut.transform(_drawIn.value),
          mode: widget.mode,
          fraction: widget.fraction,
          active: _dragging,
        ),
      ),
    );

    dial = Stack(
      alignment: Alignment.center,
      children: [
        dial,
        IgnorePointer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _v.animation,
                builder: (context, _) {
                  final live = ((_v.value / DurationDial.step).round() * DurationDial.step).clamp(widget.min, widget.max);
                  final label = widget.centerLabel ?? '$live';
                  // fit the face: 2–3 digits at full size, longer clocks scale down
                  final digits = label.replaceAll(RegExp(r'\D'), '').length;
                  final fs = widget.size * 0.22 * (3 / digits.clamp(3, 8)).clamp(0.5, 1.0);
                  return TabularNumeral(label, style: FlowType.numeral(p, fs));
                },
              ),
              const SizedBox(height: 2),
              AnimatedSwitcher(
                duration: Motion.fade,
                child: Text(
                  (_hoverCenter && widget.onCenterTap != null ? widget.centerTapHint : (widget.mode == DialMode.pick ? 'min' : ''))
                      .toUpperCase(),
                  key: ValueKey(_hoverCenter),
                  style: FlowType.label(p, size: 9.5, color: _hoverCenter ? p.text1 : p.text3),
                ),
              ),
              // past a full turn: say it in hours, in the second ring's colour
              AnimatedSize(
                duration: Motion.fade,
                child: widget.mode == DialMode.pick && _over
                    ? Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: AnimatedBuilder(
                          animation: _v.animation,
                          builder: (context, _) {
                            final live = ((_v.value / DurationDial.step).round() * DurationDial.step).clamp(widget.min, widget.max);
                            return Text(
                              flowCaps(
                                live >= widget.max ? '${flowDuration(live, caps: true)} · the most' : flowDuration(live, caps: true),
                              ),
                              style: FlowType.label(p, size: 8.5, color: p.amber),
                            );
                          },
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    );

    dial = Listener(
      onPointerSignal: interactive
          ? (e) {
              if (e is PointerScrollEvent) {
                GestureBinding.instance.pointerSignalResolver.register(e, (_) => _stepBy(e.scrollDelta.dy > 0 ? -1 : 1));
              }
            }
          : null,
      child: MouseRegion(
        cursor: interactive ? SystemMouseCursors.grab : SystemMouseCursors.basic,
        onHover: (e) {
          final c = _inCenter(e.localPosition);
          if (c != _hoverCenter) setState(() => _hoverCenter = c);
        },
        onExit: (_) {
          if (_hoverCenter) setState(() => _hoverCenter = false);
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            if (_inCenter(d.localPosition)) {
              widget.onCenterTap?.call();
            } else if (interactive) {
              var m = _minutesAt(_angleOf(d.localPosition));
              // a tap on the outer ring (or anywhere while already past a
              // full turn, within its reach) means the second turn
              final r = (d.localPosition - Offset(widget.size / 2, widget.size / 2)).distance;
              final outer = r > widget.size * 0.36 + 12 || widget.minutes > DurationDial.fullTurn;
              if (outer && m + DurationDial.fullTurn <= widget.max) m += DurationDial.fullTurn;
              widget.onChanged!(((m / DurationDial.step).round() * DurationDial.step).clamp(widget.min, widget.max));
            }
          },
          onPanStart: interactive
              ? (d) {
                  setState(() => _dragging = true);
                  _finger = _v.value;
                }
              : null,
          onPanUpdate: interactive
              ? (d) {
                  // Close to the hub a pixel of hand movement is a huge angle:
                  // ignore it there instead of letting the ring jump.
                  final hub = Offset(widget.size / 2, widget.size / 2);
                  if ((d.localPosition - hub).distance < widget.size * 0.12 ||
                      (d.localPosition - d.delta - hub).distance < widget.size * 0.12) {
                    return;
                  }
                  // angular delta → minutes; tolerate the 0/360 wrap
                  final a0 = _angleOf(d.localPosition - d.delta);
                  final a1 = _angleOf(d.localPosition);
                  var da = a1 - a0;
                  if (da > math.pi) da -= 2 * math.pi;
                  if (da < -math.pi) da += 2 * math.pi;
                  _finger += _minutesAt(da.abs()) * da.sign;
                  _show(_finger);
                }
              : null,
          onPanEnd: interactive
              ? (_) {
                  setState(() => _dragging = false);
                  _commit();
                }
              : null,
          child: dial,
        ),
      ),
    );

    return Semantics(
      slider: interactive,
      label: widget.mode == DialMode.pick ? 'Session length' : 'Session progress',
      value: '${widget.minutes} minutes',
      increasedValue: interactive ? '${(widget.minutes + DurationDial.step).clamp(widget.min, widget.max)} minutes' : null,
      decreasedValue: interactive ? '${(widget.minutes - DurationDial.step).clamp(widget.min, widget.max)} minutes' : null,
      onIncrease: interactive ? () => _stepBy(1) : null,
      onDecrease: interactive ? () => _stepBy(-1) : null,
      child: FocusableActionDetector(
        enabled: interactive,
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowUp): _DialStep(1),
          SingleActivator(LogicalKeyboardKey.arrowRight): _DialStep(1),
          SingleActivator(LogicalKeyboardKey.arrowDown): _DialStep(-1),
          SingleActivator(LogicalKeyboardKey.arrowLeft): _DialStep(-1),
        },
        actions: {
          _DialStep: CallbackAction<_DialStep>(onInvoke: (i) => _stepBy(i.n)),
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onCenterTap?.call()),
        },
        child: dial,
      ),
    );
  }
}

class _DialStep extends Intent {
  const _DialStep(this.n);
  final int n;
}

class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.p,
    required this.value,
    required this.min,
    this.max = DurationDial.healthyMax,
    this.lap = 0,
    this.ripple = 1,
    required this.suggestion,
    required this.pop,
    required this.drawIn,
    required this.mode,
    required this.fraction,
    required this.active,
  });

  final FlowPalette p;
  final double value;
  final int min;
  final int max;

  /// 0 on the first turn → 1 on the second (springs, may overshoot a little).
  final double lap;

  /// 0 → 1 once, each time a full turn is crossed going up.
  final double ripple;
  final int? suggestion;
  final double pop;
  final double drawIn;
  final DialMode mode;
  final double fraction;
  final bool active;

  static const ticks = DurationDial.fullTurn ~/ DurationDial.step; // 36

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final R = size.width * 0.36;
    // face: a raised disc inside the ring
    canvas.drawCircle(c.translate(0, 1.5), R - 6, Paint()..color = Faces.ground(p.raised).withValues(alpha: 0.35));
    canvas.drawCircle(c, R - 6, Paint()..color = p.raised);
    canvas.drawCircle(
      c,
      R - 6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = p.hairline,
    );

    // pick: the ring is a 3 h scale. progress/drain: the ring IS this session/break.
    final valueTick = mode == DialMode.pick ? value / DurationDial.step : ticks.toDouble();
    final popTick = valueTick.round();
    final filledUpTo = mode == DialMode.pick ? valueTick : ticks * fraction.clamp(0.0, 1.0);
    final fillColor = switch (mode) {
      DialMode.pick => p.selected,
      DialMode.progress => p.accent,
      DialMode.drain => p.amber,
    };

    for (var t = 0; t < ticks; t++) {
      // line-draw in: ticks appear staggered from 0
      final appear = ((drawIn * (ticks + 6)) - t).clamp(0.0, 1.0);
      if (appear <= 0) continue;
      final angle = -math.pi / 2 + t * 2 * math.pi / ticks;
      var len = t % 12 == 0 ? 9.0 : (t % 3 == 0 ? 6.0 : 3.6);
      // falloff: dashes near the dot grow (pick mode only)
      if (mode == DialMode.pick) {
        final dist = (t - valueTick).abs();
        final near = math.max(0.0, 1 - dist / 4);
        len += near * 3.2;
        if (t == popTick) len += pop * 3;
      }
      final filled = mode == DialMode.pick ? t <= filledUpTo + 0.001 : t < filledUpTo;
      final col = filled ? fillColor : p.text3.withValues(alpha: 0.45);
      final r1 = R, r2 = R + len * appear;
      final dir = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        c + dir * r1,
        c + dir * r2,
        Paint()
          ..color = col
          ..strokeWidth = t % 3 == 0 ? 1.5 : 1.2
          ..strokeCap = StrokeCap.round,
      );
    }

    // ── the second turn ──
    // Its ring sits outside the first. It fades in over the last half hour
    // of the first turn (so you can see the dial goes on), fills in amber as
    // you go round again, and ends at a stop mark at [max].
    final extra = max - DurationDial.fullTurn;
    var outerVis = 0.0;
    if (mode == DialMode.pick && extra > 0) {
      final overTick = valueTick - ticks; // ticks into the second turn (negative before it)
      final limitTick = extra / DurationDial.step;
      outerVis = ((value - (DurationDial.fullTurn - 30)) / 30).clamp(0.0, 1.0);
      if (outerVis > 0) {
        const gap = 15.0; // from the first ring's base to the outer ring's
        for (var t = 0; t <= limitTick; t++) {
          final angle = -math.pi / 2 + t * 2 * math.pi / ticks;
          var len = t % 3 == 0 ? 5.0 : 3.2;
          final near = math.max(0.0, 1 - (t - overTick).abs() / 4) * lap.clamp(0.0, 1.0);
          len += near * 3;
          if (overTick > 0 && t == overTick.round()) len += pop * 3;
          final filled = overTick >= 0 && t <= overTick + 0.001;
          final dir = Offset(math.cos(angle), math.sin(angle));
          canvas.drawLine(
            c + dir * (R + gap),
            c + dir * (R + gap + len),
            Paint()
              ..color = filled ? p.amber : p.text3.withValues(alpha: 0.4 * outerVis)
              ..strokeWidth = t % 3 == 0 ? 1.5 : 1.2
              ..strokeCap = StrokeCap.round,
          );
        }
        // the stop: where a single session ends. It thickens as you reach it.
        final sa = -math.pi / 2 + limitTick * 2 * math.pi / ticks + 0.055;
        final sd = Offset(math.cos(sa), math.sin(sa));
        final atStop = (1 - (limitTick - overTick).abs() / 2).clamp(0.0, 1.0);
        canvas.drawLine(
          c + sd * (R + gap - 2),
          c + sd * (R + gap + 9 + atStop * 2),
          Paint()
            ..color = Color.lerp(p.text2.withValues(alpha: outerVis), p.amber, atStop)!
            ..strokeWidth = 2 + atStop
            ..strokeCap = StrokeCap.round,
        );
      }
      // crossing a full turn: one ripple leaves the first ring
      if (ripple < 1) {
        final e = Curves.easeOutCubic.transform(ripple);
        canvas.drawCircle(
          c,
          R + 4 + e * 26,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4 * (1 - e) + 0.4
            ..color = p.amber.withValues(alpha: 0.55 * (1 - e)),
        );
      }
    }

    // below-minimum arc is muted (you can't pick under [min])
    if (mode == DialMode.pick && min > 0) {
      final sweep = min / DurationDial.fullTurn * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: R - 2),
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = p.hairline,
      );
    }

    // ✦ suggestion mark (outside the ring)
    if (mode == DialMode.pick && suggestion != null) {
      final a = -math.pi / 2 + suggestion! / DurationDial.fullTurn * 2 * math.pi;
      // steps outward to clear the second ring when that is showing
      final pos = c + Offset(math.cos(a), math.sin(a)) * (R + 17 + 12 * outerVis);
      final path = Path();
      for (var i = 0; i < 8; i++) {
        final rr = i.isEven ? 3.6 : 1.3;
        final aa = i * math.pi / 4 - math.pi / 2;
        final pt = pos + Offset(math.cos(aa), math.sin(aa)) * rr;
        i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = p.text2);
    }

    // accent indicator dot (pick) / progress head (progress, drain)
    final headTick = mode == DialMode.pick ? valueTick : filledUpTo;
    final a = -math.pi / 2 + headTick * 2 * math.pi / ticks;
    // on the second turn the handle rides the outer ring, in its colour
    final out = mode == DialMode.pick ? lap : 0.0;
    final dot = c + Offset(math.cos(a), math.sin(a)) * (R - 14 + 36 * out);
    final dotColor = mode == DialMode.drain ? p.amber : Color.lerp(p.accent, p.amber, out.clamp(0.0, 1.0))!;
    canvas.drawCircle(dot, active ? 5.2 : 4.4, Paint()..color = dotColor);
  }

  @override
  bool shouldRepaint(_DialPainter o) =>
      o.value != value ||
      o.pop != pop ||
      o.drawIn != drawIn ||
      o.mode != mode ||
      o.fraction != fraction ||
      o.active != active ||
      o.lap != lap ||
      o.ripple != ripple ||
      o.max != max ||
      o.p != p ||
      o.suggestion != suggestion;
}
