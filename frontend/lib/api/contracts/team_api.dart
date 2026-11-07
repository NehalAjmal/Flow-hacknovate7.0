import '../models/team.dart';

/// /team/summary — team doc §5.8. Employee + admin.
abstract interface class TeamApi {
  Future<Suppressible<TeamMetrics>> summary();
}

/// /admin/* — team doc §5.8. Admin only. No per-person data, ever.
abstract interface class AdminApi {
  Future<Suppressible<AdminSummary>> summary();
  Future<Suppressible<AdminTrend>> trend();
  Future<Suppressible<AdminInsights>> insights();
  Future<Suppressible<TeamStrain>> strain();
  Future<Suppressible<MeetingWindow>> meetingWindow();
  Future<AdminPrivacyStatus> privacyStatus();
  Future<Invite> createInvite({Duration validFor = const Duration(days: 7)});
  Future<List<Invite>> invites();
  Future<void> revokeInvite(String id);
  Future<List<AuditEntry>> auditLog();
}
