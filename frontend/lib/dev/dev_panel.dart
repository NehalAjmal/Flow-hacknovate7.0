// ════════════════════════════════════════════════════════════════════════════
//  DEV ONLY. Only referenced behind `if (kDevBuild)`, so release builds
//  compile it out. Delete this folder before shipping.
//
//  Open with Ctrl+Shift+D (Windows/Linux) or Cmd+Shift+D (macOS).
// ════════════════════════════════════════════════════════════════════════════
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override, ProviderOrFamily;

import '../api/api_connector.dart';
import '../api/mock/mock_backend.dart';
import '../api/models/session.dart';
import '../api/real/http_transport.dart';
import '../desktop/desktop_host.dart';
import '../desktop/window_controller.dart';
import '../state/auth_controller.dart';
import '../state/data_providers.dart';
import '../state/session_controller.dart';

class DevRequestLog extends Notifier<List<RequestLogEntry>> {
  static const cap = 200;

  @override
  List<RequestLogEntry> build() => const [];

  void add(RequestLogEntry e) {
    // Defer: logging can happen while another provider is building.
    scheduleMicrotask(() {
      if (!ref.mounted) return;
      final next = [e, ...state];
      state = next.length > cap ? next.sublist(0, cap) : next;
    });
  }

  void clear() => state = const [];
}

final devRequestLogProvider = NotifierProvider<DevRequestLog, List<RequestLogEntry>>(DevRequestLog.new);

final devPanelOpenProvider = NotifierProvider<_Open, bool>(_Open.new);

class _Open extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
}

/// ProviderScope overrides for dev builds.
List<Override> devOverrides() => [
  requestLoggerProvider.overrideWith((ref) {
    final log = ref.watch(devRequestLogProvider.notifier);
    return log.add;
  }),
];

class DevShell extends ConsumerStatefulWidget {
  const DevShell({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<DevShell> createState() => _DevShellState();
}

class _DevShellState extends ConsumerState<DevShell> {
  // A global key handler (not a Focus/Shortcuts widget) so the panel opens
  // no matter which widget has focus, and nothing in the tree autofocuses.
  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent || e.logicalKey != LogicalKeyboardKey.keyD) return false;
    final k = HardwareKeyboard.instance;
    if (k.isShiftPressed && (k.isControlPressed || k.isMetaPressed)) {
      ref.read(devPanelOpenProvider.notifier).toggle();
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final open = ref.watch(devPanelOpenProvider);
    return Stack(
      children: [
        widget.child,
        // Small always-visible marker so nobody mistakes a dev build for release.
        Positioned(
          left: 4,
          bottom: 4,
          child: GestureDetector(
            onTap: () => ref.read(devPanelOpenProvider.notifier).toggle(),
            child: const Material(
              color: Color(0xFFFFD54F),
              borderRadius: BorderRadius.all(Radius.circular(4)),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text('DEV', style: TextStyle(fontSize: 11)),
              ),
            ),
          ),
        ),
        if (open) const Positioned(top: 0, right: 0, bottom: 0, width: 440, child: _DevPanel()),
      ],
    );
  }
}

class _DevPanel extends ConsumerStatefulWidget {
  const _DevPanel();
  @override
  ConsumerState<_DevPanel> createState() => _DevPanelState();
}

class _DevPanelState extends ConsumerState<_DevPanel> {
  late final _url = TextEditingController(text: ref.read(apiBaseUrlProvider));

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  void _refreshData() {
    for (final ProviderOrFamily p in [
      liveSessionProvider,
      dashboardProvider,
      patternsProvider,
      forecastProvider,
      preCheckProvider,
      teamSummaryProvider,
      adminSummaryProvider,
      adminTrendProvider,
      adminInsightsProvider,
      adminStrainProvider,
      adminMeetingWindowProvider,
      adminPrivacyProvider,
      // kept for 5 min after leaving a page: forget them too
      dayTimelineProvider,
      weekTimelinesProvider,
      rollingMinutesProvider,
      yearMinutesProvider,
      sessionsPageProvider,
      calendarContextProvider,
      dataSummaryProvider,
      focusDnaProvider,
      changelogProvider,
    ]) {
      ref.invalidate(p);
    }
  }

