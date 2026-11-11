import 'dart:math' as math;

import '../models/day.dart';
import '../models/member.dart';
import '../models/session.dart';
import '../models/team.dart';

/// Deterministic team members for the mock admin People pages. Each has a
/// working style, so the comparison shows real differences: a steady one, one
/// who skips breaks and runs hot, a part-timer, a late starter…
class _Style {
  const _Style(this.id, this.name, {required this.start, required this.perDay, required this.length, required this.takes, this.days = 5});
  final String id;
  final String name;
  final int start; // first session, hour
  final int perDay; // sessions on a working day
  final int length; // typical session minutes
  final double takes; // share of nudges answered with a break
  final int days; // working days per week
}

const _styles = [
  _Style('m_ada', 'Ada Okafor', start: 9, perDay: 4, length: 50, takes: 0.8),
  _Style('m_ben', 'Ben Hartmann', start: 8, perDay: 5, length: 75, takes: 0.25),
  _Style('m_chloe', 'Chloé Martin', start: 10, perDay: 3, length: 45, takes: 0.7),
  _Style('m_dev', 'Dev Patel', start: 9, perDay: 4, length: 60, takes: 0.55),
  _Style('m_elif', 'Elif Kaya', start: 11, perDay: 3, length: 40, takes: 0.9, days: 3),
  _Style('m_femi', 'Femi Adeyemi', start: 8, perDay: 4, length: 55, takes: 0.6),
  _Style('m_gwen', 'Gwen Li', start: 9, perDay: 5, length: 65, takes: 0.35),
  _Style('m_hugo', 'Hugo Silva', start: 10, perDay: 2, length: 35, takes: 0.75, days: 4),
];

DateTime _monday(DateTime now) {
  final d = DateTime(now.year, now.month, now.day);
  return d.subtract(Duration(days: d.weekday - 1));
}

MemberDay _day(_Style s, int index, DateTime date, DateTime now) {
  final r = math.Random(s.id.hashCode ^ (date.day * 31 + date.month * 977));
  final sessions = <MemberSession>[];
  final breaks = <TimelineBreak>[];
  final nudges = <TimelineNudge>[];
  final works = date.weekday <= s.days && !date.isAfter(now);
  if (works) {
    var t = DateTime(date.year, date.month, date.day, s.start, r.nextInt(30));
    for (var i = 0; i < s.perDay; i++) {
      final len = (s.length * (0.7 + r.nextDouble() * 0.6)).round();
      final end = t.add(Duration(minutes: len));
      if (end.isAfter(now)) break;
      sessions.add(MemberSession(start: t, end: end, demand: Demand.values[(i + index) % Demand.values.length]));
      if (len >= 40) {
        final at = t.add(Duration(minutes: (len * 0.8).round()));
        final roll = r.nextDouble();
        final outcome = roll < s.takes
            ? NudgeOutcome.taken
            : roll < s.takes + (1 - s.takes) * 0.5
            ? NudgeOutcome.snoozed
            : NudgeOutcome.dismissed;
        nudges.add(TimelineNudge(at: at, outcome: outcome));
        breaks.add(
          TimelineBreak(
            at: outcome == NudgeOutcome.taken ? end : at,
            mark: switch (outcome) {
              NudgeOutcome.taken => BreakMark.taken,
              NudgeOutcome.snoozed => BreakMark.snoozed,
              _ => BreakMark.suggested,
            },
          ),
        );
      }
      t = end.add(Duration(minutes: 10 + r.nextInt(35)));
    }
  }
  return MemberDay(date: date, sessions: sessions, breaks: breaks, nudges: nudges);
}

List<MemberDay> _week(_Style s, DateTime now) {
  final mon = _monday(now);
  return [for (var i = 0; i < 7; i++) _day(s, i, mon.add(Duration(days: i)), now)];
}

MemberSummary _summary(_Style s, List<MemberDay> week, DateTime now) {
  var taken = 0, snoozed = 0, dismissed = 0;
  for (final d in week) {
    for (final n in d.nudges) {
      switch (n.outcome) {
        case NudgeOutcome.taken:
          taken++;
        case NudgeOutcome.snoozed:
          snoozed++;
        default:
          dismissed++;
      }
    }
  }
  final total = taken + snoozed + dismissed;
  final skipped = total == 0 ? 0.0 : 1 - taken / total;
  final load = week.fold(0, (a, d) => a + d.focusMinutes) / (5 * 300);
  final pressure = skipped * 0.6 + load.clamp(0.0, 1.0) * 0.4;
  final last = week.expand((d) => d.sessions).fold<DateTime?>(null, (a, x) => a == null || x.end.isAfter(a) ? x.end : a);
  return MemberSummary(
    id: s.id,
    name: s.name,
    focusByDay: [for (final d in week) d.focusMinutes],
    sessions: week.fold(0, (a, d) => a + d.sessions.length),
    breaksTaken: taken,
    breaksSuggested: total,
    nudges: NudgeResponses(taken: taken, snoozed: snoozed, dismissed: dismissed),
    strain: pressure > 0.62
        ? 'high'
        : pressure > 0.42
        ? 'moderate'
        : 'low',
    lastActiveAt: last,
    inSession: last != null && now.difference(last).inMinutes < 12,
  );
}

List<MemberSummary> mockMembers({required bool small, DateTime? now}) {
  final n = now ?? DateTime.now();
  return [for (final s in small ? _styles.take(3) : _styles) _summary(s, _week(s, n), n)];
}

MemberDetail? mockMember(String id, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final s = _styles.where((x) => x.id == id).firstOrNull;
  if (s == null) return null;
  final week = _week(s, n);
  final today = DateTime(n.year, n.month, n.day);
  final r = math.Random(s.id.hashCode);
  return MemberDetail(
    summary: _summary(s, week, n),
    days: week,
    focusTrend: [
      for (var i = 29; i >= 0; i--)
        TrendPoint(
          date: today.subtract(Duration(days: i)),
          value: today.subtract(Duration(days: i)).weekday <= s.days ? s.perDay * s.length * (0.7 + r.nextDouble() * 0.5) : 0,
        ),
    ],
    strainTrend: [
      for (var i = 13; i >= 0; i--)
        TrendPoint(
          date: today.subtract(Duration(days: i)),
          value: ((1 - s.takes) * 0.75 + (r.nextDouble() - 0.5) * 0.22 + (13 - i) * 0.006).clamp(0.05, 0.98),
        ),
    ],
  );
}
