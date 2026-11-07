// DEV ONLY. Mock implementations of every API contract, backed by MockBackend.
import 'dart:async';
import 'dart:typed_data';

import '../api_error.dart';
import '../contracts/account_api.dart';
import '../contracts/agent_api.dart';
import '../contracts/auth_api.dart';
import '../contracts/insights_api.dart';
import '../contracts/meta_api.dart';
import '../contracts/session_api.dart';
import '../contracts/schedule_api.dart';
import '../contracts/team_api.dart';
import '../models/agent.dart';
import '../models/auth.dart';
import '../models/consent.dart';
import '../models/day.dart';
import '../models/insights.dart';
import '../models/intervention.dart';
import '../models/meta.dart';
import '../models/privacy.dart';
import '../models/session.dart';
import '../models/settings.dart';
import '../models/schedule.dart';
import '../models/team.dart';
import 'mock_backend.dart';
import 'mock_focus_dna.dart';
import 'mock_day.dart';

ApiError _forbidden() => const ApiError('forbidden', 'You do not have access to this.', status: 403);
ApiError _notFound(String what) => ApiError(ApiError.notFound, '$what not found', status: 404);

// ── auth ───────────────────────────────────────────────────────────────────

class MockAuthApi implements AuthApi {
  MockAuthApi(this.b);
  final MockBackend b;

  TokenPair _tokensFor(MockUser u) {
    b.currentUserId = u.id;
    return TokenPair(accessToken: 'mock-access-${u.id}', refreshToken: 'mock-refresh-${u.id}');
  }

  @override
  Future<RegisterResult> register(RegisterRequest req) => b.call('POST', '/auth/register', () {
    if (b.users.containsKey(req.email.toLowerCase())) {
      throw const ApiError('email_taken', 'An account with this email already exists.', status: 409);
    }
    if (req.accountType == AccountType.employee && (req.inviteToken ?? '').isEmpty) {
      throw const ApiError('invite_required', 'Employees need an invite link from their admin.', status: 400);
    }
    final u = MockUser(
      id: b.nextId('u_reg'),
      name: req.name,
      email: req.email.toLowerCase(),
      password: req.password,
      role: req.accountType == AccountType.employee ? UserRole.employee : UserRole.solo,
      teamId: req.accountType == AccountType.employee ? MockBackend.teamId : null,
      emailVerified: false,
    );
    b.users[u.email] = u;
    return RegisterResult(userId: u.id, role: u.role, teamId: u.teamId, needsEmailVerification: true);
  }, auth: false);

  @override
  Future<void> verifyEmail(String token) => b.call('POST', '/auth/verify-email', () {
    // Mock: any token verifies the most recently registered user.
    for (final u in b.users.values) {
      u.emailVerified = true;
    }
  }, auth: false);

  @override
  Future<LoginResult> login({required String email, required String password}) => b.call('POST', '/auth/login', () {
    final u = b.users[email.trim().toLowerCase()];
    if (u == null || u.password != password) {
      throw const ApiError(ApiError.invalidCredentials, 'Email or password is incorrect.', status: 401);
    }
    if (u.mfa) {
      final token = b.nextId('mfa');
      b.pendingMfa[token] = u.email;
      return LoginResult(mfaRequired: true, mfaToken: token, role: u.role, teamId: u.teamId);
    }
    return LoginResult(tokens: _tokensFor(u), role: u.role, teamId: u.teamId, consentMissing: b.consentFor(u.id).missingRequired);
  }, auth: false);

  @override
  Future<TokenPair> verifyMfa({required String mfaToken, required String code}) => b.call('POST', '/auth/mfa/verify', () {
    final email = b.pendingMfa[mfaToken];
    if (email == null) throw const ApiError(ApiError.sessionExpired, 'Sign-in expired. Start again.', status: 401);
    if (code != MockBackend.mfaCode) throw const ApiError(ApiError.mfaInvalid, 'That code is not valid.', status: 401);
    b.pendingMfa.remove(mfaToken);
    return _tokensFor(b.users[email]!);
  }, auth: false);

