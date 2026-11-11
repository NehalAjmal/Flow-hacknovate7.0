import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../api/api_connector.dart';
import '../api/models/agent.dart';
import '../api/models/consent.dart';
import '../api/models/day.dart';
import '../api/models/insights.dart';
import '../api/models/member.dart';
import '../api/models/meta.dart';
import '../api/models/privacy.dart';
import '../api/models/schedule.dart';
import '../api/models/session.dart';
import '../api/models/team.dart';
import 'account_controllers.dart';
import 'auth_controller.dart';
import 'session_controller.dart';

/// Read-only data. Every provider watches the user id so it refetches on
/// account switch (a sign-out drops everything at once).
///
/// Page switches must not flash a loader, so:
/// - [_cache]: data outlives its screen by [_keep]; going back is instant.
/// - [_refreshOn]: live changes refresh *in place*. A plain `ref.watch` would
///   rebuild the provider as a dependency change, which Riverpod surfaces as
///   AsyncLoading (the loader replaces the content); `invalidateSelf()` is a
///   refresh, so the old value stays on screen until the new one lands.
const _keep = Duration(minutes: 5);

/// Dev panel "Forget cached pages": bumping it reloads every cached provider
/// (a dependency change = a real reload with the loader, not a quiet refresh).
class CacheEpoch extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

final cacheEpochProvider = NotifierProvider<CacheEpoch, int>(CacheEpoch.new);

void _cache(Ref ref) {
  ref.watch(cacheEpochProvider);
  final link = ref.keepAlive();
  Timer? t;
  ref.onCancel(() => t = Timer(_keep, link.close));
  ref.onResume(() => t?.cancel());
  ref.onDispose(() => t?.cancel());
}

void _refreshOn<T>(Ref ref, ProviderListenable<T> p) => ref.listen<T>(p, (a, b) {
  if (a != b) ref.invalidateSelf();
});

/// Changes when a session starts or ends: totals, history and patterns move.
final _sessionIdProvider = Provider<String?>((ref) => ref.watch(liveSessionProvider).value?.session.sessionId);

FutureProvider<T> _userData<T>(Future<T> Function(Ref ref) load) => FutureProvider.autoDispose<T>((ref) {
  if (ref.watch(currentUserIdProvider) == null) throw StateError('Not signed in');
  _cache(ref);
  _refreshOn(ref, _sessionIdProvider);
  return load(ref);
});

final dashboardProvider = _userData<Dashboard>((ref) => ref.watch(insightsApiProvider).dashboard());
final patternsProvider = _userData<Patterns>((ref) => ref.watch(insightsApiProvider).patterns());
final forecastProvider = _userData<Forecast>((ref) => ref.watch(insightsApiProvider).forecast());
final focusDnaProvider = _userData<Uint8List>((ref) => ref.watch(insightsApiProvider).focusDnaPng());
final preCheckProvider = _userData<PreCheck>((ref) => ref.watch(sessionApiProvider).preCheck());
final calendarContextProvider = _userData<CalendarContext>((ref) => ref.watch(calendarApiProvider).context());
final dataSummaryProvider = _userData<DataSummary>((ref) => ref.watch(privacyApiProvider).dataSummary());

/// One day's timeline for the Score. Keyed by calendar day.
final dayTimelineProvider = FutureProvider.autoDispose.family<DayTimeline, DateTime>((ref, day) {
  if (ref.watch(currentUserIdProvider) == null) throw StateError('Not signed in');
  // refetch today when the live session changes
  final now = DateTime.now();
  if (_sameDay(day, now)) _refreshOn(ref, liveSessionRevisionProvider);
  _cache(ref);
  return ref.watch(insightsApiProvider).day(day);
});

/// Focus minutes per day for the rolling 4-week terrain (two months merged).
final rollingMinutesProvider = FutureProvider.autoDispose<Map<DateTime, int>>((ref) async {
  if (ref.watch(currentUserIdProvider) == null) throw StateError('Not signed in');
  _refreshOn(ref, liveSessionRevisionProvider);
  _cache(ref);
  final now = DateTime.now();
  final api = ref.watch(insightsApiProvider);
  final results = await Future.wait([api.month(DateTime(now.year, now.month - 1, 1)), api.month(now)]);
  return {...results[0], ...results[1]};
});

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

