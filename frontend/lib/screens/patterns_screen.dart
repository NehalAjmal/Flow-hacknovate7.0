import 'package:flutter/material.dart';
import 'dart:math';
import 'theme.dart';

class PatternsScreen extends StatefulWidget {
  const PatternsScreen({Key? key}) : super(key: key);

  @override
  State<PatternsScreen> createState() => _PatternsScreenState();
}

class _PatternsScreenState extends State<PatternsScreen> {
  String _selectedPeriod = 'Week';
  
  // Dummy data for the heatmap to match the redesign (28 days)
  final List<double> _heatmapData = List.generate(28, (index) => Random().nextDouble());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(context),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: _buildPeakHoursChart(context)),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Expanded(child: _buildCycleCard(context)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildStatPill(context, "4.2", "Daily sessions")),
                          const SizedBox(width: 8),
                          Expanded(child: _buildStatPill(context, "14%", "Avg drift", isWarning: true)),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildInsightsCard(context),
            const SizedBox(height: 14),
            _buildHeatmapCard(context),
          ],
        ),
      ),
    );
  }

  // ─── TOP BAR & TOGGLE ───────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "YOUR COGNITIVE PROFILE",
              style: theme.textTheme.labelMedium?.copyWith(
                color: isDark ? FlowTheme.text3Dark : FlowTheme.text3Light,
              ),
            ),
            const SizedBox(height: 2),
            Text("Patterns & Insights", style: theme.textTheme.headlineLarge),
          ],
        ),
        // Custom Toggle Row
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: ['Week', 'Month', 'All'].map((period) {
              final isSelected = _selectedPeriod == period;
              return GestureDetector(
                onTap: () => setState(() => _selectedPeriod = period),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? theme.cardColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: isSelected 
                      ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))]
                      : [],
                  ),
                  child: Text(
                    period,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? theme.textTheme.bodyLarge?.color : theme.textTheme.bodySmall?.color,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ─── PEAK HOURS CHART ───────────────────────────────────────────────────
  Widget _buildPeakHoursChart(BuildContext context) {
    final bars = [0.30, 0.15, 0.10, 0.85, 0.92, 0.78, 0.50, 0.35, 0.70, 0.65, 0.40, 0.20];
    final hours = ['7', '8', '9', '10', '11', '12', '13', '14', '15', '16', '17', '18'];
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Focus by hour", style: theme.textTheme.headlineSmall),
                _buildTag(context, "Peak: 9–11 AM", isGreen: true),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(bars.length, (index) {
                  final h = bars[index];
                  // If it's the 12 PM trough (index 6), make it orange/fatigue color
                  final isTrough = index == 6; 
                  final color = isTrough ? theme.colorScheme.secondary : theme.primaryColor;
                  final opacity = h > 0.7 ? 0.9 : (h > 0.4 ? 0.5 : 0.3);

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: FractionallySizedBox(
                              heightFactor: h,
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(opacity),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(hours[index], style: theme.textTheme.labelSmall),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── RIGHT COLUMN CARDS ─────────────────────────────────────────────────
  Widget _buildCycleCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F6F57), Color(0xFF6B8F71)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Text("PERSONAL CYCLE", style: TextStyle(fontSize: 11, color: Colors.white70, fontFamily: 'DM Mono', letterSpacing: 1.5)),
          SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: "92 ", style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -2)),
                TextSpan(text: "min", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
              ],
            ),
          ),
          SizedBox(height: 2),
          Text("Your avg ultradian period", style: TextStyle(fontSize: 12, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildStatPill(BuildContext context, String value, String label, {bool isWarning = false}) {
    final theme = Theme.of(context);
    final bgColor = isWarning ? theme.colorScheme.secondaryContainer : theme.colorScheme.primaryContainer;
    final valColor = isWarning ? theme.colorScheme.secondary : theme.primaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: valColor, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(label.toUpperCase(), style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }

  // ─── AI INSIGHTS ────────────────────────────────────────────────────────
  Widget _buildInsightsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("AI insights this week", style: Theme.of(context).textTheme.headlineSmall),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text("↑ 3 new", style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).primaryColor, fontSize: 10)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildInsightItem(context, "🌅", "Morning dominance confirmed", "87% avg focus score 9–11 AM · 7 consecutive days", "Pattern", "green"),
            const SizedBox(height: 8),
            _buildInsightItem(context, "😴", "Post-lunch dip at 13:30", "Consistent trough, avg 41% focus · schedule breaks here", "Warning", "orange"),
            const SizedBox(height: 8),
            _buildInsightItem(context, "📱", "Slack causes 68% of drifts", "Avg 8.3 context switches per session via Slack", "Action needed", "rose"),
            const SizedBox(height: 8),
            _buildInsightItem(context, "💪", "Deep work up 23% this week", "2h 14m avg daily vs 1h 49m last week", "Progress", "green"),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightItem(BuildContext context, String emoji, String title, String sub, String tag, String type) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    Color bgColor = theme.colorScheme.primaryContainer;
    if (type == "orange") bgColor = isDark ? FlowTheme.fatigueBgDark : FlowTheme.fatigueBgLight;
    if (type == "rose") bgColor = isDark ? FlowTheme.driftBgDark : FlowTheme.driftBgLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.transparent),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: theme.textTheme.bodyLarge?.color)),
                Text(sub, style: theme.textTheme.labelSmall),
              ],
            ),
          ),
          _buildTag(context, tag, isGreen: type == "green", isOrange: type == "orange", isRose: type == "rose"),
        ],
      ),
    );
  }

  // ─── HEATMAP ────────────────────────────────────────────────────────────
  Widget _buildHeatmapCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Focus heatmap — last 28 days", style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 14),
            // The Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7, // 7 days a week
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
                childAspectRatio: 1,
              ),
              itemCount: 28,
              itemBuilder: (context, index) {
                final val = _heatmapData[index];
                double opacity = 0.2;
                if (val > 0.8) opacity = 1.0;
                else if (val > 0.6) opacity = 0.85;
                else if (val > 0.4) opacity = 0.65;
                else if (val > 0.2) opacity = 0.4;
                
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(opacity),
                    borderRadius: BorderRadius.circular(6),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text("LESS", style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(width: 8),
                _buildLegendBox(0.1),
                _buildLegendBox(0.3),
                _buildLegendBox(0.6),
                _buildLegendBox(0.85),
                _buildLegendBox(1.0),
                const SizedBox(width: 8),
                Text("MORE", style: Theme.of(context).textTheme.labelSmall),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLegendBox(double opacity) {
    return Container(
      width: 10, height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(opacity),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildTag(BuildContext context, String text, {bool isGreen = false, bool isOrange = false, bool isRose = false}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    Color bgColor = theme.colorScheme.primaryContainer;
    Color textColor = theme.primaryColor;

    if (isOrange) {
      bgColor = isDark ? FlowTheme.fatigueBgDark : FlowTheme.fatigueBgLight;
      textColor = theme.colorScheme.secondary;
    } else if (isRose) {
      bgColor = isDark ? FlowTheme.driftBgDark : FlowTheme.driftBgLight;
      textColor = theme.colorScheme.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(100)),
      child: Text(text, style: theme.textTheme.labelLarge?.copyWith(color: textColor, fontSize: 11)),
    );
  }
}