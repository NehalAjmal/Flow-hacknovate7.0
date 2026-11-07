import '../../core/json.dart';
import 'settings.dart';

enum Demand implements WireEnum {
  light('light'),
  moderate('moderate'),
  heavy('heavy');

  const Demand(this.wire);
  @override
  final String wire;
}

/// User-facing state chip (team doc §6.4). Never "fatigued"/"distracted":
/// Flow describes timing, not the person.
enum FlowState implements WireEnum {
  steady('steady'),
  approachingBreak('approaching_break'),
  breakDue('break_due'),
  paused('paused'),
  unknown('unknown');

  const FlowState(this.wire);
  @override
  final String wire;
}

class PreCheck {
  const PreCheck({required this.suggestedMinutes, this.nextMeetingInMin, this.warnings = const []});

  final int suggestedMinutes;
  final int? nextMeetingInMin;
  final List<String> warnings;

  factory PreCheck.fromJson(Json j) => PreCheck(
    suggestedMinutes: intOrNull(j['suggested_minutes']) ?? 50,
    nextMeetingInMin: intOrNull(j['next_meeting_in_min']),
    warnings: strList(j['warnings']),
  );
}

class StartSessionRequest {
  const StartSessionRequest({this.taskText, required this.demand, required this.plannedMinutes, this.shareTaskWithLlm = false});

  final String? taskText;
  final Demand demand;
  final int plannedMinutes;
  final bool shareTaskWithLlm;

  Json toJson() => {
    if (taskText != null && taskText!.trim().isNotEmpty) 'task_text': taskText!.trim(),
    'demand': demand.wire,
    'planned_minutes': plannedMinutes,
    'share_task_with_llm': shareTaskWithLlm,
  };
}

/// GET /session/active, and the result of POST /session/start.
class ActiveSession {
  const ActiveSession({
    required this.sessionId,
    required this.startedAt,
    required this.plannedMinutes,
    required this.demand,
    this.taskText,
    this.state = FlowState.steady,
    this.pendingInterventionId,
    this.paused = false,
    this.pausedSeconds = 0,
  });

  final String sessionId;
  final DateTime startedAt;
  final int plannedMinutes;
  final Demand demand;
  final String? taskText;
  final FlowState state;
  final String? pendingInterventionId;
  final bool paused;

  /// Total seconds spent paused so far; elapsed focus time excludes these.
  final int pausedSeconds;

  /// Elapsed focus time, derived from the server's start time so it survives
  /// app restarts (the old app counted from app launch).
  Duration elapsedAt(DateTime now) {
    final d = now.difference(startedAt) - Duration(seconds: pausedSeconds);
    return d.isNegative ? Duration.zero : d;
  }

  ActiveSession copyWith({
    FlowState? state,
    String? pendingInterventionId,
    bool clearIntervention = false,
    bool? paused,
    int? pausedSeconds,
  }) => ActiveSession(
    sessionId: sessionId,
    startedAt: startedAt,
    plannedMinutes: plannedMinutes,
    demand: demand,
    taskText: taskText,
    state: state ?? this.state,
    pendingInterventionId: clearIntervention ? null : (pendingInterventionId ?? this.pendingInterventionId),
    paused: paused ?? this.paused,
    pausedSeconds: pausedSeconds ?? this.pausedSeconds,
  );

  factory ActiveSession.fromJson(Json j) {
    final pending = j['pending_intervention'];
    return ActiveSession(
      sessionId: reqStr(j, 'session_id'),
      startedAt: dateOrNull(j['started_at']) ?? DateTime.now().subtract(Duration(minutes: intOrNull(j['elapsed_min']) ?? 0)),
      plannedMinutes: intOrNull(j['planned_minutes']) ?? 50,
      demand: enumFromWire(Demand.values, j['demand'], Demand.moderate),
      taskText: str(j['task_text']),
      state: enumFromWire(FlowState.values, j['state'], FlowState.steady),
      pendingInterventionId: pending is Map ? str(pending['id']) : str(pending),
      paused: boolOr(j['paused'], false),
      pausedSeconds: intOrNull(j['paused_seconds']) ?? 0,
    );
  }
}

