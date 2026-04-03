import 'package:flutter/material.dart';
import '../widgets/flow_data_card.dart';

class SessionEndScreen extends StatelessWidget {
  const SessionEndScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // For standalone viewing, we add an AppBar back button
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: theme.textTheme.bodyLarge?.color),
          onPressed: () {
            // Navigator.pop(context); // Will route back to dashboard in prod
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Session Complete",
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 32),

            // ROW 1: Summary Metrics
            Row(
              children: [
                Expanded(child: _buildMetricCard("FOCUS SCORE", "82", "Top 10% this week", theme, isHighlight: true)),
                const SizedBox(width: 16),
                Expanded(child: _buildMetricCard("DURATION", "73m", "Planned: 90m", theme)),
                const SizedBox(width: 16),
                Expanded(child: _buildMetricCard("INTERVENTIONS", "1", "Successfully recovered", theme, isWarning: true)),
              ],
            ),
            const SizedBox(height: 24),

            // ROW 2: Timeline & AI Insights
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: Replay Timeline
                  Expanded(
                    flex: 3,
                    child: FlowDataCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("SESSION REPLAY", style: theme.textTheme.labelSmall),
                          const SizedBox(height: 24),
                          Expanded(
                            child: ListView(
                              children: [
                                _buildTimelineEvent("09:15 AM", "Session Started", "Declared heavy cognitive demand.", Icons.play_arrow_rounded, theme.primaryColor, theme),
                                _buildTimelineEvent("09:30 AM", "Deep Work Reached", "BPM dropped, EAR stabilized.", Icons.waves_rounded, theme.primaryColor, theme),
                                _buildTimelineEvent("10:12 AM", "Intent Drift Detected", "Rapid context switching across 4 apps.", Icons.warning_amber_rounded, theme.colorScheme.error, theme),
                                _buildTimelineEvent("10:14 AM", "Intervention Resolved", "User requested unblock assistance. Resumed.", Icons.check_circle_outline_rounded, theme.primaryColor, theme),
                                _buildTimelineEvent("10:28 AM", "Session Ended", "Manual termination.", Icons.stop_rounded, theme.textTheme.labelSmall?.color ?? Colors.grey, theme, isLast: true),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 24),

                  // Right: What FLOW Learned
                  Expanded(
                    flex: 2,
                    child: FlowDataCard(
                      // Subtle wash to indicate AI insight
                      backgroundColor: theme.primaryColor.withValues(alpha:0.04),
                      borderColor: theme.primaryColor.withValues(alpha:0.2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.auto_awesome, color: theme.primaryColor, size: 20),
                              const SizedBox(width: 10),
                              Text("WHAT FLOW LEARNED", style: theme.textTheme.labelSmall?.copyWith(color: theme.primaryColor)),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            "Your estimated fatigue threshold for 'Debugging' tasks was 90 minutes, but physiological drift began at minute 57.",
                            style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Adjustment made:",
                            style: theme.textTheme.labelSmall,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: theme.dividerColor),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.arrow_downward_rounded, color: theme.primaryColor, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text("Future heavy tasks will recommend breaks at the 55-minute mark.", style: theme.textTheme.bodyMedium),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.textTheme.displayLarge?.color, 
                                foregroundColor: theme.scaffoldBackgroundColor, 
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              onPressed: () {
                                // Navigator.pop(context);
                              },
                              child: const Text("Return to Dashboard", style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, String subtext, ThemeData theme, {bool isHighlight = false, bool isWarning = false}) {
    final Color valueColor = isWarning ? theme.colorScheme.error : (isHighlight ? theme.primaryColor : (theme.textTheme.displayLarge?.color ?? Colors.white));
    
    return FlowDataCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.labelSmall),
          const SizedBox(height: 12),
          Text(value, style: theme.textTheme.displayLarge?.copyWith(color: valueColor)),
          const SizedBox(height: 4),
          Text(subtext, style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.labelSmall?.color)),
        ],
      ),
    );
  }

  Widget _buildTimelineEvent(String time, String title, String description, IconData icon, Color color, ThemeData theme, {bool isLast = false}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time Column
          SizedBox(
            width: 70,
            child: Text(time, style: theme.textTheme.labelSmall?.copyWith(fontSize: 11, color: theme.textTheme.labelSmall?.color?.withValues(alpha:0.7))),
          ),
          
          // Graphic Column (Node + Line)
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha:0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha:0.5), width: 1),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: theme.dividerColor,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          
          // Content Column
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(description, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}