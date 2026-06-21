import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Central SQLite singleton for log_app_offline.
///
/// Opens (or creates) the single on-device database file.
/// All services access data through [DatabaseService.instance.database].
///
/// Schema conventions:
///   - Primary keys: TEXT (UUID v4 strings)
///   - DateTime columns: INTEGER (millisecondsSinceEpoch)
///   - List<int> / List<String> columns: TEXT (JSON encoded)
///   - Nullable foreign keys: TEXT (null stored as SQL NULL)
class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  Database? _db;

  /// Returns the open [Database], initializing it if needed.
  Future<Database> get database async {
    _db ??= await _openDatabase();
    return _db!;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Initialization
  // ─────────────────────────────────────────────────────────────────────────

  Future<Database> _openDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'log_app.db');

    return openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      // Enable WAL mode for better concurrent read performance
      onOpen: (db) async => await db.rawQuery('PRAGMA journal_mode=WAL;'),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Schema
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // Activities
    batch.execute('''
      CREATE TABLE activities (
        id               TEXT PRIMARY KEY,
        name             TEXT NOT NULL,
        isActive         INTEGER NOT NULL DEFAULT 1,
        timestamp        INTEGER NOT NULL,
        trackingType     TEXT NOT NULL DEFAULT 'single',
        targetCount      INTEGER NOT NULL DEFAULT 1,
        reminderEnabled  INTEGER NOT NULL DEFAULT 1,
        repeatDays       TEXT NOT NULL DEFAULT '[]',
        scheduledTime    TEXT,
        startDate        INTEGER,
        endDate          INTEGER,
        subTaskTemplates TEXT NOT NULL DEFAULT '[]',
        description      TEXT NOT NULL DEFAULT '',
        category         TEXT,
        symbolType       TEXT,
        symbolValue      TEXT,
        skippable        INTEGER NOT NULL DEFAULT 0,
        createdAt        INTEGER NOT NULL
      )
    ''');

    // Tasks (belong to an activity, per-day)
    batch.execute('''
      CREATE TABLE tasks (
        id             TEXT PRIMARY KEY,
        activityId     TEXT NOT NULL,
        taskName       TEXT NOT NULL,
        timestamp      INTEGER NOT NULL,
        checked        INTEGER NOT NULL DEFAULT 0,
        symbolType     TEXT,
        symbolValue    TEXT,
        scheduledTime  TEXT,
        completionTime INTEGER,
        subTasks       TEXT NOT NULL DEFAULT '[]',
        createdAt      INTEGER NOT NULL,
        FOREIGN KEY (activityId) REFERENCES activities(id) ON DELETE CASCADE
      )
    ''');

    // Check-ins (activity completion records)
    batch.execute('''
      CREATE TABLE check_ins (
        id          TEXT PRIMARY KEY,
        activityId  TEXT NOT NULL,
        timestamp   INTEGER NOT NULL,
        checked     INTEGER NOT NULL DEFAULT 0,
        skipped     INTEGER NOT NULL DEFAULT 0,
        subTaskName TEXT,
        FOREIGN KEY (activityId) REFERENCES activities(id) ON DELETE CASCADE
      )
    ''');

    // Budget limits
    batch.execute('''
      CREATE TABLE budgets (
        id             TEXT PRIMARY KEY,
        name           TEXT NOT NULL,
        categoryName   TEXT NOT NULL,
        limit_amount   REAL NOT NULL DEFAULT 0,
        period         TEXT NOT NULL DEFAULT 'monthly',
        description    TEXT NOT NULL DEFAULT '',
        repeatDays     TEXT NOT NULL DEFAULT '[]',
        scheduledTime  TEXT,
        startDate      INTEGER,
        endDate        INTEGER,
        repeat         INTEGER NOT NULL DEFAULT 1,
        isActive       INTEGER NOT NULL DEFAULT 1,
        alertThreshold REAL NOT NULL DEFAULT 0.7,
        createdAt      INTEGER NOT NULL
      )
    ''');

    // Transactions (expenses/credits under a budget)
    batch.execute('''
      CREATE TABLE transactions (
        id            TEXT PRIMARY KEY,
        budgetId      TEXT NOT NULL,
        tag           TEXT NOT NULL DEFAULT '',
        description   TEXT NOT NULL DEFAULT '',
        amount        REAL NOT NULL,
        entryDate     INTEGER NOT NULL,
        expenseDate   INTEGER NOT NULL,
        isValidated   INTEGER NOT NULL DEFAULT 1,
        rawBody       TEXT,
        paymentMethod TEXT NOT NULL DEFAULT 'Cash',
        createdAt     INTEGER NOT NULL,
        FOREIGN KEY (budgetId) REFERENCES budgets(id) ON DELETE CASCADE
      )
    ''');

    // Budget settings (salary / income — single-row table)
    batch.execute('''
      CREATE TABLE budget_settings (
        key            TEXT PRIMARY KEY,
        value          TEXT NOT NULL
      )
    ''');

    await batch.commit(noResult: true);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute('DROP TABLE IF EXISTS activities');
      await db.execute('DROP TABLE IF EXISTS tasks');
      await db.execute('DROP TABLE IF EXISTS check_ins');
      await db.execute('DROP TABLE IF EXISTS budgets');
      await db.execute('DROP TABLE IF EXISTS transactions');
      await db.execute('DROP TABLE IF EXISTS budget_settings');
      await _onCreate(db, newVersion);
    }
  }
}
