import '../../core/json.dart';

enum ConsentScope implements WireEnum {
  behavior('behavior', required: true),
  camera('camera'),
  calendar('calendar'),
  llm('llm'),
  teamAggregate('team_aggregate');

  const ConsentScope(this.wire, {this.required = false});
  @override
  final String wire;

  /// Flow cannot run a session without this scope.
  final bool required;
}

class ConsentEntry {
  const ConsentEntry({required this.scope, required this.granted, this.version, this.at});

  final ConsentScope scope;
  final bool granted;
  final String? version;
  final DateTime? at;

  factory ConsentEntry.fromJson(ConsentScope scope, Json j) =>
      ConsentEntry(scope: scope, granted: boolOr(j['granted'], false), version: str(j['version']), at: dateOrNull(j['timestamp']));
}

/// GET /consent → `{ "policy_version": "...", "scopes": { "<scope>": {...} } }`.
class ConsentState {
  const ConsentState({required this.entries, this.policyVersion});

  final Map<ConsentScope, ConsentEntry> entries;

  /// Version the user must agree to. A granted entry with an older version
  /// counts as not granted.
  final String? policyVersion;

  bool granted(ConsentScope s) {
    final e = entries[s];
    if (e == null || !e.granted) return false;
    return policyVersion == null || e.version == null || e.version == policyVersion;
  }

  List<ConsentScope> get missingRequired => ConsentScope.values.where((s) => s.required && !granted(s)).toList();

  bool get canUseFlow => missingRequired.isEmpty;

  factory ConsentState.fromJson(Json j) {
    final scopes = asJson(j['scopes']);
    final entries = <ConsentScope, ConsentEntry>{};
    for (final s in ConsentScope.values) {
      final raw = scopes[s.wire];
      if (raw is Map) entries[s] = ConsentEntry.fromJson(s, asJson(raw));
    }
    return ConsentState(entries: entries, policyVersion: str(j['policy_version']));
  }

  ConsentState copyWithEntry(ConsentEntry e) => ConsentState(entries: {...entries, e.scope: e}, policyVersion: policyVersion);
}
