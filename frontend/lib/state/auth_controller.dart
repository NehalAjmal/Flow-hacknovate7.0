import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_connector.dart';
import '../api/api_error.dart';
import '../api/models/auth.dart';

sealed class AuthState {
  const AuthState();
}

/// Bootstrapping: reading stored tokens / calling /auth/me.
class AuthUnknown extends AuthState {
  const AuthUnknown();
}

class SignedOut extends AuthState {
  const SignedOut({this.message});

  /// Why the user landed here (e.g. "session expired"), shown on /login.
  final String? message;
}

class MfaRequired extends AuthState {
  const MfaRequired({required this.mfaToken, required this.email});
  final String mfaToken;
  final String email;
}

class SignedIn extends AuthState {
  const SignedIn(this.user);
  final AuthUser user;
}

/// Owns tokens + the current user. All other state hangs off this.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final sub = ref.watch(sessionExpiredProvider).stream.listen((_) => _expire());
    ref.onDispose(sub.cancel);
    // Re-bootstrap if the dev panel swaps the auth implementation.
    ref.watch(authApiProvider);
    unawaited(Future.microtask(_bootstrap));
    return const AuthUnknown();
  }

  Future<void> _bootstrap() async {
    final tokens = await ref.read(tokenStoreProvider).read();
    if (!ref.mounted) return;
    if (tokens == null) {
      state = const SignedOut();
      return;
    }
    try {
      final me = await ref.read(authApiProvider).me();
      if (ref.mounted) state = SignedIn(me);
    } on ApiError catch (e) {
      if (!ref.mounted) return;
      if (e.isNetwork) {
        // Offline at launch: we can't verify the token. Show sign-in with a
        // clear reason rather than an app full of failing screens.
        state = const SignedOut(message: "Can't reach Flow. Check your connection and sign in again.");
      } else {
        await ref.read(tokenStoreProvider).clear();
        if (ref.mounted) state = const SignedOut();
      }
    }
  }

  Future<void> _establish(TokenPair tokens) async {
    await ref.read(tokenStoreProvider).write(tokens);
    final me = await ref.read(authApiProvider).me();
    if (ref.mounted) state = SignedIn(me);
  }

  /// Throws [ApiError] on failure; the form shows `e.message`.
  Future<void> login({required String email, required String password}) async {
    final res = await ref.read(authApiProvider).login(email: email.trim(), password: password);
    if (res.mfaRequired) {
      final token = res.mfaToken;
      if (token == null) throw const ApiError(ApiError.badResponse, 'Server asked for MFA without a token.');
      state = MfaRequired(mfaToken: token, email: email.trim());
      return;
    }
    final tokens = res.tokens;
    if (tokens == null) throw const ApiError(ApiError.badResponse, 'Server did not return tokens.');
    await _establish(tokens);
  }

  Future<void> verifyMfa(String code) async {
    final s = state;
    if (s is! MfaRequired) throw StateError('No MFA challenge in progress');
    final tokens = await ref.read(authApiProvider).verifyMfa(mfaToken: s.mfaToken, code: code.trim());
    await _establish(tokens);
  }

  void cancelMfa() => state = const SignedOut();

  Future<RegisterResult> register(RegisterRequest req) => ref.read(authApiProvider).register(req);

  Future<void> logout() async {
    final store = ref.read(tokenStoreProvider);
    final tokens = await store.read();
    // Logout must actually stop tracking (the old app claimed it did, but
    // didn't). End the running session first, best-effort.
    try {
      final active = await ref.read(sessionApiProvider).active();
      if (active != null) await ref.read(sessionApiProvider).end(active.sessionId);
    } catch (_) {}
    try {
      if (tokens != null) await ref.read(authApiProvider).logout(tokens.refreshToken);
    } catch (_) {
      // Revocation failing must not keep the user signed in locally.
    }
    await store.clear();
    if (ref.mounted) state = const SignedOut();
  }

  Future<void> _expire() async {
    await ref.read(tokenStoreProvider).clear();
    if (ref.mounted && state is! SignedOut) {
      state = const SignedOut(message: 'Your session expired. Please sign in again.');
    }
  }

  /// After email verification or profile changes.
  Future<void> reloadUser() async {
    final me = await ref.read(authApiProvider).me();
    if (ref.mounted) state = SignedIn(me);
  }
}

final authProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

/// The signed-in user, or null. Data providers watch this so they refetch on
/// account switch and clear on sign-out.
final currentUserProvider = Provider<AuthUser?>((ref) {
  final s = ref.watch(authProvider);
  return s is SignedIn ? s.user : null;
});

final currentUserIdProvider = Provider<String?>((ref) => ref.watch(currentUserProvider)?.id);
