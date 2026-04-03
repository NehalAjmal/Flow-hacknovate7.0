import 'package:flutter/material.dart';
import '../widgets/flow_data_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(32.0), // Reduced outer margin
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // TOP BAR: Greeting & State
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Good morning, Amaan — peak window open now",
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
                    Text("Deep work ready", style: theme.textTheme.bodyMedium?.copyWith(color: theme.primaryColor, fontWeight: FontWeight.w600)),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 24),

          // ROW 1: Top Stats Grid
          Row(
            children: [
              Expanded(child: _buildStatCard("FOCUS SCORE TODAY", "74", "+6 vs yesterday", true, theme)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard("SESSIONS TODAY", "2", "3h 12m total", false, theme)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard("RHYTHM POSITION", "62 min", "28 min until trough", true, theme)),
            ],
          ),
          const SizedBox(height: 16),

          // ROW 2: Signal & Action
          Expanded(
            flex: 4,
            child: Row(
              children: [
                // Signal Strength
                Expanded(
                  flex: 2,
                  child: FlowDataCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween, // FIX: Distributes space safely without crashing
                      children: [
                        Text("SIGNAL STRENGTH", style: theme.textTheme.labelSmall),
                        Row(
                          children: [
                            Text("Combined", style: theme.textTheme.bodyMedium),
                            const SizedBox(width: 16),
                            Expanded(
                              child: LinearProgressIndicator(
                                value: 0.25,
                                backgroundColor: theme.dividerColor,
                                color: theme.primaryColor,
                                minHeight: 6,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text("0.25/0.68", style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                          ],
                        ),
                        Text("Threshold: 0.68 — no intervention needed.", style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.labelSmall?.color)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Quick Start Call to Action
                Expanded(
                  flex: 1,
                  child: FlowDataCard(
                    backgroundColor: theme.primaryColor.withValues(alpha: 0.05),
                    borderColor: theme.primaryColor.withValues(alpha: 0.3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween, // FIX: Safe dynamic distribution
                      children: [
                        Text("QUICK START", style: theme.textTheme.labelSmall?.copyWith(color: theme.primaryColor)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("90 min deep work", style: theme.textTheme.headlineMedium?.copyWith(color: theme.primaryColor)),
                            const SizedBox(height: 4),
                            Text("Peak window · 2h free", style: theme.textTheme.bodyMedium?.copyWith(color: theme.primaryColor.withValues(alpha: 0.8))),
                          ],
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            onPressed: () {},
                            child: const Text("Start session →", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ROW 3: Timeline & Biometrics
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: FlowDataCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("TODAY'S TIMELINE", style: theme.textTheme.labelSmall),
                        
                        // Smooth Timeline Bar
                        Container(
                          height: 12,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            gradient: LinearGradient(
                              colors: [
                                theme.primaryColor, 
                                theme.primaryColor.withValues(alpha: 0.8),
                                const Color(0xFFEF9F27), // Amber Break
                                theme.primaryColor,
                                theme.dividerColor, // Future unworked time
                              ],
                              stops: const [0.0, 0.4, 0.45, 0.5, 0.8],
                            ),
                          ),
                        ),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildTimelineStat("Deep work", "2h 47m", theme),
                            _buildTimelineStat("Breaks taken", "2 / 2", theme, color: theme.primaryColor),
                            _buildTimelineStat("Drift events", "3", theme),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: FlowDataCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("LIVE BIOMETRICS", style: theme.textTheme.labelSmall),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildBio("71", "BPM", theme),
                            _buildBio("41ms", "HRV", theme),
                            _buildBio("0.31", "EAR", theme),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
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

  Widget _buildTimelineStat(String label, String value, ThemeData theme, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.labelSmall?.color)),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: color ?? theme.textTheme.bodyLarge?.color)),
      ],
    );
  }

  Widget _buildBio(String value, String label, ThemeData theme) {
    return Column(
      children: [
        Text(value, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}