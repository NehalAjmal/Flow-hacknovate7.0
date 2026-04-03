// lib/screens/interrupt_screen.dart
//
// Shown as a full-screen overlay (pushed over ActiveSessionScreen) when
// FLOW detects fatigue / drift / ultradian break / or the user presses "Take a Break".
//
// The user picks a break duration (5 / 10 / 15 / 20 min or custom),
// then a countdown begins with a breathing animation ring.
// On completion the screen pops and the session resumes.
//
// Navigation:
//   Navigator.push(context, MaterialPageRoute(builder: (_) => const InterruptScreen(
//     type: InterruptType.fatigue,    // or drift / ultradianBreak / userRequested
//   )));

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../widgets/flow_data_card.dart';

// ─── Interrupt type ───────────────────────────────────────────────────────────

enum InterruptType {
  fatigue,        // AI-detected physiological fatigue
  drift,          // Context-drift / attention wandering
  ultradianBreak, // Natural ultradian cycle break point
  userRequested,  // User pressed "Take a Break" manually
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class InterruptScreen extends StatefulWidget {
  final InterruptType type;
  const InterruptScreen({super.key, required this.type});

  @override
  State<InterruptScreen> createState() => _InterruptScreenState();
}

class _InterruptScreenState extends State<InterruptScreen>
    with TickerProviderStateMixin {
  // Break duration selection
  int  _selectedMinutes = 5;
  bool _timerStarted    = false;
  int  _secondsLeft     = 0;
  Timer? _countdownTimer;

  // Breathing ring animation
  late AnimationController _breatheCtrl;
  late Animation<double>   _breatheAnim;

  // Entry animation
  late AnimationController _entryCtrl;
  late Animation<double>   _entryAnim;

  @override
  void initState() {
    super.initState();

    // Default duration per type
    _selectedMinutes = switch (widget.type) {
      InterruptType.fatigue        => 5,
      InterruptType.ultradianBreak => 10,
      InterruptType.drift          => 5,
      InterruptType.userRequested  => 5,
    };

    _breatheCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 4000),
    )..repeat(reverse: true);
    _breatheAnim = CurvedAnimation(parent: _breatheCtrl, curve: Curves.easeInOut);

