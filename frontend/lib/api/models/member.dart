import '../../core/json.dart';
import 'day.dart';
import 'session.dart';
import 'team.dart';

/// Per-person data for the team's admin (GET /admin/members…).
///
/// Admin only. People join a team through an invite that says the admin can
/// see this. It is deliberately coarse: time, counts and responses. Never
/// task text, window titles, apps, typing or camera data — those fields do
/// not exist in these models, so the UI cannot show them by accident.

class NudgeResponses {
  const NudgeResponses({required this.taken, required this.snoozed, required this.dismissed});
  final int taken;
  final int snoozed;
  final int dismissed;

  int get total => taken + snoozed + dismissed;

  factory NudgeResponses.fromJson(Json j) => NudgeResponses(
    taken: intOrNull(j['taken']) ?? 0,
    snoozed: intOrNull(j['snoozed']) ?? 0,
    dismissed: intOrNull(j['dismissed']) ?? 0,
  );
}

/// One person's week at a glance (a row on the People page).
class MemberSummary {
  const MemberSummary({
    required this.id,
    required this.name,
    required this.focusByDay,
    required this.sessions,
    required this.breaksTaken,
    required this.breaksSuggested,
    required this.nudges,
    required this.strain,
    this.lastActiveAt,
    this.inSession = false,
  });

  final String id;
  final String name;

  /// Focus minutes Mon..Sun of the current week (always 7 entries).
  final List<int> focusByDay;
  final int sessions;
  final int breaksTaken;
  final int breaksSuggested;
  final NudgeResponses nudges;

  /// `low` | `moderate` | `high`: break pressure, not a health measure.
  final String strain;
  final DateTime? lastActiveAt;
  final bool inSession;

  int get focusMinutes => focusByDay.fold(0, (a, b) => a + b);
  int get strainRank => switch (strain) {
    'high' => 2,
    'moderate' => 1,
    _ => 0,
  };

  factory MemberSummary.fromJson(Json j) {
    final days = intList(j['focus_by_day']);
    return MemberSummary(
      id: reqStr(j, 'id'),
      name: str(j['name']) ?? 'Unnamed',
      focusByDay: [for (var i = 0; i < 7; i++) i < days.length ? days[i] : 0],
      sessions: intOrNull(j['sessions']) ?? 0,
      breaksTaken: intOrNull(j['breaks_taken']) ?? 0,
      breaksSuggested: intOrNull(j['breaks_suggested']) ?? 0,
      nudges: NudgeResponses.fromJson(asJson(j['nudges'] ?? const <String, Object?>{})),
      strain: str(j['strain']) ?? 'low',
      lastActiveAt: dateOrNull(j['last_active_at']),
      inSession: boolOr(j['in_session'], false),
    );
  }
}

class MemberSession {
  const MemberSession({required this.start, required this.end, required this.demand});
  final DateTime start;
  final DateTime end;
  final Demand demand;

  factory MemberSession.fromJson(Json j) => MemberSession(
    start: dateOrNull(j['start']) ?? DateTime.now(),
    end: dateOrNull(j['end']) ?? DateTime.now(),
    demand: enumFromWire(Demand.values, j['demand'], Demand.moderate),
  );
}

class MemberDay {
  const MemberDay({required this.date, required this.sessions, required this.breaks, required this.nudges});
  final DateTime date;
  final List<MemberSession> sessions;
  final List<TimelineBreak> breaks;
  final List<TimelineNudge> nudges;

  int get focusMinutes => sessions.fold(0, (a, s) => a + s.end.difference(s.start).inMinutes);

  factory MemberDay.fromJson(Json j) => MemberDay(
    date: dateOrNull(j['date']) ?? DateTime.now(),
    sessions: asJsonList(j['sessions']).map(MemberSession.fromJson).toList(),
    breaks: asJsonList(j['breaks']).map(TimelineBreak.fromJson).toList(),
    nudges: asJsonList(j['nudges']).map(TimelineNudge.fromJson).toList(),
  );
}

/// One person's page: their week as timelines, plus two trends.
class MemberDetail {
  const MemberDetail({required this.summary, required this.days, required this.focusTrend, required this.strainTrend});
  final MemberSummary summary;

  /// Mon..Sun of the current week.
  final List<MemberDay> days;

  /// Focus minutes per day, last 30 days.
  final List<TrendPoint> focusTrend;

  /// Break pressure 0..1 per day, last 14 days.
  final List<TrendPoint> strainTrend;

  factory MemberDetail.fromJson(Json j) => MemberDetail(
    summary: MemberSummary.fromJson(asJson(j['summary'])),
    days: asJsonList(j['days']).map(MemberDay.fromJson).toList(),
    focusTrend: asJsonList(j['focus_trend']).map(TrendPoint.fromJson).toList(),
    strainTrend: asJsonList(j['strain_trend']).map(TrendPoint.fromJson).toList(),
  );
}
