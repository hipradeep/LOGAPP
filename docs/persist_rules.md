# Data Persistence & Database Rules

> **Core Philosophy**: SQLite via `DatabaseService` is the **single source of truth** for all entity operations in the application. Intermediary disk-bucket cache layers (e.g., `LocalTopicStorage`) for entity mutations (add, update, delete, status toggle) are strictly deprecated and eliminated.

---

## 1. Single Source of Truth (`DatabaseService`)

* **Direct DB Operations Only**:
  * Any screen or controller mutating a topic must directly invoke `DatabaseService.instance` methods:
    * `DatabaseService.instance.addTopic(topic)` — for creating a new topic.
    * `DatabaseService.instance.updateTopic(topic)` — for editing details, notes, or toggling status.
    * `DatabaseService.instance.deleteTopic(topicId)` — for removing a topic.
    * `DatabaseService.instance.getTopicById(topicId)` — for single-entity $O(1)$ retrieval.
* **No Dual-Writing**:
  * Never duplicate writes between `LocalTopicStorage` and `DatabaseService`.
  * Never rewrite an entire module bucket of topics just to update or insert a single topic entity.

---

## 2. Upsert Guarantees (`updateTopic`)

* **Atomic Upsert Rule**:
  * In `DatabaseService.updateTopic(Topic topic)`, the update statement must gracefully handle rows that do not yet exist in the SQLite `topics` table by inserting them:
  ```dart
  Future<void> updateTopic(Topic topic) async {
    final db = await database;
    final count = await db.update(
      'topics',
      topic.toMap(),
      where: 'id = ?',
      whereArgs: [topic.id],
    );
    if (count == 0) {
      await db.insert(
        'topics',
        topic.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    _getTopicController(topic.moduleId)
        .add(await getTopics(moduleId: topic.moduleId));
  }
  ```
  * This guarantees that entity status changes, whether created via bulk imports, offline sync, or legacy caches, will **always** persist without silent failure.

---

## 3. Real-Time Stream Distribution

* **Controller Broadcaster**:
  * Every mutation (`addTopic`, `updateTopic`, `deleteTopic`) in `DatabaseService` automatically publishes the latest topic list for the relevant `moduleId` via `_getTopicController(moduleId)`.
  * UI screens (`ModuleDetailScreen`, `TopicDetailScreen`) subscribing to `dbService.streamTopics(moduleId: ...)` receive instant reactive updates across routes without manual reload callbacks.

---

## 4. Single-Entity Retrieval Over Collection Scans

* **Rule**:
  * When loading or refreshing a single topic (such as inside `TopicDetailScreen._loadTopicData()`), use `getTopicById(topicId)` directly.
  * **BAD**: Loading all topics for a module via `loadTopicsForModule(...)` or `getTopics(...)` and scanning with `.where((t) => t.id == id).firstOrNull`.
  * **GOOD**:
    ```dart
    final updated = await DatabaseService.instance.getTopicById(_topic.id);
    if (updated != null && mounted) {
      setState(() => _topic = updated);
    }
    ```

---

## 5. UI Lifecycle & State Preserving

1. **Optimistic Local State Update**:
   * On user interaction (e.g., status toggle in `_handleStatusChanged`), immediately invoke `setState(() => _topic = updated)` to ensure instantaneous UI response with zero perceived latency.
2. **Immediate DB Await**:
   * Directly await `DatabaseService.instance.updateTopic(updated)`.
3. **PopScope Result Propagation**:
   * Screens accepting entity modifications (such as `TopicDetailScreen`) must configure `PopScope(canPop: false)` to intercept device back gestures and return the updated entity via `Navigator.pop(context, _topic)`.
4. **Reactive Controller Invalidation**:
   * After mutating topic status, invalidate dependent feature controllers:
     * `OngoingModulesController.refresh()`
     * `ProgressController.refresh()`
     * `RevisionController.reconcile()`
     * `TopicRevisionController.refresh()`

---

## 6. Deprecated Anti-Patterns

| Anti-Pattern | Correct Pattern |
| :--- | :--- |
| `LocalTopicStorage.saveTopics(key, list)` for single updates | `DatabaseService.instance.updateTopic(topic)` |
| `LocalTopicStorage.loadTopicsForModule(...)` inside detail screens | `DatabaseService.instance.getTopicById(id)` |
| Silent empty `catch (_) {}` swallowing DB write exceptions | Explicit await on `DatabaseService` without masking write failures |
| Using module titles as storage keys | Using immutable `moduleId` UUIDs as database keys |

---

## 7. Topic Revision Status Invariance

* **Completed Status Invariance**:
  * When a topic is under spaced repetition revision (R1, R2, R3, R4, R5), its study status is **immutable** as `TopicStatus.completed`.
  * Revision sessions must **NEVER** reset `Topic.status` to `TopicStatus.notStarted` or wipe `completedAt`.
  * Spaced repetition tracks repetition milestones (`currentLevel`, `nextRevisionAt`) inside `TopicRevision` (`topic_revisions` table) and revision session logs (`StudyLogType.revisionCompleted`), **NOT** by reverting the topic's baseline completion status.
