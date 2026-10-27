# Reward System Implementation Plan

Port the implemented `log_app` Stars + Diamonds reward system into `study_log`.

## Status

- Analysis complete.
- Design decisions locked.
- No code changes made yet.
- Target: derived Stars + Diamonds, automatic reward rules, optional Topic difficulty.

## 1. Reference System Analysis (`log_app`)

### What is actually implemented

- `Activity.points` is the base reward, default `10`; the add-activity UI offers `+5`, `+10`, `+20`, `+50 XP`.
- `Activity.weight` is a priority multiplier: Low `1.0`, Medium `2.0`, High `3.0`.
- Daily stars are derived from the current day's completion state:

  ```text
  dailyStars = sum(activityProgress * activity.points)
  maxStars   = sum(activity.points for scheduled activities)
  ```

- Activity progress depends on `trackingType`:
  - `single`: check-in count / target count.
  - `multiple`: completed subtasks / total subtasks.
  - `milestone`: completed tasks / total tasks.
  - `avoidance`: inverted completion.
- A diamond is awarded for a 100% weighted completion day.
- Total diamonds are counted across history.
- Streak is consecutive scheduled/active days; skippable days do not break it.
- Check-in feedback shows `Rewarded N Stars`.
- There is no persistent wallet, coin ledger, shop, level, or badge implementation.
- `hinotes/coin_system.md` and the activity completion weightage documents are design-only and are not implemented in any app.

### Important divergence

`log_app` has a daily activity schedule, so `maxStars` is the sum of scheduled activity points.

`study_log` has no equivalent daily activity plan, so this port replaces `maxStars` with a configurable **daily star goal**.

## 2. Locked Design Decisions

- Port **Stars + Diamonds + perfect-day streak**.
- Do **not** implement the full XP/coin economy, wallet, shop, or badges.
- Use automatic reward rules for all entity types.
- Add one optional user input: Topic difficulty weight.
- Add no new dependencies.

## 3. Reward Rules

| Action | Stars | Notes |
|---|---:|---|
| Topic completed | `50 * topic.weight` | Weight default `1.0`; Low `1x`, Medium `2x`, High `3x` |
| Topic revision level cleared | R1 `20`, R2 `25`, R3 `30`, R4 `40`, R5 `50` | Awarded when the level is completed, including early completion; revoked on uncheck or reset |
| Study session | `2 * minutes` | Minimum `1`; from `studySession` and `todoSession` logs |
| Todo completed | `10 * priority.weight` | Reuses existing `TodoPriority.weight`, giving 10/20/30 |
| Subtask completed | `2` | Revoked when unchecked |
| Module completed | `+100` | Once per module; revoked if the module reopens |
| Course completed | `+300` | Optional; only if course reopen handling is added |
| Daily goal | `100` default | Options: 50, 100, 150, 200 |

### Derived values

```text
dailyStars       = sum of reward events for the local calendar day
dailyGoal        = persisted setting, default 100
isPerfectDay     = dailyStars >= dailyGoal
totalStars       = sum of all reward events
level            = (totalStars ~/ 500) + 1
xpIntoLevel      = totalStars % 500
xpForNextLevel   = level * 500 - totalStars
perfectDayStreak = consecutive perfect days ending today or yesterday
```

- The existing `ProgressController.currentStreak` remains the study streak.
- Add a separate **perfect-day streak** based on diamond days.
- Do not replace the existing streak logic.

## 4. Architecture

### 4.1 Persistence

Add a difficulty weight to topics:

```sql
ALTER TABLE topics ADD COLUMN weight REAL NOT NULL DEFAULT 1.0;
```

Add a reward ledger so historical stars are stable and revocable:

```sql
CREATE TABLE IF NOT EXISTS reward_events (
  id         TEXT PRIMARY KEY,
  action     TEXT NOT NULL,
  entityId   TEXT NOT NULL,
  courseId   TEXT,
  moduleId   TEXT,
  topicId    TEXT,
  points     INTEGER NOT NULL,
  weight     REAL NOT NULL DEFAULT 1.0,
  multiplier REAL NOT NULL DEFAULT 1.0,
  earnedAt   TEXT NOT NULL,
  createdAt  TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_reward_events_earnedAt
  ON reward_events(earnedAt);
CREATE INDEX IF NOT EXISTS idx_reward_events_action
  ON reward_events(action);
CREATE INDEX IF NOT EXISTS idx_reward_events_course
  ON reward_events(courseId);
```

