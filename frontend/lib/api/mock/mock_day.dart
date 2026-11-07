// DEV ONLY. Deterministic, realistic day timelines for the Day Score.
import 'dart:math' as math;

import '../models/day.dart';
import '../models/insights.dart';
import '../models/session.dart';
import 'mock_backend.dart';

DateTime _at(DateTime d, int h, [int m = 0]) => DateTime(d.year, d.month, d.day, h, m);

/// A typical working pattern; varied per day by a date-seeded RNG so every
/// day looks different but the same day always looks the same.
List<(int, int, int, int, Demand, String)> _template(math.Random r) {
  final shift = r.nextInt(3) * 10; // 0/10/20 min later start
  final names = ['Auth refactor', 'Spec writing', 'Review PRs', 'Bug triage', 'Design notes', 'Tests'];
  return [
    (9, shift, 9, 50 + shift ~/ 2, Demand.moderate, names[r.nextInt(names.length)]),
    (10, shift ~/ 2, 10, 45 + shift ~/ 2, Demand.heavy, names[r.nextInt(names.length)]),
    (10, 55 + shift ~/ 4, 11, 40 + shift ~/ 4, Demand.moderate, names[r.nextInt(names.length)]),
    (13, 5, 13, 55, Demand.light, names[r.nextInt(names.length)]),
    (14, 5, 14, 40, Demand.heavy, names[r.nextInt(names.length)]),
    (15, 50, 16, 40, Demand.moderate, names[r.nextInt(names.length)]),
  ];
}

const _rate = {Demand.light: 0.45, Demand.moderate: 0.62, Demand.heavy: 0.95}; // per hour
const _recovery = 1.1; // per hour of break

