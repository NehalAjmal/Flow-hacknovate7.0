import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/models/agent.dart';
import '../api/models/consent.dart';
import '../api/models/session.dart';
import '../router/routes.dart';
import '../state/account_controllers.dart';
import '../state/auth_controller.dart';
import '../state/data_providers.dart';
import '../state/session_controller.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import '../ui/brand/wordmark.dart';
import '../ui/dial.dart';
import '../ui/feature_note.dart';
import '../ui/kit.dart';
import '../desktop/window_controller.dart';
import '../ui/nudge_card.dart';
import '../ui/nudge_style.dart';
import '../widgets/common.dart';
import 'auth_layout.dart';
import 'auth_screens.dart';

/// Welcome guide (DESIGN_SPEC §5): six steps, ~2 minutes. A centred column
/// (max 560 px), six progress dots that press in, Back / Next / Skip setup.
/// Steps slide horizontally on one spring that carries velocity, so quick
/// Next-Next-Back reverses smoothly. Step 2 (behavior consent) is required:
/// neither Next nor Skip passes it until behavior sensing is granted.
/// Also reachable from Settings › Help as /guide.
class GuideScreen extends ConsumerStatefulWidget {
  const GuideScreen({super.key});
  @override
  ConsumerState<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends ConsumerState<GuideScreen> with SingleTickerProviderStateMixin {
  static const steps = 6;
  late final _pos = SpringValue(vsync: this, initial: 0);
  int _i = 0;
  int _minutes = 50;
  bool _starting = false;

  @override
  void dispose() {
    _pos.dispose();
    super.dispose();
  }

  bool get _consentOk => ref.read(consentProvider).value?.canUseFlow ?? false;

  bool _canLeave(int step) => step != 1 || _consentOk;

  void _go(int i) {
    if (i < 0 || i >= steps) return;
    if (i > _i && !_canLeave(_i)) return;
    setState(() => _i = i);
    _pos.animateTo(i.toDouble(), spring: Motion.settle, reduced: Motion.reduced(context));
  }

  void _finish() {
    if (!_consentOk) return _go(1);
    context.go(Routes.home);
  }

  Future<void> _startFirst() async {
    if (!_consentOk) return _go(1);
    setState(() => _starting = true);
    final ok = await runGuarded(
      context,
      () => ref
          .read(liveSessionProvider.notifier)
          .start(StartSessionRequest(taskText: '', demand: Demand.moderate, plannedMinutes: _minutes, shareTaskWithLlm: false)),
    );
    if (!mounted) return;
    setState(() => _starting = false);
    if (ok) context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    ref.watch(consentProvider); // rebuild Next/Skip when consent changes
    final pages = <Widget>[
      const _WhatFlowDoes(),
      const _Consent(),
      const _Agent(),
      const _NudgeStyle(),
      const _Practice(),
      _Start(minutes: _minutes, onMinutes: (m) => setState(() => _minutes = m), busy: _starting, onStart: _startFirst, onExplore: _finish),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  const FlowWordmark(capHeight: 18),
                  const Spacer(),
                  if (_i < steps - 1) AuthLink('Skip setup', onPressed: _consentOk ? _finish : () => _go(1)),
                  AuthLink('Sign out', onPressed: () => ref.read(authProvider.notifier).logout()),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  final w = box.maxWidth;
                  return ClipRect(
                    child: AnimatedBuilder(
                      animation: _pos.animation,
                      builder: (context, _) => Stack(
                        children: [
                          for (final (i, page) in pages.indexed)
                            if ((i - _pos.value).abs() < 1)
                              Transform.translate(
                                offset: Offset((i - _pos.value) * w, 0),
                                child: ExcludeSemantics(
                                  excluding: i != _i,
                                  child: IgnorePointer(
                                    ignoring: i != _i,
                                    child: Center(
                                      child: SingleChildScrollView(
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                                        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: page),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Row(
                    children: [
                      if (_i > 0) AuthLink('Back', onPressed: () => _go(_i - 1)) else const SizedBox(width: 48),
                      const Spacer(),
                      Semantics(
                        label: 'Step ${_i + 1} of $steps',
                        child: Row(
                          children: [
                            for (var k = 0; k < steps; k++) ...[if (k > 0) const SizedBox(width: 8), PressedDot(on: k <= _i, size: 10)],
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (_i < steps - 1)
                        SizedBox(
                          width: 120,
                          child: AuthPrimary(label: 'Next', onPressed: _canLeave(_i) ? () => _go(_i + 1) : null),
                        )
                      else
                        const SizedBox(width: 120),
                    ],
                  ),
                ),
              ),
            ),
            if (_i == 1 && !_consentOk)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text('Behavior sensing is needed to use Flow', style: TextStyle(color: p.text2, fontSize: 12.5)),
              ),
          ],
        ),
      ),
    );
  }
}

class _StepHead extends StatelessWidget {
  const _StepHead(this.n, this.title, this.note);
  final int n;
  final String title;
  final String note;

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(flowCaps('Step $n of 6'), style: FlowType.label(p, size: 10, color: p.text3)),
        const SizedBox(height: 8),
        Text(title, style: FlowType.headline(p, size: 30)),
        const SizedBox(height: 10),
        Text(note, style: FlowType.note(p, size: 15)),
        const SizedBox(height: 22),
      ],
    );
  }
}

// 1 ─ What Flow does
class _WhatFlowDoes extends StatelessWidget {
  const _WhatFlowDoes();
  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _StepHead(
        1,
        'What Flow does',
        'Flow follows the rhythm of your work, never its content, and suggests a break before your focus runs down.',
      ),
      ColorField(
        tone: FieldTone.brand,
        padding: EdgeInsets.fromLTRB(26, 18, 26, 22),
        child: SizedBox(height: 180, child: BlocksStage(state: StageState.rest, showBrand: false)),
      ),
      SizedBox(height: 20),
      FeatureNote(number: 1, title: 'Your day, as blocks', body: 'Each session rises from the line. Taller means more demanding.'),
      SizedBox(height: 10),
      FeatureNote(number: 2, title: 'A nudge, with its reason', body: 'When pressure nears the line, Flow suggests a break and shows why.'),
      SizedBox(height: 10),
      FeatureNote(number: 3, title: 'It learns your rhythm', body: 'After a few sessions it times nudges to you, not to a fixed clock.'),
    ],
  );
}

