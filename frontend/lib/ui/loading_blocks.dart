import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../theme/palette.dart';

/// Loading state (spec §13): the o of the wordmark as a little jelly cup.
///
/// It shows nothing for the first [LoadingGrace.delay] — most loads finish
/// sooner, and a loader that flashes for 80 ms reads as jitter — then fades in:
///  - the cup is a dashed stone ring (the "not yet" line);
///  - liquid pours in with an overshoot, sloshing (surface tilt + ripple scale
///    with how fast the level moves, so it calms as it settles);
///  - full, the whole cup jiggles like jelly (squash ↔ stretch, damped), its
///    shadow squashing with it; then it glugs empty and goes again.
/// One controller drives the painter directly (no widget rebuilds per frame),
/// and the ring's dash path is built once per size.
/// Reduced motion: a still, half-full cup. [count] is kept for API stability.
class LoadingBlocks extends StatefulWidget {
  const LoadingBlocks({super.key, this.height = 120, this.count = 6, this.label = 'Loading'});
  final double height;
  final int count;
  final String label;

  @override
  State<LoadingBlocks> createState() => _LoadingBlocksState();
}

/// Shared "don't flash" rule for every loader.
abstract final class LoadingGrace {
  static const delay = Duration(milliseconds: 250);
}

class _LoadingBlocksState extends State<LoadingBlocks> with SingleTickerProviderStateMixin {
  static const _loop = Duration(milliseconds: 1900);
  late final _c = AnimationController(vsync: this, duration: _loop);
  final _ring = _RingCache();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    liveRegion: true,
    child: SizedBox(
      height: widget.height,
      width: double.infinity,
      child: _Graced(
        child: RepaintBoundary(
          child: CustomPaint(painter: _CupPainter(FlowPalette.of(context), _c, _ring, still: Motion.reduced(context))),
        ),
      ),
    ),
  );
}

/// Invisible for [LoadingGrace.delay], then a quick fade in.
class _Graced extends StatefulWidget {
  const _Graced({required this.child});
  final Widget child;
  @override
  State<_Graced> createState() => _GracedState();
}

class _GracedState extends State<_Graced> {
  bool _show = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(LoadingGrace.delay, () {
      if (mounted) setState(() => _show = true);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: _show ? 1 : 0,
    duration: Motion.fade,
    // don't tick an invisible painter
    child: TickerMode(enabled: _show, child: widget.child),
  );
}

class _RingCache {
  double? _r;
  Path? _path;
  Path dashes(double r) {
    if (_r == r && _path != null) return _path!;
    final out = Path();
    final m = (Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: r))).computeMetrics().first;
    final n = (m.length / 7).floor().clamp(12, 64);
    final step = m.length / n;
    for (var i = 0; i < n; i++) {
      out.addPath(m.extractPath(i * step, i * step + step * 0.55), Offset.zero);
    }
    _r = r;
    return _path = out;
  }
}

class _CupPainter extends CustomPainter {
  _CupPainter(this.p, this.anim, this.ring, {required this.still}) : super(repaint: anim);
  final FlowPalette p;
  final Animation<double> anim;
  final _RingCache ring;
  final bool still;

  static const _loopSec = 1.9;
  // phases of the loop (fractions)
  static const _fillEnd = 0.5, _holdEnd = 0.8;

  static double _backOut(double t) => Curves.easeOutBack.transform(t.clamp(0.0, 1.0));
  static double _inCubic(double t) => Curves.easeInCubic.transform(t.clamp(0.0, 1.0));

  /// Liquid level 0..1 at loop fraction [u].
  static double level(double u) {
    // fills to ~70% (overshooting to ~77%): air above the liquid keeps it a cup
    if (u < _fillEnd) return 0.12 + 0.58 * _backOut(u / _fillEnd);
    if (u < _holdEnd) return 0.7;
    return 0.7 - 0.58 * _inCubic((u - _holdEnd) / (1 - _holdEnd));
  }

