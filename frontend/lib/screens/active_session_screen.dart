import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../widgets/flow_data_card.dart';
import '../widgets/focus_ring.dart';

class ActiveSessionScreen extends StatefulWidget {
  const ActiveSessionScreen({super.key});

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> {
  bool isDrifting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final targetBg = isDrifting 
        ? FlowTheme.stateColor(context, SessionState.drift).withValues(alpha: 0.05) 
        : theme.scaffoldBackgroundColor;

    return AnimatedContainer(
      duration: const Duration(seconds: 1),
      color: targetBg,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Padding(
          padding: const EdgeInsets.all(64.0),
          child: Row(
            children: [
              Expanded(flex: 5, child: _buildFocusCore(theme)),
              const SizedBox(width: 64),
              Expanded(flex: 4, child: _buildTelemetryConsole(theme)),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => setState(() => isDrifting = !isDrifting),
          backgroundColor: theme.colorScheme.error,
          child: const Icon(Icons.bug_report, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildFocusCore(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FocusRing(progress: 0.68, timeString: "28:14", isDrifting: isDrifting),
        const SizedBox(height: 48),
        Text("ACTIVE PROTOCOL", style: theme.textTheme.labelSmall),
        const SizedBox(height: 8),
        Text("Debugging auth module", style: theme.textTheme.headlineLarge),
      ],
    );
  }

  Widget _buildTelemetryConsole(ThemeData theme) {
    return FlowDataCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text("LIVE TELEMETRY", style: theme.textTheme.labelSmall),
          ),
          const Divider(),
          _buildTelemetryRow("HEART RATE", "74", "BPM", theme),
          const Divider(),
          _buildTelemetryRow("EYE ASPECT", "0.28", "EAR", theme),
          const Divider(),
          _buildTelemetryRow("SIGNAL", "0.25", "COGNITIVE", theme),
        ],
      ),
    );
  }

  Widget _buildTelemetryRow(String label, String value, String unit, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: theme.textTheme.headlineLarge?.copyWith(fontFeatures: [const FontFeature.tabularFigures()])),
              const SizedBox(width: 8),
              Text(unit, style: theme.textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}