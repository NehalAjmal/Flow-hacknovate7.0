import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/motion.dart';
import '../theme/tokens.dart';

export 'pressable.dart';

// ── Recessed well (holds a value) ──────────────────────────────────────────

/// Paints a recess: fill, a uniform rounded hairline, and a darker 1 px line
/// just inside the top edge (reads as inset, no shadow). Flutter forbids
/// borderRadius with non-uniform border colours, so this is painted.
class RecessPainter extends CustomPainter {
  RecessPainter(this.p, {this.radius = 8, this.focused = false});
  final FlowPalette p;
  final double radius;
  final bool focused;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    canvas.drawRRect(r, Paint()..color = p.recess);
    canvas.save();
    canvas.clipRRect(r);
    final w = focused ? 2.0 : 1.0;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, w), Paint()..color = focused ? p.text3 : Color.lerp(p.hairline, p.text3, 0.45)!);
    canvas.restore();
    canvas.drawRRect(
      r.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = focused ? 1.2 : 0.8
        ..color = focused ? p.accent : p.hairline,
    );
  }

  @override
  bool shouldRepaint(RecessPainter o) => o.p != p || o.radius != radius || o.focused != focused;
}

/// "Recessed = holds a value": fields, tracks, wells. A 1 px darker top edge
/// reads as an inset without any shadow.
class Recessed extends StatelessWidget {
  const Recessed({super.key, required this.child, this.radius = 8, this.padding = EdgeInsets.zero});
  final Widget child;
  final double radius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: RecessPainter(FlowPalette.of(context), radius: radius),
    child: Padding(padding: padding, child: child),
  );
}

/// A slim recessed text field. The recess deepens 1 px on focus (SNAP).
class FlowTextField extends StatefulWidget {
  const FlowTextField({
    super.key,
    required this.controller,
    this.hint,
    this.obscure = false,
    this.onSubmitted,
    this.keyboardType,
    this.autofillHints,
    this.maxLength,
  });
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final int? maxLength;

  @override
  State<FlowTextField> createState() => _FlowTextFieldState();
}

class _FlowTextFieldState extends State<FlowTextField> {
  final _focus = FocusNode();
  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    final focused = _focus.hasFocus;
    return CustomPaint(
      painter: RecessPainter(p, focused: focused),
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        obscureText: widget.obscure,
        onSubmitted: widget.onSubmitted,
        keyboardType: widget.keyboardType,
        autofillHints: widget.autofillHints,
        maxLength: widget.maxLength,
        style: TextStyle(color: p.text1, fontSize: 13),
        cursorColor: p.accent,
        decoration: InputDecoration(
          isDense: true,
          counterText: '',
          hintText: widget.hint,
          hintStyle: TextStyle(color: p.text3, fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        ),
      ),
    );
  }
}

// ── The one knob shape ─────────────────────────────────────────────────────

/// Raised disc with a centre dimple: slider thumbs, range knobs, the wheel
/// marker. [active] puts the accent on the dimple (the one being dragged).
class KnobPainter extends CustomPainter {
  KnobPainter({required this.p, this.active = false, this.radius = 7});
  final FlowPalette p;
  final bool active;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) => paintAt(canvas, size.center(Offset.zero));

  void paintAt(Canvas canvas, Offset c) {
    canvas.drawCircle(c.translate(0, 1.2), radius, Paint()..color = Faces.ground(p.raised).withValues(alpha: 0.5));
    canvas.drawCircle(c, radius, Paint()..color = p.raised);
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Color.lerp(p.hairline, p.text3, 0.5)!,
    );
    canvas.drawCircle(c, radius * 0.28, Paint()..color = active ? p.accent : p.text2);
  }

  @override
  bool shouldRepaint(KnobPainter old) => old.active != active || old.p != p || old.radius != radius;
}

// ── Pill toggle ────────────────────────────────────────────────────────────

class PillToggle extends StatefulWidget {
  const PillToggle({super.key, required this.value, required this.onChanged, this.semanticLabel});
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  State<PillToggle> createState() => _PillToggleState();
}

class _PillToggleState extends State<PillToggle> with SingleTickerProviderStateMixin {
  late final _x = SpringValue(vsync: this, initial: widget.value ? 1 : 0);

  @override
  void didUpdateWidget(PillToggle old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _x.animateTo(widget.value ? 1 : 0, spring: Motion.snap, reduced: Motion.reduced(context));
  }

  @override
  void dispose() {
    _x.dispose();
    super.dispose();
  }

