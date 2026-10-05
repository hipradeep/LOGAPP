# Topic Completion & Revision Flow

> Study App — `study_log`  
> Documents the complete lifecycle of topic status persistence and how the Revision module relates to the Course/Module hierarchy.

---

## 1. Entity Map

### 1.1 Core Hierarchy (Course → Module → Topic)

```
Course
 ├── id           : String
 ├── title        : String
 ├── description  : String
 ├── status       : String  ('active' | 'completed' | 'archived')
 ├── deadline     : DateTime?
 ├── iconCodePoint: int?
 ├── colorValue   : int?
 ├── createdAt    : DateTime
 └── updatedAt    : DateTime

Module
 ├── id           : String
 ├── courseId     : String  ← FK → Course.id
 ├── title        : String
 ├── description  : String
 ├── orderIndex   : int
 ├── status       : String  ('active' | 'in_progress' | 'completed')
 ├── createdAt    : DateTime
 └── updatedAt    : DateTime

Topic
 ├── id             : String
 ├── courseId       : String  ← FK → Course.id
 ├── moduleId       : String  ← FK → Module.id
 ├── title          : String
 ├── status         : TopicStatus  (notStarted | inProgress | completed)
 ├── description    : String
 ├── orderIndex     : int
 ├── iconCodePoint  : int?
 ├── colorValue     : int?
 └── completedAt    : DateTime?  ← set when status → completed
```

**`TopicStatus` enum**

| Value | Meaning |
|-------|---------|
| `notStarted` | User hasn't touched the topic |
| `inProgress` | Partially studied |
| `completed` | All study done; `completedAt` is stamped |

---

### 1.2 Revision Entities

```
Revision                              ← one per completed Module
 ├── id                : String
 ├── courseId          : String  ← FK → Course.id
 ├── moduleId          : String  ← FK → Module.id
 ├── courseTitle       : String  (denormalised — display only)
 ├── moduleTitle       : String  (denormalised — display only)
 ├── moduleDescription : String  (denormalised — display only)
 ├── currentLevel      : int     (1 → 5,  R1 through R5)
 ├── status            : RevisionStatus  (active | finished)
 ├── nextRevisionAt    : DateTime  ← when this level unlocks
 ├── completedAt       : DateTime? ← set when R5 is done
 ├── createdAt         : DateTime
 └── updatedAt         : DateTime

RevisionTopic                         ← independent checklist inside a Revision
 ├── id          : String
 ├── revisionId  : String  ← FK → Revision.id
 ├── courseId    : String
 ├── moduleId    : String
 ├── title       : String
 ├── status      : TopicStatus  (shared enum with Topic)
 ├── orderIndex  : int
 ├── completedAt : DateTime?
 ├── createdAt   : DateTime
 └── updatedAt   : DateTime
```

**`RevisionStatus` enum**

| Value | Meaning |
|-------|---------|
| `active` | Ladder in progress (R1–R4 open or R5 pending) |
| `finished` | R5 completed — nothing left to revise |

**`RevisionSchedule` — Spaced Repetition Ladder**

| Level | Unlocks After |
|-------|--------------|
| R1 | +1 day  |
| R2 | +3 days |
| R3 | +7 days |
| R4 | +14 days |
| R5 | +30 days |

---

### 1.3 Supporting Entities

```
OngoingModuleItem       ← UI-only view model (no persistence)
 ├── course       : Course
 ├── module       : Module
 ├── title        : String
 ├── breadcrumb   : String   (course title)
 ├── progressRatio: String   ("3 / 5 topics")
 ├── progress     : double   (0.0 → 1.0)
 ├── inProgressRatio: double
 └── status       : ModuleStudyStatus  (running | upcoming | completed)

CourseModuleProgress    ← rollup per course
 ├── courseId          : String
 ├── completedModules  : int
 ├── totalModules      : int
 └── isCourseMarkedComplete: bool

DailyProgressActivity   ← heatmap cell
 ├── date            : DateTime
 ├── topicsFinished  : int
 └── revisionsDone   : int
```