final sessionsPageProvider = FutureProvider.autoDispose.family<SessionPage, int>((ref, page) {
  if (ref.watch(currentUserIdProvider) == null) throw StateError('Not signed in');
  _cache(ref);
  _refreshOn(ref, _sessionIdProvider);
  return ref.watch(sessionApiProvider).list(page: page);
});

final replayProvider = FutureProvider.autoDispose.family<SessionReplay, String>((ref, sessionId) {
  _cache(ref);
  return ref.watch(sessionApiProvider).replay(sessionId);
});

final breaksProvider = FutureProvider.autoDispose.family<BreakSummary, String>((ref, sessionId) {
  _cache(ref);
  return ref.watch(breakApiProvider).list(sessionId);
});

// ── team / admin ───────────────────────────────────────────────────────────

final teamSummaryProvider = _userData<Suppressible<TeamMetrics>>((ref) => ref.watch(teamApiProvider).summary());
final adminSummaryProvider = _userData<Suppressible<AdminSummary>>((ref) => ref.watch(adminApiProvider).summary());
final adminTrendProvider = _userData<Suppressible<AdminTrend>>((ref) => ref.watch(adminApiProvider).trend());
final adminInsightsProvider = _userData<Suppressible<AdminInsights>>((ref) => ref.watch(adminApiProvider).insights());
final adminStrainProvider = _userData<Suppressible<TeamStrain>>((ref) => ref.watch(adminApiProvider).strain());
final adminMeetingWindowProvider = _userData<Suppressible<MeetingWindow>>((ref) => ref.watch(adminApiProvider).meetingWindow());
final adminPrivacyProvider = _userData<AdminPrivacyStatus>((ref) => ref.watch(adminApiProvider).privacyStatus());
final invitesProvider = _userData<List<Invite>>((ref) => ref.watch(adminApiProvider).invites());
final adminMembersProvider = _userData<List<MemberSummary>>((ref) => ref.watch(adminApiProvider).members());
final adminMemberProvider = FutureProvider.autoDispose.family<MemberDetail, String>((ref, id) {
  if (ref.watch(currentUserIdProvider) == null) throw StateError('Not signed in');
  _cache(ref);
  return ref.watch(adminApiProvider).member(id);
});
final auditLogProvider = _userData<List<AuditEntry>>((ref) => ref.watch(adminApiProvider).auditLog());

// ── meta ───────────────────────────────────────────────────────────────────

final flagsProvider = FutureProvider<FeatureFlags>((ref) async {
  if (ref.watch(currentUserIdProvider) == null) return FeatureFlags.empty;
  try {
    return await ref.watch(metaApiProvider).flags();
  } catch (_) {
    return FeatureFlags.empty; // flags must never break the app
  }
});

final changelogProvider = FutureProvider.autoDispose<List<ChangelogEntry>>((ref) {
  _cache(ref);
  return ref.watch(metaApiProvider).changelog();
});

// ── local agent ────────────────────────────────────────────────────────────

class AgentStatusController extends Notifier<AgentStatus> {
  @override
  AgentStatus build() {
    final api = ref.watch(localAgentApiProvider);
    final sub = api.events().listen((e) {
      if (e is AgentStatusEvent) state = e.status;
    });
    ref.onDispose(sub.cancel);
    api.status().then((s) {
      if (ref.mounted) state = s;
    }, onError: (Object _) {});
    return AgentStatus.offline;
  }

  Future<void> pair(String code) async {
    await ref.read(localAgentApiProvider).pair(code);
    final s = await ref.read(localAgentApiProvider).status();
    if (ref.mounted) state = s;
  }
}

final agentStatusProvider = NotifierProvider<AgentStatusController, AgentStatus>(AgentStatusController.new);

