import 'package:flutter/material.dart';
import '../widgets/flow_data_card.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // MOCK STATE
    final int burnoutRiskCount = 2; // Change this to 0 to see the card turn normal

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // TOP BAR: Title & Admin Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Organizational Health Overview",
                style: theme.textTheme.headlineMedium,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.textTheme.labelSmall?.color?.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield_rounded, size: 14, color: theme.textTheme.labelSmall?.color),
                    const SizedBox(width: 8),
                    Text("ADMINISTRATOR", style: theme.textTheme.labelSmall),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 24),

          // ROW 1: Top Aggregate Stats
          Row(
            children: [
              Expanded(child: _buildStatCard("GLOBAL FOCUS AVG", "76", "Healthy baseline", theme)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard("ACTIVE SESSIONS", "42", "across 3 departments", theme)),
              const SizedBox(width: 16),
              // The Reactive Burnout Risk Card
              Expanded(
                child: FlowDataCard(
                  backgroundColor: burnoutRiskCount > 0 ? theme.colorScheme.error.withValues(alpha:0.08) : null,
                  borderColor: burnoutRiskCount > 0 ? theme.colorScheme.error.withValues(alpha:0.5) : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("BURNOUT RISK FLAGS", style: theme.textTheme.labelSmall?.copyWith(color: burnoutRiskCount > 0 ? theme.colorScheme.error : null)),
                          if (burnoutRiskCount > 0)
                            Icon(Icons.warning_rounded, color: theme.colorScheme.error, size: 18),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        burnoutRiskCount.toString(), 
                        style: theme.textTheme.displayLarge?.copyWith(color: burnoutRiskCount > 0 ? theme.colorScheme.error : null),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        burnoutRiskCount > 0 ? "Requires immediate attention" : "No risks detected", 
                        style: theme.textTheme.bodyMedium?.copyWith(color: burnoutRiskCount > 0 ? theme.colorScheme.error.withValues(alpha: 0.8) : theme.textTheme.labelSmall?.color),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ROW 2: The Anonymized Table
          Expanded(
            child: FlowDataCard(
              padding: EdgeInsets.zero, // We remove padding here to let the table touch the edges
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Table Header
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("LIVE ANONYMIZED TELEMETRY", style: theme.textTheme.labelSmall),
                        Text("Export CSV", style: theme.textTheme.labelSmall?.copyWith(color: theme.primaryColor, decoration: TextDecoration.underline)),
                      ],
                    ),
                  ),
                  
                  // Column Titles
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: theme.dividerColor),
                        bottom: BorderSide(color: theme.dividerColor),
                      ),
                      color: theme.dividerColor.withValues(alpha:0.2),
                    ),
                    child: Row(
                      children: [
                        Expanded(flex: 2, child: Text("NODE ID", style: theme.textTheme.labelSmall)),
                        Expanded(flex: 3, child: Text("CURRENT STATE", style: theme.textTheme.labelSmall)),
                        Expanded(flex: 2, child: Text("TIME IN STATE", style: theme.textTheme.labelSmall)),
                        Expanded(flex: 2, child: Text("DAILY FOCUS", style: theme.textTheme.labelSmall)),
                        Expanded(flex: 2, child: Text("STATUS", style: theme.textTheme.labelSmall)),
                      ],
                    ),
                  ),

                  // Scrollable Table Body (Prevents Overflow!)
                  Expanded(
                    child: ListView.builder(
                      itemCount: 15, // Mock number of employees
                      itemBuilder: (context, index) {
                        // Mock data generation
                        final isEven = index % 2 == 0;
                        final isWarning = index == 2 || index == 7; // Inject some warnings
                        
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                          color: isEven ? Colors.transparent : theme.dividerColor.withValues(alpha: 0.1),
                          child: Row(
                            children: [
                              Expanded(flex: 2, child: Text("ND-${800 + index}", style: theme.textTheme.bodyMedium?.copyWith(fontFeatures: [const FontFeature.tabularFigures()]))),
                              Expanded(
                                flex: 3, 
                                child: Text(
                                  isWarning ? "High Drift (Context Switching)" : (isEven ? "Deep Work" : "Trough / Break"), 
                                  style: theme.textTheme.bodyMedium?.copyWith(color: isWarning ? theme.colorScheme.error : (isEven ? theme.primaryColor : theme.textTheme.bodyMedium?.color)),
                                ),
                              ),
                              Expanded(flex: 2, child: Text("${12 + (index * 7)} min", style: theme.textTheme.bodyMedium)),
                              Expanded(flex: 2, child: Text("${88 - index}", style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600))),
                              Expanded(
                                flex: 2, 
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8, height: 8,
                                      decoration: BoxDecoration(
                                        color: isWarning ? theme.colorScheme.error : theme.primaryColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(isWarning ? "Flagged" : "Stable", style: theme.textTheme.bodyMedium),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
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

  Widget _buildStatCard(String title, String value, String subtext, ThemeData theme) {
    return FlowDataCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: theme.textTheme.labelSmall),
          const SizedBox(height: 8),
          Text(value, style: theme.textTheme.displayLarge),
          const SizedBox(height: 4),
          Text(subtext, style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.labelSmall?.color)),
        ],
      ),
    );
  }
}