import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_connector.dart';
import '../api/models/agent.dart';
import '../api/models/intervention.dart';
import '../api/models/session.dart';
import '../api/models/settings.dart';
import 'account_controllers.dart';
import 'auth_controller.dart';
import 'session_controller.dart';

class ActiveBreak {
  const ActiveBreak({
    required this.breakId,
    required this.sessionId,
    required this.startedAt,
    required this.plannedSec,
    this.interventionId,
    this.lock = false,
  });

  final String breakId;
  final String sessionId;
  final DateTime startedAt;
  final int plannedSec;
  final String? interventionId;

  /// Full-screen lock (opt-in delivery mode). Must show the override.
  final bool lock;

  DateTime get endsAt => startedAt.add(Duration(seconds: plannedSec));
}

class BreakResult {
  const BreakResult({required this.breakId, required this.sessionId, this.restorationScore});
  final String breakId;
  final String sessionId;
  final double? restorationScore;
}

class BreakController extends Notifier<ActiveBreak?> {
  @override
  ActiveBreak? build() {
    ref.watch(currentUserIdProvider); // reset on sign-out
    return null;
  }

  /// [interventionId] null = user-initiated break.
  Future<ActiveBreak> start({String? interventionId, int? plannedSec, bool lock = false}) async {
    final live = ref.read(liveSessionProvider).value;
    if (live == null) throw StateError('No active session');
    final settings = ref.read(settingsProvider).value;
    final id = await ref.read(breakApiProvider).start(sessionId: live.session.sessionId, interventionId: interventionId);
    final b = ActiveBreak(
      breakId: id,
      sessionId: live.session.sessionId,
      startedAt: DateTime.now(),
      plannedSec: plannedSec ?? settings?.breakLengthSec ?? 300,
      interventionId: interventionId,
      lock: lock,
    );
    if (ref.mounted) state = b;
    return b;
  }

  /// Ends the break, asks the agent to time the return to work.
  Future<BreakResult> end() async {
    final b = state;
    if (b == null) throw StateError('No active break');
    final minutes = (DateTime.now().difference(b.startedAt).inSeconds / 60).ceil();
    final score = await ref.read(breakApiProvider).end(b.breakId, actualMinutes: minutes);
    ref.read(resumptionTrackerProvider.notifier).expect(b.breakId, b.sessionId);
    try {
      await ref.read(localAgentApiProvider).watchResumption(b.breakId);
    } catch (_) {
      // Agent not running: no resumption metric for this break. Not fatal.
    }
    if (ref.mounted) state = null;
    return BreakResult(breakId: b.breakId, sessionId: b.sessionId, restorationScore: score);
  }
}

final breakProvider = NotifierProvider<BreakController, ActiveBreak?>(BreakController.new);

/// Forwards the agent's "time to first edit" to the backend.
class ResumptionTracker extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() {
    final sub = ref.watch(localAgentApiProvider).events().listen((e) async {
      if (e is! AgentResumptionEvent) return;
      final sessionId = state[e.breakId];
      if (sessionId == null) return;
      state = {...state}..remove(e.breakId);
      try {
        await ref.read(sessionApiProvider).reportResumption(sessionId, breakId: e.breakId, secondsToFirstEdit: e.secondsToFirstEdit);
      } catch (_) {}
    });
    ref.onDispose(sub.cancel);
    return const {};
  }

  void expect(String breakId, String sessionId) => state = {...state, breakId: sessionId};
}

final resumptionTrackerProvider = NotifierProvider<ResumptionTracker, Map<String, String>>(ResumptionTracker.new);

/// Responses to the intervention card. Keeps session + break state in sync.
class InterventionActions {
  InterventionActions(this.ref);
  final Ref ref;

  /// "Take a break". Returns the break that was started.
  Future<ActiveBreak> accept(Intervention i) async {
    await ref.read(interventionApiProvider).respond(i.id, InterventionResponse.accepted);
    ref.read(liveSessionProvider.notifier).clearIntervention();
    return ref
        .read(breakProvider.notifier)
        .start(interventionId: i.id, plannedSec: i.suggestedBreakSec, lock: i.deliveryMode == DeliveryMode.lock);
  }

  Future<void> snooze(Intervention i, int minutes) async {
    await ref.read(interventionApiProvider).respond(i.id, InterventionResponse.snoozed, snoozeMinutes: minutes);
    ref.read(liveSessionProvider.notifier).clearIntervention();
  }

  Future<void> dismiss(Intervention i) async {
    await ref.read(interventionApiProvider).respond(i.id, InterventionResponse.dismissed);
    ref.read(liveSessionProvider.notifier).clearIntervention();
  }

  /// Lock mode only. Logged server-side; never punished in the UI.
  Future<void> overrideLock(String interventionId, OverrideReason reason) async {
    await ref.read(interventionApiProvider).overrideLock(interventionId, reason);
    ref.read(liveSessionProvider.notifier).clearIntervention();
    if (ref.read(breakProvider)?.interventionId == interventionId) {
      await ref.read(breakProvider.notifier).end();
    }
  }

  Future<void> report(String interventionId, ReportReason reason, {String? text}) =>
      ref.read(interventionApiProvider).report(interventionId, reason, freeText: text);

  Future<void> rate(RatingKind kind, int value, {String? contextId}) async {
    final sessionId = ref.read(liveSessionProvider).value?.session.sessionId;
    if (sessionId == null) return;
    await ref.read(breakApiProvider).rate(sessionId: sessionId, kind: kind, value: value, contextId: contextId);
  }
}

final interventionActionsProvider = Provider<InterventionActions>(InterventionActions.new);

final interventionProvider = FutureProvider.autoDispose.family<Intervention, String>(
  (ref, id) => ref.watch(interventionApiProvider).get(id),
);

final explanationProvider = FutureProvider.autoDispose.family<Explanation, (String, ExplainDetail)>(
  (ref, key) => ref.watch(interventionApiProvider).explain(key.$1, detail: key.$2),
);

/// Fire-and-forget helper for rating outside the active-session context.
Future<void> rateSession(Ref ref, String sessionId, RatingKind kind, int value) =>
    ref.read(breakApiProvider).rate(sessionId: sessionId, kind: kind, value: value);
