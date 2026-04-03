// lib/widgets/meeting_countdown_pill.dart
//
// A self-ticking pill that shows the time until the next Google Calendar event.
// Pass [nextMeetingTime] (UTC) and it counts down in real-time.
// Colour shifts: green → amber when ≤ 15 min, red pulse when ≤ 5 min.
//
// Placement: top-right of dashboard and active-session headers.

import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme.dart';

class MeetingCountdownPill extends StatefulWidget {
  /// The absolute DateTime of the upcoming meeting (use DateTime.now().add(...) for demo).
  final DateTime nextMeetingTime;
  final String   meetingTitle;

  const MeetingCountdownPill({
    super.key,
    required this.nextMeetingTime,
    this.meetingTitle = 'Team standup',
  });

  @override
  State<MeetingCountdownPill> createState() => _MeetingCountdownPillState();
}

class _MeetingCountdownPillState extends State<MeetingCountdownPill>
    with SingleTickerProviderStateMixin {
  late Timer               _ticker;
  Duration                 _remaining = Duration.zero;
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(_pulseCtrl);

    _update();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  void _update() {
    final remaining = widget.nextMeetingTime.difference(DateTime.now());
    if (mounted) setState(() => _remaining = remaining.isNegative ? Duration.zero : remaining);
  }

  @override
  void dispose() {
    _ticker.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final isDark  = theme.brightness == Brightness.dark;
    final minutes = _remaining.inMinutes;

    // Colour logic
    final Color pillColor;
    final Color textColor;
    final IconData icon;
    final bool   doPulse;

    if (minutes <= 5 && minutes >= 0) {
      // URGENT — red
      pillColor = isDark ? FlowTheme.driftDark : FlowTheme.driftLight;
      textColor = Colors.white;
      icon      = Icons.warning_amber_rounded;
      doPulse   = true;
    } else if (minutes <= 15) {
      // WARNING — amber/copper
      pillColor = (isDark ? FlowTheme.fatigueDark : FlowTheme.fatigueLight)
          .withValues(alpha: 0.15);
      textColor = isDark ? FlowTheme.fatigueDark : FlowTheme.fatigueLight;
      icon      = Icons.schedule_rounded;
      doPulse   = false;
    } else {
      // OK — olive/green
      pillColor = theme.primaryColor.withValues(alpha: 0.1);
      textColor = theme.primaryColor;
      icon      = Icons.event_rounded;
      doPulse   = false;
    }

    Widget pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color:        pillColor,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 8),
          Text(
            '${widget.meetingTitle}  ·  ${_fmt(_remaining)}',
            style: theme.textTheme.labelSmall?.copyWith(
              color:       textColor,
              fontWeight:  FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );

    if (doPulse) {
      pill = AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, child) => Opacity(opacity: _pulseAnim.value, child: child),
        child: pill,
      );
    }

    return pill;
  }
}