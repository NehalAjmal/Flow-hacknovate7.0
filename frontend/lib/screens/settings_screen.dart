import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_connector.dart';
import '../api/models/agent.dart';
import '../api/models/consent.dart';
import '../api/models/schedule.dart';
import '../api/models/session.dart';
import '../api/models/settings.dart';
import '../core/config.dart';
import '../core/endpoint_policy.dart';
import '../router/routes.dart';
import '../state/account_controllers.dart';
import '../state/auth_controller.dart';
import '../state/data_providers.dart';
import '../desktop/desktop_host.dart';
import '../desktop/window_controller.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import '../ui/appear.dart';
import '../ui/dial.dart';
import '../ui/drum_wheel.dart';
import '../ui/feature_note.dart';
import '../ui/kit.dart';
import '../ui/loading_blocks.dart';
import '../ui/nudge_card.dart';
import '../ui/range_slider.dart';
import '../widgets/common.dart';
import 'auth_layout.dart' show AuthError, StageState;
import 'auth_screens.dart' show CodeBoxes;
import 'shell.dart' show FlowHeader;

enum _Sec { nudges, breaks, schedules, quiet, window, sensors, agent, account, help }

extension on _Sec {
  String get title => switch (this) {
    _Sec.nudges => 'Nudges',
    _Sec.breaks => 'Breaks',
    _Sec.schedules => 'Schedules',
    _Sec.quiet => 'Quiet hours',
    _Sec.window => 'Window',
    _Sec.sensors => 'Sensors',
    _Sec.agent => 'Agent',
    _Sec.account => 'Account',
    _Sec.help => 'Help',
  };
}

