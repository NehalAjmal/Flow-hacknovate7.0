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
import 'package:shared_preferences/shared_preferences.dart';

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
  Future<bool> applyMode(WindowMode mode, {WidgetCorner corner = WidgetCorner.bottomRight}) async {
    modes.add(mode);
    return !(failCompact && (mode == WindowMode.mini || mode == WindowMode.card));
  }

  bool failCompact = false;
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

/// Most tests here are about the small widget and card, i.e. the
/// notification style; the takeover tests ask for theirs.
Future<(ProviderContainer, FakeHost)> setup({NudgeStyle style = NudgeStyle.notification}) async {
  final host = FakeHost();
  final b = MockBackend(config: MockConfig.fast);
  final c = ProviderContainer.test(overrides: [...mockOverrides(b), desktopHostProvider.overrideWithValue(host)], retry: (_, _) => null);
  c.listen(desktopPrefsProvider, (_, _) {});
  // these tests are about the pop-out, so turn auto pop-out on (off by default)
  await c.read(desktopPrefsProvider.notifier).set(DesktopPrefs(nudgeStyle: style, autoMini: true));
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
  popFallbackTests();
  takeoverTests();
  prefsTests();
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
    await c.read(desktopPrefsProvider.notifier).set(c.read(desktopPrefsProvider).copyWith(autoMini: false));
    await c.read(liveSessionProvider.notifier).start(const StartSessionRequest(taskText: 'x', demand: Demand.moderate, plannedMinutes: 50));
    await eventually(() => c.read(liveSessionProvider).value != null);
    expect(c.read(windowModeProvider), WindowMode.full);
    c.read(windowModeProvider.notifier).shrink();
    expect(c.read(windowModeProvider), WindowMode.mini);
  });

  test('an unfocused full window gets an OS notification for a nudge', () async {
    final (c, host) = await setup();
    await c.read(desktopPrefsProvider.notifier).set(c.read(desktopPrefsProvider).copyWith(autoMini: false));
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
    await c.read(desktopPrefsProvider.notifier).set(c.read(desktopPrefsProvider).copyWith(closeToTray: false));
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
    c.listen(desktopPrefsProvider, (_, _) {});
    await c.read(desktopPrefsProvider.notifier).set(const DesktopPrefs(nudgeStyle: NudgeStyle.notification, autoMini: true));
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

void popFallbackTests() {
  test('if the widget cannot open, Flow falls back to the full window and stops offering it', () async {
    final (c, host) = await setup();
    host.failCompact = true;
    final ctl = c.read(windowModeProvider.notifier);
    await c.read(liveSessionProvider.notifier).start(const StartSessionRequest(taskText: 'x', demand: Demand.moderate, plannedMinutes: 50));
    await eventually(() => ctl.widgetUnavailable.value);
    expect(c.read(windowModeProvider), WindowMode.full, reason: 'never stuck in a broken widget');
    expect(host.modes.last, WindowMode.full);
    final n = host.modes.length;
    ctl.shrink();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(host.modes.length, n, reason: 'not tried again this run');
  });

  test('a successful pop bumps `popped` after the native window is in place', () async {
    final (c, _) = await setup();
    final ctl = c.read(windowModeProvider.notifier);
    expect(ctl.popped.value, 0);
    await c.read(liveSessionProvider.notifier).start(const StartSessionRequest(taskText: 'x', demand: Demand.moderate, plannedMinutes: 50));
    await eventually(() => ctl.popped.value >= 1);
    expect(c.read(windowModeProvider), anyOf(WindowMode.mini, WindowMode.card));
  });
}

void takeoverTests() {
  Future<String> nudged(ProviderContainer c) async {
    await c.read(liveSessionProvider.notifier).start(const StartSessionRequest(taskText: 'x', demand: Demand.moderate, plannedMinutes: 50));
    await eventually(() => c.read(liveSessionProvider).value?.pendingInterventionId != null);
    return c.read(liveSessionProvider).value!.pendingInterventionId!;
  }

  test('full screen (the default): a nudge takes the screen, answering returns to the widget, no OS notification', () async {
    final (c, host) = await setup(style: NudgeStyle.fullScreen);
    expect(const DesktopPrefs().nudgeStyle, NudgeStyle.fullScreen);
    final id = await nudged(c);
    expect(c.read(windowModeProvider), WindowMode.nudgeFull);
    expect(host.notifications, isEmpty, reason: 'the takeover is the nudge');
    await c.read(interventionActionsProvider).snooze(await c.read(interventionApiProvider).get(id), 5);
    expect(c.read(windowModeProvider), WindowMode.mini, reason: 'back where it came from');
    await eventually(() => host.modes.last == WindowMode.mini);
    expect(host.modes, containsAllInOrder([WindowMode.mini, WindowMode.nudgeFull, WindowMode.mini]));
  });

  test('windowed: a nudge opens the floating window; from the full app it returns to the full app', () async {
    final (c, host) = await setup(style: NudgeStyle.windowed);
    await c.read(desktopPrefsProvider.notifier).set(c.read(desktopPrefsProvider).copyWith(autoMini: false));
    final id = await nudged(c);
    expect(c.read(windowModeProvider), WindowMode.nudge);
    await c.read(interventionActionsProvider).dismiss(await c.read(interventionApiProvider).get(id));
    expect(c.read(windowModeProvider), WindowMode.full);
    await eventually(() => host.modes.last == WindowMode.full);
  });

  test('unanswered: the takeover steps back, the suggestion keeps waiting', () async {
    final (c, _) = await setup(style: NudgeStyle.fullScreen);
    final id = await nudged(c);
    c.read(windowModeProvider.notifier).retreat();
    expect(c.read(windowModeProvider), WindowMode.mini);
    expect(c.read(liveSessionProvider).value?.pendingInterventionId, id, reason: 'not answered for you');
    // and it can still be opened as the card
    c.read(windowModeProvider.notifier).openCard();
    expect(c.read(windowModeProvider), WindowMode.card);
  });

  test('ending the session during a takeover returns to the full app', () async {
    final (c, _) = await setup(style: NudgeStyle.fullScreen);
    await nudged(c);
    await c.read(liveSessionProvider.notifier).end();
    await eventually(() => c.read(windowModeProvider) == WindowMode.full);
  });

  test('defaults: full-screen nudges; the pop-out is opt-in', () {
    const d = DesktopPrefs();
    expect(d.nudgeStyle, NudgeStyle.fullScreen);
    expect(d.autoMini, isFalse, reason: 'starting a session must not reshape the window unasked');
  });

  test('window modes: which shapes float', () {
    expect([for (final m in WindowMode.values) if (m.isFloating) m], [WindowMode.mini, WindowMode.card, WindowMode.nudge, WindowMode.nudgeFull]);
    expect([for (final m in WindowMode.values) if (m.isTakeover) m], [WindowMode.nudge, WindowMode.nudgeFull]);
  });
}

void prefsTests() {
  test('a preference changed while the stored ones are still loading is kept', () async {
    SharedPreferences.setMockInitialValues({'flow.desktop.nudgeStyle': 'fullScreen'});
    final c = ProviderContainer.test();
    c.listen(desktopPrefsProvider, (_, _) {});
    // changed in the same instant the controller is created (load in flight)
    await c.read(desktopPrefsProvider.notifier).set(const DesktopPrefs(nudgeStyle: NudgeStyle.windowed));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(c.read(desktopPrefsProvider).nudgeStyle, NudgeStyle.windowed);
  });

  test('the nudge style is remembered on this computer', () async {
    SharedPreferences.setMockInitialValues({'flow.desktop.nudgeStyle': 'notification'});
    final c = ProviderContainer.test();
    c.listen(desktopPrefsProvider, (_, _) {});
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(c.read(desktopPrefsProvider).nudgeStyle, NudgeStyle.notification);
  });
}