  void _toggle() {
    if (widget.onChanged == null) return;
    HapticFeedback.selectionClick();
    widget.onChanged!(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    return Semantics(
      toggled: widget.value,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: widget.onChanged != null,
        mouseCursor: SystemMouseCursors.click,
        actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _toggle())},
        child: GestureDetector(
          onTap: _toggle,
          child: AnimatedBuilder(
            animation: _x.animation,
            builder: (context, _) {
              final t = _x.value.clamp(-0.2, 1.2);
              return SizedBox(
                width: 30,
                height: 18,
                child: CustomPaint(painter: _TogglePainter(p, t, enabled: widget.onChanged != null)),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TogglePainter extends CustomPainter {
  _TogglePainter(this.p, this.t, {required this.enabled});
  final FlowPalette p;
  final double t;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.height / 2));
    final on = t.clamp(0.0, 1.0);
    canvas.drawRRect(r, Paint()..color = Color.lerp(p.recess, p.selected, on)!);
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = p.hairline,
    );
    final kr = size.height / 2 - 2.5;
    final cx = kr + 2.5 + t * (size.width - 2 * (kr + 2.5));
    final c = Offset(cx, size.height / 2);
    canvas.drawCircle(c.translate(0, 1), kr, Paint()..color = Faces.ground(p.raised).withValues(alpha: 0.4));
    canvas.drawCircle(c, kr, Paint()..color = enabled ? p.raised : p.recess);
  }

  @override
  bool shouldRepaint(_TogglePainter old) => old.t != t || old.p != p || old.enabled != enabled;
}

// ── Pressed dots (radio / check / rating) ──────────────────────────────────

/// A raised dot that is *pressed in* when chosen (not ticked).
class PressedDot extends StatelessWidget {
  const PressedDot({super.key, required this.on, this.size = 14});
  final bool on;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? p.selected : p.raised,
        border: Border.all(color: on ? p.selected : Color.lerp(p.hairline, p.text3, 0.4)!, width: 1),
      ),
      alignment: Alignment.center,
      child: on
          ? Container(
              width: size * 0.32,
              height: size * 0.32,
              decoration: BoxDecoration(shape: BoxShape.circle, color: p.recess),
            )
          : null,
    );
  }
}

