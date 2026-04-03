import 'package:flutter/material.dart';
import '../core/theme.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key}); // ✅ FIX: use_super_parameters

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
            _buildHeroRow(context),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildLiveStateGrid(context)),
                const SizedBox(width: 14),
                Expanded(flex: 2, child: _buildSessionVolumeCard(context)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _buildPerformanceTrend(context)),
                const SizedBox(width: 14),
                Expanded(flex: 3, child: _buildPatternInsights(context)),
              ],
            ),
            const SizedBox(height: 24),
            _buildEmployeeTable(context),
          ],
        ),
      ),
    );
  }

  // ─── TOP BAR ─────────────────────────────────────────────────────────────
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
              "COMPANY ADMINISTRATOR · ERROR 011",
              style: theme.textTheme.labelMedium?.copyWith(
                color: isDark ? FlowTheme.text3Dark : FlowTheme.text3Light,
              ),
            ),
            const SizedBox(height: 2),
            Text("Team Cognitive Health", style: theme.textTheme.headlineLarge),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () {
            // Action: Send Team Break Alert
          },
          icon: const Icon(Icons.notifications_active_rounded, size: 18),
          label: const Text("Send Team Break Alert"),
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? FlowTheme.driftDark : FlowTheme.driftLight,
            foregroundColor: Colors.white,
          ),
        )
      ],
    );
  }

  // ─── HERO ROW ────────────────────────────────────────────────────────────
  Widget _buildHeroRow(BuildContext context) {
    return Row(
      children: [
        // Focus Score Card
        Expanded(
          child: _buildGradientHeroCard(
            context,
            "TEAM FOCUS SCORE",
            "71",
            "↑ +4 vs yesterday",
            const [Color(0xFF4F6F57), Color(0xFF6B8F71)],
          ),
        ),
        const SizedBox(width: 14),
        
        // Burnout Risk Card (Alert)
        Expanded(
          child: _buildGradientHeroCard(
            context,
            "BURNOUT RISK FLAGS",
            "2",
            "Employees flagged this week",
            const [Color(0xFF5A1E28), Color(0xFF9E3D4A)],
          ),
        ),
        const SizedBox(width: 14),
        
        // Best Meeting Window
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("BEST MEETING WINDOW", style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 6),
                  Text("14:30", style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, color: Theme.of(context).primaryColor, letterSpacing: -2, height: 1)),
                  const SizedBox(height: 6),
                  Text("Optimal slot in next 4 hours", style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGradientHeroCard(BuildContext context, String label, String value, String sub, List<Color> colors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70, fontFamily: 'DM Mono', letterSpacing: 1.5)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -2, height: 1)),
          const SizedBox(height: 6),
          Text(sub, style: const TextStyle(fontSize: 12, color: Colors.white)),
        ],
      ),
    );
  }

  // ─── LIVE STATE GRID ─────────────────────────────────────────────────────
  Widget _buildLiveStateGrid(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Live Team States", style: Theme.of(context).textTheme.headlineSmall),
                _buildTag(context, "Updates 60s", isGreen: true),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildStateCount(context, "Deep Work", "2", Theme.of(context).primaryColor)),
                Expanded(child: _buildStateCount(context, "Shallow Work", "1", Theme.of(context).textTheme.bodyMedium!.color!)),
                Expanded(child: _buildStateCount(context, "Break", "0", Theme.of(context).colorScheme.primaryContainer)),
                Expanded(child: _buildStateCount(context, "Trough", "1", Theme.of(context).colorScheme.secondary)),
                Expanded(child: _buildStateCount(context, "Offline", "2", Theme.of(context).dividerColor)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStateCount(BuildContext context, String label, String count, Color color) {
    return Column(
      children: [
        Text(count, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, fontFamily: 'DM Mono', fontWeight: FontWeight.w600), textAlign: TextAlign.center),
      ],
    );
  }

  // ─── SESSION VOLUME ──────────────────────────────────────────────────────
  Widget _buildSessionVolumeCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Session Volume", style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Sessions Today", style: Theme.of(context).textTheme.bodyMedium),
                Text("9", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Theme.of(context).primaryColor)),
              ],
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Avg Duration", style: Theme.of(context).textTheme.bodyMedium),
                Text("68 min", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Theme.of(context).primaryColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── PERFORMANCE TREND ───────────────────────────────────────────────────
  Widget _buildPerformanceTrend(BuildContext context) {
    final bars = [0.65, 0.70, 0.68, 0.75, 0.82, 0.71, 0.85];
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("7-Day Trend", style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 14),
            SizedBox(
              height: 80,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(bars.length, (index) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: FractionallySizedBox(
                              heightFactor: bars[index],
                              child: Container(
                                decoration: BoxDecoration(
                                  // ✅ FIX: withOpacity → withValues
                                  color: Theme.of(context).primaryColor.withValues(alpha: 0.8),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(days[index], style: Theme.of(context).textTheme.labelSmall),
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

  // ─── PATTERN INSIGHTS ────────────────────────────────────────────────────
  Widget _buildPatternInsights(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Team Pattern Insights", style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _buildInsightPill(context, "10–11 AM", "Peak Focus Hour")),
                const SizedBox(width: 8),
                Expanded(child: _buildInsightPill(context, "14:00", "Common Stuck Time", isWarning: true)),
                const SizedBox(width: 8),
                Expanded(child: _buildInsightPill(context, "18 min", "Best Break Length")),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInsightPill(BuildContext context, String value, String label, {bool isWarning = false}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: isWarning ? theme.colorScheme.secondaryContainer : theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isWarning ? theme.colorScheme.secondary : theme.primaryColor)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 9, fontFamily: 'DM Mono'), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ─── EMPLOYEE TABLE (ANONYMIZED) ─────────────────────────────────────────
  Widget _buildEmployeeTable(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Employee Overview (Anonymized)", style: Theme.of(context).textTheme.headlineSmall),
                Text("Privacy Enforced", style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color, fontFamily: 'DM Mono')),
              ],
            ),
            const SizedBox(height: 16),
            _buildTableRow(context, "ID", "Focus Score", "Sessions", "Burnout Flag", isHeader: true),
            const Divider(),
            _buildTableRow(context, "Employee 1", "88", "12", false),
            const Divider(),
            _buildTableRow(context, "Employee 2", "76", "9", false),
            const Divider(),
            _buildTableRow(context, "Employee 3", "42", "2", true),
            const Divider(),
            _buildTableRow(context, "Employee 4", "91", "14", false),
            const Divider(),
            _buildTableRow(context, "Employee 5", "58", "6", false),
          ],
        ),
      ),
    );
  }

  Widget _buildTableRow(BuildContext context, String col1, String col2, String col3, dynamic col4, {bool isHeader = false}) {
    final style = isHeader 
        ? Theme.of(context).textTheme.labelSmall 
        : Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);
        
    Widget lastCol;
    if (isHeader) {
      lastCol = Text(col4, style: style);
    } else {
      bool isFlagged = col4 as bool;
      lastCol = Container(
        width: 10, height: 10,
        decoration: BoxDecoration(
          color: isFlagged ? Theme.of(context).colorScheme.error : Theme.of(context).primaryColor,
          shape: BoxShape.circle,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(col1, style: style)),
          Expanded(flex: 2, child: Text(col2, style: style)),
          Expanded(flex: 2, child: Text(col3, style: style)),
          Expanded(flex: 1, child: lastCol),
        ],
      ),
    );
  }

  Widget _buildTag(BuildContext context, String text, {bool isGreen = false}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isGreen 
            ? (isDark ? FlowTheme.primaryTintDark : FlowTheme.primaryTintLight)
            : theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(text, style: theme.textTheme.labelLarge?.copyWith(
        color: isGreen ? theme.primaryColor : theme.textTheme.bodyMedium?.color, 
        fontSize: 10
      )),
    );
  }
}