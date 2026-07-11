/// Small, defensive JSON codec helpers shared by all entity models.
///
/// Dates are serialized as UTC epoch milliseconds (ints): they are compact,
/// locale-free, and sort correctly in Firestore range queries. [dateFromJson]
/// is deliberately tolerant of legacy ISO-8601 strings so older locally-saved
/// payloads keep loading after the backend migration.
library;

DateTime? dateFromJson(Object? value) {
  if (value == null) return null;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  if (value is String) return DateTime.tryParse(value)?.toUtc();
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
  }
  return null;
}

int dateToJson(DateTime value) => value.toUtc().millisecondsSinceEpoch;

/// Reads [key] as an int, accepting doubles (Firestore numbers can come back
/// as either) and falling back to [fallback] on absence or junk.
int intFromJson(Map<String, dynamic> json, String key, {int fallback = 0}) {
  final v = json[key];
  if (v is int) return v;
  if (v is num) return v.toInt();
  return fallback;
}

double? doubleFromJson(Map<String, dynamic> json, String key) {
  final v = json[key];
  if (v is num) return v.toDouble();
  return null;
}

String stringFromJson(Map<String, dynamic> json, String key, {String fallback = ''}) {
  final v = json[key];
  return v is String ? v : fallback;
}

bool boolFromJson(Map<String, dynamic> json, String key, {bool fallback = false}) {
  final v = json[key];
  return v is bool ? v : fallback;
}

Map<String, int> intMapFromJson(Object? value) {
  if (value is! Map) return const {};
  return value.map((k, v) => MapEntry(k.toString(), v is num ? v.toInt() : 0));
}
