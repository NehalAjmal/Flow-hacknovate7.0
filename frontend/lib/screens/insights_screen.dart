import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/models/day.dart';
import '../api/models/insights.dart';
import '../api/models/session.dart';
import '../core/save_file.dart';
import '../router/routes.dart';
import '../state/data_providers.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import '../ui/appear.dart';
import '../ui/blocks.dart';
import '../ui/feature_note.dart';
import '../ui/kit.dart';
import '../ui/loading_blocks.dart';
import '../ui/score/day_score.dart';
import '../widgets/common.dart';
import 'shell.dart' show FlowHeader;

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

DateTime _d(DateTime t) => DateTime(t.year, t.month, t.day);
DateTime _monday(DateTime t) => _d(t).subtract(Duration(days: t.weekday - 1));

/// Insights (spec §8): the week as day cards standing on a floor line; the
/// chosen day in full underneath; then what Flow has learned, each on its own
/// wash, every band full width so nothing sits in empty space (rule 1).
class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});
  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  int _weekOffset = 0;
  int? _dayIndex;

  DateTime get _weekStart => _monday(DateTime.now()).add(Duration(days: 7 * _weekOffset));

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    final now = DateTime.now();
    final week = ref.watch(weekTimelinesProvider(_weekStart));
    final patterns = ref.watch(patternsProvider);
    final todayIdx = _weekOffset == 0 ? now.weekday - 1 : 6;
    final sel = _dayIndex ?? todayIdx;

    final weekNo = ((_weekStart.difference(DateTime(_weekStart.year, 1, 1)).inDays + DateTime(_weekStart.year, 1, 1).weekday) / 7).ceil();
    final days = week.value;
    final totalMin = days?.fold<int>(0, (a, d) => a + d.totals.focusMinutes) ?? 0;
    final breaks = days?.fold<int>(0, (a, d) => a + d.totals.breaksTaken) ?? 0;

    return LayoutBuilder(
      builder: (context, viewport) {
        final cardsH = (viewport.maxHeight * 0.34).clamp(220.0, 320.0);
        return ListView(
          padding: const EdgeInsets.only(right: 24, bottom: 32),
          children: [
            FlowHeader(
              title: 'Insights',
              subtitle: 'Week $weekNo · ${flowDuration(totalMin)} focused · $breaks breaks',
              action: _WeekStepper(
                label: _weekOffset == 0 ? 'This week' : (_weekOffset == -1 ? 'Last week' : '${-_weekOffset} weeks ago'),
                onBack: () => setState(() {
                  _weekOffset--;
                  _dayIndex = null;
                }),
                onForward: _weekOffset < 0
                    ? () => setState(() {
                        _weekOffset++;
                        _dayIndex = null;
                      })
                    : null,
              ),
            ),
            const SizedBox(height: 10),
            // ── DISPLAY: the week ──
            switch (week) {
              AsyncData(:final value) => _WeekCards(
                days: value,
                selected: sel,
                futureFrom: _weekOffset == 0 ? now.weekday : 7,
                height: cardsH,
                onSelect: (i) => setState(() => _dayIndex = i),
              ),
              AsyncError(:final error) => Text(errorText(error)),
              _ => SizedBox(
                height: cardsH,
                child: Center(
                  child: LoadingBlocks(height: cardsH * 0.6, count: 7, label: 'Loading the week'),
                ),
              ),
            },
            const SizedBox(height: 16),
            // the chosen day, in full
            if (days != null)
              ColorField(
                tone: FieldTone.past,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionLabel(
                      '${_days[sel]} ${days[sel].date.day} ${_months[days[sel].date.month - 1]} · ${flowDuration(days[sel].totals.focusMinutes)}',
                    ),
                    const SizedBox(height: 6),
                    DayScore(
                      day: days[sel],
                      now: now,
                      height: 300,
                      onSessionTap: (s) => s.id == null ? null : context.go(Routes.sessionEndFor(s.id!)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 26),
            // ── WHAT FLOW LEARNED ──
            switch (patterns) {
              AsyncData(:final value) => _Learned(patterns: value, week: days),
              AsyncError(:final error) => Text(errorText(error)),
              _ => const LoadingBlocks(height: 120),
            },
            const SizedBox(height: 26),
            const _YearBand(),
            const SizedBox(height: 26),
            LayoutBuilder(
              builder: (context, box) {
                const history = _HistoryBand();
                const dna = _DnaBand();
                if (box.maxWidth < 900) return const Column(children: [history, SizedBox(height: 20), dna]);
                return const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: history),
                    SizedBox(width: 20),
                    Expanded(flex: 2, child: dna),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Text('Patterns use only your own sessions. Each one says how many sessions it is based on.', style: FlowType.note(p, size: 13)),
          ],
        );
      },
    );
  }
}

class _WeekStepper extends StatelessWidget {
  const _WeekStepper({required this.label, required this.onBack, required this.onForward});
  final String label;
  final VoidCallback onBack;
  final VoidCallback? onForward;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Pressable(
        onPressed: onBack,
        semanticLabel: 'Previous week',
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: const Text('‹'),
      ),
      SizedBox(
        width: 96,
        child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5)),
      ),
      Pressable(
        onPressed: onForward,
        semanticLabel: 'Next week',
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: const Text('›'),
      ),
    ],
  );
}

