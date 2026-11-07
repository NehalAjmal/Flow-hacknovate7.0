// ════════════════════════════════════════════════════════════════════════════
//  API CONNECTOR — the one place that decides mock vs real.
//
//  BACKEND TEAM: when an area is live on the server, change its entry in
//  [defaultApiModes] from ApiMode.mock to ApiMode.real. Nothing else.
//
//  Dev builds  (`flutter run --dart-define=FLOW_DEV=true`):
//    defaults below apply; the dev panel (Ctrl/Cmd+Shift+D) can flip any
//    area at runtime and change the backend URL.
//  Release builds (no flag):
//    kDevBuild is a compile-time `false`, every area is forced to real and the
//    compiler drops all mock + dev-panel code from the binary.
//
//  SHIPPING CHECKLIST: delete lib/api/mock/ and lib/dev/, then remove the
//  `kDevBuild && …` branches in this file. The analyzer will point at every
//  remaining reference.
// ════════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config.dart';
import '../core/token_store.dart';
import 'contracts/account_api.dart';
import 'contracts/agent_api.dart';
import 'contracts/auth_api.dart';
import 'contracts/insights_api.dart';
import 'contracts/meta_api.dart';
import 'contracts/session_api.dart';
import 'contracts/schedule_api.dart';
import 'contracts/team_api.dart';
import 'mock/mock_apis.dart';
import 'mock/mock_backend.dart';
import 'real/http_transport.dart';
import 'real/real_agent.dart';
import 'real/real_auth_account.dart';
import 'real/real_insights_team.dart';
import 'real/real_schedule.dart';
import 'real/real_session.dart';

enum ApiArea {
  auth('Auth', '/auth/*'),
  consent('Consent', '/consent'),
  settings('Settings', '/settings'),
  pause('Pause', '/pause'),
  session('Session', '/session/*, /sessions'),
  interventions('Interventions', '/intervention/*'),
  breaks('Breaks & ratings', '/breaks, /ratings'),
  insights('Insights', '/user/*, /forecast, /export'),
  calendar('Calendar', '/calendar/*'),
  privacy('Privacy', '/me/*'),
  team('Team', '/team/*'),
  admin('Admin', '/admin/*'),
  meta('Flags & feedback', '/flags, /feedback, /changelog'),
  schedules('Schedules', '/user/schedules'),
  localAgent('Local agent', 'ws://localhost');

  const ApiArea(this.label, this.paths);
  final String label;
  final String paths;
}

enum ApiMode { mock, real }

/// ▼▼▼ Flip areas to `real` as the backend ships them. ▼▼▼
const Map<ApiArea, ApiMode> defaultApiModes = {
  ApiArea.auth: ApiMode.mock,
  ApiArea.consent: ApiMode.mock,
  ApiArea.settings: ApiMode.mock,
  ApiArea.pause: ApiMode.mock,
  ApiArea.session: ApiMode.mock,
  ApiArea.interventions: ApiMode.mock,
  ApiArea.breaks: ApiMode.mock,
  ApiArea.insights: ApiMode.mock,
  ApiArea.calendar: ApiMode.mock,
  ApiArea.privacy: ApiMode.mock,
  ApiArea.team: ApiMode.mock,
  ApiArea.admin: ApiMode.mock,
  ApiArea.meta: ApiMode.mock,
  ApiArea.schedules: ApiMode.mock,
  ApiArea.localAgent: ApiMode.mock,
};

/// ▲▲▲

/// Effective modes. In release builds this is always all-real.
class ApiModes extends Notifier<Map<ApiArea, ApiMode>> {
  @override
  Map<ApiArea, ApiMode> build() => kDevBuild ? Map.of(defaultApiModes) : {for (final a in ApiArea.values) a: ApiMode.real};

  /// Dev panel only.
  void set(ApiArea area, ApiMode mode) {
    if (!kDevBuild) return;
    state = {...state, area: mode};
  }

  void setAll(ApiMode mode) {
    if (!kDevBuild) return;
    state = {for (final a in ApiArea.values) a: mode};
  }
}

final apiModesProvider = NotifierProvider<ApiModes, Map<ApiArea, ApiMode>>(ApiModes.new);

ApiMode _mode(Ref ref, ApiArea area) => ref.watch(apiModesProvider.select((m) => m[area] ?? ApiMode.real));

bool _isMock(Ref ref, ApiArea area) => kDevBuild && _mode(ref, area) == ApiMode.mock;

/// Mixed-mode pitfalls, shown in the dev panel.
List<String> apiModeWarnings(Map<ApiArea, ApiMode> modes) {
  final authMock = modes[ApiArea.auth] == ApiMode.mock;
  final anyRealServer = modes.entries.any((e) => e.key != ApiArea.localAgent && e.key != ApiArea.auth && e.value == ApiMode.real);
  return [
    if (authMock && anyRealServer)
      'Auth is mocked but some areas are real: the real backend will reject the mock token (401). Switch Auth to real.',
  ];
}

// ── shared infrastructure ──────────────────────────────────────────────────

class BaseUrl extends Notifier<String> {
  @override
  String build() => kDefaultApiBase;

  void set(String url) {
    if (kDevBuild) state = url;
  }
}

final apiBaseUrlProvider = NotifierProvider<BaseUrl, String>(BaseUrl.new);

