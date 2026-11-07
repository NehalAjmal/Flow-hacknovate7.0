import '../../core/json.dart';

class FeatureFlags {
  const FeatureFlags(this.values);
  final Map<String, Object?> values;

  static const empty = FeatureFlags({});

  bool isOn(String flag) => values[flag] == true || values[flag] == 'on';
  String? variant(String flag) => values[flag] is String ? values[flag]! as String : null;

  factory FeatureFlags.fromJson(Json j) => FeatureFlags(asJson(j['flags']));
}

enum FeedbackKind implements WireEnum {
  feedback('feedback', 'General feedback'),
  bug('bug', 'Report a problem'),
  feature('feature', 'Feature request');

  const FeedbackKind(this.wire, this.label);
  @override
  final String wire;
  final String label;
}

class FeedbackRequest {
  const FeedbackRequest({required this.kind, required this.message, this.diagnostics});
  final FeedbackKind kind;
  final String message;

  /// Only attached when the user ticks "include diagnostics".
  final Json? diagnostics;

  Json toJson() => {'kind': kind.wire, 'message': message, if (diagnostics != null) 'diagnostics': diagnostics};
}

class ChangelogEntry {
  const ChangelogEntry({required this.version, required this.date, required this.items});
  final String version;
  final DateTime? date;
  final List<String> items;

  factory ChangelogEntry.fromJson(Json j) =>
      ChangelogEntry(version: str(j['version']) ?? '', date: dateOrNull(j['date']), items: strList(j['items']));
}