  @override
  Future<TokenPair> refresh(String refreshToken) => b.call('POST', '/auth/refresh', () {
    final id = refreshToken.replaceFirst('mock-refresh-', '');
    final u = b.users.values.where((u) => u.id == id).firstOrNull;
    if (u == null) throw const ApiError(ApiError.sessionExpired, 'Session expired.', status: 401);
    return _tokensFor(u);
  }, auth: false);

  @override
  Future<void> logout(String refreshToken) => b.call('POST', '/auth/logout', () {
    b.run?.dispose();
    b.run = null;
    b.currentUserId = null;
  }, auth: false);

  @override
  Future<void> forgotPassword(String email) => b.call('POST', '/auth/forgot-password', () {}, auth: false);

  @override
  Future<void> resetPassword({required String token, required String newPassword}) => b.call('POST', '/auth/reset-password', () {
    if (token.isEmpty) throw const ApiError('invalid_token', 'This reset link is invalid or expired.', status: 400);
  }, auth: false);

  @override
  Future<AuthUser> me() => b.call('GET', '/auth/me', () => b.requireUser().toAuthUser());
}

// ── consent / settings / pause / privacy ───────────────────────────────────

class MockConsentApi implements ConsentApi {
  MockConsentApi(this.b);
  final MockBackend b;

  @override
  Future<ConsentState> get() => b.call('GET', '/consent', () => b.consentFor(b.requireUser().id));

  @override
  Future<ConsentEntry> set(ConsentScope scope, {required bool granted, required String policyVersion}) =>
      b.call('PUT', '/consent/${scope.wire}', () {
        final id = b.requireUser().id;
        final e = ConsentEntry(scope: scope, granted: granted, version: policyVersion, at: DateTime.now());
        b.consent[id] = b.consentFor(id).copyWithEntry(e);
        return e;
      });
}

class MockSettingsApi implements SettingsApi {
  MockSettingsApi(this.b);
  final MockBackend b;

  @override
  Future<UserSettings> get() => b.call('GET', '/settings', () => b.settingsFor(b.requireUser().id));

  @override
  Future<UserSettings> update(SettingsPatch patch) => b.call('PUT', '/settings', () {
    final id = b.requireUser().id;
    return b.settings[id] = patch.applyTo(b.settingsFor(id));
  });
}

class MockPauseApi implements PauseApi {
  MockPauseApi(this.b);
  final MockBackend b;

  @override
  Future<PauseState> get() => b.call('GET', '/pause', () => b.pause[b.requireUser().id] ?? PauseState.running);

  @override
  Future<PauseState> pause({int? minutes, bool untilEndOfDay = false}) => b.call('POST', '/pause', () {
    final now = DateTime.now();
    final until = untilEndOfDay ? DateTime(now.year, now.month, now.day, 23, 59) : now.add(Duration(minutes: minutes ?? 30));
    return b.pause[b.requireUser().id] = PauseState(paused: true, until: until);
  });

  @override
  Future<PauseState> resume() => b.call('DELETE', '/pause', () => b.pause[b.requireUser().id] = PauseState.running);
}

class MockPrivacyApi implements PrivacyApi {
  MockPrivacyApi(this.b);
  final MockBackend b;
  final _jobs = <String, int>{};

  @override
  Future<DataSummary> dataSummary() => b.call('GET', '/me/data-summary', () {
    final id = b.requireUser().id;
    return DataSummary(
      categories: [
        const DataCategory(name: 'Account', description: 'Name, email, role', itemCount: 1),
        DataCategory(
          name: 'Sessions',
          description: 'Start/end times, demand, planned length',
          itemCount: b.historyFor(id).length,
          retentionDays: 365,
        ),
        const DataCategory(
          name: 'Signal ticks',
          description: 'Counts and app category every 30 s. No window titles.',
          itemCount: 540,
          retentionDays: 90,
        ),
        DataCategory(name: 'Consent log', description: 'Every grant and withdrawal', itemCount: b.consentFor(id).entries.length),
      ],
    );
  });

