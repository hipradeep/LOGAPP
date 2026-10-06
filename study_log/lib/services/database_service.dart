import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/course.dart';
import '../models/module.dart';
import '../models/topic.dart';
import '../models/revision_module.dart';
import '../models/revision_topic.dart';
import '../models/study_log.dart';
import '../models/user_profile.dart';
import '../models/notification_settings.dart';

/// Central SQLite Database Service for the Study app.
///
/// Provides fast, ACID-compliant local storage, foreign key cascading,
/// automatic schema creation, seamless legacy JSON cache migration,
/// and reactive broadcast Streams for real-time UI updates.
class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  Database? _db;

  /// Always true since this is a local, on-device SQLite database.
  bool get isAvailable => true;

  // ─────────────────────────────────────────────────────────────────────────
  // Reactive Stream Controllers
  // ─────────────────────────────────────────────────────────────────────────

  final _coursesStreamController =
      StreamController<List<Course>>.broadcast();
  final _modulesStreamControllers =
      <String, StreamController<List<Module>>>{};
  final _topicsStreamControllers =
      <String, StreamController<List<Topic>>>{};
  final _revisionsStreamController =
      StreamController<List<RevisionModule>>.broadcast();
  final _revisionTopicsStreamControllers =
      <String, StreamController<List<RevisionTopic>>>{};
  final _studyLogsStreamController =
      StreamController<List<StudyLog>>.broadcast();

  StreamController<List<Module>> _getModuleController(String courseId) {
    return _modulesStreamControllers.putIfAbsent(
      courseId,
      () => StreamController<List<Module>>.broadcast(),
    );
  }

  StreamController<List<Topic>> _getTopicController(String moduleId) {
    return _topicsStreamControllers.putIfAbsent(
      moduleId,
      () => StreamController<List<Topic>>.broadcast(),
    );
  }

  StreamController<List<RevisionTopic>> _getRevisionTopicController(
      String revisionId) {
    return _revisionTopicsStreamControllers.putIfAbsent(
      revisionId,
      () => StreamController<List<RevisionTopic>>.broadcast(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Initialization & Database Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns the open [Database], initializing if needed.
  Future<Database> get database async {
    _db ??= await _openDatabase();
    return _db!;
  }

  /// Explicit initialization hook (e.g. called from `main()` or warmup).
  Future<void> init() async {
    await database;
  }

  Future<Database> _openDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'study_log.db');

    return await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: _onCreate,
      onOpen: (db) async {
        await db.rawQuery('PRAGMA journal_mode=WAL;');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // 1. Courses Table
    batch.execute('''
      CREATE TABLE courses (
        id            TEXT PRIMARY KEY,
        title         TEXT NOT NULL,
        description   TEXT NOT NULL DEFAULT '',
        status        TEXT NOT NULL DEFAULT 'active',
        deadline      TEXT,
        iconCodePoint INTEGER,
        colorValue    INTEGER,
        createdAt     TEXT NOT NULL,
        updatedAt     TEXT NOT NULL
      );
    ''');

    // 2. Modules Table
    batch.execute('''
      CREATE TABLE modules (
        id          TEXT PRIMARY KEY,
        courseId    TEXT NOT NULL,
        title       TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        orderIndex  INTEGER NOT NULL DEFAULT 0,
        status      TEXT NOT NULL DEFAULT 'active',
        createdAt   TEXT NOT NULL,
        updatedAt   TEXT NOT NULL,
        FOREIGN KEY (courseId) REFERENCES courses(id) ON DELETE CASCADE
      );
    ''');

    // 3. Topics Table
    batch.execute('''
      CREATE TABLE topics (
        id            TEXT PRIMARY KEY,
        courseId      TEXT NOT NULL,
        moduleId      TEXT NOT NULL,
        title         TEXT NOT NULL,
        status        TEXT NOT NULL DEFAULT 'notStarted',
        description   TEXT NOT NULL DEFAULT '',
        orderIndex    INTEGER NOT NULL DEFAULT 0,
        iconCodePoint INTEGER,
        colorValue    INTEGER,
        completedAt   TEXT,
        FOREIGN KEY (moduleId) REFERENCES modules(id) ON DELETE CASCADE
      );
    ''');

    // 4. Revisions Table
    batch.execute('''
      CREATE TABLE revisions (
        id             TEXT PRIMARY KEY,
        courseId       TEXT NOT NULL,
        moduleId       TEXT NOT NULL,
        currentLevel   INTEGER NOT NULL DEFAULT 1,
        status         TEXT NOT NULL DEFAULT 'active',
        nextRevisionAt TEXT NOT NULL,
        completedAt    TEXT,
        createdAt      TEXT NOT NULL,
        updatedAt      TEXT NOT NULL,
        FOREIGN KEY (moduleId) REFERENCES modules(id) ON DELETE CASCADE
      );
    ''');

    // 5. Revision Topics Table
    batch.execute('''
      CREATE TABLE revision_topics (
        id          TEXT PRIMARY KEY,
        revisionId  TEXT NOT NULL,
        courseId    TEXT NOT NULL,
        topicId     TEXT NOT NULL,
        title       TEXT NOT NULL DEFAULT '',
        status      TEXT NOT NULL DEFAULT 'notStarted',
        orderIndex  INTEGER NOT NULL DEFAULT 0,
        completedAt TEXT,
        createdAt   TEXT NOT NULL,
        updatedAt   TEXT NOT NULL,
        FOREIGN KEY (revisionId) REFERENCES revisions(id) ON DELETE CASCADE
      );
    ''');

    // 6. Study Logs Table
    batch.execute('''
      CREATE TABLE study_logs (
        id              TEXT PRIMARY KEY,
        type            TEXT NOT NULL,
        courseId        TEXT NOT NULL,
        courseTitle     TEXT NOT NULL,
        moduleId        TEXT NOT NULL,
        moduleTitle     TEXT NOT NULL,
        topicId         TEXT,
        topicTitle      TEXT,
        revisionLevel   INTEGER,
        durationMinutes INTEGER,
        timestamp       TEXT NOT NULL,
        createdAt       TEXT NOT NULL
      );
    ''');

    // 7. User Profile Table
    batch.execute('''
      CREATE TABLE user_profile (
        id                  TEXT PRIMARY KEY,
        name                TEXT NOT NULL,
        headline            TEXT NOT NULL DEFAULT '',
        email               TEXT,
        avatarUrl           TEXT,
        currentStreak       INTEGER NOT NULL DEFAULT 0,
        longestStreak       INTEGER NOT NULL DEFAULT 0,
        totalActiveDays     INTEGER NOT NULL DEFAULT 0,
        totalStudyMinutes   INTEGER NOT NULL DEFAULT 0,
        totalTopicsFinished INTEGER NOT NULL DEFAULT 0,
        totalTopicRevisions INTEGER NOT NULL DEFAULT 0,
        lastActiveDate      TEXT,
        createdAt           TEXT NOT NULL,
        updatedAt           TEXT NOT NULL
      );
    ''');

    // 8. Notification Settings Table
    batch.execute('''
      CREATE TABLE notification_settings (
        id   TEXT PRIMARY KEY,
        data TEXT NOT NULL
      );
    ''');

    // Indexes for fast querying
    batch.execute('CREATE INDEX idx_modules_courseId ON modules(courseId);');
    batch.execute('CREATE INDEX idx_topics_moduleId ON topics(moduleId);');
    batch.execute('CREATE INDEX idx_topics_courseId ON topics(courseId);');
    batch.execute('CREATE INDEX idx_revisions_courseId ON revisions(courseId);');
    batch.execute('CREATE INDEX idx_revisions_moduleId ON revisions(moduleId);');
    batch.execute('CREATE INDEX idx_revision_topics_revisionId ON revision_topics(revisionId);');
    batch.execute('CREATE INDEX idx_study_logs_timestamp ON study_logs(timestamp);');

    await batch.commit(noResult: true);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Data Reset & Maintenance
  // ─────────────────────────────────────────────────────────────────────────

  /// Clears all stored data from tables and resets broadcast streams.
  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('courses');
      await txn.delete('modules');
      await txn.delete('topics');
      await txn.delete('revisions');
      await txn.delete('revision_topics');
      await txn.delete('study_logs');
      await txn.delete('user_profile');
      await txn.delete('notification_settings');
    });

    _coursesStreamController.add([]);
    _revisionsStreamController.add([]);
    _studyLogsStreamController.add([]);
    for (final c in _modulesStreamControllers.values) {
      c.add([]);
    }
    for (final c in _topicsStreamControllers.values) {
      c.add([]);
    }
    for (final c in _revisionTopicsStreamControllers.values) {
      c.add([]);
    }
  }

  /// Completely deletes and recreates the SQLite database file from scratch.
  Future<void> resetDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'study_log.db');
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
    await deleteDatabase(path);
    await database;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Course Operations
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<Course>> getCourses() async {
    final db = await database;
    final maps = await db.query(
      'courses',
      orderBy: 'createdAt DESC',
    );
    return maps.map((m) => Course.fromMap(m)).toList();
  }

  Stream<List<Course>> streamCourses() async* {
    yield await getCourses();
    yield* _coursesStreamController.stream;
  }

  Future<Course?> getCourseById(String id) async {
    if (id.isEmpty) return null;
    final db = await database;
    final maps = await db.query(
      'courses',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Course.fromMap(maps.first);
  }

  Future<void> addCourse(Course course) async {
    final db = await database;
    await db.insert(
      'courses',
      course.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _coursesStreamController.add(await getCourses());
  }

  Future<void> updateCourse(Course course) async {
    final db = await database;
    await db.update(
      'courses',
      course.toMap(),
      where: 'id = ?',
      whereArgs: [course.id],
    );
    _coursesStreamController.add(await getCourses());
  }

  Future<void> deleteCourse(String id) async {
    final db = await database;
    await db.delete(
      'courses',
      where: 'id = ?',
      whereArgs: [id],
    );
    _coursesStreamController.add(await getCourses());
  }

  Future<void> saveCourses(List<Course> courses) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final course in courses) {
        await txn.insert(
          'courses',
          course.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    _coursesStreamController.add(await getCourses());
  }

  Future<void> clearCourses() async {
    final db = await database;
    await db.delete('courses');
    _coursesStreamController.add([]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Module Operations
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<Module>> getModules({required String courseId}) async {
    final db = await database;
    final maps = await db.query(
      'modules',
      where: 'courseId = ?',
      whereArgs: [courseId],
      orderBy: 'orderIndex ASC',
    );
    return maps.map((m) => Module.fromMap(m)).toList();
  }

  Stream<List<Module>> streamModules({required String courseId}) async* {
    yield await getModules(courseId: courseId);
    yield* _getModuleController(courseId).stream;
  }

  Future<void> addModule(Module module) async {
    final db = await database;
    await db.insert(
      'modules',
      module.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _getModuleController(module.courseId)
        .add(await getModules(courseId: module.courseId));
  }

  Future<void> updateModule(Module module) async {
    final db = await database;
    await db.update(
      'modules',
      module.toMap(),
      where: 'id = ?',
      whereArgs: [module.id],
    );
    _getModuleController(module.courseId)
        .add(await getModules(courseId: module.courseId));
  }

  Future<void> deleteModule(String id) async {
    final db = await database;
    final existing = await db.query(
      'modules',
      columns: ['courseId'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    final courseId = existing.isNotEmpty ? existing.first['courseId'] as String : null;

    await db.delete(
      'modules',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (courseId != null) {
      _getModuleController(courseId).add(await getModules(courseId: courseId));
    }
  }

  Future<void> saveModules(String courseId, List<Module> modules) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('modules', where: 'courseId = ?', whereArgs: [courseId]);
      for (final m in modules) {
        await txn.insert(
          'modules',
          m.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    _getModuleController(courseId).add(await getModules(courseId: courseId));
  }

  Future<void> clearModules() async {
    final db = await database;
    await db.delete('modules');
    for (final controller in _modulesStreamControllers.values) {
      controller.add([]);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Topic Operations
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<Topic>> getTopics({required String moduleId}) async {
    final db = await database;
    final maps = await db.query(
      'topics',
      where: 'moduleId = ?',
      whereArgs: [moduleId],
      orderBy: 'orderIndex ASC',
    );
    return maps.map((m) => Topic.fromMap(m)).toList();
  }

  Stream<List<Topic>> streamTopics({required String moduleId}) async* {
    yield await getTopics(moduleId: moduleId);
    yield* _getTopicController(moduleId).stream;
  }

  Future<List<Topic>> getTopicsForCourse({required String courseId}) async {
    final db = await database;
    final maps = await db.query(
      'topics',
      where: 'courseId = ?',
      whereArgs: [courseId],
      orderBy: 'orderIndex ASC',
    );
    return maps.map((m) => Topic.fromMap(m)).toList();
  }

  Future<List<Topic>> getAllTopics() async {
    final db = await database;
    final maps = await db.query('topics', orderBy: 'orderIndex ASC');
    return maps.map((m) => Topic.fromMap(m)).toList();
  }

  Future<void> addTopic(Topic topic) async {
    final db = await database;
    await db.insert(
      'topics',
      topic.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _getTopicController(topic.moduleId)
        .add(await getTopics(moduleId: topic.moduleId));
  }

  Future<void> updateTopic(Topic topic) async {
    final db = await database;
    await db.update(
      'topics',
      topic.toMap(),
      where: 'id = ?',
      whereArgs: [topic.id],
    );
    _getTopicController(topic.moduleId)
        .add(await getTopics(moduleId: topic.moduleId));
  }

  Future<void> deleteTopic(String id) async {
    final db = await database;
    final existing = await db.query(
      'topics',
      columns: ['moduleId'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    final moduleId =
        existing.isNotEmpty ? existing.first['moduleId'] as String : null;

    await db.delete(
      'topics',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (moduleId != null) {
      _getTopicController(moduleId).add(await getTopics(moduleId: moduleId));
    }
  }

  Future<void> saveTopics(String moduleId, List<Topic> topics) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('topics', where: 'moduleId = ?', whereArgs: [moduleId]);
      for (final t in topics) {
        await txn.insert(
          'topics',
          t.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    _getTopicController(moduleId).add(await getTopics(moduleId: moduleId));
  }

  Future<void> clearTopics() async {
    final db = await database;
    await db.delete('topics');
    for (final controller in _topicsStreamControllers.values) {
      controller.add([]);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Revision Operations
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<RevisionModule>> getRevisions() async {
    final db = await database;
    final maps = await db.query(
      'revisions',
      orderBy: 'createdAt DESC',
    );
    return maps.map((m) => RevisionModule.fromMap(m)).toList();
  }

  Stream<List<RevisionModule>> streamRevisions() async* {
    yield await getRevisions();
    yield* _revisionsStreamController.stream;
  }

  Future<void> addRevision(RevisionModule revision) async {
    final db = await database;
    await db.insert(
      'revisions',
      revision.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _revisionsStreamController.add(await getRevisions());
  }

  Future<void> updateRevision(RevisionModule revision) async {
    final db = await database;
    await db.update(
      'revisions',
      revision.toMap(),
      where: 'id = ?',
      whereArgs: [revision.id],
    );
    _revisionsStreamController.add(await getRevisions());
  }

  Future<void> deleteRevision(String id) async {
    final db = await database;
    await db.delete(
      'revisions',
      where: 'id = ?',
      whereArgs: [id],
    );
    _revisionsStreamController.add(await getRevisions());
  }

  Future<void> saveRevisions(List<RevisionModule> revisions) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('revisions');
      for (final rev in revisions) {
        await txn.insert(
          'revisions',
          rev.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    _revisionsStreamController.add(await getRevisions());
  }

  Future<void> clearRevisions() async {
    final db = await database;
    await db.delete('revisions');
    _revisionsStreamController.add([]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Revision Topic Operations
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<RevisionTopic>> getRevisionTopics(
      {required String revisionId}) async {
    final db = await database;
    final maps = await db.query(
      'revision_topics',
      where: 'revisionId = ?',
      whereArgs: [revisionId],
      orderBy: 'orderIndex ASC',
    );
    return maps.map((m) => RevisionTopic.fromMap(m)).toList();
  }

  Stream<List<RevisionTopic>> streamRevisionTopics(
      {required String revisionId}) async* {
    yield await getRevisionTopics(revisionId: revisionId);
    yield* _getRevisionTopicController(revisionId).stream;
  }

  Future<void> addRevisionTopic(RevisionTopic topic) async {
    final db = await database;
    await db.insert(
      'revision_topics',
      topic.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _getRevisionTopicController(topic.revisionId)
        .add(await getRevisionTopics(revisionId: topic.revisionId));
  }

  Future<void> updateRevisionTopic(RevisionTopic topic) async {
    final db = await database;
    await db.update(
      'revision_topics',
      topic.toMap(),
      where: 'id = ?',
      whereArgs: [topic.id],
    );
    _getRevisionTopicController(topic.revisionId)
        .add(await getRevisionTopics(revisionId: topic.revisionId));
  }

  Future<void> deleteRevisionTopic(String id) async {
    final db = await database;
    final existing = await db.query(
      'revision_topics',
      columns: ['revisionId'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    final revisionId = existing.isNotEmpty
        ? existing.first['revisionId'] as String
        : null;

    await db.delete(
      'revision_topics',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (revisionId != null) {
      _getRevisionTopicController(revisionId)
          .add(await getRevisionTopics(revisionId: revisionId));
    }
  }

  Future<void> saveRevisionTopics(
      String revisionId, List<RevisionTopic> topics) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'revision_topics',
        where: 'revisionId = ?',
        whereArgs: [revisionId],
      );
      for (final t in topics) {
        await txn.insert(
          'revision_topics',
          t.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    _getRevisionTopicController(revisionId)
        .add(await getRevisionTopics(revisionId: revisionId));
  }

  Future<void> clearRevisionTopics() async {
    final db = await database;
    await db.delete('revision_topics');
    for (final controller in _revisionTopicsStreamControllers.values) {
      controller.add([]);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Study Log Operations
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<StudyLog>> getStudyLogs() async {
    final db = await database;
    final maps = await db.query(
      'study_logs',
      orderBy: 'timestamp DESC',
    );
    return maps.map((m) => StudyLog.fromMap(m)).toList();
  }

  Stream<List<StudyLog>> streamStudyLogs() async* {
    yield await getStudyLogs();
    yield* _studyLogsStreamController.stream;
  }

  Future<void> addStudyLog(StudyLog log) async {
    final db = await database;
    await db.insert(
      'study_logs',
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _studyLogsStreamController.add(await getStudyLogs());
  }

  Future<void> saveStudyLogs(List<StudyLog> logs) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final log in logs) {
        await txn.insert(
          'study_logs',
          log.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    _studyLogsStreamController.add(await getStudyLogs());
  }

  Future<void> clearStudyLogs() async {
    final db = await database;
    await db.delete('study_logs');
    _studyLogsStreamController.add([]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // User Profile Operations
  // ─────────────────────────────────────────────────────────────────────────

  Future<UserProfile?> getUserProfile() async {
    final db = await database;
    final maps = await db.query(
      'user_profile',
      where: "id = 'profile'",
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return UserProfile.fromMap(maps.first);
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    final db = await database;
    await db.insert(
      'user_profile',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearUserProfile() async {
    final db = await database;
    await db.delete('user_profile');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Notification Settings Operations
  // ─────────────────────────────────────────────────────────────────────────

  Future<NotificationSettings?> getNotificationSettings() async {
    final db = await database;
    final maps = await db.query(
      'notification_settings',
      where: "id = 'settings'",
      limit: 1,
    );
    if (maps.isEmpty) return null;
    try {
      final jsonStr = maps.first['data'] as String;
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return NotificationSettings.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveNotificationSettings(NotificationSettings settings) async {
    final db = await database;
    final jsonStr = jsonEncode(settings.toMap());
    await db.insert(
      'notification_settings',
      {'id': 'settings', 'data': jsonStr},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearNotificationSettings() async {
    final db = await database;
    await db.delete('notification_settings');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Generic App Settings Key-Value Operations
  // ─────────────────────────────────────────────────────────────────────────

  Future<String?> getSetting(String key) async {
    final db = await database;
    final res = await db.query(
      'notification_settings',
      where: 'id = ?',
      whereArgs: ['setting_$key'],
      limit: 1,
    );
    if (res.isEmpty) return null;
    return res.first['data'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'notification_settings',
      {'id': 'setting_$key', 'data': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteSetting(String key) async {
    final db = await database;
    await db.delete(
      'notification_settings',
      where: 'id = ?',
      whereArgs: ['setting_$key'],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Batch Operations (e.g. from JSON Import Screen)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> batchSave({
    List<Course>? courses,
    List<Module>? modules,
    List<Topic>? topics,
    List<StudyLog>? studyLogs,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      if (courses != null) {
        for (final c in courses) {
          await txn.insert(
            'courses',
            c.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
      if (modules != null) {
        for (final m in modules) {
          await txn.insert(
            'modules',
            m.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
      if (topics != null) {
        for (final t in topics) {
          await txn.insert(
            'topics',
            t.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
      if (studyLogs != null) {
        for (final l in studyLogs) {
          await txn.insert(
            'study_logs',
            l.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });

    if (courses != null && courses.isNotEmpty) {
      _coursesStreamController.add(await getCourses());
    }
    if (studyLogs != null && studyLogs.isNotEmpty) {
      _studyLogsStreamController.add(await getStudyLogs());
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Advanced Query Helpers (Analytics & Progression)
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<Module>> getAllModules() async {
    final db = await database;
    final maps = await db.query('modules', orderBy: 'orderIndex ASC');
    return maps.map((m) => Module.fromMap(m)).toList();
  }

  Future<Module?> getModuleById(String id) async {
    if (id.isEmpty) return null;
    final db = await database;
    final maps = await db.query(
      'modules',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Module.fromMap(maps.first);
  }

  Future<List<DateTime>> loadCompletedTopicDatesSince(
      DateTime cutoffDate) async {
    final db = await database;
    final maps = await db.query(
      'topics',
      columns: ['completedAt'],
      where: "status = 'completed' AND completedAt IS NOT NULL",
    );
    final result = <DateTime>[];
    for (final m in maps) {
      final dtStr = m['completedAt'] as String?;
      if (dtStr != null) {
        final dt = DateTime.tryParse(dtStr);
        if (dt != null && !dt.isBefore(cutoffDate)) {
          result.add(dt);
        }
      }
    }
    return result;
  }

  Future<List<DateTime>> loadRevisionEventsSince(DateTime cutoffDate) async {
    final db = await database;
    final maps = await db.query(
      'study_logs',
      columns: ['timestamp'],
      where: "type = 'revisionCompleted'",
    );
    final result = <DateTime>[];
    for (final m in maps) {
      final dtStr = m['timestamp'] as String?;
      if (dtStr != null) {
        final dt = DateTime.tryParse(dtStr);
        if (dt != null && !dt.isBefore(cutoffDate)) {
          result.add(dt);
        }
      }
    }
    return result;
  }

  Future<Set<String>> loadSuppressedModuleIds() async {
    final db = await database;
    final maps = await db.query(
      'notification_settings',
      where: "id = 'suppressed_modules'",
      limit: 1,
    );
    if (maps.isEmpty) return {};
    try {
      final list = jsonDecode(maps.first['data'] as String) as List<dynamic>;
      return list.cast<String>().toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> saveSuppressedModuleIds(Set<String> ids) async {
    final db = await database;
    await db.insert(
      'notification_settings',
      {
        'id': 'suppressed_modules',
        'data': jsonEncode(ids.toList()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Reloads and pushes latest data across all active broadcast streams.
  Future<void> reloadAllStreams() async {
    _coursesStreamController.add(await getCourses());
    _revisionsStreamController.add(await getRevisions());
    _studyLogsStreamController.add(await getStudyLogs());

    for (final courseId in _modulesStreamControllers.keys) {
      _modulesStreamControllers[courseId]
          ?.add(await getModules(courseId: courseId));
    }
    for (final moduleId in _topicsStreamControllers.keys) {
      _topicsStreamControllers[moduleId]
          ?.add(await getTopics(moduleId: moduleId));
    }
    for (final revisionId in _revisionTopicsStreamControllers.keys) {
      _revisionTopicsStreamControllers[revisionId]
          ?.add(await getRevisionTopics(revisionId: revisionId));
    }
  }
}
