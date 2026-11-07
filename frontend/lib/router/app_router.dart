import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/models/session.dart';
import '../core/config.dart';
import '../dev/kit_gallery.dart';
import '../screens/account_screens.dart';
import '../screens/auth_screens.dart';
import '../screens/guide_screen.dart';
import '../screens/home_screen.dart';
import '../screens/insights_screen.dart';
import '../screens/privacy_screen.dart';
import '../screens/session_screens.dart';
import '../screens/settings_screen.dart';
import '../screens/not_found_screen.dart';
import '../screens/shell.dart';
import '../screens/team_screens.dart';
import '../state/account_controllers.dart';
import '../state/auth_controller.dart';
import 'routes.dart';

/// Bridges Riverpod → go_router so redirects re-run when auth/consent change.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(authProvider, (_, _) => notifyListeners());
    ref.listen(consentProvider, (_, _) => notifyListeners());
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final consent = auth is SignedIn ? ref.read(consentProvider).value : null;
      if (kDevBuild && state.matchedLocation.startsWith('/dev/')) {
        // /dev/login hands over to the normal redirects once signed in
        if (state.matchedLocation == '/dev/login' && auth is SignedIn) {
          return redirectFor(location: '/', auth: auth, consent: consent) ?? '/';
        }
        return null;
      }
      return redirectFor(location: state.matchedLocation, auth: auth, consent: consent);
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      if (kDevBuild) GoRoute(path: '/dev/kit', builder: (_, _) => const KitGallery()),
      if (kDevBuild)
        GoRoute(
          path: '/dev/login',
          builder: (_, s) => DevLogin(who: s.uri.queryParameters['as'] ?? 'solo'),
        ),
      GoRoute(path: Routes.welcome, builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: Routes.register,
        builder: (_, s) => RegisterScreen(inviteToken: s.uri.queryParameters['invite']),
      ),
      GoRoute(
        path: Routes.invite,
        builder: (_, s) => InviteLandingScreen(token: s.uri.queryParameters['token'] ?? ''),
      ),
      GoRoute(path: Routes.mfa, builder: (_, _) => const MfaScreen()),
      GoRoute(path: Routes.forgotPassword, builder: (_, _) => const ForgotPasswordScreen()),
      GoRoute(
        path: Routes.resetPassword,
        builder: (_, s) => ResetPasswordScreen(token: s.uri.queryParameters['token'] ?? ''),
      ),
      GoRoute(
        path: Routes.verifyEmail,
        builder: (_, s) => VerifyEmailScreen(token: s.uri.queryParameters['token']),
      ),
      // New users land on the welcome guide; step 2 is the consent step.
      GoRoute(path: Routes.consent, builder: (_, _) => const GuideScreen()),
      GoRoute(path: Routes.guide, builder: (_, _) => const GuideScreen()),

      // Full-screen, outside the shell: the break should not show navigation.
      GoRoute(path: Routes.sessionBreak, builder: (_, _) => const BreakScreen()),

      ShellRoute(
        builder: (_, _, child) => AppShell(child: child),
        routes: [
          GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
          // starting lives in Home's deck; old links land there
          GoRoute(path: Routes.sessionStart, redirect: (_, _) => Routes.home),
          GoRoute(path: Routes.sessionActive, builder: (_, _) => const ActiveSessionScreen()),
          GoRoute(
            path: '${Routes.sessionEnd}/:id',
            builder: (_, s) => SessionEndScreen(
              sessionId: s.pathParameters['id']!,
              summary: s.extra is SessionSummary ? s.extra! as SessionSummary : null,
            ),
          ),
          GoRoute(path: Routes.history, builder: (_, _) => const InsightsScreen()),
          GoRoute(path: Routes.patterns, builder: (_, _) => const InsightsScreen()),
          GoRoute(path: Routes.settings, builder: (_, _) => const SettingsScreen()),
          GoRoute(path: Routes.privacy, builder: (_, _) => const PrivacyScreen()),
          GoRoute(path: Routes.team, builder: (_, _) => const TeamScreen()),
          GoRoute(path: Routes.admin, builder: (_, _) => const AdminScreen()),
          // Focus DNA lives in Insights now
          GoRoute(path: Routes.export, builder: (_, _) => const InsightsScreen()),
          GoRoute(path: Routes.feedback, builder: (_, _) => const FeedbackScreen()),
        ],
      ),
    ],
    errorBuilder: (_, s) => NotFoundScreen(uri: s.uri),
  );
  ref.onDispose(router.dispose);
  return router;
});
