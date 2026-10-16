# Unified Revision Screen Architecture Plan

**Document Version:** 1.0.0  
**Status:** Completed  
**Target Screen:** `RevisionScreen` (`study_log/lib/screens/revision_screen.dart`)  

---

## 1. Executive Summary & Objective

Currently, the `RevisionScreen` is split into two primary category tabs:
```
[ Topics (34) ]   [ Modules (12) ]
```

### The Problem with 2 Tabs
1. **Fragmented Spaced Repetition**: Spaced repetition is fundamentally calendar/time-driven. A user's priority is answering: *"What is due for revision today?"* Forcing the user to manually switch between two tabs causes them to overlook due modules or topics hidden in the other tab.
2. **Duplicate Filter States**: Both tabs maintain their own filter state, scroll positions, and sort orders.
3. **Redundant UI Overhead**: The top tab bar consumes vertical space that could be used for showing actionable study cards.

### The Solution: Single Unified Revision Stream
Merge Topics and Modules into a **Single Unified Revision Stream**:
* **One Screen, One Agenda**: All due revisions appear together in chronological order (soonest due at the top).
* **Clear Identity Badges**: Each card clearly signals whether it is an individual `Topic` or a full `Module`.
* **Combined Level Filters**: The top ladder pills (`All`, `R1`–`R5`, `Finished`) reflect the combined total of both items.
* **Optional Segment Filter**: An inline pill filter (`All (46)`, `Topics (34)`, `Modules (12)`) allows instant filtering without tab fragmentation.

---

## 2. Visual Architecture Comparison

### Before (2 Category Tabs)
```
+-------------------------------------------------------+
| Revision                                              |
| [  Topics (34)  ]   [  Modules (12)  ]                |  <-- Separated tabs
|-------------------------------------------------------|
| [ All ] [ R1 (10) ] [ R2 (8) ] ... [ Finished (16) ]  |
| Due Date v                                            |
| [ Topic Card 1 ]                                      |
| [ Topic Card 2 ]                                      |
+-------------------------------------------------------+
```

### Target: Unified Single Stream
```
+-------------------------------------------------------+
| Revision                                  ⚙️ Settings |
+-------------------------------------------------------+
| [ All (46) ] [ R1 (12) ] [ R2 (8) ] ... [ Finished ]  |  <-- Combined Level Ladder
|-------------------------------------------------------|
| Scope: [ All ] [ Due Today (4) ] [ Upcoming ]         |
| Type:  [ All (46) ] [ Topics (34) ] [ Modules (12) ]  |  <-- Lightweight Filter Pills
| Sort:  Due Date v                                     |
+-------------------------------------------------------+
| TODAY'S REVISIONS (4 DUE)                             |
| +---------------------------------------------------+ |
| | [TOPIC]  Binary Search Trees                      | |
| | Algorithms • Module 3 • R2 Due Today              | |
| | [ Complete ]                         [ Revise > ] | |
| +---------------------------------------------------+ |
| | [MODULE] Dynamic Programming (8 topics)           | |
| | Advanced CS • R1 Due Today                        | |
| | [ Complete ]                         [ Open > ]   | |
| +---------------------------------------------------+ |
|                                                       |
| UPCOMING                                              |
| +---------------------------------------------------+ |
| | [TOPIC]  Red-Black Trees                          | |
| | Algorithms • Module 3 • R3 in 2 days              | |
| +-------------------------------------------------------+
```

---

## 3. Data Model: Polymorphic `RevisionItem`

To present both topics and modules in a single list with seamless sorting, we define a lightweight unified wrapper interface:

```dart
enum RevisionType { topic, module }

abstract class UnifiedRevisionItem {
  String get id;
  String get courseId;
  String get moduleId;
  String get title;
  int get currentLevel;
  RevisionStatus get status;
  DateTime get nextRevisionAt;
  DateTime? get lastRevisionAt;
  DateTime? get completedAt;
  RevisionType get type;

  bool isDueAt(DateTime now);
  bool get isFinished;
}

class UnifiedTopicRevisionItem implements UnifiedRevisionItem {
  final TopicRevision raw;
  ...
}

class UnifiedModuleRevisionItem implements UnifiedRevisionItem {
  final RevisionModule raw;
  ...
}
```