    _entryCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 500),
    )..forward();
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
    setState(() {
      _timerStarted = true;
      _secondsLeft  = _selectedMinutes * 60;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          t.cancel();
          _onBreakComplete();
        }
      });
    });
  }

  void _onBreakComplete() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Break complete ✓',
            style: Theme.of(context).textTheme.headlineMedium),
        content: Text('Ready to resume your session?',
            style: Theme.of(context).textTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // return to session
            },
            child: Text('Resume session →',
                style: TextStyle(color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _fmtCountdown(int s) {
    final m = s ~/ 60;
    final r = s % 60;
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }

  // ─── Type-specific copy ────────────────────────────────────────────────────

  _InterruptCopy get _copy {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return switch (widget.type) {
      InterruptType.fatigue => _InterruptCopy(
        icon:    Icons.battery_alert_rounded,
        color:   isDark ? FlowTheme.fatigueDark : FlowTheme.fatigueLight,
        title:   'Your brain needs a reset',
        message: "You've been in deep focus for a while — your cognitive reserves are depleting. A break now will buy you 45 more minutes of quality work.",
        tag:     'AI DETECTED — FATIGUE',
      ),
      InterruptType.drift => _InterruptCopy(
        icon:    Icons.cloud_off_rounded,
        color:   isDark ? FlowTheme.driftDark : FlowTheme.driftLight,
        title:   "You've drifted from your intention",
        message: "Context drift is normal. Noticing it is the skill. FLOW paused your session to help you reset and return intentionally.",
        tag:     'AI DETECTED — DRIFT',
      ),
      InterruptType.ultradianBreak => _InterruptCopy(
        icon:    Icons.waves_rounded,
        color:   isDark ? FlowTheme.primaryDark : FlowTheme.primaryLight,
        title:   'Natural break point reached',
        message: "You've completed a full ultradian focus cycle. This is the ideal moment for a 10–15 min break — not too early, not too late.",
        tag:     'ULTRADIAN RHYTHM',
      ),
      InterruptType.userRequested => _InterruptCopy(
        icon:    Icons.self_improvement_rounded,
        color:   isDark ? FlowTheme.primaryDark : FlowTheme.primaryLight,
        title:   'Taking a break',
        message: "Good call. Step away, let your visual focus relax, and come back fresh. FLOW will keep your session warm.",
        tag:     'USER INITIATED',
      ),
    };
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy  = _copy;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: AnimatedBuilder(
        animation: _entryAnim,
        builder: (_, child) => Opacity(
          opacity: _entryAnim.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - _entryAnim.value)),
            child: child,
          ),
        ),
        child: Row(
          children: [
            // ── Left — breathing ring ──────────────────────────────────────
            Expanded(
              flex: 5,
              child: Center(
                child: AnimatedBuilder(
                  animation: _breatheAnim,
                  builder: (_, __) => _BreathingRing(
                    color:        copy.color,
                    breathe:      _breatheAnim.value,
                    timerStarted: _timerStarted,
                    secondsLeft:  _secondsLeft,
                    totalSeconds: _selectedMinutes * 60,
                    fmt:          _fmtCountdown,
                  ),
                ),
              ),
            ),

            // ── Right — controls ──────────────────────────────────────────
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(64),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tag
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: copy.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: copy.color.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(copy.icon, size: 14, color: copy.color),
                          const SizedBox(width: 8),
                          Text(copy.tag,
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: copy.color)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title
                    Text(copy.title,
                        style: theme.textTheme.headlineLarge
                            ?.copyWith(height: 1.2)),
                    const SizedBox(height: 16),

                    // Message
                    Text(copy.message,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(height: 1.6)),
                    const SizedBox(height: 40),

                    // ── Duration picker ──────────────────────────────────
                    if (!_timerStarted) ...[
                      Text('HOW LONG?',
                          style: theme.textTheme.labelSmall),
                      const SizedBox(height: 12),
                      Row(
                        children: [5, 10, 15, 20].map((min) {
                          final sel = _selectedMinutes == min;
                          return Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: _DurBtn(
                              label:      '$min min',
                              selected:   sel,
                              color:      copy.color,
                              theme:      theme,
                              onTap:      () => setState(
                                  () => _selectedMinutes = min),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 32),

                      // ── Start break button ───────────────────────────
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: copy.color,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          onPressed: _startBreak,
                          child: Text(
                            'Start $_selectedMinutes-min break',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Skip / dismiss ───────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                theme.textTheme.labelSmall?.color,
                            side: BorderSide(color: theme.dividerColor),
                            padding:
                                const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Skip break — return to session'),
                        ),
                      ),
                    ],

                    // ── Active countdown controls ─────────────────────
                    if (_timerStarted) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                theme.textTheme.labelSmall?.color,
                            side: BorderSide(color: theme.dividerColor),
                            padding:
                                const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('End break early — resume session'),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Break tip
                    FlowDataCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lightbulb_outline_rounded,
                              color: theme.primaryColor, size: 18),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _breakTip,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _breakTip => switch (widget.type) {
    InterruptType.fatigue =>
      'Walk to a window. Let your visual focus go to infinity for 20 seconds. It genuinely helps reset the visual cortex.',
    InterruptType.drift =>
      'Before you return: write one sentence about exactly what you were trying to accomplish. Re-anchor your intention.',
    InterruptType.ultradianBreak =>
      'Your next cycle will be stronger if you fully disengage now. Avoid screens and work-related thoughts.',
    InterruptType.userRequested =>
      'Stretch, hydrate, or take 5 slow breaths. Physical micro-recovery directly improves cognitive performance.',
  };
}

// ─── Breathing ring ───────────────────────────────────────────────────────────

class _BreathingRing extends StatelessWidget {
  final Color    color;
  final double   breathe;
  final bool     timerStarted;
  final int      secondsLeft;
  final int      totalSeconds;
  final String Function(int) fmt;

  const _BreathingRing({
    required this.color,
    required this.breathe,
    required this.timerStarted,
    required this.secondsLeft,
    required this.totalSeconds,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final theme    = Theme.of(context);
    final ringSize = 320.0;
    final progress = timerStarted && totalSeconds > 0
        ? secondsLeft / totalSeconds
        : (0.5 + breathe * 0.5); // breathing fill when not started

    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow
        Container(
          width:  ringSize + 60,
          height: ringSize + 60,
          decoration: BoxDecoration(
            shape:      BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color:       color.withValues(alpha: 0.08 + breathe * 0.08),
                blurRadius:  80,
                spreadRadius: 20,
              ),
            ],
          ),
        ),
        // Ring
        CustomPaint(
          size:    Size(ringSize, ringSize),
          painter: _BreathRingPainter(
            color:    color,
            progress: progress,
            breathe:  breathe,
          ),
        ),
        // Center text
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!timerStarted) ...[
              Text(
                'Breathe',
                style: theme.textTheme.displayMedium?.copyWith(
                  color:       color,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                breathe > 0.5 ? 'inhale...' : 'exhale...',
                style: theme.textTheme.labelSmall?.copyWith(
                  color:         color.withValues(alpha: 0.7),
                  letterSpacing: 3,
                ),
              ),
            ] else ...[
              Text(
                fmt(secondsLeft),
                style: theme.textTheme.displayLarge?.copyWith(
                  fontSize:      64,
                  letterSpacing: -2,
                  fontWeight:    FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'break remaining',
                style: theme.textTheme.labelSmall
                    ?.copyWith(letterSpacing: 2),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _BreathRingPainter extends CustomPainter {
  final Color  color;
  final double progress;
  final double breathe;

  _BreathRingPainter({
    required this.color,
    required this.progress,
    required this.breathe,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center     = Offset(size.width / 2, size.height / 2);
    final radius     = (size.width / 2) - 24;
    final strokeWidth = 8.0 + breathe * 4;

    // Track
    canvas.drawCircle(
      center, radius,
      Paint()
        ..color       = color.withValues(alpha: 0.12)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..color       = color
        ..style       = PaintingStyle.stroke
        ..strokeCap   = StrokeCap.round
        ..strokeWidth = strokeWidth,
    );
  }

  @override
  bool shouldRepaint(_BreathRingPainter old) =>
      old.progress != progress || old.breathe != breathe;
}

// ─── Duration button ──────────────────────────────────────────────────────────

class _DurBtn extends StatelessWidget {
  final String   label;
  final bool     selected;
  final Color    color;
  final ThemeData theme;
  final VoidCallback onTap;

  const _DurBtn({
    required this.label,
    required this.selected,
    required this.color,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap:        onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:     const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration:  BoxDecoration(
          color:        selected ? color.withValues(alpha: 0.12) : Colors.transparent,
          border:       Border.all(
              color: selected ? color : theme.dividerColor,
              width: selected ? 1.5 : 1.0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color:      selected ? color : theme.textTheme.labelSmall?.color,
            fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ─── Copy data class ──────────────────────────────────────────────────────────

class _InterruptCopy {
  final IconData icon;
  final Color    color;
  final String   title;
  final String   message;
  final String   tag;

  _InterruptCopy({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    required this.tag,
  });
}