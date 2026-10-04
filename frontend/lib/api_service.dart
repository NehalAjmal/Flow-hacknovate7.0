import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Single place every network call goes through.
/// Override the backend URL at build time with:
///   flutter run --dart-define=FLOW_API_URL=http://192.168.x.x:8002
class ApiService {
  static const String base = String.fromEnvironment(
    'FLOW_API_URL',
    defaultValue: 'http://127.0.0.1:8002',
  );

  static const Duration _timeout = Duration(seconds: 15);
  static const Duration _aiTimeout = Duration(seconds: 60);

  /// Thrown for any non-2xx response or network failure.
  /// `detail` carries the backend's error message when present.
  static String _errorMessage(Object e) {
    if (e is ApiException) return e.message;
    return 'Cannot reach the server. Is the backend running on $base?';
  }

  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    return {
      'Content-Type': 'application/json',
      if (auth && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static dynamic _decode(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return {};
      return jsonDecode(res.body);
    }
    String detail = 'Request failed (${res.statusCode})';
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['detail'] != null) detail = body['detail'].toString();
    } catch (_) {}
    throw ApiException(detail, res.statusCode);
  }

  static Future<dynamic> get(String path, {Map<String, String>? query, bool auth = true}) async {
    try {
      final uri = Uri.parse('$base$path').replace(queryParameters: query);
      final res = await http
          .get(uri, headers: await _headers(auth: auth))
          .timeout(_timeout);
      return _decode(res);
    } catch (e) {
      throw ApiException(_errorMessage(e), e is ApiException ? e.statusCode : null);
    }
  }

  static Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
    bool ai = false,
  }) async {
    try {
      final uri = Uri.parse('$base$path');
      final res = await http
          .post(uri, headers: await _headers(auth: auth), body: jsonEncode(body ?? {}))
          .timeout(ai ? _aiTimeout : _timeout);
      return _decode(res);
    } catch (e) {
      throw ApiException(_errorMessage(e), e is ApiException ? e.statusCode : null);
    }
  }

  // ─── AUTH ─────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async =>
      await post('/auth/login', body: {'email': email, 'password': password}, auth: false)
          as Map<String, dynamic>;

  static Future<Map<String, dynamic>> register(Map<String, dynamic> payload) async =>
      await post('/auth/register', body: payload, auth: false) as Map<String, dynamic>;

  // ─── SESSIONS ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> startSession({
    required String taskDescription,
    required String difficulty,
    required int plannedMinutes,
  }) async =>
      await post('/session/start', body: {
        'task_description': taskDescription,
        'declared_difficulty': difficulty,
        'planned_duration_min': plannedMinutes,
      }) as Map<String, dynamic>;

  static Future<Map<String, dynamic>> endSession(String sessionId, {int? selfRatedQuality}) async =>
      await post('/session/end', body: {
        'session_id': sessionId,
        'self_rated_quality': selfRatedQuality,
      }) as Map<String, dynamic>;

  static Future<Map<String, dynamic>> respond(String sessionId, String response) async =>
      await post('/session/respond', body: {'session_id': sessionId, 'response': response})
          as Map<String, dynamic>;

  static Future<Map<String, dynamic>> status(String sessionId) async =>
      await get('/session/status', query: {'session_id': sessionId}) as Map<String, dynamic>;

  static Future<Map<String, dynamic>> preCheck() async =>
      await get('/session/pre-check') as Map<String, dynamic>;

  /// Gemini-backed "I'm stuck" suggestions (60s timeout — LLM latency).
  static Future<Map<String, dynamic>> stuck(Map<String, dynamic> payload) async =>
      await post('/session/stuck', body: payload, ai: true) as Map<String, dynamic>;

  // ─── USER / BIOMETRIC ─────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> userDashboard() async =>
      await get('/user/dashboard') as Map<String, dynamic>;

  static Future<Map<String, dynamic>> userPatterns() async =>
      await get('/user/patterns') as Map<String, dynamic>;

  static Future<Map<String, dynamic>> biometricLatest({String? sessionId}) async => await get(
        '/biometric/latest',
        query: sessionId != null ? {'session_id': sessionId} : null,
      ) as Map<String, dynamic>;

  // ─── ADMIN ────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> adminDashboard() async =>
      await get('/admin/dashboard') as Map<String, dynamic>;

  static Future<Map<String, dynamic>> sendBreakAlert() async =>
      await post('/admin/send-break-alert') as Map<String, dynamic>;

  // ─── EXPORT ───────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> focusDna() async =>
      await post('/export/focus-dna', ai: true) as Map<String, dynamic>;
}

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  ApiException(this.message, [this.statusCode]);

  bool get isAuthError => statusCode == 401 || statusCode == 403;
  bool get isNotFound => statusCode == 404;

  @override
  String toString() => message;
}

/// Login/register store these keys; read via [SessionStore].
class SessionStore {
  static Future<void> saveAuth({
    required String token,
    required String userId,
    required String role,
    String? fullName,
    String? email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('user_id', userId);
    await prefs.setString('user_role', role);
    if (fullName != null && fullName.isNotEmpty) {
      await prefs.setString('user_name', fullName);
    }
    if (email != null && email.isNotEmpty) {
      await prefs.setString('user_email', email);
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in ['auth_token', 'user_id', 'user_role', 'user_name', 'user_email', 'active_session_id']) {
      await prefs.remove(key);
    }
  }

  static Future<String?> token() async =>
      (await SharedPreferences.getInstance()).getString('auth_token');
}
