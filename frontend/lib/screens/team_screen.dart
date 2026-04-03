import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../widgets/flow_data_card.dart';
import '../core/theme.dart';

class TeamScreen extends StatelessWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        // LAYER 1: The Network Grid
        Positioned.fill(
          child: CustomPaint(
            painter: _NetworkGridPainter(color: theme.dividerColor.withValues(alpha: 0.3)),
          ),
        ),
        
        // LAYER 2: Spatial Nodes
        Padding(
          padding: const EdgeInsets.all(48.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(theme),
              Expanded(
                child: Stack(
                  children: [
                    // Mapping "Nodes" to random spatial positions
                    const _TeamNode(name: "Amaan", pos: Offset(0.2, 0.3), status: "Deep Work", isActive: true),
                    const _TeamNode(name: "Sarah", pos: Offset(0.7, 0.2), status: "Focus", isActive: true),
                    const _TeamNode(name: "Laraib", pos: Offset(0.5, 0.6), status: "Trough", isActive: false),
                    const _TeamNode(name: "Aleena", pos: Offset(0.8, 0.7), status: "Deep Work", isActive: true),
                  ],
                ),
              ),
              _buildTeamStats(theme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("DEPARTMENT TELEMETRY", style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Text("Engineering Node Map", style: theme.textTheme.displayMedium),
      ],
    );
  }

  Widget _buildTeamStats(ThemeData theme) {
    return Row(
      children: [
        _buildMiniInsight("74%", "AVG ALIGNMENT", theme),
        const SizedBox(width: 48),
        _buildMiniInsight("12", "ACTIVE NODES", theme),
        const SizedBox(width: 48),
        _buildMiniInsight("2.4h", "COLLECTIVE FLOW", theme),
      ],
    );
  }

  Widget _buildMiniInsight(String val, String label, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(val, style: theme.textTheme.headlineMedium?.copyWith(color: theme.primaryColor)),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}

class _TeamNode extends StatelessWidget {
  final String name;
  final Offset pos;
  final String status;
  final bool isActive;

  const _TeamNode({required this.name, required this.pos, required this.status, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isActive ? theme.primaryColor : FlowTheme.textSecondaryDark;

    return Align(
      alignment: Alignment(pos.dx * 2 - 1, pos.dy * 2 - 1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.1),
              border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
              boxShadow: isActive ? [
                BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 5)
              ] : [],
            ),
            child: Center(
              child: Text(name[0], style: theme.textTheme.headlineMedium?.copyWith(color: color)),
            ),
          ),
          const SizedBox(height: 12),
          Text(name, style: theme.textTheme.bodyLarge),
          Text(status, style: theme.textTheme.labelSmall?.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _NetworkGridPainter extends CustomPainter {
  final Color color;
  _NetworkGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1;
    for (double i = 0; i < size.width; i += 60) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 60) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}