  @override
  Future<ExportJob> requestExport() => b.call('POST', '/me/data-export', () {
    final id = b.nextId('exp');
    _jobs[id] = 0;
    return ExportJob(id: id, status: ExportStatus.pending);
  });

  @override
  Future<ExportJob> exportStatus(String id) => b.call('GET', '/me/data-export/$id', () {
    final polls = _jobs[id];
    if (polls == null) throw _notFound('Export');
    _jobs[id] = polls + 1;
    return polls >= 1
        ? ExportJob(id: id, status: ExportStatus.ready, downloadUrl: 'https://example.invalid/export/$id.zip')
        : ExportJob(id: id, status: ExportStatus.pending);
  });

  @override
  Future<void> deleteAccount() => b.call('DELETE', '/me', () {
    final u = b.requireUser();
    b.users.remove(u.email);
    b.currentUserId = null;
  });
}

// ── session / interventions / breaks ───────────────────────────────────────

class MockSessionApi implements SessionApi {
  MockSessionApi(this.b);
  final MockBackend b;

  MockRun _run(String id) {
    final r = b.run;
    if (r == null || r.session.sessionId != id) throw _notFound('Session');
    return r;
  }

  @override
  Future<PreCheck> preCheck() => b.call('GET', '/session/pre-check', () {
    final cal = b.settingsFor(b.requireUser().id).calendarEnabled;
    return PreCheck(
      suggestedMinutes: b.scenario == MockScenario.newUser ? 50 : 70,
      nextMeetingInMin: cal ? 95 : null,
      warnings: cal ? const ['Meeting in 95 min. A 70 min session leaves time for a break first.'] : const [],
    );
  });

  @override
  Future<ActiveSession> start(StartSessionRequest req) => b.call('POST', '/session/start', () {
    b.requireUser();
    if (b.run != null) throw const ApiError('session_active', 'A session is already running.', status: 409);
    final s = ActiveSession(
      sessionId: b.nextId('ses'),
      startedAt: DateTime.now(),
      plannedMinutes: req.plannedMinutes,
      demand: req.demand,
      taskText: req.taskText,
    );
    b.startRun(s);
    return s;
  });

  @override
  Future<ActiveSession?> active() => b.call('GET', '/session/active', () => b.run?.session);

  @override
  Stream<SessionEvent> stream(String sessionId) async* {
    if (b.scenario == MockScenario.backendDown) {
      throw const ApiError(ApiError.network, 'Live connection failed.');
    }
    final r = _run(sessionId);
    yield SessionStateEvent(r.status);
    var n = 0;
    await for (final e in r.events.stream) {
      yield e;
      if (b.scenario == MockScenario.streamDrops && ++n >= 3) {
        throw const ApiError(ApiError.network, 'Live connection dropped (mock).');
      }
    }
  }

  @override
  Future<SessionStatus> status(String sessionId) => b.call('GET', '/session/status', () => _run(sessionId).status);

  @override
  Future<void> pause(String sessionId, {String? reason}) => b.call('POST', '/session/$sessionId/pause', () {
    final r = _run(sessionId);
    if (r.session.paused) return;
    r.pausedAt = DateTime.now();
    r.session = r.session.copyWith(paused: true, state: FlowState.paused);
  });

  @override
  Future<void> resume(String sessionId) => b.call('POST', '/session/$sessionId/resume', () {
    final r = _run(sessionId);
    if (!r.session.paused) return;
    final extra = DateTime.now().difference(r.pausedAt ?? DateTime.now()).inSeconds;
    r.session = r.session.copyWith(paused: false, state: FlowState.steady, pausedSeconds: r.session.pausedSeconds + extra);
  });

