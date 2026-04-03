import 'dart:ui';
import 'package:flutter/material.dart';
import '../widgets/flow_data_card.dart';
import 'active_session_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(48.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("MOHAMMAD AMAAN", style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text("CONSOLE ACTIVE", style: theme.textTheme.displayMedium),
                ],
              ),
              _buildStatusBadge(theme),
            ],
          ),
          const SizedBox(height: 40),
          Expanded(
            child: Row(
              children: [
                Expanded(flex: 5, child: _buildTelemetryGrid(theme)),
                const SizedBox(width: 24),
                Expanded(flex: 3, child: _buildActionModule(context, theme)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildTimelineBar(theme),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: theme.primaryColor, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Text("PEAK WINDOW OPEN", style: theme.textTheme.labelSmall?.copyWith(color: theme.primaryColor)),
        ],
      ),
    );
  }

  Widget _buildTelemetryGrid(ThemeData theme) {
    return FlowDataCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildStatBlock("FOCUS SCORE", "74", theme)),
                const VerticalDivider(),
                Expanded(child: _buildStatBlock("RHYTHM POS", "62m", theme)),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildStatBlock("BPM", "71", theme, isSmall: true)),
                const VerticalDivider(),
                Expanded(child: _buildStatBlock("HRV", "41ms", theme, isSmall: true)),
                const VerticalDivider(),
                Expanded(child: _buildStatBlock("EAR", "0.31", theme, isSmall: true)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBlock(String label, String value, ThemeData theme, {bool isSmall = false}) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: 8),
          Text(value, style: (isSmall ? theme.textTheme.displayMedium : theme.textTheme.displayLarge)?.copyWith(
            fontFeatures: [const FontFeature.tabularFigures()],
          )),
        ],
      ),
    );
  }

  Widget _buildActionModule(BuildContext context, ThemeData theme) {
    return FlowDataCard(
      backgroundColor: theme.primaryColor.withValues(alpha: 0.05),
      borderColor: theme.primaryColor.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("REQUIRED ACTION", style: theme.textTheme.labelSmall?.copyWith(color: theme.primaryColor)),
          const Spacer(),
          Text("INITIALIZE", style: theme.textTheme.displayMedium),
          Text("DEEP WORK", style: theme.textTheme.displayMedium?.copyWith(color: theme.primaryColor)),
          const SizedBox(height: 8),
          Text("90 minute optimized block.", style: theme.textTheme.bodyMedium),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActiveSessionScreen())),
              child: const Text("START PROTOCOL"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineBar(ThemeData theme) {
    return FlowDataCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          Text("TIMELINE", style: theme.textTheme.labelSmall),
          const SizedBox(width: 32),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2)),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 0.45,
                child: Container(decoration: BoxDecoration(color: theme.primaryColor, borderRadius: BorderRadius.circular(2))),
              ),
            ),
          ),
          const SizedBox(width: 32),
          Text("2H 47M LOGGED", style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}