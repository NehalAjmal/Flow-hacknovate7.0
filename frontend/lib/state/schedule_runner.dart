import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/models/schedule.dart';
import '../api/models/session.dart';
import 'account_controllers.dart';
import 'auth_controller.dart';
import 'data_providers.dart';
import 'session_controller.dart';

/// A routine that is about to start: shown as "starts in N s · Start now · Skip".
class PendingStart {
  const PendingStart(this.schedule, this.at);
  final Schedule schedule;
  final DateTime at;
}

/// Offers scheduled sessions on time (spec §3: "Starting in 10 s · Skip").
/// Checks every 15 s; a routine is offered once per day, only when no session
/// runs and Flow isn't paused; it starts by itself after the countdown.
class ScheduleRunner extends Notifier<PendingStart?> {
  static const countdown = Duration(seconds: 10);
  static const window = Duration(minutes: 2); // late by up to this still counts

  Timer? _tick;
  Timer? _fire;
  final _handled = <String>{}; // "id@yyyy-mm-dd"

  @override
  PendingStart? build() {
    ref.onDispose(() {
      _tick?.cancel();
      _fire?.cancel();
    });
    if (ref.watch(currentUserIdProvider) == null) return null;
    _tick = Timer.periodic(const Duration(seconds: 15), (_) => check());
    return null;
  }

  static String _key(Schedule s, DateTime d) => '${s.id}@${d.year}-${d.month}-${d.day}';

  /// Public for tests: looks for a routine due now.
  void check([DateTime? nowOverride]) {
    if (state != null) return;
    final now = nowOverride ?? DateTime.now();
    if (ref.read(liveSessionProvider).value != null) return;
    if (ref.read(pauseProvider).value?.paused ?? false) return;
    for (final s in ref.read(schedulesProvider).value ?? const <Schedule>[]) {
      final occ = s.on(now);
      if (occ == null || _handled.contains(_key(s, now))) continue;
      final late = now.difference(occ.$1);
      if (late >= -countdown && late <= window) {
        _handled.add(_key(s, now));
        state = PendingStart(s, now.add(countdown));
        _fire = Timer(countdown, startNow);
        return;
      }
    }
  }

  Future<void> startNow() async {
    final p = state;
    _fire?.cancel();
    state = null;
    if (p == null || ref.read(liveSessionProvider).value != null) return;
    await ref
        .read(liveSessionProvider.notifier)
        .start(StartSessionRequest(taskText: p.schedule.name, demand: p.schedule.demand, plannedMinutes: p.schedule.durationMinutes));
  }

  void skip() {
    _fire?.cancel();
    state = null;
  }
}

final scheduleRunnerProvider = NotifierProvider<ScheduleRunner, PendingStart?>(ScheduleRunner.new);
