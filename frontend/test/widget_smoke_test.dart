import 'package:flow/api/mock/mock_backend.dart';
import 'package:flow/app.dart';
import 'package:flow/ui/pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('boots to welcome, signs in, lands on home with sensing chips', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final backend = MockBackend(
      config: const MockConfig(latency: Duration.zero, tick: Duration(hours: 1)),
    );
    await tester.pumpWidget(ProviderScope(overrides: mockOverrides(backend), retry: (_, _) => null, child: const FlowApp()));
    // Launch overlay is up on the first frame, gone once it has played.
    await tester.pump();
    expect(find.bySemanticsLabel('Flow is starting'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Flow is starting'), findsNothing);
    expect(find.text('Welcome to Flow'), findsOneWidget);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'solo@flow.dev');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'password');
    await tester.tap(find.widgetWithText(Pressable, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.textContaining(', Sam'), findsOneWidget);
    expect(find.textContaining('BEHAVIOR'), findsWidgets);
    expect(find.textContaining('Start · ends'), findsOneWidget);
    expect(find.text('LOOK BACK'), findsOneWidget);

    // Unmount so providers dispose their timers before the test ends.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('launch overlay: a tap skips the draw-in', (tester) async {
    final backend = MockBackend(
      config: const MockConfig(latency: Duration.zero, tick: Duration(hours: 1)),
    );
    await tester.pumpWidget(ProviderScope(overrides: mockOverrides(backend), retry: (_, _) => null, child: const FlowApp()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(const Offset(10, 10));
    // Skipped to the reveal: done well before the full ~2.4 s timeline.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.bySemanticsLabel('Flow is starting'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('new user is sent to consent and cannot continue without behavior', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final backend = MockBackend(
      config: const MockConfig(latency: Duration.zero, tick: Duration(hours: 1)),
    );
    await tester.pumpWidget(ProviderScope(overrides: mockOverrides(backend), retry: (_, _) => null, child: const FlowApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'new@flow.dev');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'password');
    await tester.tap(find.widgetWithText(Pressable, 'Sign in'));
    await tester.pumpAndSettle();

    // New users land on the welcome guide; step 2 holds the required consent.
    expect(find.text('What Flow does'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('What Flow may use'), findsOneWidget);
    expect(find.text('Behavior sensing is needed to use Flow'), findsOneWidget);
    // Next and Skip cannot pass the consent step yet
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('What Flow may use'), findsOneWidget);

    await tester.tap(find.text('Behavior sensing (required)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip setup'));
    await tester.pumpAndSettle();
    expect(find.textContaining(', Nia'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
