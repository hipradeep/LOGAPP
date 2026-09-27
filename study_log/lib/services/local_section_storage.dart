import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/section.dart';

/// Local disk cache for Section entities to guarantee persistent offline availability.
class LocalSectionStorage {
  static const String _fileName = 'study_sections_cache.json';

  static Future<File?> _getFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/$_fileName');
    } catch (e) {
      debugPrint('LocalSectionStorage getFile error: $e');
      return null;
    }
  }

  /// Loads cached sections for a specific courseId.
  static Future<List<Section>> loadSections(String courseId) async {
    try {
      final file = await _getFile();
      if (file == null || !await file.exists()) {
        return [];
      }
      final jsonString = await file.readAsString();
      if (jsonString.trim().isEmpty) return [];

      final List<dynamic> jsonList = jsonDecode(jsonString);
      final List<Section> sections = [];
      for (final item in jsonList) {
        if (item is Map) {
          try {
            final section = Section.fromMap(Map<String, dynamic>.from(item));
            if (section.courseId == courseId) {
              sections.add(section);
            }
          } catch (e) {
            debugPrint('Error parsing cached section: $e');
          }
        }
      }
      sections.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      return sections;
    } catch (e) {
      debugPrint('Error loading cached sections: $e');
      return [];
    }
  }

  /// Saves or updates sections for a specific courseId while preserving others.
  static Future<void> saveSectionsForCourse(String courseId, List<Section> courseSections) async {
    try {
      final file = await _getFile();
      if (file == null) return;

      List<dynamic> allJson = [];
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          try {
            allJson = jsonDecode(content) as List<dynamic>;
          } catch (_) {
            allJson = [];
          }
        }
      }

      // Filter out existing sections for this courseId
      final remaining = allJson.where((item) {
        if (item is Map) {
          return item['courseId'] != courseId;
        }
        return false;
      }).toList();

      // Add new course sections
      remaining.addAll(courseSections.map((s) => s.toMap(forLocalJson: true)));

      await file.writeAsString(jsonEncode(remaining), flush: true);
    } catch (e) {
      debugPrint('Error saving cached sections: $e');
    }
  }
}
