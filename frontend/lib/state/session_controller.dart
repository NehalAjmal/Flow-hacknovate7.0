import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_connector.dart';
import '../api/api_error.dart';
import '../api/models/session.dart';
import 'auth_controller.dart';

/// How the UI is receiving live updates. Drives the small offline chip.
enum LiveConnection { live, polling, offline }

class SessionTiming {
  const SessionTiming({this.pollEvery = const Duration(seconds: 8), this.retryStreamAfterPolls = 4});

  /// Polling fallback interval (doc §5.3: polling every 8 s).
  final Duration pollEvery;

  /// While polling, try the stream again after this many polls.
  final int retryStreamAfterPolls;
}

final sessionTimingProvider = Provider<SessionTiming>((ref) => const SessionTiming());

class LiveSession {
  const LiveSession({required this.session, this.status, this.connection = LiveConnection.live});

  final ActiveSession session;
  final SessionStatus? status;
  final LiveConnection connection;

  String? get pendingInterventionId => session.pendingInterventionId;

  LiveSession copyWith({ActiveSession? session, SessionStatus? status, LiveConnection? connection}) =>
      LiveSession(session: session ?? this.session, status: status ?? this.status, connection: connection ?? this.connection);
}

/// The running session (or null). Owns the stream subscription and the
/// polling fallback; screens only read state and call methods.
class LiveSessionController extends AsyncNotifier<LiveSession?> {
  StreamSubscription<SessionEvent>? _sub;
  Timer? _poll;
  int _pollsSinceStreamTry = 0;

  @override
  Future<LiveSession?> build() async {
    ref.onDispose(_disconnect);
    if (ref.watch(currentUserIdProvider) == null) return null;
    final active = await ref.watch(sessionApiProvider).active();
    if (active == null) return null;
    _connect(active.sessionId);
    return LiveSession(session: active);
  }

  LiveSession? get _current => state.value;

  void _set(LiveSession? s) {
    if (ref.mounted) state = AsyncData(s);
  }

  Future<void> start(StartSessionRequest req) async {
    final s = await ref.read(sessionApiProvider).start(req);
    _set(LiveSession(session: s));
    _connect(s.sessionId);
  }

  Future<void> pause({String? reason}) async {
    final cur = _current;
    if (cur == null || cur.session.paused) return;
    await ref.read(sessionApiProvider).pause(cur.session.sessionId, reason: reason);
    _set(cur.copyWith(session: cur.session.copyWith(paused: true, state: FlowState.paused)));
  }

  Future<void> resume() async {
    final cur = _current;
    if (cur == null || !cur.session.paused) return;
    final api = ref.read(sessionApiProvider);
    await api.resume(cur.session.sessionId);
    // Re-read so paused_seconds (server-side) is authoritative.
    final fresh = await api.active();
    _set(fresh == null ? null : cur.copyWith(session: fresh));
  }

  Future<SessionSummary> end() async {
    final cur = _current;
    if (cur == null) throw StateError('No active session');
    final summary = await ref.read(sessionApiProvider).end(cur.session.sessionId);
    _disconnect();
    _set(null);
    return summary;
  }

  /// "+15": extends the planned length (and the nudge clock moves with it server-side).
  Future<void> extend(int minutes) async {
    final cur = _current;
    if (cur == null) return;
    final s = await ref.read(sessionApiProvider).extend(cur.session.sessionId, minutes);
    _set(cur.copyWith(session: s));
  }

  /// After the user responded to a nudge.
  void clearIntervention() {
    final cur = _current;
    if (cur == null) return;
    _set(cur.copyWith(session: cur.session.copyWith(clearIntervention: true)));
  }

  // ── live updates ─────────────────────────────────────────────────────

  void _connect(String sessionId) {
    _disconnect();
    _sub = ref
        .read(sessionApiProvider)
        .stream(sessionId)
        .listen(
          (e) {
            _stopPolling();
            _onEvent(e);
          },
          onError: (Object e) => _fallBackToPolling(sessionId, e),
          onDone: () {
            // Server closed the stream without ending the session → poll.
            if (_current != null) _fallBackToPolling(sessionId, null);
          },
          cancelOnError: true,
        );
  }

  void _onEvent(SessionEvent e) {
    final cur = _current;
    if (cur == null) return;
    switch (e) {
      case SessionStateEvent(:final status):
        _applyStatus(status, LiveConnection.live);
      case InterventionEvent(:final interventionId):
        _set(
          cur.copyWith(
            connection: LiveConnection.live,
            session: cur.session.copyWith(pendingInterventionId: interventionId, state: FlowState.breakDue),
          ),
        );
      case BreakDueEvent():
        _set(cur.copyWith(session: cur.session.copyWith(state: FlowState.breakDue)));
      case SessionEndedEvent():
        _disconnect();
        _set(null);
    }
  }

  void _applyStatus(SessionStatus status, LiveConnection connection) {
    final cur = _current;
    if (cur == null) return;
    final session = cur.session.copyWith(
      state: status.state == FlowState.unknown ? null : status.state,
      pendingInterventionId: status.interventionId,
      clearIntervention: status.interventionId == null,
    );
    _set(cur.copyWith(session: session, status: status, connection: connection));
  }

  void _fallBackToPolling(String sessionId, Object? error) {
    _sub?.cancel();
    _sub = null;
    final cur = _current;
    if (cur == null) return;
    _set(cur.copyWith(connection: LiveConnection.polling));
    if (_poll != null) return;
    _pollsSinceStreamTry = 0;
    _poll = Timer.periodic(ref.read(sessionTimingProvider).pollEvery, (_) => _pollOnce(sessionId));
  }

  Future<void> _pollOnce(String sessionId) async {
    try {
      final status = await ref.read(sessionApiProvider).status(sessionId);
      _applyStatus(status, LiveConnection.polling);
      if (++_pollsSinceStreamTry >= ref.read(sessionTimingProvider).retryStreamAfterPolls) {
        _pollsSinceStreamTry = 0;
        _retryStream(sessionId);
      }
    } on ApiError catch (e) {
      final cur = _current;
      if (cur == null) return;
      if (e.isNotFound) {
        // Ended elsewhere (another device, server cleanup).
        _disconnect();
        _set(null);
      } else if (e.isNetwork) {
        _set(cur.copyWith(connection: LiveConnection.offline));
      }
    }
  }

  void _retryStream(String sessionId) {
    _sub?.cancel();
    _sub = ref
        .read(sessionApiProvider)
        .stream(sessionId)
        .listen(
          (e) {
            _stopPolling();
            _onEvent(e);
          },
          // Stay on polling; the timer keeps running.
          onError: (Object _) => _sub = null,
          cancelOnError: true,
        );
  }

  void _stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  void _disconnect() {
    _sub?.cancel();
    _sub = null;
    _stopPolling();
  }
}

/// Changes whenever a session starts, ends, or its state/intervention changes,
/// so day/terrain data refetches without polling.
final liveSessionRevisionProvider = Provider<Object?>((ref) {
  final l = ref.watch(liveSessionProvider).value;
  return (l?.session.sessionId, l?.session.state, l?.pendingInterventionId, l?.session.plannedMinutes);
});

final liveSessionProvider = AsyncNotifierProvider<LiveSessionController, LiveSession?>(LiveSessionController.new);

/// Ticks once a second while a session runs, for the countdown display.
final clockProvider = StreamProvider<DateTime>((ref) => Stream<DateTime>.periodic(const Duration(seconds: 1), (_) => DateTime.now()));
