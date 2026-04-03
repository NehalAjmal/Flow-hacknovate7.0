import 'package:flutter/material.dart';
import 'theme.dart';
import 'widgets/count_up_text.dart';
import 'widgets/focus_ring.dart';
import 'widgets/meeting_countdown_pill.dart';
import 'widgets/skeleton_loader.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  late AnimationController _ringEntry;

  @override
  void initState() {
    super.initState();
    _ringEntry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    // Simulate initial data fetch as per specs (1.8s)
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() => _isLoading = false);
        _ringEntry.forward();
      }
    });
  }

  @override
  void dispose() {
    _ringEntry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildSkeletonDashboard();

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(context),
            const SizedBox(height: 24),
            _buildInterventionBanner(context),
            const SizedBox(height: 20),
            _buildRow1(context), 
            const SizedBox(height: 14),
            _buildRow2(context), 
            const SizedBox(height: 14),
            _buildRow3(context), 
          ],
        ),
      ),
    );
  }

  // ─── SKELETON LOADER ─────────────────────────────────────────────────────
  Widget _buildSkeletonDashboard() {
    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SkeletonBox(width: 200, height: 40),
              SkeletonBox(width: 140, height: 32, borderRadius: BorderRadius.circular(100)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: const [
              Expanded(flex: 3, child: SkeletonStatCard()),
              SizedBox(width: 14),
              Expanded(flex: 2, child: SkeletonStatCard()),
            ],
          )
        ],
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
            Text("SAT, 4 APR · 09:24", style: theme.textTheme.labelMedium?.copyWith(color: isDark ? FlowTheme.text3Dark : FlowTheme.text3Light)),
            const SizedBox(height: 2),
            Text("Good morning, Nehal 👋", style: theme.textTheme.headlineLarge),
          ],
        ),
        // Live Meeting Pill Injection
        MeetingCountdownPill(
          nextMeetingTime: DateTime.now().add(const Duration(minutes: 14)),
          meetingTitle: "Team standup",
        ),
      ],
    );
  }

  // ─── INTERVENTION BANNER ──────────────────────────────────────────────────
  Widget _buildInterventionBanner(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final driftColor = isDark ? FlowTheme.driftDark : FlowTheme.driftLight;
    final driftBg = isDark ? FlowTheme.driftBgDark : FlowTheme.driftBgLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: driftBg,
        border: Border.all(color: driftColor, width: 1.5),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: driftColor.withOpacity(0.1), blurRadius: 12, spreadRadius: 2)
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: driftColor, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.compare_arrows_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("You've drifted from your intention", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: driftColor)),
                const SizedBox(height: 3),
                Text("Context drift is normal. Your session goal was \"Debug auth module\" — want to return?", style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: driftColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: Size.zero,
            ),
            child: const Text("Return to task", style: TextStyle(fontSize: 11)),
          )
        ],
      ),
    );
  }

  // ─── ROW 1: HERO + STATS ──────────────────────────────────────────────────
  Widget _buildRow1(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left: Asym Large (Flex 3)
        Expanded(
          flex: 3,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("FOCUS SCORE", style: Theme.of(context).textTheme.labelMedium),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              CountUpText(
                                target: 82,
                                style: Theme.of(context).textTheme.displayLarge?.copyWith(color: Theme.of(context).primaryColor),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8, left: 2),
                                child: Text("%", style: TextStyle(fontSize: 24, color: Theme.of(context).primaryColor, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      FocusRing(
                        score: 82, 
                        color: Theme.of(context).primaryColor, 
                        trackColor: Theme.of(context).dividerColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Ultradian Rhythm Bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("ULTRADIAN RHYTHM", style: Theme.of(context).textTheme.labelSmall),
                          Text("Cycle 2 / Peak", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).primaryColor)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _buildRhythmSegment(context, isTrough: true),
                          _buildRhythmSegment(context, isPeak: true),
                          _buildRhythmSegment(context, isPeak: true),
                          _buildRhythmSegment(context, isCurrent: true),
                          _buildRhythmSegment(context, isUpcoming: true),
                          _buildRhythmSegment(context, isUpcoming: true),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Bottom Pills
                  Row(
                    children: [
                      Expanded(child: _buildStatPill(context, 47, "CURRENT CYCLE", "min", isPrimary: true)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildStatPill(context, 13, "NEXT BREAK", "min", isFatigue: true, prefix: '~')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        
        // Right: Asym Small (Flex 2)
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Expanded(child: _buildHeroCard(context, "SESSIONS TODAY", "3", "2h 14m total focus", isGreen: true)),
              const SizedBox(height: 12),
              Expanded(child: _buildHeroCard(context, "STREAK", "7 🔥", "days in a row", isOrange: true)),
              const SizedBox(height: 12),
              Expanded(
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("EYE FATIGUE", style: Theme.of(context).textTheme.labelMedium),
                            CountUpText(target: 34, prefix: '0.', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Theme.of(context).primaryColor)),
                            Text("EAR · Normal", style: Theme.of(context).textTheme.labelSmall),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(100),
                                child: LinearProgressIndicator(
                                  value: 0.34,
                                  minHeight: 8,
                                  backgroundColor: Theme.of(context).dividerColor,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text("threshold 0.25", style: Theme.of(context).textTheme.labelSmall),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── ROW 2: CALENDAR + APPS ───────────────────────────────────────────────
  Widget _buildRow2(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Today's schedule", style: Theme.of(context).textTheme.headlineSmall),
                      Text("View all", style: TextStyle(fontSize: 11, color: Theme.of(context).primaryColor, fontFamily: 'DM Mono', fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _buildCalDay(context, "Mon", "30"),
                      _buildCalDay(context, "Tue", "31"),
                      _buildCalDay(context, "Wed", "1"),
                      _buildCalDay(context, "Thu", "2"),
                      _buildCalDay(context, "Fri", "3", hasEvent: true),
                      _buildCalDay(context, "Sat", "4", isActive: true, hasEvent: true),
                      _buildCalDay(context, "Sun", "5"),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Column(
                      children: [
                        _buildTimelineItem(context, "📌", "Debug auth module", "09:00 — ongoing · FLOW session", true, false),
                        _buildTimelineItem(context, "📅", "Team standup", "11:00 — 11:30 · Google Meet", false, true),
                        _buildTimelineItem(context, "💤", "Afternoon deep work", "14:00 — recommended window", false, false, isLast: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("App focus map", style: Theme.of(context).textTheme.headlineSmall),
                      _buildTag(context, "Live", true),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildAppRow(context, "💻", "VS Code", "47m", 0.82, const Color(0xFFE8F0EA), Theme.of(context).primaryColor),
                  _buildAppRow(context, "🌐", "Chrome", "12m", 0.21, const Color(0xFFFFF3E8), Theme.of(context).colorScheme.secondary),
                  _buildAppRow(context, "💬", "Slack", "8m", 0.14, const Color(0xFFF0E8F5), Theme.of(context).colorScheme.error),
                  _buildAppRow(context, "📋", "Notion", "5m", 0.09, const Color(0xFFE8EEF5), Theme.of(context).primaryColor),
                  const Spacer(),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("DRIFT SCORE", style: Theme.of(context).textTheme.labelSmall),
                      _buildTag(context, "LOW · 12%", true),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── ROW 3: BIOMETRIC ─────────────────────────────────────────────────────
  Widget _buildRow3(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildBiometricCard(context, "Heart Rate", 72, "BPM", "↓ calm", isDrift: true, heights: [0.4, 0.6, 0.5, 0.45, 0.48, 0.42, 0.44])),
        const SizedBox(width: 14),
        Expanded(child: _buildBiometricCard(context, "HRV", 54, "ms", "↑ high", heights: [0.55, 0.7, 0.8, 0.75, 0.85, 0.82, 0.88])),
        const SizedBox(width: 14),
        Expanded(
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("QUICK ACTIONS", style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text("＋ New session"),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Theme.of(context).colorScheme.primaryContainer),
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      ),
                      child: Text("View active →", style: TextStyle(color: Theme.of(context).primaryColor)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── HELPER WIDGETS ───────────────────────────────────────────────────────

  Widget _buildTag(BuildContext context, String text, bool isGreen) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isGreen ? (isDark ? FlowTheme.primaryTintDark : FlowTheme.primaryTintLight) : (isDark ? FlowTheme.fatigueBgDark : FlowTheme.fatigueBgLight),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: isGreen ? (isDark ? FlowTheme.primaryDark : FlowTheme.primaryLight) : (isDark ? FlowTheme.fatigueDark : FlowTheme.fatigueLight),
      )),
    );
  }

  Widget _buildRhythmSegment(BuildContext context, {bool isTrough = false, bool isPeak = false, bool isCurrent = false, bool isUpcoming = false}) {
    final theme = Theme.of(context);
    Color bgColor = theme.dividerColor;
    Border? border;

    if (isTrough) bgColor = theme.colorScheme.secondary.withOpacity(0.6);
    else if (isPeak) bgColor = theme.primaryColor;
    else if (isCurrent) {
      bgColor = theme.brightness == Brightness.dark ? FlowTheme.primaryStrongDark : FlowTheme.primaryStrongLight;
      border = Border.all(color: theme.primaryColor, width: 2);
    }

    return Expanded(
      child: Container(
        height: 32, margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(4), border: border),
      ),
    );
  }

  Widget _buildStatPill(BuildContext context, int target, String label, String unit, {bool isPrimary = false, bool isFatigue = false, String prefix = ''}) {
    final theme = Theme.of(context);
    Color bgColor = theme.colorScheme.primaryContainer;
    Color valColor = theme.primaryColor;
    if (isFatigue) {
      bgColor = theme.colorScheme.secondaryContainer;
      valColor = theme.colorScheme.secondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CountUpText(target: target, prefix: prefix, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: valColor, letterSpacing: -0.5)),
              Padding(padding: const EdgeInsets.only(bottom: 3, left: 2), child: Text(unit, style: TextStyle(fontSize: 11, color: valColor, fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 4),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, String label, String value, String sub, {bool isGreen = false, bool isOrange = false}) {
    List<Color> gradientColors = isGreen ? [const Color(0xFF4F6F57), const Color(0xFF6B8F71)] : [const Color(0xFF8B5E3A), const Color(0xFFC4845A)];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: LinearGradient(colors: gradientColors), borderRadius: BorderRadius.circular(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70, fontFamily: 'DM Mono', letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -2, height: 1)),
          const SizedBox(height: 4),
          Text(sub, style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildCalDay(BuildContext context, String name, String num, {bool isActive = false, bool hasEvent = false}) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? theme.primaryColor : theme.scaffoldBackgroundColor,
          border: Border.all(color: isActive ? theme.primaryColor : theme.dividerColor),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(name, style: TextStyle(fontSize: 9, fontFamily: 'DM Mono', color: isActive ? Colors.white70 : theme.textTheme.bodySmall?.color)),
            const SizedBox(height: 2),
            Text(num, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isActive ? Colors.white : theme.textTheme.bodyLarge?.color)),
            if (hasEvent) ...[
              const SizedBox(height: 4),
              Container(width: 4, height: 4, decoration: BoxDecoration(color: isActive ? Colors.white : theme.colorScheme.secondary, shape: BoxShape.circle))
            ] else const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(BuildContext context, String emoji, String title, String time, bool isGreen, bool isOrange, {bool isLast = false}) {
    final theme = Theme.of(context);
    Color dotBg = isGreen ? theme.colorScheme.primaryContainer : (isOrange ? theme.colorScheme.secondaryContainer : theme.colorScheme.surface);
    Color dotBorder = isGreen ? theme.primaryColor : (isOrange ? theme.colorScheme.secondary : theme.dividerColor);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(color: dotBg, border: Border.all(color: dotBorder, width: 2), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(emoji, style: const TextStyle(fontSize: 14)),
                ),
                if (!isLast) Expanded(child: Container(width: 2, color: theme.dividerColor)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(time, style: theme.textTheme.labelSmall),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAppRow(BuildContext context, String emoji, String name, String time, double progress, Color iconBg, Color barColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(9)), alignment: Alignment.center, child: Text(emoji, style: const TextStyle(fontSize: 16))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)), Text(time, style: Theme.of(context).textTheme.labelSmall)]),
                const SizedBox(height: 6),
                ClipRRect(borderRadius: BorderRadius.circular(100), child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: Theme.of(context).dividerColor, color: barColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBiometricCard(BuildContext context, String title, int target, String unit, String sub, {bool isDrift = false, required List<double> heights}) {
    final theme = Theme.of(context);
    final highlightColor = isDrift ? theme.colorScheme.error : theme.primaryColor;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(), style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            Row(
              children: [
                CountUpText(target: target, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: highlightColor, letterSpacing: -1.5)),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(unit, style: theme.textTheme.bodySmall),
                    Text(sub, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.primaryColor)),
                  ],
                )
              ],
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: heights.map((h) => Expanded(
                child: Container(
                  height: 48 * h, margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(color: theme.primaryColor.withOpacity(h > 0.6 ? 1.0 : (h > 0.45 ? 0.7 : 0.3)), borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}