import '../models/member.dart';
import '../models/team.dart';

/// /team/summary — team doc §5.8. Employee + admin.
abstract interface class TeamApi {
  Future<Suppressible<TeamMetrics>> summary();
}

/// /admin/* — team doc §5.8. Admin only.
/// Aggregates are suppressed under 5 people. Per-person data ([members],
/// [member]) is coarse by contract — time, counts, responses; never task
/// text, titles, apps — and people are told at the invite that the admin
/// sees it.
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

  /// Everyone on the team, this week (the People page).
  Future<List<MemberSummary>> members();

  /// One person's week and trends.
  Future<MemberDetail> member(String id);
}
