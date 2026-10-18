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

1. **Strict Due-Date Advancement Invariant**:
   - **In any case, a topic will NOT advance to the next revision level ($R_n \to R_{n+1}$) before its scheduled due date** (`now < dueDay` / `!isDueAt(now)`).
   - Any review, study timer completion, or checkmark interaction before the due date only updates `levelStatus = TopicStatus.completed` for the current level.
   - Advancing to $R_{n+1}$ is strictly gated until the scheduled due date arrives (`isDueAt(now) == true`).
2. **Advancing on / after Due Date**:
   - When `isDueAt(now)` is true, completing the review advances `currentLevel` to $n + 1$ and resets `levelStatus` to `notStarted`.
   - `nextRevisionAt` recalculates from completion timestamp: `now + RevisionSchedule.intervalFor(n)`.
3. **Automatic Study Logging**:
   - Every revision completion (early or due) inserts a `StudyLog` entry with `type = StudyLogType.revisionCompleted`.
   - Updates study streaks, daily review tallies, and analytics in `ProgressController`.
4. **Terminal Stage (R5)**:
   - Completing **R5** marks `status = RevisionStatus.finished` and stamps `completedAt = now`.
   - No further due dates are scheduled (`levelsRemaining = 0`, `ladderProgress = 1.0`).
5. **Session Timer Integration**:
   - Completing a timed revision session in `SessionTimerScreen` with `isRevision: true` records elapsed minutes and marks the revision completed. If not due, it marks `levelStatus = completed` without advancing level.

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

---

## 7. Dual-Phase Model: Initial Study Phase vs. Revision Level Lifecycle

1. **Initial Study Phase (Curriculum Phase)**:
   - Tracks first-time learning on the core `Topic` model.
   - Determined by `topic.completedAt` and `topic.status` (`notStarted`, `inProgress`, `completed`).
   - For all topics enrolled in spaced repetition, the initial study phase is already finished (`topic.isCompleted == true`).

2. **Revision Level Lifecycle (`levelStatus`)**:
   - Each revision level ($R_1 \dots R_5$) manages its own cycle independently via `TopicRevision.levelStatus`:
     - **`notStarted`** (Empty circle outline): Newly enrolled in revision or freshly advanced to the level.
     - **`inProgress`** (Purple circular progress ring): Review or revision session currently in progress.
     - **`completed`** (Green checkmark with strikethrough): Review completed for this level's cycle.

3. **Leading Indicator Tap Behavior (3-State Progression)**:
   - **First Tap (`notStarted` $\to$ `inProgress`)**: Sets the topic to active review for this level.
   - **Second Tap (`inProgress` $\to$ `completed`)**:
     - *Before Due Date*: Marks the cycle completed for this level without advancing.
     - *On / After Due Date*: Completes the cycle and advances to the next level ($R_{n+1}$), resetting `levelStatus` fresh to `notStarted`.
   - **Third Tap (`completed` $\to$ `notStarted`)**: Unchecks/reverts the cycle back to not started.
   - **Silent Interaction**: Tapping the leading indicator toggles status instantly without toast/snackBar notifications.

4. **Strict Interval Lock (No Early Advance Under Any Circumstances)**:
   - **Early Review Completion (Before Due Date)**:
     - When a learner completes a revision ahead of its scheduled due date (`!isDueAt(now)`), the topic is marked `completed` (`levelStatus = TopicStatus.completed`) with a green checkmark for today.
     - The topic **strictly remains at its current repetition level ($R_n$)** and keeps its original unlock schedule (`nextRevisionAt`).
     - Spacing intervals are absolute and will never be shortened or bypassed early.
   - **Advancing to the Next Repetition Level ($R_n \to R_{n+1}$)**:
     - **On / After Due Date Only**: Promotion to $R_{n+1}$ can only occur once the calendar due date arrives (`isDueAt(now) == true`).
     - **No Early Advancement Override**: There is no button, shortcut, or manual bypass to advance to $R_{n+1}$ prior to the scheduled due date.

---

## 8. Group Module Details (GMD) Presentation & Header Rules

1. **Entity Header Status Badge Format**:
   - Header badge reflects the active module revision level and its combined topic cycle status:
     - **`R{n}: Not Started`**: Neutral outline badge when no topics have started the current level.
     - **`R{n}: In Progress`**: Primary/purple badge when topics are in progress or partially completed.
     - **`R{n}: In Progress • X Due`**: Warning/amber badge when one or more topic due dates have arrived.
     - **`R{n}: Completed`**: Success/green badge when all topics in the module are completed for this cycle.
     - **`Mastered`**: When all topics in the module have completed $R_5$.
   - The active level $R_n$ is dynamically computed from $\min(\text{currentLevel})$ among the module's active revision topics.

2. **Entity Header Metadata**:
   - **Progress Counter**: Combines topic completion counts (`X/Y Completed`), not an artificial module level.
   - **Timestamp**: Displays the most recent topic update timestamp (`lastTopicUpdatedAt`).

3. **Scroll Physics**:
   - Use standard `ClampingScrollPhysics()` on topic lists in GMD screens; do not use bouncing scroll physics.

---

## 9. Topic Details Page (Repetition Tab) Presentation & Interaction Rules

1. **Left-Right Swipeable Tabs**:
   - The screen employs a `PageView` with `ClampingScrollPhysics` wrapping the **Notes** (page 0) and **Progress / Repetition** (page 1) tabs.
   - Tapping the tab header animates smoothly between views via `PageController.animateToPage`.
   - Swiping left or right automatically updates the tab underline indicator via `onPageChanged`.
   - Each page is enclosed in a keep-alive wrapper (`AutomaticKeepAliveClientMixin` with `wantKeepAlive: true`) to preserve scroll offsets and draft notes across swipes.

2. **Streamlined Pipeline Layout**:
   - The vertical repetition pipeline floats directly in the scrollable view without redundant outer card containers, border boxes, or duplicate `"Repetition"` / `"R1 Active"` section labels (all context is already present in the screen header badge).

3. **In-Pipeline 3-State Toggle**:
   - Tapping the current level glyph in the vertical pipeline cycles directly through `notStarted` $\to$ `inProgress` $\to$ `completed` $\to$ `notStarted` without toast messages.

4. **Concrete Dates on Pipeline Nodes (Instead of Days Intervals)**:
   - All stages in the repetition ladder (Study Phase, cleared levels, active level, and upcoming levels) display their exact scheduled/projected calendar dates (e.g., `Completed on 16 Oct, 2026`, `21 Oct, 2026`) directly underneath the stage label instead of abstract interval strings (`+3d interval`) or status text (`Ready for repetition`, `Completed for this interval`).

