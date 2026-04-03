import 'package:flutter/material.dart';
import 'theme.dart';

class IntentScreen extends StatefulWidget {
  final VoidCallback? onStartSession;

  const IntentScreen({Key? key, this.onStartSession}) : super(key: key);

  @override
  State<IntentScreen> createState() => _IntentScreenState();
}

class _IntentScreenState extends State<IntentScreen> {
  String _selectedTask = 'Deep work';
  String _selectedDuration = '50m';
  final TextEditingController _intentController = TextEditingController();

  final List<Map<String, String>> _taskChips = [
    {'emoji': '🧠', 'label': 'Deep work'},
    {'emoji': '📝', 'label': 'Writing'},
    {'emoji': '🐛', 'label': 'Debugging'},
    {'emoji': '📊', 'label': 'Review'},
    {'emoji': '📞', 'label': 'Meeting prep'},
    {'emoji': '🎨', 'label': 'Design'},
  ];

  final List<String> _durations = ['25m', '50m', '90m', 'Custom'];

  @override
  void dispose() {
    _intentController.dispose();
    super.dispose();
  }

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── LEFT COLUMN (Inputs) ──────────────────────────────
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTaskTypeCard(context),
                      const SizedBox(height: 16),
                      _buildIntentDeclarationCard(context),
                      const SizedBox(height: 16),
                      _buildDurationCard(context),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          // TODO: Trigger backend session start
                          if (widget.onStartSession != null) {
                            widget.onStartSession!();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.play_circle_fill_rounded, size: 22),
                            SizedBox(width: 8),
                            Text("Begin focus session", style: TextStyle(fontSize: 16)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // ─── RIGHT COLUMN (Recommendations) ────────────────────
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildOptimalWindowHero(context),
                      const SizedBox(height: 12),
                      _buildCalendarCheckCard(context),
                      const SizedBox(height: 12),
                      _buildPatternInsightCard(context),
                      const SizedBox(height: 12),
                      _buildRecentIntentionsCard(context),
                    ],
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // ─── TOP BAR ─────────────────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "STARTING A SESSION",
          style: theme.textTheme.labelMedium?.copyWith(
            color: isDark ? FlowTheme.text3Dark : FlowTheme.text3Light,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          "What will you focus on?",
          style: theme.textTheme.headlineLarge,
        ),
      ],
    );
  }

  // ─── LEFT COLUMN WIDGETS ─────────────────────────────────────────────────

  Widget _buildTaskTypeCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Task type", style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _taskChips.map((chip) {
                final isSelected = _selectedTask == chip['label'];
                return _buildChip(
                  context,
                  emoji: chip['emoji']!,
                  label: chip['label']!,
                  isSelected: isSelected,
                  onTap: () => setState(() => _selectedTask = chip['label']!),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntentDeclarationCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Declare your intention", style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _intentController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "e.g. Fix the JWT token refresh bug in the auth module and write unit tests for edge cases…",
                contentPadding: const EdgeInsets.all(20),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Be specific — FLOW will track drift against this intent.",
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Target duration", style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 12),
            Row(
              children: _durations.map((dur) {
                final isSelected = _selectedDuration == dur;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: dur != _durations.last ? 8.0 : 0),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedDuration = dur),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).scaffoldBackgroundColor,
                          border: Border.all(
                            color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).dividerColor,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          dur,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ─── RIGHT COLUMN WIDGETS ────────────────────────────────────────────────

  Widget _buildOptimalWindowHero(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
        children: const [
          Text("OPTIMAL WINDOW", style: TextStyle(fontSize: 11, color: Colors.white70, fontFamily: 'DM Mono', letterSpacing: 1.5)),
          SizedBox(height: 8),
          Text("Right now ✓", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1)),
          SizedBox(height: 6),
          Text("You're in a peak ultradian phase. Best 50 min window starts immediately.", style: TextStyle(fontSize: 13, color: Colors.white, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildCalendarCheckCard(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Calendar check", style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
                children: [
                  const TextSpan(text: "Next meeting in "),
                  TextSpan(text: "2h 36m", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text("✓ Plenty of uninterrupted time", style: TextStyle(fontSize: 11, color: Theme.of(context).primaryColor, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternInsightCard(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Your pattern says", style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(10)),
                    alignment: Alignment.center,
                    child: const Text("🔬", style: TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Peak hours: 9–11 AM", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Theme.of(context).textTheme.bodyLarge?.color)),
                        Text("Avg focus score 87% this week", style: Theme.of(context).textTheme.labelSmall),
                      ],
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildRecentIntentionsCard(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Recent intentions", style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 10),
            _buildRecentTaskItem(context, "🐛 Debug auth module"),
            const SizedBox(height: 6),
            _buildRecentTaskItem(context, "📝 Write engineering spec"),
            const SizedBox(height: 6),
            _buildRecentTaskItem(context, "🎨 UI component design"),
          ],
        ),
      ),
    );
  }

  // ─── HELPER WIDGETS ──────────────────────────────────────────────────────

  Widget _buildChip(BuildContext context, {required String emoji, required String label, required bool isSelected, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primaryContainer : theme.scaffoldBackgroundColor,
          border: Border.all(
            color: isSelected ? theme.primaryColor : theme.dividerColor,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? theme.primaryColor : theme.textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTaskItem(BuildContext context, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color),
      ),
    );
  }
}