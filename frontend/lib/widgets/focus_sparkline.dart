// lib/widgets/focus_sparkline.dart
//
// A compact sparkline that shows the focus-score trend for the current session.
// The most recent point is highlighted with a glowing dot.
//
// Usage (inside ActiveSessionScreen):
//   FocusSparkline(
//     scores: [72, 65, 78, 80, 76, 82, 85],   // values 0–100
//     color:  theme.primaryColor,
//   )

import 'package:flutter/material.dart';
import 'dart:math' as math;

class FocusSparkline extends StatefulWidget {
  final List<double> scores;   // 0–100 each
  final Color        color;
  final double       height;

  const FocusSparkline({
    super.key,
    required this.scores,
    required this.color,
    this.height = 56,
  });

  @override
  State<FocusSparkline> createState() => _FocusSparklineState();
}

// ✅ FIX: Changed SingleTickerProviderStateMixin to TickerProviderStateMixin
class _FocusSparklineState extends State<FocusSparkline>
    with TickerProviderStateMixin {
  late AnimationController _entryCtrl;
  late Animation<double>   _entryAnim;
  late AnimationController _dotCtrl;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 900),
    );
    _entryAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic);
    _entryCtrl.forward();

    _dotCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _dotCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_entryAnim, _dotCtrl]),
      builder: (_, __) => CustomPaint(
        size:    Size(double.infinity, widget.height),
        painter: _SparklinePainter(
          scores:    widget.scores,
          color:     widget.color,
          progress:  _entryAnim.value,
          dotPulse:  _dotCtrl.value,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> scores;
  final Color        color;
  final double       progress; // 0–1, entry animation
  final double       dotPulse; // 0–1, pulsing dot

  _SparklinePainter({
    required this.scores,
    required this.color,
    required this.progress,
    required this.dotPulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.isEmpty) return;

    final n        = scores.length;
    final minScore = scores.reduce(math.min);
    final maxScore = scores.reduce(math.max);
    final range    = (maxScore - minScore).clamp(1.0, 100.0);

    // Map a score to a canvas y coordinate
    double yFor(double s) =>
        size.height - ((s - minScore) / range) * (size.height * 0.85) - size.height * 0.075;

    // Build all points
    final pts = List<Offset>.generate(n, (i) {
      final x = (i / (n - 1)) * size.width;
      final y = yFor(scores[i]);
      return Offset(x, y);
    });

    // How many points to draw (entry animation)
    final visibleCount = ((n - 1) * progress).toInt() + 1;
    if (visibleCount < 2) return;
    final visPts = pts.sublist(0, visibleCount);

    // ── Fill path ────────────────────────────────────────────────────────────
    final fillPath = Path()..moveTo(visPts.first.dx, size.height);
    fillPath.lineTo(visPts.first.dx, visPts.first.dy);
    for (int i = 1; i < visPts.length; i++) {
      final cp1 = Offset(
          (visPts[i - 1].dx + visPts[i].dx) / 2, visPts[i - 1].dy);
      final cp2 = Offset(
          (visPts[i - 1].dx + visPts[i].dx) / 2, visPts[i].dy);
      fillPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, visPts[i].dx, visPts[i].dy);
    }
    fillPath.lineTo(visPts.last.dx, size.height);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin:  Alignment.topCenter,
          end:    Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill,
    );

    // ── Line path ─────────────────────────────────────────────────────────────
    final linePath = Path()..moveTo(visPts.first.dx, visPts.first.dy);
    for (int i = 1; i < visPts.length; i++) {
      final cp1 = Offset(
          (visPts[i - 1].dx + visPts[i].dx) / 2, visPts[i - 1].dy);
      final cp2 = Offset(
          (visPts[i - 1].dx + visPts[i].dx) / 2, visPts[i].dy);
      linePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, visPts[i].dx, visPts[i].dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color       = color
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap   = StrokeCap.round
        ..strokeJoin  = StrokeJoin.round,
    );

    // ── Pulsing dot at last visible point ────────────────────────────────────
    final last = visPts.last;
    // Outer glow
    canvas.drawCircle(
      last,
      6 + dotPulse * 4,
      Paint()..color = color.withValues(alpha: 0.2 * (1 - dotPulse)),
    );
    // Solid dot
    canvas.drawCircle(last, 4, Paint()..color = color);
    canvas.drawCircle(last, 2, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.progress != progress || old.dotPulse != dotPulse;
}