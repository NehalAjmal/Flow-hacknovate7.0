import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/motion.dart';
import '../theme/palette.dart';

/// Loading state (spec §13): faint blocks on a line that rise and fall very
/// gently, out of phase, like slow breathing. They first rise from the line
/// (SETTLE), then breathe. Reduced motion: still blocks.
class LoadingBlocks extends StatefulWidget {
  const LoadingBlocks({super.key, this.height = 120, this.count = 6, this.label = 'Loading'});
  final double height;
  final int count;
  final String label;

  @override
  State<LoadingBlocks> createState() => _LoadingBlocksState();
}

class _LoadingBlocksState extends State<LoadingBlocks> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((e) => setState(() => _t = e.inMicroseconds / 1e6));
  double _t = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = Motion.reduced(context);
    if (reduced && _ticker.isActive) _ticker.stop();
    if (!reduced && !_ticker.isActive) _ticker.start();
    if (reduced) _t = 10;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    liveRegion: true,
    child: SizedBox(
      height: widget.height,
      width: double.infinity,
      child: CustomPaint(painter: _LoadingPainter(FlowPalette.of(context), _t, widget.count, Motion.reduced(context))),
    ),
  );
}

class _LoadingPainter extends CustomPainter {
  _LoadingPainter(this.p, this.t, this.count, this.still);
  final FlowPalette p;
  final double t;
  final int count;
  final bool still;

  static const _shape = [0.55, 0.9, 0.7, 1.0, 0.6, 0.8, 0.5, 0.75];

  @override
  void paint(Canvas c, Size s) {
    final base = s.height - 6;
    final maxH = s.height * 0.7;
    final span = math.min(s.width, count * 64.0);
    final x0 = (s.width - span) / 2;
    final slot = span / count;
    final w = slot * 0.62;
    final depth = (w * 0.14).clamp(3.0, 8.0);
    c.drawLine(
      Offset(x0 - 12, base),
      Offset(x0 + span + 12, base),
      Paint()
        ..color = p.hairline
        ..strokeWidth = 1,
    );
    for (var i = 0; i < count; i++) {
      final rise = still ? 1.0 : Motion.settleAt(t - i * 0.035 * 2);
      // very light: ±9% around the block's own height, 2.4 s period, out of phase
      final breathe = still ? 0.0 : 0.09 * math.sin(2 * math.pi * (t / 2.4) + i * 0.9);
      final h = maxH * _shape[i % _shape.length] * (1 + breathe) * rise;
      if (h < 0.5) continue;
      final x = x0 + i * slot + (slot - w) / 2;
      final top = base - h;
      final face = Color.lerp(p.recess, p.hairline, 0.35)!;
      c.drawPath(
        Path()
          ..moveTo(x, top)
          ..lineTo(x + depth, top - depth)
          ..lineTo(x + w + depth, top - depth)
          ..lineTo(x + w, top)
          ..close(),
        Paint()..color = Faces.top(face),
      );
      c.drawPath(
        Path()
          ..moveTo(x + w, top)
          ..lineTo(x + w + depth, top - depth)
          ..lineTo(x + w + depth, base - depth)
          ..lineTo(x + w, base)
          ..close(),
        Paint()..color = Faces.side(face),
      );
      c.drawRect(Rect.fromLTRB(x, top, x + w, base), Paint()..color = face);
    }
  }

  @override
  bool shouldRepaint(_LoadingPainter o) => o.t != t || o.p != p;
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
