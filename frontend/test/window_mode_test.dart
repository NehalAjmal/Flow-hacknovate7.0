import 'package:flow/api/api_connector.dart';
import 'package:flow/api/mock/mock_backend.dart';
import 'package:flow/api/models/session.dart';
import 'package:flow/desktop/desktop_host.dart';
import 'package:flow/desktop/window_controller.dart';
import 'package:flow/state/account_controllers.dart';
import 'package:flow/state/auth_controller.dart';
import 'package:flow/state/break_controller.dart';
import 'package:flow/state/session_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Records what the controller asks of the OS.
class FakeHost implements DesktopHost {
  final modes = <WindowMode>[];
  final notifications = <String>[];
  final trays = <TrayState>[];
  bool hidden = false;
  bool quitted = false;
  bool focused = true;
  VoidCallback? close;
  void Function(String)? tray;

  @override
  bool get isDesktop => true;
  @override
  Future<void> init({
    required VoidCallback onCloseRequested,
    required void Function(String key) onTrayAction,
    required ValueChanged<WidgetCorner> onWidgetSnapped,
  }) async {
    close = onCloseRequested;
    tray = onTrayAction;
  }

  @override
  Future<void> applyMode(WindowMode mode, {WidgetCorner corner = WidgetCorner.bottomRight}) async => modes.add(mode);
  @override
  Future<void> setTray(TrayState state, {String? tooltip, double? progress, required bool paused}) async => trays.add(state);
  @override
  Future<void> notify(String title, String body, {VoidCallback? onClick}) async => notifications.add(title);
  @override
  Future<bool> isFocused() async => focused;
  @override
  Future<void> show() async => hidden = false;
  @override
  Future<void> hide() async => hidden = true;
  @override
  Future<void> quit() async => quitted = true;
  @override
  Future<void> startDrag() async {}
}

Future<(ProviderContainer, FakeHost)> setup() async {
  final host = FakeHost();
  final b = MockBackend(config: MockConfig.fast);
  final c = ProviderContainer.test(overrides: [...mockOverrides(b), desktopHostProvider.overrideWithValue(host)], retry: (_, _) => null);
  c.listen(authProvider, (_, _) {});
  await eventually(() => c.read(authProvider) is SignedOut);
  await c.read(authProvider.notifier).login(email: 'solo@flow.dev', password: 'password');
  c.listen(liveSessionProvider, (_, _) {});
  c.listen(breakProvider, (_, _) {});
  c.listen(settingsProvider, (_, _) {});
  c.listen(windowModeProvider, (_, _) {});
  await c.read(liveSessionProvider.future);
  return (c, host);
}

void main() {
  devNudgeTests();
  test('no session: shrink does nothing (the widget only exists during a session)', () async {
    final (c, host) = await setup();
    c.read(windowModeProvider.notifier).shrink();
    expect(c.read(windowModeProvider), WindowMode.full);
    expect(host.modes, isEmpty);
  });

  test('session start auto-shrinks; a nudge grows the card; answering folds it back; ending returns to full', () async {
    final (c, host) = await setup();
    await c.read(liveSessionProvider.notifier).start(const StartSessionRequest(taskText: 'x', demand: Demand.moderate, plannedMinutes: 50));
    await eventually(() => c.read(windowModeProvider) == WindowMode.mini);

    await eventually(() => c.read(liveSessionProvider).value?.pendingInterventionId != null);
    expect(c.read(windowModeProvider), WindowMode.card);
    expect(host.notifications, isEmpty, reason: 'the card on top is the nudge; no duplicate OS notification');

    final id = c.read(liveSessionProvider).value!.pendingInterventionId!;
    await c.read(interventionActionsProvider).snooze(await c.read(interventionApiProvider).get(id), 5);
    expect(c.read(windowModeProvider), WindowMode.mini);

    await c.read(liveSessionProvider.notifier).end();
    await eventually(() => c.read(windowModeProvider) == WindowMode.full);
    expect(host.modes, containsAllInOrder([WindowMode.mini, WindowMode.card, WindowMode.mini, WindowMode.full]));
  });

  test('auto-mini off: the session stays in the full window', () async {
    final (c, host) = await setup();
    await c.read(desktopPrefsProvider.notifier).set(const DesktopPrefs(autoMini: false));
    await c.read(liveSessionProvider.notifier).start(const StartSessionRequest(taskText: 'x', demand: Demand.moderate, plannedMinutes: 50));
    await eventually(() => c.read(liveSessionProvider).value != null);
    expect(c.read(windowModeProvider), WindowMode.full);
    c.read(windowModeProvider.notifier).shrink();
    expect(c.read(windowModeProvider), WindowMode.mini);
  });

  test('an unfocused full window gets an OS notification for a nudge', () async {
    final (c, host) = await setup();
    await c.read(desktopPrefsProvider.notifier).set(const DesktopPrefs(autoMini: false));
    host.focused = false;
    await c.read(liveSessionProvider.notifier).start(const StartSessionRequest(taskText: 'x', demand: Demand.moderate, plannedMinutes: 50));
    await eventually(() => host.notifications.isNotEmpty);
    expect(c.read(windowModeProvider), WindowMode.full);
  });

  test('close keeps Flow in the tray; with the setting off it quits', () async {
    final (c, host) = await setup();
    host.close!();
    expect(host.hidden, isTrue);
    expect(host.quitted, isFalse);
    await c.read(desktopPrefsProvider.notifier).set(const DesktopPrefs(closeToTray: false));
    host.close!();
    expect(host.quitted, isTrue);
  });

  test('tray reflects the session: idle → steady', () async {
    final (c, host) = await setup();
    await c.read(liveSessionProvider.notifier).start(const StartSessionRequest(taskText: 'x', demand: Demand.moderate, plannedMinutes: 50));
    await eventually(() => host.trays.contains(TrayState.steady) || host.trays.contains(TrayState.breakDue));
  });
}

void devNudgeTests() {
  test('dev panel: "Send a nudge now" raises a nudge at once, even in the quiet scenario', () async {
    final host = FakeHost();
    final b = MockBackend(config: const MockConfig(latency: Duration.zero, tick: Duration(hours: 1)))..scenario = MockScenario.quiet;
    final c = ProviderContainer.test(overrides: [...mockOverrides(b), desktopHostProvider.overrideWithValue(host)], retry: (_, _) => null);
    c.listen(authProvider, (_, _) {});
    await eventually(() => c.read(authProvider) is SignedOut);
    await c.read(authProvider.notifier).login(email: 'solo@flow.dev', password: 'password');
    c.listen(liveSessionProvider, (_, _) {});
    c.listen(windowModeProvider, (_, _) {});
    await c.read(liveSessionProvider.future);
    expect(b.forceNudge(), 'Start a session first.');
    await c.read(liveSessionProvider.notifier).start(const StartSessionRequest(taskText: 'x', demand: Demand.moderate, plannedMinutes: 50));
    expect(b.forceNudge(), isNull);
    await eventually(() => c.read(liveSessionProvider).value?.pendingInterventionId != null);
    expect(c.read(windowModeProvider), WindowMode.card, reason: 'the widget grows into the card');
    expect(b.forceNudge(), 'A nudge is already waiting.');
  });
}