---

## 2. Local Storage (Cache Files)

| File | Content |
|------|---------|
| `study_topics_cache.json` | `Map<moduleId, List<Topic>>` buckets |
| `study_revisions_cache.json` | `List<Revision>` |
| `study_revision_topics_cache.json` | `Map<revisionId, List<RevisionTopic>>` |
| `study_revision_events.json` | `List<ISO-8601 String>` (timestamps of completed revision sessions) |
| `study_revisions_suppressed.json` | `List<String>` (moduleIds excluded from auto-reconcile) |

---

## 3. Key Functions

### 3.1 `LocalTopicStorage`

| Function | Signature | Purpose |
|----------|-----------|---------|
| `saveTopics` | `(moduleKey, List<Topic>) → Future<void>` | Persists topic list for a module. Deduplicates cross-bucket orphans on rename. |
| `loadTopicsForModule` | `({moduleId, fallbackTitle}) → Future<List<Topic>>` | Loads topics preferring `moduleId` key; falls back to title. |
| `loadAllBuckets` | `() → Future<Map<String, List<Topic>>>` | Single-pass read of entire cache — used by `OngoingModulesController.refresh()`. |
| `resolveForModule` | `(buckets, {moduleId, fallbackTitle}) → List<Topic>` | Synchronous lookup: direct key → case-insensitive → `item.moduleId` scan → title fallback. |
| `loadCompletedTopicDatesSince` | `(cutoffDate) → Future<List<DateTime>>` | Streams `completedAt` timestamps for analytics — avoids full `Topic` allocations. |
| `clearAll` | `() → Future<void>` | Wipes entire topic cache. |

### 3.2 `LocalRevisionStorage`

| Function | Signature | Purpose |
|----------|-----------|---------|
| `loadAll` | `() → Future<List<Revision>>` | Reads and parses the full revision list. |
| `saveAll` | `(List<Revision>) → Future<void>` | Overwrites entire revision cache (FIFO queued). |
| `recordRevisionEvent` | `(DateTime) → Future<void>` | Appends a session timestamp to the events log. |
| `loadRevisionEvents` | `() → Future<List<DateTime>>` | All revision event timestamps. |
| `loadRevisionEventsSince` | `(cutoffDate) → Future<List<DateTime>>` | Filtered events for analytics. |
| `loadSuppressedModuleIds` | `() → Future<Set<String>>` | Loads IDs exempt from reconcile auto-creation. |
| `saveSuppressedModuleIds` | `(Set<String>) → Future<void>` | Persists suppression list. |

### 3.3 `LocalRevisionTopicStorage`

| Function | Signature | Purpose |
|----------|-----------|---------|
| `loadTopicsForRevision` | `(revisionId) → Future<List<RevisionTopic>>` | Loads checklist items for one revision. |
| `saveTopics` | `(revisionId, List<RevisionTopic>) → Future<void>` | Replaces full list for a revision. |
| `addTopic` | `(revisionId, RevisionTopic) → Future<void>` | Appends one item. |
| `updateTopic` | `(revisionId, RevisionTopic) → Future<void>` | Upserts by `id`. |
| `deleteTopic` | `(revisionId, topicId) → Future<void>` | Removes one item by `id`. |

### 3.4 `RevisionController`

