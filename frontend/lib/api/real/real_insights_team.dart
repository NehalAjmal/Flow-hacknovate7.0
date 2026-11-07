import 'dart:typed_data';

import '../../core/json.dart';
import '../contracts/insights_api.dart';
import '../contracts/meta_api.dart';
import '../contracts/team_api.dart';
import '../models/day.dart';
import '../models/insights.dart';
import '../models/meta.dart';
import '../models/team.dart';
import 'http_transport.dart';

class RealInsightsApi implements InsightsApi {
  RealInsightsApi(this._t);
  final HttpTransport _t;

  @override
  Future<Dashboard> dashboard() async => Dashboard.fromJson(await _t.getJson('/user/dashboard'));

  @override
  Future<Patterns> patterns() async => Patterns.fromJson(await _t.getJson('/user/patterns'));

  @override
  Future<Forecast> forecast() async => Forecast.fromJson(await _t.getJson('/forecast'));

  @override
  Future<DayTimeline> day(DateTime date) async => DayTimeline.fromJson(await _t.getJson('/user/day', query: {'date': _ymd(date)}));

  @override
  Future<Map<DateTime, int>> month(DateTime month) async {
    final j = await _t.getJson('/user/month', query: {'month': _ymd(month).substring(0, 7)});
    return {
      for (final d in asJsonList(j['days']))
        if (dateOrNull(d['date']) case final date?) DateTime(date.year, date.month, date.day): intOrNull(d['focus_minutes']) ?? 0,
    };
  }

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Future<Uint8List> focusDnaPng() =>
      // POST per doc §5.6; the response body is the PNG itself.
      _t.bytes('POST', '/export/focus-dna', timeout: const Duration(seconds: 45));
}

class RealCalendarApi implements CalendarApi {
  RealCalendarApi(this._t);
  final HttpTransport _t;

  @override
  Future<Uri> connect() async => Uri.parse(reqStr(await _t.postJson('/calendar/connect'), 'auth_url'));

  @override
  Future<CalendarContext> context() async => CalendarContext.fromJson(await _t.getJson('/calendar/context'));

  @override
  Future<void> disconnect() => _t.send('DELETE', '/calendar');
}

class RealTeamApi implements TeamApi {
  RealTeamApi(this._t);
  final HttpTransport _t;

  @override
  Future<Suppressible<TeamMetrics>> summary() async => Suppressible.fromJson(await _t.getJson('/team/summary'), TeamMetrics.fromJson);
}

class RealAdminApi implements AdminApi {
  RealAdminApi(this._t);
  final HttpTransport _t;

  Future<Suppressible<T>> _get<T>(String path, T Function(Json) read) async => Suppressible.fromJson(await _t.getJson(path), read);

  @override
  Future<Suppressible<AdminSummary>> summary() => _get('/admin/summary', AdminSummary.fromJson);

  @override
  Future<Suppressible<AdminTrend>> trend() => _get('/admin/trend', AdminTrend.fromJson);

  @override
  Future<Suppressible<AdminInsights>> insights() => _get('/admin/insights', AdminInsights.fromJson);

  @override
  Future<Suppressible<TeamStrain>> strain() => _get('/admin/strain', TeamStrain.fromJson);

  @override
  Future<Suppressible<MeetingWindow>> meetingWindow() => _get('/admin/meeting-window', MeetingWindow.fromJson);

  @override
  Future<AdminPrivacyStatus> privacyStatus() async => AdminPrivacyStatus.fromJson(await _t.getJson('/admin/privacy-status'));

  @override
  Future<Invite> createInvite({Duration validFor = const Duration(days: 7)}) async =>
      Invite.fromJson(await _t.postJson('/admin/invites', body: {'valid_for_hours': validFor.inHours}));

  @override
  Future<List<Invite>> invites() async => asJsonList((await _t.getJson('/admin/invites'))['items']).map(Invite.fromJson).toList();

  @override
  Future<void> revokeInvite(String id) => _t.send('DELETE', '/admin/invites/${Uri.encodeComponent(id)}');

  @override
  Future<List<AuditEntry>> auditLog() async =>
      asJsonList((await _t.getJson('/admin/audit-log'))['items']).map(AuditEntry.fromJson).toList();
}

class RealMetaApi implements MetaApi {
  RealMetaApi(this._t);
  final HttpTransport _t;

  @override
  Future<FeatureFlags> flags() async => FeatureFlags.fromJson(await _t.getJson('/flags'));

  @override
  Future<void> sendFeedback(FeedbackRequest req) => _t.send('POST', '/feedback', body: req.toJson());

  @override
  Future<List<ChangelogEntry>> changelog() async =>
      asJsonList((await _t.getJson('/changelog', auth: false))['items']).map(ChangelogEntry.fromJson).toList();
}
