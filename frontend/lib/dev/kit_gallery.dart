// DEV ONLY: a gallery of the control kit, at /dev/kit (dev builds only).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_connector.dart';
import '../api/models/session.dart';
import '../desktop/desktop_host.dart';
import '../desktop/window_controller.dart';
import '../state/auth_controller.dart';
import '../state/session_controller.dart';

import '../api/mock/mock_backend.dart';
import '../api/mock/mock_day.dart';
import '../api/models/day.dart';
import '../theme/tokens.dart';
import '../ui/iso/month_terrain.dart';
import '../ui/score/day_score.dart';
import '../ui/dial.dart';
import '../ui/drum_wheel.dart';
import '../ui/kit.dart';
import '../ui/range_slider.dart';

class KitGallery extends StatefulWidget {
  const KitGallery({super.key});
  @override
  State<KitGallery> createState() => _KitGalleryState();
}

class _KitGalleryState extends State<KitGallery> {
  int _minutes = 70;
  int _day = 14;
  int _demand = 1;
  bool _toggle = true;
  int? _rating = 3;
  int _qs = 22 * 60, _qe = 23 * 60 + 30;
  int _preset = 1;
  final _task = TextEditingController();
  double _progress = 0.35;
  int _ghost = 0;
  String _tap = '';
  late final DateTime _now = () {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day, 15, 12);
  }();
  late final Map<DateTime, int> _month = {
    ...mockMonth(DateTime(_now.year, _now.month - 1, 1), newUser: false),
    ...mockMonth(_now, newUser: false),
  };
  late DateTime _sel = DateTime(_now.year, _now.month, _now.day);
  late final DayTimeline _timeline = mockDay(MockBackend(), _now, newUser: false, nowOverride: _now);

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(32),
        children: [
          Text('Control kit', style: FlowType.numeral(p, 28)),
          const SizedBox(height: 4),
          const SectionLabel('dev gallery · not in release builds'),
          const SizedBox(height: 20),
          DayScore(
            day: _timeline,
            now: _now,
            ghostMinutes: _ghost,
            height: 300,
            onGhostDrag: (m) => setState(() => _ghost = m),
            onSessionTap: (s) => setState(() => _tap = 'tapped ${s.taskText}'),
            onScheduleDraft: (a, b) => setState(() => _tap = 'draft ${a.hour}:${a.minute}–${b.hour}:${b.minute}'),
          ),
          ReadOut('ghost $_ghost min · $_tap'),
          const SizedBox(height: 16),
          Row(
            children: [
              DrumWheel(
                value: -_now.difference(_sel).inDays,
                min: -27,
                max: 0,
                onChanged: (d) => setState(() => _sel = DateTime(_now.year, _now.month, _now.day + d)),
                semanticLabel: 'Day',
              ),
              const SizedBox(width: 10),
              MonthTerrain(
                month: _now,
                minutes: _month,
                selected: _sel,
                onSelect: (d) => setState(() => _sel = d),
                size: const Size(300, 170),
              ),
              const SizedBox(width: 16),
              ReadOut('${_sel.month}/${_sel.day} · ${_month[DateTime(_sel.year, _sel.month, _sel.day)] ?? 0} min'),
            ],
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 48,
            runSpacing: 32,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DurationDial(
                    minutes: _minutes,
                    suggestion: 70,
                    onChanged: (v) => setState(() {
                      _minutes = v;
                      _ghost = v;
                    }),
                    onCenterTap: () => setState(() => _progress = 0.35),
                  ),
                  const SizedBox(height: 8),
                  ReadOut('$_minutes min · ends 4:40'),
                ],
              ),
              DurationDial(minutes: 70, onChanged: null, mode: DialMode.progress, fraction: _progress, centerLabel: '24:30', size: 140),
              DurationDial(minutes: 10, onChanged: null, mode: DialMode.drain, fraction: 0.6, centerLabel: '6:00', size: 120),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DrumWheel(value: _day, min: 0, max: 27, onChanged: (v) => setState(() => _day = v), semanticLabel: 'Day'),
                  const SizedBox(width: 16),
                  ReadOut('day $_day'),
                ],
              ),
              DrumWheel(value: _day, min: 0, max: 27, onChanged: (v) => setState(() => _day = v), axis: Axis.horizontal, length: 160),
            ],
          ),
          const SizedBox(height: 36),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final (i, m) in const [(0, '25'), (1, '50'), (2, '90')].indexed)
                Pressable(selected: _preset == i, onPressed: () => setState(() => _preset = i), child: Text(m.$2)),
              Pressable(tone: PressableTone.primary, onPressed: () {}, child: const Text('Start · ends 4:40')),
              const Pressable(onPressed: null, child: Text('Disabled')),
              PillToggle(value: _toggle, onChanged: (v) => setState(() => _toggle = v)),
              SnapSlider(
                steps: 3,
                index: _demand,
                labels: const ['light', 'moderate', 'heavy'],
                onChanged: (v) => setState(() => _demand = v),
              ),
              SizedBox(
                width: 220,
                child: FlowTextField(controller: _task, hint: 'task (optional)'),
              ),
            ],
          ),
          const SizedBox(height: 28),
          DotRating(label: 'How focused do you feel?', value: _rating, onChanged: (v) => setState(() => _rating = v)),
          const SizedBox(height: 28),
          SizedBox(
            width: 520,
            child: TimeRangeSlider(
              start: _qs,
              end: _qe,
              onChanged: (s, e) => setState(() {
                _qs = s;
                _qe = e;
              }),
              semanticLabel: 'Quiet hours',
            ),
          ),
          const SizedBox(height: 40),
          Slider(value: _progress, onChanged: (v) => setState(() => _progress = v)),
        ],
      ),
    );
  }
}

/// DEV ONLY: `/dev/login?as=solo|employee|admin|new` signs straight in (mock auth).
/// `&nudge=fullScreen|windowed|notification` also starts a session and sends
/// a nudge in that style (to look at the takeover without waiting).
class DevLogin extends ConsumerStatefulWidget {
  const DevLogin({super.key, required this.who, this.nudge});
  final String who;
  final String? nudge;
  @override
  ConsumerState<DevLogin> createState() => _DevLoginState();
}

class _DevLoginState extends ConsumerState<DevLogin> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final auth = ref.read(authProvider.notifier);
      await auth.login(email: '${widget.who}@flow.dev', password: 'password');
      if (ref.read(authProvider) is MfaRequired) await auth.verifyMfa('123456');
      if (!mounted) return;
      // this widget is gone after the redirect: keep the container, not `ref`
      final c = ProviderScope.containerOf(context, listen: false);
      GoRouter.of(context).go('/');
      final style = NudgeStyle.values.asNameMap()[widget.nudge];
      if (style == null) return;
      await c.read(desktopPrefsProvider.notifier).set(c.read(desktopPrefsProvider).copyWith(nudgeStyle: style));
      await c
          .read(liveSessionProvider.notifier)
          .start(const StartSessionRequest(taskText: 'Write spec', demand: Demand.moderate, plannedMinutes: 50));
      await Future<void>.delayed(const Duration(seconds: 2));
      c.read(mockBackendProvider).forceNudge();
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}
