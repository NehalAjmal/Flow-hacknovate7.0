// lib/widgets/focus_ring.dart
//
// Upgrades vs original:
//   • Animated arc entry — on first build the arc sweeps in from 0 → progress
//     over 1.2 s with an easeOutCubic curve (no code changes needed at call site)
//   • Still fully compatible with the existing FocusRing(progress, timeString, isDrifting) API
//   • Drift mode keeps the jagged vibration behaviour

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../core/theme.dart';

class FocusRing extends StatefulWidget {
  final double progress;      // 0.0 – 1.0
  final String timeString;    // e.g. "28:14"
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

class _FocusRingState extends State<FocusRing>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _entryController;
  late Animation<double>   _entryAnimation;

  @override
  void initState() {
    super.initState();

    // ── Ambient pulse (unchanged from original) ──────────────────────────────
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // ── One-shot entry sweep ──────────────────────────────────────────────────
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _entryAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    );
    _entryController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme       = Theme.of(context);
    final activeColor = widget.isDrifting
        ? theme.colorScheme.error
        : theme.primaryColor;

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _entryAnimation]),
      builder: (context, child) {
        final drawnProgress = widget.progress * _entryAnimation.value;

        return Stack(
          alignment: Alignment.center,
          children: [
            // LAYER 1 — Glow bloom
            Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: activeColor
                        .withValues(alpha: 0.12 * _pulseController.value),
                    blurRadius: 60,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),

            // LAYER 2 — Orbit ring
            CustomPaint(
              size: const Size(320, 320),
              painter: _FocusOrbitPainter(
                progress:    drawnProgress,
                color:       activeColor,
                pulse:       _pulseController.value,
                isDrifting:  widget.isDrifting,
              ),
            ),

            // LAYER 3 — Data core
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.timeString,
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontSize:     64,
                    letterSpacing: -2,
                    fontWeight:   FontWeight.w800,
                  ),
                ),
                Text(
                  widget.isDrifting ? "STABILIZE" : "FLOW ACTIVE",
                  style: theme.textTheme.labelLarge?.copyWith(
                    color:         activeColor.withValues(alpha: 0.8),
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

// ─────────────────────────────────────────────────────────────────────────────
// Orbit painter (unchanged logic, kept here for co-location)
// ─────────────────────────────────────────────────────────────────────────────

class _FocusOrbitPainter extends CustomPainter {
  final double progress;
  final Color  color;
  final double pulse;
  final bool   isDrifting;

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

    // Background track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color      = color.withValues(alpha: 0.1)
        ..style      = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final progressPaint = Paint()
      ..color       = color
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round
      ..strokeWidth = 4 + (pulse * 2);

    if (isDrifting) {
      final path = Path();
      for (double i = 0; i < (progress * 2 * math.pi); i += 0.1) {
        final r = radius + (math.sin(i * 20) * 4 * pulse);
        final x = center.dx + r * math.cos(i - math.pi / 2);
        final y = center.dy + r * math.sin(i - math.pi / 2);
        if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
      }
      canvas.drawPath(path, progressPaint);
    } else {
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