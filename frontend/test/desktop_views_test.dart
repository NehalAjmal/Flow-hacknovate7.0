import 'dart:math' as math;

import 'package:flow/api/mock/mock_backend.dart';
import 'package:flow/api/models/session.dart';
import 'package:flow/app.dart';
import 'package:flow/desktop/compact_views.dart';
import 'package:flow/desktop/desktop_host.dart';
import 'package:flow/desktop/window_controller.dart';
import 'package:flutter/services.dart';
import 'package:flow/state/break_controller.dart';
import 'package:flow/desktop/nudge_takeover.dart';
import 'package:flow/router/app_router.dart';
import 'package:flow/router/routes.dart';
import 'package:flow/state/auth_controller.dart';
import 'package:flow/state/session_controller.dart';
import 'package:flow/theme/tokens.dart';
import 'package:flow/ui/dial.dart';
import 'package:flow/ui/range_slider.dart';
import 'package:flow/ui/nudge_card.dart';
import 'package:flow/ui/brand/launch_overlay.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// Regressions found on real Windows hardware:
/// - the compact views live above the router's Navigator, so their tooltips
///   had no Overlay ("No Overlay widget found");
/// - a schedule row's day + demand pills overflowed at mid widths.
void main() {
  dialTests();
  dialLapTests();
  arrivalTests();
  takeoverViewTests();
  settingsNavTests();
  appearanceTests();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ProviderContainer> boot(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final b = MockBackend(config: const MockConfig(latency: Duration.zero, tick: Duration(hours: 1)));
    final c = mockContainer(b);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const FlowApp()));
    await tester.pump(const Duration(seconds: 4));
    await tester.runAsync(() => c.read(authProvider.notifier).login(email: 'solo@flow.dev', password: 'password'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    return c;
  }

  Future<void> settle(WidgetTester tester, [int n = 10]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<void> teardown(WidgetTester tester, ProviderContainer c) async {
    final err = tester.takeException();
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.pump(const Duration(seconds: 1));
    expect(err, isNull);
  }

  for (final mode in [WindowMode.mini, WindowMode.card]) {
    testWidgets('${mode.name} view renders with tooltips (has an Overlay)', (tester) async {
      final c = await boot(tester, const Size(1280, 800));
      await tester.runAsync(
        () => c.read(liveSessionProvider.notifier).start(const StartSessionRequest(taskText: 'Draft', demand: Demand.moderate, plannedMinutes: 50)),
      );
      await settle(tester);
      c.read(windowModeProvider.notifier).debugPreview(mode);
      // the native resize to the widget's own window size
      tester.view.physicalSize = mode == WindowMode.mini ? const Size(320, 88) : const Size(360, 440);
      await settle(tester);
      expect(find.byType(Tooltip), findsWidgets);
      // it must actually fill the small window (a 0×0 view paints black)
      final view = mode == WindowMode.mini ? const Size(320, 88) : const Size(360, 440);
      expect(tester.getSize(find.byType(mode == WindowMode.mini ? MiniWidget : CardView)), view);
      // hover a tooltip so it actually opens in the overlay
      final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await g.addPointer(location: Offset.zero);
      await g.moveTo(tester.getCenter(find.byTooltip('Open Flow')));
      await tester.pump(const Duration(seconds: 2));
      await g.removePointer();
      await settle(tester);
      // back to full: the app takes input again (the empty overlay passes it through)
      c.read(windowModeProvider.notifier).debugPreview(WindowMode.full);
      tester.view.physicalSize = const Size(1280, 800);
      await settle(tester);
      await teardown(tester, c);
    });
  }

  testWidgets('the launch reveal ends without remounting the app beneath it', (tester) async {
    _Probe.mounts = 0;
    final c = mockContainer(MockBackend(config: const MockConfig(latency: Duration.zero, tick: Duration(hours: 1))));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: LaunchOverlay(child: _Probe())),
      ),
    );
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(_Probe.mounts, 1);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  for (final w in [1024.0, 1100.0, 1180.0, 1280.0, 1440.0]) {
    testWidgets('settings › schedules rows fit at ${w.toInt()} wide', (tester) async {
      final c = await boot(tester, Size(w, 800));
      c.read(appRouterProvider).go(Routes.settings);
      await settle(tester, 20);
      // the row's key is ValueKey<String?>, so match by value, not by type
      final row = find.byWidgetPredicate((w) => w.key is ValueKey && (w.key! as ValueKey).value == 'sch_1');
      await tester.ensureVisible(row); // every section is built now, so it can be scrolled to directly
      await settle(tester);
      await teardown(tester, c);
    });
  }
}

