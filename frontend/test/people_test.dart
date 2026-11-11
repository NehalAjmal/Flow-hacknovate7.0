import 'package:flow/api/api_connector.dart';
import 'package:flow/api/api_error.dart';
import 'package:flow/api/mock/mock_backend.dart';
import 'package:flow/api/mock/mock_members.dart';
import 'package:flow/api/models/member.dart';
import 'package:flow/app.dart';
import 'package:flow/router/app_router.dart';
import 'package:flow/router/routes.dart';
import 'package:flow/state/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('member JSON: coarse fields only, tolerant of gaps', () {
    final m = MemberSummary.fromJson({
      'id': 'm1',
      'name': 'Ada',
      'focus_by_day': [60, 90],
      'sessions': 3,
      'breaks_taken': 1,
      'breaks_suggested': 2,
      'nudges': {'taken': 1, 'snoozed': 1, 'dismissed': 0},
      'strain': 'moderate',
      // a backend that leaks these must not surface them anywhere
      'task_text': 'secret project',
      'window_title': 'secret.docx',
    });
    expect(m.focusByDay, [60, 90, 0, 0, 0, 0, 0]);
    expect(m.focusMinutes, 150);
    expect(m.nudges.total, 2);
    expect(m.strainRank, 1);
  });

  test('mock members are stable, and differ enough to compare', () {
    final now = DateTime(2026, 11, 12, 17); // a Thursday
    final a = mockMembers(small: false, now: now), b = mockMembers(small: false, now: now);
    expect(a.length, 8);
    expect([for (final m in a) m.focusMinutes], [for (final m in b) m.focusMinutes]);
    expect(a.map((m) => m.strain).toSet().length, greaterThan(1));
    for (final m in a) {
      expect(m.focusByDay.sublist(4), everyElement(0), reason: 'Fri–Sun have not happened yet');
    }
    expect(mockMember('m_ada', now: now)!.days.length, 7);
    expect(mockMember('nobody', now: now), isNull);
  });

  test('only an admin can list people or open a person', () async {
    final b = MockBackend(config: MockConfig.fast);
    final c = mockContainer(b);
    c.listen(authProvider, (_, _) {});
    await eventually(() => c.read(authProvider) is SignedOut);
    await c.read(authProvider.notifier).login(email: 'employee@flow.dev', password: 'password');
    await expectLater(c.read(adminApiProvider).members(), throwsA(isA<ApiError>()));
    await expectLater(c.read(adminApiProvider).member('m_ada'), throwsA(isA<ApiError>()));
    await c.read(authProvider.notifier).logout();
    await c.read(authProvider.notifier).login(email: 'admin@flow.dev', password: 'password');
    await c.read(authProvider.notifier).verifyMfa(MockBackend.mfaCode);
    expect(await c.read(adminApiProvider).members(), hasLength(8));
    final before = b.audit.length;
    await c.read(adminApiProvider).member('m_ada');
    expect(b.audit.length, before + 1, reason: 'opening a person is recorded');
    expect(b.audit.first.action, 'member.view');
    c.dispose();
  });

  for (final size in const [Size(1024, 700), Size(1440, 900)]) {
    for (final route in [Routes.adminPeople, Routes.adminPerson('m_ben')]) {
      testWidgets('$route lays out at ${size.width.toInt()}×${size.height.toInt()}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final c = mockContainer(MockBackend(config: const MockConfig(latency: Duration.zero, tick: Duration(hours: 1))));
        await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const FlowApp()));
        await tester.pump(const Duration(seconds: 4));
        await tester.runAsync(() async {
          await c.read(authProvider.notifier).login(email: 'admin@flow.dev', password: 'password');
          await c.read(authProvider.notifier).verifyMfa(MockBackend.mfaCode);
        });
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        c.read(appRouterProvider).go(route);
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 150));
        }
        if (route == Routes.adminPeople) {
          expect(find.text('Ben Hartmann'), findsOneWidget);
          await tester.tap(find.text('Ben Hartmann'));
          for (var i = 0; i < 10; i++) {
            await tester.pump(const Duration(milliseconds: 150));
          }
          expect(c.read(appRouterProvider).state.uri.path, Routes.adminPerson('m_ben'));
        } else {
          expect(find.text('Ben Hartmann'), findsOneWidget);
          expect(find.textContaining('never what anyone works on'), findsOneWidget);
        }
        final err = tester.takeException();
        await tester.pumpWidget(const SizedBox());
        c.dispose();
        await tester.pump(const Duration(seconds: 1));
        expect(err, isNull);
      });
    }
  }

  testWidgets('a non-admin is sent away from the People pages', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = mockContainer(MockBackend(config: const MockConfig(latency: Duration.zero, tick: Duration(hours: 1))));
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const FlowApp()));
    await tester.pump(const Duration(seconds: 4));
    await tester.runAsync(() => c.read(authProvider.notifier).login(email: 'employee@flow.dev', password: 'password'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    c.read(appRouterProvider).go(Routes.adminPerson('m_ada'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(c.read(appRouterProvider).state.uri.path, Routes.home);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.pump(const Duration(seconds: 1));
  });
}
