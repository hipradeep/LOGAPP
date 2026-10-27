import 'dart:convert';

double? asDoubleOrNull(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

double asDouble(Object? value, [double fallback = 0]) =>
    asDoubleOrNull(value) ?? fallback;

int? asIntOrNull(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

int asInt(Object? value, [int fallback = 0]) => asIntOrNull(value) ?? fallback;

bool asBool(Object? value, [bool fallback = false]) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value.toString().toLowerCase();
  return normalized == 'true' || normalized == '1';
}

DateTime? dateFromValue(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return DateTime.tryParse(value.toString());
}

int? epochFromDate(DateTime? value) => value?.millisecondsSinceEpoch;

String stringValue(Object? value, [String fallback = '']) =>
    value?.toString() ?? fallback;

String? nullableString(Object? value) {
  if (value == null) return null;
  final text = value.toString();
  return text.isEmpty ? null : text;
}

List<int> intListFromValue(Object? value) {
  if (value is List) {
    return value.map(asInt).toList();
  }
  if (value is String && value.isNotEmpty) {
    final decoded = jsonDecode(value);
    if (decoded is List) return decoded.map(asInt).toList();
  }
  return const [];
}

Map<String, dynamic> mapFromValue(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String && value.isNotEmpty) {
    final decoded = jsonDecode(value);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  }
  return const {};
}
