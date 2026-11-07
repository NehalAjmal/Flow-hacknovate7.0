import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/endpoint_policy.dart';
import '../../core/json.dart';
import '../contracts/agent_api.dart';
import '../models/agent.dart';

/// Talks to the local agent over JSON-on-WebSocket at [url].
///
/// Proposed wire protocol (see CONTRACT_NOTES.md), app → agent:
///   {"type":"get_status"} | {"type":"pair","code":"123456"}
///   {"type":"set_camera","on":true} | {"type":"watch_resumption","break_id":"…"}
/// agent → app: `status`, `signals`, `resumption` events (see AgentEvent).
class RealLocalAgentApi implements LocalAgentApi {
  RealLocalAgentApi(this.url);

  final String url;
  WebSocketChannel? _ch;
  final _events = StreamController<AgentEvent>.broadcast();
  AgentStatus _last = AgentStatus.offline;

  Future<WebSocketChannel?> _connect() async {
    if (_ch != null) return _ch;
    try {
      final target = Uri.parse(url);
      // activity data never leaves this computer
      if (EndpointPolicy.agentProblem(target) != null) return null;
      final ch = WebSocketChannel.connect(target);
      await ch.ready.timeout(const Duration(seconds: 2));
      ch.stream.listen(
        (raw) {
          try {
            final e = AgentEvent.fromJson(asJson(jsonDecode(raw.toString())));
            if (e is AgentStatusEvent) _last = e.status;
            if (e != null) _events.add(e);
          } on FormatException {
            // ignore malformed frames
          }
        },
        onDone: _onClosed,
        onError: (_) => _onClosed(),
      );
      _ch = ch;
      return ch;
    } catch (_) {
      _onClosed();
      return null;
    }
  }

  void _onClosed() {
    _ch = null;
    _last = AgentStatus.offline;
    _events.add(const AgentStatusEvent(AgentStatus.offline));
  }

  Future<void> _send(Json msg) async {
    final ch = await _connect();
    if (ch == null) throw StateError('Flow agent is not running on this computer.');
    ch.sink.add(jsonEncode(msg));
  }

  @override
  Stream<AgentEvent> events() {
    unawaited(_connect());
    return _events.stream;
  }

  @override
  Future<AgentStatus> status() async {
    final ch = await _connect();
    if (ch == null) return AgentStatus.offline;
    final next = _events.stream
        .where((e) => e is AgentStatusEvent)
        .cast<AgentStatusEvent>()
        .first
        .timeout(const Duration(seconds: 2), onTimeout: () => AgentStatusEvent(_last));
    ch.sink.add(jsonEncode({'type': 'get_status'}));
    return (await next).status;
  }

  @override
  Future<void> pair(String code) => _send({'type': 'pair', 'code': code});

  @override
  Future<void> setCamera(bool on) => _send({'type': 'set_camera', 'on': on});

  @override
  Future<void> watchResumption(String breakId) => _send({'type': 'watch_resumption', 'break_id': breakId});
}
