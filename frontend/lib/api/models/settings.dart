import '../../core/json.dart';

enum DeliveryMode implements WireEnum {
  /// Default. Quiet nudge, never steals focus.
  advisory('advisory'),

  /// Nudge plus the one-line reason shown up front.
  explained('explained'),

  /// Opt-in full-screen break with a visible emergency override.
  lock('lock');

  const DeliveryMode(this.wire);
  @override
  final String wire;
}

class QuietHours {
  const QuietHours({required this.start, required this.end});

  /// "HH:mm", local time.
  final String start;
  final String end;

  factory QuietHours.fromJson(Json j) => QuietHours(start: str(j['start']) ?? '22:00', end: str(j['end']) ?? '07:00');

  Json toJson() => {'start': start, 'end': end};
}

class UserSettings {
  const UserSettings({
    this.deliveryMode = DeliveryMode.advisory,
    this.breakLengthSec = 300,
    this.quietHours,
    this.cameraEnabled = false,
    this.calendarEnabled = false,
    this.llmEnabled = false,
    this.snoozeOptions = const [5, 10, 20],
  });

  final DeliveryMode deliveryMode;
  final int breakLengthSec;
  final QuietHours? quietHours;
  final bool cameraEnabled;
  final bool calendarEnabled;
  final bool llmEnabled;

  /// Minutes.
  final List<int> snoozeOptions;

  factory UserSettings.fromJson(Json j) => UserSettings(
    deliveryMode: enumFromWire(DeliveryMode.values, j['delivery_mode'], DeliveryMode.advisory),
    breakLengthSec: intOrNull(j['break_length_sec']) ?? 300,
    quietHours: j['quiet_hours'] is Map ? QuietHours.fromJson(asJson(j['quiet_hours'])) : null,
    cameraEnabled: boolOr(j['camera_enabled'], false),
    calendarEnabled: boolOr(j['calendar_enabled'], false),
    llmEnabled: boolOr(j['llm_enabled'], false),
    snoozeOptions: intList(j['snooze_options']).isEmpty ? const [5, 10, 20] : intList(j['snooze_options']),
  );
}

/// Partial update for PUT /settings. Only non-null fields are sent.
class SettingsPatch {
  const SettingsPatch({
    this.deliveryMode,
    this.breakLengthSec,
    this.quietHours,
    this.clearQuietHours = false,
    this.cameraEnabled,
    this.calendarEnabled,
    this.llmEnabled,
    this.snoozeOptions,
  });

  final DeliveryMode? deliveryMode;
  final int? breakLengthSec;
  final QuietHours? quietHours;
  final bool clearQuietHours;
  final bool? cameraEnabled;
  final bool? calendarEnabled;
  final bool? llmEnabled;
  final List<int>? snoozeOptions;

  Json toJson() => {
    if (deliveryMode != null) 'delivery_mode': deliveryMode!.wire,
    if (breakLengthSec != null) 'break_length_sec': breakLengthSec,
    if (quietHours != null) 'quiet_hours': quietHours!.toJson(),
    if (clearQuietHours) 'quiet_hours': null,
    if (cameraEnabled != null) 'camera_enabled': cameraEnabled,
    if (calendarEnabled != null) 'calendar_enabled': calendarEnabled,
    if (llmEnabled != null) 'llm_enabled': llmEnabled,
    if (snoozeOptions != null) 'snooze_options': snoozeOptions,
  };

  UserSettings applyTo(UserSettings s) => UserSettings(
    deliveryMode: deliveryMode ?? s.deliveryMode,
    breakLengthSec: breakLengthSec ?? s.breakLengthSec,
    quietHours: clearQuietHours ? null : (quietHours ?? s.quietHours),
    cameraEnabled: cameraEnabled ?? s.cameraEnabled,
    calendarEnabled: calendarEnabled ?? s.calendarEnabled,
    llmEnabled: llmEnabled ?? s.llmEnabled,
    snoozeOptions: snoozeOptions ?? s.snoozeOptions,
  );
}

class PauseState {
  const PauseState({required this.paused, this.until});

  final bool paused;
  final DateTime? until;

  static const running = PauseState(paused: false);

  factory PauseState.fromJson(Json j) => PauseState(paused: boolOr(j['paused'], false), until: dateOrNull(j['until']));
}