/// Settings (spec §9), filling the page: a sticky index on the left whose rows
/// show each section's current value (so the index itself reads as a summary),
/// sections on the right with controls beside a live preview. Every change
/// saves immediately (optimistic, rolled back on failure).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _scroll = ScrollController();
  final _keys = {for (final s in _Sec.values) s: GlobalKey()};
  _Sec _active = _Sec.nudges;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // the section whose top has passed ~a third of the viewport is "active"
  void _track() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final line = box.localToGlobal(Offset.zero).dy + box.size.height * 0.33;
    var best = _Sec.nudges;
    for (final s in _Sec.values) {
      final ctx = _keys[s]!.currentContext;
      final rb = ctx?.findRenderObject() as RenderBox?;
      if (rb == null || !rb.attached) continue;
      if (rb.localToGlobal(Offset.zero).dy <= line) best = s;
    }
    if (best != _active) setState(() => _active = best);
  }

  void _jump(_Sec s) {
    final ctx = _keys[s]!.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: Motion.reduced(context) ? Duration.zero : const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    return Padding(
      padding: const EdgeInsets.only(right: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FlowHeader(title: 'Settings', subtitle: 'Changes save as you make them'),
          const SizedBox(height: 8),
          Expanded(
            child: AsyncSection(
              value: settings,
              onRetry: () => ref.invalidate(settingsProvider),
              builder: (s) => LayoutBuilder(
                builder: (context, box) {
                  final wide = box.maxWidth >= 980;
                  final body = NotificationListener<ScrollUpdateNotification>(
                    onNotification: (_) {
                      // read positions after this frame's layout, not mid-scroll
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _track();
                      });
                      return false;
                    },
                    child: ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.only(bottom: 40),
                      children: [
                        for (final (i, sec) in _Sec.values.indexed)
                          Padding(
                            key: _keys[sec],
                            padding: const EdgeInsets.only(bottom: 18),
                            child: Appear(index: i, child: _section(sec, s)),
                          ),
                      ],
                    ),
                  );
                  if (!wide) return body;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 240,
                        child: _Index(active: _active, settings: s, onTap: _jump),
                      ),
                      const SizedBox(width: 22),
                      Expanded(child: body),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(_Sec sec, UserSettings s) => switch (sec) {
    _Sec.nudges => _NudgesSection(settings: s),
    _Sec.breaks => _BreaksSection(settings: s),
    _Sec.schedules => const _SchedulesSection(),
    _Sec.quiet => _QuietSection(settings: s),
    _Sec.window => const _WindowSection(),
    _Sec.sensors => _SensorsSection(settings: s),
    _Sec.agent => const _AgentSection(),
    _Sec.account => const _AccountSection(),
    _Sec.help => const _HelpSection(),
  };
}

// ── index ───────────────────────────────────────────────────────────────────

class _Index extends StatelessWidget {
  const _Index({required this.active, required this.settings, required this.onTap});
  final _Sec active;
  final UserSettings settings;
  final ValueChanged<_Sec> onTap;

  String _value(_Sec s) => switch (s) {
    _Sec.nudges => _modeTitle(settings.deliveryMode),
    _Sec.breaks => '${settings.breakLengthSec ~/ 60} min',
    _Sec.quiet => settings.quietHours == null ? 'Off' : '${settings.quietHours!.start}–${settings.quietHours!.end}',
    _Sec.window => '',
    _Sec.schedules => '',
    _Sec.sensors => [
      if (settings.cameraEnabled) 'camera',
      if (settings.calendarEnabled) 'calendar',
      if (settings.llmEnabled) 'AI',
    ].join(' · ').ifEmpty('behavior only'),
    _Sec.agent => '',
    _Sec.account => '',
    _Sec.help => '',
  };

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    final q = settings.quietHours;
    final summary =
        '${_modeTitle(settings.deliveryMode)} nudges, ${settings.breakLengthSec ~/ 60}-minute breaks, '
        '${q == null ? 'no quiet hours' : 'quiet from ${q.start} to ${q.end}'}, '
        'snooze ${settings.snoozeOptions.join('/')} min.';
    return ColorField(
      tone: FieldTone.past,
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final s in _Sec.values)
            InkWell(
              onTap: () => onTap(s),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: s == active ? p.raised : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: s == active ? p.hairline : Colors.transparent),
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 3,
                      height: _value(s).isEmpty ? 14 : 28,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: s == active ? p.selected : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.title,
                            style: TextStyle(
                              color: s == active ? p.text1 : p.text2,
                              fontSize: 13,
                              fontWeight: s == active ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                          if (_value(s).isNotEmpty)
                            Text(
                              _value(s),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: FlowType.chart(p, size: 10.5, color: p.text3),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('In one line'),
                const SizedBox(height: 6),
                Text(summary, style: FlowType.note(p, size: 13.5, color: p.text1)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

String _modeTitle(DeliveryMode m) => switch (m) {
  DeliveryMode.advisory => 'Quiet',
  DeliveryMode.explained => 'Explained',
  DeliveryMode.lock => 'Firm',
};

// ── shared section frame ────────────────────────────────────────────────────

/// One section: title + Flow's one-line explanation, then controls beside a
/// preview (stacked when narrow).
class _Frame extends StatelessWidget {
  const _Frame({required this.title, required this.note, required this.controls, this.preview, this.tone = FieldTone.past});
  final String title;
  final String note;
  final Widget controls;
  final Widget? preview;
  final FieldTone tone;

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    return ColorField(
      tone: tone,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
      child: LayoutBuilder(
        builder: (context, box) {
          final head = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: FlowType.headline(p, size: 24)),
              const SizedBox(height: 6),
              Text(note, style: FlowType.note(p, size: 14)),
              const SizedBox(height: 16),
            ],
          );
          if (preview == null || box.maxWidth < 760) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                head,
                controls,
                if (preview != null) ...[const SizedBox(height: 18), preview!],
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 11,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [head, controls]),
              ),
              const SizedBox(width: 28),
              Expanded(flex: 9, child: preview!),
            ],
          );
        },
      ),
    );
  }
}

