import '../../core/json.dart';
import 'settings.dart';

class Intervention {
  const Intervention({
    required this.id,
    required this.type,
    required this.message,
    required this.deliveryMode,
    required this.suggestedBreakSec,
    required this.shortReason,
  });

  final String id;

  /// Free-form so new types don't need a client release (e.g. `break`,
  /// `approaching_break`, `stuck_check`).
  final String type;
  final String message;
  final DeliveryMode deliveryMode;
  final int suggestedBreakSec;

  /// One line, shown on the card. The full table comes from /explain.
  final String shortReason;

  factory Intervention.fromJson(Json j) => Intervention(
    id: reqStr(j, 'id'),
    type: str(j['type']) ?? 'break',
    message: str(j['message']) ?? '',
    deliveryMode: enumFromWire(DeliveryMode.values, j['delivery_mode'], DeliveryMode.advisory),
    suggestedBreakSec: intOrNull(j['suggested_break_sec']) ?? 300,
    shortReason: str(j['short_reason']) ?? '',
  );
}

enum ExplainDetail implements WireEnum {
  short('short'),
  full('full');

  const ExplainDetail(this.wire);
  @override
  final String wire;
}

class Contribution {
  const Contribution({required this.name, required this.value, required this.weight, required this.contribution});
  final String name;
  final double value;
  final double weight;
  final double contribution;

  factory Contribution.fromJson(Json j) => Contribution(
    name: str(j['name']) ?? '?',
    value: dblOrNull(j['value']) ?? 0,
    weight: dblOrNull(j['weight']) ?? 0,
    contribution: dblOrNull(j['contribution']) ?? 0,
  );
}

class Explanation {
  const Explanation({
    required this.interventionId,
    required this.detail,
    required this.headline,
    required this.primaryDriver,
    required this.contributions,
    required this.combinedScore,
    required this.threshold,
  });

  final String interventionId;
  final ExplainDetail detail;
  final String headline;
  final String primaryDriver;
  final List<Contribution> contributions;
  final double combinedScore;
  final double threshold;

  factory Explanation.fromJson(Json j) => Explanation(
    interventionId: str(j['intervention_id']) ?? '',
    detail: enumFromWire(ExplainDetail.values, j['detail'], ExplainDetail.short),
    headline: str(j['headline']) ?? '',
    primaryDriver: str(j['primary_driver']) ?? '',
    contributions: asJsonList(j['contributions']).map(Contribution.fromJson).toList(),
    combinedScore: dblOrNull(j['combined_score']) ?? 0,
    threshold: dblOrNull(j['threshold']) ?? 1,
  );
}

enum InterventionResponse implements WireEnum {
  accepted('accepted'),
  snoozed('snoozed'),
  dismissed('dismissed');

  const InterventionResponse(this.wire);
  @override
  final String wire;
}

enum OverrideReason implements WireEnum {
  incident('incident', 'Production incident'),
  deploy('deploy', 'Deploy in progress'),
  pairing('pairing', 'Pairing / in a call'),
  other('other', 'Other');

  const OverrideReason(this.wire, this.label);
  @override
  final String wire;
  final String label;
}

/// Not enumerated in the team doc; proposed in CONTRACT_NOTES.md.
enum ReportReason implements WireEnum {
  wrongTime('wrong_time', 'Bad timing'),
  inMeeting('in_meeting', 'I was in a meeting'),
  tooFrequent('too_frequent', 'Too frequent'),
  notNeeded('not_needed', "I didn't need a break"),
  other('other', 'Other');

  const ReportReason(this.wire, this.label);
  @override
  final String wire;
  final String label;
}