class _Probe extends StatefulWidget {
  const _Probe();
  static int mounts = 0;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    _Probe.mounts++;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

void dialTests() {
  testWidgets('dragging the dial tracks the hand 1:1 (no spring between hand and ring)', (tester) async {
    var minutes = 60;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: StatefulBuilder(
              builder: (context, set) => DurationDial(minutes: minutes, size: 200, onChanged: (m) => set(() => minutes = m)),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    final c = tester.getCenter(find.byType(DurationDial));
    // grab the ring at 3 o'clock and pull it a quarter turn clockwise, to 6 o'clock
    final g = await tester.startGesture(c + const Offset(80, 0));
    await tester.pump();
    for (var i = 1; i <= 30; i++) {
      final a = (math.pi / 2) * i / 30;
      await g.moveTo(c + Offset(80 * math.cos(a), 80 * math.sin(a)));
      await tester.pump(const Duration(milliseconds: 2)); // a fast flick
    }
    // Still held. What the read-out says in this very frame must be what it
    // says after waiting: with a spring between hand and ring it would still
    // be travelling now and read something else a moment later.
    String label() => tester.widget<TabularNumeral>(find.descendant(of: find.byType(DurationDial), matching: find.byType(TabularNumeral))).text;
    final now = label();
    await tester.pump(const Duration(seconds: 1));
    expect(label(), now, reason: 'the ring is where the hand is, not chasing it');
    expect(int.parse(now), greaterThanOrEqualTo(95), reason: 'about a quarter turn (45 min) from 60');
    await g.up();
    await tester.pump(const Duration(seconds: 1));
    expect(minutes, int.parse(now), reason: 'release keeps the value shown');
  });
}

void arrivalTests() {
  testWidgets('the nudge card rises in (and is not simply there on the first frame)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final b = MockBackend(config: const MockConfig(latency: Duration.zero, tick: Duration(hours: 1)));
    final c = mockContainer(b);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const FlowApp()));
    await tester.pump(const Duration(seconds: 4));
    await tester.runAsync(() => c.read(authProvider.notifier).login(email: 'solo@flow.dev', password: 'password'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.runAsync(
      () => c.read(liveSessionProvider.notifier).start(const StartSessionRequest(taskText: 'x', demand: Demand.moderate, plannedMinutes: 50)),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await c.read(desktopPrefsProvider.notifier).set(const DesktopPrefs(nudgeStyle: NudgeStyle.notification));
    expect(b.forceNudge(), isNull);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(); // the card mounts
    await tester.pump(const Duration(milliseconds: 60));
    final card = find.byType(NudgeCardView);
    expect(card, findsOneWidget);
    final early = tester.getTopLeft(card).dy;
    // every frame of the arrival, overshoot included (it must not assert)
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(seconds: 1));
    final rest = tester.getTopLeft(card).dy;
    expect(early, greaterThan(rest + 8), reason: 'it starts lower and rises into place');
    final err = tester.takeException();
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.pump(const Duration(seconds: 1));
    expect(err, isNull);
  });

  testWidgets('the compact view springs in when the native window has popped', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = mockContainer(MockBackend(config: const MockConfig(latency: Duration.zero, tick: Duration(hours: 1))));
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const FlowApp()));
    await tester.pump(const Duration(seconds: 4));
    await tester.runAsync(() => c.read(authProvider.notifier).login(email: 'solo@flow.dev', password: 'password'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.runAsync(
      () => c.read(liveSessionProvider.notifier).start(const StartSessionRequest(taskText: 'x', demand: Demand.moderate, plannedMinutes: 50)),
    );
    final ctl = c.read(windowModeProvider.notifier);
    ctl.debugPreview(WindowMode.mini);
    tester.view.physicalSize = const Size(320, 88);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final full = tester.getSize(find.byType(MiniWidget));
    Size painted() => tester.getRect(find.byType(MiniWidget)).size; // after transforms
    expect(painted(), full);
    ctl.popped.value++; // what the native host reports once the pill is on screen
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    expect(painted().width, lessThan(full.width - 10), reason: 'it starts smaller…');
    await tester.pump(const Duration(seconds: 1));
    expect(painted(), full, reason: '…and settles at full size');
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.pump(const Duration(seconds: 1));
  });
}

