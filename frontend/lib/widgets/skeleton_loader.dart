// lib/widgets/skeleton_loader.dart
//
// Shimmer skeleton placeholders.
//
// Usage:
//   SkeletonBox(width: 120, height: 20)          // generic rectangle
//   SkeletonStatCard()                            // mimics FlowDataCard stat block
//   SkeletonRow(children: [...])                  // horizontal group

import 'package:flutter/material.dart';

// ─── Core shimmer ─────────────────────────────────────────────────────────────

class _ShimmerPainter extends CustomPainter {
  final double progress;
  final Color  baseColor;
  final Color  highlightColor;

  _ShimmerPainter({
    required this.progress,
    required this.baseColor,
    required this.highlightColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gradient = LinearGradient(
      begin:  Alignment.centerLeft,
      end:    Alignment.centerRight,
      colors: [baseColor, highlightColor, baseColor],
      stops:  const [0.0, 0.5, 1.0],
      transform: GradientRotation(progress * 3.14 * 2),
    );
    final paint = Paint()
      ..shader = gradient.createShader(
          Rect.fromLTWH(-size.width, 0, size.width * 3, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) =>
      old.progress != progress;
}

class SkeletonBox extends StatefulWidget {
  final double  width;
  final double  height;
  final double  borderRadius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base   = isDark ? const Color(0xFF2A342C) : const Color(0xFFE2E6E2);
    final hi     = isDark ? const Color(0xFF3A4A3E) : const Color(0xFFF0F4F1);

    return AnimatedBuilder(
      animation: _ctrl,
      builder:   (_, __) => ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child:        CustomPaint(
          size:    Size(widget.width, widget.height),
          painter: _ShimmerPainter(
            progress:       _ctrl.value,
            baseColor:      base,
            highlightColor: hi,
          ),
        ),
      ),
    );
  }
}

// ─── Preset composites ────────────────────────────────────────────────────────

/// Mimics a two-column telemetry row (label + big number).
class SkeletonStatCard extends StatelessWidget {
  const SkeletonStatCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:  MainAxisAlignment.center,
        children: [
          SkeletonBox(width: 80,  height: 10, borderRadius: 5),
          const SizedBox(height: 12),
          SkeletonBox(width: 120, height: 40, borderRadius: 8),
          const SizedBox(height: 8),
          SkeletonBox(width: 60,  height: 10, borderRadius: 5),
        ],
      ),
    );
  }
}

/// Skeleton for a horizontal list of items.
class SkeletonRow extends StatelessWidget {
  final List<Widget> children;
  const SkeletonRow({super.key, required this.children});

  @override
  Widget build(BuildContext context) => Row(
        children: children
            .expand((w) => [w, const SizedBox(width: 16)])
            .toList()
          ..removeLast(),
      );
}

/// Full-screen skeleton for the dashboard — shows while data loads.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SkeletonBox(width: 160, height: 12, borderRadius: 6),
                const SizedBox(height: 10),
                SkeletonBox(width: 280, height: 28, borderRadius: 8),
              ]),
              SkeletonBox(width: 160, height: 32, borderRadius: 8),
            ],
          ),
          const SizedBox(height: 40),
          // Main content grid
          Expanded(
            child: Row(
              children: [
                // Left — telemetry grid
                Expanded(
                  flex: 5,
                  child: Container(
                    decoration: BoxDecoration(
                      color:        theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border:       Border.all(color: theme.dividerColor),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: Row(children: [
                            Expanded(child: const SkeletonStatCard()),
                            VerticalDivider(color: theme.dividerColor),
                            Expanded(child: const SkeletonStatCard()),
                          ]),
                        ),
                        Divider(color: theme.dividerColor),
                        Expanded(
                          child: Row(children: [
                            Expanded(child: const SkeletonStatCard()),
                            VerticalDivider(color: theme.dividerColor),
                            Expanded(child: const SkeletonStatCard()),
                            VerticalDivider(color: theme.dividerColor),
                            Expanded(child: const SkeletonStatCard()),
                          ]),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // Right — action module
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color:        theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border:       Border.all(color: theme.dividerColor),
                    ),
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 100, height: 10, borderRadius: 5),
                        const Spacer(),
                        SkeletonBox(width: 180, height: 32, borderRadius: 8),
                        const SizedBox(height: 10),
                        SkeletonBox(width: 220, height: 32, borderRadius: 8),
                        const SizedBox(height: 12),
                        SkeletonBox(width: 160, height: 14, borderRadius: 6),
                        const Spacer(),
                        SkeletonBox(
                          width:        double.infinity,
                          height:       52,
                          borderRadius: 12,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Timeline bar
          Container(
            height: 56,
            decoration: BoxDecoration(
              color:        theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border:       Border.all(color: theme.dividerColor),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Row(children: [
              SkeletonBox(width: 80,  height: 10, borderRadius: 5),
              const SizedBox(width: 32),
              Expanded(child: SkeletonBox(width: double.infinity, height: 8, borderRadius: 4)),
              const SizedBox(width: 32),
              SkeletonBox(width: 100, height: 10, borderRadius: 5),
            ]),
          ),
        ],
      ),
    );
  }
}