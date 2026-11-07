import '../models/intervention.dart';
import '../models/session.dart';

/// /session/* and /sessions — team doc §5.3.
abstract interface class SessionApi {
  Future<PreCheck> preCheck();
  Future<ActiveSession> start(StartSessionRequest req);

  /// The running session, or null if none (backend returns 404 / 204).
  Future<ActiveSession?> active();

  /// Live push channel. Errors or completes when the connection drops; the
  /// caller falls back to [status] polling.
  Stream<SessionEvent> stream(String sessionId);
  Future<SessionStatus> status(String sessionId);

  Future<void> pause(String sessionId, {String? reason});
  Future<void> resume(String sessionId);
  Future<SessionSummary> end(String sessionId);

  /// POST /session/{id}/extend {minutes}: "+15" in the session controls.
  /// Returns the session with its new planned length.
  Future<ActiveSession> extend(String sessionId, int minutes);
  Future<SessionReplay> replay(String sessionId);
  Future<SessionPage> list({int page = 1, DateTime? from, DateTime? to});

  /// POST /session/{id}/stuck. Throws ApiError `llm_consent_required` (403)
  /// unless the user granted the `llm` scope.
  Future<StuckHelp> stuck(String sessionId);

  /// POST /session/{id}/resumption — time to first edit after a break,
  /// measured by the local agent.
  Future<void> reportResumption(String sessionId, {required String breakId, required int secondsToFirstEdit});
}

/// /intervention/* — team doc §5.4.
abstract interface class InterventionApi {
  Future<Intervention> get(String id);
  Future<Explanation> explain(String id, {ExplainDetail detail = ExplainDetail.short});
  Future<void> respond(String id, InterventionResponse response, {int? snoozeMinutes});
  Future<void> overrideLock(String id, OverrideReason reason);
  Future<void> report(String id, ReportReason reason, {String? freeText});
}

/// /breaks, /ratings — team doc §5.4.
abstract interface class BreakApi {
  Future<String> start({required String sessionId, String? interventionId});

  /// Returns the restoration score, if the backend computed one.
  Future<double?> end(String breakId, {required int actualMinutes});
  Future<BreakSummary> list(String sessionId);
  Future<void> rate({required String sessionId, required RatingKind kind, required int value, String? contextId});
}