void takeoverViewTests() {
  Future<(ProviderContainer, MockBackend)> nudgedApp(WidgetTester tester, Size size, NudgeStyle style) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final b = MockBackend(config: const MockConfig(latency: Duration.zero, tick: Duration(hours: 1)));
    final c = mockContainer(b);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const FlowApp()));
    await tester.pump(const Duration(seconds: 4));
    await tester.runAsync(() => c.read(authProvider.notifier).login(email: 'solo@flow.dev', password: 'password'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await c.read(desktopPrefsProvider.notifier).set(DesktopPrefs(nudgeStyle: style));
    await tester.runAsync(
      () => c.read(liveSessionProvider.notifier).start(const StartSessionRequest(taskText: 'x', demand: Demand.moderate, plannedMinutes: 50)),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(b.forceNudge(), isNull);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    tester.view.physicalSize = size; // the native window takes its shape
    await tester.pump();
    return (c, b);
  }

  Future<void> finish(WidgetTester tester, ProviderContainer c) async {
    final err = tester.takeException();
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.pump(const Duration(seconds: 1));
    expect(err, isNull);
  }

  for (final (size, style) in const [
    (Size(1920, 1080), NudgeStyle.fullScreen),
    (Size(1366, 768), NudgeStyle.fullScreen),
    // the floating window's own size, and a very small one (the view is the
    // same widget; on a desktop the app underneath is offstage at these sizes)
    (Size(760, 480), NudgeStyle.fullScreen),
    (Size(420, 300), NudgeStyle.fullScreen),
    // in a browser the windowed style is a panel over the dimmed app
    (Size(1280, 800), NudgeStyle.windowed),
  ]) {
    testWidgets('takeover lays out at ${size.width.toInt()}×${size.height.toInt()} (${style.name})', (tester) async {
      final (c, _) = await nudgedApp(tester, size, style);
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(find.byType(NudgeTakeover), findsOneWidget);
      expect(find.textContaining('Take a '), findsOneWidget);
      expect(find.byType(NudgeCardView), findsNothing, reason: 'one nudge on screen, not two');
      await finish(tester, c);
    });
  }

  testWidgets('takeover: keys are dead at first (you were typing elsewhere), then Enter takes the break', (tester) async {
    final (c, b) = await nudgedApp(tester, const Size(1366, 768), NudgeStyle.fullScreen);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.read(liveSessionProvider).value?.pendingInterventionId, isNotNull, reason: 'a stray key must not answer it');
    expect(c.read(breakProvider), isNull);
    // the arm timer may have been started on the real clock (the native pop
    // completes inside runAsync), so wait for it in real time too
    await tester.runAsync(() => Future<void>.delayed(NudgeTakeover.armAfter + const Duration(milliseconds: 200)));
    await tester.pump(NudgeTakeover.armAfter);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await tester.pump(const Duration(milliseconds: 200));
    expect(c.read(liveSessionProvider).value?.pendingInterventionId, isNull, reason: 'Enter takes the break once the keys are live');
    expect(b.breaks, isNotEmpty);
    await finish(tester, c);
  });

  testWidgets('takeover: the tide rises, then the question and the controls land in order', (tester) async {
    final (c, _) = await nudgedApp(tester, const Size(1366, 768), NudgeStyle.fullScreen);
    await tester.pump(const Duration(milliseconds: 120));
    double opacityOf(String text) =>
        tester.widget<Opacity>(find.ancestor(of: find.textContaining(text), matching: find.byType(Opacity)).first).opacity;
    expect(opacityOf('Take a '), 0, reason: 'controls are not there yet');
    await tester.pump(const Duration(milliseconds: 700));
    expect(opacityOf('Take 5?'), greaterThan(opacityOf('Take a ')), reason: 'the question lands before the controls');
    await tester.pump(const Duration(seconds: 2));
    expect(opacityOf('Take a '), 1);
    await finish(tester, c);
  });

  testWidgets('"Not now" steps back and leaves the small card waiting', (tester) async {
    final (c, _) = await nudgedApp(tester, const Size(1366, 768), NudgeStyle.fullScreen);
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('Not now'));
    tester.view.physicalSize = const Size(1280, 800);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(find.byType(NudgeTakeover), findsNothing);
    expect(c.read(liveSessionProvider).value?.pendingInterventionId, isNotNull);
    expect(find.byType(NudgeCardView), findsOneWidget, reason: 'it waits as the corner card');
    await finish(tester, c);
  });
}

