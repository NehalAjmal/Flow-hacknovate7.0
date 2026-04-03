import 'package:flutter/material.dart';
import '../widgets/flow_data_card.dart';
import '../core/theme.dart';

class TeamScreen extends StatelessWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final troughColor = FlowTheme.stateColor(context, SessionState.trough);
    final driftColor  = FlowTheme.stateColor(context, SessionState.drift);

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // TOP BAR: Title & Active Count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Team Cognitive Aggregate",
                style: theme.textTheme.headlineMedium,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: theme.primaryColor, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text("12 Active Members", style: theme.textTheme.bodyMedium?.copyWith(color: theme.primaryColor, fontWeight: FontWeight.w600)),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 24),

          // ROW 1: Top Aggregate Stats
          Row(
            children: [
              Expanded(child: _buildStatCard("TEAM AVG FOCUS", "78", "+4 vs yesterday", true, theme)),
              const SizedBox(width: 16),
              Expanded(
                child: FlowDataCard(
                  backgroundColor: theme.primaryColor.withValues(alpha: 0.05),
                  borderColor: theme.primaryColor.withValues(alpha: 0.3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.event_available_rounded, size: 16, color: theme.primaryColor),
                          const SizedBox(width: 8),
                          Text("BEST MEETING WINDOW", style: theme.textTheme.labelSmall?.copyWith(color: theme.primaryColor)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text("2:00 PM", style: theme.textTheme.displayLarge?.copyWith(color: theme.primaryColor)),
                      const SizedBox(height: 4),
                      Text("High alignment · Low interruption risk", style: theme.textTheme.bodyMedium?.copyWith(color: theme.primaryColor.withValues(alpha: 0.8))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard("BURNOUT RISK", "Low", "No flags in 48h", true, theme)),
            ],
          ),
          const SizedBox(height: 16),

          // ROW 2: Live Distribution
          Expanded(
            flex: 3,
            child: FlowDataCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("CURRENT TEAM DISTRIBUTION", style: theme.textTheme.labelSmall),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildDistributionPillar("Deep Work", 8, 12, theme.primaryColor, theme),
                        const SizedBox(width: 16),
                        _buildDistributionPillar("Light Task", 2, 12, theme.primaryColor.withValues(alpha: 0.05), theme),
                        const SizedBox(width: 16),
                        _buildDistributionPillar("Trough/Break", 1, 12, troughColor, theme),
                        const SizedBox(width: 16),
                        _buildDistributionPillar("Drift", 1, 12, driftColor, theme),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ROW 3: Anonymized Live Strips
          Expanded(
            flex: 4,
            child: FlowDataCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("ANONYMIZED LIVE STATES", style: theme.textTheme.labelSmall),
                      Text("Last updated: Just now", style: theme.textTheme.labelSmall?.copyWith(color: theme.dividerColor)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildAnonymousStrip("Member 1", 0.8, theme.primaryColor, "Deep Work (42m)", theme),
                        _buildAnonymousStrip("Member 2", 0.9, theme.primaryColor, "Deep Work (12m)", theme),
                        _buildAnonymousStrip("Member 3", 0.3, troughColor, "Approaching Trough", theme),
                        _buildAnonymousStrip("Member 4", 0.1, driftColor, "Intervention Active", theme),
                        _buildAnonymousStrip("Member 5", 0.5, theme.primaryColor.withValues(alpha: 0.5), "Light Task", theme),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String subtext, bool isPositive, ThemeData theme) {
    return FlowDataCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: theme.textTheme.labelSmall),
          const SizedBox(height: 8),
          Text(value, style: theme.textTheme.displayLarge),
          const SizedBox(height: 4),
          Text(subtext, style: theme.textTheme.bodyMedium?.copyWith(color: isPositive ? theme.primaryColor : theme.textTheme.labelSmall?.color)),
        ],
      ),
    );
  }

  Widget _buildDistributionPillar(String label, int count, int total, Color color, ThemeData theme) {
    final heightFactor = count / total;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // Background Track
                  Container(
                    width: 40,
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  // Active Fill
                  FractionallySizedBox(
                    heightFactor: heightFactor > 0 ? heightFactor : 0.05,
                    child: Container(
                      width: 40,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(count.toString(), style: theme.textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(label, style: theme.textTheme.labelSmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildAnonymousStrip(String label, double strength, Color color, String stateStr, ThemeData theme) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.labelSmall?.color)),
        ),
        Expanded(
          child: Container(
            height: 10,
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(5),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: strength,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 140,
          child: Text(
            stateStr,
            style: theme.textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w500),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}