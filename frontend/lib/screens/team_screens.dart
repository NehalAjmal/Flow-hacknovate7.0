import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_connector.dart';
import '../api/models/team.dart';
import '../state/data_providers.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import '../ui/appear.dart';
import '../ui/blocks.dart';
import '../ui/feature_note.dart';
import '../ui/iso/iso.dart';
import '../ui/kit.dart';
import '../ui/loading_blocks.dart';
import '../widgets/common.dart';
import 'shell.dart' show FlowHeader;

const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
String _pct(double v) => '${(v * 100).round()}';

// ── Team (employees and admins) ─────────────────────────────────────────────

/// Team (spec §11). Aggregates only, never a person. Below 5 people: the
/// empty grid and one sentence; no numbers, no animation.
class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = FlowPalette.of(context);
    final t = ref.watch(teamSummaryProvider);
    return LayoutBuilder(
      builder: (context, viewport) {
        // fill the page: the week takes the height the window has
        final h = (viewport.maxHeight - 210).clamp(300.0, 760.0);
        return ListView(
          padding: const EdgeInsets.only(right: 24, bottom: 32),
          children: [
            FlowHeader(title: 'Team', subtitle: t.value == null ? null : 'Group of ${t.value!.groupSize} · averages only'),
            const SizedBox(height: 10),
            switch (t) {
              AsyncData(:final value) when value.suppressed || value.data == null => _Suppressed(groupSize: value.groupSize, height: h),
              AsyncData(:final value) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TwoUp(
                    left: ColorField(
                      tone: FieldTone.past,
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionLabel("The team's week"),
                          const SizedBox(height: 4),
                          Text('Each pillar is one day: the average focus of everyone who shares.', style: FlowType.note(p, size: 14)),
                          SizedBox(
                            height: h,
                            child: _TeamWeek(points: value.data!.trend, groupSize: value.groupSize),
                          ),
                        ],
                      ),
                    ),
                    right: ColorField(
                      tone: FieldTone.planned,
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionLabel('Average focus'),
                          const SizedBox(height: 10),
                          Appear(child: TabularNumeral(_pct(value.data!.averageFocus), style: FlowType.numeral(p, 72))),
                          const SizedBox(height: 4),
                          Text('out of 100, this week', style: FlowType.chart(p, size: 11)),
                          const SizedBox(height: 22),
                          SizedBox(
                            height: (h - 300).clamp(150.0, 420.0),
                            child: _TrendLine(points: value.data!.trend),
                          ),
                          const SizedBox(height: 18),
                          const FeatureNote(
                            number: 1,
                            compact: true,
                            title: 'Only averages',
                            body: 'No one, admins included, can see a single person here.',
                          ),
                          const SizedBox(height: 10),
                          const FeatureNote(
                            number: 2,
                            compact: true,
                            title: 'You can leave',
                            body: 'Turn off "Team averages" in Privacy and you drop out of these numbers.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              AsyncError(:final error) => InlineError(message: errorText(error), onRetry: () => ref.invalidate(teamSummaryProvider)),
              _ => SizedBox(
                height: h,
                child: const Center(child: LoadingBlocks(height: 160, count: 7)),
              ),
            },
          ],
        );
      },
    );
  }
}

/// Left/right bands that stack under 980 px.
class _TwoUp extends StatelessWidget {
  const _TwoUp({required this.left, required this.right, this.flex = const (11, 9)});
  final Widget left;
  final Widget right;
  final (int, int) flex;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => box.maxWidth < 980
        ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, const SizedBox(height: 18), right])
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: flex.$1, child: left),
              const SizedBox(width: 18),
              Expanded(flex: flex.$2, child: right),
            ],
          ),
  );
}

/// Fewer than 5 people: the empty grid, one sentence, nothing else.
class _Suppressed extends StatelessWidget {
  const _Suppressed({required this.groupSize, required this.height});
  final int groupSize;
  final double height;
  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    return ColorField(
      tone: FieldTone.past,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: height,
            child: CustomPaint(size: Size.infinite, painter: _EmptyGridPainter(p)),
          ),
          const SizedBox(height: 10),
          Text(
            'Team data appears when at least ${Suppressible.minGroupSize} people share (now $groupSize). '
            'Small groups stay hidden so no one can be picked out.',
            style: FlowType.note(p, size: 15, color: p.text1),
          ),
        ],
      ),
    );
  }
}