Future<void> _save(BuildContext context, WidgetRef ref, SettingsPatch patch, {void Function(ConsentScope)? onConsent}) async {
  try {
    await ref.read(settingsProvider.notifier).patch(patch);
  } on ConsentRequired catch (e) {
    onConsent?.call(e.scope);
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}

// ── 1 nudges ────────────────────────────────────────────────────────────────

class _NudgesSection extends ConsumerWidget {
  const _NudgesSection({required this.settings});
  final UserSettings settings;

  static const _snoozeChoices = [5, 10, 15, 20, 30];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = FlowPalette.of(context);
    final mode = settings.deliveryMode;
    final flags = ref.watch(flagsProvider).value;
    final modes = [
      for (final m in DeliveryMode.values)
        if (m != DeliveryMode.lock || flags == null || flags.values.isEmpty || flags.isOn('lock_mode')) m,
    ];
    return _Frame(
      tone: FieldTone.rest,
      title: 'Nudges',
      note: 'How a break suggestion reaches you. The preview shows exactly what you will see.',
      controls: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final m in modes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Pressable(
                selected: m == mode,
                onPressed: () => _save(context, ref, SettingsPatch(deliveryMode: m)),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_modeTitle(m), style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(switch (m) {
                        DeliveryMode.advisory => 'A small card you can ignore. The reason is one tap away.',
                        DeliveryMode.explained => 'The card says why, up front.',
                        DeliveryMode.lock => 'A full-screen break with a slide-to-override. Opt-in.',
                      }, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: m == mode ? p.onSelected : p.text2)),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 14),
          const SectionLabel('Snooze options'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in _snoozeChoices)
                Pressable(
                  selected: settings.snoozeOptions.contains(m),
                  semanticLabel: 'Snooze $m minutes',
                  onPressed: () {
                    final next = {...settings.snoozeOptions};
                    if (!next.remove(m)) next.add(m);
                    if (next.isEmpty || next.length > 3) return; // 1–3 choices keep the menu short
                    _save(context, ref, SettingsPatch(snoozeOptions: next.toList()..sort()));
                  },
                  child: Text('$m min'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Pick up to three.', style: FlowType.chart(p, size: 10.5)),
        ],
      ),
      preview: AnimatedSwitcher(
        duration: Motion.fade,
        child: mode == DeliveryMode.lock
            ? Container(
                key: const ValueKey('lock'),
                height: 200,
                decoration: BoxDecoration(color: p.selected, borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Break · 5:00', style: FlowType.numeral(p, 32, color: p.onSelected)),
                    const SizedBox(height: 16),
                    Text('slide to override  ›', style: TextStyle(color: p.onSelected.withValues(alpha: 0.75), fontSize: 12)),
                  ],
                ),
              )
            : IgnorePointer(
                key: ValueKey(mode),
                child: NudgeCardView(
                  message: "You're 48 minutes in and your typing rhythm has broken up. A short break now usually buys you the next hour.",
                  reason: mode == DeliveryMode.explained ? 'Window switching is 40% above your usual for this hour.' : null,
                  breakMinutes: settings.breakLengthSec ~/ 60,
                  snoozeOptions: settings.snoozeOptions,
                  onBreak: () {},
                  onSnooze: (_) {},
                  onDismiss: () {},
                  onWhy: mode == DeliveryMode.advisory ? () {} : null,
                ),
              ),
      ),
    );
  }
}

// ── 2 breaks ────────────────────────────────────────────────────────────────

class _BreaksSection extends ConsumerStatefulWidget {
  const _BreaksSection({required this.settings});
  final UserSettings settings;
  @override
  ConsumerState<_BreaksSection> createState() => _BreaksSectionState();
}

class _BreaksSectionState extends ConsumerState<_BreaksSection> {
  int? _min; // local value while the wheel turns; saved after it settles
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    final m = _min ?? (widget.settings.breakLengthSec ~/ 60).clamp(2, 15);
    return _Frame(
      tone: FieldTone.rest,
      title: 'Breaks',
      note: 'How long a suggested break lasts. Short and often beats long and late.',
      controls: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TabularNumeral('$m', style: FlowType.numeral(p, 56)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(flowCaps('min'), style: FlowType.label(p, size: 11)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DrumWheel(
            value: m,
            min: 2,
            max: 15,
            axis: Axis.horizontal,
            length: 300,
            thickness: 34,
            semanticLabel: 'Break length',
            semanticValue: (v) => '$v minutes',
            onChanged: (v) {
              setState(() => _min = v);
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 450), () => _save(context, ref, SettingsPatch(breakLengthSec: v * 60)));
            },
          ),
          const SizedBox(height: 8),
          Text('2 – 15 minutes. Scroll, drag or use the arrow keys.', style: FlowType.chart(p, size: 10.5)),
        ],
      ),
      // the break as you'll see it: the dial's dashes draining
      preview: Center(
        child: DurationDial(minutes: m, onChanged: null, size: 200, mode: DialMode.drain, fraction: 1, centerLabel: '$m:00'),
      ),
    );
  }
}

// ── 3 quiet hours ───────────────────────────────────────────────────────────

class _QuietSection extends ConsumerStatefulWidget {
  const _QuietSection({required this.settings});
  final UserSettings settings;
  @override
  ConsumerState<_QuietSection> createState() => _QuietSectionState();
}

class _QuietSectionState extends ConsumerState<_QuietSection> {
  static const _origin = 12 * 60; // the track runs noon → noon so nights are one piece
  (int, int)? _local;
  Timer? _debounce;