final liveSignalsProvider = StreamProvider.autoDispose<LiveSignals>(
  (ref) => ref.watch(localAgentApiProvider).events().where((e) => e is AgentSignalsEvent).map((e) => (e as AgentSignalsEvent).signals),
);

// ── "what is being sensed right now" (doc §6.1 principle 5) ───────────────

class Sensing {
  const Sensing({required this.behavior, required this.camera, required this.calendar, required this.llm});
  final bool behavior;
  final bool camera;
  final bool calendar;
  final bool llm;
}

final sensingProvider = Provider<Sensing>((ref) {
  final consent = ref.watch(consentProvider).value;
  final settings = ref.watch(settingsProvider).value;
  final agent = ref.watch(agentStatusProvider);
  bool c(ConsentScope s) => consent?.granted(s) ?? false;
  return Sensing(
    behavior: c(ConsentScope.behavior) && agent.behaviorOn,
    camera: c(ConsentScope.camera) && (settings?.cameraEnabled ?? false) && agent.cameraOn,
    calendar: c(ConsentScope.calendar) && (settings?.calendarEnabled ?? false),
    llm: c(ConsentScope.llm) && (settings?.llmEnabled ?? false),
  );
});

/// The seven day timelines of the week starting [weekStart] (a Monday).
final weekTimelinesProvider = FutureProvider.autoDispose.family<List<DayTimeline>, DateTime>((ref, weekStart) {
  if (ref.watch(currentUserIdProvider) == null) throw StateError('Not signed in');
  _refreshOn(ref, liveSessionRevisionProvider);
  _cache(ref);
  final api = ref.watch(insightsApiProvider);
  return Future.wait([for (var i = 0; i < 7; i++) api.day(DateTime(weekStart.year, weekStart.month, weekStart.day + i))]);
});

/// Focus minutes per day for the last 12 months (year heatmap).
final yearMinutesProvider = FutureProvider.autoDispose<Map<DateTime, int>>((ref) async {
  if (ref.watch(currentUserIdProvider) == null) throw StateError('Not signed in');
  _cache(ref);
  _refreshOn(ref, _sessionIdProvider);
  final now = DateTime.now();
  final api = ref.watch(insightsApiProvider);
  final months = await Future.wait([for (var i = 11; i >= 0; i--) api.month(DateTime(now.year, now.month - i, 1))]);
  return {for (final m in months) ...m};
});

// ── schedules (routines) ───────────────────────────────────────────────────

class SchedulesController extends AsyncNotifier<List<Schedule>> {
  @override
  Future<List<Schedule>> build() {
    if (ref.watch(currentUserIdProvider) == null) throw StateError('Not signed in');
    return ref.watch(scheduleApiProvider).list();
  }

  // Home's Score shows occurrences: refresh every day timeline after a change.
  void _changed() {
    ref.invalidate(dayTimelineProvider);
    ref.invalidate(weekTimelinesProvider);
  }

  Future<Schedule> add(Schedule s) async {
    final saved = await ref.read(scheduleApiProvider).create(s);
    state = AsyncData([...?state.value, saved]);
    _changed();
    return saved;
  }

  /// Optimistic; rolls back if the backend refuses.
  Future<void> save(Schedule s) async {
    final before = state.value;
    state = AsyncData([for (final x in before ?? const <Schedule>[]) x.id == s.id ? s : x]);
    try {
      await ref.read(scheduleApiProvider).update(s);
      _changed();
    } catch (_) {
      if (before != null) state = AsyncData(before);
      rethrow;
    }
  }

  Future<void> remove(String id) async {
    final before = state.value;
    state = AsyncData([
      for (final x in before ?? const <Schedule>[])
        if (x.id != id) x,
    ]);
    try {
      await ref.read(scheduleApiProvider).delete(id);
      _changed();
    } catch (_) {
      if (before != null) state = AsyncData(before);
      rethrow;
    }
  }
}

final schedulesProvider = AsyncNotifierProvider<SchedulesController, List<Schedule>>(SchedulesController.new);