// ── week cards ──────────────────────────────────────────────────────────────

/// Seven day cards standing on one floor line. Each card is the day's spine
/// (blocks rising, 3D) on its own little floor; hover stands it up (SNAP),
/// neighbours part slightly; the chosen card is outlined in ink.
class _WeekCards extends StatefulWidget {
  const _WeekCards({required this.days, required this.selected, required this.onSelect, required this.height, required this.futureFrom});
  final List<DayTimeline> days;
  final int selected;
  final ValueChanged<int> onSelect;
  final double height;

  /// Index from which days are still to come (drawn as outlines).
  final int futureFrom;

  @override
  State<_WeekCards> createState() => _WeekCardsState();
}

class _WeekCardsState extends State<_WeekCards> with TickerProviderStateMixin {
  late final _hover = SpringValue(vsync: this, initial: -10);
  double? _hoverCard;
  // the selection outline slides between cards (SNAP, carries velocity)
  late final _sel = SpringValue(vsync: this, initial: widget.selected.toDouble());
  late final _rise = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  @override
  void initState() {
    super.initState();
    Motion.enterOnMount(context, _rise, () => mounted);
  }

  @override
  void didUpdateWidget(_WeekCards old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      _sel.animateTo(widget.selected.toDouble(), spring: Motion.snap, reduced: Motion.reduced(context));
    }
    if (!identical(old.days, widget.days) && !Motion.reduced(context)) {
      _rise
        ..value = 0
        ..forward();
    }
  }

  @override
  void dispose() {
    _hover.dispose();
    _sel.dispose();
    _rise.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    final maxMin = widget.days.fold<int>(1, (a, d) => math.max(a, d.totals.focusMinutes));
    return LayoutBuilder(
      builder: (context, box) {
        final slot = box.maxWidth / 7;
        return MouseRegion(
          // retarget only when the card under the pointer changes (not on
          // every mouse event), and arrive without overshoot
          onHover: (e) {
            final i = (e.localPosition.dx / slot).floorToDouble().clamp(0.0, 6.0);
            if (i == _hoverCard) return;
            // entering from outside: appear on the card, don't sweep in from afar
            if (_hoverCard == null) _hover.value = i;
            _hoverCard = i;
            _hover.animateTo(i, spring: Motion.hover, reduced: Motion.reduced(context));
          },
          onExit: (_) {
            _hoverCard = null;
            _hover.value = -10;
          },
          child: GestureDetector(
            onTapUp: (e) => widget.onSelect((e.localPosition.dx / slot).floor().clamp(0, 6)),
            child: AnimatedBuilder(
              animation: Listenable.merge([_hover.animation, _rise, _sel.animation]),
              builder: (context, _) => CustomPaint(
                size: Size(box.maxWidth, widget.height),
                painter: _WeekPainter(
                  p: p,
                  days: widget.days,
                  selected: widget.selected,
                  selPos: _sel.value,
                  hover: _hover.value,
                  rise: _rise.isCompleted ? 1e9 : _rise.value * 2.2,
                  maxMin: maxMin,
                  futureFrom: widget.futureFrom,
                  scaler: MediaQuery.textScalerOf(context),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WeekPainter extends CustomPainter {
  _WeekPainter({
    required this.p,
    required this.days,
    required this.selected,
    required this.selPos,
    required this.hover,
    required this.rise,
    required this.maxMin,
    required this.futureFrom,
    required this.scaler,
  });
  final FlowPalette p;
  final List<DayTimeline> days;
  final int selected;
  final double selPos;
  final double hover;
  final double rise;
  final int maxMin;
  final int futureFrom;
  final TextScaler scaler;

  void _t(Canvas c, String s, Offset at, {double size = 11, Color? color, bool bold = false, String? family}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontFamily: family ?? FlowFonts.ui,
          fontSize: size,
          color: color ?? p.text2,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    tp.paint(c, Offset(at.dx - tp.width / 2, at.dy - tp.height / 2));
  }

  @override
  void paint(Canvas c, Size s) {
    final floor = s.height - 46;
    final slot = s.width / 7;
    // fit every card to the hours this week actually used (≥ 6 h), so blocks
    // keep a readable width instead of thin towers on a 14 h axis
    var lo = 24, hi = 0;
    for (final d in days) {
      for (final sess in d.sessions) {
        lo = math.min(lo, sess.start.hour);
        hi = math.max(hi, sess.end.hour + (sess.end.minute > 0 ? 1 : 0));
      }
    }
    if (lo >= hi) {
      lo = 9;
      hi = 18;
    }
    if (hi - lo < 6) hi = lo + 6;
    final spanStart = lo, spanHours = hi - lo;
    c.drawLine(
      Offset(0, floor),
      Offset(s.width, floor),
      Paint()
        ..color = p.text3
        ..strokeWidth = 1,
    );

    for (var i = 0; i < 7; i++) {
      final d = days[i];
      final future = i >= futureFrom;
      // hover stands the card up; neighbours part a little
      final dist = (i - hover).abs();
      final lift = math.max(0.0, 1 - dist) * 10;
      // continuous through zero: `sign` here made the hovered card itself
      // jump ±5 px whenever the hover point crossed its centre
      final part = hover < -5 ? 0.0 : (i - hover).clamp(-1.0, 1.0) * math.max(0.0, 1.6 - dist) * 3;
      final cx = slot * i + slot / 2 + part;
      final w = slot - 14;
      final cardH = floor - 10 - lift;
      final card = RRect.fromRectAndRadius(Rect.fromLTWH(cx - w / 2, floor - cardH, w, cardH), const Radius.circular(12));
      // a thin 3D edge under the card (it stands on the floor)
      c.drawRRect(card.shift(const Offset(0, 2)), Paint()..color = Faces.ground(p.raised));
      c.drawRRect(card, Paint()..color = future ? p.bg : p.raised);
      c.drawRRect(
        card,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = p.hairline,
      );

      // the day's spine inside the card: 7:00–21:00
      final inner = card.outerRect.deflate(12);
      final base = inner.bottom - 8;
      final dayStart = DateTime(d.date.year, d.date.month, d.date.day, spanStart);
      double x(DateTime t) => inner.left + inner.width * (t.difference(dayStart).inMinutes / (spanHours * 60)).clamp(0.0, 1.0);
      c.drawLine(
        Offset(inner.left, base),
        Offset(inner.right, base),
        Paint()
          ..color = p.text3.withValues(alpha: 0.6)
          ..strokeWidth = 0.8,
      );
      final maxH = inner.height * 0.5;
      for (final (k, sess) in d.sessions.indexed) {
        final x0 = x(sess.start) + 0.8, x1 = x(sess.end) - 0.8;
        if (x1 - x0 < 1) continue;
        final tt = rise >= 1e8 ? 1e9 : rise - i * 0.06 - k * 0.04;
        final h =
            maxH *
            switch (sess.demand) {
              Demand.light => 0.5,
              Demand.moderate => 0.75,
              Demand.heavy => 1.0,
            };
        final col = p.pastByDemand[sess.demand.index];
        if (future || sess.state == TimelineSessionState.scheduled || sess.state == TimelineSessionState.forecast) {
          c.drawRect(
            Rect.fromLTRB(x0, base - h, x1, base),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.9
              ..color = p.future,
          );
          continue;
        }
        paintLiquidBlock(c, x0, x1, base, h, 4, col, fill: LiquidFill.at(tt, maxRipple: 2), t: tt, outline: p.text3, shade: false);
      }
      // breaks as small dots under the spine
      for (final b in d.breaks.where((b) => b.mark == BreakMark.taken)) {
        c.drawCircle(Offset(x(b.at), base + 5), 1.6, Paint()..color = p.selected);
      }
      // the day's total as a big numeral at the top of the card
      final tot = d.totals.focusMinutes;
      if (tot > 0) {
        // numbers in the instrument face, units small beside them
        final tp = TextPainter(
          text: TextSpan(children: durationSpans(p, tot, 21, color: p.text1)),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        tp.paint(c, Offset(cx - tp.width / 2, card.top + 26 - tp.height / 2));
      } else {
        _t(c, future ? 'ahead' : 'no focus', Offset(cx, card.top + 26), size: 11, color: p.text3);
      }
      _t(c, _days[i], Offset(cx, floor + 14), bold: i == selected, color: i == selected ? p.text1 : p.text2);
      _t(c, '${d.date.day}', Offset(cx, floor + 30), size: 10, color: p.text3);
    }
    // one selection outline that slides to the chosen card
    final sx = slot * selPos + slot / 2;
    final sw = slot - 14;
    final near = selPos.round().clamp(0, 6);
    final nd = (near - hover).abs();
    final sh = floor - 10 - math.max(0.0, 1 - nd) * 10;
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(sx - sw / 2, floor - sh, sw, sh), const Radius.circular(12)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = p.selected,
    );
  }

  @override
  bool shouldRepaint(_WeekPainter o) =>
      o.selPos != selPos || o.hover != hover || o.rise != rise || o.selected != selected || o.days != days || o.p != p;
}

// ── what Flow learned ──────────────────────────────────────────────────────

class _Learned extends StatelessWidget {
  const _Learned({required this.patterns, required this.week});
  final Patterns patterns;
  final List<DayTimeline>? week;

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    // minutes focused per hour of day, from this week's real sessions
    final perHour = List<int>.filled(24, 0);
    for (final d in week ?? const <DayTimeline>[]) {
      for (final s in d.sessions.where((s) => s.state == TimelineSessionState.done || s.state == TimelineSessionState.active)) {
        var t = s.start;
        while (t.isBefore(s.end)) {
          final next = DateTime(t.year, t.month, t.day, t.hour + 1);
          final end = next.isBefore(s.end) ? next : s.end;
          perHour[t.hour] += end.difference(t).inMinutes;
          t = end;
        }
      }
    }
    final learning = patterns.isLearning;
    final total = patterns.sessionsCompleted + patterns.sessionsNeeded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (learning)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              'Flow is still learning your rhythm: ${patterns.sessionsCompleted} of $total sessions. Outlines fill in as it learns.',
              style: FlowType.note(p, size: 14.5, color: p.text1),
            ),
          ),
        ColorField(
          tone: FieldTone.past,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SectionLabel('Peak hours · this week'),
                  const Spacer(),
                  if (patterns.peakHours case final h?)
                    Text(
                      'learned peak: ${h.value.map((x) => '$x:00').join(', ')} · n=${h.sampleSize} · ${h.confidence.wire}',
                      style: FlowType.chart(p, size: 10.5),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: _PeakBars(perHour: perHour, peaks: patterns.peakHours?.value ?? const []),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, box) {
            final cycle = ColorField(
              tone: FieldTone.planned,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('Your focus cycle'),
                  const SizedBox(height: 4),
                  Text(
                    patterns.personalPeriodMin == null
                        ? 'Starts from a 90 min assumption until Flow has enough sessions.'
                        : 'Your focus tends to peak around ${patterns.personalPeriodMin!.value} min in '
                              '(${patterns.personalPeriodMin!.sampleSize} sessions, ${patterns.personalPeriodMin!.confidence.wire} confidence).',
                    style: FlowType.note(p, size: 13.5),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 170,
                    child: _CycleCurve(periodMin: patterns.personalPeriodMin?.value, learned: !learning),
                  ),
                ],
              ),
            );
            final effect = ColorField(
              tone: FieldTone.rest,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('Breaks that helped'),
                  const SizedBox(height: 14),
                  if (patterns.breakEffectiveness case final b?) ...[
                    Appear(child: TabularNumeral('${(b.value * 100).round()}%', style: FlowType.numeral(p, 56))),
                    const SizedBox(height: 8),
                    Text('of breaks raised your next focus rating.', style: FlowType.note(p, size: 14, color: p.text1)),
                    const SizedBox(height: 14),
                    _SplitBar(value: b.value),
                    const SizedBox(height: 8),
                    Text('from ${b.sampleSize} breaks · ${b.confidence.wire} confidence', style: FlowType.chart(p, size: 10.5)),
                  ] else ...[
                    TabularNumeral('—', style: FlowType.numeral(p, 56, color: p.text3)),
                    const SizedBox(height: 8),
                    Text('Rate a few breaks (two taps after each) and this fills in.', style: FlowType.note(p, size: 14)),
                  ],
                ],
              ),
            );
            if (box.maxWidth < 900) return Column(children: [cycle, const SizedBox(height: 18), effect]);
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 3, child: cycle),
                  const SizedBox(width: 18),
                  Expanded(flex: 2, child: effect),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// 3D bars rising from a 24 h line: minutes focused in each hour this week.
/// Learned peak hours carry a small ▲ under their bar.
class _PeakBars extends StatefulWidget {
  const _PeakBars({required this.perHour, required this.peaks});
  final List<int> perHour;
  final List<int> peaks;
  @override
  State<_PeakBars> createState() => _PeakBarsState();
}

class _PeakBarsState extends State<_PeakBars> with TickerProviderStateMixin {
  late final _rise = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  // where the lift is, in hours: it glides to the hovered bar instead of popping
  late final _lift = SpringValue(vsync: this, initial: -10);
  int? _hoverHour;
  @override
  void initState() {
    super.initState();
    Motion.enterOnMount(context, _rise, () => mounted);
  }

  @override
  void dispose() {
    _rise.dispose();
    _lift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => MouseRegion(
      onHover: (e) {
        final h = (e.localPosition.dx / (box.maxWidth / 24)).floor().clamp(0, 23);
        if (h == _hoverHour) return;
        if (_hoverHour == null) _lift.value = h.toDouble();
        _lift.animateTo(h.toDouble(), spring: Motion.hover, reduced: Motion.reduced(context));
        setState(() => _hoverHour = h);
      },
      onExit: (_) {
        _lift.value = -10;
        setState(() => _hoverHour = null);
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_rise, _lift.animation]),
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _PeakPainter(
            FlowPalette.of(context),
            widget.perHour,
            widget.peaks,
            _rise.isCompleted ? 1e9 : _rise.value * 2.2,
            MediaQuery.textScalerOf(context),
            hoverHour: _hoverHour,
            liftAt: _lift.value,
          ),
        ),
      ),
    ),
  );
}

class _PeakPainter extends CustomPainter {
  _PeakPainter(this.p, this.perHour, this.peaks, this.rise, this.scaler, {this.hoverHour, this.liftAt = -10});
  final int? hoverHour;
  final double liftAt;
  final FlowPalette p;
  final List<int> perHour;
  final List<int> peaks;
  final double rise;
  final TextScaler scaler;

  @override
  void paint(Canvas c, Size s) {
    final base = s.height - 22;
    final maxV = math.max(1, perHour.reduce(math.max));
    final slot = s.width / 24;
    final w = slot * 0.62;
    final dep = math.min(8.0, w * 0.28);
    c.drawLine(
      Offset(0, base),
      Offset(s.width, base),
      Paint()
        ..color = p.text3
        ..strokeWidth = 1,
    );
    for (var h = 0; h < 24; h++) {
      final x0 = h * slot + (slot - w) / 2, x1 = x0 + w;
      final tt = rise >= 1e8 ? 1e9 : rise - (h - 12).abs() * 0.035;
      final lifted = 4.0 * math.max(0.0, 1 - (h - liftAt).abs());
      final bh = (base - 24) * perHour[h] / maxV + lifted;
      final col = perHour[h] / maxV > 0.66 ? p.pastHeavy : (perHour[h] / maxV > 0.33 ? p.pastModerate : p.pastLight);
      final rh = bh * (tt >= 1e8 ? 1.0 : Motion.settleAt(tt));
      if (rh > 0.5) paintSolidBlock(c, x0, x1, base, rh, dep, col);
      if (h == hoverHour && perHour[h] > 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: '$h:00 · ${perHour[h]} min',
            style: FlowType.chart(p, size: 10.5, color: p.text1),
          ),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
        )..layout();
        final lx = (x0 + w / 2 - tp.width / 2).clamp(0.0, s.width - tp.width);
        tp.paint(c, Offset(lx, base - bh - dep - tp.height - 6));
      }
      if (h % 3 == 0) {
        final tp = TextPainter(
          text: TextSpan(text: '$h', style: FlowType.chart(p, size: 10)),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
        )..layout();
        tp.paint(c, Offset(x0 + w / 2 - tp.width / 2, base + 6));
      }
      if (peaks.contains(h)) {
        final cx = x0 + w / 2;
        c.drawPath(
          Path()
            ..moveTo(cx - 4, base + 20)
            ..lineTo(cx + 4, base + 20)
            ..lineTo(cx, base + 14)
            ..close(),
          Paint()..color = p.selected,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PeakPainter o) =>
      o.hoverHour != hoverHour || o.liftAt != liftAt || o.rise != rise || o.perHour != perHour || o.p != p;
}

/// Relative focus × minutes into a session. The curve is Flow's model of you
/// (labelled as such): it rises, peaks near your learned period, then falls.
/// The 90-min assumption is a dashed line; your peak is marked.
class _CycleCurve extends StatefulWidget {
  const _CycleCurve({required this.periodMin, required this.learned});
  final int? periodMin;
  final bool learned;
  @override
  State<_CycleCurve> createState() => _CycleCurveState();
}

/// The curve line-draws in from the left (then its area fades in); hovering
/// reads the model at that minute.
class _CycleCurveState extends State<_CycleCurve> with SingleTickerProviderStateMixin {
  late final _draw = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  double? _hoverX;

  @override
  void initState() {
    super.initState();
    Motion.enterOnMount(context, _draw, () => mounted);
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    onHover: (e) {
      // whole pixels: sub-pixel mouse noise is not worth a repaint
      final x = e.localPosition.dx.roundToDouble();
      if (x != _hoverX) setState(() => _hoverX = x);
    },
    onExit: (_) => setState(() => _hoverX = null),
    child: AnimatedBuilder(
      animation: _draw,
      builder: (context, _) => CustomPaint(
        size: Size.infinite,
        painter: _CyclePainter(
          FlowPalette.of(context),
          widget.periodMin ?? 90,
          widget.learned,
          MediaQuery.textScalerOf(context),
          progress: Curves.easeInOutCubic.transform(_draw.value),
          hoverX: _hoverX,
        ),
      ),
    ),
  );
}

class _CyclePainter extends CustomPainter {
  _CyclePainter(this.p, this.period, this.learned, this.scaler, {this.progress = 1, this.hoverX});
  final double progress;
  final double? hoverX;
  final FlowPalette p;
  final int period;
  final bool learned;
  final TextScaler scaler;

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
    final base = s.height - 20;
    const maxMin = 150.0;
    double x(double m) => s.width * m / maxMin;
    double f(double m) {
      // rise to the peak, then a gentler fall: a skewed bell
      final z = (m - period) / (m < period ? period * 0.55 : period * 0.75);
      return math.exp(-z * z);
    }

    c.drawLine(
      Offset(0, base),
      Offset(s.width, base),
      Paint()
        ..color = p.text3
        ..strokeWidth = 1,
    );
    for (var m = 0; m <= maxMin; m += 30) {
      _t(c, '$m′', Offset(x(m.toDouble()), base + 10), p.text3);
    }
    // 90-min assumption
    for (var y = 6.0; y < base; y += 6) {
      c.drawLine(
        Offset(x(90), y),
        Offset(x(90), y + 3),
        Paint()
          ..color = p.text3
          ..strokeWidth = 0.8,
      );
    }
    _t(c, '90′ assumed', Offset(x(90) + 34, base - 10), p.text3);

    final path = Path()..moveTo(0, base);
    for (var m = 0.0; m <= maxMin; m += 2) {
      path.lineTo(x(m), base - (base - 16) * f(m));
    }
    final area = Path.from(path)
      ..lineTo(s.width, base)
      ..close();
    if (learned) c.drawPath(area, Paint()..color = p.future.withValues(alpha: 0.16 * ((progress - 0.6) / 0.4).clamp(0.0, 1.0)));
    // the line draws itself in from the left
    final drawn = Path();
    for (final m in path.computeMetrics()) {
      drawn.addPath(m.extractPath(0, m.length * progress), Offset.zero);
    }
    c.drawPath(
      drawn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = learned ? 1.6 : 1
        ..color = learned ? p.future : p.text3,
    );
    if (progress > 0.55) {
      final peak = Offset(x(period.toDouble()), 16);
      c.drawCircle(peak, 3.4, Paint()..color = learned ? p.selected : p.text3);
      if (learned) _t(c, 'your peak · $period′', peak.translate(0, -9), p.text1);
    }
    // hover: read the model at that minute
    final hx = hoverX;
    if (hx != null && progress >= 1) {
      final m = (hx / s.width * maxMin).clamp(0.0, maxMin);
      final y = base - (base - 16) * f(m);
      c.drawLine(
        Offset(hx, 10),
        Offset(hx, base),
        Paint()
          ..color = p.text2
          ..strokeWidth = 0.7,
      );
      c.drawCircle(Offset(hx, y), 3, Paint()..color = p.selected);
      final label = '${m.round()}′ in · focus ${(f(m) * 100).round()}% of your peak';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: FlowType.chart(p, size: 10.5, color: p.text1),
        ),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      final lx = (hx + 8 + tp.width > s.width) ? hx - 8 - tp.width : hx + 8;
      final r = RRect.fromLTRBR(lx - 6, y - 24, lx + tp.width + 6, y - 6, const Radius.circular(5));
      c.drawRRect(r, Paint()..color = p.raised);
      c.drawRRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = p.hairline,
      );
      tp.paint(c, Offset(lx, y - 15 - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_CyclePainter o) =>
      o.progress != progress || o.hoverX != hoverX || o.period != period || o.learned != learned || o.p != p;
}

class _SplitBar extends StatelessWidget {
  const _SplitBar({required this.value});
  final double value;
  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    return Recessed(
      radius: 4,
      child: SizedBox(
        height: 10,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
          duration: Motion.reduced(context) ? Duration.zero : const Duration(milliseconds: 1100),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: v,
            child: DecoratedBox(
              decoration: BoxDecoration(color: p.amber.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(4)),
            ),
          ),
        ),
      ),
    );
  }
}

