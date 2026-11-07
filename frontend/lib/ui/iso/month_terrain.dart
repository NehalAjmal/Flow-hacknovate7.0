import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../blocks.dart';
import 'iso.dart';

/// Month terrain (DESIGN_SPEC §6 deck "look back").
///
/// One cell per day on a hairline floor grid (rows = weeks, cols = weekdays);
/// pillars rise from their cells, height = focus minutes. Empty cells are just
/// the grid (no data / still learning / future). Hover lifts nearby pillars with
/// a clamped falloff, hit-tested against the ground (rest pose, no flicker).
/// The selected day is dark neutral (selection, never the accent).
class MonthTerrain extends StatefulWidget {
  const MonthTerrain({
    super.key,
    required this.month,
    required this.minutes,
    required this.selected,
    required this.onSelect,
    this.size = const Size(260, 150),
    this.weeks = 4,
  });

  /// The last day shown; the grid is the [weeks] weeks ending in this day's week
  /// (rolling, so the terrain is never empty at the start of a month).
  final DateTime month;
  final int weeks;
  final Map<DateTime, int> minutes;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;
  final Size size;

  @override
  State<MonthTerrain> createState() => _MonthTerrainState();
}

class _MonthTerrainState extends State<MonthTerrain> with TickerProviderStateMixin {
  late final _rise = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  late final _hoverX = SpringValue(vsync: this, initial: -100);
  late final _hoverY = SpringValue(vsync: this, initial: -100);
  late final _lift = SpringValue(vsync: this, initial: 0);
  (int, int)? _hoverCell;

  DateTime get _end => DateTime(widget.month.year, widget.month.month, widget.month.day);
  DateTime get _start => _end.subtract(Duration(days: _end.weekday - 1 + 7 * (widget.weeks - 1)));
  int get _rows => widget.weeks;

  DateTime? _dateAt(int row, int col) {
    if (row < 0 || row >= _rows || col < 0 || col > 6) return null;
    return _start.add(Duration(days: row * 7 + col));
  }

  (int, int) _cellOf(DateTime d) {
    final idx = DateTime(d.year, d.month, d.day).difference(_start).inDays;
    return (idx ~/ 7, idx % 7);
  }

  @override
  void initState() {
    super.initState();
    Motion.enterOnMount(context, _rise, () => mounted);
  }

  @override
  void didUpdateWidget(MonthTerrain old) {
    super.didUpdateWidget(old);
    // rise again only when the data is new (spec: never on every visit)
    if (!DateUtils.isSameDay(old.month, widget.month)) {
      _rise
        ..value = 0
        ..forward();
    }
  }

  @override
  void dispose() {
    _rise.dispose();
    _hoverX.dispose();
    _hoverY.dispose();
    _lift.dispose();
    super.dispose();
  }

  IsoCamera _cam() {
    // fit the 7 × rows grid into the box
    final s = math.min(widget.size.width / ((7 + _rows) * 0.7071 + 4.5), widget.size.height / ((7 + _rows) * 0.354 + 2.6));
    final origin = Offset(_rows * 0.7071 * s + 6, widget.size.height * 0.24);
    return IsoCamera(origin: origin, scale: s);
  }

  void _select(DateTime d) {
    HapticFeedback.selectionClick();
    widget.onSelect(d);
  }