Use deterministic IDs to make awards idempotent:

- `topic_completed:<topicId>`
- `revision_level:<topicRevisionId>:<level>`
- `todo_completed:<todoId>`
- `subtask_completed:<subtaskId>`
- `module_completed:<moduleId>`
- `session:<studyLogId>`

`RewardService` must check whether the event already exists before inserting so duplicate save paths do not re-award stars or re-trigger toasts.

### 4.2 New files

| File | Purpose |
|---|---|
| `lib/models/reward.dart` | `RewardAction`, `RewardEvent`, `RewardDay`, `RewardSummary`, `RewardAward` |
| `lib/services/reward_rules.dart` | Constants, point formulas, level math, weight labels |
| `lib/services/reward_service.dart` | Award/revoke methods, summary queries, award broadcast stream |
| `lib/controllers/reward_controller.dart` | `ChangeNotifier`, summary state, DB listener, daily goal persistence |
| `lib/screens/rewards_screen.dart` | Detailed rewards dashboard |
| `lib/widgets/reward_summary_card.dart` | Home summary card |
| `lib/widgets/reward_highlights_card.dart` | Profile/progress summary card |
| `lib/widgets/reward_week_strip.dart` | Seven-day star/diamond strip |
| `lib/widgets/reward_toast_host.dart` | Global reward toast listener |

### 4.3 Modified files

| File | Change |
|---|---|
| `lib/models/topic.dart` | Add `double weight` to fields, constructor, `copyWith`, `toMap`, `fromMap` |
| `lib/services/database_service.dart` | Create `reward_events`, migrate `topics.weight`, clean reward rows in `clearAllData` |
| `lib/services/service_locator.dart` | Register `RewardService` and `RewardController`; warm up the controller |
| `lib/services/database_backup_service.dart` | Export/import/delete `rewardEvents`; default imported topic weight; refresh reward controller after import |
| `lib/main.dart` | Add global scaffold messenger key; wrap `MaterialApp.builder` with `RewardToastHost` |
| `lib/services/navigation_service.dart` | Add static `scaffoldMessengerKey` |
| `lib/screens/topic_detail_screen.dart` | Award/revoke topic completion |
| `lib/screens/module_detail_screen.dart` | Award/revoke topic and module completion |
| `lib/screens/session_timer_screen.dart` | Award topic completion and study-session stars |
| `lib/controllers/topic_revision_controller.dart` | Award/revoke revision levels |
| `lib/controllers/todo_controller.dart` | Award/revoke todo, subtask, and pomodoro session stars |
| `lib/screens/add_topic_screen.dart` | Add difficulty selector and persist weight |
| `lib/screens/home_screen.dart` | Insert reward summary card after `TodayProgressCard` |
| `lib/screens/profile_screen.dart` | Add reward highlights card and Rewards menu entry |
| `lib/screens/my_progress_screen.dart` | Add reward highlights card and week strip |
| `lib/screens/settings_screen.dart` | Add Daily Star Goal tile and picker sheet |
| `lib/controllers/revision_controller.dart` | Optional module-revision bonus; otherwise no change |

## 5. Service and Controller Design

### `RewardRules`

Pure, unit-testable functions:

```text
topicCompletion(topic)        -> 50 * topic.weight
revisionLevel(level)          -> 20, 25, 30, 40, 50
studySession(minutes)         -> max(1, minutes) * 2
todoCompletion(priority)      -> 10 * priority.weight
subtaskCompletion()           -> 2
moduleCompletion()            -> 100
courseCompletion()            -> 300
levelFor(totalStars)          -> totalStars ~/ 500 + 1
weightLabel(weight)           -> Low / Medium / High
```

### `RewardService`

Responsibilities:

- Insert and revoke reward events.
- Emit `RewardAward` objects on a broadcast stream for toasts.
- Load the current summary:
  - today's stars
  - daily goal
  - today's breakdown by action
  - last seven days
  - total stars
  - level and level progress
  - total diamonds
  - perfect-day streak