// ── year heatmap ────────────────────────────────────────────────────────────

class _YearBand extends ConsumerWidget {
  const _YearBand();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(yearMinutesProvider);
    return ColorField(
      tone: FieldTone.past,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('The last 12 months'),
          const SizedBox(height: 10),
          switch (year) {
            // cells sized from the width so the year spans the whole band
            AsyncData(:final value) => LayoutBuilder(
              builder: (context, box) => SizedBox(
                height: 18 + 7 * ((box.maxWidth - 26) / 53),
                child: _Heatmap(minutes: value),
              ),
            ),
            AsyncError(:final error) => Text(errorText(error)),
            _ => const LoadingBlocks(height: 100),
          },
        ],
      ),
    );
  }
}

class _Heatmap extends StatefulWidget {
  const _Heatmap({required this.minutes});
  final Map<DateTime, int> minutes;
  @override
  State<_Heatmap> createState() => _HeatmapState();
}

/// Cells grow in outward from today (SETTLE, staggered by weeks back);
/// hovering a cell reads its day.
class _HeatmapState extends State<_Heatmap> with SingleTickerProviderStateMixin {
  late final _in = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  Offset? _hover;

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
  Widget build(BuildContext context) => MouseRegion(
    onHover: (e) => setState(() => _hover = e.localPosition),
    onExit: (_) => setState(() => _hover = null),
    child: AnimatedBuilder(
      animation: _in,
      builder: (context, _) => CustomPaint(
        size: Size.infinite,
        painter: _HeatPainter(
          FlowPalette.of(context),
          widget.minutes,
          MediaQuery.textScalerOf(context),
          t: _in.isCompleted ? 1e9 : _in.value * 1.5,
          hover: _hover,
        ),
      ),
    ),
  );
}

