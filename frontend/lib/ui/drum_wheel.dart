import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../theme/motion.dart';
import '../theme/tokens.dart';

/// The drum wheel (DESIGN_SPEC §2): ridges on a cylinder that bunch and fade
/// toward the edges, under a fixed marker.
///
/// - Step ends are built in: hovering the outer thirds shows a chevron; a click
///   steps once (the visible, primary control; D7).
/// - Drag / trackpad: FOLLOW → friction → snap to the projected detent.
/// - Notched mouse wheel: exactly one step per notch.
/// - Rubber band past [min]/[max].
/// - No text inside the wheel (Hairline rule 10): the read-out names the value.
class DrumWheel extends StatefulWidget {
  const DrumWheel({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.axis = Axis.vertical,
    this.length = 120,
    this.thickness = 30,
    this.semanticLabel = 'Wheel',
    this.semanticValue,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final Axis axis;
  final double length;
  final double thickness;
  final String semanticLabel;
  final String Function(int)? semanticValue;

  static const ridgeGap = 7.0; // px per step along the drum surface

  @override
  State<DrumWheel> createState() => _DrumWheelState();
}

class _DrumWheelState extends State<DrumWheel> with SingleTickerProviderStateMixin {
  late final _pos = SpringValue(vsync: this, initial: widget.value.toDouble());
  double _finger = 0;
  bool _dragging = false;
  int? _hoverEnd; // -1 = start end, 1 = far end
  int _lastStep = 0;

  bool get _vertical => widget.axis == Axis.vertical;

  @override
  void initState() {
    super.initState();
    _lastStep = widget.value;
  }

  @override
  void didUpdateWidget(DrumWheel old) {
    super.didUpdateWidget(old);
    if (!_dragging && old.value != widget.value) {
      _pos.animateTo(widget.value.toDouble(), spring: Motion.snap, reduced: Motion.reduced(context));
    }
  }

  @override
  void dispose() {
    _pos.dispose();
    super.dispose();
  }

  void _emit(int v) {
    final c = v.clamp(widget.min, widget.max);
    if (c != _lastStep) {
      _lastStep = c;
      HapticFeedback.selectionClick();
    }
    if (c != widget.value) widget.onChanged(c);
  }

  void _step(int d) {
    final next = widget.value + d;
    if (next < widget.min || next > widget.max) {
      // refused: rubber-band out and back
      _pos.animateTo(widget.value + d * 0.35, spring: Motion.follow);
      Future.delayed(const Duration(milliseconds: 90), () {
        if (mounted) _pos.animateTo(widget.value.toDouble(), spring: Motion.snap);
      });
      return;
    }
    _emit(next);
  }

  double _banded(double raw) {
    final lo = widget.min.toDouble(), hi = widget.max.toDouble();
    const g = DrumWheel.ridgeGap;
    if (raw < lo) return lo - RubberBand.offset((lo - raw) * g, widget.length / 2, 0.4) / g;
    if (raw > hi) return hi + RubberBand.offset((raw - hi) * g, widget.length / 2, 0.4) / g;
    return raw;
  }

  void _dragUpdate(double deltaAlong) {
    // dragging the surface "down" (or right) moves to earlier values
    _finger -= deltaAlong / DrumWheel.ridgeGap;
    _pos.animateTo(_banded(_finger), spring: Motion.follow);
  }

  void _dragEnd(double velocityAlong) {
    _dragging = false;
    // project where friction would stop it, then snap to that detent
    final v0 = -velocityAlong / DrumWheel.ridgeGap; // steps per second
    final sim = FrictionSimulation(0.135, _pos.value, v0);
    final projected = sim.finalX.round().clamp(widget.min, widget.max);
    _pos.animateTo(projected.toDouble(), spring: Motion.snap, velocity: v0, reduced: Motion.reduced(context));
    _emit(projected);
    setState(() {});
  }

  int? _endAt(Offset local) {
    final along = _vertical ? local.dy : local.dx;
    if (along < widget.length / 3) return -1;
    if (along > widget.length * 2 / 3) return 1;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    final size = _vertical ? Size(widget.thickness, widget.length) : Size(widget.length, widget.thickness);

    Widget wheel = AnimatedBuilder(
      animation: _pos.animation,
      builder: (context, _) => CustomPaint(
        size: size,
        painter: _DrumPainter(
          p,
          _pos.value,
          widget.axis,
          _hoverEnd,
          atStart: widget.value <= widget.min,
          atEnd: widget.value >= widget.max,
        ),
      ),
    );

    wheel = Listener(
      onPointerSignal: (e) {
        if (e is PointerScrollEvent) {
          GestureBinding.instance.pointerSignalResolver.register(e, (_) {
            final d = _vertical ? e.scrollDelta.dy : (e.scrollDelta.dx != 0 ? e.scrollDelta.dx : e.scrollDelta.dy);
            if (d.abs() >= 40) {
              _step(d.sign.toInt()); // notched wheel: one step per notch
            } else {
              _finger = _pos.value + d / DrumWheel.ridgeGap;
              _pos.animateTo(_banded(_finger), spring: Motion.follow);
              _emit(_finger.round());
            }
          });
        }
      },
      child: MouseRegion(
        cursor: _hoverEnd != null ? SystemMouseCursors.click : SystemMouseCursors.resizeUpDown,
        onHover: (e) => setState(() => _hoverEnd = _endAt(e.localPosition)),
        onExit: (_) => setState(() => _hoverEnd = null),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            final end = _endAt(d.localPosition);
            if (end != null) _step(end);
          },
          onVerticalDragStart: _vertical
              ? (_) {
                  _dragging = true;
                  _finger = _pos.value;
                }
              : null,
          onVerticalDragUpdate: _vertical ? (d) => _dragUpdate(d.delta.dy) : null,
          onVerticalDragEnd: _vertical ? (d) => _dragEnd(d.velocity.pixelsPerSecond.dy) : null,
          onHorizontalDragStart: !_vertical
              ? (_) {
                  _dragging = true;
                  _finger = _pos.value;
                }
              : null,
          onHorizontalDragUpdate: !_vertical ? (d) => _dragUpdate(d.delta.dx) : null,
          onHorizontalDragEnd: !_vertical ? (d) => _dragEnd(d.velocity.pixelsPerSecond.dx) : null,
          child: wheel,
        ),
      ),
    );

    return Semantics(
      slider: true,
      label: widget.semanticLabel,
      value: widget.semanticValue?.call(widget.value) ?? '${widget.value}',
      increasedValue: widget.value < widget.max ? (widget.semanticValue?.call(widget.value + 1) ?? '${widget.value + 1}') : null,
      decreasedValue: widget.value > widget.min ? (widget.semanticValue?.call(widget.value - 1) ?? '${widget.value - 1}') : null,
      onIncrease: widget.value < widget.max ? () => _step(1) : null,
      onDecrease: widget.value > widget.min ? () => _step(-1) : null,
      child: FocusableActionDetector(
        shortcuts: {
          SingleActivator(_vertical ? LogicalKeyboardKey.arrowDown : LogicalKeyboardKey.arrowRight): const _WheelStep(1),
          SingleActivator(_vertical ? LogicalKeyboardKey.arrowUp : LogicalKeyboardKey.arrowLeft): const _WheelStep(-1),
        },
        actions: {_WheelStep: CallbackAction<_WheelStep>(onInvoke: (i) => _step(i.d))},
        child: wheel,
      ),
    );
  }
}

