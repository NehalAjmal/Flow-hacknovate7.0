import '../../core/json.dart';
import 'consent.dart';

enum UserRole implements WireEnum {
  solo('solo'),
  employee('employee'),
  admin('admin');

  const UserRole(this.wire);
  @override
  final String wire;
}

/// Self-registration may only create these (team doc §4.2).
enum AccountType implements WireEnum {
  solo('solo'),
  employee('employee');

  const AccountType(this.wire);
  @override
  final String wire;
}

class TokenPair {
  const TokenPair({required this.accessToken, required this.refreshToken});
  final String accessToken;
  final String refreshToken;
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.teamId,
    this.emailVerified = true,
    this.settingsVersion,
  });

  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? teamId;
  final bool emailVerified;
  final int? settingsVersion;

  bool get isAdmin => role == UserRole.admin;
  bool get hasTeam => teamId != null;

  factory AuthUser.fromJson(Json j) => AuthUser(
    id: reqStr(j, 'user_id'),
    name: str(j['name']) ?? '',
    email: str(j['email']) ?? '',
    role: enumFromWire(UserRole.values, j['role'], UserRole.solo),
    teamId: str(j['team_id']),
    emailVerified: boolOr(j['email_verified'], true),
    settingsVersion: intOrNull(j['settings_version']),
  );
}

/// POST /auth/login. Either tokens are present, or `mfaRequired` is true and
/// `mfaToken` must be exchanged via /auth/mfa/verify.
class LoginResult {
  const LoginResult({this.tokens, this.role, this.teamId, this.consentMissing = const [], this.mfaRequired = false, this.mfaToken});

  final TokenPair? tokens;
  final UserRole? role;
  final String? teamId;
  final List<ConsentScope> consentMissing;
  final bool mfaRequired;
  final String? mfaToken;

  factory LoginResult.fromJson(Json j) {
    final access = str(j['access_token']);
    final refresh = str(j['refresh_token']);
    return LoginResult(
      tokens: access != null && refresh != null ? TokenPair(accessToken: access, refreshToken: refresh) : null,
      role: enumFromWireOrNull(UserRole.values, j['role']),
      teamId: str(j['team_id']),
      consentMissing: strList(j['consent_missing'])
          .map((s) => enumFromWireOrNull(ConsentScope.values, s))
          .whereType<ConsentScope>()
          .toList(),
      mfaRequired: boolOr(j['mfa_required'], false),
      mfaToken: str(j['mfa_token']),
    );
  }
}

class RegisterRequest {
  const RegisterRequest({required this.name, required this.email, required this.password, required this.accountType, this.inviteToken});

  final String name;
  final String email;
  final String password;
  final AccountType accountType;
  final String? inviteToken;

  Json toJson() => {
    'name': name,
    'email': email,
    'password': password,
    'account_type': accountType.wire,
    if (inviteToken != null) 'invite_token': inviteToken,
  };
}

class RegisterResult {
  const RegisterResult({required this.userId, required this.role, this.teamId, required this.needsEmailVerification});

  final String userId;
  final UserRole role;
  final String? teamId;
  final bool needsEmailVerification;

  factory RegisterResult.fromJson(Json j) => RegisterResult(
    userId: reqStr(j, 'user_id'),
    role: enumFromWire(UserRole.values, j['role'], UserRole.solo),
    teamId: str(j['team_id']),
    needsEmailVerification: boolOr(j['needs_email_verification'], true),
  );
}
