// lib/widgets/count_up_text.dart
//
// Drop-in widget that counts a number from 0 → [target] over [duration].
// Usage:
//   CountUpText(target: 82, suffix: '%', style: theme.textTheme.displayLarge)
//   CountUpText(target: 74, duration: Duration(milliseconds: 900), style: ...)

import 'package:flutter/material.dart';

class CountUpText extends StatefulWidget {
  final int      target;
  final String   suffix;
  final String   prefix;
  final Duration duration;
  final TextStyle? style;
  final Curve    curve;

  const CountUpText({
    super.key,
    required this.target,
    this.suffix   = '',
    this.prefix   = '',
    this.duration = const Duration(milliseconds: 1100),
    this.style,
    this.curve    = Curves.easeOutCubic,
  });

  @override
  State<CountUpText> createState() => _CountUpTextState();
}

class _CountUpTextState extends State<CountUpText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int>      _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync:    this,
      duration: widget.duration,
    );
    _animation = IntTween(begin: 0, end: widget.target).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(CountUpText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) {
      _animation = IntTween(begin: _animation.value, end: widget.target)
          .animate(CurvedAnimation(parent: _controller, curve: widget.curve));
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) => Text(
        '${widget.prefix}${_animation.value}${widget.suffix}',
        style: widget.style,
      ),
    );
  }
}