void settingsNavTests() {
  testWidgets('settings: every entry in the index scrolls its section into view', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = mockContainer(MockBackend(config: const MockConfig(latency: Duration.zero, tick: Duration(hours: 1))));
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const FlowApp()));
    await tester.pump(const Duration(seconds: 4));
    await tester.runAsync(() => c.read(authProvider.notifier).login(email: 'solo@flow.dev', password: 'password'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    c.read(appRouterProvider).go(Routes.settings);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    // index label → a text that only that section's body has
    const sections = {
      'Help': 'Replay the welcome guide',
      'Account': 'Sign out',
      'Agent': 'Agent',
      'Sensors': 'Camera eye signal',
      'Window': 'Closing keeps Flow in the tray',
      'Appearance': 'Light or dark, on this computer.',
      'Quiet hours': 'Quiet hours',
      'Schedules': 'Schedules',
      'Breaks': 'Breaks',
      'Nudges': 'Lock the screen during breaks',
    };
    final viewport = tester.getRect(find.byType(SingleChildScrollView).first);
    for (final e in sections.entries) {
      // the index entry is the first match (it sits left of the sections)
      await tester.tap(find.text(e.key).first);
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      final target = find.text(e.value).last;
      expect(target, findsOneWidget, reason: '${e.key} exists');
      final r = tester.getRect(target);
      expect(r.top, inInclusiveRange(viewport.top - 4, viewport.bottom), reason: '${e.key} is on screen after its index entry is clicked');
    }
    final err = tester.takeException();
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.pump(const Duration(seconds: 1));
    expect(err, isNull);
  });
}