  @override
  Future<SessionSummary> end(String sessionId) => b.call('POST', '/session/$sessionId/end', () {
    final r = _run(sessionId);
    final now = DateTime.now();
    final summary = SessionSummary(
      sessionId: sessionId,
      startedAt: r.session.startedAt,
      endedAt: now,
      focusMinutes: r.session.elapsedAt(now).inMinutes,
      plannedMinutes: r.session.plannedMinutes,
      demand: r.session.demand,
      taskText: r.session.taskText,
      breaksSuggested: r.breaksSuggested,
      breaksTaken: r.breaksTaken,
      replayReady: true,
    );
    b.historyFor(b.requireUser().id).insert(0, summary);
    r.events.add(SessionEndedEvent(sessionId));
    r.dispose();
    b.run = null;
    return summary;
  });

  @override
  Future<ActiveSession> extend(String sessionId, int minutes) => b.call('POST', '/session/$sessionId/extend', () {
    final r = _run(sessionId);
    r.session = ActiveSession(
      sessionId: r.session.sessionId,
      startedAt: r.session.startedAt,
      plannedMinutes: r.session.plannedMinutes + minutes,
      demand: r.session.demand,
      taskText: r.session.taskText,
      state: r.session.state,
      pendingInterventionId: r.session.pendingInterventionId,
      paused: r.session.paused,
      pausedSeconds: r.session.pausedSeconds,
    );
    return r.session;
  });

  @override
  Future<SessionReplay> replay(String sessionId) => b.call('GET', '/session/$sessionId/replay', () {
    return const SessionReplay(
      events: [
        ReplayEvent(minute: 0, kind: 'start', text: 'Session started (moderate demand, 50 min planned).'),
        ReplayEvent(minute: 34, kind: 'approaching', text: 'Window switching rose above your usual level.'),
        ReplayEvent(minute: 41, kind: 'intervention', text: 'Flow suggested a 5 min break. You took it.'),
        ReplayEvent(minute: 47, kind: 'resume', text: 'Back to editing 40 s after the break.'),
      ],
      whatFlowLearned: ['Your break point today landed near minute 41 (usual: 45).', 'Post-break focus rating: 4/5.'],
    );
  });

  @override
  Future<SessionPage> list({int page = 1, DateTime? from, DateTime? to}) => b.call('GET', '/sessions', () {
    final all = b.historyFor(b.requireUser().id);
    const size = 20;
    final items = all.skip((page - 1) * size).take(size).toList();
    return SessionPage(items: items, page: page, hasMore: all.length > page * size);
  });

  @override
  Future<StuckHelp> stuck(String sessionId) => b.call('POST', '/session/$sessionId/stuck', () {
    final id = b.requireUser().id;
    if (!b.consentFor(id).granted(ConsentScope.llm)) {
      throw const ApiError(ApiError.llmConsentRequired, 'Allow the AI assistant in Privacy to use this.', status: 403);
    }
    final task = _run(sessionId).session.taskText;
    return StuckHelp(
      breakdown: [
        'Write down the exact input that fails${task == null ? '' : ' in "$task"'}.',
        'Reproduce it in the smallest possible test.',
        'Change one thing at a time and re-run.',
      ],
      questions: const ['What did you expect to happen?', 'What changed since it last worked?'],
      nextStep: 'Spend 5 minutes writing the failing test case only.',
    );
  });

  @override
  Future<void> reportResumption(String sessionId, {required String breakId, required int secondsToFirstEdit}) =>
      b.call('POST', '/session/$sessionId/resumption', () {});
}

class MockInterventionApi implements InterventionApi {
  MockInterventionApi(this.b);
  final MockBackend b;

  Intervention _get(String id) => b.interventions[id] ?? (throw _notFound('Intervention'));

  @override
  Future<Intervention> get(String id) => b.call('GET', '/intervention/$id', () => _get(id));

