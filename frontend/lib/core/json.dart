/// Small, strict JSON helpers. Backend payloads are untrusted input: every
/// reader tolerates a missing field and never throws on a wrong type unless
/// the field is required.
library;

typedef Json = Map<String, dynamic>;

Json asJson(Object? v) => v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};

List<Json> asJsonList(Object? v) => v is List ? v.whereType<Map<dynamic, dynamic>>().map(asJson).toList() : <Json>[];

String? str(Object? v) => v?.toString();

String reqStr(Json j, String key) {
  final v = j[key];
  if (v == null) throw FormatException('Missing required field "$key"');
  return v.toString();
}

int? intOrNull(Object? v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

double? dblOrNull(Object? v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);

bool boolOr(Object? v, bool fallback) => v is bool ? v : fallback;

DateTime? dateOrNull(Object? v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

List<String> strList(Object? v) => v is List ? v.map((e) => e.toString()).toList() : <String>[];

List<int> intList(Object? v) => v is List ? v.map(intOrNull).whereType<int>().toList() : <int>[];

/// Enums that travel over the wire implement this so (de)serialisation is
/// explicit and renaming a Dart identifier never changes the API.
abstract interface class WireEnum {
  String get wire;
}

T enumFromWire<T extends WireEnum>(List<T> values, Object? raw, T fallback) {
  final s = raw?.toString();
  for (final v in values) {
    if (v.wire == s) return v;
  }
  return fallback;
}

T? enumFromWireOrNull<T extends WireEnum>(List<T> values, Object? raw) {
  final s = raw?.toString();
  for (final v in values) {
    if (v.wire == s) return v;
  }
  return null;
}
