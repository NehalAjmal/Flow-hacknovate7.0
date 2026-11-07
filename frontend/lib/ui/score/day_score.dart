import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/models/day.dart';
import '../../api/models/insights.dart' show Confidence;
import '../../api/models/session.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';

/// Visible time range of the Score: auto-fit to the day (DESIGN_SPEC §6).
/// From 30 min before the first thing to 30 min after the last planned thing
/// (and NOW / the ghost block), at least 6 h, snapped to half hours.
({DateTime start, DateTime end}) scoreRange(DayTimeline d, DateTime now, {int ghostMinutes = 0}) {
  final day = DateTime(d.date.year, d.date.month, d.date.day);
  final isToday = DateUtils.isSameDay(day, now);
  final times = <DateTime>[
    for (final s in d.sessions) ...[s.start, s.end],
    for (final m in d.meetings) ...[m.start, m.end],
    if (isToday) now,
    if (isToday && ghostMinutes > 0) now.add(Duration(minutes: ghostMinutes)),
  ];
  var start = times.isEmpty ? DateTime(day.year, day.month, day.day, 9) : times.reduce((a, b) => a.isBefore(b) ? a : b);
  var end = times.isEmpty ? DateTime(day.year, day.month, day.day, 17) : times.reduce((a, b) => a.isAfter(b) ? a : b);
  start = start.subtract(const Duration(minutes: 30));
  end = end.add(const Duration(minutes: 30));
  if (end.difference(start) < const Duration(hours: 6)) {
    end = start.add(const Duration(hours: 6));
  }
  DateTime floorHalf(DateTime t) => DateTime(t.year, t.month, t.day, t.hour, t.minute < 30 ? 0 : 30);
  DateTime ceilHalf(DateTime t) => floorHalf(t).add(t.minute % 30 == 0 && t.second == 0 ? Duration.zero : const Duration(minutes: 30));
  return (start: floorHalf(start), end: ceilHalf(end));
}

class ScoreHover {
  const ScoreHover({required this.at, this.session, this.pressure, this.usual, this.meeting});
  final DateTime at;
  final TimelineSession? session;
  final double? pressure;
  final double? usual;
  final TimelineMeeting? meeting;
}

/// The Day Score: stacked tracks on one time axis with a NOW line through
/// all of them. Interactive: crosshair (mouse + arrow keys), click a past
/// block, drag from NOW to size a session, drag elsewhere in the future to
/// draft a scheduled session.
class DayScore extends StatefulWidget {
  const DayScore({
    super.key,
    required this.day,
    required this.now,
    this.ghostMinutes = 0,
    this.onSessionTap,
    this.onGhostDrag,
    this.onScheduleDraft,
    this.height = 300,
  });

  final DayTimeline day;
  final DateTime now;

  /// Minutes of the ghost (proposed) session starting at NOW; 0 = none.
  final int ghostMinutes;
  final ValueChanged<TimelineSession>? onSessionTap;

  /// Dragging from the NOW line sizes the ghost block (same as the dial).
  final ValueChanged<int>? onGhostDrag;
  final void Function(DateTime start, DateTime end)? onScheduleDraft;
  final double height;

  @override
  State<DayScore> createState() => _DayScoreState();
}

class _DayScoreState extends State<DayScore> with TickerProviderStateMixin {
  late final _a = SpringValue(vsync: this, initial: 0); // axis start (ms since day start)
  late final _b = SpringValue(vsync: this, initial: 0); // axis end
  late final _ghost = SpringValue(vsync: this, initial: widget.ghostMinutes.toDouble());
  late final _nowDraw = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  // every 3D block rises from the line on arrival (and when the day changes)
  late final _rise = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  DateTime? _hoverAt;
  _Drag? _drag;
  DateTime? _draftStart, _draftEnd;
  final _focus = FocusNode(debugLabel: 'DayScore');

  DateTime get _day0 => DateTime(widget.day.date.year, widget.day.date.month, widget.day.date.day);
  double _ms(DateTime t) => t.difference(_day0).inMilliseconds.toDouble();
  DateTime _fromMs(double ms) => _day0.add(Duration(milliseconds: ms.round()));

