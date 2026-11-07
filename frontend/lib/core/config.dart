/// Build-time configuration. Everything here is a compile-time constant so
/// that `kDevBuild == false` lets the compiler strip dev-only code (mocks,
/// dev panel) out of release builds entirely.
library;

/// `flutter run --dart-define=FLOW_DEV=true` enables mocks + the dev panel.
/// Release builds must NOT pass this flag.
const bool kDevBuild = bool.fromEnvironment('FLOW_DEV');

/// Backend origin, e.g. `--dart-define=FLOW_API_URL=https://api.flow.app`.
const String kDefaultApiBase = String.fromEnvironment('FLOW_API_URL', defaultValue: 'http://127.0.0.1:8002');

/// Every backend path lives under this prefix (team doc §5).
const String kApiPrefix = '/api/v1';

/// Local activity agent (team doc §5.10). Transport is an assumption:
/// JSON over a localhost WebSocket. See CONTRACT_NOTES.md.
const String kDefaultAgentUrl = String.fromEnvironment('FLOW_AGENT_URL', defaultValue: 'ws://127.0.0.1:8765');