class SignalReading {
  const SignalReading({required this.name, this.value, required this.weight});

  final String name;

  /// null when the signal is off (e.g. camera disabled).
  final double? value;
  final double weight;

  bool get available => value != null && weight > 0;

  factory SignalReading.fromJson(Json j) =>
      SignalReading(name: str(j['name']) ?? '?', value: dblOrNull(j['value']), weight: dblOrNull(j['weight']) ?? 0);
}

/// Stream `state` event and GET /session/status (team doc §5.11).
class SessionStatus {
  const SessionStatus({
    required this.sessionId,
    required this.elapsedMin,
    required this.combinedScore,
    required this.threshold,
    required this.signals,
    this.state = FlowState.steady,
    this.interventionId,
  });

  final String sessionId;
  final int elapsedMin;
  final double combinedScore;
  final double threshold;
  final List<SignalReading> signals;
  final FlowState state;
  final String? interventionId;

  /// 0..1 progress toward the break threshold, for "approaching break" UI.
  double get pressure => threshold <= 0 ? 0 : (combinedScore / threshold).clamp(0.0, 1.0);

  factory SessionStatus.fromJson(Json j) => SessionStatus(
    sessionId: str(j['session_id']) ?? '',
    elapsedMin: intOrNull(j['elapsed_min']) ?? 0,
    combinedScore: dblOrNull(j['combined_score']) ?? 0,
    threshold: dblOrNull(j['threshold']) ?? 1,
    signals: asJsonList(j['signals']).map(SignalReading.fromJson).toList(),
    state: enumFromWire(FlowState.values, j['state'], FlowState.unknown),
    interventionId: str(j['intervention_id']),
  );
}

/// Events on GET /session/stream.
sealed class SessionEvent {
  const SessionEvent();

  /// Parses one SSE/WebSocket message. Unknown types return null so new
  /// event types never crash older clients.
  static SessionEvent? fromJson(Json j) => switch (str(j['type'])) {
    'state' => SessionStateEvent(SessionStatus.fromJson(j)),
    'intervention' => InterventionEvent(
      interventionId: reqStr(j, 'intervention_id'),
      deliveryMode: enumFromWire(DeliveryMode.values, j['delivery_mode'], DeliveryMode.advisory),
    ),
    'break_due' => BreakDueEvent(suggestedBreakSec: intOrNull(j['suggested_break_sec'])),
    'session_ended' => SessionEndedEvent(str(j['session_id']) ?? ''),
    _ => null,
  };
}

class SessionStateEvent extends SessionEvent {
  const SessionStateEvent(this.status);
  final SessionStatus status;
}

class InterventionEvent extends SessionEvent {
  const InterventionEvent({required this.interventionId, required this.deliveryMode});
  final String interventionId;
  final DeliveryMode deliveryMode;
}

class BreakDueEvent extends SessionEvent {
  const BreakDueEvent({this.suggestedBreakSec});
  final int? suggestedBreakSec;
}

class SessionEndedEvent extends SessionEvent {
  const SessionEndedEvent(this.sessionId);
  final String sessionId;
}

/// Returned by POST /session/{id}/end and listed by GET /sessions.
class SessionSummary {
  const SessionSummary({
    required this.sessionId,
    required this.startedAt,
    this.endedAt,
    required this.focusMinutes,
    required this.plannedMinutes,
    required this.demand,
    this.taskText,
    this.breaksSuggested = 0,
    this.breaksTaken = 0,
    this.replayReady = false,
  });

  final String sessionId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int focusMinutes;
  final int plannedMinutes;
  final Demand demand;
  final String? taskText;
  final int breaksSuggested;
  final int breaksTaken;
  final bool replayReady;

