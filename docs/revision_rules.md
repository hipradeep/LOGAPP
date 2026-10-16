# Spaced Repetition & Revision Rules

**Document:** `docs/revision_rules.md`  
**Scope:** Topic & Module Revision Architecture  
**Controllers:** [`TopicRevisionController`](file:///c:/Users/hipradeep/Documents/android_apps/log_app/study_log/lib/controllers/topic_revision_controller.dart), [`RevisionController`](file:///c:/Users/hipradeep/Documents/android_apps/log_app/study_log/lib/controllers/revision_controller.dart)  
**Schedule Engine:** [`RevisionSchedule`](file:///c:/Users/hipradeep/Documents/android_apps/log_app/study_log/lib/models/revision_module.dart#L4-L22)  

---

## 1. The 5-Stage Interval Ladder

Revisions follow a 5-step spaced repetition curve designed to optimize memory retention:

| Level | Interval Delay | Target Retention Window | Due Threshold |
| :---: | :---: | :--- | :--- |
| **Initial Study** | Immediate | First complete pass / active recall | Marked `TopicStatus.completed` |
| **R1** | **+1 Day** (24 hours) | Intercept initial forgetting curve | 1 day after enrollment |
| **R2** | **+3 Days** | Solidify short-term recall | 3 days after R1 completed |
| **R3** | **+7 Days** | One-week structural retention anchor | 7 days after R2 completed |
| **R4** | **+14 Days** | Two-week consolidation | 14 days after R3 completed |
| **R5** | **+30 Days** | One-month long-term consolidation | 30 days after R4 completed |
| **Mastered** | Terminal | Permanent knowledge retention | Cleared R5 (`isFinished == true`) |

$$\text{Initial Study} \xrightarrow{+1\text{d}} \text{R1} \xrightarrow{+3\text{d}} \text{R2} \xrightarrow{+7\text{d}} \text{R3} \xrightarrow{+14\text{d}} \text{R4} \xrightarrow{+30\text{d}} \text{R5} \xrightarrow{} \text{Mastered}$$

---

## 2. Enrollment Rules

1. **Completion Prerequisite**:
   - A topic must reach `TopicStatus.completed` before the **"Add to Revision (R1)"** action is available.
   - Topics in `notStarted` or `inProgress` stay in the Study Phase and do not display enrollment actions.
2. **Anchor & Initial Unlock**:
   - Enrolling a topic creates a record with `currentLevel = 1` and `status = RevisionStatus.active`.
   - `nextRevisionAt` is set to `now + RevisionSchedule.intervalFor(1)` (+1 day).
3. **Idempotent Enrollment**:
   - If a topic is already enrolled, `enrollTopicInRevision()` returns the existing record without duplicating.

---

## 3. Due Date & Status Computation Rules

1. **Due Evaluation (`isDueAt(now)`)**:
   - Calculated by calendar date comparison (ignoring time-of-day offsets):
     $$\text{today} \ge \text{dueDay}$$
   - When `today >= nextRevisionAt`, the stage is flagged as **Due**.
2. **Due Status Labels**:
   - `days < 0`: **Overdue (-Xd)** (e.g., `Overdue (2d)`)
   - `days == 0`: **Due today**
   - `days == 1`: **Due tomorrow**
   - `days > 1`: **In X days** (e.g., `In 4 days`)
   - `isFinished`: **Mastered**

---

## 4. Advancement & Completion Rules

1. **Level Step**:
   - Tapping **"Complete R{n}"** advances `currentLevel` to `n + 1`.
   - `nextRevisionAt` recalculates from completion timestamp: `now + RevisionSchedule.intervalFor(n)`.
2. **Automatic Study Logging**:
   - Every revision completion MUST insert a `StudyLog` entry with `type = StudyLogType.revisionCompleted`.
   - Updates study streaks, daily review tallies, and analytics in `ProgressController`.
3. **Terminal Stage (R5)**:
   - Completing **R5** marks `status = RevisionStatus.finished` and stamps `completedAt = now`.
   - No further due dates are scheduled (`levelsRemaining = 0`, `ladderProgress = 1.0`).
4. **Session Timer Integration**:
   - Completing a timed revision session in `SessionTimerScreen` with `isRevision: true` records elapsed minutes and calls `completeCurrentLevel()`.

---

## 5. Reset & Deletion Rules

1. **Reset to R1**:
   - Resetting an active or mastered revision resets `currentLevel = 1`, `status = RevisionStatus.active`, clears `completedAt`, and sets `nextRevisionAt = now + 1 day`.
2. **Topic Deletion Cascade**:
   - Deleting a topic removes its associated `TopicRevision` record from SQLite via `deleteByTopicId(topic.id)`.

---

## 6. UI & Presentation Rules

1. **Direct Horizontal Progression**:
   - Always render the 6-stage horizontal pipeline:
     $$\text{[Study Status]} \longrightarrow \text{[R1]} \longrightarrow \text{[R2]} \longrightarrow \text{[R3]} \longrightarrow \text{[R4]} \longrightarrow \text{[R5]}$$
   - **Study Status Node**: Reflects live topic status (`Study` / `In Prog` / `Learned`).
   - **Revision Nodes**: Display level and interval (`+1d`, `+3d`, `+7d`, `+14d`, `+30d`).
   - **Illumination**: Nodes and connecting lines illuminate as stages are reached or completed.
2. **Context-Sensitive Actions**:
   - **Completed & Not Enrolled**: Display full-width **"Add to Revision (R1)"** button.
   - **Enrolled, Completed Status & Due (`topic.status == completed && isDue`)**: Display full-width **"Complete R{n}"** button styled with `AppTheme.successColor` and `Icons.check_circle_rounded`.
   - **Enrolled & Not Completed Status (`topic.status != completed`)**: Completion button is hidden; displays a status reminder (`Mark topic as completed to continue revision`).
   - **Enrolled, Completed Status & Not Due (`!isDue`)**: Completion button is hidden; displays an unlock badge showing countdown and target date (e.g. `R2 unlocks in 3 days (19 Oct)`).
   - **Mastered**: Display green **"Topic mastered! All 5 revision stages completed."** banner.