  @override
  Future<Explanation> explain(String id, {ExplainDetail detail = ExplainDetail.short}) => b.call('GET', '/intervention/$id/explain', () {
    _get(id);
    final status = b.run?.status;
    final signals = (status?.signals ?? const <SignalReading>[]).where((s) => s.available).toList();
    final totalW = signals.fold<double>(0, (a, s) => a + s.weight);
    final contributions = [
      for (final s in signals)
        Contribution(name: s.name, value: s.value!, weight: s.weight, contribution: totalW == 0 ? 0 : s.value! * s.weight / totalW),
    ]..sort((a, c) => c.contribution.compareTo(a.contribution));
    final primary = contributions.isEmpty ? 'behavioral' : contributions.first.name;
    return Explanation(
      interventionId: id,
      detail: detail,
      headline: primary == 'behavioral'
          ? 'You have switched windows 14 times in 5 minutes.'
          : 'You are about 40 minutes into your usual focus cycle.',
      primaryDriver: primary,
      contributions: detail == ExplainDetail.full ? contributions : contributions.take(1).toList(),
      combinedScore: status?.combinedScore ?? 0,
      threshold: status?.threshold ?? 0.62,
    );
  });

  @override
  Future<void> respond(String id, InterventionResponse response, {int? snoozeMinutes}) => b.call('POST', '/intervention/$id/respond', () {
    _get(id);
    switch (response) {
      case InterventionResponse.accepted:
        b.run?.breaksTaken++;
        b.resetPressure(ticksHeadStart: 0);
      case InterventionResponse.snoozed:
        // Mock: 1 tick per snoozed minute.
        b.resetPressure(ticksHeadStart: snoozeMinutes ?? 10);
      case InterventionResponse.dismissed:
        b.resetPressure(ticksHeadStart: 5);
    }
  });

  @override
  Future<void> overrideLock(String id, OverrideReason reason) =>
      b.call('POST', '/intervention/$id/override', () => b.resetPressure(ticksHeadStart: 15));

  @override
  Future<void> report(String id, ReportReason reason, {String? freeText}) => b.call('POST', '/intervention/$id/report', () => _get(id));
}

class MockBreakApi implements BreakApi {
  MockBreakApi(this.b);
  final MockBackend b;

  @override
  Future<String> start({required String sessionId, String? interventionId}) => b.call('POST', '/breaks/start', () {
    final id = b.nextId('brk');
    b.breakActive = true;
    b.breaks[id] = BreakRecord(id: id, startedAt: DateTime.now(), interventionId: interventionId);
    return id;
  });

  @override
  Future<double?> end(String breakId, {required int actualMinutes}) => b.call('POST', '/breaks/$breakId/end', () {
    final br = b.breaks[breakId] ?? (throw _notFound('Break'));
    b.breakActive = false;
    b.breaks[breakId] = BreakRecord(
      id: br.id,
      startedAt: br.startedAt,
      endedAt: DateTime.now(),
      interventionId: br.interventionId,
      actualMinutes: actualMinutes,
      restorationScore: actualMinutes >= 5 ? 0.8 : 0.5,
    );
    return b.breaks[breakId]!.restorationScore;
  });

  @override
  Future<BreakSummary> list(String sessionId) => b.call('GET', '/breaks', () {
    final list = b.breaks.values.toList();
    return BreakSummary(suggested: b.run?.breaksSuggested ?? list.length, taken: list.length, breaks: list);
  });

  @override
  Future<void> rate({required String sessionId, required RatingKind kind, required int value, String? contextId}) =>
      b.call('POST', '/ratings', () {
        if (value < 1 || value > 5) throw const ApiError('invalid_rating', 'Rating must be 1–5.', status: 422);
      });
}

// ── insights / calendar ────────────────────────────────────────────────────

class MockInsightsApi implements InsightsApi {
  MockInsightsApi(this.b);
  final MockBackend b;

  bool get _learning => b.historyFor(b.requireUser().id).length < 5;

  @override
  Future<Dashboard> dashboard() => b.call('GET', '/user/dashboard', () {
    final hist = b.historyFor(b.requireUser().id);
    final today = hist.where((s) => _isToday(s.startedAt)).toList();
    return Dashboard(
      today: TodayStats(
        sessions: today.length,
        focusMinutes: today.fold(0, (a, s) => a + s.focusMinutes),
        breaksTaken: today.fold(0, (a, s) => a + s.breaksTaken),
      ),
      currentState: b.run?.status.state,
      quickStart: hist.isEmpty ? null : QuickStart(demand: hist.first.demand, minutes: 50, taskText: hist.first.taskText),
      forecast: _forecast(),
    );
  });

