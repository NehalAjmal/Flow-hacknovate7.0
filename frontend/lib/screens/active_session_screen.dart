import 'package:flutter/material.dart';
import '../widgets/flow_data_card.dart';
import '../widgets/focus_ring.dart';

class ActiveSessionScreen extends StatefulWidget {
  const ActiveSessionScreen({super.key});

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> {
  // MOCK STATE
  bool isDrifting = false; 
  double sessionProgress = 0.68; // 68% remaining
  String timeRemaining = "28:14";

  void _toggleDriftState() {
    setState(() {
      isDrifting = !isDrifting;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    final Color targetBgColor = isDrifting 
        ? (theme.brightness == Brightness.dark ? const Color(0xFF1E1214) : const Color(0xFFFFF0F2))
        : theme.scaffoldBackgroundColor;

    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(begin: theme.scaffoldBackgroundColor, end: targetBgColor),
      duration: const Duration(seconds: 2), 
      builder: (context, color, child) {
        return Scaffold(
          backgroundColor: color,
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 40.0), 
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                // LEFT PANEL: The Focus Anchor
                Expanded(
                  flex: 5, 
                  child: _buildLeftPanel(theme),
                ),
                
                const SizedBox(width: 48), 

                // RIGHT PANEL: Telemetry Grid
                Expanded(
                  flex: 4, 
                  child: isDrifting ? _buildInterventionPanel(theme) : _buildTelemetryStack(theme),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _toggleDriftState,
            backgroundColor: theme.primaryColor,
            elevation: 0, 
            child: const Icon(Icons.warning_amber_rounded, color: Colors.white),
          ),
        );
      },
    );
  }

  Widget _buildLeftPanel(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center, 
      children: [
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 420),
            child: FocusRing(
              progress: sessionProgress,
              timeString: timeRemaining,
              isDrifting: isDrifting,
            ),
          ),
        ),
        const SizedBox(height: 40),
        
        // Structured Task Container 
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor, width: 1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "CURRENT TASK",
                style: theme.textTheme.labelSmall?.copyWith(color: theme.textTheme.labelSmall?.color?.withValues(alpha:0.6)),
              ),
              const SizedBox(height: 8),
              Text(
                "Debugging auth module",
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // State Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: isDrifting ? theme.colorScheme.error.withValues(alpha: 0.1) : theme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: isDrifting ? theme.colorScheme.error.withValues(alpha:0.5) : theme.primaryColor.withValues(alpha:0.5),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: isDrifting ? theme.colorScheme.error : theme.primaryColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (isDrifting ? theme.colorScheme.error : theme.primaryColor).withValues(alpha:0.4),
                      blurRadius: 6,
                      spreadRadius: 2,
                    )
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isDrifting ? "Drift Detected" : "Deep Work",
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: isDrifting ? theme.colorScheme.error : theme.primaryColor,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTelemetryStack(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch, 
      children: [
        FlowDataCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("RHYTHM POSITION", style: theme.textTheme.labelSmall),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text("62", style: theme.textTheme.displayLarge),
                  const SizedBox(width: 6),
                  Text("min", style: theme.textTheme.bodyLarge?.copyWith(color: theme.textTheme.labelSmall?.color)),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha:0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.75, // 62 out of ~83 mins
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text("28 min until trough", style: theme.textTheme.bodyMedium?.copyWith(color: theme.primaryColor, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        const SizedBox(height: 20), 
        
        FlowDataCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("LIVE BIOMETRICS", style: theme.textTheme.labelSmall),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                children: [
                  _buildBioStat("74", "BPM", theme),
                  _buildBioStat("38", "HRV (ms)", theme),
                  _buildBioStat("0.28", "EAR", theme),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        
        FlowDataCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("COMBINED SIGNAL", style: theme.textTheme.labelSmall),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: 0.25,
                      backgroundColor: theme.dividerColor,
                      color: theme.primaryColor,
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Text("0.25", style: theme.textTheme.headlineMedium?.copyWith(fontFeatures: [const FontFeature.tabularFigures()])), 
                ],
              ),
              const SizedBox(height: 12),
              Text("Threshold: 0.68 — all clear", style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.labelSmall?.color)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBioStat(String value, String label, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: theme.textTheme.headlineMedium?.copyWith(fontFeatures: [const FontFeature.tabularFigures()])),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }

  Widget _buildInterventionPanel(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch, 
      children: [
        FlowDataCard(
          backgroundColor: theme.colorScheme.error.withValues(alpha:0.08),
          borderColor: theme.colorScheme.error.withValues(alpha:0.4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_rounded, color: theme.colorScheme.error, size: 28),
                  const SizedBox(width: 12),
                  Text("Intent drift detected", style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.error)),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                "You declared heavy cognitive work but switched context 11 times in 10 minutes. What's happening?",
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {},
                  child: const Text("I'm stuck — help me break this down", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    side: BorderSide(color: theme.colorScheme.error.withValues(alpha:0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _toggleDriftState, 
                  child: Text("Back to task", style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}