class _EmptyGridPainter extends CustomPainter {
  _EmptyGridPainter(this.p);
  final FlowPalette p;
  @override
  void paint(Canvas c, Size s) {
    final cam = _weekCamera(s);
    for (var r = 0; r < 4; r++) {
      for (var col = 0; col < 7; col++) {
        paintCell(c, cam, col.toDouble(), r.toDouble(), 1, p.hairline);
      }
    }
  }

  @override
  bool shouldRepaint(_EmptyGridPainter o) => o.p != p;
}

IsoCamera _weekCamera(Size s, {double depth = 4, double maxZ = 3}) {
  // fit world x 0..7, y 0..depth, z 0..maxZ into the box
  const c = 0.7071;
  final scale = math.min(s.width / ((7 + depth) * c * 1.08), s.height / (((7 + depth) * c * 0.5 + maxZ) * 1.12));
  final cx = (7 - depth) * c * scale / 2; // screen x of the footprint centre relative to origin
  final top = maxZ * scale;
  return IsoCamera(origin: Offset(s.width / 2 - cx, top + (s.height - top - (7 + depth) * c * 0.5 * scale) / 2), scale: scale);
}

/// The team's week as seven day pillars on a hairline floor (aggregate).
/// Day pillars arrive like the wordmark: outline, then a liquid fill.
class _TeamWeek extends StatefulWidget {
  const _TeamWeek({required this.points, required this.groupSize});
  final List<TrendPoint> points;
  final int groupSize;
  @override
  State<_TeamWeek> createState() => _TeamWeekState();
}

class _TeamWeekState extends State<_TeamWeek> with SingleTickerProviderStateMixin {
  late final _in = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  int? _hover;

  @override
  void initState() {
    super.initState();
    Motion.enterOnMount(context, _in, () => mounted);
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final cam = _weekCamera(box.biggest, depth: 1.6);
      return MouseRegion(
        onHover: (e) {
          final (x, y) = cam.unproject(e.localPosition.translate(0, cam.scale * 0.8));
          final i = (x >= 0 && x < 7 && y > -1.5 && y < 2.5) ? x.floor() : null;
          if (i != _hover) setState(() => _hover = i);
        },
        onExit: (_) => setState(() => _hover = null),
        child: AnimatedBuilder(
          animation: _in,
          builder: (context, _) => CustomPaint(
            size: box.biggest,
            painter: _TeamWeekPainter(
              FlowPalette.of(context),
              widget.points,
              cam,
              _in.isCompleted ? 1e9 : _in.value * 2.2,
              _hover,
              widget.groupSize,
              MediaQuery.textScalerOf(context),
            ),
          ),
        ),
      );
    },
  );
}

class _TeamWeekPainter extends CustomPainter {
  _TeamWeekPainter(this.p, this.points, this.cam, this.t, this.hover, this.group, this.scaler);
  final FlowPalette p;
  final List<TrendPoint> points;
  final IsoCamera cam;
  final double t;
  final int? hover;
  final int group;
  final TextScaler scaler;

