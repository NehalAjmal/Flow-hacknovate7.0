import '../../core/json.dart';

/// Coarse app category. Window titles never leave the device (doc §2.4).
enum AppCategory implements WireEnum {
  editor('editor'),
  terminal('terminal'),
  browser('browser'),
  chat('chat'),
  docs('docs'),
  meeting('meeting'),
  other('other');

  const AppCategory(this.wire);
  @override
  final String wire;
}

enum AgentConnection { disconnected, unpaired, connected }

class AgentStatus {
  const AgentStatus({required this.connection, this.behaviorOn = false, this.cameraOn = false, this.category, this.agentVersion});

  final AgentConnection connection;
  final bool behaviorOn;
  final bool cameraOn;
  final AppCategory? category;
  final String? agentVersion;

  static const offline = AgentStatus(connection: AgentConnection.disconnected);

  factory AgentStatus.fromJson(Json j) => AgentStatus(
    connection: boolOr(j['paired'], false) ? AgentConnection.connected : AgentConnection.unpaired,
    behaviorOn: boolOr(j['behavior_on'], false),
    cameraOn: boolOr(j['camera_on'], false),
    category: enumFromWireOrNull(AppCategory.values, j['app_category']),
    agentVersion: str(j['version']),
  );
}

/// Live counts for the "expand live signals" panel. Local only.
class LiveSignals {
  const LiveSignals({required this.keysPerMin, required this.switchesPer5Min, required this.idleSec, this.eyeScore});
  final int keysPerMin;
  final int switchesPer5Min;
  final int idleSec;
  final double? eyeScore;

  factory LiveSignals.fromJson(Json j) => LiveSignals(
    keysPerMin: intOrNull(j['keys_per_min']) ?? 0,
    switchesPer5Min: intOrNull(j['switches_per_5min']) ?? 0,
    idleSec: intOrNull(j['idle_sec']) ?? 0,
    eyeScore: dblOrNull(j['eye_score']),
  );
}

sealed class AgentEvent {
  const AgentEvent();

  static AgentEvent? fromJson(Json j) => switch (str(j['type'])) {
    'status' => AgentStatusEvent(AgentStatus.fromJson(j)),
    'signals' => AgentSignalsEvent(LiveSignals.fromJson(j)),
    'resumption' => AgentResumptionEvent(breakId: reqStr(j, 'break_id'), secondsToFirstEdit: intOrNull(j['seconds_to_first_edit']) ?? 0),
    _ => null,
  };
}

class AgentStatusEvent extends AgentEvent {
  const AgentStatusEvent(this.status);
  final AgentStatus status;
}

class AgentSignalsEvent extends AgentEvent {
  const AgentSignalsEvent(this.signals);
  final LiveSignals signals;
}

class AgentResumptionEvent extends AgentEvent {
  const AgentResumptionEvent({required this.breakId, required this.secondsToFirstEdit});
  final String breakId;
  final int secondsToFirstEdit;
}
