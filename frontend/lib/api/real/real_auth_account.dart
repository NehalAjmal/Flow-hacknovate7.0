import '../../core/json.dart';
import '../contracts/account_api.dart';
import '../contracts/auth_api.dart';
import '../models/auth.dart';
import '../models/consent.dart';
import '../models/privacy.dart';
import '../models/settings.dart';
import 'http_transport.dart';

class RealAuthApi implements AuthApi {
  RealAuthApi(this._t);
  final HttpTransport _t;

  @override
  Future<RegisterResult> register(RegisterRequest req) async =>
      RegisterResult.fromJson(await _t.postJson('/auth/register', body: req.toJson(), auth: false));

  @override
  Future<void> verifyEmail(String token) => _t.send('POST', '/auth/verify-email', body: {'token': token}, auth: false);

  @override
  Future<LoginResult> login({required String email, required String password}) async =>
      LoginResult.fromJson(await _t.postJson('/auth/login', body: {'email': email, 'password': password}, auth: false));

  @override
  Future<TokenPair> verifyMfa({required String mfaToken, required String code}) async {
    final j = await _t.postJson('/auth/mfa/verify', body: {'mfa_token': mfaToken, 'code': code}, auth: false);
    return TokenPair(accessToken: reqStr(j, 'access_token'), refreshToken: reqStr(j, 'refresh_token'));
  }

  @override
  Future<TokenPair> refresh(String refreshToken) async {
    final j = await _t.postJson('/auth/refresh', body: {'refresh_token': refreshToken}, auth: false);
    return TokenPair(accessToken: reqStr(j, 'access_token'), refreshToken: str(j['refresh_token']) ?? refreshToken);
  }

  @override
  Future<void> logout(String refreshToken) => _t.send('POST', '/auth/logout', body: {'refresh_token': refreshToken});

  @override
  Future<void> forgotPassword(String email) => _t.send('POST', '/auth/forgot-password', body: {'email': email}, auth: false);

  @override
  Future<void> resetPassword({required String token, required String newPassword}) =>
      _t.send('POST', '/auth/reset-password', body: {'token': token, 'new_password': newPassword}, auth: false);

  @override
  Future<AuthUser> me() async => AuthUser.fromJson(await _t.getJson('/auth/me'));
}

class RealConsentApi implements ConsentApi {
  RealConsentApi(this._t);
  final HttpTransport _t;

  @override
  Future<ConsentState> get() async => ConsentState.fromJson(await _t.getJson('/consent'));

  @override
  Future<ConsentEntry> set(ConsentScope scope, {required bool granted, required String policyVersion}) async {
    final j = asJson(await _t.send('PUT', '/consent/${scope.wire}', body: {'granted': granted, 'policy_version': policyVersion}));
    return j.isEmpty
        ? ConsentEntry(scope: scope, granted: granted, version: policyVersion, at: DateTime.now())
        : ConsentEntry.fromJson(scope, j);
  }
}

class RealSettingsApi implements SettingsApi {
  RealSettingsApi(this._t);
  final HttpTransport _t;

  @override
  Future<UserSettings> get() async => UserSettings.fromJson(await _t.getJson('/settings'));

  @override
  Future<UserSettings> update(SettingsPatch patch) async =>
      UserSettings.fromJson(asJson(await _t.send('PUT', '/settings', body: patch.toJson())));
}

class RealPauseApi implements PauseApi {
  RealPauseApi(this._t);
  final HttpTransport _t;

  @override
  Future<PauseState> get() async => PauseState.fromJson(await _t.getJson('/pause'));

  @override
  Future<PauseState> pause({int? minutes, bool untilEndOfDay = false}) async =>
      PauseState.fromJson(await _t.postJson('/pause', body: {'minutes': ?minutes, if (untilEndOfDay) 'until_end_of_day': true}));

  @override
  Future<PauseState> resume() async {
    await _t.send('DELETE', '/pause');
    return PauseState.running;
  }
}

class RealPrivacyApi implements PrivacyApi {
  RealPrivacyApi(this._t);
  final HttpTransport _t;

  @override
  Future<DataSummary> dataSummary() async => DataSummary.fromJson(await _t.getJson('/me/data-summary'));

  @override
  Future<ExportJob> requestExport() async => ExportJob.fromJson(await _t.postJson('/me/data-export'));

  @override
  Future<ExportJob> exportStatus(String id) async => ExportJob.fromJson(await _t.getJson('/me/data-export/${Uri.encodeComponent(id)}'));

  @override
  Future<void> deleteAccount() => _t.send('DELETE', '/me');
}
