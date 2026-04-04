import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../widgets/count_up_text.dart';
import '../widgets/focus_ring.dart';
import '../widgets/focus_sparkline.dart';
import 'app_shell.dart';

class SessionEndScreen extends StatelessWidget {
  const SessionEndScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(40, 40, 40, 60),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── HEADER ───
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("SESSION COMPLETE", 
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6) // ✅ Dynamic Color
                          )
                        ),
                        const SizedBox(height: 4),
                        Text("Great work.", style: theme.textTheme.displayMedium),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const AppShell()),
                        );
                      },
                      icon: const Icon(Icons.grid_view_rounded, size: 18),
                      label: const Text("Return to Dashboard"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.scaffoldBackgroundColor,
                        foregroundColor: theme.primaryColor,
                        side: BorderSide(color: theme.dividerColor),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 32),

                // ─── TOP METRICS ROW ───
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: theme.dividerColor)),
                        child: Padding(
                          padding: const EdgeInsets.all(28.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("FINAL FOCUS SCORE", style: theme.textTheme.labelMedium),
                                  const SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      CountUpText(
                                        target: 78,
                                        style: theme.textTheme.displayLarge?.copyWith(color: theme.primaryColor, fontSize: 64),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 12, left: 4),
                                        child: Text("%", style: TextStyle(fontSize: 28, color: theme.primaryColor, fontWeight: FontWeight.w700)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: theme.primaryColor.withValues(alpha: 0.15), // ✅ Dynamic Color
                                      borderRadius: BorderRadius.circular(100)
                                    ),
                                    child: Text("↑ Top 10% this week", style: theme.textTheme.labelLarge?.copyWith(color: theme.primaryColor)),
                                  ),
                                ],
                              ),
                              FocusRing(
                                score: 78,
                                color: theme.primaryColor,
                                trackColor: theme.dividerColor,
                                size: 120,
                                strokeWidth: 12,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          _buildStatCard(context, "TOTAL DURATION", 52, "min"),
                          const SizedBox(height: 14),
                          _buildStatCard(context, "INTERVENTIONS", 1, "accepted"),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ─── PERFORMANCE SPARKLINE & AI INSIGHT ───
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: theme.dividerColor)),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Session Telemetry Replay", style: theme.textTheme.headlineSmall),
                              const SizedBox(height: 24),
                              FocusSparkline(
                                scores: const [75, 82, 85, 38, 79, 55, 72, 78], // Drop at index 3 indicates "Stuck" event
                                color: theme.primaryColor,
                                height: 140,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 2,
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: theme.dividerColor)),
                        color: theme.colorScheme.primaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.auto_awesome_rounded, color: theme.primaryColor, size: 20),
                                  const SizedBox(width: 8),
                                  Text("WHAT FLOW LEARNED", style: theme.textTheme.labelMedium?.copyWith(color: theme.primaryColor)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "Your post-intervention recovery is remarkably strong. You accepted the suggested break at minute 48 and returned highly focused. Ultradian period estimated at 52 minutes.",
                                style: theme.textTheme.bodyLarge?.copyWith(height: 1.6, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // ─── REPLAY TIMELINE ───
                Text("Session Event Log", style: theme.textTheme.headlineSmall),
                const SizedBox(height: 20),
                
                // ✅ FIX: Removed the extra `Icons.play_arrow_rounded` argument from this first line!
                _buildTimelineEvent(context, "10:00 AM", "Session Started", "Deep Work baseline established.", theme.primaryColor),
                
                _buildTimelineEvent(context, "10:22 AM", "Cognitive Loop Detected", "Focus score dropped to 38%.", theme.colorScheme.secondary),
                _buildTimelineEvent(context, "10:24 AM", "AI Strategy Deployed", "Constraint Inversion strategy suggested.", theme.primaryColor),
                _buildTimelineEvent(context, "10:35 AM", "Flow Resumed", "Focus score stabilized at 79%.", theme.primaryColor),
                _buildTimelineEvent(context, "10:48 AM", "Fatigue Detected", "Intervention fired. 5m break accepted.", theme.colorScheme.error),
                _buildTimelineEvent(context, "10:52 AM", "Session Concluded", "Ended manually.", theme.dividerColor, isLast: true),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String label, int target, String unit) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: theme.dividerColor)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                CountUpText(target: target, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: theme.textTheme.displayLarge?.color)),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, left: 4),
                  child: Text(unit, style: TextStyle(fontSize: 14, color: theme.textTheme.labelSmall?.color, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineEvent(BuildContext context, String time, String title, String description, Color color, {bool isLast = false}) {
    final theme = Theme.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 70,
            child: Text(time, style: theme.textTheme.labelSmall?.copyWith(fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 3),
                ),
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
          const SizedBox(width: 20),
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