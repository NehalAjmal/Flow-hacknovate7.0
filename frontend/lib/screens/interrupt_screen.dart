import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme.dart';

enum InterruptType { fatigue, drift, ultradianBreak, userRequested }

class InterruptScreen extends StatefulWidget {
  final InterruptType type;
  const InterruptScreen({super.key, required this.type});

  @override
  State<InterruptScreen> createState() => _InterruptScreenState();
}

class _InterruptScreenState extends State<InterruptScreen> with TickerProviderStateMixin {
  int _selectedMinutes = 5;
  bool _timerStarted = false;
  int _secondsLeft = 0;
  Timer? _countdownTimer;
  late AnimationController _breatheCtrl;
  late Animation<double> _breatheAnim;
  late AnimationController _entryCtrl;
  late Animation<double> _entryAnim;

  @override
  void initState() {
    super.initState();
    _selectedMinutes = switch (widget.type) {
      InterruptType.fatigue => 5,
      InterruptType.ultradianBreak => 10,
      InterruptType.drift => 5,
      InterruptType.userRequested => 5,
    };
    _breatheCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 4000))..repeat(reverse: true);
    _breatheAnim = CurvedAnimation(parent: _breatheCtrl, curve: Curves.easeInOut);
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..forward();
    _entryAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _breatheCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  void _startBreak() {
    setState(() { _timerStarted = true; _secondsLeft = _selectedMinutes * 60; });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) { t.cancel(); _onBreakComplete(); }
      });
    });
  }

  void _onBreakComplete() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Break complete ✓', style: Theme.of(context).textTheme.headlineMedium),
        content: Text('Ready to resume your session?', style: Theme.of(context).textTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context); },
            child: Text('Resume session →', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _formatCountdown(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  _InterruptCopy get _copyConfig {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return switch (widget.type) {
      InterruptType.fatigue => _InterruptCopy(
        icon: Icons.battery_alert_rounded,
        color: isDark ? FlowTheme.fatigueDark : FlowTheme.fatigueLight,
        title: 'Your brain needs a reset',
        message: "You've been in deep focus for a while — your cognitive reserves are depleting. A break now will buy you 45 more minutes of quality work.",
        tag: 'AI DETECTED — FATIGUE',
      ),
      InterruptType.drift => _InterruptCopy(
        icon: Icons.cloud_off_rounded,
        color: isDark ? FlowTheme.driftDark : FlowTheme.driftLight,
        title: "You've drifted from your intention",
        message: "Context drift is normal. Noticing it is the skill. FLOW paused your session to help you reset and return intentionally.",
        tag: 'AI DETECTED — DRIFT',
      ),
      InterruptType.ultradianBreak => _InterruptCopy(
        icon: Icons.waves_rounded,
        color: isDark ? FlowTheme.primaryDark : FlowTheme.primaryLight,
        title: 'Natural break point reached',
        message: "You've completed a full ultradian focus cycle. This is the ideal moment for a 10–15 min break — not too early, not too late.",
        tag: 'ULTRADIAN RHYTHM',
      ),
      InterruptType.userRequested => _InterruptCopy(
        icon: Icons.self_improvement_rounded,
        color: isDark ? FlowTheme.primaryDark : FlowTheme.primaryLight,
        title: 'Taking a break',
        message: "Good call. Step away, let your visual focus relax, and come back fresh. FLOW will keep your session warm.",
        tag: 'USER INITIATED',
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = _copyConfig;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: AnimatedBuilder(
        animation: _entryAnim,
        builder: (context, child) => Opacity(
          opacity: _entryAnim.value,
          child: Transform.translate(offset: Offset(0, 20 * (1 - _entryAnim.value)), child: child),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Center(
                child: AnimatedBuilder(
                  animation: _breatheAnim,
                  builder: (context, child) => _BreathingRing(
                    color: copy.color,
                    breatheValue: _breatheAnim.value,
                    timerStarted: _timerStarted,
                    secondsLeft: _secondsLeft,
                    totalSeconds: _selectedMinutes * 60,
                    formatTime: _formatCountdown,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(64),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: copy.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: copy.color.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(copy.icon, size: 14, color: copy.color),
                          const SizedBox(width: 8),
                          Text(copy.tag, style: theme.textTheme.labelSmall?.copyWith(color: copy.color)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(copy.title, style: theme.textTheme.headlineLarge?.copyWith(height: 1.2)),
                    const SizedBox(height: 16),
                    Text(copy.message, style: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
                    const SizedBox(height: 40),
                    if (!_timerStarted) ...[
                      Text('HOW LONG?', style: theme.textTheme.labelSmall),
                      const SizedBox(height: 12),
                      Row(
                        children: [5, 10, 15, 20].map((min) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: _DurationButton(
                              label: '$min min',
                              isSelected: _selectedMinutes == min,
                              baseColor: copy.color,
                              theme: theme,
                              onTap: () => setState(() => _selectedMinutes = min),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: copy.color,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _startBreak,
                          child: const Text('Start Break', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Dismiss and resume session', style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
                        ),
                      ),
                    ] else ...[
                      Text('BREAK IN PROGRESS', style: theme.textTheme.labelSmall),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.stop_rounded, size: 18),
                        label: const Text('End break early'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: copy.color,
                          side: BorderSide(color: copy.color.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreathingRing extends StatelessWidget {
  final Color color;
  final double breatheValue;
  final bool timerStarted;
  final int secondsLeft;
  final int totalSeconds;
  final String Function(int) formatTime;

  const _BreathingRing({
    required this.color, required this.breatheValue, required this.timerStarted,
    required this.secondsLeft, required this.totalSeconds, required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    final progress = timerStarted ? 1.0 - (secondsLeft / totalSeconds) : 0.0;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 380, height: 380,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1 + breatheValue * 0.1), blurRadius: 80, spreadRadius: 20 + breatheValue * 40)],
          ),
        ),
        CustomPaint(
          size: const Size(380, 380),
          painter: _BreathRingPainter(color: color, progress: progress, breathe: breatheValue),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              timerStarted ? formatTime(secondsLeft) : formatTime(totalSeconds),
              style: TextStyle(fontSize: 72, fontWeight: FontWeight.w800, color: color, fontFamily: 'DM Mono', letterSpacing: -2),
            ),
            if (timerStarted)
              Text('REMAINING', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
          ],
        ),
      ],
    );
  }
}

class _BreathRingPainter extends CustomPainter {
  final Color color;
  final double progress;
  final double breathe;
  _BreathRingPainter({required this.color, required this.progress, required this.breathe});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 24;
    final strokeWidth = 8.0 + (breathe * 4.0);
    canvas.drawCircle(center, radius,
        Paint()..color = color.withValues(alpha: 0.12)..style = PaintingStyle.stroke..strokeWidth = strokeWidth);
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, 2 * math.pi * progress.clamp(0.0, 1.0), false,
        Paint()..color = color..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeWidth = strokeWidth,
      );
    }
  }

  @override
  bool shouldRepaint(_BreathRingPainter old) => old.progress != progress || old.breathe != breathe;
}

class _DurationButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color baseColor;
  final ThemeData theme;
  final VoidCallback onTap;
  const _DurationButton({required this.label, required this.isSelected, required this.baseColor, required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? baseColor.withValues(alpha: 0.12) : Colors.transparent,
          border: Border.all(color: isSelected ? baseColor : theme.dividerColor, width: isSelected ? 1.5 : 1.0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(
          color: isSelected ? baseColor : theme.textTheme.labelSmall?.color,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
        )),
      ),
    );
  }
}

class _InterruptCopy {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String tag;
  _InterruptCopy({required this.icon, required this.color, required this.title, required this.message, required this.tag});
}