class _HeatPainter extends CustomPainter {
  _HeatPainter(this.p, this.minutes, this.scaler, {this.t = 1e9, this.hover});
  final double t;
  final Offset? hover;
  final FlowPalette p;
  final Map<DateTime, int> minutes;
  final TextScaler scaler;

  @override
  void paint(Canvas c, Size s) {
    final today = _d(DateTime.now());
    final start = _monday(today.subtract(const Duration(days: 52 * 7)));
    const weeks = 53;
    const left = 26.0;
    final cell = math.min((s.width - left) / weeks, (s.height - 18) / 7);
    final gap = cell * 0.18;
    final maxV = math.max(1, minutes.values.fold<int>(0, math.max));
    var lastMonth = -1;
    (Rect, DateTime, int)? hovered;
    for (var w = 0; w < weeks; w++) {
      for (var d = 0; d < 7; d++) {
        final day = start.add(Duration(days: w * 7 + d));
        if (day.isAfter(today)) continue;
        final m = minutes[day] ?? 0;
        final full = Rect.fromLTWH(left + w * cell, 16 + d * cell, cell - gap, cell - gap);
        // grow outward from today: the newest weeks first
        final k = t >= 1e8 ? 1.0 : Motion.settleAt(t - (weeks - 1 - w) * 0.018);
        if (k <= 0.01) continue;
        final rect = Rect.fromCenter(center: full.center, width: full.width * k, height: full.height * k);
        final v = m / maxV;
        final col = m == 0 ? p.recess : (v < 0.33 ? p.pastLight : (v < 0.66 ? p.pastModerate : p.pastHeavy));
        c.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.18 * k)), Paint()..color = col);
        final hv = hover;
        if (hv != null && full.inflate(gap / 2).contains(hv)) hovered = (full, day, m);
        if (day == today) {
          c.drawRRect(
            RRect.fromRectAndRadius(rect.inflate(1.2), Radius.circular(cell * 0.22)),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..color = p.accent,
          );
        }
        if (d == 0 && day.month != lastMonth) {
          lastMonth = day.month;
          final tp = TextPainter(
            text: TextSpan(text: _months[day.month - 1], style: FlowType.chart(p, size: 9.5)),
            textDirection: TextDirection.ltr,
            textScaler: scaler,
          )..layout();
          tp.paint(c, Offset(left + w * cell, 0));
        }
      }
    }
    for (final (i, l) in const [(0, 'M'), (2, 'W'), (4, 'F')]) {
      final tp = TextPainter(
        text: TextSpan(text: l, style: FlowType.chart(p, size: 9)),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      tp.paint(c, Offset(4, 16 + i * cell + (cell - gap - tp.height) / 2));
    }
    if (hovered case (final r, final day, final m)) {
      c.drawRRect(
        RRect.fromRectAndRadius(r.inflate(1.5), Radius.circular(cell * 0.25)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = p.selected,
      );
      final label = '${_days[day.weekday - 1]} ${day.day} ${_months[day.month - 1]} · ${m == 0 ? 'no focus' : flowDuration(m)}';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: FlowType.chart(p, size: 10.5, color: p.onSelected),
        ),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      final lx = (r.center.dx - tp.width / 2 - 6).clamp(0.0, s.width - tp.width - 12);
      final ly = r.top > 34 ? r.top - tp.height - 12 : r.bottom + 6;
      c.drawRRect(RRect.fromLTRBR(lx, ly, lx + tp.width + 12, ly + tp.height + 6, const Radius.circular(5)), Paint()..color = p.selected);
      tp.paint(c, Offset(lx + 6, ly + 3));
    }
  }

  @override
  bool shouldRepaint(_HeatPainter o) => o.t != t || o.hover != hover || o.minutes != minutes || o.p != p;
}

