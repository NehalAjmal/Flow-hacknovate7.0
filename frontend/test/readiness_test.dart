import 'package:flow/api/mock/mock_backend.dart';
import 'package:flow/app.dart';
import 'package:flow/state/auth_controller.dart';
import 'package:flow/state/boot.dart';
import 'package:flow/theme/tokens.dart';
import 'package:flow/ui/loading_blocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('durations: one format, the unit after a space, readable in caps', () {
    expect(flowDuration(25), '25 min');
    expect(flowDuration(60), '1 h');
    expect(flowDuration(85), '1 h 25 min');
    expect(flowDuration(125), '2 h 05 min');
    expect(flowDuration(0), '0 min');
    expect(flowDuration(-35), '35 min', reason: 'the sign is the caller\'s to print');
    expect(flowDuration(85, caps: true).toUpperCase(), '1 HR 25 MIN', reason: 'a lone H in caps is hard to read');
  });

  testWidgets('a duration numeral keeps its units small and apart from the numbers', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Center(child: DurationNumeral(85, size: 40)))));
    final rich = tester.widget<RichText>(find.descendant(of: find.byType(DurationNumeral), matching: find.byType(RichText)));
    final spans = <TextSpan>[];
    rich.text.visitChildren((s) {
      if (s is TextSpan && s.text != null) spans.add(s);
      return true;
    });
    final numbers = spans.where((s) => RegExp(r'^\d+$').hasMatch(s.text!)).toList();
    final units = spans.where((s) => s.text == 'h' || s.text == 'min').toList();
    expect([for (final s in numbers) s.text], ['1', '25']);
    expect([for (final s in units) s.text], ['h', 'min']);
    expect(units.first.style!.fontSize!, lessThan(numbers.first.style!.fontSize! * 0.6));
    expect(tester.getSemantics(find.byType(DurationNumeral)).label, '1 h 25 min');
  });

  test('boot: signed out there is nothing to wait for; signed in it waits for Home\'s data, but never past the cap', () async {
    final b = MockBackend(config: const MockConfig(latency: Duration(milliseconds: 60), tick: Duration(hours: 1)));
    final c = mockContainer(b);
    c.listen(authProvider, (_, _) {});
    c.listen(bootReadyProvider, (_, _) {});
    await eventually(() => c.read(authProvider) is SignedOut);
    await c.read(bootReadyProvider.future);
    expect(c.read(bootReadyProvider).isLoading, isFalse);

    await c.read(authProvider.notifier).login(email: 'solo@flow.dev', password: 'password');
    expect(c.read(bootReadyProvider).isLoading, isTrue, reason: 'a new user: load their day first');
    await eventually(() => !c.read(bootReadyProvider).isLoading);

    // a backend that is down must not hold the app closed
    b.scenario = MockScenario.backendDown;
    await c.read(authProvider.notifier).logout().catchError((Object _) {});
    expect(cap, lessThanOrEqualTo(const Duration(seconds: 5)));
    c.dispose();
  });

  testWidgets('after signing in, one loader, then Home arrives whole (no part still loading)', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = mockContainer(MockBackend(config: const MockConfig(latency: Duration(milliseconds: 400), tick: Duration(hours: 1))));
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const FlowApp()));
    await tester.pump(const Duration(seconds: 4));
    await tester.runAsync(() => c.read(authProvider.notifier).login(email: 'solo@flow.dev', password: 'password'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // while Home's data is in flight: exactly the one page loader
    expect(c.read(bootReadyProvider).isLoading, isTrue);
    expect(find.byType(LoadingBlocks), findsOneWidget);
    expect(find.bySemanticsLabel('Getting your day ready'), findsOneWidget);
    // real time for the mock's latency, then frames
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1500)));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(c.read(bootReadyProvider).isLoading, isFalse);
    expect(find.byType(LoadingBlocks), findsNothing, reason: 'Home has everything it needs for its first frame');
    final err = tester.takeException();
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.pump(const Duration(seconds: 1));
    expect(err, isNull);
  });
}