class _WheelStep extends Intent {
  const _WheelStep(this.d);
  final int d;
}

class _DrumPainter extends CustomPainter {
  _DrumPainter(this.p, this.pos, this.axis, this.hoverEnd, {required this.atStart, required this.atEnd});
  final FlowPalette p;
  final double pos;
  final Axis axis;
  final int? hoverEnd;
  final bool atStart, atEnd;

  @override
  void paint(Canvas canvas, Size size) {
    final vertical = axis == Axis.vertical;
    final along = vertical ? size.height : size.width;
    final across = vertical ? size.width : size.height;
    canvas.save();
    if (!vertical) {
      // draw in vertical space, rotate for horizontal
      canvas.translate(0, size.height);
      canvas.rotate(-math.pi / 2);
    }
    final w = across, h = along;
    // the well (recessed)
    final well = RRect.fromLTRBR(0, 0, w, h, Radius.circular(w * 0.38));
    canvas.drawRRect(well, Paint()..color = p.recess);
    canvas.drawRRect(
      well,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = p.hairline,
    );
    // drum surface: ridges placed on a cylinder of radius h/2
    final r = h / 2 - 6;
    final frac = pos - pos.floorToDouble();
    const gap = 7.0;
    final count = (math.pi * r / gap).ceil();
    for (var i = -count; i <= count; i++) {
      final arc = (i - frac) * gap; // distance along the surface from the centre
      final theta = arc / r;
      if (theta.abs() >= math.pi / 2) continue;
      final y = h / 2 + r * math.sin(theta);
      final facing = math.cos(theta); // 1 at centre, 0 at the edge
      final inset = w * 0.22 + (1 - facing) * w * 0.12;
      canvas.drawLine(
        Offset(inset, y),
        Offset(w - inset, y),
        Paint()
          ..color = p.text3.withValues(alpha: 0.15 + 0.6 * facing)
          ..strokeWidth = 0.6 + 0.8 * facing
          ..strokeCap = StrokeCap.round,
      );
    }
    // fixed marker (selection = dark neutral, never the accent)
    canvas.drawRRect(
      RRect.fromLTRBR(w * 0.16, h / 2 - 1.6, w * 0.84, h / 2 + 1.6, const Radius.circular(1.6)),
      Paint()..color = p.selected,
    );
    // built-in step ends: chevrons appear on hover (faint when at a limit)
    void chevron(double y, bool up, bool disabled) {
      final c = Offset(w / 2, y);
      final path = Path()
        ..moveTo(c.dx - 4, c.dy + (up ? 2 : -2))
        ..lineTo(c.dx, c.dy + (up ? -2 : 2))
        ..lineTo(c.dx + 4, c.dy + (up ? 2 : -2));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round
          ..color = disabled ? p.text3.withValues(alpha: 0.35) : p.text1,
      );
    }

    if (hoverEnd == -1) chevron(10, true, atStart);
    if (hoverEnd == 1) chevron(h - 10, false, atEnd);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DrumPainter o) => o.pos != pos || o.hoverEnd != hoverEnd || o.p != p || o.atStart != atStart || o.atEnd != atEnd;
}