  static int _parse(String hm) {
    final parts = hm.split(':');
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0);
  }

  static String _fmt(int clock) => '${(clock ~/ 60 % 24).toString().padLeft(2, '0')}:${(clock % 60).toString().padLeft(2, '0')}';
  static int _toTrack(int clock) => (clock - _origin) % TimeRangeSlider.day;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    final q = widget.settings.quietHours;
    final on = q != null;
    final range = _local ?? (on ? (_toTrack(_parse(q.start)), _toTrack(_parse(q.end))) : (_toTrack(22 * 60), _toTrack(7 * 60)));
    final (a, b) = range.$1 < range.$2 ? range : (range.$2, range.$1);
    final hours = ((b - a) / 60).toStringAsFixed((b - a) % 60 == 0 ? 0 : 1);
    return _Frame(
      tone: FieldTone.planned,
      title: 'Quiet hours',
      note: 'No nudges in this window. Sessions you start yourself still run.',
      controls: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PillToggle(
                value: on,
                semanticLabel: 'Quiet hours',
                onChanged: (v) => _save(
                  context,
                  ref,
                  v
                      ? SettingsPatch(
                          quietHours: QuietHours(start: _fmt(a + _origin), end: _fmt(b + _origin)),
                        )
                      : const SettingsPatch(clearQuietHours: true),
                ),
              ),
              const SizedBox(width: 12),
              Text(on ? 'On · $hours h without nudges' : 'Off', style: TextStyle(color: p.text1, fontSize: 13.5)),
            ],
          ),
          const SizedBox(height: 18),
          Opacity(
            opacity: on ? 1 : 0.45,
            child: IgnorePointer(
              ignoring: !on,
              child: TimeRangeSlider(
                start: a,
                end: b,
                origin: _origin,
                semanticLabel: 'Quiet hours',
                onChanged: (s, e) {
                  setState(() => _local = (s, e));
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 450), () {
                    _save(
                      context,
                      ref,
                      SettingsPatch(
                        quietHours: QuietHours(start: _fmt(s + _origin), end: _fmt(e + _origin)),
                      ),
                    );
                  });
                },
              ),
            ),
          ),
        ],
      ),
      preview: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FeatureNote(
            number: 1,
            compact: true,
            title: 'Drag either end',
            body: 'Snaps to 15 minutes. The track runs noon to noon, so a night stays in one piece.',
          ),
        ],
      ),
    );
  }
}

// ── 4 sensors ───────────────────────────────────────────────────────────────

class _SensorsSection extends ConsumerStatefulWidget {
  const _SensorsSection({required this.settings});
  final UserSettings settings;
  @override
  ConsumerState<_SensorsSection> createState() => _SensorsSectionState();
}

class _SensorsSectionState extends ConsumerState<_SensorsSection> {
  ConsentScope? _needs; // a switch that rubber-banded back because consent is missing

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    void ask(ConsentScope sc) => setState(() => _needs = sc);
    return _Frame(
      tone: FieldTone.past,
      title: 'Sensors',
      note: 'Optional signals that sharpen the timing. Each needs your consent in Privacy first.',
      controls: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SwitchRow(
            title: 'Camera eye signal',
            body: 'Estimates eye openness on this computer. Frames never leave the device.',
            value: s.cameraEnabled,
            needsConsent: _needs == ConsentScope.camera,
            onChanged: (v) => _save(context, ref, SettingsPatch(cameraEnabled: v), onConsent: ask),
          ),
          _SwitchRow(
            title: 'Calendar awareness',
            body: 'Avoids nudging right before meetings. Read-only, next 3 hours.',
            value: s.calendarEnabled,
            needsConsent: _needs == ConsentScope.calendar,
            onChanged: (v) => _save(context, ref, SettingsPatch(calendarEnabled: v), onConsent: ask),
          ),
          if (s.calendarEnabled) const _CalendarRow(),
          _SwitchRow(
            title: 'AI assistant when stuck',
            body: 'Sends only your task text, and only when you ask for help.',
            value: s.llmEnabled,
            needsConsent: _needs == ConsentScope.llm,
            onChanged: (v) => _save(context, ref, SettingsPatch(llmEnabled: v), onConsent: ask),
          ),
        ],
      ),
      preview: const _SensingPreview(),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.title, required this.body, required this.value, required this.onChanged, this.needsConsent = false});
  final String title;
  final String body;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool needsConsent;

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: p.text1, fontSize: 13.5, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(body, style: TextStyle(color: p.text2, fontSize: 12, height: 1.4)),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  alignment: Alignment.topLeft,
                  child: !needsConsent
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Text('Needs consent first.', style: TextStyle(color: p.text1, fontSize: 12)),
                              TextButton(
                                onPressed: () => context.go(Routes.privacy),
                                style: TextButton.styleFrom(visualDensity: VisualDensity.compact, foregroundColor: p.text1),
                                child: const Text(
                                  'Allow in Privacy →',
                                  style: TextStyle(decoration: TextDecoration.underline, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // without consent the value never changes, so the toggle springs back
          PillToggle(value: value, onChanged: onChanged, semanticLabel: title),
        ],
      ),
    );
  }
}

/// Calendar connect: the OAuth consent opens in the system browser; Flow
/// then checks every few seconds (for up to 2 minutes) until the backend
/// reports the account linked. The person can cancel the wait.
class _CalendarRow extends ConsumerStatefulWidget {
  const _CalendarRow();
  @override
  ConsumerState<_CalendarRow> createState() => _CalendarRowState();
}