void dialLapTests() {
  Future<int Function()> dial(WidgetTester tester, int start) async {
    var minutes = start;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: StatefulBuilder(
              builder: (context, set) => DurationDial(minutes: minutes, size: 220, onChanged: (m) => set(() => minutes = m)),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    return () => minutes;
  }

  /// Drags round the ring from the [from] o'clock angle by [turn] of a revolution.
  Future<void> sweep(WidgetTester tester, double fromTurn, double turn) async {
    final c = tester.getCenter(find.byType(DurationDial));
    Offset at(double t) => c + Offset(80 * math.sin(t * 2 * math.pi), -80 * math.cos(t * 2 * math.pi));
    final g = await tester.startGesture(at(fromTurn));
    await tester.pump();
    const n = 60;
    for (var i = 1; i <= n; i++) {
      await g.moveTo(at(fromTurn + turn * i / n));
      await tester.pump(const Duration(milliseconds: 4));
    }
    await g.up();
    await tester.pump(const Duration(seconds: 1));
  }

  test('one turn is 3 h; the healthy limit is 4 h', () {
    expect(DurationDial.fullTurn, 180);
    expect(DurationDial.healthyMax, 240);
    expect(const DurationDial(minutes: 50, onChanged: null).max, 240);
  });

  testWidgets('the dial goes past a full turn onto the second ring, and says so', (tester) async {
    final minutes = await dial(tester, 150);
    expect(find.textContaining('HR'), findsNothing);
    // a quarter turn more: 150 → about 195, across the 180 mark
    await sweep(tester, 150 / 180, 0.25);
    expect(minutes(), greaterThan(180));
    expect(minutes(), lessThanOrEqualTo(200));
    expect(find.textContaining('3 HR'), findsOneWidget, reason: 'past a turn the caption gives it in hours');
    // and back under: the caption goes
    await sweep(tester, (minutes() - 180) / 180, -0.2);
    expect(minutes(), lessThan(180));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('HR'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the dial stops at the healthy limit however far it is dragged', (tester) async {
    final minutes = await dial(tester, 170);
    await sweep(tester, 170 / 180, 0.9); // most of another full turn
    expect(minutes(), DurationDial.healthyMax);
    expect(find.textContaining('THE MOST'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tap on the outer ring picks a second-turn value', (tester) async {
    final minutes = await dial(tester, 185);
    final c = tester.getCenter(find.byType(DurationDial));
    // 1 o'clock on the dial = 15 min into a turn; already past a turn, so 195
    await tester.tapAt(c + Offset(98 * math.sin(math.pi / 6), -98 * math.cos(math.pi / 6)));
    await tester.pump(const Duration(seconds: 1));
    expect(minutes(), 195);
  });
}

void appearanceTests() {
  test('time-of-day appearance: light inside the span, dark outside, spans may cross midnight', () {
    const day = DesktopPrefs(appearance: Appearance.schedule, lightFrom: 7 * 60, lightTo: 19 * 60);
    expect(day.lightAt(6 * 60 + 59), isFalse);
    expect(day.lightAt(7 * 60), isTrue);
    expect(day.lightAt(12 * 60), isTrue);
    expect(day.lightAt(19 * 60), isFalse, reason: 'the end is exclusive');
    expect(day.lightAt(23 * 60), isFalse);
    // someone who works nights: light 22:00 → 06:00
    const night = DesktopPrefs(appearance: Appearance.schedule, lightFrom: 22 * 60, lightTo: 6 * 60);
    expect(night.lightAt(23 * 60), isTrue);
    expect(night.lightAt(3 * 60), isTrue);
    expect(night.lightAt(6 * 60), isFalse);
    expect(night.lightAt(12 * 60), isFalse);
  });

  test('theme mode follows the appearance choice, and is remembered', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer.test();
    c.listen(themeModeProvider, (_, _) {});
    expect(c.read(themeModeProvider), ThemeMode.system, reason: 'default: this computer');
    final ctl = c.read(desktopPrefsProvider.notifier);
    await ctl.set(c.read(desktopPrefsProvider).copyWith(appearance: Appearance.dark));
    expect(c.read(themeModeProvider), ThemeMode.dark);
    await ctl.set(c.read(desktopPrefsProvider).copyWith(appearance: Appearance.light));
    expect(c.read(themeModeProvider), ThemeMode.light);
    // by time of day: a span that covers every minute but one is light now
    final now = DateTime.now();
    final m = now.hour * 60 + now.minute;
    await ctl.set(c.read(desktopPrefsProvider).copyWith(appearance: Appearance.schedule, lightFrom: m, lightTo: (m + 60) % 1440));
    expect(c.read(themeModeProvider), ThemeMode.light);
    await ctl.set(c.read(desktopPrefsProvider).copyWith(lightFrom: (m + 120) % 1440, lightTo: (m + 180) % 1440));
    expect(c.read(themeModeProvider), ThemeMode.dark);
    // stored for next launch
    final sp = await SharedPreferences.getInstance();
    expect(sp.getString('flow.desktop.appearance'), 'schedule');
    final c2 = ProviderContainer.test();
    c2.listen(desktopPrefsProvider, (_, _) {});
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(c2.read(desktopPrefsProvider).appearance, Appearance.schedule);
    expect(c2.read(desktopPrefsProvider).lightFrom, (m + 120) % 1440);
  });

  testWidgets('Settings › Appearance: choosing Dark turns the whole app dark, Light turns it back', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = mockContainer(MockBackend(config: const MockConfig(latency: Duration.zero, tick: Duration(hours: 1))));
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const FlowApp()));
    await tester.pump(const Duration(seconds: 4));
    await tester.runAsync(() => c.read(authProvider.notifier).login(email: 'solo@flow.dev', password: 'password'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    c.read(appRouterProvider).go(Routes.settings);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    Brightness app() => Theme.of(tester.element(find.text('Settings').first)).brightness;
    Future<void> choose(String label) async {
      final option = find.text(label).last;
      await tester.ensureVisible(option);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(option);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await choose('Always dark.');
    expect(c.read(desktopPrefsProvider).appearance, Appearance.dark);
    expect(app(), Brightness.dark);
    await choose('Always light.');
    expect(app(), Brightness.light);
    await choose('Light between two times you set, dark for the rest.');
    expect(c.read(desktopPrefsProvider).appearance, Appearance.schedule);
    expect(
      find.byWidgetPredicate((w) => w is TimeRangeSlider && w.semanticLabel == 'Light hours'),
      findsOneWidget,
      reason: 'the hours can be set',
    );
    final err = tester.takeException();
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.pump(const Duration(seconds: 1));
    expect(err, isNull);
  });
}
