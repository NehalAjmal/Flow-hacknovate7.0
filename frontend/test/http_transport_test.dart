import 'dart:convert';

import 'package:flow/api/api_error.dart';
import 'package:flow/api/models/auth.dart';
import 'package:flow/api/real/http_transport.dart';
import 'package:flow/core/token_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late MemoryTokenStore tokens;
  setUp(() => tokens = MemoryTokenStore(const TokenPair(accessToken: 'old', refreshToken: 'r1')));

  HttpTransport transport(MockClient client, {void Function()? onExpired}) =>
      HttpTransport(baseUrl: () => 'https://api.test/', tokens: tokens, client: client, onSessionExpired: onExpired);

  test('prefixes /api/v1 and sends the bearer token', () async {
    late http.Request seen;
    final t = transport(
      MockClient((req) async {
        seen = req;
        return http.Response('{"ok":true}', 200);
      }),
    );
    await t.getJson('/settings');
    expect(seen.url.toString(), 'https://api.test/api/v1/settings');
    expect(seen.headers['Authorization'], 'Bearer old');
  });

  test('on 401 refreshes once, stores rotated tokens and retries', () async {
    var refreshCalls = 0;
    final t = transport(
      MockClient((req) async {
        if (req.url.path.endsWith('/auth/refresh')) {
          refreshCalls++;
          expect(jsonDecode(req.body), {'refresh_token': 'r1'});
          return http.Response('{"access_token":"new","refresh_token":"r2"}', 200);
        }
        return req.headers['Authorization'] == 'Bearer new' ? http.Response('{"value":1}', 200) : http.Response('', 401);
      }),
    );

    // Three concurrent calls share a single refresh.
    final results = await Future.wait([t.getJson('/a'), t.getJson('/b'), t.getJson('/c')]);
    expect(results.every((r) => r['value'] == 1), isTrue);
    expect(refreshCalls, 1);
    final stored = await tokens.read();
    expect(stored!.accessToken, 'new');
    expect(stored.refreshToken, 'r2');
  });

  test('failed refresh clears tokens and signals session expiry', () async {
    var expired = 0;
    final t = transport(
      MockClient((req) async => http.Response('{"error":{"code":"invalid","message":"no"}}', 401)),
      onExpired: () => expired++,
    );
    await expectLater(t.getJson('/a'), throwsA(isA<ApiError>().having((e) => e.code, 'code', ApiError.sessionExpired)));
    expect(expired, 1);
    expect(await tokens.read(), isNull);
  });

  test('network failure during refresh does NOT log the user out', () async {
    var expired = 0;
    final t = transport(
      MockClient((req) async {
        if (req.url.path.endsWith('/auth/refresh')) throw http.ClientException('offline');
        return http.Response('', 401);
      }),
      onExpired: () => expired++,
    );
    await expectLater(t.getJson('/a'), throwsA(isA<ApiError>().having((e) => e.isNetwork, 'isNetwork', true)));
    expect(expired, 0);
    expect(await tokens.read(), isNotNull);
  });

  test('client exceptions become network ApiErrors', () async {
    final t = transport(MockClient((_) async => throw http.ClientException('boom')));
    await expectLater(t.getJson('/a'), throwsA(isA<ApiError>().having((e) => e.code, 'code', ApiError.network)));
  });

  test('doc error shape is surfaced', () async {
    final t = transport(MockClient((_) async => http.Response('{"error":{"code":"rate_limited","message":"Slow down"}}', 429)));
    await expectLater(
      t.getJson('/a'),
      throwsA(isA<ApiError>().having((e) => e.message, 'message', 'Slow down').having((e) => e.status, 'status', 429)),
    );
  });

  test('SSE: parses multi-line data blocks and skips comments', () async {
    final t = transport(
      MockClient.streaming((req, _) async {
        expect(req.headers['Accept'], 'text/event-stream');
        const body =
            ': keep-alive\n'
            'event: state\n'
            'data: {"type":"state",\n'
            'data: "elapsed_min":3}\n'
            '\n'
            'data: not json\n'
            '\n'
            'data: {"type":"session_ended","session_id":"s"}\n'
            '\n';
        return http.StreamedResponse(Stream.value(utf8.encode(body)), 200);
      }),
    );
    final events = await t.sse('/session/stream').toList();
    expect(events, [
      {'type': 'state', 'elapsed_min': 3},
      {'type': 'session_ended', 'session_id': 's'},
    ]);
  });
}