| Function | Signature | Purpose |
|----------|-----------|---------|
| `completeCurrentLevel` | `(revisionId, {at}) → Future<bool>` | **Core action** — advances `currentLevel`, stamps event, writes `StudyLog`, notifies downstream. |
| `resetRevision` | `(revisionId, {at}) → Future<void>` | Sends ladder back to R1. |
| `reconcile` | `() → Future<void>` | Entry-point: queues `_performReconcile`. Guards against concurrent runs. |
| `_performReconcile` | `() → Future<void>` | Purges incomplete-module revisions; syncs `moduleDescription`/`courseTitle` metadata. |
| `createOrEnsureRevision` | `({courseId, moduleId, courseTitle, moduleTitle, moduleDescription}) → Future<Revision>` | Manual add path — un-suppresses module, creates R1 if missing. |
| `deleteRevision` | `(revisionId) → Future<void>` | Removes record and suppresses module from future reconcile. |
| `removeRevisionsForCourse` | `(courseId) → Future<void>` | Bulk-removes all revisions for an archived course. |
| `_isModuleComplete` | `(Module) → Future<bool>` | All topics completed? Checks memory → local → Firestore in order. |
| `_isRevisionComplete` | `(Revision) → Future<bool>` | Same check scoped to a revision's module. |
| `revisionForModule` | `(moduleId, {moduleTitle}) → Revision?` | Lookup by `moduleId` or title. |

### 3.5 `OngoingModulesController`

| Function | Signature | Purpose |
|----------|-----------|---------|
| `refresh` | `() → Future<void>` | Full rebuild of `_ongoingItems` from local storage + Firestore fallback. |
| `isModuleComplete` | `(moduleId) → bool` | Quick completion check from in-memory maps. |
| `topicCountForModule` | `(moduleId) → int` | Total topics in a module. |
| `completedTopicCountForModule` | `(moduleId) → int` | Done topics in a module. |
| `deleteModule` | `(OngoingModuleItem) → Future<void>` | Permanent delete from local + Firestore. |

### 3.6 `Revision` model helpers

| Function | Purpose |
|----------|---------|
| `advance(DateTime)` | Immutably moves ladder forward; anchors next date to `createdAt` to preserve schedule. |
| `isDueAt(DateTime)` | `true` when current level has unlocked (not before `nextRevisionAt`). |
| `daysUntilDue(DateTime)` | Positive = countdown, negative = overdue. |
| `ladderProgress` | `0.0 – 1.0` fraction of R5 ladder cleared. |

---

## 4. Flow Diagrams

### 4.1 Topic Completion Save Flow

```
User taps "Mark Complete" on a Topic
        │
        ▼
[UI Widget — ModuleDetailScreen / TopicListItem]
        │  calls
        ▼
[OngoingModulesController] (or direct service call)
  topic.copyWith(
    status: TopicStatus.completed,
    completedAt: DateTime.now()
  )
        │
        ▼
LocalTopicStorage.saveTopics(moduleId, updatedTopics)
  ├── reads current JSON bucket from disk
  ├── replaces topic entry by id
  ├── removes orphan buckets sharing same moduleId
  └── writes JSON atomically (FIFO queue)
        │
        ▼
[Firestore] FirestoreService.updateTopic(topic)    (async, non-blocking)
        │
        ▼
OngoingModulesController.refresh()
  ├── recomputes _topicCounts[moduleId]
  ├── recomputes _completedTopicCounts[moduleId]
  ├── sets ModuleStudyStatus.completed when all topics done
  └── notifyListeners()  →  UI rebuilds
        │
        ├── [If ALL topics in module are completed]
        │         │
        │         ▼
        │   RevisionController._onOngoingChanged()
        │         │
        │         ▼
        │   RevisionController.reconcile()
        │         │
        │         ▼
        │   RevisionController.createOrEnsureRevision(...)
        │     ├── creates Revision at R1
        │     ├── nextRevisionAt = now + 1 day
        │     ├── LocalRevisionStorage.saveAll(...)
        │     └── FirestoreService.addRevision(...)  (async)
        │
        └── [Always]
              ProgressController.refresh()
                ├── re-reads completedTopicDates from disk
                └── updates streak / heatmap
```

---

### 4.2 Revision Level Completion Flow