- Backfill existing data once for upgrading installations.
- Recompute a topic event when a completed topic's weight changes.

All queries use the SQLite date prefix:

```sql
substr(earnedAt, 1, 10)
```

### `RewardController`

- Lazy singleton registered in `service_locator.dart`.
- Loads `RewardSummary` on warmup.
- Subscribes to `DatabaseService.onDatabaseChanged`.
- Debounces reloads by roughly 200 ms.
- Reloads on:
  - `reward_events`
  - `topics`
  - `topic_revisions`
  - `todos`
  - `todo_subtasks`
  - `study_logs`
  - `modules`
  - `courses`
  - `all`
- Persists the daily goal through `getSetting` and `setSetting` using the key `reward_daily_goal`.
- Exposes `setDailyGoal(int)`.

## 6. Award and Revoke Hooks

### Topic completion

Award when status changes to `completed`; revoke when it changes away from `completed`.

Call sites:

- `lib/screens/topic_detail_screen.dart` in `_handleStatusChanged`.
- `lib/screens/module_detail_screen.dart` in `_toggleTopicStatus`.
- `lib/screens/session_timer_screen.dart` in `_handleDoneAndNext`.

Because the event ID is `topic_completed:<topicId>`, the same topic cannot be awarded twice.

### Revision levels

In `lib/controllers/topic_revision_controller.dart`:

- `completeCurrentLevel`: award the level that was cleared.
- Early completion through `setLevelStatus(completed)`: award the current level.
- Unchecking a completed level: revoke the current level.
- `resetTopicRevision`: revoke all levels at or above the reset level.
- `_reconcileDueEarlyCompletions`: award silently, without a toast.

Event ID:

```text
revision_level:<topicRevisionId>:<level>
```

### Todos and subtasks

In `lib/controllers/todo_controller.dart`:

- `updateStatus`:
  - Transition to `done`: award `todo_completed`.
  - Transition away from `done`: revoke `todo_completed`.
- `toggleSubtask`:
  - Complete: award `subtask_completed`.
  - Uncheck: revoke `subtask_completed`.
- `recordPomodoroCompleted`: award the study-session event after adding its log.

The existing auto-complete behavior in `toggleSubtask` may award both the subtask and the todo; this is intentional.

### Study sessions

Award `2 stars per minute` after each session log is added:

- `lib/screens/session_timer_screen.dart`
- `lib/controllers/todo_controller.dart` in `recordPomodoroCompleted`

Event ID:

```text
session:<studyLogId>
```

Sessions are immutable, so they are never revoked.

### Module completion

Award `+100` in the module completion log helper:

- `_recordModuleCompletionLog` in `lib/screens/module_detail_screen.dart`.

Revoke in:

- `_removeModuleCompletionLog` in the same file.

Event ID:

```text
module_completed:<moduleId>
```

### Deletion cleanup

Deleting an entity must remove its reward events:

- Topic: rows with matching `topicId`.
- Todo: rows with `entityId = todoId` plus subtask events.
- Subtask: row with `entityId = subtaskId`.
- Module: rows with matching `moduleId`.
- Course: rows with matching `courseId`.
- Full clear: delete all `reward_events`.

Do this inside the existing delete methods/transactions in `DatabaseService` so all delete entry points are covered.

## 7. UI Plan

### Reward toast

- `RewardService` emits an award stream.
- `RewardToastHost` listens to the stream and shows a floating snackbar using the star icon and `+N stars`.
- Coalesce multiple awards triggered in the same interaction.
- Never show toasts during startup reconcile or backfill.

### Home

Insert `RewardSummaryCard` immediately after `TodayProgressCard` in `lib/screens/home_screen.dart`.

Contents:

- Star icon and `Today's stars`.
- `earned / daily goal`.
- Linear progress bar.
- Diamond count.
- Perfect-day streak.
- Tap opens `RewardsScreen`.

### Rewards screen

Sections:

1. Level hero card: level, total stars, progress to next level.
2. Today's breakdown by action.
3. Seven-day star strip with diamond markers.
4. All-time totals: total stars, diamonds, perfect days, best perfect-day streak.
5. Daily goal chips: 50, 100, 150, 200.
6. Reward rules legend.