  factory SessionSummary.fromJson(Json j) {
    // POST /end nests the summary: `{summary: {...}, replay_ready}`.
    final s = j['summary'] is Map ? asJson(j['summary']) : j;
    return SessionSummary(
      sessionId: str(s['session_id']) ?? str(j['session_id']) ?? '',
      startedAt: dateOrNull(s['started_at']) ?? DateTime.now(),
      endedAt: dateOrNull(s['ended_at']),
      focusMinutes: intOrNull(s['focus_minutes']) ?? 0,
      plannedMinutes: intOrNull(s['planned_minutes']) ?? 0,
      demand: enumFromWire(Demand.values, s['demand'], Demand.moderate),
      taskText: str(s['task_text']),
      breaksSuggested: intOrNull(s['breaks_suggested']) ?? 0,
      breaksTaken: intOrNull(s['breaks_taken']) ?? 0,
      replayReady: boolOr(j['replay_ready'], boolOr(s['replay_ready'], false)),
    );
  }
}

class SessionPage {
  const SessionPage({required this.items, required this.page, required this.hasMore});
  final List<SessionSummary> items;
  final int page;
  final bool hasMore;

  factory SessionPage.fromJson(Json j) => SessionPage(
    items: asJsonList(j['items']).map(SessionSummary.fromJson).toList(),
    page: intOrNull(j['page']) ?? 1,
    hasMore: boolOr(j['has_more'], false),
  );
}

class ReplayEvent {
  const ReplayEvent({required this.minute, required this.kind, required this.text});
  final int minute;
  final String kind;
  final String text;

  factory ReplayEvent.fromJson(Json j) =>
      ReplayEvent(minute: intOrNull(j['minute']) ?? 0, kind: str(j['kind']) ?? 'note', text: str(j['text']) ?? '');
}

class SessionReplay {
  const SessionReplay({required this.events, required this.whatFlowLearned});
  final List<ReplayEvent> events;
  final List<String> whatFlowLearned;

  factory SessionReplay.fromJson(Json j) =>
      SessionReplay(events: asJsonList(j['events']).map(ReplayEvent.fromJson).toList(), whatFlowLearned: strList(j['what_flow_learned']));
}

// ── Breaks, ratings, stuck ──────────────────────────────────────────────────

class BreakRecord {
  const BreakRecord({
    required this.id,
    required this.startedAt,
    this.endedAt,
    this.interventionId,
    this.actualMinutes,
    this.restorationScore,
  });

  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? interventionId;
  final int? actualMinutes;
  final double? restorationScore;

  factory BreakRecord.fromJson(Json j) => BreakRecord(
    id: reqStr(j, 'break_id'),
    startedAt: dateOrNull(j['started_at']) ?? DateTime.now(),
    endedAt: dateOrNull(j['ended_at']),
    interventionId: str(j['intervention_id']),
    actualMinutes: intOrNull(j['actual_minutes']),
    restorationScore: dblOrNull(j['restoration_score']),
  );
}

class BreakSummary {
  const BreakSummary({required this.suggested, required this.taken, required this.breaks});
  final int suggested;
  final int taken;
  final List<BreakRecord> breaks;

  factory BreakSummary.fromJson(Json j) => BreakSummary(
    suggested: intOrNull(j['suggested']) ?? 0,
    taken: intOrNull(j['taken']) ?? 0,
    breaks: asJsonList(j['breaks']).map(BreakRecord.fromJson).toList(),
  );
}

enum RatingKind implements WireEnum {
  focus('focus'),
  fatigue('fatigue'),
  postBreakFocus('post_break_focus');

  const RatingKind(this.wire);
  @override
  final String wire;
}

class StuckHelp {
  const StuckHelp({required this.breakdown, required this.questions, required this.nextStep, this.fromCache = false});

  final List<String> breakdown;
  final List<String> questions;
  final String nextStep;

  /// True when the model call failed and a cached fallback was returned.
  final bool fromCache;

  factory StuckHelp.fromJson(Json j) => StuckHelp(
    breakdown: strList(j['breakdown']),
    questions: strList(j['questions']),
    nextStep: str(j['next_step']) ?? '',
    fromCache: boolOr(j['cached'], false),
  );
}