  void _moveSel(int days) {
    final next = widget.selected.add(Duration(days: days));
    if (!next.isBefore(_start) && !next.isAfter(_end)) _select(next);
  }

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    final maxMin = widget.minutes.values.fold<int>(0, math.max);
    return Semantics(
      label:
          'Last ${widget.weeks} weeks of focus. Selected ${widget.selected.day}: ${widget.minutes[_key(widget.selected)] ?? 0} minutes. '
          'Arrow keys change the day.',
      child: Focus(
        onKeyEvent: (n, e) {
          if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
          final d = switch (e.logicalKey) {
            LogicalKeyboardKey.arrowLeft => -1,
            LogicalKeyboardKey.arrowRight => 1,
            LogicalKeyboardKey.arrowUp => -7,
            LogicalKeyboardKey.arrowDown => 7,
            _ => 0,
          };
          if (d == 0) return KeyEventResult.ignored;
          _moveSel(d);
          return KeyEventResult.handled;
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onHover: (e) {
            final (x, y) = _cam().unproject(e.localPosition);
            _hoverX.animateTo(x, spring: Motion.follow);
            _hoverY.animateTo(y, spring: Motion.follow);
            _lift.animateTo(1, spring: Motion.snap);
            final cell = (y.floor(), x.floor()); // world y = row, x = col
            if (cell != _hoverCell) setState(() => _hoverCell = cell);
          },
          onExit: (_) {
            _lift.animateTo(0, spring: Motion.settle);
            setState(() => _hoverCell = null);
          },
          child: GestureDetector(
            onTapUp: (e) {
              final (x, y) = _cam().unproject(e.localPosition);
              final d = _dateAt(y.floor(), x.floor());
              if (d != null && !d.isAfter(_end)) _select(d);
            },
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: Listenable.merge([_rise, _hoverX.animation, _hoverY.animation, _lift.animation]),
                builder: (context, _) => CustomPaint(
                  size: widget.size,
                  painter: _TerrainPainter(
                    p: p,
                    cam: _cam(),
                    rows: _rows,
                    dateAt: (r, c) {
                      final d = _dateAt(r, c);
                      return d == null || d.isAfter(_end) ? null : d;
                    },
                    minutes: widget.minutes,
                    maxMin: maxMin,
                    selected: _cellOf(widget.selected),
                    rise: _rise.value,
                    hover: Offset(_hoverX.value, _hoverY.value),
                    lift: _lift.value,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

DateTime _key(DateTime d) => DateTime(d.year, d.month, d.day);

class _TerrainPainter extends CustomPainter {
  _TerrainPainter({
    required this.p,
    required this.cam,
    required this.rows,
    required this.dateAt,
    required this.minutes,
    required this.maxMin,
    required this.selected,
    required this.rise,
    required this.hover,
    required this.lift,
  });

  final FlowPalette p;
  final IsoCamera cam;
  final int rows;
  final DateTime? Function(int, int) dateAt;
  final Map<DateTime, int> minutes;
  final int maxMin;
  final (int, int) selected;
  final double rise;
  final Offset hover;
  final double lift;

  static const maxH = 1.3; // world units for the tallest day

  @override
  void paint(Canvas c, Size size) {
    // floor grid first (behind everything)
    for (var r = 0; r < rows; r++) {
      for (var col = 0; col < 7; col++) {
        if (dateAt(r, col) != null) paintCell(c, cam, col.toDouble(), r.toDouble(), 1, p.hairline);
      }
    }
    // the selected day's floor cell, so a 0-minute day still shows the selection
    final (sr, sc) = selected;
    if (dateAt(sr, sc) != null) {
      final cell = Path()
        ..moveTo(cam.project(sc + 0.1, sr + 0.1).dx, cam.project(sc + 0.1, sr + 0.1).dy)
        ..lineTo(cam.project(sc + 0.9, sr + 0.1).dx, cam.project(sc + 0.9, sr + 0.1).dy)
        ..lineTo(cam.project(sc + 0.9, sr + 0.9).dx, cam.project(sc + 0.9, sr + 0.9).dy)
        ..lineTo(cam.project(sc + 0.1, sr + 0.9).dx, cam.project(sc + 0.1, sr + 0.9).dy)
        ..close();
      c.drawPath(cell, Paint()..color = p.selected.withValues(alpha: 0.18));
      c.drawPath(
        cell,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = p.selected,
      );
    }
    // pillars back to front: far corner first
    final cells = <(int, int)>[
      for (var r = 0; r < rows; r++)
        for (var col = 0; col < 7; col++) (r, col),
    ]..sort((a, b) => (a.$1 + a.$2).compareTo(b.$1 + b.$2));
    for (final (r, col) in cells) {
      final d = dateAt(r, col);
      if (d == null) continue;
      final m = minutes[_key(d)];
      if (m == null || m == 0 || maxMin == 0) continue;
      // each day arrives like the wordmark: a dashed outline ("not yet"),
      // then liquid fills it from the floor; the surface sloshes and calms.
      // Staggered outward from the selected day.
      final dist = ((r - selected.$1).abs() + (col - selected.$2).abs()).toDouble();
      final t = rise >= 1 ? 1e9 : rise * 2.4 - dist * 0.05;
      final lf = LiquidFill.at(t, response: 0.75, outlineLead: 0.22, maxRipple: 0.09);
      final hd = (Offset(col + 0.5, r + 0.5) - hover).distance;
      final full = maxH * (m / maxMin) + 0.35 * lift * falloff(hd, 2.2);
      final isSel = (r, col) == selected;
      final ramp = m / maxMin;
      final fill = isSel ? p.selected : (ramp < 0.4 ? p.pastLight : (ramp < 0.75 ? p.pastModerate : p.pastHeavy));
      final oa = lf.outlineAlpha(t);
      if (oa > 0) paintPillarOutline(c, cam, col.toDouble(), r.toDouble(), 1, full, p.text3.withValues(alpha: oa), inset: 0.17);
      if (lf.level > 0.002) {
        paintPillar(
          c,
          cam,
          col.toDouble(),
          r.toDouble(),
          1,
          math.max(0.05, full * lf.level),
          fill,
          inset: 0.17,
          ripple: lf.ripple,
          phase: lf.phase,
        );
      }
    }
    // labels outside the objects (Hairline rule 10)
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    for (var col = 0; col < 7; col++) {
      final at = cam.project(col + 0.5, rows + 0.75);
      _t(c, days[col], at, col == selected.$2 ? p.text1 : p.text3);
    }
    if (maxMin > 0) {
      final at = cam.project(7.6, 0);
      _t(c, 'TALLEST = ${maxMin ~/ 60} H ${(maxMin % 60).toString().padLeft(2, '0')}', at, p.text3, left: true);
    }
  }

  void _t(Canvas c, String s, Offset at, Color color, {bool left = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontFamily: FlowFonts.mono, fontSize: 9.5, color: color, letterSpacing: 1, fontFeatures: FlowType.tabular),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(left ? at.dx : at.dx - tp.width / 2, at.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_TerrainPainter o) =>
      o.rise != rise ||
      o.hover != hover ||
      o.lift != lift ||
      o.selected != selected ||
      o.minutes != minutes ||
      o.p != p ||
      o.cam.scale != cam.scale;
}