  @override
  void paint(Canvas c, Size s) {
    for (var col = 0; col < 7; col++) {
      paintCell(c, cam, col.toDouble(), 0, 1, p.hairline);
    }
    final pts = points.length > 7 ? points.sublist(points.length - 7) : points;
    for (var i = 0; i < pts.length; i++) {
      final v = pts[i].value.clamp(0.0, 1.0);
      final full = 3.0 * v + (hover == i ? 0.25 : 0);
      final ti = t >= 1e8 ? 1e9 : t - i * 0.08;
      final lf = LiquidFill.at(ti, response: 0.75, outlineLead: 0.22, maxRipple: 0.08);
      final col = v > 0.66 ? p.pastHeavy : (v > 0.45 ? p.pastModerate : p.pastLight);
      final oa = lf.outlineAlpha(ti);
      if (oa > 0) paintPillarOutline(c, cam, i.toDouble(), 0, 1, full, p.text3.withValues(alpha: oa), inset: 0.14);
      if (lf.level > 0.002) {
        paintPillar(
          c,
          cam,
          i.toDouble(),
          0,
          1,
          math.max(0.04, full * lf.level),
          hover == i ? p.selected : col,
          inset: 0.14,
          ripple: lf.ripple,
          phase: lf.phase,
        );
      }
      // labels outside the object: day under the floor, value only on hover
      final at = cam.project(i + 0.5, 1.35);
      final day = TextPainter(
        text: TextSpan(
          text: _dayNames[pts[i].date.weekday - 1],
          style: FlowType.chart(p, size: 10.5, color: hover == i ? p.text1 : p.text3),
        ),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      day.paint(c, at - Offset(day.width / 2, 0));
      if (hover == i) {
        final top = cam.project(i + 0.5, 0.5, full);
        final label = TextPainter(
          text: TextSpan(
            text: '${_dayNames[pts[i].date.weekday - 1]} · avg ${_pct(v)} · $group people',
            style: FlowType.chart(p, size: 11, color: p.onSelected),
          ),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
        )..layout();
        final lx = (top.dx - label.width / 2 - 8).clamp(0.0, s.width - label.width - 16);
        final r = RRect.fromLTRBR(lx, top.dy - 34, lx + label.width + 16, top.dy - 12, const Radius.circular(6));
        c.drawRRect(r, Paint()..color = p.selected);
        label.paint(c, Offset(lx + 8, top.dy - 23 - label.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(_TeamWeekPainter o) => o.t != t || o.hover != hover || o.points != points || o.p != p || o.cam.scale != cam.scale;
}

/// 2D trend: a line over a faint area; the last value is labelled at the line's
/// end; hovering reads any day.
class _TrendLine extends StatefulWidget {
  const _TrendLine({required this.points});
  final List<TrendPoint> points;
  @override
  State<_TrendLine> createState() => _TrendLineState();
}

class _TrendLineState extends State<_TrendLine> with SingleTickerProviderStateMixin {
  late final _draw = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  double? _hx;

  @override
  void initState() {
    super.initState();
    Motion.enterOnMount(context, _draw, () => mounted);
  }

  @override
  void didUpdateWidget(_TrendLine old) {
    super.didUpdateWidget(old);
    if (old.points.length != widget.points.length && !Motion.reduced(context)) {
      _draw
        ..value = 0
        ..forward();
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    onHover: (e) => setState(() => _hx = e.localPosition.dx),
    onExit: (_) => setState(() => _hx = null),
    child: AnimatedBuilder(
      animation: _draw,
      builder: (context, _) => CustomPaint(
        size: Size.infinite,
        painter: _TrendPainter(
          FlowPalette.of(context),
          widget.points,
          Curves.easeInOutCubic.transform(_draw.value),
          _hx,
          MediaQuery.textScalerOf(context),
        ),
      ),
    ),
  );
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.p, this.pts, this.progress, this.hx, this.scaler);
  final FlowPalette p;
  final List<TrendPoint> pts;
  final double progress;
  final double? hx;
  final TextScaler scaler;

  void _t(Canvas c, String s, Offset at, Color col, {bool right = false, double size = 10.5}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: FlowType.chart(p, size: size, color: col),
      ),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    tp.paint(c, Offset(right ? at.dx - tp.width : at.dx, at.dy - tp.height / 2));
  }

  @override
  void paint(Canvas c, Size s) {
    if (pts.length < 2) return;
    const left = 0.0, top = 12.0;
    final right = s.width - 34, base = s.height - 16;
    double x(int i) => left + (right - left) * i / (pts.length - 1);
    double y(double v) => base - (base - top) * v.clamp(0.0, 1.0);
    c.drawLine(
      Offset(left, base),
      Offset(s.width, base),
      Paint()
        ..color = p.text3
        ..strokeWidth = 1,
    );
    for (final v in [0.5, 1.0]) {
      for (var xx = left; xx < right; xx += 6) {
        c.drawLine(
          Offset(xx, y(v)),
          Offset(xx + 2, y(v)),
          Paint()
            ..color = p.hairline
            ..strokeWidth = 0.8,
        );
      }
      _t(c, _pct(v), Offset(s.width, y(v)), p.text3, right: true, size: 9.5);
    }
    final line = Path()..moveTo(x(0), y(pts[0].value));
    for (var i = 1; i < pts.length; i++) {
      line.lineTo(x(i), y(pts[i].value));
    }
    final drawn = Path();
    for (final m in line.computeMetrics()) {
      drawn.addPath(m.extractPath(0, m.length * progress), Offset.zero);
    }
    final area = Path.from(line)
      ..lineTo(x(pts.length - 1), base)
      ..lineTo(x(0), base)
      ..close();
    c.drawPath(area, Paint()..color = p.pastModerate.withValues(alpha: 0.22 * progress));
    c.drawPath(
      drawn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round
        ..color = p.pastHeavy,
    );
    if (progress >= 1) {
      final last = Offset(x(pts.length - 1), y(pts.last.value));
      c.drawCircle(last, 3.2, Paint()..color = p.selected);
      _t(c, _pct(pts.last.value), last.translate(7, 0), p.text1, size: 11);
    }
    final h = hx;
    if (h != null && progress >= 1) {
      final i = ((h - left) / (right - left) * (pts.length - 1)).round().clamp(0, pts.length - 1);
      final o = Offset(x(i), y(pts[i].value));
      c.drawLine(
        Offset(o.dx, top),
        Offset(o.dx, base),
        Paint()
          ..color = p.text2
          ..strokeWidth = 0.7,
      );
      c.drawCircle(o, 3, Paint()..color = p.selected);
      final d = pts[i].date;
      _t(
        c,
        '${_dayNames[d.weekday - 1]} ${d.day} · ${_pct(pts[i].value)}',
        Offset(o.dx + 8 > right - 90 ? o.dx - 8 : o.dx + 8, top + 2),
        p.text1,
        right: o.dx + 8 > right - 90,
      );
    }
  }

  @override
  bool shouldRepaint(_TrendPainter o) => o.progress != progress || o.hx != hx || o.pts != pts || o.p != p;
}

// ── Admin ───────────────────────────────────────────────────────────────────

/// Admin (spec §11): the privacy panel first, then the team's week, trend,
/// workload band and meeting window, then invites and the activity log.
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});
  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  bool _thirty = false;

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    final privacy = ref.watch(adminPrivacyProvider);
    final summary = ref.watch(adminSummaryProvider);
    final trend = ref.watch(adminTrendProvider);
    final insights = ref.watch(adminInsightsProvider);
    final strain = ref.watch(adminStrainProvider);
    final window = ref.watch(adminMeetingWindowProvider);
    final group = privacy.value?.groupSize;
    final suppressed = privacy.value?.suppressed ?? false;

    return LayoutBuilder(
      builder: (context, viewport) {
        final h = (viewport.maxHeight * 0.42).clamp(280.0, 400.0);
        return ListView(
          padding: const EdgeInsets.only(right: 24, bottom: 32),
          children: [
            FlowHeader(title: 'Team admin', subtitle: group == null ? 'Aggregates only' : 'Group of $group · aggregates only'),
            const SizedBox(height: 10),
            _TwoUp(
              flex: const (8, 12),
              // the privacy panel always comes first
              left: ColorField(
                tone: FieldTone.planned,
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                child: switch (privacy) {
                  AsyncData(:final value) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionLabel('What you can and cannot see'),
                      const SizedBox(height: 12),
                      for (final s in value.canSee) _Line(ok: true, text: s),
                      const SizedBox(height: 10),
                      for (final s in value.cannotSee) _Line(ok: false, text: s),
                      const SizedBox(height: 14),
                      Text(
                        value.suppressed
                            ? 'Hidden right now: fewer than ${Suppressible.minGroupSize} people share (now ${value.groupSize}).'
                            : 'Everything here is an average over ${value.groupSize} people who chose to share.',
                        style: FlowType.note(p, size: 14, color: p.text1),
                      ),
                    ],
                  ),
                  AsyncError(:final error) => InlineError(message: errorText(error), onRetry: () => ref.invalidate(adminPrivacyProvider)),
                  _ => const LoadingBlocks(height: 100),
                },
              ),
              right: suppressed
                  ? _Suppressed(groupSize: group ?? 0, height: h)
                  : ColorField(
                      tone: FieldTone.past,
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const SectionLabel("The team's week"),
                              const Spacer(),
                              if (summary.value?.data case final s?)
                                Text(
                                  '${s.activeCount} in a session now · ${s.sessionVolume} sessions this week',
                                  style: FlowType.chart(p, size: 10.5),
                                ),
                            ],
                          ),
                          SizedBox(
                            height: h,
                            child: switch (trend) {
                              AsyncData(:final value) when value.data != null => _TeamWeek(
                                points: value.data!.days7,
                                groupSize: group ?? 0,
                              ),
                              AsyncError(:final error) => InlineError(
                                message: errorText(error),
                                onRetry: () => ref.invalidate(adminTrendProvider),
                              ),
                              _ => const Center(child: LoadingBlocks(height: 140, count: 7)),
                            },
                          ),
                        ],
                      ),
                    ),
            ),
            if (!suppressed) ...[
              const SizedBox(height: 18),
              _TwoUp(
                left: ColorField(
                  tone: FieldTone.past,
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const SectionLabel('Average focus'),
                          const Spacer(),
                          for (final (label, v) in const [('7 days', false), ('30 days', true)]) ...[
                            Pressable(
                              selected: _thirty == v,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              onPressed: () => setState(() => _thirty = v),
                              child: Text(label),
                            ),
                            const SizedBox(width: 6),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 190,
                        child: switch (trend) {
                          AsyncData(:final value) when value.data != null => _TrendLine(
                            points: _thirty ? value.data!.days30 : value.data!.days7,
                          ),
                          _ => const SizedBox.shrink(),
                        },
                      ),
                    ],
                  ),
                ),
                right: ColorField(
                  tone: FieldTone.rest,
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionLabel('Workload'),
                      const SizedBox(height: 4),
                      Text('A team-level reading of break pressure. Not a health measure.', style: FlowType.note(p, size: 13.5)),
                      const SizedBox(height: 12),
                      switch (strain) {
                        AsyncData(:final value) when value.data != null => _WorkloadBand(level: value.data!.level, note: value.data!.note),
                        _ => const SizedBox(height: 60),
                      },
                      const SizedBox(height: 22),
                      const SectionLabel('Best meeting window'),
                      const SizedBox(height: 10),
                      switch ((window, insights)) {
                        (AsyncData(value: final w), AsyncData(value: final ins)) when w.data != null => SizedBox(
                          height: 64,
                          child: _DaySpine(start: w.data!.start, end: w.data!.end, peaks: ins.data?.peakHours ?? const []),
                        ),
                        _ => const SizedBox(height: 64),
                      },
                      if (insights.value?.data?.typicalRecoveryMin case final m?) ...[
                        const SizedBox(height: 10),
                        Text('After a break, people are typically back in focus within $m min.', style: FlowType.note(p, size: 13.5)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            const _TwoUp(left: _Invites(), right: _Audit()),
          ],
        );
      },
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.ok, required this.text});
  final bool ok;
  final String text;
  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Text(ok ? '✓' : '✕', style: TextStyle(color: ok ? p.text1 : p.text3, fontSize: 13)),
          ),
          Expanded(
            child: Text(text, style: TextStyle(color: ok ? p.text1 : p.text2, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

/// Workload as a filled band (low · moderate · high), not a gauge: the
/// band fills up to the current level with SETTLE.
class _WorkloadBand extends StatelessWidget {
  const _WorkloadBand({required this.level, required this.note});
  final String level;
  final String note;
  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    final to = switch (level) {
      'low' => 1 / 3,
      'high' => 1.0,
      _ => 2 / 3,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: to),
          duration: Motion.reduced(context) ? Duration.zero : const Duration(milliseconds: 1000),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => CustomPaint(size: const Size(double.infinity, 26), painter: _BandPainter(p, v)),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final l in const ['low', 'moderate', 'high'])
              Expanded(
                child: Text(
                  flowCaps(l),
                  textAlign: TextAlign.center,
                  style: FlowType.label(p, size: 9.5, color: l == level ? p.text1 : p.text3),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(note, style: FlowType.note(p, size: 14, color: p.text1)),
      ],
    );
  }
}

class _BandPainter extends CustomPainter {
  _BandPainter(this.p, this.v);
  final FlowPalette p;
  final double v;
  @override
  void paint(Canvas c, Size s) {
    final r = RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(6));
    c.drawRRect(r, Paint()..color = p.recess);
    c.save();
    c.clipRRect(r);
    final cols = [p.pastLight, p.pastModerate, p.amber.withValues(alpha: 0.75)];
    for (var i = 0; i < 3; i++) {
      final x0 = s.width * i / 3, x1 = math.min(s.width * (i + 1) / 3, s.width * v);
      if (x1 > x0) c.drawRect(Rect.fromLTRB(x0, 0, x1, s.height), Paint()..color = cols[i]);
    }
    c.restore();
    for (var i = 1; i < 3; i++) {
      c.drawLine(
        Offset(s.width * i / 3, 3),
        Offset(s.width * i / 3, s.height - 3),
        Paint()
          ..color = p.bg
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_BandPainter o) => o.v != v || o.p != p;
}

/// The working day (8–20) as a line; the suggested meeting window is a
/// highlighted span; the team's peak hours are ▲ (protect them).
class _DaySpine extends StatelessWidget {
  const _DaySpine({required this.start, required this.end, required this.peaks});
  final String start;
  final String end;
  final List<int> peaks;
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.infinite,
    painter: _SpinePainter(FlowPalette.of(context), start, end, peaks, MediaQuery.textScalerOf(context)),
  );
}

class _SpinePainter extends CustomPainter {
  _SpinePainter(this.p, this.start, this.end, this.peaks, this.scaler);
  final FlowPalette p;
  final String start, end;
  final List<int> peaks;
  final TextScaler scaler;

  static double _h(String hm) {
    final parts = hm.split(':');
    return (double.tryParse(parts[0]) ?? 0) + (double.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0) / 60;
  }

  void _t(Canvas c, String s, Offset at, Color col) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: FlowType.chart(p, size: 10, color: col),
      ),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    tp.paint(c, Offset(at.dx - tp.width / 2, at.dy - tp.height / 2));
  }

  @override
  void paint(Canvas c, Size s) {
    const h0 = 8.0, h1 = 20.0;
    double x(double h) => s.width * (h - h0) / (h1 - h0);
    final y = s.height * 0.45;
    final a = x(_h(start).clamp(h0, h1)), b = x(_h(end).clamp(h0, h1));
    c.drawRRect(RRect.fromLTRBR(a, y - 10, b, y + 10, const Radius.circular(5)), Paint()..color = p.selected.withValues(alpha: 0.85));
    _t(c, '$start–$end', Offset((a + b) / 2, y - 20), p.text1);
    c.drawLine(
      Offset(0, y),
      Offset(s.width, y),
      Paint()
        ..color = p.text3
        ..strokeWidth = 1,
    );
    for (var h = h0; h <= h1; h += 2) {
      c.drawLine(
        Offset(x(h), y),
        Offset(x(h), y + 4),
        Paint()
          ..color = p.text3
          ..strokeWidth = 0.8,
      );
      _t(c, '${h.toInt()}', Offset(x(h), y + 14), p.text3);
    }
    for (final pk in peaks) {
      final px = x(pk + 0.5);
      c.drawPath(
        Path()
          ..moveTo(px - 4, y + 30)
          ..lineTo(px + 4, y + 30)
          ..lineTo(px, y + 24)
          ..close(),
        Paint()..color = p.pastHeavy,
      );
    }
    if (peaks.isNotEmpty) _t(c, 'focus peaks', Offset(x(peaks.first + 0.5) + 36, y + 27), p.text3);
  }

  @override
  bool shouldRepaint(_SpinePainter o) => o.start != start || o.end != end || o.p != p;
}

