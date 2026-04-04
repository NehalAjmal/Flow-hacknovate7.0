// lib/core/models.dart

class DashboardData {
  final int focusScore;
  final String currentState;
  final int totalFocusMins;
  final int contextSwitches;

  DashboardData({
    required this.focusScore, 
    required this.currentState, 
    required this.totalFocusMins,
    required this.contextSwitches,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      focusScore: json['focus_score'] ?? 50,
      currentState: json['current_state'] ?? 'DEEP_WORK',
      totalFocusMins: ((json['weekly_summary']?['deep_work_hours'] ?? 0) * 60).toInt(),
      contextSwitches: json['weekly_summary']?['context_switches'] ?? 0,
    );
  }
}

class BiometricData {
  final int hr;
  final int hrv;
  final double fatigueSignal;

  BiometricData({
    required this.hr, 
    required this.hrv, 
    required this.fatigueSignal
  });

  factory BiometricData.fromJson(Map<String, dynamic> json) {
    return BiometricData(
      hr: json['heart_rate_bpm'] ?? 72,
      hrv: json['hrv_sdnn'] ?? 55,
      fatigueSignal: (json['fatigue_signal'] ?? 0.5).toDouble(),
    );
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