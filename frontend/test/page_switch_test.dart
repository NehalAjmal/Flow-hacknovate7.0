import 'package:flow/api/mock/mock_backend.dart';
import 'package:flow/api/models/session.dart';
import 'package:flow/app.dart';
import 'package:flow/router/app_router.dart';
import 'package:flow/router/routes.dart';
import 'package:flow/state/auth_controller.dart';
import 'package:flow/state/data_providers.dart';
import 'package:flow/state/session_controller.dart';
import 'package:flow/ui/loading_blocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// Page switches must feel instant: no loader on a revisit, no loader flash
/// for fast loads, and live changes refresh in place.
void main() {
  devLoaderTests();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ProviderContainer> boot(WidgetTester tester, {Duration latency = Duration.zero}) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = mockContainer(MockBackend(config: MockConfig(latency: latency, tick: const Duration(hours: 1))));
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const FlowApp()));
    await tester.pump(const Duration(seconds: 4));
    await tester.runAsync(() => c.read(authProvider.notifier).login(email: 'solo@flow.dev', password: 'password'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    return c;
  }

  Future<void> go(WidgetTester tester, ProviderContainer c, String route) async {
    c.read(appRouterProvider).go(route);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> done(WidgetTester tester, ProviderContainer c) async {
    final err = tester.takeException();
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.pump(const Duration(seconds: 1));
    expect(err, isNull);
  }

  /// Is any loader actually visible (past its grace period)?
  bool loaderVisible(WidgetTester tester) => tester
      .widgetList<AnimatedOpacity>(find.descendant(of: find.byType(LoadingBlocks), matching: find.byType(AnimatedOpacity)))
      .any((o) => o.opacity > 0);

  testWidgets('going back to a page shows it at once (data kept, no loader)', (tester) async {
    final c = await boot(tester);
    await go(tester, c, Routes.patterns);
    await go(tester, c, Routes.home);
    c.read(appRouterProvider).go(Routes.patterns);
    // the very first frames of the revisit
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(LoadingBlocks), findsNothing, reason: 'cached data, no loader on a revisit');
    }
    await done(tester, c);
  });

  testWidgets('a load faster than the grace period never shows the loader', (tester) async {
    final c = await boot(tester, latency: const Duration(milliseconds: 120));
    c.read(appRouterProvider).go(Routes.patterns);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      expect(loaderVisible(tester), isFalse);
    }
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump(const Duration(milliseconds: 100));
    await done(tester, c);
  });

  testWidgets('a slow load does show the loader, after the grace period', (tester) async {
    final c = await boot(tester);
    // the loader itself, as a slow page would show it
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: LoadingBlocks(height: 120))));
    await tester.pump(const Duration(milliseconds: 100));
    expect(loaderVisible(tester), isFalse);
    await tester.pump(LoadingGrace.delay);
    expect(loaderVisible(tester), isTrue);
    await done(tester, c);
  });

  testWidgets('starting a session refreshes Home in place (no loader)', (tester) async {
    final c = await boot(tester);
    await go(tester, c, Routes.home);
    expect(find.byType(LoadingBlocks), findsNothing);
    await tester.runAsync(
      () => c.read(liveSessionProvider.notifier).start(const StartSessionRequest(taskText: 'x', demand: Demand.moderate, plannedMinutes: 50)),
    );
    c.read(appRouterProvider).go(Routes.home); // stay on Home (start navigates to the focus page)
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      // not even mounted: a hidden loader still blanks the content it replaced
      expect(find.byType(LoadingBlocks), findsNothing);
    }
    await done(tester, c);
  });
}

void devLoaderTests() {
  testWidgets('dev panel: latency + "Forget cached pages" make the loader visible', (tester) async {
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
    c.read(appRouterProvider).go(Routes.patterns);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    b.latencyOverride = const Duration(milliseconds: 800);
    c.read(cacheEpochProvider.notifier).bump();
    await tester.pump(const Duration(milliseconds: 16)); // the reload mounts the loaders
    await tester.pump(const Duration(milliseconds: 400)); // past the grace
    final shown = tester
        .widgetList<AnimatedOpacity>(find.descendant(of: find.byType(LoadingBlocks), matching: find.byType(AnimatedOpacity)))
        .any((o) => o.opacity > 0);
    expect(shown, isTrue);
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.pump(const Duration(seconds: 1));
  });
}