  Forecast _forecast() {
    final needed = (5 - b.historyFor(b.requireUser().id).length).clamp(0, 5);
    if (needed > 0) {
      return Forecast(available: false, windows: const [], confidence: Confidence.low, basis: '', sessionsNeeded: needed);
    }
    final now = DateTime.now();
    return Forecast(
      available: true,
      confidence: Confidence.medium,
      basis: 'Last 6 sessions',
      windows: [
        ForecastWindow(start: now, end: now.add(const Duration(minutes: 70)), kind: 'focus'),
        ForecastWindow(start: now.add(const Duration(minutes: 70)), end: now.add(const Duration(minutes: 80)), kind: 'break'),
        ForecastWindow(
          start: now.add(const Duration(minutes: 95)),
          end: now.add(const Duration(minutes: 125)),
          kind: 'meeting',
          note: 'Calendar',
        ),
      ],
    );
  }

  @override
  Future<Patterns> patterns() => b.call('GET', '/user/patterns', () {
    final n = b.historyFor(b.requireUser().id).length;
    if (_learning) return Patterns(sessionsCompleted: n, sessionsNeeded: 5 - n);
    return Patterns(
      sessionsCompleted: n,
      sessionsNeeded: 0,
      peakHours: Learned(value: const [10, 15], sampleSize: n, confidence: Confidence.medium),
      personalPeriodMin: Learned(value: 72, sampleSize: n, confidence: Confidence.low),
      breakEffectiveness: Learned(value: 0.64, sampleSize: n - 2, confidence: Confidence.low),
    );
  });

  @override
  Future<Forecast> forecast() => b.call('GET', '/forecast', _forecast);

  bool get _newUser =>
      b.scenario == MockScenario.newUser || (b.currentUser?.id.startsWith('u_reg') ?? false) || b.currentUser?.id == 'u_new';

  @override
  Future<DayTimeline> day(DateTime date) => b.call('GET', '/user/day', () => mockDay(b, date, newUser: _newUser));

  @override
  Future<Map<DateTime, int>> month(DateTime month) => b.call('GET', '/user/month', () => mockMonth(month, newUser: _newUser));

  @override
  Future<Uint8List> focusDnaPng() => b.call('POST', '/export/focus-dna', () => mockFocusDnaPng);
}

bool _isToday(DateTime d) {
  final n = DateTime.now();
  return d.year == n.year && d.month == n.month && d.day == n.day;
}

class MockCalendarApi implements CalendarApi {
  MockCalendarApi(this.b);
  final MockBackend b;
  bool _connected = false;

  @override
  Future<Uri> connect() => b.call('POST', '/calendar/connect', () {
    _connected = true;
    return Uri.parse('https://accounts.google.com/o/oauth2/v2/auth?mock=1');
  });

  @override
  Future<CalendarContext> context() => b.call('GET', '/calendar/context', () {
    if (!_connected) return const CalendarContext(connected: false, events: []);
    final now = DateTime.now();
    return CalendarContext(
      connected: true,
      events: [CalendarEvent(title: 'Team sync', start: now.add(const Duration(minutes: 95)), end: now.add(const Duration(minutes: 125)))],
    );
  });

  @override
  Future<void> disconnect() => b.call('DELETE', '/calendar', () => _connected = false);
}

// ── team / admin ───────────────────────────────────────────────────────────

class MockTeamApi implements TeamApi {
  MockTeamApi(this.b);
  final MockBackend b;

  @override
  Future<Suppressible<TeamMetrics>> summary() => b.call('GET', '/team/summary', () {
    final u = b.requireUser();
    if (u.teamId == null) throw _forbidden();
    if (b.scenario == MockScenario.smallTeam) {
      return const Suppressible<TeamMetrics>(groupSize: 3, suppressed: true, reason: 'min_group_size_5');
    }
    return Suppressible(groupSize: 8, suppressed: false, data: TeamMetrics(averageFocus: 0.68, trend: _trend(7)));
  });
}

