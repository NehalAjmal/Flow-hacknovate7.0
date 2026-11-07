import '../models/auth.dart';

/// /auth/* — team doc §5.1.
abstract interface class AuthApi {
  Future<RegisterResult> register(RegisterRequest req);
  Future<void> verifyEmail(String token);
  Future<LoginResult> login({required String email, required String password});

  /// Exchanges the `mfa_token` from [login] plus a TOTP code for tokens.
  Future<TokenPair> verifyMfa({required String mfaToken, required String code});

  Future<TokenPair> refresh(String refreshToken);
  Future<void> logout(String refreshToken);
  Future<void> forgotPassword(String email);
  Future<void> resetPassword({required String token, required String newPassword});
  Future<AuthUser> me();
}
