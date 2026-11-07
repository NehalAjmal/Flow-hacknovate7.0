import 'config.dart';

/// Where Flow may send data. Release builds refuse unencrypted transport to
/// anything but this machine, and the local agent must be on this machine.
abstract final class EndpointPolicy {
  static bool isLoopback(Uri u) => const {'127.0.0.1', 'localhost', '::1'}.contains(u.host);

  /// Null when [u] is acceptable for the Flow backend; otherwise why not.
  static String? backendProblem(Uri u) {
    if (kDevBuild) return null; // dev builds point anywhere on purpose
    if (u.scheme == 'https' && u.host.isNotEmpty) return null;
    if (u.scheme == 'http' && isLoopback(u)) return null;
    return 'Flow only talks to its server over HTTPS. This build points at "${u.scheme}://${u.host}".';
  }

  /// The activity agent is local by definition: loopback WebSocket only.
  static String? agentProblem(Uri u) {
    if ((u.scheme == 'ws' || u.scheme == 'wss') && isLoopback(u)) return null;
    return 'The activity agent must run on this computer (got "${u.scheme}://${u.host}").';
  }

  /// OAuth consent pages Flow will open in the browser (server-provided URL).
  static const oauthHosts = {'accounts.google.com'};
  static bool isAllowedOAuthUrl(Uri u) => u.scheme == 'https' && oauthHosts.contains(u.host);
}
