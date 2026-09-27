import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/subsection_item.dart';

/// Local disk cache for Subsection entities to guarantee persistent offline availability.
class LocalSubsectionStorage {
  static const String _fileName = 'study_subsections_cache.json';

  static Future<File?> _getFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/$_fileName');
    } catch (e) {
      debugPrint('LocalSubsectionStorage getFile error: $e');
      return null;
    }
  }

  /// Loads cached subsections for a specific section title or section key.
  static Future<List<SubsectionItem>> loadSubsections(String sectionKey) async {
    try {
      final file = await _getFile();
      if (file == null || !await file.exists()) {
        return [];
      }
      final jsonString = await file.readAsString();
      if (jsonString.trim().isEmpty) return [];

      final Map<String, dynamic> data = jsonDecode(jsonString);
      final List<dynamic>? rawList = data[sectionKey] as List<dynamic>?;
      if (rawList == null || rawList.isEmpty) return [];

      return rawList
          .map((item) => SubsectionItem.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      debugPrint('Error loading cached subsections: $e');
      return [];
    }
  }

  /// Reads every bucket from disk in a single pass.
  static Future<Map<String, List<SubsectionItem>>> loadAllBuckets() async {
    try {
      final file = await _getFile();
      if (file == null || !await file.exists()) {
        return {};
      }
      final jsonString = await file.readAsString();
      if (jsonString.trim().isEmpty) return {};

      final decoded = jsonDecode(jsonString);
      if (decoded is! Map) return {};

      final buckets = <String, List<SubsectionItem>>{};
      decoded.forEach((key, value) {
        if (value is! List) return;
        final items = <SubsectionItem>[];
        for (final entry in value) {
          if (entry is Map) {
            try {
              items.add(SubsectionItem.fromMap(Map<String, dynamic>.from(entry)));
            } catch (e) {
              debugPrint('Error parsing cached subsection: $e');
            }
          }
        }
        buckets[key.toString()] = items;
      });
      return buckets;
    } catch (e) {
      debugPrint('Error loading cached subsection buckets: $e');
      return {};
    }
  }

  /// Loads the topics belonging to a specific Section.
  ///
  /// Prefers records tagged with [sectionId], which stays correct when a
  /// module is renamed or two modules share a title. Falls back to the bucket
  /// keyed by [fallbackTitle] for records written before ids were stored.
  static Future<List<SubsectionItem>> loadSubsectionsForSection({
    required String sectionId,
    String? fallbackTitle,
  }) async {
    if (sectionId.isEmpty) {
      return fallbackTitle == null
          ? <SubsectionItem>[]
          : loadSubsections(fallbackTitle);
    }
    return resolveForSection(
      await loadAllBuckets(),
      sectionId: sectionId,
      fallbackTitle: fallbackTitle,
    );
  }

  /// Synchronous variant of [loadSubsectionsForSection] for callers that
  /// already hold the buckets and must not re-read the file per section.
  static List<SubsectionItem> resolveForSection(
    Map<String, List<SubsectionItem>> buckets, {
    required String sectionId,
    String? fallbackTitle,
  }) {
    if (sectionId.isEmpty) {
      return fallbackTitle == null ? <SubsectionItem>[] : buckets[fallbackTitle] ?? <SubsectionItem>[];
    }

    final byId = <SubsectionItem>[];
    for (final items in buckets.values) {
      for (final item in items) {
        if (item.sectionId == sectionId) byId.add(item);
      }
    }
    if (byId.isNotEmpty) return byId;
    if (fallbackTitle != null) {
      return buckets[fallbackTitle] ?? <SubsectionItem>[];
    }
    return <SubsectionItem>[];
  }

  /// Saves subsections for a specific sectionKey to local disk.
  static Future<void> saveSubsections(
    String sectionKey,
    List<SubsectionItem> items,
  ) async {
    try {
      final file = await _getFile();
      if (file == null) return;

      Map<String, dynamic> data = {};
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          try {
            data = Map<String, dynamic>.from(jsonDecode(content) as Map);
          } catch (_) {
            data = {};
          }
        }
      }

      data[sectionKey] = items.map((i) => i.toMap()).toList();

      // Buckets are keyed by section title, so a renamed module would leave the
      // previous title's bucket behind holding the same records. Drop any bucket
      // that duplicates the section id we just wrote, otherwise id-based reads
      // would count those topics twice.
      if (items.isNotEmpty && items.first.sectionId.isNotEmpty) {
        final sectionId = items.first.sectionId;
        data.removeWhere((key, value) {
          if (key == sectionKey || value is! List) return false;
          for (final entry in value) {
            if (entry is Map && entry['sectionId'] == sectionId) return true;
          }
          return false;
        });
      }

      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (e) {
      debugPrint('Error saving cached subsections: $e');
    }
  }

  /// Clears all locally cached subsections from disk.
  static Future<void> clearAll() async {
    try {
      final file = await _getFile();
      if (file != null && await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error clearing subsections cache: $e');
    }
  }
}