DayTimeline mockDay(MockBackend b, DateTime date, {required bool newUser, DateTime? nowOverride}) {
  final now = nowOverride ?? DateTime.now();
  final day = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  final isToday = day == today;
  final isFuture = day.isAfter(today);
  final r = math.Random(day.millisecondsSinceEpoch ~/ 86400000);

  final sessions = <TimelineSession>[];
  final breaks = <TimelineBreak>[];
  final nudges = <TimelineNudge>[];
  final pressure = <PressurePoint>[];
  final meetings = [
    TimelineMeeting(start: _at(day, 12, 0), end: _at(day, 12, 45), title: 'Lunch & learn'),
    TimelineMeeting(start: _at(day, 17, 0), end: _at(day, 17, 30), title: 'Team sync'),
  ];

  if (!newUser && !isFuture) {
    var p = 0.1;
    var lastEnd = _at(day, 8, 30);
    pressure.add(PressurePoint(lastEnd, p));
    for (final (sh, sm, eh, em, dmd, task) in _template(r)) {
      final start = _at(day, sh, sm), end = _at(day, eh, em);
      if (isToday && !end.isBefore(now)) break; // only finished ones; the active one comes from the run
      final gapH = start.difference(lastEnd).inMinutes / 60;
      p = math.max(0.08, p - _recovery * gapH);
      pressure.add(PressurePoint(start, p));
      // rise during the session; if it crosses the line, a nudge fires there
      final durH = end.difference(start).inMinutes / 60;
      final peak = p + _rate[dmd]! * durH;
      if (peak >= 1.0) {
        final crossH = (1.0 - p) / _rate[dmd]!;
        final crossAt = start.add(Duration(minutes: (crossH * 60).round()));
        pressure.add(PressurePoint(crossAt, 1.0));
        final outcome = r.nextDouble() < 0.75 ? NudgeOutcome.taken : NudgeOutcome.snoozed;
        nudges.add(TimelineNudge(at: crossAt, outcome: outcome));
        pressure.add(PressurePoint(end, 0.97));
        p = 0.97;
      } else {
        pressure.add(PressurePoint(end, peak));
        p = peak;
      }
      sessions.add(
        TimelineSession(id: 'tl_${day.day}_$sh$sm', start: start, end: end, demand: dmd, state: TimelineSessionState.done, taskText: task),
      );
      breaks.add(
        TimelineBreak(at: end.add(const Duration(minutes: 3)), mark: r.nextDouble() < 0.8 ? BreakMark.taken : BreakMark.suggested),
      );
      lastEnd = end;
    }

    // the active session (today only) from the mock run
    final run = b.run;
    if (isToday && run != null) {
      final s = run.session;
      final gapH = s.startedAt.difference(lastEnd).inMinutes / 60;
      p = math.max(0.08, p - _recovery * gapH);
      pressure.add(PressurePoint(s.startedAt, p));
      final elapsedH = now.difference(s.startedAt).inSeconds / 3600;
      pressure.add(PressurePoint(now, math.min(1.05, p + (_rate[s.demand]! * elapsedH) + run.status.combinedScore * 0.15)));
      sessions.add(
        TimelineSession(
          id: s.sessionId,
          start: s.startedAt,
          end: s.startedAt.add(Duration(minutes: s.plannedMinutes)),
          demand: s.demand,
          state: TimelineSessionState.active,
          taskText: s.taskText,
        ),
      );
      if (s.pendingInterventionId != null) nudges.add(TimelineNudge(at: now, outcome: NudgeOutcome.pending));
    } else if (isToday) {
      final gapH = now.difference(lastEnd).inMinutes / 60;
      pressure.add(PressurePoint(now, math.max(0.08, p - _recovery * gapH)));
    }
  }

  // forecast (today: from now; future days: a planned shape) + scheduled sessions
  final forecast = <PressurePoint>[];
  final band = <BandPoint>[];
  if ((isToday || isFuture) && !newUser) {
    final from = isToday ? now : _at(day, 9);
    final startV = pressure.isNotEmpty ? pressure.last.v : 0.2;
    final shape = [0.0, 0.35, 0.55, 0.9, 1.4, 2.2, 3.0];
    final vals = [startV, math.min(1.0, startV + 0.25), 0.55, 0.85, 0.4, 0.62, 0.5];
    for (var i = 0; i < shape.length; i++) {
      final t = from.add(Duration(minutes: (shape[i] * 60).round()));
      forecast.add(PressurePoint(t, vals[i]));
      final spread = 0.05 + 0.06 * shape[i];
      band.add(BandPoint(t, math.max(0, vals[i] - spread), math.min(1.2, vals[i] + spread)));
    }
    final fStart = from.add(const Duration(minutes: 38));
    sessions.add(
      TimelineSession(
        id: null,
        start: fStart,
        end: fStart.add(const Duration(minutes: 50)),
        demand: Demand.moderate,
        state: TimelineSessionState.forecast,
      ),
    );
  }

  // scheduled sessions come from the user's routines (Settings › Schedules)
  final user = b.currentUserId == null ? null : b.users.values.where((u) => u.id == b.currentUserId).firstOrNull;
  if (user != null && (isToday || isFuture)) {
    for (final sc in b.schedulesFor(user)) {
      final occ = sc.on(day);
      if (occ == null || !occ.$2.isAfter(isToday ? now : occ.$1)) continue;
      sessions.add(
        TimelineSession(id: sc.id, start: occ.$1, end: occ.$2, demand: sc.demand, state: TimelineSessionState.scheduled, taskText: sc.name),
      );
    }
  }

  // usual band: shown once there is history
  final usual = <BandPoint>[];
  final usualDays = newUser ? 0 : 12;
  if (usualDays > 0) {
    for (var m = 8 * 60 + 30; m <= 19 * 60; m += 15) {
      final x = (m - 8 * 60 - 30) / 60;
      final mid = 0.32 + 0.25 * math.sin(x * 1.25).abs();
      usual.add(BandPoint(_at(day, m ~/ 60, m % 60), math.max(0, mid - 0.14), mid + 0.14));
    }
  }

  final done = sessions.where((s) => s.state == TimelineSessionState.done);
  final active = sessions.where((s) => s.state == TimelineSessionState.active);
  final focus =
      done.fold<int>(0, (a, s) => a + s.duration.inMinutes) + active.fold<int>(0, (a, s) => a + now.difference(s.start).inMinutes);
  return DayTimeline(
    date: day,
    sessions: sessions,
    breaks: breaks,
    nudges: nudges,
    meetings: meetings,
    pressure: pressure,
    forecast: forecast,
    forecastBand: band,
    forecastConfidence: forecast.isEmpty ? null : Confidence.medium,
    usualBand: usual,
    usualDays: usualDays,
    totals: DayTotals(
      focusMinutes: focus,
      usualFocusMinutes: usualDays > 0 ? 180 : null,
      breaksTaken: breaks.where((x) => x.mark == BreakMark.taken).length,
      breaksSuggested: breaks.length,
      breaksSkipped: breaks.where((x) => x.mark != BreakMark.taken).length,
    ),
  );
}

Map<DateTime, int> mockMonth(DateTime month, {required bool newUser}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final out = <DateTime, int>{};
  final days = DateTime(month.year, month.month + 1, 0).day;
  for (var d = 1; d <= days; d++) {
    final day = DateTime(month.year, month.month, d);
    if (day.isAfter(today)) continue;
    final r = math.Random(day.millisecondsSinceEpoch ~/ 86400000);
    final weekend = day.weekday >= 6;
    if (newUser) {
      if (today.difference(day).inDays < 2) out[day] = 40 + r.nextInt(60);
      continue;
    }
    out[day] = weekend ? (r.nextDouble() < 0.3 ? 30 + r.nextInt(60) : 0) : 90 + r.nextInt(170);
  }
  return out;
}
