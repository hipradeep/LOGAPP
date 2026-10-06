import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'database_service.dart';

/// Dedicated service handling full JSON export and import of the SQLite database
/// for Google Drive cloud sync, local backup files, and database restoration.
class DatabaseBackupService {
  final DatabaseService _dbService;

  DatabaseBackupService({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService.instance;

  /// Serializes the complete SQLite database state into a JSON-compatible map
  /// for Google Drive cloud backup or local JSON export.
  Future<Map<String, dynamic>> exportAllToJson() async {
    final db = await _dbService.database;

    final courses = await db.query('courses');
    final modules = await db.query('modules');
    final topics = await db.query('topics');
    final revisions = await db.query('revisions');
    final revisionTopics = await db.query('revision_topics');
    final studyLogs = await db.query('study_logs');
    final userProfile = await db.query('user_profile', limit: 1);
    final notificationSettings = await db.query('notification_settings');

    return {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'courses': courses,
      'modules': modules,
      'topics': topics,
      'revisions': revisions,
      'revisionTopics': revisionTopics,
      'studyLogs': studyLogs,
      'userProfile': userProfile.isNotEmpty ? userProfile.first : null,
      'notificationSettings': notificationSettings,
    };
  }

  /// Exports the entire database to a local `.json` file using FilePicker.
  /// Returns the destination path if saved, or null if cancelled.
  Future<String?> exportToFile() async {
    final data = await exportAllToJson();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final fileName = 'study_log_backup_$timestamp.json';

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Database Backup',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: utf8.encode(jsonStr),
    );

    if (savePath != null) {
      final file = File(savePath);
      if (!await file.exists() || (await file.length()) == 0) {
        await file.writeAsString(jsonStr);
      }
      return savePath;
    }
    return null;
  }

  /// Picks a local `.json` backup file and restores the entire database.
  /// Returns true if imported successfully, false if cancelled.
  Future<bool> importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return false;

    final path = result.files.single.path;
    String content;
    if (path != null) {
      content = await File(path).readAsString();
    } else if (result.files.single.bytes != null) {
      content = utf8.decode(result.files.single.bytes!);
    } else {
      return false;
    }

    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup file format');
    }

    await importAllFromJson(decoded);
    return true;
  }

  /// Restores the complete SQLite database state from a backup map,
  /// replacing current data transactionally and refreshing all reactive streams.
  Future<void> importAllFromJson(Map<String, dynamic> data) async {
    final db = await _dbService.database;

    await db.transaction((txn) async {
      await txn.delete('courses');
      await txn.delete('modules');
      await txn.delete('topics');
      await txn.delete('revisions');
      await txn.delete('revision_topics');
      await txn.delete('study_logs');
      await txn.delete('user_profile');
      await txn.delete('notification_settings');

      if (data['courses'] is List) {
        for (final row in (data['courses'] as List)) {
          if (row is Map) {
            await txn.insert('courses', Map<String, dynamic>.from(row),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }

      if (data['modules'] is List) {
        for (final row in (data['modules'] as List)) {
          if (row is Map) {
            await txn.insert('modules', Map<String, dynamic>.from(row),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }

      if (data['topics'] is List) {
        for (final row in (data['topics'] as List)) {
          if (row is Map) {
            await txn.insert('topics', Map<String, dynamic>.from(row),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }

      if (data['revisions'] is List) {
        for (final row in (data['revisions'] as List)) {
          if (row is Map) {
            await txn.insert('revisions', Map<String, dynamic>.from(row),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }

      if (data['revisionTopics'] is List) {
        for (final row in (data['revisionTopics'] as List)) {
          if (row is Map) {
            await txn.insert('revision_topics', Map<String, dynamic>.from(row),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }

      if (data['studyLogs'] is List) {
        for (final row in (data['studyLogs'] as List)) {
          if (row is Map) {
            await txn.insert('study_logs', Map<String, dynamic>.from(row),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }

      if (data['userProfile'] is Map) {
        await txn.insert('user_profile', Map<String, dynamic>.from(data['userProfile']),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }

      if (data['notificationSettings'] is List) {
        for (final row in (data['notificationSettings'] as List)) {
          if (row is Map) {
            await txn.insert('notification_settings', Map<String, dynamic>.from(row),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }
    });

    // Notify all active broadcast streams with freshly restored data
    await _dbService.reloadAllStreams();
  }
}

