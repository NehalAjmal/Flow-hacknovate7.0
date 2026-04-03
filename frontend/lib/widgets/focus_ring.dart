import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../core/theme.dart';

class FocusRing extends StatefulWidget {
  final double progress;
  final String timeString;
  final bool isDrifting;

  const FocusRing({
    super.key,
    required this.progress,
    required this.timeString,
    required this.isDrifting,
  });

  @override
  State<FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<FocusRing> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = widget.isDrifting ? theme.colorScheme.error : theme.primaryColor;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // LAYER 1: The Glow Bloom (Organic Depth)
            Container(
              width: 280, height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.1 * _pulseController.value),
                    blurRadius: 60,
                    spreadRadius: 20,
                  )
                ],
              ),
            ),
            
            // LAYER 2: The Technical Orbit
            CustomPaint(
              size: const Size(320, 320),
              painter: _FocusOrbitPainter(
                progress: widget.progress,
                color: activeColor,
                pulse: _pulseController.value,
                isDrifting: widget.isDrifting,
              ),
            ),

            // LAYER 3: Data Core
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.timeString,
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontSize: 64,
                    letterSpacing: -2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  widget.isDrifting ? "STABILIZE" : "FLOW ACTIVE",
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: activeColor.withValues(alpha: 0.8),
                    letterSpacing: 4,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _FocusOrbitPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double pulse;
  final bool isDrifting;

  _FocusOrbitPainter({
    required this.progress,
    required this.color,
    required this.pulse,
    required this.isDrifting,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 20;

    // Background track (Earthy dark stroke)
    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, trackPaint);

    // Liquid Progress Arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4 + (pulse * 2); // Breathing thickness

    if (isDrifting) {
      // Jagged Vibration for Drift
      final path = Path();
      for (double i = 0; i < (progress * 2 * math.pi); i += 0.1) {
        double r = radius + (math.sin(i * 20) * 4 * pulse);
        double x = center.dx + r * math.cos(i - math.pi / 2);
        double y = center.dy + r * math.sin(i - math.pi / 2);
        if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
      }
      canvas.drawPath(path, progressPaint);
    } else {
      // Smooth Orbit
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}