List<TrendPoint> _trend(int days) {
  final now = DateTime.now();
  return List.generate(
    days,
    (i) => TrendPoint(
      date: now.subtract(Duration(days: days - 1 - i)),
      value: 0.55 + (i % 4) * 0.05,
    ),
  );
}

class MockAdminApi implements AdminApi {
  MockAdminApi(this.b);
  final MockBackend b;

  Future<T> _admin<T>(String method, String path, T Function() body) => b.call(method, path, () {
    if (b.requireUser().role != UserRole.admin) throw _forbidden();
    return body();
  });

  Future<Suppressible<T>> _sup<T>(String path, T Function() data) => _admin('GET', path, () {
    if (b.scenario == MockScenario.smallTeam) {
      return Suppressible<T>(groupSize: 3, suppressed: true, reason: 'min_group_size_5');
    }
    return Suppressible<T>(groupSize: 8, suppressed: false, data: data());
  });

  @override
  Future<Suppressible<AdminSummary>> summary() =>
      _sup('/admin/summary', () => AdminSummary(activeCount: 5, avgFocusTrend: _trend(7), sessionVolume: 31));

  @override
  Future<Suppressible<AdminTrend>> trend() => _sup('/admin/trend', () => AdminTrend(days7: _trend(7), days30: _trend(30)));

  @override
  Future<Suppressible<AdminInsights>> insights() =>
      _sup('/admin/insights', () => const AdminInsights(peakHours: [10, 14], typicalRecoveryMin: 6));

  @override
  Future<Suppressible<TeamStrain>> strain() =>
      _sup('/admin/strain', () => const TeamStrain(level: 'moderate', note: 'Break suggestions up 20% vs last week.'));

  @override
  Future<Suppressible<MeetingWindow>> meetingWindow() =>
      _sup('/admin/meeting-window', () => const MeetingWindow(start: '13:30', end: '14:30'));

  @override
  Future<AdminPrivacyStatus> privacyStatus() => _admin('GET', '/admin/privacy-status', () {
    final small = b.scenario == MockScenario.smallTeam;
    return AdminPrivacyStatus(
      groupSize: small ? 3 : 8,
      suppressed: small,
      canSee: const ['Team averages and trends', 'Number of active sessions', 'Team-level strain indicator'],
      cannotSee: const ['Any individual\'s sessions, scores or tasks', 'Who is active right now', 'Window titles, apps or camera data'],
    );
  });

  @override
  Future<Invite> createInvite({Duration validFor = const Duration(days: 7)}) => _admin('POST', '/admin/invites', () {
    final id = b.nextId('inv');
    final now = DateTime.now();
    final inv = Invite(id: id, createdAt: now, expiresAt: now.add(validFor), used: false, url: 'flow://invite/$id-secret');
    b.invites.insert(0, Invite(id: id, createdAt: now, expiresAt: inv.expiresAt, used: false));
    b.audit.insert(0, AuditEntry(action: 'invite.create', at: now, actor: b.requireUser().name));
    return inv;
  });

  @override
  Future<List<Invite>> invites() => _admin('GET', '/admin/invites', () => List.of(b.invites));

  @override
  Future<void> revokeInvite(String id) => _admin('DELETE', '/admin/invites/$id', () {
    b.invites.removeWhere((i) => i.id == id);
    b.audit.insert(0, AuditEntry(action: 'invite.revoke', at: DateTime.now(), actor: b.requireUser().name));
  });

  @override
  Future<List<AuditEntry>> auditLog() => _admin('GET', '/admin/audit-log', () => List.of(b.audit));
}

// ── meta ───────────────────────────────────────────────────────────────────

class MockMetaApi implements MetaApi {
  MockMetaApi(this.b);
  final MockBackend b;