### Profile and My Progress

- Add `RewardHighlightsCard` between the user/streak sections.
- Add `RewardWeekStrip` on My Progress.
- Add a `Rewards` menu tile in the profile menu.

### Settings

Add a `Daily Star Goal` tile under PREFERENCES.

- Show the current goal as the subtitle.
- Tapping opens a bottom sheet with goal options.
- Persist through `RewardController.setDailyGoal`.

### Add Topic

Add a difficulty selector to `lib/screens/add_topic_screen.dart`:

- Low `1x`, default.
- Medium `2x`.
- High `3x`.

Persist through `Topic.weight` on create and edit.

## 8. Backup, Import, and Backfill

### Export

Add `rewardEvents` to `exportAllToJson` and bump the backup version to `2`.

### Import

- Delete `reward_events` before restoring.
- Import `rewardEvents` when present.
- Default topic `weight` to `1.0` for old backups.
- Refresh `RewardController` explicitly after import because change events are suppressed during restore.

### One-time backfill

Run when `reward_backfill_v1_done` is not set.

Seed events from existing data:

- Completed topics from `completedAt`.
- Done todos from `completedAt`.
- Completed subtasks from `completedAt`.
- Study sessions from `study_logs`.
- Revision levels from `revisionCompleted` logs, falling back to current revision state.
- Completed modules from module status and `updatedAt`.

Set the setting after completion.

Backfill is approximate for old revision levels because per-level timestamps may not exist.

## 9. Edge Cases and Invariants

- Award IDs are deterministic, so duplicate save paths cannot double-award.
- Unchecking revokes the event, matching `log_app` behavior.
- Re-completing after a revoke creates a new event with the new date.
- Day grouping uses the local ISO date prefix.
- Changing the daily goal re-evaluates historical diamonds. Add a `reward_days` snapshot table later if diamond history must be frozen.
- Stars are never negative.
- Reward loading is debounced to avoid excessive queries.
- Import and cloud-sync paths must refresh the reward controller explicitly.
- Archiving keeps stars; deletion removes them.
- Topic difficulty changes on an already-completed topic update that topic's existing reward event.
- Course completion bonus remains optional because the current code has no course-reopen flow to revoke it.

## 10. Implementation Phases

### Phase 1: Data and rules

1. Add `Topic.weight` and the `topics` migration.
2. Add `reward_events` and indexes.
3. Add `RewardRules`.
4. Add `RewardService`.
5. Add deletion cleanup.
6. Register services and warm up the controller.

### Phase 2: Award and revoke hooks

1. Topic completion.
2. Revision levels.
3. Todos and subtasks.
4. Study sessions.
5. Module completion.
6. Silent awards during reconcile.
7. Topic weight re-computation.

### Phase 3: UI

1. Reward toast host.
2. Home summary card.
3. Rewards screen.
4. Profile and My Progress cards.
5. Settings daily goal.
6. Add Topic difficulty selector.

### Phase 4: Backup and backfill

1. Export/import `rewardEvents`.
2. Old-backup defaults.
3. Clear-all handling.
4. One-time backfill.

### Phase 5: Verification

1. Run `flutter analyze` after each phase.
2. Manual checks:
   - Complete/uncomplete a topic.
   - Complete/uncheck a revision level and reset R-levels.
   - Complete/uncheck a todo and a subtask.
   - Finish a timer session and a pomodoro.
   - Complete a module and confirm the `+100` bonus appears once.
   - Change the daily goal and confirm diamonds and perfect-day streak update.
   - Export, clear, import, and confirm rewards restore.
   - Change a completed topic's difficulty and confirm its reward updates.
   - Confirm startup reconcile and backfill do not show toasts.
3. Run `flutter build apk` only after all phases are complete.

## 11. Assumptions

- `Stars` is the display unit; the internal column is `points`.
- The daily star goal replaces `log_app`'s scheduled-max because `study_log` has no daily activity plan.
- Reward values are tunable constants in `RewardRules`; changing them does not require a schema migration.
- The course completion bonus is optional.
- No new packages are required.