  @override
  void initState() {
    super.initState();
    final r = scoreRange(widget.day, widget.now, ghostMinutes: widget.ghostMinutes);
    _a.value = _ms(r.start);
    _b.value = _ms(r.end);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (Motion.reduced(context)) {
        _nowDraw.value = 1;
        _rise.value = 1;
      } else {
        LaunchGate.whenVisible(() {
          if (!mounted) return;
          _nowDraw.forward();
          _rise.forward();
        });
      }
    });
  }

  @override
  void didUpdateWidget(DayScore old) {
    super.didUpdateWidget(old);
    final reduced = Motion.reduced(context);
    final r = scoreRange(widget.day, widget.now, ghostMinutes: widget.ghostMinutes);
    if (!DateUtils.isSameDay(old.day.date, widget.day.date)) {
      _a.value = _ms(r.start);
      _b.value = _ms(r.end);
      _nowDraw
        ..value = 0
        ..forward();
      if (!reduced) {
        _rise
          ..value = 0
          ..forward();
      }
    } else {
      if ((_a.target - _ms(r.start)).abs() > 1) _a.animateTo(_ms(r.start), spring: Motion.settle, reduced: reduced);
      if ((_b.target - _ms(r.end)).abs() > 1) _b.animateTo(_ms(r.end), spring: Motion.settle, reduced: reduced);
    }
    if (old.ghostMinutes != widget.ghostMinutes && _drag != _Drag.ghost) {
      _ghost.animateTo(widget.ghostMinutes.toDouble(), spring: Motion.settle, reduced: reduced);
    }
  }

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    _ghost.dispose();
    _nowDraw.dispose();
    _rise.dispose();
    _focus.dispose();
    super.dispose();
  }

  _ScoreLayout _layout(Size size) => _ScoreLayout(size, _fromMs(_a.value), _fromMs(_b.value));

  ScoreHover _hoverInfo(DateTime at) {
    final d = widget.day;
    TimelineSession? s;
    for (final x in d.sessions) {
      if (!at.isBefore(x.start) && at.isBefore(x.end)) s = x;
    }
    TimelineMeeting? m;
    for (final x in d.meetings) {
      if (!at.isBefore(x.start) && at.isBefore(x.end)) m = x;
    }
    double? usual;
    for (final b in d.usualBand) {
      if (!b.t.isAfter(at)) usual = (b.lo + b.hi) / 2;
    }
    return ScoreHover(
      at: at,
      session: s,
      pressure: d.pressureAt(at) ?? (d.forecastConfidence == Confidence.high ? d.forecastAt(at) : null),
      usual: d.usualDays >= _ScorePainter.usualMinDays ? usual : null,
      meeting: m,
    );
  }

  void _moveHover(int minutes) {
    final base = _hoverAt ?? (DateUtils.isSameDay(widget.now, widget.day.date) ? widget.now : _fromMs((_a.value + _b.value) / 2));
    final next = base.add(Duration(minutes: minutes));
    final lo = _fromMs(_a.value), hi = _fromMs(_b.value);
    setState(() => _hoverAt = next.isBefore(lo) ? lo : (next.isAfter(hi) ? hi : next));
  }

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    final isToday = DateUtils.isSameDay(widget.now, widget.day.date);
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, widget.height);

        DateTime timeAt(double x) => _layout(size).timeAt(x);

        return Semantics(
          label: _semanticSummary(widget.day, isToday ? widget.now : null),
          child: Focus(
            focusNode: _focus,
            onKeyEvent: (node, e) {
              if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
              if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
                _moveHover(-15);
                return KeyEventResult.handled;
              }
              if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
                _moveHover(15);
                return KeyEventResult.handled;
              }
              if (e.logicalKey == LogicalKeyboardKey.escape) {
                setState(() => _hoverAt = null);
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: MouseRegion(
              cursor: _drag != null ? SystemMouseCursors.resizeColumn : SystemMouseCursors.precise,
              onHover: (e) => setState(() => _hoverAt = timeAt(e.localPosition.dx)),
              onExit: (_) => setState(() => _hoverAt = null),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (e) {
                  _focus.requestFocus();
                  final at = timeAt(e.localPosition.dx);
                  final hit = widget.day.sessions.where(
                    (s) => s.state == TimelineSessionState.done && !at.isBefore(s.start) && at.isBefore(s.end),
                  );
                  if (hit.isNotEmpty) widget.onSessionTap?.call(hit.first);
                },
                onHorizontalDragStart: (e) {
                  final l = _layout(size);
                  final nowX = l.x(widget.now);
                  if (isToday && (e.localPosition.dx - nowX).abs() < 14 && widget.onGhostDrag != null) {
                    _drag = _Drag.ghost;
                  } else if (widget.onScheduleDraft != null) {
                    final at = timeAt(e.localPosition.dx);
                    if (at.isAfter(widget.now)) {
                      _drag = _Drag.draft;
                      _draftStart = _snap5(at);
                      _draftEnd = _draftStart;
                    }
                  }
                  setState(() {});
                },
                onHorizontalDragUpdate: (e) {
                  final at = timeAt(e.localPosition.dx);
                  if (_drag == _Drag.ghost) {
                    final mins = at.difference(widget.now).inMinutes.clamp(0, 180);
                    _ghost.animateTo(mins.toDouble(), spring: Motion.follow);
                    final snapped = (mins / 5).round() * 5;
                    if (snapped != widget.ghostMinutes) {
                      HapticFeedback.selectionClick();
                      widget.onGhostDrag!(snapped.clamp(15, 180));
                    }
                  } else if (_drag == _Drag.draft) {
                    setState(() => _draftEnd = _snap5(at));
                  }
                },
                onHorizontalDragEnd: (_) {
                  if (_drag == _Drag.ghost) {
                    _ghost.animateTo(widget.ghostMinutes.toDouble(), spring: Motion.snap);
                  } else if (_drag == _Drag.draft && _draftStart != null && _draftEnd != null) {
                    final a = _draftStart!.isBefore(_draftEnd!) ? _draftStart! : _draftEnd!;
                    final b = _draftStart!.isBefore(_draftEnd!) ? _draftEnd! : _draftStart!;
                    if (b.difference(a).inMinutes >= 15) widget.onScheduleDraft!(a, b);
                  }
                  setState(() {
                    _drag = null;
                    _draftStart = _draftEnd = null;
                  });
                },
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_a.animation, _b.animation, _ghost.animation, _nowDraw, _rise]),
                    builder: (context, _) => CustomPaint(
                      size: size,
                      painter: _ScorePainter(
                        p: p,
                        day: widget.day,
                        now: widget.now,
                        isToday: isToday,
                        layout: _layout(size),
                        ghostMinutes: _ghost.value,
                        nowDraw: Curves.easeOut.transform(_nowDraw.value),
                        hover: _hoverAt == null ? null : _hoverInfo(_hoverAt!),
                        draft: _draftStart == null || _draftEnd == null ? null : (_draftStart!, _draftEnd!),
                        textScale: MediaQuery.textScalerOf(context),
                        rise: _rise.isCompleted ? 1e9 : _rise.value * 2.4,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static DateTime _snap5(DateTime t) => DateTime(t.year, t.month, t.day, t.hour, (t.minute / 5).round() * 5);
}

enum _Drag { ghost, draft }

String _semanticSummary(DayTimeline d, DateTime? now) {
  final t = d.totals;
  final b = StringBuffer(
    'Day score. ${t.focusMinutes ~/ 60} hours ${t.focusMinutes % 60} minutes focused, '
    '${t.breaksTaken} of ${t.breaksSuggested} breaks taken.',
  );
  if (d.nudges.isNotEmpty) b.write(' ${d.nudges.length} nudges.');
  b.write(' Use left and right arrow keys to read the timeline.');
  return b.toString();
}

/// Vertical layout of the tracks inside the Score.
class _ScoreLayout {
  _ScoreLayout(this.size, this.start, this.end);
  final Size size;
  final DateTime start;
  final DateTime end;

  static const left = 4.0;
  double get right => size.width - 6;
  // Blocks are the hero (the day's real record): up to ~27% of the height,
  // 96 px max. The pressure track takes what is left under the hour ruler.
  double get maxBlock => (size.height * 0.27).clamp(30.0, 96.0);
  double get blockBase => 30 + maxBlock;
  double get depth => (maxBlock * 0.13).clamp(5.0, 13.0);
  double get meetingY => blockBase + 22;
  double get pressureBase => size.height - 24;
  double get pressureTop => blockBase + 38;
  double get nudgeH => (pressureBase - pressureTop) / 1.18;
  double get dotsY => size.height - 9;

  double get spanMs => end.difference(start).inMilliseconds.toDouble();
  double x(DateTime t) => left + (right - left) * t.difference(start).inMilliseconds / spanMs;
  DateTime timeAt(double px) => start.add(Duration(milliseconds: ((px - left) / (right - left) * spanMs).round().clamp(0, spanMs.toInt())));
  double py(double v) => pressureBase - v.clamp(0.0, 1.18) * nudgeH;
  double blockH(Demand d) =>
      maxBlock *
      switch (d) {
        Demand.light => 0.5,
        Demand.moderate => 0.74,
        Demand.heavy => 1.0,
      };
}

class _ScorePainter extends CustomPainter {
  _ScorePainter({
    required this.p,
    required this.day,
    required this.now,
    required this.isToday,
    required this.layout,
    required this.ghostMinutes,
    required this.nowDraw,
    required this.hover,
    required this.draft,
    required this.textScale,
    this.rise = 1e9,
  });

  final FlowPalette p;
  final DayTimeline day;
  final DateTime now;
  final bool isToday;
  final _ScoreLayout layout;
  final double ghostMinutes;
  final double nowDraw;
  final ScoreHover? hover;
  final (DateTime, DateTime)? draft;
  final TextScaler textScale;

  /// Seconds since the blocks started rising (each block staggers in).
  final double rise;

  // each block rises from the line, staggered left to right
  double _tOf(int i) => rise >= 1e8 ? 1e9 : rise - i * 0.07;

  double get depth => layout.depth;

  void _text(
    Canvas c,
    String s,
    Offset at, {
    double size = 9.5,
    Color? color,
    TextAlign align = TextAlign.left,
    bool caps = false,
    FontWeight w = FontWeight.w400,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: caps ? flowCaps(s) : s,
        style: FlowType.chart(
          p,
          size: size,
          color: color,
          weight: w,
        ).copyWith(fontFamily: caps ? FlowFonts.ui : FlowFonts.mono, letterSpacing: caps ? size * 0.14 : 0),
      ),
      textDirection: TextDirection.ltr,
      textScaler: textScale,
    )..layout();
    final dx = switch (align) {
      TextAlign.center => at.dx - tp.width / 2,
      TextAlign.right => at.dx - tp.width,
      _ => at.dx,
    };
    tp.paint(c, Offset(dx, at.dy - tp.height / 2));
  }

  /// Front-on block with a visible top face, rising from [base].
  void _block(Canvas c, double x0, double x1, double base, double h, {Color? fill, Color? stroke, bool dashed = false, double sw = 1}) {
    if (h <= 0.5) return;
    // a hairline gap between neighbours so each session reads as its own solid
    final inset = math.min(2.0, (x1 - x0) * 0.08);
    x0 += inset;
    x1 -= inset;
    final top = base - h;
    final w = math.max(1.0, x1 - x0);
    final depth = math.min(this.depth, math.max(2.0, w * 0.32));
    if (fill != null) {
      c.drawPath(
        Path()
          ..moveTo(x0, top)
          ..lineTo(x0 + depth, top - depth)
          ..lineTo(x0 + w + depth, top - depth)
          ..lineTo(x0 + w, top)
          ..close(),
        Paint()..color = Faces.top(fill),
      );
      c.drawPath(
        Path()
          ..moveTo(x0 + w, top)
          ..lineTo(x0 + w + depth, top - depth)
          ..lineTo(x0 + w + depth, base - depth)
          ..lineTo(x0 + w, base)
          ..close(),
        Paint()..color = Faces.side(fill),
      );
      // front face: lit from above, so it darkens slightly toward the ground
      final front = Rect.fromLTWH(x0, top, w, h);
      c.drawRect(
        front,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(fill, Faces.top(fill), 0.35)!, fill, Color.lerp(fill, Faces.side(fill), 0.25)!],
            stops: const [0, 0.45, 1],
          ).createShader(front),
      );
      // catch-light on the front-top edge, crease on the front-side edge
      c.drawLine(
        Offset(x0, top + 0.5),
        Offset(x0 + w, top + 0.5),
        Paint()
          ..color = Color.lerp(Faces.top(fill), const Color(0xFFFFFFFF), 0.35)!.withValues(alpha: 0.8)
          ..strokeWidth = 1,
      );
      c.drawLine(
        Offset(x0 + w - 0.5, top),
        Offset(x0 + w - 0.5, base),
        Paint()
          ..color = Faces.side(fill).withValues(alpha: 0.6)
          ..strokeWidth = 1,
      );
      c.drawLine(
        Offset(x0, base),
        Offset(x0 + w + depth, base),
        Paint()
          ..color = Faces.ground(fill)
          ..strokeWidth = 1,
      );
    }
    if (stroke != null) {
      final outline = Path()
        ..moveTo(x0, base)
        ..lineTo(x0, top)
        ..lineTo(x0 + depth, top - depth)
        ..lineTo(x0 + w + depth, top - depth)
        ..lineTo(x0 + w + depth, base - depth)
        ..lineTo(x0 + w, base)
        ..close()
        ..moveTo(x0, top)
        ..lineTo(x0 + w, top)
        ..lineTo(x0 + w, base)
        ..moveTo(x0 + w, top)
        ..lineTo(x0 + w + depth, top - depth);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeJoin = StrokeJoin.round
        ..color = stroke;
      c.drawPath(dashed ? _dash(outline, 3, 2.5) : outline, paint);
    }
  }

  static Path _dash(Path src, double on, double off) {
    final out = Path();
    for (final m in src.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        out.addPath(m.extractPath(d, math.min(d + on, m.length)), Offset.zero);
        d += on + off;
      }
    }
    return out;
  }

  /// Full-day forecast only when the backend is confident in it.
  bool get _forecastTrusted => day.forecastConfidence == Confidence.high;

  /// Minimum days of history before the "usual" band means anything.
  static const usualMinDays = 10;

  /// Short, honest projection: only during a live session, extends the last
  /// 15 min trend for up to 20 min and stops at the nudge line.
  List<Offset>? _projection() {
    if (!isToday || day.active == null) return null;
    final past = day.pressure.where((pt) => !pt.t.isAfter(now.add(const Duration(minutes: 2)))).toList();
    if (past.length < 2) return null;
    final last = past.last;
    final ref = past.lastWhere((pt) => !pt.t.isAfter(last.t.subtract(const Duration(minutes: 15))), orElse: () => past.first);
    final mins = last.t.difference(ref.t).inSeconds / 60;
    if (mins < 3) return null;
    final slope = (last.v - ref.v) / mins; // per minute
    if (slope <= 0.002) return null; // flat or falling: nothing to warn about
    final toLine = (1.0 - last.v) / slope;
    final span = math.min(20.0, math.max(0.0, toLine));
    if (span < 1) return null;
    final end = last.t.add(Duration(seconds: (span * 60).round()));
    return [Offset(layout.x(last.t), layout.py(last.v)), Offset(layout.x(end), layout.py(last.v + slope * span))];
  }

  /// Monotone cubic through [pts] (Fritsch–Carlson): smooth, never overshoots,
  /// so the curve can't invent peaks or dip below zero.
  static Path _smooth(List<Offset> pts, {bool startNew = true, Path? into}) {
    final path = into ?? Path();
    if (pts.isEmpty) return path;
    if (startNew) {
      path.moveTo(pts.first.dx, pts.first.dy);
    } else {
      path.lineTo(pts.first.dx, pts.first.dy);
    }
    if (pts.length < 3) {
      for (final q in pts.skip(1)) {
        path.lineTo(q.dx, q.dy);
      }
      return path;
    }
    final n = pts.length;
    final d = List<double>.generate(n - 1, (i) {
      final dx = pts[i + 1].dx - pts[i].dx;
      return dx == 0 ? 0 : (pts[i + 1].dy - pts[i].dy) / dx;
    });
    final m = List<double>.filled(n, 0);
    m[0] = d[0];
    m[n - 1] = d[n - 2];
    for (var i = 1; i < n - 1; i++) {
      m[i] = d[i - 1] * d[i] <= 0 ? 0 : (d[i - 1] + d[i]) / 2;
    }
    for (var i = 0; i < n - 1; i++) {
      if (d[i] == 0) {
        m[i] = 0;
        m[i + 1] = 0;
        continue;
      }
      final a = m[i] / d[i], b = m[i + 1] / d[i];
      final h = a * a + b * b;
      if (h > 9) {
        final t = 3 / math.sqrt(h);
        m[i] = t * a * d[i];
        m[i + 1] = t * b * d[i];
      }
    }
    for (var i = 0; i < n - 1; i++) {
      final p0 = pts[i], p1 = pts[i + 1];
      final h = (p1.dx - p0.dx) / 3;
      path.cubicTo(p0.dx + h, p0.dy + m[i] * h, p1.dx - h, p1.dy - m[i + 1] * h, p1.dx, p1.dy);
    }
    return path;
  }

  Path _line(List<Offset> pts) {
    final path = Path();
    for (var i = 0; i < pts.length; i++) {
      i == 0 ? path.moveTo(pts[i].dx, pts[i].dy) : path.lineTo(pts[i].dx, pts[i].dy);
    }
    return path;
  }

  @override
  void paint(Canvas c, Size size) {
    final l = layout;
    final clip = Rect.fromLTRB(0, 0, size.width, size.height);
    c.save();
    c.clipRect(clip);
    final nowX = l.x(now);
    final showNow = isToday && nowX >= _ScoreLayout.left && nowX <= l.right;

    // ── usual: your typical pressure at this hour (median of past days),
    // one dashed line labelled at its end; never louder than today's curve.
    if (day.usualDays >= usualMinDays && day.usualBand.length > 1) {
      final mid = [for (final b in day.usualBand) Offset(l.x(b.t), l.py((b.lo + b.hi) / 2))];
      c.drawPath(
        _dash(_smooth(mid), 4, 3),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..color = p.text3.withValues(alpha: 0.7),
      );
      final end = mid.lastWhere((o) => o.dx <= l.right, orElse: () => mid.last);
      _text(
        c,
        'your usual',
        Offset(math.min(end.dx, l.right) - 34, end.dy + (end.dy > l.py(0.5) ? -9 : 9)),
        size: 8.5,
        color: p.text3,
        align: TextAlign.right,
      );
    }

    // ── guides: 50% + nudge line ───────────────────────────────────────
    final half = l.py(0.5), line = l.py(1.0);
    c.drawPath(
      _dash(
        Path()
          ..moveTo(_ScoreLayout.left, half)
          ..lineTo(l.right, half),
        1,
        3,
      ),
      Paint()
        ..color = p.hairline
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke,
    );
    _text(c, '50%', Offset(l.right, half - 6), size: 8, align: TextAlign.right);
    c.drawPath(
      _dash(
        Path()
          ..moveTo(_ScoreLayout.left, line)
          ..lineTo(l.right, line),
        4,
        3,
      ),
      Paint()
        ..color = p.amber.withValues(alpha: 0.85)
        ..strokeWidth = 0.9
        ..style = PaintingStyle.stroke,
    );
    _text(c, 'nudge line', Offset(l.right, line - 7), size: 8, color: p.amber, align: TextAlign.right, caps: true);

    // ── pressure (past) ────────────────────────────────────────────────
    // small tolerance: data fetched a moment after `now` was captured still counts as the present
    final past = day.pressure.where((pt) => !isToday || !pt.t.isAfter(now.add(const Duration(minutes: 2)))).toList();
    if (past.length > 1) {
      final pts = [for (final pt in past) Offset(l.x(pt.t), l.py(pt.v))];
      final curve = _smooth(pts);
      final area = Path()..moveTo(pts.first.dx, l.pressureBase);
      _smooth(pts, startNew: false, into: area);
      area
        ..lineTo(pts.last.dx, l.pressureBase)
        ..close();
      // Coloured by height: calm stone low, deeper stone mid, amber tint on
      // the approach (80–100%), full amber over the line. Read at a glance.
      c.save();
      c.clipPath(area);
      final bands = <(double, double, Color)>[
        (0.0, 0.5, Color.lerp(p.pastLight, p.bg, 0.30)!),
        (0.5, 0.8, Color.lerp(p.pastModerate, p.bg, 0.35)!),
        (0.8, 1.0, p.amberTint),
        (1.0, 1.25, p.amber.withValues(alpha: 0.75)),
      ];
      for (final (lo, hi, col) in bands) {
        c.drawRect(Rect.fromLTRB(_ScoreLayout.left, l.py(hi) - (hi >= 1.2 ? 40 : 0), l.right, l.py(lo)), Paint()..color = col);
      }
      c.restore();
      c.drawPath(
        curve,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..strokeJoin = StrokeJoin.round
          ..color = p.pastHeavy,
      );
    }

    if (day.usualDays < usualMinDays) {
      // No fake curve while history is thin: say so, in the track itself.
      _text(
        c,
        'learning your usual rhythm · day ${day.usualDays} of $usualMinDays',
        Offset(l.right, l.pressureBase - 8),
        size: 8.5,
        color: p.text3,
        align: TextAlign.right,
      );
    }

    // session-start hairlines tie blocks to their part of the curve
    for (final s in day.sessions.where((s) => s.state == TimelineSessionState.done || s.state == TimelineSessionState.active)) {
      final x = l.x(s.start);
      c.drawLine(
        Offset(x, l.blockBase + 14),
        Offset(x, l.pressureBase),
        Paint()
          ..color = p.hairline
          ..strokeWidth = 0.6,
      );
    }

    // ── forecast: only a trusted backend forecast is drawn for the whole
    // day; otherwise a short projection while a session runs (honest, Rule B).
    if (_forecastTrusted) {
      if (day.forecastBand.length > 1) {
        final up = [for (final b in day.forecastBand) Offset(l.x(b.t), l.py(b.hi))];
        final lo = [for (final b in day.forecastBand.reversed) Offset(l.x(b.t), l.py(b.lo))];
        c.drawPath(_line([...up, ...lo])..close(), Paint()..color = p.future.withValues(alpha: 0.12));
      }
      if (day.forecast.length > 1) {
        c.drawPath(
          _dash(_smooth([for (final f in day.forecast) Offset(l.x(f.t), l.py(f.v))]), 2.5, 2.5),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = p.future,
        );
      }
    } else {
      final proj = _projection();
      if (proj != null) {
        c.drawPath(
          _dash(_line(proj), 2.5, 2.5),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1
            ..color = p.future,
        );
      }
    }

    // ── nudge markers ▼ + outcomes ─────────────────────────────────────
    double lastLabelX = -1e9;
    for (final n in day.nudges) {
      final x = l.x(n.at);
      c.drawPath(
        Path()
          ..moveTo(x - 3.5, line - 7)
          ..lineTo(x + 3.5, line - 7)
          ..lineTo(x, line - 2)
          ..close(),
        Paint()..color = p.amber,
      );
      final label = switch (n.outcome) {
        NudgeOutcome.taken => 'break taken',
        NudgeOutcome.snoozed => 'snoozed',
        NudgeOutcome.dismissed => 'dismissed',
        NudgeOutcome.ignored => 'no response',
        NudgeOutcome.pending => 'now',
      };
      if (x - lastLabelX > 90) {
        _text(c, '${_hm(n.at)} · $label', Offset(x, line - 14), size: 8.5, color: p.text2, align: TextAlign.center);
        lastLabelX = x;
      }
    }

    // ── break dots + the dip each caused ───────────────────────────────
    for (final b in day.breaks) {
      final x = l.x(b.at);
      if (b.mark == BreakMark.taken) {
        final v = day.pressureAt(b.at);
        if (v != null) {
          c.drawPath(
            _dash(
              Path()
                ..moveTo(x, l.dotsY - 4)
                ..lineTo(x, l.py(v) + 2),
              1,
              1.6,
            ),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.6
              ..color = p.text3,
          );
        }
        c.drawCircle(Offset(x, l.dotsY), 2.7, Paint()..color = p.selected);
      } else if (b.mark == BreakMark.suggested) {
        c.drawCircle(
          Offset(x, l.dotsY),
          2.5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = p.text2,
        );
      } else {
        c.drawCircle(
          Offset(x, l.dotsY),
          2.5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = p.text2,
        );
        c.drawArc(Rect.fromCircle(center: Offset(x, l.dotsY), radius: 2.5), -math.pi / 2, math.pi, true, Paint()..color = p.text2);
      }
    }

    // ── axis + hour labels ─────────────────────────────────────────────
    c.drawLine(
      Offset(_ScoreLayout.left, l.blockBase),
      Offset(l.right, l.blockBase),
      Paint()
        ..color = p.hairline
        ..strokeWidth = 1,
    );
    var t = DateTime(l.start.year, l.start.month, l.start.day, l.start.hour);
    final pxPerHour = (l.right - _ScoreLayout.left) / (l.spanMs / 3600000);
    final labelEvery = pxPerHour < 34 ? 2 : 1;
    while (!t.isAfter(l.end)) {
      final x = l.x(t);
      if (x >= _ScoreLayout.left - 1) {
        c.drawLine(
          Offset(x, l.blockBase),
          Offset(x, l.blockBase + 3.5),
          Paint()
            ..color = p.text3
            ..strokeWidth = 0.8,
        );
        if (t.hour % labelEvery == 0) {
          _text(c, '${(t.hour - 1) % 12 + 1}', Offset(x, l.blockBase + 11), size: 9, align: TextAlign.center);
        }
        final hx = l.x(t.add(const Duration(minutes: 30)));
        if (hx <= l.right) {
          c.drawLine(
            Offset(hx, l.blockBase),
            Offset(hx, l.blockBase + 2),
            Paint()
              ..color = p.text3.withValues(alpha: 0.6)
              ..strokeWidth = 0.6,
          );
        }
      }
      t = t.add(const Duration(hours: 1));
    }

    // ── meetings ───────────────────────────────────────────────────────
    for (final m in day.meetings) {
      c.drawRRect(
        RRect.fromLTRBR(l.x(m.start), l.meetingY - 2.5, l.x(m.end), l.meetingY + 2.5, const Radius.circular(2.5)),
        Paint()..color = p.text3.withValues(alpha: 0.55),
      );
    }

    // ── session blocks ─────────────────────────────────────────────────
    for (final (i, s) in day.sessions.indexed) {
      final x0 = l.x(s.start), x1 = l.x(s.end), h = l.blockH(s.demand);
      final ti = _tOf(i);
      final stone = p.pastByDemand[s.demand.index];
      switch (s.state) {
        case TimelineSessionState.done:
          final since = isToday ? now.difference(s.end) : const Duration(days: 1);
          // Home's blocks rise from the hour line (SETTLE, staggered)
          final col = p.drying(stone, since.isNegative ? Duration.zero : since);
          _block(c, x0, x1, l.blockBase, h * (ti >= 1e8 ? 1.0 : Motion.settleAt(ti, response: 0.55)), fill: col);
        case TimelineSessionState.active:
          _block(c, x0, x1, l.blockBase, h, stroke: p.accent, dashed: true, sw: 1.1);
          _block(c, x0, math.min(nowX, x1), l.blockBase, h, fill: p.accent);
        case TimelineSessionState.forecast:
          // your plan (the ghost) replaces the prediction while you size it
          // never draw a prediction on top of a running session
          final act = day.active;
          final overlapsActive = act != null && s.start.isBefore(act.end) && s.end.isAfter(act.start);
          if (_forecastTrusted && ghostMinutes <= 0.5 && !overlapsActive) _block(c, x0, x1, l.blockBase, h, stroke: p.future);
        case TimelineSessionState.scheduled:
          _block(c, x0, x1, l.blockBase, h, stroke: p.future, dashed: true);
      }
    }

    // ghost block (proposed session from NOW)
    if (showNow && ghostMinutes > 0.5) {
      final gx1 = l.x(now.add(Duration(seconds: (ghostMinutes * 60).round())));
      _block(c, nowX, gx1, l.blockBase, l.blockH(Demand.moderate), fill: p.accentTint);
      _block(c, nowX, gx1, l.blockBase, l.blockH(Demand.moderate), stroke: p.accent, dashed: true);
    }

    // draft (drag in the future to schedule)
    if (draft != null) {
      final a = draft!.$1.isBefore(draft!.$2) ? draft!.$1 : draft!.$2;
      final b = draft!.$1.isBefore(draft!.$2) ? draft!.$2 : draft!.$1;
      _block(c, l.x(a), l.x(b), l.blockBase, l.blockH(Demand.moderate), stroke: p.future, dashed: true, sw: 1.3);
      _text(
        c,
        '${_hm(a)}–${_hm(b)} · schedule',
        Offset((l.x(a) + l.x(b)) / 2, l.blockBase - l.maxBlock - 14),
        size: 9,
        color: p.text2,
        align: TextAlign.center,
      );
    }

    // ── NOW ────────────────────────────────────────────────────────────
    if (showNow) {
      final top = math.max(18.0, l.blockBase - l.maxBlock - 14);
      final bottom = l.dotsY + 4;
      c.drawLine(
        Offset(nowX, top),
        Offset(nowX, top + (bottom - top) * nowDraw),
        Paint()
          ..color = p.accent
          ..strokeWidth = 1,
      );
      _text(c, 'now ${_hm(now)}', Offset(nowX, top - 8), size: 9, color: p.accent, align: TextAlign.center, caps: true);
      final v = day.pressureAt(now) ?? (day.pressure.isNotEmpty ? day.pressure.last.v : null);
      if (v != null && nowDraw > 0.95) {
        final y = l.py(v);
        c.drawCircle(Offset(nowX, y), 3.2, Paint()..color = p.bg);
        c.drawCircle(Offset(nowX, y), 2.6, Paint()..color = p.accent);
        final eta = _minutesToLine();
        // body text uses text colours (accent < 4.5:1 in light); the dot carries the colour
        // percentages live on hover; the present only says what matters next
        if (eta != null) _text(c, 'line in ~${eta}m', Offset(nowX - 6, y + 11), size: 9, color: p.text2, align: TextAlign.right);
      }
    }

    // ── crosshair + card ───────────────────────────────────────────────
    if (hover != null) {
      final h = hover!;
      final x = l.x(h.at);
      c.drawLine(
        Offset(x, l.blockBase - l.maxBlock - 10),
        Offset(x, l.dotsY + 3),
        Paint()
          ..color = p.text2
          ..strokeWidth = 0.7,
      );
      final lines = <String>[
        [
          _hm(h.at),
          if (h.session?.taskText != null) h.session!.taskText!,
          if (h.meeting != null) h.meeting!.title ?? 'Meeting',
        ].join(' · '),
        [
          if (h.session != null) h.session!.demand.wire,
          if (h.pressure != null) 'pressure ${(h.pressure! * 100).round()}%',
          if (h.usual != null) 'usual ${(h.usual! * 100).round()}%',
        ].join(' · '),
      ].where((s) => s.isNotEmpty).toList();
      final cardW = 170.0, cardH = 12.0 + lines.length * 13;
      final cx = (x + 8 + cardW > l.right) ? x - 8 - cardW : x + 8;
      final cy = l.blockBase - l.maxBlock - 12;
      final r = RRect.fromLTRBR(cx, cy, cx + cardW, cy + cardH, const Radius.circular(6));
      c.drawRRect(r, Paint()..color = p.raised);
      c.drawRRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = p.hairline,
      );
      for (var i = 0; i < lines.length; i++) {
        _text(c, lines[i], Offset(cx + 8, cy + 12 + i * 13), size: i == 0 ? 10 : 9, color: i == 0 ? p.text1 : p.text3);
      }
    }
    c.restore();
  }

  int? _minutesToLine() {
    if (!_forecastTrusted) {
      final proj = _projection();
      if (proj == null) return null;
      final endT = layout.timeAt(proj.last.dx);
      return (layout.py(1.0) - proj.last.dy).abs() < 1.5 ? endT.difference(now).inMinutes : null;
    }
    for (final f in day.forecast) {
      if (f.v >= 1.0 && f.t.isAfter(now)) return f.t.difference(now).inMinutes;
    }
    // interpolate between forecast points
    for (var i = 0; i < day.forecast.length - 1; i++) {
      final a = day.forecast[i], b = day.forecast[i + 1];
      if (a.v < 1 && b.v >= 1) {
        final f = (1 - a.v) / (b.v - a.v);
        return a.t.add(Duration(milliseconds: (b.t.difference(a.t).inMilliseconds * f).round())).difference(now).inMinutes;
      }
    }
    return null;
  }

  static String _hm(DateTime t) => '${(t.hour - 1) % 12 + 1}:${t.minute.toString().padLeft(2, '0')}';

  @override
  bool shouldRepaint(_ScorePainter o) =>
      o.day != day ||
      o.now != now ||
      o.layout.start != layout.start ||
      o.layout.end != layout.end ||
      o.layout.size != layout.size ||
      o.ghostMinutes != ghostMinutes ||
      o.nowDraw != nowDraw ||
      o.rise != rise ||
      o.hover?.at != hover?.at ||
      o.draft != draft ||
      o.p != p;
}
