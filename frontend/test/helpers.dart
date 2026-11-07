import 'package:flow/api/api_connector.dart';
import 'package:flow/api/mock/mock_apis.dart';
import 'package:flow/api/mock/mock_backend.dart';
import 'package:flow/core/token_store.dart';
import 'package:flow/state/session_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// Overrides every API provider with its mock, regardless of FLOW_DEV.
List<Override> mockOverrides(MockBackend b) => [
  tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
  mockBackendProvider.overrideWith((ref) {
    b.onSessionExpired = () => ref.read(sessionExpiredProvider).add(null);
    ref.onDispose(b.dispose);
    return b;
  }),
  authApiProvider.overrideWithValue(MockAuthApi(b)),
  consentApiProvider.overrideWithValue(MockConsentApi(b)),
  settingsApiProvider.overrideWithValue(MockSettingsApi(b)),
  pauseApiProvider.overrideWithValue(MockPauseApi(b)),
  sessionApiProvider.overrideWithValue(MockSessionApi(b)),
  interventionApiProvider.overrideWithValue(MockInterventionApi(b)),
  breakApiProvider.overrideWithValue(MockBreakApi(b)),
  insightsApiProvider.overrideWithValue(MockInsightsApi(b)),
  calendarApiProvider.overrideWithValue(MockCalendarApi(b)),
  privacyApiProvider.overrideWithValue(MockPrivacyApi(b)),
  teamApiProvider.overrideWithValue(MockTeamApi(b)),
  adminApiProvider.overrideWithValue(MockAdminApi(b)),
  metaApiProvider.overrideWithValue(MockMetaApi(b)),
  scheduleApiProvider.overrideWithValue(MockScheduleApi(b)),
  localAgentApiProvider.overrideWith((ref) {
    final agent = MockLocalAgentApi(b);
    ref.onDispose(agent.dispose);
    return agent;
  }),
  sessionTimingProvider.overrideWithValue(const SessionTiming(pollEvery: Duration(milliseconds: 15), retryStreamAfterPolls: 1000)),
];

ProviderContainer mockContainer(MockBackend b) {
  final c = ProviderContainer.test(overrides: mockOverrides(b), retry: (_, _) => null);
  // The mock backend's expiry hook is installed when its provider is built.
  c.read(mockBackendProvider);
  return c;
}

Future<void> pump([int ms = 60]) => Future<void>.delayed(Duration(milliseconds: ms));

/// Polls [check] until it returns true or [timeout] passes.
Future<void> eventually(bool Function() check, {Duration timeout = const Duration(seconds: 2)}) async {
  final end = DateTime.now().add(timeout);
  while (!check()) {
    if (DateTime.now().isAfter(end)) throw StateError('Condition not met within $timeout');
    await pump(10);
  }
}