// ── invites + activity ──────────────────────────────────────────────────────

class _Invites extends ConsumerStatefulWidget {
  const _Invites();
  @override
  ConsumerState<_Invites> createState() => _InvitesState();
}

class _InvitesState extends ConsumerState<_Invites> {
  Invite? _fresh; // the link is shown once, right here

  Future<void> _create() async {
    try {
      final inv = await ref.read(adminApiProvider).createInvite();
      ref.invalidate(invitesProvider);
      ref.invalidate(auditLogProvider);
      if (mounted) setState(() => _fresh = inv);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    final invites = ref.watch(invitesProvider);
    final loc = MaterialLocalizations.of(context);
    return ColorField(
      tone: FieldTone.planned,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SectionLabel('Invites'),
              const Spacer(),
              Pressable(tone: PressableTone.primary, onPressed: _create, child: const Text('New invite')),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topLeft,
            child: _fresh?.url == null
                ? const SizedBox(width: double.infinity)
                : Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: p.raised,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: p.hairline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(_fresh!.url!, style: FlowType.chart(p, size: 11.5, color: p.text1)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Single use · expires ${loc.formatMediumDate(_fresh!.expiresAt)} · shown only now',
                                style: FlowType.chart(p, size: 10.5),
                              ),
                            ),
                            Pressable(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              onPressed: () => Clipboard.setData(ClipboardData(text: _fresh!.url!)),
                              child: const Text('Copy'),
                            ),
                            const SizedBox(width: 6),
                            Pressable(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              onPressed: () => setState(() => _fresh = null),
                              child: const Text('Done'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          AsyncSection(
            lines: 5,
            value: invites,
            onRetry: () => ref.invalidate(invitesProvider),
            builder: (list) => Column(
              children: [
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('No open invites.', style: FlowType.note(p, size: 14)),
                  ),
                for (final (i, inv) in list.indexed)
                  Appear(
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: inv.used ? p.selected : null,
                              border: inv.used ? null : Border.all(color: p.text3),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              inv.used ? 'Used' : (inv.expired ? 'Expired' : 'Open'),
                              style: TextStyle(color: p.text1, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                          Text('expires ${loc.formatMediumDate(inv.expiresAt)}', style: FlowType.chart(p, size: 10.5)),
                          if (!inv.used) ...[
                            const SizedBox(width: 10),
                            TextButton(
                              onPressed: () async {
                                await runGuarded(context, () => ref.read(adminApiProvider).revokeInvite(inv.id));
                                ref.invalidate(invitesProvider);
                                ref.invalidate(auditLogProvider);
                              },
                              child: Text(
                                'Revoke',
                                style: TextStyle(color: p.text1, fontSize: 12.5, decoration: TextDecoration.underline),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Audit extends ConsumerWidget {
  const _Audit();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = FlowPalette.of(context);
    final log = ref.watch(auditLogProvider);
    final loc = MaterialLocalizations.of(context);
    return ColorField(
      tone: FieldTone.past,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Admin activity'),
          const SizedBox(height: 4),
          Text('Every admin action is recorded here, and the team can ask to see it.', style: FlowType.note(p, size: 13.5)),
          const SizedBox(height: 10),
          AsyncSection(
            lines: 5,
            value: log,
            onRetry: () => ref.invalidate(auditLogProvider),
            builder: (list) => Column(
              children: [
                if (list.isEmpty) Text('No admin actions yet.', style: FlowType.note(p, size: 14)),
                for (final (i, e) in list.take(10).indexed)
                  Appear(
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          SizedBox(width: 92, child: Text(loc.formatShortMonthDay(e.at), style: FlowType.chart(p, size: 10.5))),
                          Expanded(
                            child: Text(e.action, style: TextStyle(color: p.text1, fontSize: 13)),
                          ),
                          Text(e.actor, style: FlowType.chart(p, size: 10.5)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
