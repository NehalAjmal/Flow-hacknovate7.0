import '../../core/json.dart';
import 'insights.dart';
import 'session.dart';

/// GET /user/day?date=YYYY-MM-DD: everything the Day Score draws for one day.
/// Pressure values are normalised so that **1.0 = the nudge line**.

enum TimelineSessionState implements WireEnum {
  done('done'),
  active('active'),
  forecast('forecast'),
  scheduled('scheduled');

  const TimelineSessionState(this.wire);
  @override
  final String wire;
}

class TimelineSession {
  const TimelineSession({
    required this.id,
    required this.start,
    required this.end,
    required this.demand,
    required this.state,
    this.taskText,
  });

  final String? id;
  final DateTime start;

  /// For the active session: its planned end.
  final DateTime end;
  final Demand demand;
  final TimelineSessionState state;
  final String? taskText;

  Duration get duration => end.difference(start);

  factory TimelineSession.fromJson(Json j) => TimelineSession(
    id: str(j['session_id']),
    start: dateOrNull(j['start']) ?? DateTime.now(),
    end: dateOrNull(j['end']) ?? DateTime.now(),
    demand: enumFromWire(Demand.values, j['demand'], Demand.moderate),
    state: enumFromWire(TimelineSessionState.values, j['state'], TimelineSessionState.done),
    taskText: str(j['task_text']),
  );
}

enum BreakMark implements WireEnum {
  taken('taken'),
  suggested('suggested'),
  snoozed('snoozed');

  const BreakMark(this.wire);
  @override
  final String wire;
}

class TimelineBreak {
  const TimelineBreak({required this.at, required this.mark});
  final DateTime at;
  final BreakMark mark;

  factory TimelineBreak.fromJson(Json j) =>
      TimelineBreak(at: dateOrNull(j['at']) ?? DateTime.now(), mark: enumFromWire(BreakMark.values, j['mark'], BreakMark.taken));
}

enum NudgeOutcome implements WireEnum {
  taken('taken'),
  snoozed('snoozed'),
  dismissed('dismissed'),
  ignored('ignored'),
  pending('pending');

  const NudgeOutcome(this.wire);
  @override
  final String wire;
}

class TimelineNudge {
  const TimelineNudge({required this.at, required this.outcome});
  final DateTime at;
  final NudgeOutcome outcome;

  factory TimelineNudge.fromJson(Json j) => TimelineNudge(
    at: dateOrNull(j['at']) ?? DateTime.now(),
    outcome: enumFromWire(NudgeOutcome.values, j['outcome'], NudgeOutcome.ignored),
  );
}

class TimelineMeeting {
  const TimelineMeeting({required this.start, required this.end, this.title});
  final DateTime start;
  final DateTime end;
  final String? title;

  factory TimelineMeeting.fromJson(Json j) =>
      TimelineMeeting(start: dateOrNull(j['start']) ?? DateTime.now(), end: dateOrNull(j['end']) ?? DateTime.now(), title: str(j['title']));
}

class PressurePoint {
  const PressurePoint(this.t, this.v);
  final DateTime t;
  final double v;

  factory PressurePoint.fromJson(Json j) => PressurePoint(dateOrNull(j['t']) ?? DateTime.now(), dblOrNull(j['v']) ?? 0);
}

class BandPoint {
  const BandPoint(this.t, this.lo, this.hi);
  final DateTime t;
  final double lo;
  final double hi;

  factory BandPoint.fromJson(Json j) => BandPoint(dateOrNull(j['t']) ?? DateTime.now(), dblOrNull(j['lo']) ?? 0, dblOrNull(j['hi']) ?? 0);
}

class DayTotals {
  const DayTotals({
    required this.focusMinutes,
    this.usualFocusMinutes,
    required this.breaksTaken,
    required this.breaksSuggested,
    required this.breaksSkipped,
  });

  final int focusMinutes;
  final int? usualFocusMinutes;
  final int breaksTaken;
  final int breaksSuggested;
  final int breaksSkipped;

  factory DayTotals.fromJson(Json j) => DayTotals(
    focusMinutes: intOrNull(j['focus_minutes']) ?? 0,
    usualFocusMinutes: intOrNull(j['usual_focus_minutes']),
    breaksTaken: intOrNull(j['breaks_taken']) ?? 0,
    breaksSuggested: intOrNull(j['breaks_suggested']) ?? 0,
    breaksSkipped: intOrNull(j['breaks_skipped']) ?? 0,
  );
}

class DayTimeline {
  const DayTimeline({
    required this.date,
    required this.sessions,
    required this.breaks,
    required this.nudges,
    required this.meetings,
    required this.pressure,
    required this.forecast,
    required this.forecastBand,
    required this.forecastConfidence,
    required this.usualBand,
    required this.usualDays,
    required this.totals,
  });

  final DateTime date;
  final List<TimelineSession> sessions;
  final List<TimelineBreak> breaks;
  final List<TimelineNudge> nudges;
  final List<TimelineMeeting> meetings;
  final List<PressurePoint> pressure;
  final List<PressurePoint> forecast;
  final List<BandPoint> forecastBand;
  final Confidence? forecastConfidence;
  final List<BandPoint> usualBand;

  /// How many past days the usual band is built from (0 = not shown).
  final int usualDays;
  final DayTotals totals;

  bool get isEmpty => sessions.isEmpty && meetings.isEmpty;

  TimelineSession? get active => sessions.where((s) => s.state == TimelineSessionState.active).firstOrNull;

  factory DayTimeline.fromJson(Json j) => DayTimeline(
    date: dateOrNull(j['date']) ?? DateTime.now(),
    sessions: asJsonList(j['sessions']).map(TimelineSession.fromJson).toList(),
    breaks: asJsonList(j['breaks']).map(TimelineBreak.fromJson).toList(),
    nudges: asJsonList(j['nudges']).map(TimelineNudge.fromJson).toList(),
    meetings: asJsonList(j['meetings']).map(TimelineMeeting.fromJson).toList(),
    pressure: asJsonList(j['pressure']).map(PressurePoint.fromJson).toList(),
    forecast: asJsonList(j['forecast']).map(PressurePoint.fromJson).toList(),
    forecastBand: asJsonList(j['forecast_band']).map(BandPoint.fromJson).toList(),
    forecastConfidence: enumFromWireOrNull(Confidence.values, j['forecast_confidence']),
    usualBand: asJsonList(j['usual_band']).map(BandPoint.fromJson).toList(),
    usualDays: intOrNull(j['usual_days']) ?? 0,
    totals: DayTotals.fromJson(asJson(j['totals'])),
  );

  /// Linear interpolation of the pressure curve at [t] (null outside data).
  double? pressureAt(DateTime t) => _interp(pressure, t);
  double? forecastAt(DateTime t) => _interp(forecast, t);

  static double? _interp(List<PressurePoint> pts, DateTime t) {
    if (pts.isEmpty || t.isBefore(pts.first.t) || t.isAfter(pts.last.t)) return null;
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i], b = pts[i + 1];
      if (!t.isBefore(a.t) && !t.isAfter(b.t)) {
        final span = b.t.difference(a.t).inMilliseconds;
        if (span == 0) return a.v;
        return a.v + (b.v - a.v) * t.difference(a.t).inMilliseconds / span;
      }
    }
    return pts.last.v;
  }
}
