// lib/screens/active_session_screen.dart
//
// Upgraded vs original:
//   • Meeting countdown pill in the top-right
//   • Focus score sparkline below the telemetry console header
//   • "Take a Break" button (+ duration picker row) lets the user
//     self-initiate a break without waiting for an AI trigger
//   • "Feeling stuck?" chip routes to InterruptScreen(drift)
//   • Session controls moved to a cleaner action strip at the bottom
//   • isDrifting now drives BOTH the ring AND the background (unchanged)

import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../widgets/flow_data_card.dart';
import '../widgets/focus_ring.dart';
import '../widgets/focus_sparkline.dart';
import '../widgets/meeting_countdown_pill.dart';
import 'interrupt_screen.dart';
import 'session_end_screen.dart';

class ActiveSessionScreen extends StatefulWidget {
  const ActiveSessionScreen({super.key});

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> {
  bool isDrifting = false;

  // Demo meeting time — 32 minutes from when the screen opens
  late final DateTime _nextMeeting;

  // Last 8 focus-score readings for the sparkline (demo data)
  final List<double> _focusHistory = [72, 65, 78, 80, 76, 82, 85, 88];

  @override
  void initState() {
    super.initState();
    _nextMeeting = DateTime.now().add(const Duration(minutes: 32));
  }

  void _openInterrupt(InterruptType type) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => InterruptScreen(type: type),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  void _endSession() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const SessionEndScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme    = Theme.of(context);
    final targetBg = isDrifting
        ? FlowTheme.stateColor(context, SessionState.drift)
            .withValues(alpha: 0.05)
        : theme.scaffoldBackgroundColor;

    return AnimatedContainer(
      duration: const Duration(seconds: 1),
      color:    targetBg,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Padding(
          padding: const EdgeInsets.fromLTRB(64, 40, 64, 32),
          child: Column(
            children: [
              // ── Top bar ────────────────────────────────────────────────
              _buildTopBar(theme),
              const SizedBox(height: 32),

              // ── Main content ───────────────────────────────────────────
              Expanded(
                child: Row(
                  children: [
                    Expanded(flex: 5, child: _buildFocusCore(theme)),
                    const SizedBox(width: 64),
                    Expanded(flex: 4, child: _buildTelemetryConsole(theme)),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Break strip ────────────────────────────────────────────
              _buildBreakStrip(theme),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar(ThemeData theme) {
    return Row(
      children: [
        // Back (returns to AppShell but keeps session "running")
        IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: theme.textTheme.labelSmall?.color),
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ACTIVE SESSION', style: theme.textTheme.labelSmall),
            Text('Debugging auth module',
                style: theme.textTheme.headlineSmall),
          ],
        ),
        const Spacer(),

        // Meeting countdown pill
        MeetingCountdownPill(
          nextMeetingTime: _nextMeeting,
          meetingTitle:    'Team standup',
        ),
        const SizedBox(width: 16),

        // End session
        OutlinedButton.icon(
          icon:  const Icon(Icons.stop_rounded, size: 16),
          label: const Text('End session'),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.textTheme.labelSmall?.color,
            side:            BorderSide(color: theme.dividerColor),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _endSession,
        ),
      ],
    );
  }

  // ── Focus core (left) ──────────────────────────────────────────────────────

  Widget _buildFocusCore(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FocusRing(
          progress:   0.68,
          timeString: '28:14',
          isDrifting: isDrifting,
        ),
        const SizedBox(height: 40),
        Text('ACTIVE PROTOCOL', style: theme.textTheme.labelSmall),
        const SizedBox(height: 8),
        Text('Debugging auth module',
            style: theme.textTheme.headlineLarge),
        const SizedBox(height: 20),

        // ── Feeling stuck? chip ──────────────────────────────────────
        GestureDetector(
          onTap: () => _openInterrupt(InterruptType.drift),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: theme.dividerColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.help_outline_rounded,
                    size: 14,
                    color: theme.textTheme.labelSmall?.color),
                const SizedBox(width: 8),
                Text('Feeling stuck?',
                    style: theme.textTheme.labelSmall),
              ],
            ),
          ),
        ),

        // Debug toggle (same as original FAB, now a chip)
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => setState(() => isDrifting = !isDrifting),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color:        theme.colorScheme.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                  color: theme.colorScheme.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bug_report_rounded,
                    size: 12, color: theme.colorScheme.error),
                const SizedBox(width: 6),
                Text('Toggle drift (demo)',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.error)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Telemetry console (right) ──────────────────────────────────────────────

  Widget _buildTelemetryConsole(ThemeData theme) {
    return FlowDataCard(
      padding: EdgeInsets.zero,
      child:   Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header + sparkline
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('LIVE TELEMETRY',
                    style: theme.textTheme.labelSmall),
                Row(
                  children: [
                    Container(
                      width:  8, height: 8,
                      decoration: BoxDecoration(
                        color: theme.primaryColor, shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('LIVE',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.primaryColor)),
                  ],
                ),
              ],
            ),
          ),

          // Focus score sparkline
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('FOCUS TREND',
                        style: theme.textTheme.labelSmall),
                    Text('82 now',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.primaryColor)),
                  ],
                ),
                const SizedBox(height: 8),
                FocusSparkline(
                  scores: _focusHistory,
                  color:  theme.primaryColor,
                  height: 52,
                ),
              ],
            ),
          ),

          const Divider(),

          // Telemetry rows
          _buildTelemetryRow('HEART RATE',  '74',   'BPM',       theme),
          const Divider(),
          _buildTelemetryRow('EYE ASPECT',  '0.28', 'EAR',       theme),
          const Divider(),
          _buildTelemetryRow('COGNITIVE',   '0.25', 'SIGNAL',    theme),
          const Divider(),
          _buildTelemetryRow('DRIFT SCORE', '14%',  'LOW',       theme,
              highlight: !isDrifting),
        ],
      ),
    );
  }

  Widget _buildTelemetryRow(
    String label, String value, String unit, ThemeData theme,
    {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline:       TextBaseline.alphabetic,
            children: [
              Text(value,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontFeatures: [const FontFeature.tabularFigures()],
                    color: highlight ? theme.primaryColor : null,
                  )),
              const SizedBox(width: 8),
              Text(unit, style: theme.textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }

  // ── Break strip (bottom) ───────────────────────────────────────────────────

  Widget _buildBreakStrip(ThemeData theme) {
    final fatigueColor =
        FlowTheme.stateColor(context, SessionState.trough);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: BoxDecoration(
        color:        theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          // Left: label
          Icon(Icons.self_improvement_rounded,
              color: fatigueColor, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize:       MainAxisSize.min,
            children: [
              Text('Take a break?',
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
              Text('Your rhythm suggests a break in ~13 min',
                  style: theme.textTheme.bodyMedium),
            ],
          ),
          const Spacer(),

          // Quick-pick duration buttons
          ...([5, 10, 15].map((min) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: fatigueColor,
                    side: BorderSide(
                        color: fatigueColor.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => InterruptScreen(
                          type: InterruptType.userRequested,
                        ),
                        transitionsBuilder: (_, anim, __, child) =>
                            FadeTransition(opacity: anim, child: child),
                      ),
                    );
                  },
                  child: Text('$min min',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ))),

          const SizedBox(width: 8),

          // Full interrupt screen
          ElevatedButton.icon(
            icon:  Icon(Icons.pause_rounded, size: 16, color: Colors.white),
            label: const Text('Custom break',
                style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: fatigueColor,
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () => _openInterrupt(InterruptType.userRequested),
          ),
        ],
      ),
    );
  }
}