// ── history + Focus DNA ─────────────────────────────────────────────────────

class _HistoryBand extends ConsumerWidget {
  const _HistoryBand();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = FlowPalette.of(context);
    final page = ref.watch(sessionsPageProvider(1));
    return ColorField(
      tone: FieldTone.past,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Recent sessions'),
          const SizedBox(height: 8),
          AsyncSection(
            lines: 5,
            value: page,
            onRetry: () => ref.invalidate(sessionsPageProvider(1)),
            builder: (pg) => Column(
              children: [
                if (pg.items.isEmpty) Text('No sessions yet. Your first one will appear here.', style: FlowType.note(p, size: 14)),
                for (final (i, s) in pg.items.take(8).indexed)
                  Appear(
                    index: i,
                    child: _HistoryRow(s: s, index: i),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.s, this.index = 0});
  final SessionSummary s;
  final int index;
  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    final col = p.pastByDemand[s.demand.index];
    final frac = s.plannedMinutes == 0 ? 1.0 : (s.focusMinutes / s.plannedMinutes).clamp(0.0, 1.2);
    final start = TimeOfDay.fromDateTime(s.startedAt);
    return InkWell(
      onTap: s.replayReady ? () => context.go(Routes.sessionEndFor(s.sessionId), extra: s) : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
        child: Row(
          children: [
            SizedBox(
              width: 116,
              child: Text(
                '${_days[s.startedAt.weekday - 1]} ${s.startedAt.day} · ${start.hour}:${start.minute.toString().padLeft(2, '0')}',
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                style: TextStyle(color: p.text2, fontSize: 12, fontFeatures: FlowType.tabular),
              ),
            ),
            // a shallow 3D mini spine: planned length as the line, focus as the block
            SizedBox(
              width: 120,
              height: 22,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 2.4),
                duration: Motion.reduced(context) ? Duration.zero : const Duration(milliseconds: 2400),
                builder: (context, t, _) => CustomPaint(
                  painter: _MiniSpine(col: col, frac: frac, line: p.text3, t: t >= 2.4 ? 1e9 : t - index * 0.07),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                s.taskText?.isNotEmpty == true ? s.taskText! : 'Focus session',
                style: TextStyle(color: p.text1, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${s.focusMinutes} min · ${s.breaksTaken}/${s.breaksSuggested} breaks',
              style: FlowType.chart(p, size: 11, color: p.text2),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniSpine extends CustomPainter {
  _MiniSpine({required this.col, required this.frac, required this.line, this.t = 1e9});
  final double t;
  final Color col;
  final double frac;
  final Color line;
  @override
  void paint(Canvas c, Size s) {
    final base = s.height - 3;
    c.drawLine(
      Offset(0, base),
      Offset(s.width, base),
      Paint()
        ..color = line
        ..strokeWidth = 0.8,
    );
    final w = (s.width - 6) * math.min(1.0, frac);
    final r = t >= 1e8 ? 1.0 : Motion.settleAt(t);
    if (r > 0.01) paintSolidBlock(c, 0, w, base, 12 * r, 3, col, shade: false);
  }

  @override
  bool shouldRepaint(_MiniSpine o) => o.t != t || o.frac != frac || o.col != col;
}

class _DnaBand extends ConsumerWidget {
  const _DnaBand();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = FlowPalette.of(context);
    final png = ref.watch(focusDnaProvider);
    return ColorField(
      tone: FieldTone.planned,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Focus DNA'),
          const SizedBox(height: 4),
          Text('Your rhythm as one image to keep or share.', style: FlowType.note(p, size: 13.5)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 220,
                height: 220,
                child: switch (png) {
                  AsyncData(:final value) => ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Appear(child: Image.memory(value, fit: BoxFit.cover, gaplessPlayback: true)),
                  ),
                  AsyncError() => Text('Focus DNA is not available yet.', style: FlowType.note(p, size: 13)),
                  _ => const LoadingBlocks(height: 100, count: 4),
                },
              ),
              const SizedBox(width: 18),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Appear(
                      index: 2,
                      child: FeatureNote(
                        number: 1,
                        compact: true,
                        title: 'Rings are days',
                        body: 'Innermost is the oldest; the outer ring is the latest.',
                      ),
                    ),
                    SizedBox(height: 12),
                    Appear(
                      index: 4,
                      child: FeatureNote(
                        number: 2,
                        compact: true,
                        title: 'Arcs are sessions',
                        body: 'On a 24-hour clock. Darker stone = more demanding.',
                      ),
                    ),
                    SizedBox(height: 12),
                    Appear(
                      index: 6,
                      child: FeatureNote(number: 3, compact: true, title: 'One green arc', body: 'Your most recent session.'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Pressable(
                onPressed: png.value == null
                    ? null
                    : () async {
                        try {
                          final saved = await saveBytes(
                            png.value!,
                            suggestedName: 'flow-focus-dna.png',
                            mimeType: 'image/png',
                            extension: 'png',
                          );
                          if (saved && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Focus DNA saved.')));
                          }
                        } catch (e) {
                          if (context.mounted) showError(context, e);
                        }
                      },
                child: const Text('Save PNG'),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('A new card each week. Nothing on it identifies you.', style: FlowType.chart(p, size: 10.5))),
            ],
          ),
        ],
      ),
    );
  }
}
