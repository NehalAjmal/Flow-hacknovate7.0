import 'package:flow/api/api_error.dart';
import 'package:flow/api/real/http_transport.dart';
import 'package:flow/core/endpoint_policy.dart';
import 'package:flow/core/token_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('endpoint policy (release rules; tests build without FLOW_DEV)', () {
    test('backend: https anywhere, plain http only to this machine', () {
      expect(EndpointPolicy.backendProblem(Uri.parse('https://api.flow.app/api/v1/x')), isNull);
      expect(EndpointPolicy.backendProblem(Uri.parse('http://127.0.0.1:8002/api/v1/x')), isNull);
      expect(EndpointPolicy.backendProblem(Uri.parse('http://localhost:8002/x')), isNull);
      expect(EndpointPolicy.backendProblem(Uri.parse('http://api.flow.app/x')), isNotNull);
      expect(EndpointPolicy.backendProblem(Uri.parse('http://192.168.1.4/x')), isNotNull);
      expect(EndpointPolicy.backendProblem(Uri.parse('ftp://api.flow.app/x')), isNotNull);
    });

    test('agent: loopback WebSocket only', () {
      expect(EndpointPolicy.agentProblem(Uri.parse('ws://127.0.0.1:8765')), isNull);
      expect(EndpointPolicy.agentProblem(Uri.parse('ws://evil.example:8765')), isNotNull);
      expect(EndpointPolicy.agentProblem(Uri.parse('http://127.0.0.1:8765')), isNotNull);
    });

    test('OAuth: only https Google consent pages are opened', () {
      expect(EndpointPolicy.isAllowedOAuthUrl(Uri.parse('https://accounts.google.com/o/oauth2/v2/auth?x=1')), isTrue);
      expect(EndpointPolicy.isAllowedOAuthUrl(Uri.parse('http://accounts.google.com/o/oauth2')), isFalse);
      expect(EndpointPolicy.isAllowedOAuthUrl(Uri.parse('https://accounts.google.com.evil.io/')), isFalse);
      expect(EndpointPolicy.isAllowedOAuthUrl(Uri.parse('file:///etc/passwd')), isFalse);
      expect(EndpointPolicy.isAllowedOAuthUrl(Uri.parse('javascript:alert(1)')), isFalse);
    });
  });

  test('the transport refuses to send a token over plain http to another host', () async {
    var called = false;
    final t = HttpTransport(
      baseUrl: () => 'http://api.flow.app',
      tokens: MemoryTokenStore(),
      client: MockClient((_) async {
        called = true;
        return http.Response('{}', 200);
      }),
    );
    await expectLater(t.getJson('/settings'), throwsA(isA<ApiError>().having((e) => e.code, 'code', 'insecure_transport')));
    expect(called, isFalse, reason: 'nothing may leave the machine');
  });
}
