import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../screens/section_detail_screen.dart';

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
