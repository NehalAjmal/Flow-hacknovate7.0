import 'dart:async';
import 'package:flutter/material.dart';

/// Shows a countdown pill to the next meeting, e.g. "Team standup · 14m"
class MeetingCountdownPill extends StatefulWidget {
  final DateTime nextMeetingTime;
  final String meetingTitle;

  const MeetingCountdownPill({
    super.key,
    required this.nextMeetingTime,
    required this.meetingTitle,
  });

  @override
  State<MeetingCountdownPill> createState() => _MeetingCountdownPillState();
}

class _MeetingCountdownPillState extends State<MeetingCountdownPill> {
  late Timer _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.nextMeetingTime.difference(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {
          _remaining = widget.nextMeetingTime.difference(DateTime.now());
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String get _label {
    if (_remaining.isNegative) return widget.meetingTitle;
    final minutes = _remaining.inMinutes;
    if (minutes < 60) return '${widget.meetingTitle} · ${minutes}m';
    final hours = _remaining.inHours;
    return '${widget.meetingTitle} · ${hours}h ${minutes % 60}m';
  }

  bool get _isUrgent => !_remaining.isNegative && _remaining.inMinutes <= 10;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = _isUrgent
        ? theme.colorScheme.errorContainer
        : (isDark
            ? const Color(0xFF1E3028) // primaryTintDark
            : const Color(0xFFE6EFE8)); // primaryTintLight

    final textColor = _isUrgent
        ? theme.colorScheme.error
        : theme.primaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: textColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isUrgent ? Icons.alarm_rounded : Icons.calendar_today_rounded,
            size: 13,
            color: textColor,
          ),
          const SizedBox(width: 6),
          Text(
            _label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
              fontFamily: 'DM Mono',
            ),
          ),
        ],
      ),
    );
  }
}