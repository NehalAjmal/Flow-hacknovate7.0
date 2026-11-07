// DEV ONLY. Never referenced from release code paths (see api_connector.dart).
import 'dart:async';

import '../api_error.dart';
import '../models/schedule.dart';
import '../models/auth.dart';
import '../models/consent.dart';
import '../models/intervention.dart';
import '../models/session.dart';
import '../models/settings.dart';
import '../models/team.dart';
import '../real/http_transport.dart' show RequestLogEntry, RequestLogger;

/// Scenarios let the frontend reach every UI state without a backend.
enum MockScenario {
  normal('Normal', 'Break nudge after a few ticks'),
  quiet('Quiet', 'No interventions'),
  newUser('New user', 'No history, still learning'),
  streamDrops('Stream drops', 'Live stream fails → polling fallback'),
  tokenExpiry('Token expires', 'Next call returns 401 + failed refresh'),
  backendDown('Backend down', 'Every call fails with a network error'),
  smallTeam('Small team', 'Team/admin data suppressed (group < 5)');

  const MockScenario(this.label, this.description);
  final String label;
  final String description;
}

class MockConfig {
  const MockConfig({
    this.latency = const Duration(milliseconds: 250),
    this.tick = const Duration(seconds: 2),
    this.ticksToIntervention = 8,
  });

  final Duration latency;
  final Duration tick;
  final int ticksToIntervention;

  /// For tests: no latency, fast ticks.
  static const fast = MockConfig(latency: Duration.zero, tick: Duration(milliseconds: 10), ticksToIntervention: 3);
}

class MockUser {
  MockUser({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    this.teamId,
    this.mfa = false,
    this.emailVerified = true,
  });

  final String id;
  final String name;
  final String email;
  String password;
  final UserRole role;
  final String? teamId;
  final bool mfa;
  bool emailVerified;

  AuthUser toAuthUser() => AuthUser(id: id, name: name, email: email, role: role, teamId: teamId, emailVerified: emailVerified);
}

/// One running mock session.
class MockRun {
  MockRun(this.session);

  ActiveSession session;
  final events = StreamController<SessionEvent>.broadcast();
  Timer? timer;
  int ticksSinceReset = 0;
  int elapsedTicks = 0;
  DateTime? pausedAt;
  late SessionStatus status;
  int breaksSuggested = 0;
  int breaksTaken = 0;

  void dispose() {
    timer?.cancel();
    unawaited(events.close());
  }
}

/// In-memory fake of the whole backend. Stateful and shared by all mock APIs.
class MockBackend {
  MockBackend({this.config = const MockConfig(), this.logger});

  final MockConfig config;
  RequestLogger? logger;

  /// Called when the mock simulates an expired session (tokenExpiry).
  void Function()? onSessionExpired;

  MockScenario scenario = MockScenario.normal;

  static const policyVersion = '2026-11-01';
  static const mfaCode = '123456';
  static const teamId = 'team_alpha';

  final users = <String, MockUser>{
    'solo@flow.dev': MockUser(id: 'u_solo', name: 'Sam Solo', email: 'solo@flow.dev', password: 'password', role: UserRole.solo),
    'employee@flow.dev': MockUser(
      id: 'u_emp',
      name: 'Eli Employee',
      email: 'employee@flow.dev',
      password: 'password',
      role: UserRole.employee,
      teamId: teamId,
    ),
    'admin@flow.dev': MockUser(
      id: 'u_admin',
      name: 'Ada Admin',
      email: 'admin@flow.dev',
      password: 'password',
      role: UserRole.admin,
      teamId: teamId,
      mfa: true,
    ),
    'new@flow.dev': MockUser(id: 'u_new', name: 'Nia New', email: 'new@flow.dev', password: 'password', role: UserRole.solo),
  };

  String? currentUserId;
  final pendingMfa = <String, String>{}; // mfaToken -> email
  final consent = <String, ConsentState>{};
  final settings = <String, UserSettings>{};
  final pause = <String, PauseState>{};
  final history = <String, List<SessionSummary>>{};
  final schedules = <String, List<Schedule>>{};