```
User taps "Start R{n}" on RevisionDetailScreen
        │
        ▼
RevisionController.completeCurrentLevel(revisionId)
        │
        ├── current.advance(now)
        │     ├── if currentLevel >= 5  →  status = finished, completedAt = now
        │     └── else  →  currentLevel++, nextRevisionAt = anchored or now+interval
        │
        ├── LocalRevisionStorage.saveAll(_revisions)
        │
        ├── LocalRevisionStorage.recordRevisionEvent(now)
        │     └── appends ISO timestamp to study_revision_events.json
        │
        ├── LocalStudyLogStorage.addLog(StudyLog{type: revisionCompleted, ...})
        │
        ├── FirestoreService.addStudyLog(log)         (async)
        │
        ├── OngoingModulesController.refresh()        (async)
        │
        ├── ProgressController.refresh()              (async)
        │
        ├── notifyListeners()  →  RevisionScreen / RevisionDetailScreen rebuild
        │
        └── FirestoreService.updateRevision(advanced) (async)
```

---

### 4.3 Reconcile Flow (Auto-Triggered)

```
OngoingModulesController notifies
  (every topic toggle / add / delete / course change)
        │
        ▼
RevisionController._onOngoingChanged()
        │
        ▼
RevisionController.reconcile()          ← queued if already running
        │
        ▼
_performReconcile()
  │
  ├── STEP 1 — PURGE
  │   For each existing Revision:
  │     _isRevisionComplete()
  │       ├── Check OngoingModulesController in-memory (fast path)
  │       ├── Read LocalTopicStorage (disk)
  │       └── Fallback to FirestoreService.getTopics()
  │     If NOT complete → mark for removal
  │         │
  │         └── FirestoreService.deleteRevision(id)  (async)
  │
  ├── STEP 2 — METADATA SYNC
  │   For each Module across all non-archived Courses:
  │     If Revision exists for module:
  │       Sync moduleDescription, courseTitle → copyWith(updatedAt: now)
  │       └── FirestoreService.updateRevision(...)  (async)
  │
  └── notifyListeners()  →  RevisionScreen rebuilds
```

---

### 4.4 RevisionTopic (Checklist) Flow

```
RevisionDetailScreen loads
        │
        ▼
LocalRevisionTopicStorage.loadTopicsForRevision(revisionId)
        │
        ▼
User adds / edits / deletes a RevisionTopic
        │
        ├── ADD:    LocalRevisionTopicStorage.addTopic(revisionId, topic)
        ├── EDIT:   LocalRevisionTopicStorage.updateTopic(revisionId, topic)
        └── DELETE: LocalRevisionTopicStorage.deleteTopic(revisionId, topicId)

User toggles a RevisionTopic status
        │
        ▼
topic.copyWith(
  status: TopicStatus.completed,
  completedAt: DateTime.now()
)
        │
        ▼
LocalRevisionTopicStorage.updateTopic(revisionId, updated)
  (Does NOT affect Course Topic status — completely independent)
```

---

## 5. How Revision Module Relates to Course Module

```
Course
  └── Module ──────────────────────────────────────────────────────────┐
        └── Topics (all completed?)                                     │
                  YES                                                   │
                   │                                                    │
                   ▼                                                    │
             Revision (R1 created)  ←── linked via moduleId / courseId ┘
               │  courseTitle  (copy — display only)
               │  moduleTitle  (copy — display only)
               │  moduleDescription (copy — display only)
               │
               └── RevisionTopics  ←── independent checklist
                     (seeded from Module Topics via RevisionTopic.fromTopic(),
                      but lifecycle is fully decoupled)
```

### Relationship Rules

| Rule | Detail |
|------|--------|
| **One Revision per Module** | `RevisionController` enforces uniqueness by `moduleId` (and `moduleTitle` fallback). |
| **Revision is created automatically** | `reconcile()` fires on every `OngoingModulesController` notification; `createOrEnsureRevision()` handles the manual add path. |
| **Revision is destroyed automatically** | `_performReconcile()` purges any `Revision` whose module is no longer fully completed (e.g. a topic was un-checked). |
| **Module data is denormalised** | `courseTitle`, `moduleTitle`, `moduleDescription` are copied into `Revision` for offline display. They are re-synced during `_performReconcile()` if they drift. |
| **RevisionTopics are independent** | Completing a `RevisionTopic` does **not** change the parent `Topic.status`. They share the `TopicStatus` enum and `toTopic()` helper for widget interoperability only. |
| **Course archive cascades** | `removeRevisionsForCourse(courseId)` deletes all revisions when a course is archived. Archived courses are also filtered out of `RevisionController.revisions` getter. |
| **Suppression list** | When the user manually deletes a `Revision`, the `moduleId` is added to `_suppressedModuleIds` so `reconcile()` won't recreate it. Calling `createOrEnsureRevision()` again clears the suppression. |

