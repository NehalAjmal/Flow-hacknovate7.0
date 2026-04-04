import 'package:flutter/material.dart';

class TeamScreen extends StatelessWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // ✅ Lets the AppShell mesh show through
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(context),
            const SizedBox(height: 24),
            _buildTeamStatsGrid(context),
            const SizedBox(height: 14),
            _buildTeamNodesCard(context),
            const SizedBox(height: 14),
            
            // ✅ THE FIX: IntrinsicHeight safely allows the cards to match heights 
            // without forcing them to stretch into infinity and crashing!
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildTeamFocusWindow(context)),
                  const SizedBox(width: 14),
                  Expanded(child: _buildCollectiveDrift(context)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // ─── TOP BAR ─────────────────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "DEPARTMENT TELEMETRY",
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6), // ✅ Dynamic Color
              ),
            ),
            const SizedBox(height: 2),
            Text("Team node map", style: theme.textTheme.headlineLarge),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: theme.primaryColor.withValues(alpha: 0.15), // ✅ Dynamic Color
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            "ERR011",
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  // ─── HERO STATS ──────────────────────────────────────────────────────────
  Widget _buildTeamStatsGrid(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildHeroCard("AVG ALIGNMENT", "74%", const [Color(0xFF4F6F57), Color(0xFF6B8F71)])),
        const SizedBox(width: 14),
        Expanded(child: _buildHeroCard("ACTIVE NODES", "12", const [Color(0xFF8B5E3A), Color(0xFFC4845A)])),
        const SizedBox(width: 14),
        Expanded(child: _buildHeroCard("COLLECTIVE FLOW", "2.4h", const [Color(0xFF1A4A44), Color(0xFF3D7A72)])),
      ],
    );
  }

  Widget _buildHeroCard(String label, String value, List<Color> gradientColors) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70, fontFamily: 'DM Mono', letterSpacing: 1.5)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -2, height: 1)),
        ],
      ),
    );
  }

  // ─── TEAM NODES ──────────────────────────────────────────────────────────
  Widget _buildTeamNodesCard(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Theme.of(context).dividerColor)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Your team", style: Theme.of(context).textTheme.headlineSmall),
                Text("Full view", style: TextStyle(fontSize: 11, color: Theme.of(context).primaryColor, fontFamily: 'DM Mono', fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _buildTeamNode(context, "Amaan", "A", "● Deep Work", "92% focus", const [Color(0xFF4F6F57), Color(0xFF6B8F71)], true)),
                const SizedBox(width: 10),
                Expanded(child: _buildTeamNode(context, "Nehal", "N", "● Focus", "78% focus", const [Color(0xFF3D7A72), Color(0xFF5AAD9E)], true)),
                const SizedBox(width: 10),
                Expanded(child: _buildTeamNode(context, "Laraib", "L", "◎ Trough", "43% focus", const [Color(0xFF8B5E3A), Color(0xFFC4845A)], false)),
                const SizedBox(width: 10),
                Expanded(child: _buildTeamNode(context, "Shreya", "S", "● Deep Work", "88% focus", const [Color(0xFF7A6B8F), Color(0xFF9E8FB0)], true)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTeamNode(BuildContext context, String name, String initial, String status, String focusScore, List<Color> avatarGradient, bool isInFlow) {
    final theme = Theme.of(context);

    final borderColor = isInFlow ? theme.primaryColor : theme.colorScheme.secondary;
    // ✅ Dynamic Background Colors
    final bgColor = isInFlow 
        ? theme.primaryColor.withValues(alpha: 0.1)
        : theme.colorScheme.secondary.withValues(alpha: 0.1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor, width: 1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: avatarGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          Text(name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: theme.textTheme.bodyLarge?.color)),
          const SizedBox(height: 2),
          Text(status, style: theme.textTheme.labelSmall),
          const SizedBox(height: 8),
          _buildTag(context, focusScore, isGreen: isInFlow, isOrange: !isInFlow),
        ],
      ),
    );
  }

  // ─── BOTTOM CHARTS ───────────────────────────────────────────────────────
  Widget _buildTeamFocusWindow(BuildContext context) {
    final bars = [0.20, 0.15, 0.80, 0.90, 0.55, 0.30, 0.65, 0.25];
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: theme.dividerColor)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Team focus window", style: theme.textTheme.headlineSmall),
            const SizedBox(height: 14),
            SizedBox(
              height: 60,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(bars.length, (index) {
                  final h = bars[index];
                  final isTrough = index == 4;
                  final color = isTrough ? theme.colorScheme.secondary : theme.primaryColor;
                  final opacity = h > 0.7 ? 0.9 : (h > 0.4 ? 0.5 : 0.3);

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: FractionallySizedBox(
                        heightFactor: h,
                        child: Container(
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: opacity),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 8),
            Text("Best meeting slots: Tue/Thu 14–15h", style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectiveDrift(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: theme.dividerColor)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Collective drift events", style: theme.textTheme.headlineSmall),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Slack notifications", style: theme.textTheme.bodyMedium),
                _buildTag(context, "47 today", isRose: true),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: 0.72,
                minHeight: 8,
                backgroundColor: theme.dividerColor,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Ad-hoc meetings", style: theme.textTheme.bodyMedium),
                _buildTag(context, "3 today", isOrange: true),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: 0.34,
                minHeight: 8,
                backgroundColor: theme.dividerColor,
                color: theme.colorScheme.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(BuildContext context, String text, {bool isGreen = false, bool isOrange = false, bool isRose = false}) {
    final theme = Theme.of(context);
    
    // ✅ Dynamic Colors
    Color bgColor = theme.primaryColor.withValues(alpha: 0.15);
    Color textColor = theme.primaryColor;

    if (isOrange) {
      bgColor = theme.colorScheme.secondary.withValues(alpha: 0.15);
      textColor = theme.colorScheme.secondary;
    } else if (isRose) {
      bgColor = theme.colorScheme.error.withValues(alpha: 0.15);
      textColor = theme.colorScheme.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(100)),
      child: Text(text, style: theme.textTheme.labelLarge?.copyWith(color: textColor, fontSize: 9)),
    );
  }
}