class _CalendarRowState extends ConsumerState<_CalendarRow> {
  Timer? _poll;
  DateTime? _waitingSince;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _stopWaiting() {
    _poll?.cancel();
    if (mounted) setState(() => _waitingSince = null);
  }

  Future<void> _connect() async {
    try {
      final uri = await ref.read(calendarApiProvider).connect();
      // the dev mock hands back a placeholder URL; don't open it
      final mock = kDevBuild && uri.queryParameters['mock'] == '1';
      // the URL comes from the server: only ever open Google's https consent page
      if (!mock && !EndpointPolicy.isAllowedOAuthUrl(uri)) {
        if (mounted) showError(context, StateError('Flow received an unexpected sign-in address and did not open it.'));
        return;
      }
      if (!mock && !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) showError(context, StateError('Could not open the browser. Copy this link: $uri'));
        return;
      }
      setState(() => _waitingSince = DateTime.now());
      _poll?.cancel();
      _poll = Timer.periodic(const Duration(seconds: 3), (_) async {
        if (DateTime.now().difference(_waitingSince!) > const Duration(minutes: 2)) return _stopWaiting();
        try {
          final c = await ref.read(calendarApiProvider).context();
          if (c.connected) {
            _stopWaiting();
            ref.invalidate(calendarContextProvider);
          }
        } catch (_) {}
      });
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    final ctx = ref.watch(calendarContextProvider);
    final waiting = _waitingSince != null;
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 6),
      child: switch (ctx) {
        AsyncData(:final value) => Row(
          children: [
            Icon(Icons.event_outlined, size: 16, color: p.text2),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value.connected
                    ? 'Google Calendar connected${value.events.isNotEmpty ? ' · next: ${value.events.first.title}' : ''}'
                    : (waiting ? 'Finish signing in in your browser… Flow is waiting.' : 'Google Calendar not connected'),
                style: TextStyle(color: waiting ? p.text1 : p.text2, fontSize: 12),
              ),
            ),
            if (waiting)
              TextButton(
                onPressed: _stopWaiting,
                child: Text('Cancel', style: TextStyle(color: p.text2, fontSize: 12)),
              )
            else
              Pressable(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                onPressed: () async {
                  if (value.connected) {
                    await runGuarded(context, () => ref.read(calendarApiProvider).disconnect());
                    ref.invalidate(calendarContextProvider);
                  } else {
                    await _connect();
                  }
                },
                child: Text(value.connected ? 'Disconnect' : 'Connect'),
              ),
          ],
        ),
        AsyncError(:final error) => Text(errorText(error), style: TextStyle(color: p.text2, fontSize: 12)),
        _ => const SizedBox(height: 24),
      },
    );
  }
}

/// What is being sensed right now, as chips that light up per signal.
class _SensingPreview extends ConsumerWidget {
  const _SensingPreview();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = FlowPalette.of(context);
    final consent = ref.watch(consentProvider).value;
    final s = ref.watch(settingsProvider).value;
    Widget chip(String label, bool on) => AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: on ? p.raised : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: on ? p.text3 : p.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? p.selected : null,
              border: on ? null : Border.all(color: p.text3),
            ),
          ),
          const SizedBox(width: 7),
          Text(flowCaps(label), style: FlowType.label(p, size: 9.5, color: on ? p.text1 : p.text3)),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Sensed right now'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            chip('Behavior', consent?.granted(ConsentScope.behavior) ?? false),
            chip('Camera', s?.cameraEnabled ?? false),
            chip('Calendar', s?.calendarEnabled ?? false),
            chip('AI', s?.llmEnabled ?? false),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Behavior means counts only: typing, switching, idle time and the kind of app in front. Never window titles, never what you type.',
          style: FlowType.note(p, size: 13.5),
        ),
      ],
    );
  }
}

// ── 5 agent ─────────────────────────────────────────────────────────────────

class _AgentSection extends ConsumerStatefulWidget {
  const _AgentSection();
  @override
  ConsumerState<_AgentSection> createState() => _AgentSectionState();
}