  /// The user's routines (seeded with one for everyone but the new user).
  List<Schedule> schedulesFor(MockUser u) => schedules.putIfAbsent(u.id, () {
    if (u.email.startsWith('new@')) return <Schedule>[];
    return [
      const Schedule(id: 'sch_1', name: 'Weekly review', start: '17:40', end: '18:20', weekdays: [1, 2, 3, 4, 5], demand: Demand.light),
    ];
  });
  final interventions = <String, Intervention>{};
  final breaks = <String, BreakRecord>{};
  final invites = <Invite>[];
  final audit = <AuditEntry>[];
  MockRun? run;

  /// No nudges while the user is on a break.
  bool breakActive = false;
  int _seq = 0;

  String nextId(String prefix) => '${prefix}_${++_seq}';

  MockUser? get currentUser => currentUserId == null ? null : users.values.where((u) => u.id == currentUserId).firstOrNull;

  MockUser requireUser() {
    final u = currentUser;
    if (u == null) throw const ApiError(ApiError.sessionExpired, 'Not signed in (mock).', status: 401);
    return u;
  }

  ConsentState consentFor(String userId) => consent.putIfAbsent(userId, () {
    // Seeded accounts already consented to behavior; "new" has nothing.
    if (userId == 'u_new' || userId.startsWith('u_reg')) {
      return const ConsentState(entries: {}, policyVersion: policyVersion);
    }
    final now = DateTime.now();
    return ConsentState(
      policyVersion: policyVersion,
      entries: {
        ConsentScope.behavior: ConsentEntry(scope: ConsentScope.behavior, granted: true, version: policyVersion, at: now),
        ConsentScope.teamAggregate: ConsentEntry(scope: ConsentScope.teamAggregate, granted: true, version: policyVersion, at: now),
      },
    );
  });

  UserSettings settingsFor(String userId) => settings.putIfAbsent(userId, () => const UserSettings());

  List<SessionSummary> historyFor(String userId) => history.putIfAbsent(userId, () {
    if (scenario == MockScenario.newUser || userId == 'u_new' || userId.startsWith('u_reg')) return [];
    final now = DateTime.now();
    return List.generate(6, (i) {
      final start = now.subtract(Duration(days: i + 1, hours: 2));
      return SessionSummary(
        sessionId: 'hist_$i',
        startedAt: start,
        endedAt: start.add(Duration(minutes: 45 + i * 5)),
        focusMinutes: 45 + i * 5,
        plannedMinutes: 50,
        demand: Demand.values[i % 3],
        taskText: ['Auth refactor', 'Write spec', 'Review PRs'][i % 3],
        breaksSuggested: 1 + i % 2,
        breaksTaken: i % 2,
        replayReady: true,
      );
    });
  });

  /// Wraps every mock call: latency, scenario failures, auth, request log.
  Future<T> call<T>(String method, String path, FutureOr<T> Function() body, {bool auth = true}) async {
    final started = DateTime.now();
    if (config.latency > Duration.zero) await Future<void>.delayed(config.latency);
    try {
      if (scenario == MockScenario.backendDown) {
        throw const ApiError(ApiError.network, "Can't reach Flow. Check your connection.");
      }
      if (auth) {
        if (scenario == MockScenario.tokenExpiry) {
          scenario = MockScenario.normal; // one-shot
          currentUserId = null;
          onSessionExpired?.call();
          throw const ApiError(ApiError.sessionExpired, 'Your session expired. Please sign in again.', status: 401);
        }
        requireUser();
      }
      final result = await body();
      _log(method, path, started, 200);
      return result;
    } on ApiError catch (e) {
      _log(method, path, started, e.status, error: e.message);
      rethrow;
    }
  }

