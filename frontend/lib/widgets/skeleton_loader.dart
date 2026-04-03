import 'package:flutter/material.dart';

class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonBox({
    Key? key,
    required this.width,
    required this.height,
    this.borderRadius,
  }) : super(key: key);

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white : Colors.black;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: baseColor.withOpacity(_animation.value * 0.1),
            borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
          ),
        );
      },
    );
  }
}

// A pre-built skeleton for a standard data card
class SkeletonStatCard extends StatelessWidget {
  const SkeletonStatCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 80, height: 14, borderRadius: BorderRadius.circular(4)),
            const SizedBox(height: 16),
            SkeletonBox(width: 120, height: 48, borderRadius: BorderRadius.circular(8)),
            const SizedBox(height: 16),
            SkeletonBox(width: double.infinity, height: 8, borderRadius: BorderRadius.circular(4)),
            const SizedBox(height: 8),
            SkeletonBox(width: double.infinity, height: 8, borderRadius: BorderRadius.circular(4)),
          ],
        ),
      ),
    );
  }
}