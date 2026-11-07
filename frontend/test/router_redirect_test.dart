import 'package:flow/api/models/auth.dart';
import 'package:flow/api/models/consent.dart';
import 'package:flow/router/routes.dart';
import 'package:flow/state/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';

AuthUser _user(UserRole role, {String? team}) => AuthUser(id: 'u', name: 'U', email: 'u@x', role: role, teamId: team);

final _consented = ConsentState(
  policyVersion: 'v1',
  entries: {ConsentScope.behavior: const ConsentEntry(scope: ConsentScope.behavior, granted: true, version: 'v1')},
);
const _noConsent = ConsentState(policyVersion: 'v1', entries: {});

void main() {
  test('unknown auth → splash', () {
    expect(redirectFor(location: Routes.home, auth: const AuthUnknown()), Routes.splash);
    expect(redirectFor(location: Routes.splash, auth: const AuthUnknown()), isNull);
  });

  test('signed out: public pages allowed, everything else → welcome', () {
    for (final p in Routes.public) {
      expect(
        redirectFor(location: p, auth: const SignedOut()),
        isNull,
        reason: p,
      );
    }
    expect(redirectFor(location: Routes.admin, auth: const SignedOut()), Routes.welcome);
    expect(redirectFor(location: Routes.home, auth: const SignedOut()), Routes.welcome);
  });

  test('MFA pending pins the user to /mfa', () {
    const s = MfaRequired(mfaToken: 't', email: 'a@b');
    expect(redirectFor(location: Routes.home, auth: s), Routes.mfa);
    expect(redirectFor(location: Routes.mfa, auth: s), isNull);
  });

  test('signed in on an auth page → home', () {
    final s = SignedIn(_user(UserRole.solo));
    expect(redirectFor(location: Routes.login, auth: s, consent: _consented), Routes.home);
    expect(redirectFor(location: Routes.splash, auth: s, consent: _consented), Routes.home);
  });

  test('missing required consent → /consent, except privacy and consent itself', () {
    final s = SignedIn(_user(UserRole.solo));
    expect(redirectFor(location: Routes.home, auth: s, consent: _noConsent), Routes.consent);
    expect(redirectFor(location: Routes.sessionStart, auth: s, consent: _noConsent), Routes.consent);
    expect(redirectFor(location: Routes.consent, auth: s, consent: _noConsent), isNull);
    expect(redirectFor(location: Routes.privacy, auth: s, consent: _noConsent), isNull);
  });

  test('consent still loading does not redirect', () {
    expect(redirectFor(location: Routes.home, auth: SignedIn(_user(UserRole.solo))), isNull);
  });

  test('admin route is admin-only; team route needs a team', () {
    expect(
      redirectFor(
        location: Routes.admin,
        auth: SignedIn(_user(UserRole.employee, team: 't')),
        consent: _consented,
      ),
      Routes.home,
    );
    expect(
      redirectFor(
        location: Routes.admin,
        auth: SignedIn(_user(UserRole.admin, team: 't')),
        consent: _consented,
      ),
      isNull,
    );
    expect(redirectFor(location: Routes.team, auth: SignedIn(_user(UserRole.solo)), consent: _consented), Routes.home);
    expect(
      redirectFor(
        location: Routes.team,
        auth: SignedIn(_user(UserRole.employee, team: 't')),
        consent: _consented,
      ),
      isNull,
    );
  });
}
