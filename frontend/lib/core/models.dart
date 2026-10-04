// lib/core/models.dart
// Typed parsers for the backend payloads. Every field tolerates absence —
// the UI decides how to render missing data.

class DashboardData {
  final int focusScore;
  final int focusDelta;
  final int sessionsToday;
  final int totalFocusMins;
  final int rhythmPositionMin;
  final int minutesUntilTrough;
  final String greeting;

  DashboardData({
    required this.focusScore,
    required this.focusDelta,
    required this.sessionsToday,
    required this.totalFocusMins,
    required this.rhythmPositionMin,
    required this.minutesUntilTrough,
    required this.greeting,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      focusScore: json['focus_score_today'] ?? 75,
      focusDelta: json['focus_score_delta'] ?? 0,
      sessionsToday: json['sessions_today'] ?? 0,
      totalFocusMins: json['total_duration_minutes'] ?? 0,
      rhythmPositionMin: json['rhythm_position_minutes'] ?? 0,
      minutesUntilTrough: json['minutes_until_trough'] ?? 0,
      greeting: json['greeting_message'] ?? 'Welcome back',
    );
  }
}

class BiometricData {
  final int hr;
  final int hrv;
  final double ear;
  final double fatigueSignal;

  BiometricData({
    required this.hr,
    required this.hrv,
    required this.ear,
    required this.fatigueSignal,
  });

  factory BiometricData.fromJson(Map<String, dynamic> json) {
    return BiometricData(
      hr: (json['heart_rate_bpm'] ?? 0).toInt(),
      hrv: (json['hrv_sdnn'] ?? 0).toInt(),
      ear: (json['ear_value'] ?? 0).toDouble(),
      fatigueSignal: (json['fatigue_signal'] ?? 0.5).toDouble(),
    );
  }

  bool get hasHr => hr > 0;
  bool get hasHrv => hrv > 0;
}

class ChartPoint {
  final String label;
  final int value;

  ChartPoint({required this.label, required this.value});

  factory ChartPoint.fromJson(Map<String, dynamic> json) {
    return ChartPoint(label: json['label'] ?? '', value: json['value'] ?? 0);
  }
}

class PatternsData {
  final int cycleMinutes;
  final List<int> peakFocusHours;
  final List<ChartPoint> weeklyTrends;
  final List<ChartPoint> hourlyQuality;

  PatternsData({
    required this.cycleMinutes,
    required this.peakFocusHours,
    required this.weeklyTrends,
    required this.hourlyQuality,
  });

  factory PatternsData.fromJson(Map<String, dynamic> json) {
    return PatternsData(
      cycleMinutes: json['ultradian_cycle_minutes'] ?? 90,
      peakFocusHours:
          (json['peak_focus_hours'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [],
      weeklyTrends:
          (json['weekly_trends'] as List?)?.map((e) => ChartPoint.fromJson(e)).toList() ?? [],
      hourlyQuality:
          (json['hourly_quality'] as List?)?.map((e) => ChartPoint.fromJson(e)).toList() ?? [],
    );
  }

  String get peakHoursLabel {
    if (peakFocusHours.isEmpty) return 'No peak data yet';
    final sorted = [...peakFocusHours]..sort();
    return sorted.map((h) => '$h:00').join(' · ');
  }
}

class TrendPoint {
  final String day;
  final int avgScore;

  TrendPoint({required this.day, required this.avgScore});

  factory TrendPoint.fromJson(Map<String, dynamic> json) {
    return TrendPoint(
      day: json['day'] ?? '',
      avgScore: json['avg_score'] ?? 0,
    );
  }
}

class BurnoutFlag {
  final String employeeId;
  final String displayName;
  final String riskLevel;
  final int sessionsThisWeek;
  final int avgFocusScore;

  BurnoutFlag({
    required this.employeeId,
    required this.displayName,
    required this.riskLevel,
    required this.sessionsThisWeek,
    required this.avgFocusScore,
  });

  factory BurnoutFlag.fromJson(Map<String, dynamic> json) {
    return BurnoutFlag(
      employeeId: json['employee_id'] ?? '',
      displayName: json['display_name'] ?? 'Unknown',
      riskLevel: json['risk_level'] ?? 'medium',
      sessionsThisWeek: json['sessions_this_week'] ?? 0,
      avgFocusScore: json['avg_focus_score'] ?? 0,
    );
  }
}

class AdminDashboardData {
  final int totalEmployees;
  final int activeRightNow;
  final int avgFocusScore;
  final int burnoutFlagsCount;
  final String bestMeetingWindow;
  final List<TrendPoint> trend7Days;
  final List<BurnoutFlag> burnoutFlags;
  final Map<String, int> stateDistribution;

  AdminDashboardData({
    required this.totalEmployees,
    required this.activeRightNow,
    required this.avgFocusScore,
    required this.burnoutFlagsCount,
    required this.bestMeetingWindow,
    required this.trend7Days,
    required this.burnoutFlags,
    required this.stateDistribution,
  });

  factory AdminDashboardData.fromJson(Map<String, dynamic> json) {
    return AdminDashboardData(
      totalEmployees: json['total_employees'] ?? 0,
      activeRightNow: json['active_right_now'] ?? 0,
      avgFocusScore: json['avg_focus_score'] ?? 0,
      burnoutFlagsCount: json['burnout_flags_count'] ?? 0,
      bestMeetingWindow: json['best_meeting_window'] ?? '--:--',
      trend7Days: (json['trend_7_days'] as List?)?.map((e) => TrendPoint.fromJson(e)).toList() ?? [],
      burnoutFlags: (json['burnout_flags'] as List?)?.map((e) => BurnoutFlag.fromJson(e)).toList() ?? [],
      stateDistribution: Map<String, int>.from(json['state_distribution'] ?? {}),
    );
  }
}

/// Payload returned by POST /session/end.
class SessionEndData {
  final String sessionId;
  final int focusScore;
  final int? actualDurationMin;
  final int cycleMinutes;
  final int troughMinute;
  final int eventCount;
  final List<double> scores;
  final List<Map<String, dynamic>> events;

  SessionEndData({
    required this.sessionId,
    required this.focusScore,
    required this.actualDurationMin,
    required this.cycleMinutes,
    required this.troughMinute,
    required this.eventCount,
    required this.scores,
    required this.events,
  });

  factory SessionEndData.fromJson(Map<String, dynamic> json) {
    final params = (json['patterns']?['parameters'] ?? {}) as Map<String, dynamic>;
    final events = (json['events'] as List?) ?? [];
    return SessionEndData(
      sessionId: (json['session_id'] ?? '').toString(),
      focusScore: json['focus_score'] ?? 75,
      actualDurationMin: json['actual_duration_min'],
      cycleMinutes: params['ultradian_cycle_minutes'] ?? 90,
      troughMinute: params['trough_minute'] ?? 45,
      eventCount: events.length,
      scores: List<double>.from(
        events.map((e) => ((e is Map ? e['score'] : null) ?? 75).toDouble()),
      ),
      events: events.whereType<Map<String, dynamic>>().toList(),
    );
  }
}
