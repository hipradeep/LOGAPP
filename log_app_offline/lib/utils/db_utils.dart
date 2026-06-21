import 'dart:convert';

/// Shared SQLite encode/decode helpers.
/// Used by ALL SQLite-backed services — never duplicate these patterns.
class DbUtils {
  DbUtils._();

  // ─── List Encoding ───────────────────────────────────────────────────────

  static String encodeIntList(List<int> list) => jsonEncode(list);

  static List<int> decodeIntList(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      return (jsonDecode(json) as List).cast<int>();
    } catch (_) {
      return [];
    }
  }

  static String encodeStringList(List<String> list) => jsonEncode(list);

  static List<String> decodeStringList(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      return (jsonDecode(json) as List).cast<String>();
    } catch (_) {
      return [];
    }
  }

  // ─── DateTime <-> int (millisecondsSinceEpoch) ───────────────────────────

  static int dateToMs(DateTime dt) => dt.millisecondsSinceEpoch;

  static DateTime msToDate(int? ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms ?? 0);

  static DateTime? msToDateNullable(int? ms) =>
      ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);

  // ─── Map helpers ─────────────────────────────────────────────────────────

  /// Safely encode a Map to a JSON string for blob columns.
  static String encodeMap(Map<String, dynamic> map) => jsonEncode(map);

  /// Safely decode a JSON blob string back to a Map.
  static Map<String, dynamic> decodeMap(String? json) {
    if (json == null || json.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(json) as Map);
    } catch (_) {
      return {};
    }
  }
}
