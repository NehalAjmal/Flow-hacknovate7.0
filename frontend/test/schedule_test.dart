import 'package:flow/api/mock/mock_backend.dart';
import 'package:flow/api/models/day.dart';
import 'package:flow/api/models/schedule.dart';
import 'package:flow/api/models/session.dart';
import 'package:flow/state/auth_controller.dart';
import 'package:flow/state/data_providers.dart';
import 'package:flow/state/schedule_runner.dart';
import 'package:flow/state/session_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Future<ProviderContainer> signedIn(String email) async {
  final c = mockContainer(MockBackend(config: MockConfig.fast));
  c.listen(authProvider, (_, _) {});
  await eventually(() => c.read(authProvider) is SignedOut);
  await c.read(authProvider.notifier).login(email: email, password: 'password');
  c.listen(schedulesProvider, (_, _) {});
  c.listen(liveSessionProvider, (_, _) {});
  c.listen(scheduleRunnerProvider, (_, _) {});
  await c.read(schedulesProvider.future);
  await c.read(liveSessionProvider.future);
  return c;
}

void main() {
  test('schedule model: occurrences only on chosen weekdays', () {
    const s = Schedule(name: 'x', start: '09:30', end: '10:15', weekdays: [1, 3]);
    expect(s.durationMinutes, 45);
    expect(s.on(DateTime(2026, 11, 9)), isNotNull); // Monday
    expect(s.on(DateTime(2026, 11, 10)), isNull); // Tuesday
    expect(s.on(DateTime(2026, 11, 9))!.$1, DateTime(2026, 11, 9, 9, 30));
    expect(Schedule.fromJson(s.toJson()).weekdays, [1, 3]);
  });

  test('create, edit and remove; the day timeline shows the occurrence', () async {
    final c = await signedIn('solo@flow.dev');
    expect(c.read(schedulesProvider).value, hasLength(1)); // seeded "Weekly review"

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final day = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    final s = await c
        .read(schedulesProvider.notifier)
        .add(Schedule(name: 'Deep work', start: '06:00', end: '07:00', weekdays: [day.weekday]));
    expect(c.read(schedulesProvider).value, hasLength(2));

    final tl = await c.read(dayTimelineProvider(day).future);
    expect(tl.sessions.where((x) => x.state == TimelineSessionState.scheduled && x.taskText == 'Deep work'), hasLength(1));

    await c.read(schedulesProvider.notifier).save(s.copyWith(name: 'Writing'));
    expect(c.read(schedulesProvider).value!.any((x) => x.name == 'Writing'), isTrue);

    await c.read(schedulesProvider.notifier).remove(s.id!);
    expect(c.read(schedulesProvider).value, hasLength(1));
  });

  test('runner offers a due routine once, and starting it starts the session', () async {
    final c = await signedIn('new@flow.dev'); // starts with no routines
    final now = DateTime.now();
    final m = now.hour * 60 + now.minute;
    await c
        .read(schedulesProvider.notifier)
        .add(
          Schedule(name: 'Standup prep', start: Schedule.hm(m), end: Schedule.hm(m + 25), weekdays: [now.weekday], demand: Demand.light),
        );

    c.read(scheduleRunnerProvider.notifier).check(now);
    expect(c.read(scheduleRunnerProvider)?.schedule.name, 'Standup prep');

    await c.read(scheduleRunnerProvider.notifier).startNow();
    await eventually(() => c.read(liveSessionProvider).value != null);
    expect(c.read(liveSessionProvider).value!.session.taskText, 'Standup prep');

    // offered once per day, and never while a session runs
    c.read(scheduleRunnerProvider.notifier).check(now);
    expect(c.read(scheduleRunnerProvider), isNull);
  });

  test('skip clears the offer and it is not offered again today', () async {
    final c = await signedIn('new@flow.dev');
    final now = DateTime.now();
    final m = now.hour * 60 + now.minute;
    await c
        .read(schedulesProvider.notifier)
        .add(Schedule(name: 'Admin', start: Schedule.hm(m), end: Schedule.hm(m + 30), weekdays: [now.weekday]));
    final r = c.read(scheduleRunnerProvider.notifier);
    r.check(now);
    expect(c.read(scheduleRunnerProvider), isNotNull);
    r.skip();
    r.check(now);
    expect(c.read(scheduleRunnerProvider), isNull);
    expect(c.read(liveSessionProvider).value, isNull);
  });
}
