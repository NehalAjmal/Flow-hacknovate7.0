// lib/screens/dashboard_screen.dart
//
import 'dart:math' as math;
// Upgrades vs original:
//   • Skeleton loading state shown for 1.8 s on first mount (simulates API fetch)
//   • CountUpText on FOCUS SCORE and all large numeric stats
//   • MeetingCountdownPill in the top-right header
//   • AnimatedFocusRingEntry replaces the plain stat block for the focus score
//     (the ring draws itself in on every dashboard visit)
//   • All other structure preserved exactly

import 'dart:ui';
import 'package:flutter/material.dart';
import '../widgets/flow_data_card.dart';
import '../widgets/count_up_text.dart';
import '../widgets/meeting_countdown_pill.dart';
import '../widgets/skeleton_loader.dart';
import 'active_session_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;

  // Demo meeting: 28 minutes from now
  late final DateTime _nextMeeting;

  // Animated focus ring entry
  late AnimationController _ringEntry;
  late Animation<double>   _ringAnim;

  @override
  void initState() {
    super.initState();
    _nextMeeting = DateTime.now().add(const Duration(minutes: 28));

    _ringEntry = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1300),
    );
    _ringAnim = CurvedAnimation(
      parent: _ringEntry,
      curve:  Curves.easeOutCubic,
    );

    // Simulate data load then reveal
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() => _loading = false);
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
    if (_loading) return const DashboardSkeleton();

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(48.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ────────────────────────────────────────────────────
          Row(
            mainAxisAlignment:  MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MOHAMMAD AMAAN',
                      style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text('CONSOLE ACTIVE',
                      style: theme.textTheme.displayMedium),
                ],
              ),
              Row(
                children: [
                  // Meeting pill
                  MeetingCountdownPill(
                    nextMeetingTime: _nextMeeting,
                    meetingTitle:    'Team standup',
                  ),
                  const SizedBox(width: 16),
                  // Status badge (unchanged)
                  _buildStatusBadge(theme),
                ],
              ),
            ],
          ),
          const SizedBox(height: 40),

          // ── Main grid ─────────────────────────────────────────────────
          Expanded(
            child: Row(
              children: [
                Expanded(flex: 5, child: _buildTelemetryGrid(theme)),
                const SizedBox(width: 24),
                Expanded(flex: 3, child: _buildActionModule(context, theme)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Timeline bar ──────────────────────────────────────────────
          _buildTimelineBar(theme),
        ],
      ),
    );
  }

  // ── Widgets ────────────────────────────────────────────────────────────────

  Widget _buildStatusBadge(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color:        theme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(
            color: theme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width:  8, height: 8,
            decoration: BoxDecoration(
                color: theme.primaryColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Text('PEAK WINDOW OPEN',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.primaryColor)),
        ],
      ),
    );
  }

  Widget _buildTelemetryGrid(ThemeData theme) {
    return FlowDataCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                // ── Focus score with animated ring + count-up ──────────
                Expanded(child: _buildAnimatedFocusBlock(theme)),
                const VerticalDivider(),
                // ── Rhythm with count-up ───────────────────────────────
                Expanded(
                  child: _buildCountUpBlock(
                    label: 'RHYTHM POS',
                    target: 62,
                    suffix: 'm',
                    theme: theme,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _buildCountUpBlock(
                      label: 'BPM', target: 71, theme: theme,
                      isSmall: true),
                ),
                const VerticalDivider(),
                Expanded(
                  child: _buildCountUpBlock(
                      label: 'HRV', target: 41, suffix: 'ms',
                      theme: theme, isSmall: true),
                ),
                const VerticalDivider(),
                // EAR is a decimal — keep as plain text
                Expanded(
                  child: _buildStatBlock('EAR', '0.31', theme,
                      isSmall: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Focus score block — ring draws in, number counts up
  Widget _buildAnimatedFocusBlock(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('FOCUS SCORE', style: theme.textTheme.labelSmall),
          const SizedBox(height: 10),
          // Row: count-up number + mini animated arc
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CountUpText(
                target: 74,
                suffix: '%',
                style: theme.textTheme.displayLarge?.copyWith(
                  fontFeatures: [const FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              // Mini arc ring
              AnimatedBuilder(
                animation: _ringAnim,
                builder: (_, __) => SizedBox(
                  width: 52, height: 52,
                  child: CustomPaint(
                    painter: _MiniRingPainter(
                      progress: 0.74 * _ringAnim.value,
                      color:    theme.primaryColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Generic count-up stat block
  Widget _buildCountUpBlock({
    required String label,
    required int target,
    String suffix = '',
    required ThemeData theme,
    bool isSmall = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: 8),
          CountUpText(
            target: target,
            suffix: suffix,
            style: (isSmall
                    ? theme.textTheme.displayMedium
                    : theme.textTheme.displayLarge)
                ?.copyWith(
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBlock(
      String label, String value, ThemeData theme,
      {bool isSmall = false}) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: 8),
          Text(
            value,
            style: (isSmall
                    ? theme.textTheme.displayMedium
                    : theme.textTheme.displayLarge)
                ?.copyWith(
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionModule(BuildContext context, ThemeData theme) {
    return FlowDataCard(
      backgroundColor: theme.primaryColor.withValues(alpha: 0.05),
      borderColor:     theme.primaryColor.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('REQUIRED ACTION',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.primaryColor)),
          const Spacer(),
          Text('INITIALIZE',
              style: theme.textTheme.displayMedium),
          Text('DEEP WORK',
              style: theme.textTheme.displayMedium
                  ?.copyWith(color: theme.primaryColor)),
          const SizedBox(height: 8),
          Text('90 minute optimized block.',
              style: theme.textTheme.bodyMedium),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ActiveSessionScreen()),
              ),
              child: const Text('START PROTOCOL'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineBar(ThemeData theme) {
    return FlowDataCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          Text('TIMELINE', style: theme.textTheme.labelSmall),
          const SizedBox(width: 32),
          Expanded(
            child: Container(
              height:     4,
              decoration: BoxDecoration(
                  color:        theme.dividerColor,
                  borderRadius: BorderRadius.circular(2)),
              child: AnimatedBuilder(
                animation: _ringAnim,
                builder: (_, __) => FractionallySizedBox(
                  alignment:   Alignment.centerLeft,
                  widthFactor: 0.45 * _ringAnim.value,
                  child: Container(
                    decoration: BoxDecoration(
                        color:        theme.primaryColor,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 32),
          Text('2H 47M LOGGED', style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

// ── Mini arc ring painter ─────────────────────────────────────────────────────

class _MiniRingPainter extends CustomPainter {
  final double progress;
  final Color  color;
  _MiniRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;

    canvas.drawCircle(
      center, radius,
      Paint()
        ..color       = color.withValues(alpha: 0.12)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color       = color
        ..style       = PaintingStyle.stroke
        ..strokeCap   = StrokeCap.round
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_MiniRingPainter old) => old.progress != progress;
}