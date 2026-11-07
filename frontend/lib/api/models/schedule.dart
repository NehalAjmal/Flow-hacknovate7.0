import '../../core/json.dart';
import 'session.dart';

/// A routine: a planned session that repeats on chosen weekdays (DESIGN_SPEC
/// §9.3). Times are local "HH:mm". Weekdays use DateTime.weekday (1 = Mon).
class Schedule {
  const Schedule({
    this.id,
    required this.name,
    required this.start,
    required this.end,
    required this.weekdays,
    this.demand = Demand.moderate,
    this.enabled = true,
  });

  /// Null until the backend has stored it.
  final String? id;
  final String name;
  final String start;
  final String end;
  final List<int> weekdays;
  final Demand demand;
  final bool enabled;

  static int minutesOf(String hm) {
    final p = hm.split(':');
    return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p.length > 1 ? p[1] : '0') ?? 0);
  }

  static String hm(int minutes) => '${(minutes ~/ 60 % 24).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  int get startMinutes => minutesOf(start);
  int get endMinutes => minutesOf(end);
  int get durationMinutes => (endMinutes - startMinutes).clamp(5, 24 * 60);

  /// Does it run on [day]? If so, its start and end on that date.
  (DateTime, DateTime)? on(DateTime day) {
    if (!enabled || !weekdays.contains(day.weekday)) return null;
    final d = DateTime(day.year, day.month, day.day);
    return (d.add(Duration(minutes: startMinutes)), d.add(Duration(minutes: endMinutes)));
  }

  Schedule copyWith({String? id, String? name, String? start, String? end, List<int>? weekdays, Demand? demand, bool? enabled}) => Schedule(
    id: id ?? this.id,
    name: name ?? this.name,
    start: start ?? this.start,
    end: end ?? this.end,
    weekdays: weekdays ?? this.weekdays,
    demand: demand ?? this.demand,
    enabled: enabled ?? this.enabled,
  );

  factory Schedule.fromJson(Json j) => Schedule(
    id: str(j['id']),
    name: str(j['name']) ?? 'Planned session',
    start: str(j['start']) ?? '09:00',
    end: str(j['end']) ?? '10:00',
    weekdays: intList(j['weekdays']),
    demand: enumFromWire(Demand.values, j['demand'], Demand.moderate),
    enabled: boolOr(j['enabled'], true),
  );

  Json toJson() => {'name': name, 'start': start, 'end': end, 'weekdays': weekdays, 'demand': demand.wire, 'enabled': enabled};
}
