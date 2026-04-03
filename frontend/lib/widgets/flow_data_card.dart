import 'package:flutter/material.dart';

class FlowDataCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;

  const FlowDataCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18.0), 
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = backgroundColor ?? theme.cardColor;

    // CHANGED TO AnimatedContainer for smooth theme/state transitions
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseColor,
            baseColor.withOpacity(0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(20.0), 
        border: Border.all(
          color: borderColor ?? theme.dividerColor, 
          width: 1.0,
        ),
      ),
      child: child,
    );
  }
}