  @override
  Future<FeatureFlags> flags() => b.call('GET', '/flags', () => const FeatureFlags({'lock_mode': true, 'prompt_style': 'explained'}));

  @override
  Future<void> sendFeedback(FeedbackRequest req) => b.call('POST', '/feedback', () {
    if (req.message.trim().isEmpty) throw const ApiError('invalid', 'Message is empty.', status: 422);
  });

  @override
  Future<List<ChangelogEntry>> changelog() => b.call(
    'GET',
    '/changelog',
    () => const [
      ChangelogEntry(version: '2.0.0', date: null, items: ['New app shell', 'Snooze and pause', 'Why-this-nudge explainer']),
    ],
    auth: false,
  );
}

// ── local agent ────────────────────────────────────────────────────────────

class MockLocalAgentApi implements LocalAgentApi {
  MockLocalAgentApi(this.b);
  final MockBackend b;
  final _events = StreamController<AgentEvent>.broadcast();
  bool _paired = true;
  bool _camera = false;
  Timer? _signals;

  AgentStatus get _status => AgentStatus(
    connection: _paired ? AgentConnection.connected : AgentConnection.unpaired,
    behaviorOn: _paired,
    cameraOn: _camera,
    category: AppCategory.editor,
    agentVersion: 'mock-1.0',
  );

  @override
  Stream<AgentEvent> events() {
    _signals ??= Timer.periodic(b.config.tick, (_) {
      if (_events.isClosed || !_events.hasListener) return;
      _events.add(
        AgentSignalsEvent(
          LiveSignals(
            keysPerMin: 40 + DateTime.now().second % 30,
            switchesPer5Min: 3 + DateTime.now().second % 6,
            idleSec: DateTime.now().second % 10,
            eyeScore: _camera ? 0.4 : null,
          ),
        ),
      );
    });
    return _events.stream;
  }

  @override
  // The agent is local: it stays up even in the backendDown scenario.
  Future<AgentStatus> status() async => _status;

  @override
  Future<void> pair(String code) async {
    if (code.length != 6) throw StateError('Pairing code must be 6 digits.');
    _paired = true;
    if (!_events.isClosed) _events.add(AgentStatusEvent(_status));
  }

  @override
  Future<void> setCamera(bool on) async {
    _camera = on;
    if (!_events.isClosed) _events.add(AgentStatusEvent(_status));
  }

  final _pending = <Timer>{};

  @override
  Future<void> watchResumption(String breakId) async {
    late final Timer t;
    t = Timer(b.config.tick * 2, () {
      _pending.remove(t);
      if (!_events.isClosed) _events.add(AgentResumptionEvent(breakId: breakId, secondsToFirstEdit: 38));
    });
    _pending.add(t);
  }

  void dispose() {
    _signals?.cancel();
    for (final t in _pending) {
      t.cancel();
    }
    unawaited(_events.close());
  }
}

// ── schedules ───────────────────────────────────────────────────────────────

class MockScheduleApi implements ScheduleApi {
  MockScheduleApi(this.b);
  final MockBackend b;

  List<Schedule> _mine() => b.schedulesFor(b.requireUser());

  @override
  Future<List<Schedule>> list() => b.call('GET', '/user/schedules', () => List.of(_mine()));

  @override
  Future<Schedule> create(Schedule s) => b.call('POST', '/user/schedules', () {
    final saved = s.copyWith(id: 'sch_${DateTime.now().microsecondsSinceEpoch}');
    _mine().add(saved);
    return saved;
  });

  @override
  Future<Schedule> update(Schedule s) => b.call('PUT', '/user/schedules/${s.id}', () {
    final list = _mine();
    final i = list.indexWhere((x) => x.id == s.id);
    if (i < 0) throw const ApiError('not_found', 'That schedule no longer exists.', status: 404);
    list[i] = s;
    return s;
  });

  @override
  Future<void> delete(String id) => b.call('DELETE', '/user/schedules/$id', () => _mine().removeWhere((x) => x.id == id));
}
