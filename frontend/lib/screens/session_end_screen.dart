import 'package:flutter/material.dart';
import '../core/models.dart';
import '../widgets/count_up_text.dart';
import '../widgets/focus_ring.dart';
import '../widgets/focus_sparkline.dart';
import 'main_layout.dart';

class SessionEndScreen extends StatelessWidget {
  final SessionEndData result;
  const SessionEndScreen({super.key, required this.result});

  String _formatClock(dynamic ts) {
    final t = DateTime.tryParse(ts?.toString() ?? '');
    if (t == null) return '--:--';
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  (String, String, Color) _eventCopy(Map<String, dynamic> e, ThemeData theme) {
    final state = (e['state'] ?? '').toString();
    final score = ((e['score'] ?? 75) as num).toDouble().round();
    switch (state) {
      case 'stuck':
        return ('Cognitive loop detected', 'Focus score dropped to $score%.', theme.colorScheme.secondary);
      case 'fatigue':
        return ('Fatigue detected', 'Focus score at $score% — reset recommended.', theme.colorScheme.error);
      case 'passive':
      case 'distracted':
        return ('Attention drift', 'Focus score at $score% — context switching observed.', theme.colorScheme.secondary);
      case 'neutral':
        return ('Steady state', 'Focus score holding at $score%.', theme.primaryColor);
      default:
        return ('In flow', 'Focus score at $score%.', theme.primaryColor);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final events = result.events;

    final learnedText = result.eventCount == 0
        ? "No telemetry reached the engine this session (the activity agent may not have run). Complete a session with the desktop agent running and FLOW will start learning your rhythm."
        : "Across ${result.eventCount} telemetry ticks, your strongest trough landed at minute ${result.troughMinute}. Your ultradian cycle is currently estimated at ${result.cycleMinutes} minutes — next session, FLOW will schedule your break just before that dip.";

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
                            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6)
                          )
                        ),
                        const SizedBox(height: 4),
                        Text("Great work.", style: theme.textTheme.displayMedium),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const MainLayout()),
                          (route) => false,
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
                                        target: result.focusScore,
                                        style: theme.textTheme.displayLarge?.copyWith(color: theme.primaryColor, fontSize: 64),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 12, left: 4),
                                        child: Text("%", style: TextStyle(fontSize: 28, color: theme.primaryColor, fontWeight: FontWeight.w700)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              FocusRing(
                                score: result.focusScore.toDouble(),
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
                          _buildStatCard(context, "TOTAL DURATION", result.actualDurationMin ?? 0, "min"),
                          const SizedBox(height: 14),
                          _buildStatCard(context, "TELEMETRY TICKS", result.eventCount, "logged"),
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
                              if (result.scores.length >= 2)
                                FocusSparkline(
                                  scores: result.scores,
                                  color: theme.primaryColor,
                                  height: 140,
                                )
                              else
                                Text(
                                  "Not enough telemetry was captured to replay this session.",
                                  style: theme.textTheme.bodyMedium,
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
                                learnedText,
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

                if (events.isEmpty)
                  Text(
                    "No events logged for this session.",
                    style: theme.textTheme.bodyMedium,
                  )
                else
                  ...List.generate(events.length, (i) {
                    final e = events[i];
                    final (title, description, color) = _eventCopy(e, theme);
                    return _buildTimelineEvent(
                      context,
                      _formatClock(e['ts']),
                      title,
                      description,
                      color,
                      isLast: i == events.length - 1,
                    );
                  }),
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
