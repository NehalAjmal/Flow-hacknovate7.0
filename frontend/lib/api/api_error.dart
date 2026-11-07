import 'dart:convert';

/// The one error type every API call throws. Mirrors the team doc's error
/// shape: `{ "error": { "code": "string", "message": "string" } }`.
class ApiError implements Exception {
  const ApiError(this.code, this.message, {this.status});

  final String code;
  final String message;

  /// HTTP status, or null for transport failures.
  final int? status;

  // Codes the UI branches on. Backend must use these exact strings.
  static const network = 'network_error';
  static const timeout = 'timeout';
  static const sessionExpired = 'session_expired';
  static const invalidCredentials = 'invalid_credentials';
  static const mfaInvalid = 'mfa_invalid';
  static const llmConsentRequired = 'llm_consent_required';
  static const notFound = 'not_found';
  static const rateLimited = 'rate_limited';
  static const badResponse = 'bad_response';

  bool get isNetwork => code == network || code == timeout;
  bool get isUnauthorized => status == 401;
  bool get isForbidden => status == 403;
  bool get isNotFound => status == 404;

  factory ApiError.fromResponse(int status, String body) {
    String code = _defaultCode(status);
    String message = 'Request failed ($status)';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final err = decoded['error'];
        if (err is Map) {
          code = err['code']?.toString() ?? code;
          message = err['message']?.toString() ?? message;
        } else if (decoded['detail'] != null) {
          // Tolerate FastAPI's default `{detail: ...}` until the backend
          // adopts the doc's error shape.
          message = decoded['detail'].toString();
        }
      }
    } catch (_) {
      // Non-JSON body: keep the defaults.
    }
    return ApiError(code, message, status: status);
  }

  static String _defaultCode(int status) => switch (status) {
    401 => sessionExpired,
    404 => notFound,
    429 => rateLimited,
    _ => 'http_$status',
  };

  @override
  String toString() => 'ApiError($code, $status): $message';
}
