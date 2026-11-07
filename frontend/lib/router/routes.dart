import '../api/models/auth.dart';
import '../api/models/consent.dart';
import '../state/auth_controller.dart';

/// Route paths (team doc §6.3 plus auth sub-flows and history).
abstract final class Routes {
  static const splash = '/splash';
  static const welcome = '/welcome';
  static const login = '/login';
  static const register = '/register';
  static const mfa = '/mfa';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const verifyEmail = '/verify-email';
  static const consent = '/consent';

  /// Landing page of an admin's invite link: `/invite?token=…`.
  static const invite = '/invite';

  /// The welcome guide replayed from Settings › Help (same screen as [consent]).
  static const guide = '/guide';

  static const home = '/';
  static const sessionStart = '/session/start';
  static const sessionActive = '/session/active';
  static const sessionBreak = '/session/break';
  static const sessionEnd = '/session/end'; // /session/end/:id
  static const history = '/history';
  static const patterns = '/patterns';
  static const settings = '/settings';
  static const privacy = '/privacy';
  static const team = '/team';
  static const admin = '/admin';
  static const export = '/export';
  static const feedback = '/feedback';

  static String sessionEndFor(String id) => '$sessionEnd/${Uri.encodeComponent(id)}';

  /// Reachable while signed out.
  static const public = {welcome, login, register, forgotPassword, resetPassword, verifyEmail, invite};

  /// Reachable while signed in even when required consent is missing.
  static const consentExempt = {consent, guide, privacy, verifyEmail};
}

/// Pure redirect logic so it can be unit-tested without widgets.
///
/// [consent] is null while loading; we don't redirect on unknown consent to
/// avoid bouncing the user around during startup.
String? redirectFor({required String location, required AuthState auth, ConsentState? consent}) {
  switch (auth) {
    case AuthUnknown():
      return location == Routes.splash ? null : Routes.splash;

    case SignedOut():
      return Routes.public.contains(location) ? null : Routes.welcome;

    case MfaRequired():
      return location == Routes.mfa ? null : Routes.mfa;

    case SignedIn(:final user):
      final onAuthPage =
          location == Routes.splash || location == Routes.mfa || (Routes.public.contains(location) && location != Routes.verifyEmail);
      if (consent != null && !consent.canUseFlow && !Routes.consentExempt.contains(location)) {
        return Routes.consent;
      }
      if (onAuthPage) return Routes.home;
      if (location.startsWith(Routes.admin) && user.role != UserRole.admin) return Routes.home;
      if (location.startsWith(Routes.team) && !user.hasTeam) return Routes.home;
      return null;
  }
}
