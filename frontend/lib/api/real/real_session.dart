import '../../core/json.dart';
import '../api_error.dart';
import '../contracts/session_api.dart';
import '../models/intervention.dart';
import '../models/session.dart';
import 'http_transport.dart';

String _id(String s) => Uri.encodeComponent(s);

class RealSessionApi implements SessionApi {
  RealSessionApi(this._t);
  final HttpTransport _t;

  @override
  Future<PreCheck> preCheck() async => PreCheck.fromJson(await _t.getJson('/session/pre-check'));

  @override
  Future<ActiveSession> start(StartSessionRequest req) async {
    final j = await _t.postJson('/session/start', body: req.toJson());
    // Doc returns {session_id, started_at}; fill the rest from the request.
    return ActiveSession.fromJson({'demand': req.demand.wire, 'planned_minutes': req.plannedMinutes, 'task_text': req.taskText, ...j});
  }

  @override
  Future<ActiveSession?> active() async {
    try {
      final j = asJson(await _t.send('GET', '/session/active'));
      if (j['session_id'] == null) return null;
      return ActiveSession.fromJson(j);
    } on ApiError catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  @override
  Stream<SessionEvent> stream(String sessionId) =>
      _t.sse('/session/stream?session_id=${_id(sessionId)}').map(SessionEvent.fromJson).where((e) => e != null).cast<SessionEvent>();

  @override
  Future<SessionStatus> status(String sessionId) async =>
      SessionStatus.fromJson(await _t.getJson('/session/status', query: {'session_id': sessionId}));

  @override
  Future<void> pause(String sessionId, {String? reason}) => _t.send('POST', '/session/${_id(sessionId)}/pause', body: {'reason': ?reason});

  @override
  Future<void> resume(String sessionId) => _t.send('POST', '/session/${_id(sessionId)}/resume');

  @override
  Future<SessionSummary> end(String sessionId) async => SessionSummary.fromJson(await _t.postJson('/session/${_id(sessionId)}/end'));

  @override
  Future<ActiveSession> extend(String sessionId, int minutes) async =>
      ActiveSession.fromJson(await _t.postJson('/session/${_id(sessionId)}/extend', body: {'minutes': minutes}));

  @override
  Future<SessionReplay> replay(String sessionId) async => SessionReplay.fromJson(await _t.getJson('/session/${_id(sessionId)}/replay'));

  @override
  Future<SessionPage> list({int page = 1, DateTime? from, DateTime? to}) async => SessionPage.fromJson(
    await _t.getJson(
      '/sessions',
      query: {
        'page': '$page',
        if (from != null) 'from': from.toUtc().toIso8601String(),
        if (to != null) 'to': to.toUtc().toIso8601String(),
      },
    ),
  );

  @override
  Future<StuckHelp> stuck(String sessionId) async =>
      StuckHelp.fromJson(await _t.postJson('/session/${_id(sessionId)}/stuck', timeout: const Duration(seconds: 45)));

  @override
  Future<void> reportResumption(String sessionId, {required String breakId, required int secondsToFirstEdit}) =>
      _t.send('POST', '/session/${_id(sessionId)}/resumption', body: {'break_id': breakId, 'seconds_to_first_edit': secondsToFirstEdit});
}

class RealInterventionApi implements InterventionApi {
  RealInterventionApi(this._t);
  final HttpTransport _t;

  @override
  Future<Intervention> get(String id) async => Intervention.fromJson(await _t.getJson('/intervention/${_id(id)}'));

  @override
  Future<Explanation> explain(String id, {ExplainDetail detail = ExplainDetail.short}) async =>
      Explanation.fromJson(await _t.getJson('/intervention/${_id(id)}/explain', query: {'detail': detail.wire}));

  @override
  Future<void> respond(String id, InterventionResponse response, {int? snoozeMinutes}) =>
      _t.send('POST', '/intervention/${_id(id)}/respond', body: {'response': response.wire, 'snooze_minutes': ?snoozeMinutes});

  @override
  Future<void> overrideLock(String id, OverrideReason reason) =>
      _t.send('POST', '/intervention/${_id(id)}/override', body: {'reason': reason.wire});

  @override
  Future<void> report(String id, ReportReason reason, {String? freeText}) => _t.send(
    'POST',
    '/intervention/${_id(id)}/report',
    body: {'reason': reason.wire, if (freeText != null && freeText.trim().isNotEmpty) 'free_text': freeText.trim()},
  );
}

class RealBreakApi implements BreakApi {
  RealBreakApi(this._t);
  final HttpTransport _t;

  @override
  Future<String> start({required String sessionId, String? interventionId}) async =>
      reqStr(await _t.postJson('/breaks/start', body: {'session_id': sessionId, 'intervention_id': ?interventionId}), 'break_id');

  @override
  Future<double?> end(String breakId, {required int actualMinutes}) async =>
      dblOrNull((await _t.postJson('/breaks/${_id(breakId)}/end', body: {'actual_minutes': actualMinutes}))['restoration_score']);

  @override
  Future<BreakSummary> list(String sessionId) async => BreakSummary.fromJson(await _t.getJson('/breaks', query: {'session_id': sessionId}));

  @override
  Future<void> rate({required String sessionId, required RatingKind kind, required int value, String? contextId}) =>
      _t.send('POST', '/ratings', body: {'session_id': sessionId, 'kind': kind.wire, 'value': value, 'context_id': ?contextId});
}
