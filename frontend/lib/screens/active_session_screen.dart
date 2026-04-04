import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../widgets/focus_sparkline.dart';
import '../widgets/meeting_countdown_pill.dart';
import 'interrupt_screen.dart';

class ActiveSessionScreen extends StatefulWidget {
  final VoidCallback? onEndSession;
  const ActiveSessionScreen({super.key, this.onEndSession});

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen>
    with SingleTickerProviderStateMixin {
  int _secondsElapsed = 47 * 60 + 12;
  bool _isPaused = false;
  late Timer _timer;
  late AnimationController _blinkController;
  final List<double> _focusHistory = [72, 65, 78, 80, 76, 82, 85, 88];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && mounted) {
        setState(() => _secondsElapsed++);
      }
    });

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _blinkController.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _blinkController.stop(); 
    _blinkController.dispose();
    super.dispose();
  }

  void _togglePause() => setState(() => _isPaused = !_isPaused);

  void _triggerBreak(InterruptType type) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => InterruptScreen(type: type),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  String _formatTime(int totalSeconds) {
    int h = totalSeconds ~/ 3600;
    int m = (totalSeconds % 3600) ~/ 60;
    int s = totalSeconds % 60;
    String minSec =
        '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return h > 0 ? '${h.toString().padLeft(2, '0')}:$minSec' : minSec;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final appState = context.watch<AppState>();
    final isDrifting = appState.isDrifting;

    final targetBg = isDrifting 
        ? (isDark ? const Color(0xFF24181A) : const Color(0xFFF5EBEB)) 
        : Colors.transparent;

    return Scaffold(
      backgroundColor: Colors.transparent,
      // ✅ THE FIREWALL: RepaintBoundary prevents the semantics crash!
      body: RepaintBoundary(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          color: targetBg,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
            child: Column(
              children: [
                _buildTopBar(context),
                const SizedBox(height: 24),
                _buildSessionHero(context, appState),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          _buildTelemetryConsole(context, appState),
                          const SizedBox(height: 12),
                          _buildDriftMeterCard(context, appState),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          _buildUltradianCard(context),
                          const SizedBox(height: 12),
                          _buildFlowStatusCard(context),
                          const SizedBox(height: 12),
                          _buildSessionGoalCard(context),
                        ],
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.read<AppState>().toggleDrift(),
        backgroundColor: isDrifting ? theme.colorScheme.error : theme.primaryColor,
        icon: Icon(isDrifting ? Icons.warning_amber_rounded : Icons.waves_rounded, color: Colors.white),
        label: Text(isDrifting ? "STABILIZE" : "SIMULATE DRIFT", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "SESSION IN PROGRESS",
              style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 2),
            Text("Stay in the zone.", style: theme.textTheme.headlineLarge),
          ],
        ),
        Row(
          children: [
            MeetingCountdownPill(
              nextMeetingTime: DateTime.now().add(const Duration(minutes: 32)),
              meetingTitle: "Team standup",
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: _blinkController,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                          color: theme.primaryColor, shape: BoxShape.circle),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text("LIVE", style: theme.textTheme.labelLarge?.copyWith(color: theme.primaryColor)),
                ],
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildSessionHero(BuildContext context, AppState appState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(36),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: -90, left: -90,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            children: [
              const Text(
                "TIME ELAPSED",
                style: TextStyle(fontSize: 12, color: Colors.white70, fontFamily: 'DM Mono', letterSpacing: 1.2),
              ),
              Text(
                _formatTime(_secondsElapsed),
                style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w800, fontFamily: 'DM Mono', color: Colors.white, letterSpacing: -3, height: 1.1),
              ),
              const SizedBox(height: 8),
              Text(
                "🐛 ${appState.currentTask}", 
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildHeroActionButton(
                    _isPaused ? "Resume" : "Pause",
                    _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    _togglePause,
                  ),
                  const SizedBox(width: 8),
                  _buildQuickBreakBtn("5m break", () => _triggerBreak(InterruptType.userRequested)),
                  const SizedBox(width: 8),
                  _buildQuickBreakBtn("Feeling stuck?", () => _triggerBreak(InterruptType.drift), isWarning: true),
                  const SizedBox(width: 8),
                  _buildHeroActionButton("End session", Icons.check_rounded, widget.onEndSession ?? () {}),
                ],
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroActionButton(String label, IconData icon, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white, size: 18),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      style: TextButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.15),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildQuickBreakBtn(String label, VoidCallback onTap, {bool isWarning = false}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isWarning ? Colors.white.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isWarning ? const Color(0xFF7A2E3A) : Colors.white,
            fontWeight: FontWeight.w600, fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildTelemetryConsole(BuildContext context, AppState appState) {
    final theme = Theme.of(context);
    final isDrifting = appState.isDrifting;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: theme.dividerColor, width: 1)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("LIVE TELEMETRY", style: theme.textTheme.labelMedium),
                Text(
                  '${appState.focusScore} now', 
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.primaryColor, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // ✅ THE SECOND FIREWALL
            RepaintBoundary(
              child: FocusSparkline(scores: _focusHistory, color: theme.primaryColor, height: 60),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMinStat("BPM", "${appState.currentBpm}", theme.textTheme.bodyLarge?.color), 
                _buildMinStat("EAR", "${appState.currentEar}", theme.colorScheme.secondary),      
                _buildMinStat("DRIFT", isDrifting ? "HIGH" : "LOW", isDrifting ? theme.colorScheme.error : theme.primaryColor),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMinStat(String label, String val, Color? color) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color, letterSpacing: -0.5)),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }

  Widget _buildDriftMeterCard(BuildContext context, AppState appState) {
    final theme = Theme.of(context);
    final isDrifting = appState.isDrifting;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDrifting ? theme.colorScheme.error : theme.dividerColor, width: isDrifting ? 2 : 1)
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Drift meter", style: theme.textTheme.labelMedium),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isDrifting ? theme.colorScheme.error : theme.primaryColor).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    isDrifting ? "CRITICAL" : "LOW",
                    style: theme.textTheme.labelLarge?.copyWith(color: isDrifting ? theme.colorScheme.error : theme.primaryColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              height: 10, width: double.infinity,
              decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(8)),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: isDrifting ? 0.85 : 0.14,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      colors: [
                        isDrifting ? theme.colorScheme.error : theme.primaryColor,
                        isDrifting ? Colors.redAccent : theme.colorScheme.secondary
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("ALIGNED", style: theme.textTheme.labelSmall),
                Text(
                  isDrifting ? "85%" : "14%",
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, fontFamily: 'DM Mono', color: isDrifting ? theme.colorScheme.error : theme.primaryColor),
                ),
                Text("DRIFT", style: theme.textTheme.labelSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUltradianCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: theme.dividerColor, width: 1)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Ultradian position", style: theme.textTheme.labelMedium),
            const SizedBox(height: 14),
            Row(
              children: [
                _buildRhythmSegment(context, isTrough: true), const SizedBox(width: 4),
                _buildRhythmSegment(context, isPeak: true), const SizedBox(width: 4),
                _buildRhythmSegment(context, isPeak: true), const SizedBox(width: 4),
                _buildRhythmSegment(context, isCurrent: true), const SizedBox(width: 4),
                _buildRhythmSegment(context, isUpcoming: true), const SizedBox(width: 4),
                _buildRhythmSegment(context, isUpcoming: true),
              ],
            ),
            const SizedBox(height: 10),
            RichText(
              text: TextSpan(
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                children: [
                  const TextSpan(text: "Peak phase — "),
                  TextSpan(text: "~13 min", style: TextStyle(fontWeight: FontWeight.bold, color: theme.primaryColor)),
                  const TextSpan(text: " until recommended break"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRhythmSegment(BuildContext context, {bool isTrough = false, bool isPeak = false, bool isCurrent = false, bool isUpcoming = false}) {
    final theme = Theme.of(context);
    final Color bgColor = isTrough ? theme.colorScheme.secondary.withValues(alpha: 0.6) : (isPeak ? theme.primaryColor : theme.dividerColor);
    final double height = isPeak ? 40 : (isTrough ? 20 : 30);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 24, height: height,
      decoration: BoxDecoration(
        color: isCurrent ? bgColor : bgColor.withValues(alpha: isUpcoming ? 0.3 : 0.7),
        borderRadius: BorderRadius.circular(4),
        border: isCurrent ? Border.all(color: theme.primaryColor, width: 2) : null,
      ),
    );
  }

  Widget _buildFlowStatusCard(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final tintColor = primaryColor.withValues(alpha: 0.15);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: theme.dividerColor, width: 1)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("FLOW STATE", style: theme.textTheme.labelMedium),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: tintColor, shape: BoxShape.circle),
                  child: Icon(Icons.waves_rounded, color: primaryColor, size: 22),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Deep Focus", style: theme.textTheme.headlineSmall?.copyWith(color: primaryColor)),
                    const SizedBox(height: 2),
                    Text("Cognitive load nominal", style: theme.textTheme.bodySmall),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: tintColor, borderRadius: BorderRadius.circular(100)),
                  child: Text("82 / 100", style: theme.textTheme.labelLarge?.copyWith(color: primaryColor)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: 0.82, minHeight: 6, backgroundColor: theme.dividerColor,
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionGoalCard(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final tintColor = primaryColor.withValues(alpha: 0.15);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: theme.dividerColor, width: 1)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("SESSION GOAL", style: theme.textTheme.labelMedium),
                Icon(Icons.flag_rounded, color: primaryColor, size: 18),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: tintColor, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, color: primaryColor, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text("Fix JWT token refresh & write unit tests", style: theme.textTheme.bodyMedium)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: 0.4, minHeight: 5, backgroundColor: theme.dividerColor,
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text("40%", style: theme.textTheme.labelSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}