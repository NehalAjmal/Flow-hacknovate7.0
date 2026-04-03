import 'package:flutter/material.dart';

class FlowDataCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;

  const FlowDataCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24.0), 
    this.backgroundColor,
    this.borderColor,
  });

  @override
  State<FlowDataCard> createState() => _FlowDataCardState();
}

class _FlowDataCardState extends State<FlowDataCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.01 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: widget.backgroundColor ?? theme.cardColor,
            borderRadius: BorderRadius.circular(24.0), // More organic rounding
            border: Border.all(
              color: _isHovered ? theme.primaryColor.withOpacity(0.5) : (widget.borderColor ?? theme.dividerColor), 
              width: 1.5,
            ),
            boxShadow: _isHovered ? [
              BoxShadow(color: theme.primaryColor.withOpacity(0.1), blurRadius: 30, offset: const Offset(0, 10))
            ] : [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}