// 2 ─ What it senses + consent
class _Consent extends ConsumerWidget {
  const _Consent();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consent = ref.watch(consentProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHead(
          2,
          'What Flow may use',
          'Nothing is on until you turn it on. Behavior sensing is the one Flow needs; the rest are optional and can change any time in Privacy.',
        ),
        AsyncSection(
          lines: 5,
          value: consent,
          onRetry: () => ref.invalidate(consentProvider),
          builder: (c) => ColorField(
            tone: FieldTone.planned,
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final scope in ConsentScope.values)
                  ConsentRow(
                    title: consentTitle(scope) + (scope.required ? ' (required)' : ''),
                    description: consentDescription(scope),
                    value: c.granted(scope),
                    onChanged: (v) => runGuarded(context, () => ref.read(consentProvider.notifier).set(scope, v)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// 3 ─ Connect the agent
class _Agent extends ConsumerStatefulWidget {
  const _Agent();
  @override
  ConsumerState<_Agent> createState() => _AgentState();
}

class _AgentState extends ConsumerState<_Agent> {
  final _code = TextEditingController();
  StageState _stage = StageState.rest;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _pair(String code) async {
    setState(() {
      _stage = StageState.busy;
      _error = null;
    });
    try {
      await ref.read(agentStatusProvider.notifier).pair(code);
      if (mounted) setState(() => _stage = StageState.success);
    } catch (e) {
      if (mounted) {
        setState(() {
          _stage = StageState.error;
          _error = errorText(e);
          _code.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    final status = ref.watch(agentStatusProvider);
    final (line, sub) = switch (status.connection) {
      AgentConnection.connected => ('Connected', 'Agent ${status.agentVersion ?? ''} is measuring activity on this computer.'),
      AgentConnection.unpaired => ('Agent found', 'Enter the 6-digit code the agent shows.'),
      AgentConnection.disconnected => ('Agent not running', 'Install or start the Flow agent on this computer, then enter its code.'),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHead(
          3,
          'Connect the agent',
          'A small helper on this computer counts activity. It never reads window titles or what you type.',
        ),
        ColorField(
          tone: FieldTone.planned,
          child: _ConnectionLine(connected: status.connection == AgentConnection.connected),
        ),
        const SizedBox(height: 16),
        Text(
          line,
          style: TextStyle(color: p.text1, fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(sub, style: TextStyle(color: p.text2, fontSize: 12.5)),
        if (status.connection != AgentConnection.connected) ...[
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: CodeBoxes(controller: _code, onComplete: _pair, enabled: _stage != StageState.busy),
          ),
          if (_error != null) ...[const SizedBox(height: 8), AuthError(_error!)],
          const SizedBox(height: 6),
          Text('You can do this later from Settings › Agent.', style: TextStyle(color: p.text3, fontSize: 12)),
        ],
      ],
    );
  }
}

/// App ⟷ agent: a dashed line (not yet) that becomes solid only on a real
/// pairing; the plug end snaps in.
class _ConnectionLine extends StatelessWidget {
  const _ConnectionLine({required this.connected});
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    Widget node(String label, IconData icon) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: p.raised,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.hairline),
          ),
          child: Icon(icon, size: 18, color: p.text2),
        ),
        const SizedBox(height: 6),
        Text(flowCaps(label), style: FlowType.label(p, size: 9, color: p.text3)),
      ],
    );
    return Row(
      children: [
        node('Flow', Icons.space_dashboard_outlined),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: connected ? 1 : 0),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => CustomPaint(size: const Size(double.infinity, 12), painter: _LinkPainter(p, v)),
            ),
          ),
        ),
        node('Agent', Icons.memory_outlined),
      ],
    );
  }
}