class _AgentSectionState extends ConsumerState<_AgentSection> {
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
    final a = ref.watch(agentStatusProvider);
    final connected = a.connection == AgentConnection.connected;
    final (title, sub) = switch (a.connection) {
      AgentConnection.connected => ('Connected', 'Version ${a.agentVersion ?? '?'} · app in front: ${a.category?.wire ?? '—'}'),
      AgentConnection.unpaired => ('Found, not paired', 'Enter the 6-digit code the agent shows.'),
      AgentConnection.disconnected => ('Not running', 'Install or start the Flow agent on this computer.'),
    };
    return _Frame(
      tone: connected ? FieldTone.now : FieldTone.planned,
      title: 'Agent',
      note: 'The small helper on this computer that counts activity.',
      controls: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(shape: BoxShape.circle, color: connected ? p.accent : p.text3),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(color: p.text1, fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(sub, style: TextStyle(color: p.text2, fontSize: 12.5)),
          if (!connected) ...[
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: CodeBoxes(controller: _code, onComplete: _pair, enabled: _stage != StageState.busy),
            ),
            if (_error != null) ...[const SizedBox(height: 8), AuthError(_error!)],
          ],
        ],
      ),
      preview: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Signals from this computer'),
          const SizedBox(height: 8),
          Consumer(
            builder: (context, ref, _) {
              final sig = ref.watch(liveSignalsProvider).value;
              if (sig == null) return Text('Nothing yet: signals appear once the agent is connected.', style: FlowType.note(p, size: 13.5));
              Widget stat(String big, String label) => Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TabularNumeral(big, style: FlowType.numeral(p, 30)),
                    const SizedBox(height: 3),
                    Text(flowCaps(label), style: FlowType.label(p, size: 9.5, color: p.text3)),
                  ],
                ),
              );
              return Row(
                children: [
                  stat('${sig.keysPerMin}', 'keys / min'),
                  stat('${sig.switchesPer5Min}', 'switches / 5 min'),
                  stat('${sig.idleSec}s', 'idle'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── 6 account ───────────────────────────────────────────────────────────────

class _AccountSection extends ConsumerStatefulWidget {
  const _AccountSection();
  @override
  ConsumerState<_AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends ConsumerState<_AccountSection> {
  bool _resetSent = false;

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    final u = ref.watch(currentUserProvider);
    if (u == null) return const SizedBox.shrink();
    Widget field(String label, String value, {Widget? trailing}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(flowCaps(label), style: FlowType.label(p, size: 10, color: p.text3)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: p.text1, fontSize: 13.5)),
          ),
          ?trailing,
        ],
      ),
    );
    return _Frame(
      tone: FieldTone.past,
      title: 'Account',
      note: 'Who you are to Flow. Your sessions belong to this account only.',
      controls: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          field('Name', u.name),
          field(
            'Email',
            u.email,
            trailing: Text(
              u.emailVerified ? 'verified' : 'not verified',
              style: FlowType.chart(p, size: 10.5, color: u.emailVerified ? p.text2 : p.problem),
            ),
          ),
          field('Account', switch (u.role.wire) {
            'admin' => 'Team admin',
            'employee' => 'Team member',
            _ => 'Just me',
          }),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              Pressable(
                onPressed: _resetSent
                    ? null
                    : () async {
                        final ok = await runGuarded(context, () => ref.read(authApiProvider).forgotPassword(u.email));
                        if (ok && mounted) setState(() => _resetSent = true);
                      },
                child: Text(_resetSent ? 'Reset link sent' : 'Change password'),
              ),
              Pressable(onPressed: () => ref.read(authProvider.notifier).logout(), child: const Text('Sign out')),
            ],
          ),
        ],
      ),
      preview: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FeatureNote(
            number: 1,
            compact: true,
            title: 'Change password',
            body: 'We email you a link; the change happens there, so a stolen session cannot do it.',
          ),
          const SizedBox(height: 12),
          if (u.role.wire == 'admin')
            const FeatureNote(
              number: 2,
              compact: true,
              title: 'Two-step setup',
              body: 'Admins sign in with a code. QR setup and recovery codes arrive with the 2-step API.',
            )
          else
            const FeatureNote(number: 2, compact: true, title: 'Your data', body: 'Export it or delete the account from Privacy.'),
        ],
      ),
    );
  }
}

// ── 7 help ──────────────────────────────────────────────────────────────────

class _HelpSection extends StatelessWidget {
  const _HelpSection();
  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    Widget key(String k, String what) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: p.raised,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: p.hairline),
            ),
            child: Text(k, style: FlowType.chart(p, size: 11, color: p.text1)),
          ),
          const SizedBox(width: 12),
          Flexible(child: Text(what, style: TextStyle(color: p.text2, fontSize: 12.5))),
        ],
      ),
    );
    return _Frame(
      tone: FieldTone.planned,
      title: 'Help',
      note: 'Everything has a button; shortcuts are only a faster way.',
      controls: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Pressable(onPressed: () => context.go(Routes.guide), child: const Text('Replay the welcome guide')),
          const SizedBox(height: 14),
          Text(
            'Questions or a bug? Use Feedback in the sidebar; it can include diagnostics if you choose.',
            style: FlowType.note(p, size: 13.5),
          ),
        ],
      ),
      preview: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Shortcuts'),
          const SizedBox(height: 8),
          key('Ctrl 1', 'Home'),
          key('Ctrl 2', 'Insights'),
          key('Ctrl ,', 'Settings'),
          key('Space', 'Pause / resume on the focus screen dial'),
        ],
      ),
    );
  }
}

