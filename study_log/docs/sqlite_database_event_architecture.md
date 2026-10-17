# SQLite Database Event Architecture & Automated Cloud Sync

This document details the architectural analysis, technical constraints, and proposed patterns for intercepting database events in Flutter using `sqflite`, specifically for automated background synchronization (e.g. Google Drive sync).

---

## 1. The Core Problem

When implementing automated features like background cloud synchronization on database changes:
- Scattering manual `_notifyChange('table_name')` calls across 30+ individual CRUD methods (`addCourse`, `updateCourse`, `deleteCourse`, `addTopic`, `deleteStudyLog`, etc.) increases boilerplate and introduces human error (a new developer or method could forget to invoke it).
- A natural developer question arises: **"Is there any native database event-based hook or function in SQLite/sqflite that automatically notifies when data changes?"**

---

## 2. Technical Analysis: Why `sqflite` Lacks Native Event Hooks

### 2.1 The Platform Channel Bridge
`sqflite` is built on top of Flutter's Platform Channels:
- **Android**: Uses Java/Kotlin `SQLiteOpenHelper` and Android SQLite APIs.
- **iOS/macOS**: Uses FMDB / native SQLite C API.
- Calls across platform channels are asynchronous IPC messages. 
- While the native SQLite C API does provide `sqlite3_update_hook()`, the `sqflite` plugin **does not expose** this hook to Dart. There is no `db.onUpdate` or `db.onDatabaseChanged` stream provided by `sqflite`.

### 2.2 Why Native SQL Triggers Cannot Call Dart
SQLite supports triggers (`CREATE TRIGGER ... AFTER INSERT ON ...`), but:
- Triggers execute strictly within the embedded C engine inside the SQLite process.
- SQLite triggers cannot make asynchronous callbacks over Flutter's platform channel into Dart without custom native platform code and reverse method channels.
- Storing changes in a separate `change_log` table via triggers would still require periodic Dart polling or query inspection.

### 2.3 Difference from FFI-based ORMs (e.g., Drift)
- Packages like **Drift** (formerly Moor) talk to SQLite via **Dart FFI** (Foreign Function Interface), loading `sqlite3.so` / `sqlite3.dll` directly in memory without platform channels.
- Drift registers an FFI C-hook with `sqlite3_update_hook`, allowing tables to be observed as reactive Dart streams (`select().watch()`).
- In `sqflite`, which uses platform channels without FFI, this hook is unavailable.

---

## 3. Recommended Architectural Patterns

To avoid manually calling notify in every single CRUD function, you can centralize database writes using either of the following patterns:

---

### Pattern 1: Centralized Write Dispatcher (Recommended)

Instead of calling `db.insert()`, `db.update()`, and `db.delete()` directly inside each CRUD function, route all write operations through unified internal methods within `DatabaseService`.

```dart
class DatabaseService {
  final _databaseChangeController = StreamController<String>.broadcast();
  Stream<String> get onDatabaseChanged => _databaseChangeController.stream;

  bool _suppressChangeEvents = false;

  void _notifyChange(String table) {
    if (!_suppressChangeEvents && !_databaseChangeController.isClosed) {
      _databaseChangeController.add(table);
    }
  }

  // ── Centralized Write Dispatchers ──────────────────────────────────────────

  Future<int> insertRecord(
    String table,
    Map<String, dynamic> values, {
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final db = await database;
    final id = await db.insert(table, values, conflictAlgorithm: conflictAlgorithm);
    _notifyChange(table);
    return id;
  }

  Future<int> updateRecord(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = await database;
    final count = await db.update(table, values, where: where, whereArgs: whereArgs);
    _notifyChange(table);
    return count;
  }

  Future<int> deleteRecord(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = await database;
    final count = await db.delete(table, where: where, whereArgs: whereArgs);
    _notifyChange(table);
    return count;
  }

  Future<T> runWriteTransaction<T>(
    String table,
    Future<T> Function(Transaction txn) action,
  ) async {
    final db = await database;
    final result = await db.transaction(action);
    _notifyChange(table);
    return result;
  }
}
```

#### Benefits:
- **Single Point of Responsibility**: Notification logic, logging, and error handling live in exactly 4 methods.
- **Zero Boilerplate in CRUD**: Individual feature methods (`addCourse`, `updateTopic`, etc.) simply call `insertRecord('courses', ...)` without caring about notifications.

---

### Pattern 2: Intercepting Database Proxy (Decorator Pattern)

Wrap the `sqflite` `Database` or `DatabaseExecutor` in a custom wrapper class that intercepts all mutating calls.

```dart
class ObservableDatabase {
  final Database _db;
  final void Function(String table) onWrite;

  ObservableDatabase(this._db, {required this.onWrite});

  Future<int> insert(String table, Map<String, dynamic> values, {ConflictAlgorithm? conflictAlgorithm}) async {
    final id = await _db.insert(table, values, conflictAlgorithm: conflictAlgorithm);
    onWrite(table);
    return id;
  }

  Future<int> update(String table, Map<String, dynamic> values, {String? where, List<Object?>? whereArgs}) async {
    final count = await _db.update(table, values, where: where, whereArgs: whereArgs);
    onWrite(table);
    return count;
  }

  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) async {
    final count = await _db.delete(table, where: where, whereArgs: whereArgs);
    onWrite(table);
    return count;
  }

  // Read-only operations pass straight through without notification
  Future<List<Map<String, dynamic>>> query(String table, {bool? distinct, List<String>? columns, String? where, List<Object?>? whereArgs, String? groupBy, String? having, String? orderBy, int? limit, int? offset}) {
    return _db.query(table, distinct: distinct, columns: columns, where: where, whereArgs: whereArgs, groupBy: groupBy, having: having, orderBy: orderBy, limit: limit, offset: offset);
  }
}
```

---

## 4. Background Sync Architecture Integration

Once the database emits changes on `Stream<String> onDatabaseChanged`, the consumer (`CloudSyncController`) orchestrates the background sync pipeline:

```
[UI Action / User Input]
         │
         ▼
[DatabaseService.insertRecord / updateRecord]
         │
         ├─── Writes to local SQLite
         │
         └─── Emits table event on onDatabaseChanged
                      │
                      ▼
        [CloudSyncController Observer]
                      │
                      ▼
         [Debounce Timer (4 seconds)]
           • Batches consecutive writes
           • Prevents duplicate uploads
                      │
                      ▼ (Timer fires OR App Pauses via WidgetsBindingObserver)
         [GoogleDriveService.backupDatabase]
           • Checks user auth status
           • Silently pushes JSON snapshot to appDataFolder
           • Updates lastBackupDate in UI
```

---

## 5. Summary & Recommendation

| Approach | Native Event Hook? | Pros | Cons |
| :--- | :---: | :--- | :--- |
| **Direct calls in CRUD** | No | Simple to trace per method | Manual repetition across 30+ methods |
| **Centralized Dispatcher** (Pattern 1) | Simulated | Clean, single place for writes & notifications | Requires refactoring internal CRUD calls to use `insertRecord` |
| **Database Decorator** (Pattern 2) | Simulated | Matches `sqflite` interface, 100% transparent | Need to maintain proxy forwarding signatures |
| **Migrate to Drift** | Yes (FFI) | Native table streams | Massive rewrite, requires code generation and build_runner |

**Conclusion**: For `study_log`, **Pattern 1 (Centralized Write Dispatcher)** provides the best balance of simplicity, reliability, and zero third-party dependencies while eliminating manual notification calls in individual CRUD functions.
