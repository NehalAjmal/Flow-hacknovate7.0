import 'package:flow/api/mock/mock_backend.dart';
import 'package:flow/app.dart';
import 'package:flow/router/app_router.dart';
import 'package:flow/router/routes.dart';
import 'package:flow/state/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Every screen, at a small and a large window, must lay out without
/// overflow or exceptions (release builds hide these, so check them here).
void main() {
  const sizes = [Size(1024, 700), Size(1440, 900)];
  const byRole = {
    'solo@flow.dev': [
      Routes.home,
      Routes.patterns,
      Routes.settings,
      Routes.privacy,
      Routes.feedback,
      Routes.sessionActive,
      '/session/end/s-demo',
      '/nope',
    ],
    'employee@flow.dev': [Routes.team],
    'new@flow.dev': [Routes.guide],
  };

  for (final size in sizes) {
    for (final entry in byRole.entries) {
      for (final route in entry.value) {
        testWidgets('${entry.key} $route at ${size.width.toInt()}×${size.height.toInt()}', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          final b = MockBackend(
            config: const MockConfig(latency: Duration.zero, tick: Duration(hours: 1)),
          );
          final c = mockContainer(b);
          await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const FlowApp()));
          await tester.pump(const Duration(seconds: 4)); // launch overlay

          await tester.runAsync(() => c.read(authProvider.notifier).login(email: entry.key, password: 'password'));
          for (var i = 0; i < 10; i++) {
            await tester.pump(const Duration(milliseconds: 200));
          }
          c.read(appRouterProvider).go(route);
          for (var i = 0; i < 20; i++) {
            await tester.pump(const Duration(milliseconds: 150));
          }
          final err = tester.takeException();
          await tester.pumpWidget(const SizedBox());
          c.dispose();
          await tester.pump(const Duration(seconds: 1));
          expect(err, isNull);
        });
      }
    }
  }

  testWidgets('admin screen at 1024×700', (tester) async {
    tester.view.physicalSize = const Size(1024, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final b = MockBackend(
      config: const MockConfig(latency: Duration.zero, tick: Duration(hours: 1)),
    );
    final c = mockContainer(b);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const FlowApp()));
    await tester.pump(const Duration(seconds: 4));
    await tester.runAsync(() async {
      await c.read(authProvider.notifier).login(email: 'admin@flow.dev', password: 'password');
      await c.read(authProvider.notifier).verifyMfa(MockBackend.mfaCode);
    });
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    c.read(appRouterProvider).go(Routes.admin);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    final err = tester.takeException();
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.pump(const Duration(seconds: 1));
    expect(err, isNull);
  });
}