// ── window (desktop) ────────────────────────────────────────────────────────

class _WindowSection extends ConsumerWidget {
  const _WindowSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = FlowPalette.of(context);
    final desktop = ref.watch(desktopHostProvider).isDesktop;
    final prefs = ref.watch(desktopPrefsProvider);
    final set = ref.read(desktopPrefsProvider.notifier).set;
    Widget row(String title, String body, bool v, ValueChanged<bool> on) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: p.text1, fontSize: 13.5, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(body, style: TextStyle(color: p.text2, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          PillToggle(value: v, onChanged: desktop ? on : null, semanticLabel: title),
        ],
      ),
    );
    return _Frame(
      tone: FieldTone.planned,
      title: 'Window',
      note: desktop
          ? 'During a session Flow can step aside into a small widget that stays on top.'
          : 'These apply to the desktop app (Windows and macOS).',
      controls: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row(
            'Shrink to the widget when a session starts',
            'You can always shrink or open it again yourself.',
            prefs.autoMini,
            (v) => set(prefs.copyWith(autoMini: v)),
          ),
          row(
            'Closing keeps Flow in the tray',
            'Sessions keep running; nudges arrive as notifications. Quit is in the tray menu.',
            prefs.closeToTray,
            (v) => set(prefs.copyWith(closeToTray: v)),
          ),
        ],
      ),
      // the widget's corner, picked on a little screen
      preview: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Widget corner'),
          const SizedBox(height: 10),
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Container(
              decoration: BoxDecoration(
                color: p.raised,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: p.hairline),
              ),
              padding: const EdgeInsets.all(10),
              child: Stack(
                children: [
                  for (final c in WidgetCorner.values)
                    Align(
                      alignment: switch (c) {
                        WidgetCorner.topLeft => Alignment.topLeft,
                        WidgetCorner.topRight => Alignment.topRight,
                        WidgetCorner.bottomLeft => Alignment.bottomLeft,
                        WidgetCorner.bottomRight => Alignment.bottomRight,
                      },
                      child: Pressable(
                        selected: prefs.corner == c,
                        semanticLabel: 'Widget corner ${c.name}',
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        onPressed: desktop ? () => set(prefs.copyWith(corner: c)) : null,
                        child: const SizedBox(width: 44, height: 10),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text('Drag the widget anywhere; it settles into the nearest corner and remembers it.', style: FlowType.note(p, size: 13.5)),
        ],
      ),
    );
  }
}

// ── schedules (routines) ────────────────────────────────────────────────────

const _wd = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

class _SchedulesSection extends ConsumerWidget {
  const _SchedulesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = FlowPalette.of(context);
    final list = ref.watch(schedulesProvider);
    final items = list.value ?? const <Schedule>[];
    return _Frame(
      tone: FieldTone.planned,
      title: 'Schedules',
      note: 'Sessions you plan to repeat. They show on Home as dashed blocks, and Flow offers to start them on time.',
      controls: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          switch (list) {
            AsyncError(:final error) => InlineError(message: errorText(error), onRetry: () => ref.invalidate(schedulesProvider)),
            AsyncLoading() when list.value == null => const LoadingBlocks(height: 60, count: 4),
            _ => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (items.isEmpty) Text('No schedules yet.', style: FlowType.note(p, size: 14)),
                for (final sc in items) _ScheduleRow(key: ValueKey(sc.id), schedule: sc),
              ],
            ),
          },
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Pressable(
              onPressed: () => runGuarded(
                context,
                () => ref
                    .read(schedulesProvider.notifier)
                    .add(const Schedule(name: 'Deep work', start: '09:30', end: '10:30', weekdays: [1, 2, 3, 4, 5])),
              ),
              child: const Text('Add a schedule'),
            ),
          ),
          const SizedBox(height: 8),
          Text('Tip: drag across the future part of Home’s day to plan one there.', style: FlowType.chart(p, size: 10.5)),
        ],
      ),
      preview: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Your week'),
          const SizedBox(height: 10),
          SizedBox(
            height: 180,
            child: CustomPaint(size: Size.infinite, painter: _WeekPlanPainter(p, items, MediaQuery.textScalerOf(context))),
          ),
        ],
      ),
    );
  }
}