  @override
  Widget build(BuildContext context) {
    final modes = ref.watch(apiModesProvider);
    final warnings = apiModeWarnings(modes);
    final log = ref.watch(devRequestLogProvider);
    final backend = ref.watch(mockBackendProvider);
    final anyMock = modes.values.contains(ApiMode.mock);

    return Material(
      elevation: 12,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              Text('Dev panel', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => ref.read(devPanelOpenProvider.notifier).toggle()),
            ],
          ),
          for (final w in warnings)
            Card(
              color: Colors.amber.shade100,
              child: Padding(padding: const EdgeInsets.all(8), child: Text(w)),
            ),
          Text('Backend URL', style: Theme.of(context).textTheme.titleSmall),
          Row(
            children: [
              Expanded(
                child: TextField(controller: _url, decoration: const InputDecoration(isDense: true)),
              ),
              TextButton(
                onPressed: () {
                  ref.read(apiBaseUrlProvider.notifier).set(_url.text.trim());
                  _refreshData();
                },
                child: const Text('Apply'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('API areas', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              TextButton(onPressed: () => ref.read(apiModesProvider.notifier).setAll(ApiMode.mock), child: const Text('All mock')),
              TextButton(onPressed: () => ref.read(apiModesProvider.notifier).setAll(ApiMode.real), child: const Text('All real')),
            ],
          ),
          Row(
            children: [
              const Text('Window', style: TextStyle(fontSize: 12)),
              const Spacer(),
              for (final m in WindowMode.values)
                TextButton(onPressed: () => ref.read(windowModeProvider.notifier).debugPreview(m), child: Text(m.name)),
            ],
          ),
          const _SimulateBox(),
          for (final area in ApiArea.values)
            Row(
              children: [
                Expanded(child: Text('${area.label}\n${area.paths}', style: const TextStyle(fontSize: 12))),
                SegmentedButton<ApiMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: ApiMode.mock, label: Text('mock')),
                    ButtonSegment(value: ApiMode.real, label: Text('real')),
                  ],
                  selected: {modes[area] ?? ApiMode.real},
                  onSelectionChanged: (s) => ref.read(apiModesProvider.notifier).set(area, s.first),
                ),
              ],
            ),
          if (anyMock) ...[
            const SizedBox(height: 12),
            Text('Mock scenario', style: Theme.of(context).textTheme.titleSmall),
            RadioGroup<MockScenario>(
              groupValue: backend.scenario,
              onChanged: (s) {
                if (s == null) return;
                setState(() {
                  backend.scenario = s;
                  backend.history.clear();
                });
                _refreshData();
              },
              child: Column(
                children: [
                  for (final s in MockScenario.values)
                    RadioListTile<MockScenario>(dense: true, value: s, title: Text(s.label), subtitle: Text(s.description)),
                ],
              ),
            ),
            const Text(
              'Mock logins (password: "password"): solo@, employee@, admin@ (MFA 123456), new@ — all @flow.dev',
              style: TextStyle(fontSize: 12),
            ),
            Wrap(
              spacing: 6,
              children: [
                for (final who in const ['solo', 'employee', 'admin', 'new'])
                  TextButton(
                    onPressed: () => ref.read(authProvider.notifier).login(email: '$who@flow.dev', password: 'password'),
                    child: Text('Sign in as $who'),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Requests (${log.length})', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              TextButton(onPressed: () => ref.read(devRequestLogProvider.notifier).clear(), child: const Text('Clear')),
            ],
          ),
          for (final e in log.take(80))
            Text(
              '${e.mocked ? 'MOCK' : 'REAL'} ${e.method} ${e.path} → ${e.status ?? e.error ?? '…'}'
              '${e.duration == null ? '' : ' (${e.duration!.inMilliseconds} ms)'}',
              style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: (e.status ?? 500) >= 400 ? Colors.red.shade700 : null),
            ),
        ],
      ),
    );
  }
}

/// Simulate: mock latency (to see loading states) and a nudge on demand.
/// Results show inline: the panel sits above the app's Scaffold, so a
/// SnackBar from here would never appear.
class _SimulateBox extends ConsumerStatefulWidget {
  const _SimulateBox();
  @override
  ConsumerState<_SimulateBox> createState() => _SimulateBoxState();
}

class _SimulateBoxState extends ConsumerState<_SimulateBox> {
  String? _status;

  static const _latencies = [0, 250, 800, 2000];

  Future<void> _nudge() async {
    final modes = ref.read(apiModesProvider);
    final notMock = [ApiArea.session, ApiArea.interventions].where((a) => modes[a] != ApiMode.mock).map((a) => a.label);
    if (notMock.isNotEmpty) {
      setState(() => _status = '${notMock.join(' and ')} use the real backend: nudges come from it. Set them to mock to simulate.');
      return;
    }
    final b = ref.read(mockBackendProvider);
    if (b.run == null) {
      setState(() => _status = 'Starting a 50 min session…');
      try {
        await ref
            .read(liveSessionProvider.notifier)
            .start(const StartSessionRequest(taskText: 'Simulated', demand: Demand.moderate, plannedMinutes: 50));
      } catch (e) {
        if (mounted) setState(() => _status = 'Could not start a session: $e');
        return;
      }
    }
    final why = b.forceNudge();
    if (mounted) setState(() => _status = why ?? 'Nudge sent: it shows bottom-right (or as the card in widget mode).');
  }

  @override
  Widget build(BuildContext context) {
    final modes = ref.watch(apiModesProvider);
    if (!modes.values.contains(ApiMode.mock)) return const SizedBox.shrink();
    final b = ref.watch(mockBackendProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Simulate', style: Theme.of(context).textTheme.titleSmall),
          Row(
            children: [
              const Expanded(child: Text('Mock latency (loaders show after 250 ms)', style: TextStyle(fontSize: 12))),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [for (final ms in _latencies) ButtonSegment(value: ms, label: Text(ms < 1000 ? '$ms' : '${ms ~/ 1000}s'))],
                selected: {b.latency.inMilliseconds},
                emptySelectionAllowed: true,
                onSelectionChanged: (sel) {
                  if (sel.isEmpty) return;
                  setState(() => b.latencyOverride = Duration(milliseconds: sel.first));
                },
              ),
            ],
          ),
          Row(
            children: [
              TextButton(
                onPressed: () {
                  ref.read(cacheEpochProvider.notifier).bump();
                  setState(() => _status = 'Cache cleared: pages reload (with the loader, if latency > 250 ms).');
                },
                child: const Text('Forget cached pages'),
              ),
              const Spacer(),
              FilledButton.tonal(onPressed: _nudge, child: const Text('Send a nudge now')),
            ],
          ),
          if (_status != null) Text(_status!, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
