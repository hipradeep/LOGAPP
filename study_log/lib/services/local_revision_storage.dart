import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/revision.dart';

/// Local disk cache for Revision entities to guarantee persistent offline availability.
class LocalRevisionStorage {
  static const String _fileName = 'study_revisions_cache.json';

  static Future<File?> _getFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/$_fileName');
    } catch (e) {
      debugPrint('LocalRevisionStorage getFile error: $e');
      return null;
    }
  }

  static Future<List<Revision>> loadAll() async {
    try {
      final file = await _getFile();
      if (file == null || !await file.exists()) {
        return [];
      }
      final jsonString = await file.readAsString();
      if (jsonString.trim().isEmpty) return [];

      final List<dynamic> jsonList = jsonDecode(jsonString);
      final List<Revision> revisions = [];
      for (final item in jsonList) {
        if (item is Map) {
          try {
            revisions.add(Revision.fromMap(Map<String, dynamic>.from(item)));
          } catch (e) {
            debugPrint('Error parsing cached revision: $e');
          }
        }
      }
      return revisions;
    } catch (e) {
      debugPrint('Error loading cached revisions: $e');
      return [];
    }
  }

  static Future<void> saveAll(List<Revision> revisions) async {
    try {
      final file = await _getFile();
      if (file == null) return;
      await file.writeAsString(
        jsonEncode(revisions.map((r) => r.toMap(forLocalJson: true)).toList()),
        flush: true,
      );
    } catch (e) {
      debugPrint('Error saving cached revisions: $e');
    }
  }

  /// Clears all locally cached revisions from disk.
  static Future<void> clearAll() async {
    try {
      final file = await _getFile();
      if (file != null && await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error clearing revisions cache: $e');
    }
  }
}
