import '../../core/json.dart';

/// Every team/admin response carries group size and suppression (doc §5.8).
/// When `suppressed`, `data` is null and the UI must say why instead of
/// showing zeros.
class Suppressible<T> {
  const Suppressible({required this.groupSize, required this.suppressed, this.reason, this.data});

  final int groupSize;
  final bool suppressed;
  final String? reason;
  final T? data;

  static const minGroupSize = 5;

  factory Suppressible.fromJson(Json j, T Function(Json) read, {String key = 'metrics'}) {
    final suppressed = boolOr(j['suppressed'], true);
    final raw = j[key];
    return Suppressible(
      groupSize: intOrNull(j['group_size']) ?? 0,
      suppressed: suppressed,
      reason: str(j['reason']),
      // Never trust data the server sent alongside suppressed=true.
      data: !suppressed && raw is Map ? read(asJson(raw)) : null,
    );
  }
}

class TrendPoint {
  const TrendPoint({required this.date, required this.value});
  final DateTime date;
  final double value;

  factory TrendPoint.fromJson(Json j) => TrendPoint(date: dateOrNull(j['date']) ?? DateTime.now(), value: dblOrNull(j['value']) ?? 0);
}

class TeamMetrics {
  const TeamMetrics({required this.averageFocus, required this.trend});
  final double averageFocus;
  final List<TrendPoint> trend;

  factory TeamMetrics.fromJson(Json j) =>
      TeamMetrics(averageFocus: dblOrNull(j['average_focus']) ?? 0, trend: asJsonList(j['trend']).map(TrendPoint.fromJson).toList());
}

class AdminSummary {
  const AdminSummary({required this.activeCount, required this.avgFocusTrend, required this.sessionVolume});
  final int activeCount;
  final List<TrendPoint> avgFocusTrend;
  final int sessionVolume;

  factory AdminSummary.fromJson(Json j) => AdminSummary(
    activeCount: intOrNull(j['active_count']) ?? 0,
    avgFocusTrend: asJsonList(j['avg_focus_trend']).map(TrendPoint.fromJson).toList(),
    sessionVolume: intOrNull(j['session_volume']) ?? 0,
  );
}

class AdminTrend {
  const AdminTrend({required this.days7, required this.days30});
  final List<TrendPoint> days7;
  final List<TrendPoint> days30;

  factory AdminTrend.fromJson(Json j) => AdminTrend(
    days7: asJsonList(j['days_7']).map(TrendPoint.fromJson).toList(),
    days30: asJsonList(j['days_30']).map(TrendPoint.fromJson).toList(),
  );
}

class AdminInsights {
  const AdminInsights({required this.peakHours, this.typicalRecoveryMin});
  final List<int> peakHours;
  final int? typicalRecoveryMin;

  factory AdminInsights.fromJson(Json j) =>
      AdminInsights(peakHours: intList(j['peak_hours']), typicalRecoveryMin: intOrNull(j['typical_recovery_min']));
}

/// Team workload signal. Never a health or burnout detector (doc §8).
class TeamStrain {
  const TeamStrain({required this.level, required this.note});

  /// `low` | `moderate` | `high`
  final String level;
  final String note;

  factory TeamStrain.fromJson(Json j) => TeamStrain(level: str(j['level']) ?? 'low', note: str(j['note']) ?? '');
}

class MeetingWindow {
  const MeetingWindow({required this.start, required this.end});
  final String start;
  final String end;

  factory MeetingWindow.fromJson(Json j) => MeetingWindow(start: str(j['start']) ?? '', end: str(j['end']) ?? '');
}

class AdminPrivacyStatus {
  const AdminPrivacyStatus({required this.groupSize, required this.suppressed, required this.canSee, required this.cannotSee});
  final int groupSize;
  final bool suppressed;
  final List<String> canSee;
  final List<String> cannotSee;

  factory AdminPrivacyStatus.fromJson(Json j) => AdminPrivacyStatus(
    groupSize: intOrNull(j['group_size']) ?? 0,
    suppressed: boolOr(j['suppressed'], true),
    canSee: strList(j['can_see']),
    cannotSee: strList(j['cannot_see']),
  );
}

class Invite {
  const Invite({required this.id, required this.createdAt, required this.expiresAt, required this.used, this.url});
  final String id;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool used;

  /// Only returned once, on creation.
  final String? url;

  bool get expired => DateTime.now().isAfter(expiresAt);

  factory Invite.fromJson(Json j) => Invite(
    id: reqStr(j, 'id'),
    createdAt: dateOrNull(j['created_at']) ?? DateTime.now(),
    expiresAt: dateOrNull(j['expires_at']) ?? DateTime.now(),
    used: boolOr(j['used'], false),
    url: str(j['url']),
  );
}

class AuditEntry {
  const AuditEntry({required this.action, required this.at, required this.actor});
  final String action;
  final DateTime at;
  final String actor;

  factory AuditEntry.fromJson(Json j) =>
      AuditEntry(action: str(j['action']) ?? '', at: dateOrNull(j['at']) ?? DateTime.now(), actor: str(j['actor']) ?? '');
}