class _ScheduleRow extends ConsumerStatefulWidget {
  const _ScheduleRow({super.key, required this.schedule});
  final Schedule schedule;
  @override
  ConsumerState<_ScheduleRow> createState() => _ScheduleRowState();
}

class _ScheduleRowState extends ConsumerState<_ScheduleRow> {
  late final _name = TextEditingController(text: widget.schedule.name);
  Schedule? _local;
  Timer? _debounce;

  Schedule get _s => _local ?? widget.schedule;

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose();
    super.dispose();
  }

  void _change(Schedule next, {bool now = false}) {
    setState(() => _local = next);
    _debounce?.cancel();
    void push() => runGuarded(context, () => ref.read(schedulesProvider.notifier).save(next)).then((_) {
      if (mounted) setState(() => _local = null);
    });
    now ? push() : _debounce = Timer(const Duration(milliseconds: 500), push);
  }

  @override
  Widget build(BuildContext context) {
    final p = FlowPalette.of(context);
    final s = _s;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: p.raised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: FlowTextField(
                  controller: _name,
                  hint: 'Name',
                  onSubmitted: (v) => _change(s.copyWith(name: v.trim().isEmpty ? 'Planned session' : v.trim()), now: true),
                ),
              ),
              const SizedBox(width: 12),
              PillToggle(
                value: s.enabled,
                semanticLabel: 'Schedule on',
                onChanged: (v) => _change(s.copyWith(enabled: v), now: true),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Opacity(
            opacity: s.enabled ? 1 : 0.5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TimeRangeSlider(
                  start: s.startMinutes,
                  end: s.endMinutes,
                  semanticLabel: '${s.name} time',
                  onChanged: (a, b) => _change(s.copyWith(start: Schedule.hm(a), end: Schedule.hm(b))),
                ),
                const SizedBox(height: 10),
                // days left, demand right; wraps to two lines when narrow
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 8,
                  spacing: 12,
                  children: [
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (var d = 1; d <= 7; d++)
                          Pressable(
                            selected: s.weekdays.contains(d),
                            semanticLabel: 'Day $d',
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            onPressed: () {
                              final w = {...s.weekdays};
                              if (!w.remove(d)) w.add(d);
                              if (w.isNotEmpty) _change(s.copyWith(weekdays: w.toList()..sort()), now: true);
                            },
                            child: Text(_wd[d - 1]),
                          ),
                      ],
                    ),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final dm in Demand.values)
                          Pressable(
                            selected: s.demand == dm,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            onPressed: () => _change(s.copyWith(demand: dm), now: true),
                            child: Text(dm.wire),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: s.id == null ? null : () => runGuarded(context, () => ref.read(schedulesProvider.notifier).remove(s.id!)),
              child: Text(
                'Remove',
                style: TextStyle(color: p.text2, fontSize: 12, decoration: TextDecoration.underline),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Seven day lines (8:00–20:00) with each schedule as a dashed planned block.
class _WeekPlanPainter extends CustomPainter {
  _WeekPlanPainter(this.p, this.items, this.scaler);
  final FlowPalette p;
  final List<Schedule> items;
  final TextScaler scaler;

  @override
  void paint(Canvas c, Size s) {
    const left = 18.0;
    const h0 = 8 * 60, h1 = 20 * 60;
    double x(int m) => left + (s.width - left) * ((m - h0) / (h1 - h0)).clamp(0.0, 1.0);
    final row = s.height / 7.6;
    for (var d = 0; d < 7; d++) {
      final y = row * (d + 1);
      c.drawLine(
        Offset(left, y),
        Offset(s.width, y),
        Paint()
          ..color = p.hairline
          ..strokeWidth = 1,
      );
      final tp = TextPainter(
        text: TextSpan(text: _wd[d], style: FlowType.chart(p, size: 9.5)),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      tp.paint(c, Offset(2, y - tp.height));
      for (final sc in items.where((x) => x.enabled && x.weekdays.contains(d + 1))) {
        final r = Rect.fromLTRB(x(sc.startMinutes), y - row * 0.62, x(sc.endMinutes), y);
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = p.future;
        final path = Path()..addRect(r);
        for (final m in path.computeMetrics()) {
          for (var t = 0.0; t < m.length; t += 5) {
            c.drawPath(m.extractPath(t, math.min(t + 3, m.length)), paint);
          }
        }
      }
    }
    for (final hh in const [8, 12, 16, 20]) {
      final tp = TextPainter(
        text: TextSpan(text: '$hh', style: FlowType.chart(p, size: 9)),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      tp.paint(c, Offset(x(hh * 60) - tp.width / 2, s.height - tp.height));
    }
  }

  @override
  bool shouldRepaint(_WeekPlanPainter o) => o.items != items || o.p != p;
}