### Benefits
1. **Single Sort Operation**:
   ```dart
   unifiedItems.sort((a, b) {
     if (a.isFinished != b.isFinished) return a.isFinished ? 1 : -1;
     return a.nextRevisionAt.compareTo(b.nextRevisionAt);
   });
   ```
2. **Unified Search & Scope Filtering**:
   A single `.where()` pass checks level, scope (`dueToday`, `upcoming`, `finished`), and optional type filter (`all`, `topics`, `modules`).

---

## 4. Unified Card Design

Each list item renders using a unified card layout with visual differentiation:

| Element | Topic Revision Item | Module Revision Item |
| :--- | :--- | :--- |
| **Type Pill** | `Topic` (e.g. Pastel Indigo) | `Module` (e.g. Pastel Blue) |
| **Icon** | `Icons.topic_outlined` | `Icons.folder_outlined` |
| **Breadcrumb** | `Course Title • Module Title` | `Course Title • 8 topics` |
| **Level Badge** | `R1` – `R5` / `Finished` | `R1` – `R5` / `Finished` |
| **Primary Action** | **"Revise"** $\rightarrow$ Launches 1-topic session timer | **"Open"** $\rightarrow$ Opens module revision detail |
| **Quick Action** | Checkmark to complete level immediately | Checkmark to complete module level immediately |

---

## 5. UI Layout & Controls

### Level Selector (Horizontal Bar)
Displays counts aggregated across both Topics and Modules:
* `All` $\rightarrow$ Total active ($N_{\text{topics}} + N_{\text{modules}}$)
* `R1` $\dots$ `R5` $\rightarrow$ Combined items at each level
* `Finished` $\rightarrow$ Combined completed items

### Filter Chips (Single Horizontal Row)
* **Scope**: `All` | `Due Today` | `Upcoming` | `Finished`
* **Type Filter**: `All` | `Topics` | `Modules`
* **Sort Dropdown**: `Due Date` | `Level` | `Name`

---

## 6. Implementation Roadmap

### Phase 1: Unified Model & Data Adapter
- [x] Define `UnifiedRevisionItem` interface and wrappers (`UnifiedTopicRevisionItem`, `UnifiedModuleRevisionItem`) in `study_log/lib/models/unified_revision_item.dart`.
- [x] Implement data merge & sort helper combining `TopicRevisionController` and `RevisionController`.

### Phase 2: Revision Screen UI Refactor
- [x] Remove `_RevisionCategoryTabBar` and `RevisionCategoryTab` enum from `RevisionScreen`.
- [x] Update top level ladder counts to sum both topics and modules.
- [x] Add lightweight type filter pills (`All`, `Topics`, `Modules`).
- [x] Update list builder to render polymorphic items (`TopicRevisionCard` or `_RevisionItemCard`) within the same `ListView.separated`.

### Phase 3: Quick Actions & Navigation
- [x] Ensure quick complete on topic items calls `TopicRevisionController.completeCurrentLevel`.
- [x] Ensure quick complete on module items calls `RevisionController.completeCurrentLevel`.
- [x] Wire single-topic timer launch for topics and `RevisionDetailScreen` navigation for modules.

### Phase 4: Empty States & Polish
- [x] Contextual empty state when filter yields zero results (e.g. "No topics or modules due today! 🎉").
- [x] Adhere to all rules in `optimize_view.md` (`const` gravity, zero `.withOpacity()`, pure `ListenableBuilder`).

---

## 7. User Experience Win

1. **Zero Context Switching**: The user never misses an overdue item hiding in a secondary tab.
2. **Immediate Clarity**: Launch the app, tap "Revision", and immediately see today's complete revision workload.
3. **Fast Actions**: Revise individual topics or review entire modules from one continuous, beautifully organized feed.
