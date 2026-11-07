import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../core/config.dart';
import '../../core/endpoint_policy.dart';
import '../../core/json.dart';
import '../../core/token_store.dart';
import '../api_error.dart';
import '../models/auth.dart';

class RequestLogEntry {
  RequestLogEntry({
    required this.method,
    required this.path,
    required this.at,
    this.status,
    this.duration,
    this.error,
    this.mocked = false,
  });

  final String method;
  final String path;
  final DateTime at;
  final int? status;
  final Duration? duration;
  final String? error;
  final bool mocked;
}

typedef RequestLogger = void Function(RequestLogEntry entry);

/// Single HTTP entry point for all real API classes.
///
/// - Prefixes every path with `/api/v1`.
/// - Attaches the bearer token.
/// - On a 401, refreshes once (single-flight across concurrent calls) and
///   retries; if refresh fails, clears tokens and calls [onSessionExpired].
/// - Converts every failure into [ApiError].
class HttpTransport {
  HttpTransport({
    required this.baseUrl,
    required this.tokens,
    http.Client? client,
    this.onSessionExpired,
    this.logger,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  /// Read on every call so the dev panel can switch backends live.
  final String Function() baseUrl;
  final TokenStore tokens;
  final http.Client _client;
  final void Function()? onSessionExpired;
  final RequestLogger? logger;
  final Duration timeout;

  Future<TokenPair?>? _refreshing;

  Uri uri(String path, [Map<String, String>? query]) {
    final base = baseUrl().replaceAll(RegExp(r'/+$'), '');
    final u = Uri.parse('$base$kApiPrefix$path').replace(queryParameters: query);
    // never send tokens or personal data over plain HTTP to another machine
    final problem = EndpointPolicy.backendProblem(u);
    if (problem != null) throw ApiError('insecure_transport', problem);
    return u;
  }

  Future<Json> getJson(String path, {Map<String, String>? query, bool auth = true}) async =>
      asJson(await send('GET', path, query: query, auth: auth));

  Future<Json> postJson(String path, {Object? body, bool auth = true, Duration? timeout}) async =>
      asJson(await send('POST', path, body: body, auth: auth, timeout: timeout));

  Future<Object?> send(String method, String path, {Object? body, Map<String, String>? query, bool auth = true, Duration? timeout}) async {
    final res = await _sendRaw(method, path, body: body, query: query, auth: auth, timeout: timeout);
    if (res.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(res.bodyBytes));
    } on FormatException {
      throw ApiError(ApiError.badResponse, 'Server returned invalid JSON', status: res.statusCode);
    }
  }

  Future<Uint8List> bytes(String method, String path, {bool auth = true, Duration? timeout}) async =>
      (await _sendRaw(method, path, auth: auth, timeout: timeout)).bodyBytes;

  Future<http.Response> _sendRaw(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    bool auth = true,
    Duration? timeout,
    bool isRetry = false,
  }) async {
    final started = DateTime.now();
    final headers = <String, String>{'Accept': 'application/json', if (body != null) 'Content-Type': 'application/json'};
    if (auth) {
      final t = await tokens.read();
      if (t != null) headers['Authorization'] = 'Bearer ${t.accessToken}';
    }

    final req = http.Request(method, uri(path, query))..headers.addAll(headers);
    if (body != null) req.body = jsonEncode(body);

    http.Response res;
    try {
      res = await http.Response.fromStream(await _client.send(req)).timeout(timeout ?? this.timeout);
    } on TimeoutException {
      _log(method, path, started, error: 'timeout');
      throw const ApiError(ApiError.timeout, 'The server took too long to respond.');
    } on http.ClientException catch (e) {
      _log(method, path, started, error: e.message);
      throw const ApiError(ApiError.network, "Can't reach Flow. Check your connection.");
    }

    _log(method, path, started, status: res.statusCode);

    if (res.statusCode == 401 && auth && !isRetry) {
      final fresh = await _refreshOnce();
      if (fresh != null) {
        return _sendRaw(method, path, body: body, query: query, auth: auth, timeout: timeout, isRetry: true);
      }
      throw const ApiError(ApiError.sessionExpired, 'Your session expired. Please sign in again.', status: 401);
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiError.fromResponse(res.statusCode, res.body);
    }
    return res;
  }

  /// Concurrent 401s share one refresh call.
  Future<TokenPair?> _refreshOnce() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<TokenPair?> _doRefresh() async {
    final current = await tokens.read();
    if (current == null) {
      onSessionExpired?.call();
      return null;
    }
    try {
      final res = await _sendRaw('POST', '/auth/refresh', body: {'refresh_token': current.refreshToken}, auth: false, isRetry: true);
      final j = asJson(jsonDecode(res.body));
      final access = str(j['access_token']);
      if (access == null) throw const ApiError(ApiError.badResponse, 'No access token');
      // Rotation: backend may return a new refresh token.
      final pair = TokenPair(accessToken: access, refreshToken: str(j['refresh_token']) ?? current.refreshToken);
      await tokens.write(pair);
      return pair;
    } on ApiError catch (e) {
      if (e.isNetwork) rethrow; // offline ≠ logged out
      await tokens.clear();
      onSessionExpired?.call();
      return null;
    }
  }

  /// Server-sent events. Each `data:` block is decoded as JSON.
  Stream<Json> sse(String path) async* {
    final started = DateTime.now();
    final t = await tokens.read();
    final req = http.Request('GET', uri(path))
      ..headers['Accept'] = 'text/event-stream'
      ..headers['Cache-Control'] = 'no-cache';
    if (t != null) req.headers['Authorization'] = 'Bearer ${t.accessToken}';

    final http.StreamedResponse res;
    try {
      res = await _client.send(req).timeout(timeout);
    } on TimeoutException {
      throw const ApiError(ApiError.timeout, 'Live connection timed out.');
    } on http.ClientException catch (e) {
      _log('SSE', path, started, error: e.message);
      throw const ApiError(ApiError.network, 'Live connection failed.');
    }
    _log('SSE', path, started, status: res.statusCode);
    if (res.statusCode != 200) {
      throw ApiError.fromResponse(res.statusCode, await res.stream.bytesToString());
    }

    final data = StringBuffer();
    await for (final line in res.stream.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.isEmpty) {
        if (data.isNotEmpty) {
          final payload = data.toString();
          data.clear();
          try {
            yield asJson(jsonDecode(payload));
          } on FormatException {
            // Skip malformed events rather than killing the stream.
          }
        }
      } else if (line.startsWith('data:')) {
        if (data.isNotEmpty) data.write('\n');
        data.write(line.substring(5).trimLeft());
      }
      // `event:`, `id:`, `retry:` and `:` comments are ignored; the event
      // type travels inside the JSON (`type` field).
    }
  }

  void _log(String method, String path, DateTime started, {int? status, String? error}) {
    logger?.call(
      RequestLogEntry(method: method, path: path, at: started, status: status, duration: DateTime.now().difference(started), error: error),
    );
  }

  void close() => _client.close();
}