/// Fires when the backend (or mock) says the session can't be refreshed.
/// AuthController listens and signs the user out.
final sessionExpiredProvider = Provider<StreamController<void>>((ref) {
  final c = StreamController<void>.broadcast();
  ref.onDispose(c.close);
  return c;
});

/// Dev request log sink. No-op in release.
final requestLoggerProvider = Provider<RequestLogger?>((ref) => null);

final tokenStoreProvider = Provider<TokenStore>((ref) {
  // Mock auth keeps tokens in memory so a restart = signed out, matching the
  // in-memory mock backend.
  if (_isMock(ref, ApiArea.auth)) return MemoryTokenStore();
  return SecureTokenStore();
});

final httpTransportProvider = Provider<HttpTransport>((ref) {
  final expired = ref.watch(sessionExpiredProvider);
  final t = HttpTransport(
    baseUrl: () => ref.read(apiBaseUrlProvider),
    tokens: ref.watch(tokenStoreProvider),
    logger: ref.watch(requestLoggerProvider),
    onSessionExpired: () => expired.add(null),
  );
  ref.onDispose(t.close);
  return t;
});

/// DEV ONLY — the in-memory fake backend shared by all mock APIs.
final mockBackendProvider = Provider<MockBackend>((ref) {
  final expired = ref.watch(sessionExpiredProvider);
  final b = MockBackend(logger: ref.watch(requestLoggerProvider))..onSessionExpired = () => expired.add(null);
  ref.onDispose(b.dispose);
  return b;
});

// ── one provider per contract ──────────────────────────────────────────────

final authApiProvider = Provider<AuthApi>(
  (ref) => _isMock(ref, ApiArea.auth) ? MockAuthApi(ref.watch(mockBackendProvider)) : RealAuthApi(ref.watch(httpTransportProvider)),
);

final consentApiProvider = Provider<ConsentApi>(
  (ref) =>
      _isMock(ref, ApiArea.consent) ? MockConsentApi(ref.watch(mockBackendProvider)) : RealConsentApi(ref.watch(httpTransportProvider)),
);

final settingsApiProvider = Provider<SettingsApi>(
  (ref) =>
      _isMock(ref, ApiArea.settings) ? MockSettingsApi(ref.watch(mockBackendProvider)) : RealSettingsApi(ref.watch(httpTransportProvider)),
);

final pauseApiProvider = Provider<PauseApi>(
  (ref) => _isMock(ref, ApiArea.pause) ? MockPauseApi(ref.watch(mockBackendProvider)) : RealPauseApi(ref.watch(httpTransportProvider)),
);

final sessionApiProvider = Provider<SessionApi>(
  (ref) =>
      _isMock(ref, ApiArea.session) ? MockSessionApi(ref.watch(mockBackendProvider)) : RealSessionApi(ref.watch(httpTransportProvider)),
);

final interventionApiProvider = Provider<InterventionApi>(
  (ref) => _isMock(ref, ApiArea.interventions)
      ? MockInterventionApi(ref.watch(mockBackendProvider))
      : RealInterventionApi(ref.watch(httpTransportProvider)),
);

final breakApiProvider = Provider<BreakApi>(
  (ref) => _isMock(ref, ApiArea.breaks) ? MockBreakApi(ref.watch(mockBackendProvider)) : RealBreakApi(ref.watch(httpTransportProvider)),
);

final insightsApiProvider = Provider<InsightsApi>(
  (ref) =>
      _isMock(ref, ApiArea.insights) ? MockInsightsApi(ref.watch(mockBackendProvider)) : RealInsightsApi(ref.watch(httpTransportProvider)),
);

final calendarApiProvider = Provider<CalendarApi>(
  (ref) =>
      _isMock(ref, ApiArea.calendar) ? MockCalendarApi(ref.watch(mockBackendProvider)) : RealCalendarApi(ref.watch(httpTransportProvider)),
);

final scheduleApiProvider = Provider<ScheduleApi>(
  (ref) =>
      _isMock(ref, ApiArea.schedules) ? MockScheduleApi(ref.watch(mockBackendProvider)) : RealScheduleApi(ref.watch(httpTransportProvider)),
);

final privacyApiProvider = Provider<PrivacyApi>(
  (ref) =>
      _isMock(ref, ApiArea.privacy) ? MockPrivacyApi(ref.watch(mockBackendProvider)) : RealPrivacyApi(ref.watch(httpTransportProvider)),
);

final teamApiProvider = Provider<TeamApi>(
  (ref) => _isMock(ref, ApiArea.team) ? MockTeamApi(ref.watch(mockBackendProvider)) : RealTeamApi(ref.watch(httpTransportProvider)),
);

final adminApiProvider = Provider<AdminApi>(
  (ref) => _isMock(ref, ApiArea.admin) ? MockAdminApi(ref.watch(mockBackendProvider)) : RealAdminApi(ref.watch(httpTransportProvider)),
);

final metaApiProvider = Provider<MetaApi>(
  (ref) => _isMock(ref, ApiArea.meta) ? MockMetaApi(ref.watch(mockBackendProvider)) : RealMetaApi(ref.watch(httpTransportProvider)),
);

final localAgentApiProvider = Provider<LocalAgentApi>((ref) {
  if (_isMock(ref, ApiArea.localAgent)) {
    final m = MockLocalAgentApi(ref.watch(mockBackendProvider));
    ref.onDispose(m.dispose);
    return m;
  }
  return RealLocalAgentApi(kDefaultAgentUrl);
});
