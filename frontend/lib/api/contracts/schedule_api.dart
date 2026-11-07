import '../models/schedule.dart';

/// /user/schedules — scheduled sessions (routines). Assumed contract; see
/// CONTRACT_NOTES.md. The backend should also place each schedule's
/// occurrences into GET /user/day as `state: "scheduled"` sessions.
abstract interface class ScheduleApi {
  Future<List<Schedule>> list();
  Future<Schedule> create(Schedule s);
  Future<Schedule> update(Schedule s);
  Future<void> delete(String id);
}
