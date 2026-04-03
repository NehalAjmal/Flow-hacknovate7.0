import 'package:flutter/material.dart';
import 'dart:math' as math;

class FocusSparkline extends StatefulWidget {
  final List<double> scores; // List of data points
  final Color color;
  final double height;

  const FocusSparkline({
    Key? key,
    required this.scores,
    required this.color,
    this.height = 56,
  }) : super(key: key);

  @override
  State<FocusSparkline> createState() => _FocusSparklineState();
}

class _FocusSparklineState extends State<FocusSparkline> with TickerProviderStateMixin {
  late AnimationController _entryCtrl;
  late Animation<double> _entryAnim;
  late AnimationController _dotCtrl;

  @override
  void initState() {
    super.initState();
    
    // Entry sweep animation
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _entryAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic);
    _entryCtrl.forward();

    // Live pulsing dot animation
    _dotCtrl = AnimationController(
      vsync: this,
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
      builder: (context, child) {
        return CustomPaint(
          size: Size(double.infinity, widget.height),
          painter: _SparklinePainter(
            scores: widget.scores,
            color: widget.color,
            progress: _entryAnim.value,
            dotPulse: _dotCtrl.value,
          ),
        );
      },
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> scores;
  final Color color;
  final double progress; 
  final double dotPulse; 

  _SparklinePainter({
    required this.scores,
    required this.color,
    required this.progress,
    required this.dotPulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.isEmpty) return;

    final n = scores.length;
    final minScore = scores.reduce(math.min);
    final maxScore = scores.reduce(math.max);
    final range = (maxScore - minScore).clamp(1.0, 100.0);

    // Dynamic Y mapping based on available height
    double yFor(double s) {
      return size.height - ((s - minScore) / range) * (size.height * 0.85) - size.height * 0.075;
    }

    final pts = List<Offset>.generate(n, (i) {
      final x = (i / (n - 1)) * size.width;
      final y = yFor(scores[i]);
      return Offset(x, y);
    });

    final visibleCount = ((n - 1) * progress).toInt() + 1;
    if (visibleCount < 2) return;
    
    final visPts = pts.sublist(0, visibleCount);

    // 1. Draw Gradient Fill beneath the line
    final fillPath = Path()..moveTo(visPts.first.dx, size.height);
    fillPath.lineTo(visPts.first.dx, visPts.first.dy);

    for (int i = 1; i < visPts.length; i++) {
      final cp1 = Offset((visPts[i - 1].dx + visPts[i].dx) / 2, visPts[i - 1].dy);
      final cp2 = Offset((visPts[i - 1].dx + visPts[i].dx) / 2, visPts[i].dy);
      fillPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, visPts[i].dx, visPts[i].dy);
    }
    fillPath.lineTo(visPts.last.dx, size.height);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.25), color.withOpacity(0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill,
    );

    // 2. Draw the Smooth Curved Line
    final linePath = Path()..moveTo(visPts.first.dx, visPts.first.dy);
    for (int i = 1; i < visPts.length; i++) {
      final cp1 = Offset((visPts[i - 1].dx + visPts[i].dx) / 2, visPts[i - 1].dy);
      final cp2 = Offset((visPts[i - 1].dx + visPts[i].dx) / 2, visPts[i].dy);
      linePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, visPts[i].dx, visPts[i].dy);
    }
    
    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // 3. Draw the pulsing Live Dot at the end of the line
    final last = visPts.last;
    canvas.drawCircle(
      last,
      4 + (dotPulse * 6),
      Paint()..color = color.withOpacity(0.4 * (1 - dotPulse)),
    );
    canvas.drawCircle(last, 4, Paint()..color = color);
    canvas.drawCircle(last, 2, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.progress != progress || old.dotPulse != dotPulse;
}