class _LinkPainter extends CustomPainter {
  _LinkPainter(this.p, this.v);
  final FlowPalette p;
  final double v;

  @override
  void paint(Canvas c, Size s) {
    final y = s.height / 2;
    final dashed = Paint()
      ..color = p.text3
      ..strokeWidth = 1.2;
    for (var x = 6.0; x < s.width - 6; x += 8) {
      c.drawLine(Offset(x, y), Offset(x + 4, y), dashed);
    }
    if (v > 0) {
      c.drawLine(
        Offset(6, y),
        Offset(6 + (s.width - 12) * v, y),
        Paint()
          ..color = p.accent
          ..strokeWidth = 1.6,
      );
    }
  }

  @override
  bool shouldRepaint(_LinkPainter o) => o.v != v || o.p != p;
}

// 4 ─ Nudge style
class _NudgeStyle extends ConsumerWidget {
  const _NudgeStyle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(desktopPrefsProvider).nudgeStyle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHead(
          4,
          'How should nudges arrive?',
          'Pick one. The little screen shows where it will appear. You can change it in Settings.',
        ),
        const NudgeStyleOptions(axis: Axis.horizontal),
        const SizedBox(height: 20),
        ColorField(
          tone: FieldTone.rest,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: NudgeStylePreview(style: style),
            ),
          ),
        ),
      ],
    );
  }
}

// 5 ─ Practice nudge
class _Practice extends StatefulWidget {
  const _Practice();
  @override
  State<_Practice> createState() => _PracticeState();
}

class _PracticeState extends State<_Practice> {
  bool _why = false;
  String? _note;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _StepHead(
        5,
        'Try a practice nudge',
        'This one is pretend. Snooze it, or ask why. During a session the window shrinks to a small widget and the card grows out of it.',
      ),
      ColorField(
        tone: FieldTone.rest,
        child: NudgeCardView(
          message: "You're 48 minutes in and your typing rhythm has broken up. A short break now usually buys you the next hour.",
          onBreak: () => setState(() => _note = 'In a real session this starts your break.'),
          onSnooze: (m) => setState(() => _note = 'snoozed $m m'),
          onDismiss: () => setState(() => _note = 'dismissed — Flow will learn from that'),
          onWhy: () => setState(() => _why = !_why),
          why: _why
              ? const [
                  (name: 'Window switching', share: 0.46),
                  (name: 'Typing rhythm', share: 0.31),
                  (name: 'Time into cycle', share: 0.23),
                ]
              : null,
          note: _note,
        ),
      ),
      const SizedBox(height: 16),
      const FeatureNote(
        number: 1,
        title: 'Snooze',
        body: 'Pushes the nudge back 5, 10 or 20 minutes. Flow notes that the timing was early.',
      ),
      const SizedBox(height: 8),
      const FeatureNote(number: 2, title: 'Why?', body: 'Shows which signals pushed pressure up, and by how much.'),
      const SizedBox(height: 8),
      const FeatureNote(number: 3, title: 'The flag', body: 'Tell Flow a nudge was wrong. It is the fastest way to teach it.'),
    ],
  );
}

// 6 ─ Start
class _Start extends StatelessWidget {
  const _Start({required this.minutes, required this.onMinutes, required this.busy, required this.onStart, required this.onExplore});
  final int minutes;
  final ValueChanged<int> onMinutes;
  final bool busy;
  final VoidCallback onStart;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _StepHead(6, 'Ready when you are', 'Pick a length on the dial. Flow learns your rhythm from the first few sessions.'),
      ColorField(
        tone: FieldTone.now,
        child: Center(
          child: DurationDial(minutes: minutes, onChanged: onMinutes, size: 200, onCenterTap: busy ? null : onStart),
        ),
      ),
      const SizedBox(height: 22),
      AuthPrimary(label: busy ? 'Starting…' : 'Start your first session', onPressed: busy ? null : onStart),
      const SizedBox(height: 8),
      Center(child: AuthLink('Explore first', onPressed: onExplore)),
    ],
  );
}
