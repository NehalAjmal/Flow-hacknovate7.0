import '../../core/json.dart';
import 'session.dart';

enum Confidence implements WireEnum {
  low('low'),
  medium('medium'),
  high('high');

  const Confidence(this.wire);
  @override
  final String wire;
}

/// Anything Flow "learned" ships with its sample size and confidence
/// (team doc §6.1 "Honest numbers").
class Learned<T> {
  const Learned({required this.value, required this.sampleSize, required this.confidence});
  final T value;
  final int sampleSize;
  final Confidence confidence;

  static Learned<T>? parse<T>(Object? raw, T? Function(Object?) read) {
    if (raw is! Map) return null;
    final j = asJson(raw);
    final v = read(j['value']);
    if (v == null) return null;
    return Learned(
      value: v,
      sampleSize: intOrNull(j['sample_size']) ?? 0,
      confidence: enumFromWire(Confidence.values, j['confidence'], Confidence.low),
    );
  }
}

class TodayStats {
  const TodayStats({required this.sessions, required this.focusMinutes, required this.breaksTaken});
  final int sessions;
  final int focusMinutes;
  final int breaksTaken;

  factory TodayStats.fromJson(Json j) => TodayStats(
    sessions: intOrNull(j['sessions']) ?? 0,
    focusMinutes: intOrNull(j['focus_minutes']) ?? 0,
    breaksTaken: intOrNull(j['breaks_taken']) ?? 0,
  );
}

class QuickStart {
  const QuickStart({required this.demand, required this.minutes, this.taskText});
  final Demand demand;
  final int minutes;
  final String? taskText;

  factory QuickStart.fromJson(Json j) => QuickStart(
    demand: enumFromWire(Demand.values, j['demand'], Demand.moderate),
    minutes: intOrNull(j['minutes']) ?? 50,
    taskText: str(j['task_text']),
  );
}

class ForecastWindow {
  const ForecastWindow({required this.start, required this.end, required this.kind, this.note});
  final DateTime start;
  final DateTime end;

  /// `focus` | `break` | `meeting`
  final String kind;
  final String? note;

  factory ForecastWindow.fromJson(Json j) => ForecastWindow(
    start: dateOrNull(j['start']) ?? DateTime.now(),
    end: dateOrNull(j['end']) ?? DateTime.now(),
    kind: str(j['kind']) ?? 'focus',
    note: str(j['note']),
  );
}

class Forecast {
  const Forecast({required this.available, required this.windows, required this.confidence, required this.basis, this.sessionsNeeded = 0});

  /// False until enough sessions exist; then `sessionsNeeded` says how many more.
  final bool available;
  final List<ForecastWindow> windows;
  final Confidence confidence;
  final String basis;
  final int sessionsNeeded;

  factory Forecast.fromJson(Json j) => Forecast(
    available: boolOr(j['available'], j['windows'] is List),
    windows: asJsonList(j['windows']).map(ForecastWindow.fromJson).toList(),
    confidence: enumFromWire(Confidence.values, j['confidence'], Confidence.low),
    basis: str(j['basis']) ?? '',
    sessionsNeeded: intOrNull(j['sessions_needed']) ?? 0,
  );
}

class Dashboard {
  const Dashboard({required this.today, this.currentState, this.quickStart, this.forecast});
  final TodayStats today;
  final FlowState? currentState;
  final QuickStart? quickStart;
  final Forecast? forecast;

  factory Dashboard.fromJson(Json j) => Dashboard(
    today: TodayStats.fromJson(asJson(j['today'])),
    currentState: enumFromWireOrNull(FlowState.values, j['current_state']),
    quickStart: j['quick_start'] is Map ? QuickStart.fromJson(asJson(j['quick_start'])) : null,
    forecast: j['forecast'] is Map ? Forecast.fromJson(asJson(j['forecast'])) : null,
  );
}

class Patterns {
  const Patterns({
    required this.sessionsCompleted,
    required this.sessionsNeeded,
    this.peakHours,
    this.personalPeriodMin,
    this.breakEffectiveness,
  });

  final int sessionsCompleted;

  /// Sessions still needed before anything is learned. 0 = learning done.
  final int sessionsNeeded;
  final Learned<List<int>>? peakHours;
  final Learned<int>? personalPeriodMin;

  /// 0..1 — how much focus ratings recover after breaks.
  final Learned<double>? breakEffectiveness;

  bool get isLearning => sessionsNeeded > 0;

  factory Patterns.fromJson(Json j) => Patterns(
    sessionsCompleted: intOrNull(j['sessions_completed']) ?? 0,
    sessionsNeeded: intOrNull(j['sessions_needed']) ?? 0,
    peakHours: Learned.parse<List<int>>(j['peak_hours'], (v) => v is List ? intList(v) : null),
    personalPeriodMin: Learned.parse<int>(j['personal_period_min'], intOrNull),
    breakEffectiveness: Learned.parse<double>(j['break_effectiveness'], dblOrNull),
  );
}

class CalendarEvent {
  const CalendarEvent({required this.title, required this.start, required this.end});
  final String title;
  final DateTime start;
  final DateTime end;

  factory CalendarEvent.fromJson(Json j) => CalendarEvent(
    title: str(j['title']) ?? 'Busy',
    start: dateOrNull(j['start']) ?? DateTime.now(),
    end: dateOrNull(j['end']) ?? DateTime.now(),
  );
}

class CalendarContext {
  const CalendarContext({required this.connected, required this.events});
  final bool connected;
  final List<CalendarEvent> events;

  factory CalendarContext.fromJson(Json j) =>
      CalendarContext(connected: boolOr(j['connected'], true), events: asJsonList(j['events']).map(CalendarEvent.fromJson).toList());
}