  @override
  void paint(Canvas c, Size s) {
    final u = still ? 0.6 : anim.value;
    final r = math.min(s.shortestSide * 0.3, 30.0).clamp(10.0, 30.0);
    final ctr = Offset(s.width / 2, s.height / 2 - r * 0.1);

    // level and its speed (finite difference) drive the slosh
    final lv = still ? 0.5 : level(u);
    final speed = still ? 0.0 : (level((u + 0.01) % 1) - lv).abs() / (0.01 * _loopSec);

    // jelly jiggle once full: damped squash ↔ stretch
    var squash = 0.0;
    if (!still && u >= _fillEnd && u < 1) {
      final tau = (u - _fillEnd) * _loopSec;
      squash = 0.11 * math.exp(-5.5 * tau) * math.sin(2 * math.pi * 3.2 * tau);
    }
    final sx = 1 + squash, sy = 1 - squash;

    // shadow squashes with the cup
    c.drawOval(
      Rect.fromCenter(center: Offset(ctr.dx, ctr.dy + r * 1.28), width: r * 1.5 * sx, height: r * 0.22),
      Paint()..color = p.hairline.withValues(alpha: 0.7),
    );

    c.save();
    // jiggle about the cup's base, like jelly on a plate
    c.translate(ctr.dx, ctr.dy + r);
    c.scale(sx, sy);
    c.translate(0, -r);

    // liquid, clipped to the cup
    final inner = r - 3.5;
    c.save();
    c.clipPath(Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: inner)));
    final surface = inner - 2 * inner * lv; // y of the surface
    final amp = math.min(1.2 + speed * inner * 0.05, inner * 0.13);
    final tilt = still ? 0.0 : math.sin(u * 2 * math.pi * 2) * math.min(speed, 2.0) * 0.12;
    final ph = u * 2 * math.pi * 3;
    final wave = Path()..moveTo(-inner, inner + 1);
    const seg = 18;
    for (var i = 0; i <= seg; i++) {
      final x = -inner + 2 * inner * i / seg;
      final y = surface + x * tilt + amp * math.sin(ph + i / seg * 2 * math.pi * 1.3);
      wave.lineTo(x, y);
    }
    wave
      ..lineTo(inner, inner + 1)
      ..close();
    c.drawPath(wave, Paint()..color = p.accent.withValues(alpha: 0.78));
    // a highlight band just under the surface reads as "wet"
    c.drawPath(wave.shift(Offset(0, inner * 0.16)), Paint()..color = p.accent.withValues(alpha: 0.28));
    // two bubbles rise while pouring
    if (!still && u < _holdEnd) {
      for (final (i, x) in const [(0, -0.35), (1, 0.28)].indexed) {
        final bt = ((u * 1.6 + i * 0.37) % 1);
        final by = inner - bt * (inner - surface + inner * 0.1);
        if (by > surface + 3) {
          c.drawCircle(Offset(x.$2 * inner, by), 1.6 + i * 0.6, Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.6));
        }
      }
    }
    c.restore();

    // the dashed "not yet" ring on top
    c.drawPath(
      ring.dashes(r),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = p.pastHeavy,
    );
    // cartoon gloss on the rim
    c.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: r - 6),
      -math.pi * 0.82,
      math.pi * 0.28,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.55),
    );
    c.restore();
  }

  @override
  bool shouldRepaint(_CupPainter o) => o.p != p || o.still != still || o.anim != anim;
}

/// Loading state for lists of text rows (ported from the old frontend's
/// skeleton loader, restyled): recessed bars in each row's shape, pulsing
/// slowly from top to bottom so it reads as "arriving", not "broken".
/// Reduced motion: still bars.
class SkeletonLines extends StatefulWidget {
  const SkeletonLines({super.key, this.rows = 4, this.label = 'Loading'});
  final int rows;
  final String label;

  @override
  State<SkeletonLines> createState() => _SkeletonLinesState();
}

class _SkeletonLinesState extends State<SkeletonLines> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    const widths = [0.72, 0.9, 0.55, 0.82, 0.64, 0.76];
    return Semantics(
      label: widget.label,
      liveRegion: true,
      child: _Graced(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < widget.rows; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                Row(
                  children: [
                    _bar(p, 64, _alpha(i)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: widths[i % widths.length],
                        child: _bar(p, null, _alpha(i)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // a soft wave moving down the rows
  double _alpha(int i) => 0.55 + 0.45 * (0.5 + 0.5 * math.sin(2 * math.pi * (_c.value - i * 0.12)));

  Widget _bar(FlowPalette p, double? w, double a) => Container(
    width: w,
    height: 10,
    decoration: BoxDecoration(color: Color.lerp(p.bg, p.recess, a), borderRadius: BorderRadius.circular(5)),
  );
}
