import '../models/agent.dart';

/// The local activity agent on this machine (team doc §5.10). Never talks to
/// the cloud on the app's behalf; raw window titles and camera frames stay
/// inside the agent.
abstract interface class LocalAgentApi {
  /// Connects if needed. Emits status, live signals and resumption events.
  Stream<AgentEvent> events();
  Future<AgentStatus> status();

  /// One-time pairing with the code the agent shows on first run.
  Future<void> pair(String code);
  Future<void> setCamera(bool on);

  /// Start measuring time-to-first-edit after this break. The agent answers
  /// with an [AgentResumptionEvent].
  Future<void> watchResumption(String breakId);
}
