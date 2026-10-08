import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';
import '../controllers/courses_controller.dart';
import '../controllers/ongoing_modules_controller.dart';
import '../controllers/progress_controller.dart';
import '../controllers/revision_controller.dart';
import 'database_service.dart';
import 'service_locator.dart';

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
      withData: true,
    );

    if (result == null || result.files.isEmpty) return false;

    final file = result.files.single;
    String content;
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      content = utf8.decode(file.bytes!);
    } else if (file.path != null) {
      content = await File(file.path!).readAsString();
    } else {
      return false;
    }

    String cleaned = content.trim();
    if (cleaned.startsWith('\uFEFF')) {
      cleaned = cleaned.substring(1).trim();
    }

    final decoded = jsonDecode(cleaned);
    if (decoded is! Map<String, dynamic> || !decoded.containsKey('courses')) {
      throw const FormatException('Invalid backup file format: Missing database tables');
    }

    await importAllFromJson(decoded);
    return true;
  }

  /// Restores the complete SQLite database state from a backup map,
  /// replacing current data transactionally and refreshing all reactive streams.
  Future<void> importAllFromJson(Map<String, dynamic> data) async {
    final db = await _dbService.database;
    final nowIso = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.delete('courses');
      await txn.delete('modules');
      await txn.delete('topics');
      await txn.delete('revisions');
      await txn.delete('revision_topics');
      await txn.delete('study_logs');
      await txn.delete('user_profile');
      await txn.delete('notification_settings');

      // 1. Courses
      if (data['courses'] is List) {
        for (final row in (data['courses'] as List)) {
          if (row is Map) {
            final raw = Map<String, dynamic>.from(row);
            final title = (raw['title'] ?? raw['courseTitle'] ?? raw['courseName'] ?? raw['name'] ?? 'Untitled Course').toString();
            final courseMap = <String, dynamic>{
              'id': (raw['id'] ?? 'course_${DateTime.now().millisecondsSinceEpoch}').toString(),
              'title': title,
              'description': (raw['description'] ?? raw['desc'] ?? '').toString(),
              'status': (raw['status'] ?? 'active').toString(),
              'deadline': raw['deadline']?.toString(),
              'iconCodePoint': (raw['iconCodePoint'] as num?)?.toInt(),
              'colorValue': (raw['colorValue'] as num?)?.toInt(),
              'createdAt': (raw['createdAt'] ?? nowIso).toString(),
              'updatedAt': (raw['updatedAt'] ?? nowIso).toString(),
            };
            await txn.insert('courses', courseMap,
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }

      // 2. Modules
      if (data['modules'] is List) {
        int mIdx = 0;
        for (final row in (data['modules'] as List)) {
          if (row is Map) {
            final raw = Map<String, dynamic>.from(row);
            final title = (raw['title'] ?? raw['name'] ?? raw['moduleTitle'] ?? 'Untitled Module').toString();
            final moduleMap = <String, dynamic>{
              'id': (raw['id'] ?? 'module_${DateTime.now().millisecondsSinceEpoch}_$mIdx').toString(),
              'courseId': (raw['courseId'] ?? '').toString(),
              'title': title,
              'description': (raw['description'] ?? raw['desc'] ?? '').toString(),
              'orderIndex': (raw['orderIndex'] as num?)?.toInt() ?? mIdx,
              'status': (raw['status'] ?? 'active').toString(),
              'createdAt': (raw['createdAt'] ?? nowIso).toString(),
              'updatedAt': (raw['updatedAt'] ?? nowIso).toString(),
            };
            await txn.insert('modules', moduleMap,
                conflictAlgorithm: ConflictAlgorithm.replace);
            mIdx++;
          }
        }
      }

      // 3. Topics
      if (data['topics'] is List) {
        int tIdx = 0;
        for (final row in (data['topics'] as List)) {
          if (row is Map) {
            final raw = Map<String, dynamic>.from(row);
            final title = (raw['title'] ?? raw['name'] ?? raw['topicTitle'] ?? 'Untitled Topic').toString();
            final topicMap = <String, dynamic>{
              'id': (raw['id'] ?? 'topic_${DateTime.now().millisecondsSinceEpoch}_$tIdx').toString(),
              'courseId': (raw['courseId'] ?? '').toString(),
              'moduleId': (raw['moduleId'] ?? '').toString(),
              'title': title,
              'status': (raw['status'] ?? 'notStarted').toString(),
              'description': (raw['description'] ?? raw['desc'] ?? '').toString(),
              'orderIndex': (raw['orderIndex'] as num?)?.toInt() ?? tIdx,
              'iconCodePoint': (raw['iconCodePoint'] as num?)?.toInt(),
              'colorValue': (raw['colorValue'] as num?)?.toInt(),
              'completedAt': raw['completedAt']?.toString(),
            };
            await txn.insert('topics', topicMap,
                conflictAlgorithm: ConflictAlgorithm.replace);
            tIdx++;
          }
        }
      }

      // 4. Revisions
      if (data['revisions'] is List) {
        for (final row in (data['revisions'] as List)) {
          if (row is Map) {
            final raw = Map<String, dynamic>.from(row);
            final revMap = <String, dynamic>{
              'id': raw['id'].toString(),
              'courseId': (raw['courseId'] ?? '').toString(),
              'moduleId': (raw['moduleId'] ?? '').toString(),
              'currentLevel': (raw['currentLevel'] as num?)?.toInt() ?? 1,
              'status': (raw['status'] ?? 'active').toString(),
              'nextRevisionAt': (raw['nextRevisionAt'] ?? nowIso).toString(),
              'completedAt': raw['completedAt']?.toString(),
              'createdAt': (raw['createdAt'] ?? nowIso).toString(),
              'updatedAt': (raw['updatedAt'] ?? nowIso).toString(),
            };
            await txn.insert('revisions', revMap,
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }

      // 5. Revision Topics
      if (data['revisionTopics'] is List) {
        int rtIdx = 0;
        for (final row in (data['revisionTopics'] as List)) {
          if (row is Map) {
            final raw = Map<String, dynamic>.from(row);
            final revTopicMap = <String, dynamic>{
              'id': (raw['id'] ?? 'rev_topic_$rtIdx').toString(),
              'revisionId': (raw['revisionId'] ?? '').toString(),
              'courseId': (raw['courseId'] ?? '').toString(),
              'topicId': (raw['topicId'] ?? '').toString(),
              'title': (raw['title'] ?? '').toString(),
              'status': (raw['status'] ?? 'notStarted').toString(),
              'orderIndex': (raw['orderIndex'] as num?)?.toInt() ?? rtIdx,
              'completedAt': raw['completedAt']?.toString(),
              'createdAt': (raw['createdAt'] ?? nowIso).toString(),
              'updatedAt': (raw['updatedAt'] ?? nowIso).toString(),
            };
            await txn.insert('revision_topics', revTopicMap,
                conflictAlgorithm: ConflictAlgorithm.replace);
            rtIdx++;
          }
        }
      }

      // 6. Study Logs
      if (data['studyLogs'] is List) {
        for (final row in (data['studyLogs'] as List)) {
          if (row is Map) {
            final raw = Map<String, dynamic>.from(row);
            final logMap = <String, dynamic>{
              'id': raw['id'].toString(),
              'type': (raw['type'] ?? 'sessionCompleted').toString(),
              'courseId': (raw['courseId'] ?? '').toString(),
              'courseTitle': (raw['courseTitle'] ?? '').toString(),
              'moduleId': (raw['moduleId'] ?? '').toString(),
              'moduleTitle': (raw['moduleTitle'] ?? '').toString(),
              'topicId': raw['topicId']?.toString(),
              'topicTitle': raw['topicTitle']?.toString(),
              'revisionLevel': (raw['revisionLevel'] as num?)?.toInt(),
              'durationMinutes': (raw['durationMinutes'] as num?)?.toInt(),
              'timestamp': (raw['timestamp'] ?? nowIso).toString(),
              'createdAt': (raw['createdAt'] ?? nowIso).toString(),
            };
            await txn.insert('study_logs', logMap,
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }

      // 7. User Profile
      if (data['userProfile'] is Map) {
        final raw = Map<String, dynamic>.from(data['userProfile'] as Map);
        final profileMap = <String, dynamic>{
          'id': (raw['id'] ?? 'user_profile').toString(),
          'name': (raw['name'] ?? 'Scholar').toString(),
          'headline': (raw['headline'] ?? '').toString(),
          'email': raw['email']?.toString(),
          'avatarUrl': raw['avatarUrl']?.toString(),
          'currentStreak': (raw['currentStreak'] as num?)?.toInt() ?? 0,
          'longestStreak': (raw['longestStreak'] as num?)?.toInt() ?? 0,
          'totalActiveDays': (raw['totalActiveDays'] as num?)?.toInt() ?? 0,
          'totalStudyMinutes': (raw['totalStudyMinutes'] as num?)?.toInt() ?? 0,
          'totalTopicsFinished': (raw['totalTopicsFinished'] as num?)?.toInt() ?? 0,
          'totalTopicRevisions': (raw['totalTopicRevisions'] as num?)?.toInt() ?? 0,
          'lastActiveDate': raw['lastActiveDate']?.toString(),
          'createdAt': (raw['createdAt'] ?? nowIso).toString(),
          'updatedAt': (raw['updatedAt'] ?? nowIso).toString(),
        };
        await txn.insert('user_profile', profileMap,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // 8. Notification Settings
      if (data['notificationSettings'] is List) {
        for (final row in (data['notificationSettings'] as List)) {
          if (row is Map) {
            final raw = Map<String, dynamic>.from(row);
            final notifMap = <String, dynamic>{
              'id': raw['id'].toString(),
              'data': (raw['data'] ?? '').toString(),
            };
            await txn.insert('notification_settings', notifMap,
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }
    });

    // Notify all active broadcast streams with freshly restored data
    await _dbService.reloadAllStreams();

    // Immediately refresh all registered UI controllers
    if (getIt.isRegistered<CoursesController>()) {
      await getIt<CoursesController>().loadCourses();
    }
    if (getIt.isRegistered<OngoingModulesController>()) {
      await getIt<OngoingModulesController>().refresh();
    }
    if (getIt.isRegistered<RevisionController>()) {
      await getIt<RevisionController>().reconcile();
    }
    if (getIt.isRegistered<ProgressController>()) {
      await getIt<ProgressController>().load();
    }
  }
}