  void _log(String method, String path, DateTime started, int? status, {String? error}) {
    logger?.call(
      RequestLogEntry(
        method: method,
        path: path,
        at: started,
        status: status,
        duration: DateTime.now().difference(started),
        error: error,
        mocked: true,
      ),
    );
  }

  // ── session simulation ────────────────────────────────────────────────

  void startRun(ActiveSession s) {
    run?.dispose();
    final r = MockRun(s);
    r.status = _statusFor(r);
    r.timer = Timer.periodic(config.tick, (_) => _tick(r));
    run = r;
  }

  bool _forceNudge = false;

  /// Dev panel: make the running session's next tick a nudge, whatever the
  /// scenario or timing. Returns why it can't, or null when it will.
  String? forceNudge() {
    final r = run;
    if (r == null) return 'Start a session first.';
    if (r.session.pendingInterventionId != null) return 'A nudge is already waiting.';
    if (breakActive) return 'A break is running.';
    if (r.session.paused) return 'The session is paused.';
    _forceNudge = true;
    _tick(r);
    return null;
  }

  void _tick(MockRun r) {
    if (r.session.paused) return;
    r.elapsedTicks++;
    r.ticksSinceReset++;
    r.status = _statusFor(r);
    r.events.add(SessionStateEvent(r.status));

    final forced = _forceNudge;
    _forceNudge = false;
    final interventionDue =
        forced ||
        scenario != MockScenario.quiet &&
        !breakActive &&
        r.session.pendingInterventionId == null &&
        r.ticksSinceReset >= config.ticksToIntervention &&
        !(pause[currentUserId]?.paused ?? false);
    if (interventionDue) {
      final mode = settingsFor(currentUserId ?? '').deliveryMode;
      final i = Intervention(
        id: nextId('int'),
        type: 'break',
        message: 'Good moment for a short break.',
        deliveryMode: mode,
        suggestedBreakSec: settingsFor(currentUserId ?? '').breakLengthSec,
        shortReason: 'Window switching has climbed and you are near your usual break point.',
      );
      interventions[i.id] = i;
      r.breaksSuggested++;
      r.session = r.session.copyWith(pendingInterventionId: i.id, state: FlowState.breakDue);
      r.status = _statusFor(r);
      r.events.add(InterventionEvent(interventionId: i.id, deliveryMode: mode));
    }
  }

  SessionStatus _statusFor(MockRun r) {
    final p = (r.ticksSinceReset / config.ticksToIntervention).clamp(0.0, 1.0);
    final combined = 0.25 + 0.4 * p;
    const threshold = 0.62;
    final cameraOn = settingsFor(currentUserId ?? '').cameraEnabled;
    final state = r.session.paused
        ? FlowState.paused
        : r.session.pendingInterventionId != null
        ? FlowState.breakDue
        : combined / threshold > 0.8
        ? FlowState.approachingBreak
        : FlowState.steady;
    return SessionStatus(
      sessionId: r.session.sessionId,
      elapsedMin: r.session.elapsedAt(DateTime.now()).inMinutes,
      combinedScore: combined,
      threshold: threshold,
      state: state,
      interventionId: r.session.pendingInterventionId,
      signals: [
        SignalReading(name: 'ultradian', value: (combined + 0.05).clamp(0, 1), weight: cameraOn ? 0.35 : 0.45),
        SignalReading(name: 'behavioral', value: (combined - 0.03).clamp(0, 1), weight: cameraOn ? 0.40 : 0.55),
        SignalReading(name: 'eye', value: cameraOn ? combined : null, weight: cameraOn ? 0.25 : 0.0),
      ],
    );
  }

  /// After a response, pressure resets so the next nudge isn't immediate.
  void resetPressure({required int ticksHeadStart}) {
    final r = run;
    if (r == null) return;
    r.ticksSinceReset = -ticksHeadStart;
    r.session = r.session.copyWith(clearIntervention: true, state: FlowState.steady);
    r.status = _statusFor(r);
    r.events.add(SessionStateEvent(r.status));
  }

  void dispose() => run?.dispose();
}