/// 5-dot rating (focus 1–5, tiredness 1–5).
class DotRating extends StatelessWidget {
  const DotRating({super.key, required this.label, required this.value, required this.onChanged, this.count = 5});
  final String label;
  final int? value;
  final ValueChanged<int> onChanged;
  final int count;

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: p.text2, fontSize: 13)),
        const SizedBox(width: 12),
        for (var i = 1; i <= count; i++)
          Semantics(
            button: true,
            selected: value == i,
            label: '$label $i of $count',
            child: InkResponse(
              radius: 14,
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(i);
              },
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: PressedDot(on: value != null && i <= value!),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Snap slider (N detents) ────────────────────────────────────────────────

/// Discrete slider on a recessed track: FOLLOW while dragging, SNAP to the
/// nearest step on release, rubber band past either end (c for mouse drag).
class SnapSlider extends StatefulWidget {
  const SnapSlider({
    super.key,
    required this.steps,
    required this.index,
    required this.onChanged,
    this.labels,
    this.width = 160,
    this.semanticLabel,
  });
  final int steps;
  final int index;
  final ValueChanged<int> onChanged;
  final List<String>? labels;
  final double width;
  final String? semanticLabel;

  @override
  State<SnapSlider> createState() => _SnapSliderState();
}

class _SnapSliderState extends State<SnapSlider> with SingleTickerProviderStateMixin {
  late final _pos = SpringValue(vsync: this, initial: widget.index.toDouble());
  bool _dragging = false;
  double _finger = 0; // un-banded drag position, in step units

  double get _span => widget.width - 16;
  double get _stepPx => _span / (widget.steps - 1);

  @override
  void didUpdateWidget(SnapSlider old) {
    super.didUpdateWidget(old);
    if (!_dragging && old.index != widget.index) {
      _pos.animateTo(widget.index.toDouble(), spring: Motion.snap, reduced: Motion.reduced(context));
    }
  }

  @override
  void dispose() {
    _pos.dispose();
    super.dispose();
  }

  void _drag(double dxPx) {
    _finger += dxPx / _stepPx;
    final max = (widget.steps - 1).toDouble();
    var v = _finger;
    if (_finger < 0) v = -RubberBand.offset(-_finger * _stepPx, _stepPx, 0.4) / _stepPx;
    if (_finger > max) v = max + RubberBand.offset((_finger - max) * _stepPx, _stepPx, 0.4) / _stepPx;
    _pos.animateTo(v, spring: Motion.follow);
  }

  void _release() {
    _dragging = false;
    final i = _pos.value.round().clamp(0, widget.steps - 1);
    _pos.animateTo(i.toDouble(), spring: Motion.snap, reduced: Motion.reduced(context));
    if (i != widget.index) {
      HapticFeedback.selectionClick();
      widget.onChanged(i);
    }
  }

  void _step(int d) {
    final i = (widget.index + d).clamp(0, widget.steps - 1);
    if (i != widget.index) widget.onChanged(i);
  }

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    return Semantics(
      slider: true,
      label: widget.semanticLabel,
      value: widget.labels?[widget.index] ?? '${widget.index + 1}',
      increasedValue: widget.index < widget.steps - 1 ? (widget.labels?[widget.index + 1] ?? '${widget.index + 2}') : null,
      decreasedValue: widget.index > 0 ? (widget.labels?[widget.index - 1] ?? '${widget.index}') : null,
      onIncrease: widget.index < widget.steps - 1 ? () => _step(1) : null,
      onDecrease: widget.index > 0 ? () => _step(-1) : null,
      child: FocusableActionDetector(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowRight): _StepIntent(1),
          SingleActivator(LogicalKeyboardKey.arrowLeft): _StepIntent(-1),
        },
        actions: {_StepIntent: CallbackAction<_StepIntent>(onInvoke: (i) => _step(i.delta))},
        mouseCursor: SystemMouseCursors.click,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (_) {
                _dragging = true;
                _finger = _pos.value;
              },
              onHorizontalDragUpdate: (d) => _drag(d.delta.dx),
              onHorizontalDragEnd: (_) => _release(),
              onTapUp: (d) {
                final i = ((d.localPosition.dx - 8) / _stepPx).round().clamp(0, widget.steps - 1);
                if (i != widget.index) widget.onChanged(i);
              },
              child: SizedBox(
                width: widget.width,
                height: 22,
                child: AnimatedBuilder(
                  animation: _pos.animation,
                  builder: (context, _) => CustomPaint(painter: _SnapTrackPainter(p, widget.steps, _pos.value, _dragging)),
                ),
              ),
            ),
            if (widget.labels != null)
              SizedBox(
                width: widget.width,
                height: 16,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var i = 0; i < widget.steps; i++)
                      Positioned(
                        left: i == 0 ? 0 : null,
                        right: i == widget.steps - 1 ? 0 : null,
                        child: i == 0 || i == widget.steps - 1
                            ? Text(widget.labels![i], style: TextStyle(fontSize: 11, color: i == widget.index ? p.text1 : p.text3))
                            : const SizedBox.shrink(),
                      ),
                    for (var i = 1; i < widget.steps - 1; i++)
                      Align(
                        alignment: Alignment(-1 + 2 * i / (widget.steps - 1), 0),
                        child: Text(widget.labels![i], style: TextStyle(fontSize: 11, color: i == widget.index ? p.text1 : p.text3)),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StepIntent extends Intent {
  const _StepIntent(this.delta);
  final int delta;
}

class _SnapTrackPainter extends CustomPainter {
  _SnapTrackPainter(this.p, this.steps, this.pos, this.active);
  final FlowPalette p;
  final int steps;
  final double pos;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 8.0;
    final y = size.height / 2;
    final span = size.width - 2 * inset;
    final track = RRect.fromLTRBR(inset - 2, y - 2, size.width - inset + 2, y + 2, const Radius.circular(2));
    canvas.drawRRect(track, Paint()..color = p.recess);
    canvas.drawLine(
      Offset(inset, y - 1.5),
      Offset(size.width - inset, y - 1.5),
      Paint()
        ..color = Color.lerp(p.hairline, p.text3, 0.4)!
        ..strokeWidth = 0.6,
    );
    for (var i = 0; i < steps; i++) {
      canvas.drawCircle(Offset(inset + span * i / (steps - 1), y), 1.4, Paint()..color = p.text3);
    }
    final x = inset + span * pos / (steps - 1);
    KnobPainter(p: p, active: active).paintAt(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(_SnapTrackPainter old) => old.pos != pos || old.active != active || old.p != p;
}

// ── Read-out line ──────────────────────────────────────────────────────────

/// Centred, letter-spaced small caps under every display (spec rule P).
class ReadOut extends StatelessWidget {
  const ReadOut(this.text, {super.key, this.size = 11});
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    return Semantics(
      liveRegion: true,
      child: AnimatedSwitcher(
        duration: Motion.fade,
        child: Text(
          flowCaps(text),
          key: ValueKey(text),
          textAlign: TextAlign.center,
          style: FlowType.label(p, size: size),
        ),
      ),
    );
  }
}

/// Small section label (letter-spaced, muted).
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(flowCaps(text), style: FlowType.label(FlowPalette.of(context), size: 10, color: FlowPalette.of(context).text3));
}

/// Utility used by painters: angle helpers.
double degToRad(double d) => d * math.pi / 180;