---

## 6. Data Flow Summary (One-Page View)

```
┌─────────────────────────────────────────────────────────────────────┐
│                         USER ACTION                                 │
│                  "Mark topic as completed"                          │
└────────────────────────────┬────────────────────────────────────────┘
                             │
               ┌─────────────▼──────────────┐
               │   LocalTopicStorage        │
               │   saveTopics(moduleId, []) │
               └─────────────┬──────────────┘
                             │ notifies
               ┌─────────────▼──────────────┐
               │  OngoingModulesController  │
               │  refresh()                 │──► UI: progress bar, ratio
               └──────┬──────────┬──────────┘
                      │          │
              all done?│          └──► ProgressController.refresh()
                      │                  (streak, heatmap)
                      ▼
        ┌─────────────────────────┐
        │  RevisionController     │
        │  createOrEnsureRevision │──► LocalRevisionStorage.saveAll()
        │  R1, nextAt = +1 day   │──► Firestore.addRevision()
        └─────────────────────────┘
                      │
        User taps "Start R1" (after 1 day)
                      │
        ┌─────────────▼──────────────────────┐
        │  RevisionController                 │
        │  completeCurrentLevel(revisionId)   │
        │   advance() → R2, nextAt = +3 days  │
        │   recordRevisionEvent(now)           │
        │   addStudyLog(revisionCompleted)     │
        └────────────────────────────────────┘
                      │
        ... repeat R3 (+7d), R4 (+14d), R5 (+30d)
                      │
                 status = finished ✅
```

---

## 7. File Reference

| Layer | File |
|-------|------|
| Model | [`topic.dart`](file:///c:/Users/hipradeep/Documents/android_apps/log_app/study_log/lib/models/topic.dart) |
| Model | [`module.dart`](file:///c:/Users/hipradeep/Documents/android_apps/log_app/study_log/lib/models/module.dart) |
| Model | [`course.dart`](file:///c:/Users/hipradeep/Documents/android_apps/log_app/study_log/lib/models/course.dart) |
| Model | [`revision.dart`](file:///c:/Users/hipradeep/Documents/android_apps/log_app/study_log/lib/models/revision.dart) |
| Model | [`revision_topic.dart`](file:///c:/Users/hipradeep/Documents/android_apps/log_app/study_log/lib/models/revision_topic.dart) |
| Storage | [`local_topic_storage.dart`](file:///c:/Users/hipradeep/Documents/android_apps/log_app/study_log/lib/services/local_topic_storage.dart) |
| Storage | [`local_revision_storage.dart`](file:///c:/Users/hipradeep/Documents/android_apps/log_app/study_log/lib/services/local_revision_storage.dart) |
| Storage | [`local_revision_topic_storage.dart`](file:///c:/Users/hipradeep/Documents/android_apps/log_app/study_log/lib/services/local_revision_topic_storage.dart) |
| Controller | [`ongoing_modules_controller.dart`](file:///c:/Users/hipradeep/Documents/android_apps/log_app/study_log/lib/controllers/ongoing_modules_controller.dart) |
| Controller | [`revision_controller.dart`](file:///c:/Users/hipradeep/Documents/android_apps/log_app/study_log/lib/controllers/revision_controller.dart) |
| Controller | [`progress_controller.dart`](file:///c:/Users/hipradeep/Documents/android_apps/log_app/study_log/lib/controllers/progress_controller.dart) |
