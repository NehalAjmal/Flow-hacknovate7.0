import 'package:flow/api/api_error.dart';
import 'package:flow/api/models/consent.dart';
import 'package:flow/api/models/intervention.dart';
import 'package:flow/api/models/session.dart';
import 'package:flow/api/models/team.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the doc §5.11 live status payload', () {
    final ev = SessionEvent.fromJson({
      'type': 'state',
      'session_id': 'uuid',
      'elapsed_min': 62,
      'combined_score': 0.41,
      'threshold': 0.62,
      'signals': [
        {'name': 'ultradian', 'value': 0.55, 'weight': 0.35},
        {'name': 'behavioral', 'value': 0.32, 'weight': 0.40},
        {'name': 'eye', 'value': null, 'weight': 0.0},
      ],
      'intervention_id': null,
    });
    expect(ev, isA<SessionStateEvent>());
    final s = (ev! as SessionStateEvent).status;
    expect(s.elapsedMin, 62);
    expect(s.signals.where((x) => x.available).map((x) => x.name), ['ultradian', 'behavioral']);
    expect(s.pressure, closeTo(0.41 / 0.62, 1e-9));
  });

  test('unknown stream event types are ignored, not fatal', () {
    expect(SessionEvent.fromJson({'type': 'something_new'}), isNull);
  });

  test('parses the doc §5.11 explain payload', () {
    final e = Explanation.fromJson({
      'intervention_id': 'uuid',
      'detail': 'short',
      'headline': 'You have switched windows 14 times in 5 minutes.',
      'primary_driver': 'behavioral',
      'contributions': [
        {'name': 'behavioral', 'value': 0.81, 'weight': 0.40, 'contribution': 0.32},
        {'name': 'ultradian', 'value': 0.70, 'weight': 0.35, 'contribution': 0.25},
      ],
      'combined_score': 0.67,
      'threshold': 0.62,
    });
    expect(e.primaryDriver, 'behavioral');
    expect(e.contributions, hasLength(2));
  });

  test('suppressed admin payload never exposes data, even if the server sends it', () {
    final s = Suppressible.fromJson({
      'group_size': 3,
      'suppressed': true,
      'reason': 'min_group_size_5',
      'metrics': {'active_count': 2, 'session_volume': 9},
    }, AdminSummary.fromJson);
    expect(s.suppressed, isTrue);
    expect(s.data, isNull);
    expect(s.groupSize, 3);
  });

  test('missing suppression flag defaults to suppressed', () {
    final s = Suppressible.fromJson({'group_size': 9, 'metrics': {}}, AdminSummary.fromJson);
    expect(s.suppressed, isTrue);
  });

  test('consent granted under an old policy version counts as missing', () {
    final c = ConsentState.fromJson({
      'policy_version': 'v2',
      'scopes': {
        'behavior': {'granted': true, 'version': 'v1'},
      },
    });
    expect(c.granted(ConsentScope.behavior), isFalse);
    expect(c.missingRequired, [ConsentScope.behavior]);
  });

  test('active session elapsed time comes from the server start, minus pauses', () {
    final start = DateTime(2026, 1, 1, 10);
    final s = ActiveSession(sessionId: 's', startedAt: start, plannedMinutes: 50, demand: Demand.heavy, pausedSeconds: 120);
    expect(s.elapsedAt(start.add(const Duration(minutes: 30))), const Duration(minutes: 28));
  });

  group('ApiError.fromResponse', () {
    test('doc error shape', () {
      final e = ApiError.fromResponse(403, '{"error":{"code":"llm_consent_required","message":"Need consent"}}');
      expect(e.code, ApiError.llmConsentRequired);
      expect(e.message, 'Need consent');
      expect(e.isForbidden, isTrue);
    });
    test('FastAPI detail shape', () {
      final e = ApiError.fromResponse(400, '{"detail":"Email is already registered"}');
      expect(e.message, 'Email is already registered');
    });
    test('non-JSON body', () {
      final e = ApiError.fromResponse(502, '<html>Bad gateway</html>');
      expect(e.code, 'http_502');
    });
  });
}
