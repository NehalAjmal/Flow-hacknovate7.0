import 'dart:math';
import 'package:flutter/material.dart';

class FocusRing extends StatelessWidget {
  final double progress; // 0.0 to 1.0 (e.g., 0.75 means 75% time remaining)
  final String timeString; // e.g., "28:14"
  final String label; // e.g., "remaining"
  final bool isDrifting; // Flips the UI to critical red if true

  const FocusRing({
    super.key,
    required this.progress,
    required this.timeString,
    this.label = 'remaining',
    this.isDrifting = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Auto-adapt colors based on Light/Dark mode and Drift state
    final ringColor = isDrifting ? theme.colorScheme.error : theme.primaryColor;
    final trackColor = theme.dividerColor; 
    final textColor = theme.textTheme.displayLarge?.color ?? Colors.white;
    final subTextColor = theme.textTheme.labelSmall?.color ?? Colors.grey;

    return AspectRatio(
      aspectRatio: 1.0, // Ensures it is always a perfect circle
      child: CustomPaint(
        painter: _FocusRingPainter(
          progress: progress,
          ringColor: ringColor,
          trackColor: trackColor,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                timeString,
                style: TextStyle(
                  fontSize: 64, // Massive typography
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  letterSpacing: -1.5,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: subTextColor,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FocusRingPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final Color trackColor;

  _FocusRingPainter({
    required this.progress,
    required this.ringColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 12; // 12 is padding for the stroke

    // 1. Draw the background track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16.0;
    
    canvas.drawCircle(center, radius, trackPaint);

    // 2. Draw the active progress arc
    final progressPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16.0
      ..strokeCap = StrokeCap.round; // Deeply rounded caps for Soft Brutalism

    // Start at top (-pi/2), draw clockwise
    const startAngle = -pi / 2;
    final sweepAngle = 2 * pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _FocusRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.ringColor != ringColor ||
           oldDelegate.trackColor != trackColor;
  }
}