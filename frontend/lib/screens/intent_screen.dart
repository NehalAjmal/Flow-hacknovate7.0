import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../widgets/flow_data_card.dart';
import 'active_session_screen.dart'; // IMPORT ADDED

class IntentScreen extends StatefulWidget {
  const IntentScreen({super.key});

  @override
  State<IntentScreen> createState() => _IntentScreenState();
}

class _IntentScreenState extends State<IntentScreen> {
  String selectedDemand = 'heavy';
  String selectedDuration = '90'; 

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("New Session Declaration", style: theme.textTheme.headlineMedium),
          const SizedBox(height: 32),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 1, child: _buildDeclarationForm(theme)),
                const SizedBox(width: 48),
                Expanded(flex: 1, child: _buildIntelligencePanel(theme)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeclarationForm(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("What are you working on?", style: theme.textTheme.labelSmall),
        const SizedBox(height: 12),
        TextField(
          controller: TextEditingController(text: "Debugging auth module"),
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            filled: true,
            fillColor: theme.cardColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.dividerColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.dividerColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.primaryColor)),
          ),
        ),
        const SizedBox(height: 32),
        Text("COGNITIVE DEMAND", style: theme.textTheme.labelSmall),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildPillToggle("Light", 'light', selectedDemand, theme, (v) => setState(() => selectedDemand = v))),
            const SizedBox(width: 12),
            Expanded(child: _buildPillToggle("Moderate", 'moderate', selectedDemand, theme, (v) => setState(() => selectedDemand = v))),
            const SizedBox(width: 12),
            Expanded(child: _buildPillToggle("Heavy", 'heavy', selectedDemand, theme, (v) => setState(() => selectedDemand = v), activeColor: theme.colorScheme.error)),
          ],
        ),
        const SizedBox(height: 32),
        Text("SESSION LENGTH", style: theme.textTheme.labelSmall),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildPillToggle("25 min", '25', selectedDuration, theme, (v) => setState(() => selectedDuration = v))),
            const SizedBox(width: 12),
            Expanded(child: _buildPillToggle("50 min", '50', selectedDuration, theme, (v) => setState(() => selectedDuration = v))),
            const SizedBox(width: 12),
            Expanded(child: _buildPillToggle("90 min", '90', selectedDuration, theme, (v) => setState(() => selectedDuration = v))),
            const SizedBox(width: 12),
            Expanded(child: _buildPillToggle("Custom", 'custom', selectedDuration, theme, (v) => setState(() => selectedDuration = v))),
          ],
        ),
        const Spacer(),
        
        // BUTTON WIRED UP
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.textTheme.displayLarge?.color,
              foregroundColor: theme.scaffoldBackgroundColor,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            onPressed: () {
              // Pushes the active session over the entire app shell
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => const ActiveSessionScreen(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                ),
              );
            },
            child: const Text("Begin Focus Session →", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildPillToggle(String text, String value, String groupValue, ThemeData theme, Function(String) onSelect, {Color? activeColor}) {
    final isSelected = value == groupValue;
    final color = activeColor ?? theme.primaryColor;

    return InkWell(
      onTap: () => onSelect(value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : theme.dividerColor, width: isSelected ? 1.5 : 1.0),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isSelected ? color : theme.textTheme.labelSmall?.color,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildIntelligencePanel(ThemeData theme) {
    final troughColor = FlowTheme.stateColor(context, SessionState.trough);
    final driftColor = FlowTheme.stateColor(context, SessionState.drift);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text("PRE-SESSION CHECK", style: theme.textTheme.labelSmall),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: theme.primaryColor.withValues(alpha:0.08), border: Border.all(color: theme.primaryColor.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(12)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: theme.primaryColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Peak window open", style: theme.textTheme.bodyLarge?.copyWith(color: theme.primaryColor, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text("Historically your best 2 hours of the day. Good time to start.", style: theme.textTheme.bodyMedium?.copyWith(color: theme.primaryColor.withValues(alpha: 0.8))),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: troughColor.withValues(alpha:0.08), border: Border.all(color: troughColor.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(12)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: troughColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Trough in ~28 min", style: theme.textTheme.bodyLarge?.copyWith(color: troughColor, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text("Recommended break at 10:48 AM. Adjust session if needed.", style: theme.textTheme.bodyMedium?.copyWith(color: troughColor.withValues(alpha: 0.8))),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FlowDataCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("FLOW RECOMMENDATION", style: theme.textTheme.labelSmall),
              const SizedBox(height: 8),
              Text("73 min session", style: theme.textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text("Based on calendar + rhythm + today's fatigue", style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: FlowDataCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("3-HOUR FORECAST", style: theme.textTheme.labelSmall),
                const SizedBox(height: 24),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildForecastRow("9:15", 0.88, theme.primaryColor, "Peak — start now", theme),
                      _buildForecastRow("10:45", 0.28, troughColor, "Trough — take break", theme),
                      _buildForecastRow("11:15", 0.05, driftColor, "Standup meeting", theme),
                      _buildForecastRow("12:00", 0.62, theme.primaryColor, "Second window", theme),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForecastRow(String time, double strength, Color color, String label, ThemeData theme) {
    return Row(
      children: [
        SizedBox(width: 50, child: Text(time, style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.labelSmall?.color))),
        Expanded(
          child: Container(
            height: 8,
            decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(4)),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: strength,
              child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(width: 140, child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w500), textAlign: TextAlign.right)),
      ],
    );
  }
}