import 'package:flow/api/mock/mock_backend.dart';
import 'package:flow/api/models/session.dart';
import 'package:flow/app.dart';
import 'package:flow/desktop/compact_views.dart';
import 'package:flow/desktop/desktop_host.dart';
import 'package:flow/desktop/window_controller.dart';
import 'package:flow/router/app_router.dart';
import 'package:flow/router/routes.dart';
import 'package:flow/state/auth_controller.dart';
import 'package:flow/state/session_controller.dart';
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
      final list = find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first;
      await tester.scrollUntilVisible(row, 300, scrollable: list);
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
