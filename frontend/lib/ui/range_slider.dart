import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/motion.dart';
import '../theme/tokens.dart';
import 'kit.dart';

/// Two-knob range on a 24 h recessed track (quiet hours, schedules).
///
/// Values are minutes since midnight, snapping to [step]. The track can show
/// context behind the span (the mini spine: your usual focus + meetings) via
/// [background]. FOLLOW while dragging, SNAP on release, rubber band at 0/24 h.
class TimeRangeSlider extends StatefulWidget {
  const TimeRangeSlider({
    super.key,
    required this.start,
    required this.end,
    required this.onChanged,
    this.step = 15,
    this.background,
    this.height = 44,
    this.semanticLabel = 'Time range',
    this.origin = 0,
  });

  /// Clock minute at the left end of the track. 720 (noon) lets an overnight
  /// range such as quiet hours 22:00–07:00 sit in one piece.
  final int origin;

  final int start;
  final int end;
  final void Function(int start, int end) onChanged;
  final int step;
  final void Function(Canvas canvas, Rect track)? background;
  final double height;
  final String semanticLabel;

  static const day = 24 * 60;

  @override
  State<TimeRangeSlider> createState() => _TimeRangeSliderState();
}

class _TimeRangeSliderState extends State<TimeRangeSlider> with TickerProviderStateMixin {
  late final _a = SpringValue(vsync: this, initial: widget.start.toDouble());
  late final _b = SpringValue(vsync: this, initial: widget.end.toDouble());
  int? _dragging; // 0 = start knob, 1 = end knob
  double _finger = 0;

  @override
  void didUpdateWidget(TimeRangeSlider old) {
    super.didUpdateWidget(old);
    if (_dragging == null) {
      final r = Motion.reduced(context);
      if (old.start != widget.start) _a.animateTo(widget.start.toDouble(), spring: Motion.snap, reduced: r);
      if (old.end != widget.end) _b.animateTo(widget.end.toDouble(), spring: Motion.snap, reduced: r);
    }
  }

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  int _snap(double m) => ((m / widget.step).round() * widget.step).clamp(0, TimeRangeSlider.day);

  void _commit(int i, int v) {
    var s = widget.start, e = widget.end;
    if (i == 0) s = v.clamp(0, e - widget.step);
    if (i == 1) e = v.clamp(s + widget.step, TimeRangeSlider.day);
    if (s != widget.start || e != widget.end) {
      HapticFeedback.selectionClick();
      widget.onChanged(s, e);
    }
  }

  String _fmt(int m) {
    final c = (m + widget.origin) % TimeRangeSlider.day;
    return '${(c ~/ 60).toString().padLeft(2, '0')}:${(c % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        const inset = 10.0;
        final span = w - 2 * inset;
        double toPx(double m) => inset + span * m / TimeRangeSlider.day;
        final perMin = span / TimeRangeSlider.day;

        void update(double dx) {
          _finger += dx / perMin;
          var v = _finger;
          if (v < 0) v = -RubberBand.offset(-v * perMin, 40, 0.4) / perMin;
          if (v > TimeRangeSlider.day) v = TimeRangeSlider.day + RubberBand.offset((v - TimeRangeSlider.day) * perMin, 40, 0.4) / perMin;
          (_dragging == 0 ? _a : _b).animateTo(v, spring: Motion.follow);
        }

        void release() {
          final i = _dragging;
          if (i == null) return;
          final sv = (i == 0 ? _a : _b);
          final snapped = _snap(sv.value);
          _commit(i, snapped);
          sv.animateTo(
            snapped.toDouble().clamp(
              i == 0 ? 0 : widget.start + widget.step.toDouble(),
              i == 0 ? widget.end - widget.step.toDouble() : TimeRangeSlider.day.toDouble(),
            ),
            spring: Motion.snap,
            reduced: Motion.reduced(context),
          );
          setState(() => _dragging = null);
        }

        return Semantics(
          label: '${widget.semanticLabel}: ${_fmt(widget.start)} to ${_fmt(widget.end)}',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (d) {
                  final x = d.localPosition.dx;
                  final i = (x - toPx(_a.value)).abs() <= (x - toPx(_b.value)).abs() ? 0 : 1;
                  setState(() => _dragging = i);
                  _finger = (i == 0 ? _a : _b).value;
                },
                onHorizontalDragUpdate: (d) => update(d.delta.dx),
                onHorizontalDragEnd: (_) => release(),
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: SizedBox(
                    height: widget.height,
                    width: w,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_a.animation, _b.animation]),
                      builder: (context, _) =>
                          CustomPaint(painter: _RangePainter(p, toPx(_a.value), toPx(_b.value), inset, _dragging, widget.background)),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: w,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final h in const [0, 6, 12, 18, 24])
                      Text((((h * 60 + widget.origin) ~/ 60) % 24).toString().padLeft(2, '0'), style: FlowType.chart(p, size: 10)),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text('${_fmt(widget.start)} – ${_fmt(widget.end)}', style: FlowType.label(p, size: 10.5)),
            ],
          ),
        );
      },
    );
  }
}

class _RangePainter extends CustomPainter {
  _RangePainter(this.p, this.xa, this.xb, this.inset, this.dragging, this.background);
  final FlowPalette p;
  final double xa, xb, inset;
  final int? dragging;
  final void Function(Canvas, Rect)? background;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final track = Rect.fromLTRB(inset - 4, y - 9, size.width - inset + 4, y + 9);
    canvas.drawRRect(RRect.fromRectAndRadius(track, const Radius.circular(9)), Paint()..color = p.recess);
    canvas.drawLine(
      track.topLeft.translate(9, 0.5),
      track.topRight.translate(-9, 0.5),
      Paint()
        ..color = Color.lerp(p.hairline, p.text3, 0.4)!
        ..strokeWidth = 0.8,
    );
    background?.call(canvas, track.deflate(3));
    // hour ticks
    for (var h = 0; h <= 24; h++) {
      final x = inset + (size.width - 2 * inset) * h / 24;
      canvas.drawLine(
        Offset(x, y + 9),
        Offset(x, y + (h % 6 == 0 ? 13 : 11)),
        Paint()
          ..color = p.text3
          ..strokeWidth = 0.7,
      );
    }
    // chosen span: dark neutral (selection, not "now")
    final spanR = RRect.fromLTRBR(xa, y - 5, xb, y + 5, const Radius.circular(5));
    canvas.drawRRect(spanR, Paint()..color = p.selected.withValues(alpha: 0.85));
    KnobPainter(p: p, active: dragging == 0, radius: 8).paintAt(canvas, Offset(xa, y));
    KnobPainter(p: p, active: dragging == 1, radius: 8).paintAt(canvas, Offset(xb, y));
  }

  @override
  bool shouldRepaint(_RangePainter old) => old.xa != xa || old.xb != xb || old.dragging != dragging || old.p != p;
}
