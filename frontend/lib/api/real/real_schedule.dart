import '../../core/json.dart';
import '../contracts/schedule_api.dart';
import '../models/schedule.dart';
import 'http_transport.dart';

class RealScheduleApi implements ScheduleApi {
  RealScheduleApi(this._t);
  final HttpTransport _t;

  @override
  Future<List<Schedule>> list() async => asJsonList((await _t.getJson('/user/schedules'))['schedules']).map(Schedule.fromJson).toList();

  @override
  Future<Schedule> create(Schedule s) async => Schedule.fromJson(await _t.postJson('/user/schedules', body: s.toJson()));

  @override
  Future<Schedule> update(Schedule s) async => Schedule.fromJson(asJson(await _t.send('PUT', '/user/schedules/${s.id}', body: s.toJson())));

  @override
  Future<void> delete(String id) async => _t.send('DELETE', '/user/schedules/$id');
}
