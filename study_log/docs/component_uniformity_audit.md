# Study Log — Component Uniformity Audit

> Verification of shared-component adoption across every screen and sheet.
> Companion to [`design_system_audit.md`](./design_system_audit.md) (tokens/themes).
> This doc answers: *does every screen use the shared component when one exists,
> and where can it be improved?*
>
> Scope: `lib/screens/` (26 files) + `lib/widgets/` (47 files).
> Counting: "sites" = real constructor / static-helper call sites (doc-comment
> mentions excluded). Evidence is line-numbered against the current tree.

Legend: ✅ healthy adoption · ⚠️ under-used · ❌ dead / no live consumer.

---

## 1. Shared Component Catalog

| Component | File | Consumers | Verdict |
|---|---|---|---|
| `AppSpacers` (`VGap*`/`HGap*`) | `widgets/app_spacers.dart` | 61 files | ✅ |
| `CustomAppBar` | `widgets/custom_app_bar.dart` | 18 screens | ✅ |
| `SheetContainer` / `SheetHeader` / `SheetHandleBar` | `widgets/sheet_action_widgets.dart` | 10 files | ✅ |
| `StudyConfirmationDialog` | `widgets/study_confirmation_dialog.dart` | 10 files (17 sites) | ✅ |
| `CourseIconChip` | `widgets/course_icon_chip.dart` | 10 files | ✅ |
| `AddPillButton` | `widgets/add_pill_button.dart` | 7 screens | ✅ |
| `CompactListItem` | `widgets/compact_list_item.dart` | 7 consumers | ✅ |
| `TabHeader` | `widgets/tab_header.dart` | 4 screens (Home, Revision, Profile, TODO) | ✅ |
| `UnderlineInputField` / `BorderlessDescriptionField` | `widgets/study_text_fields.dart` | 4 screens | ✅ |
| `EntityDetailHeader` (+ `DetailStatusBadge`) | `widgets/entity_detail_header.dart` | 3 files | ✅ |
| `AppEmptyState` | `widgets/app_empty_state.dart` | **2** screens vs 8 hand-rolled clones | ⚠️ |
| `CourseContextPill` | `widgets/course_context_pill.dart` | 2 sites | ⚠️ |
| `ModuleContextPill` | `widgets/module_context_pill.dart` | 2 sites (+1 unused import) | ⚠️ |
| `TopicListItem` | `widgets/topic_list_item.dart` | 2 screens | ⚠️ |
| `TodoListItem` | `widgets/todo_list_item.dart` | 1 screen | ⚠️ |
| `todo_group_header` | `widgets/todo_group_header.dart` | 1 screen | ⚠️ |
| `AppBackButton` | `widgets/app_back_button.dart` | 1 (only via `CustomAppBar`) | ⚠️ |
| `PillButton` | `widgets/pill_button.dart` | **2, both dead files** → 0 live | ❌ |
| `ActivityCard` | `widgets/activity_card.dart` | 0 | ❌ dead |
| `ActivityListTile` | `widgets/activity_list_tile.dart` | 0 | ❌ dead |
| `FullScreenPage` | `widgets/full_screen_page.dart` | 0 | ❌ dead |
| `TopicStatusLabel` | `widgets/topic_status_label.dart` | 0 | ❌ dead |
| `TopicProgressHeader` | `widgets/topic_progress_header.dart` | 0 | ❌ dead |
| `EditCourseSheet` | `widgets/edit_course_sheet.dart` | 0 | ❌ dead |
| `ProfileSheet` | `widgets/profile_sheet.dart` | 0 | ❌ dead |
| `AddModuleSheet` | `widgets/add_module_sheet.dart` | 0 | ❌ dead |
| `RevisionCompletionDialog` | `widgets/revision_completion_dialog.dart` | 0 (only a commented-out ref at `revision_detail_screen.dart:317`) | ❌ dead |

**Zero-consumer shared components:** `PillButton`, `ActivityCard`, `ActivityListTile`,
`FullScreenPage`, `TopicStatusLabel`, `TopicProgressHeader`, `EditCourseSheet`,
`ProfileSheet`, `AddModuleSheet`, `RevisionCompletionDialog`.
`DetailMetaChip` is only used inside `entity_detail_header.dart`.
`SheetActionRow` / `SheetCancelButton` / `SheetDestructiveButton` are only used by
`session_timer_screen` and the option sheets.

---

## 2. Screen Verification Matrix

Raw `SizedBox(` = count of literal spacers that should be `VGap*`/`HGap*`.
Verdict = adoption of shared components for that screen.

| # | Screen | Shared components used (sites) | VGap/HGap | Raw `SizedBox` | Verdict |
|---|---|---|---|---|---|
| 1 | `activity_screen.dart` | CustomAppBar 1 | 3/0 | 1 | ✅ |
| 2 | `add_course_screen.dart` | CustomAppBar, AddPillButton ×2, UnderlineInputField, BorderlessDescriptionField | 11/3 | 1 | ⚠️ sheet + pickers hand-rolled |
| 3 | `add_module_screen.dart` | CustomAppBar, AddPillButton, CourseContextPill, UnderlineInputField, BorderlessDescriptionField | 1/0 | 0 | ✅ |
| 4 | `add_topic_screen.dart` | CustomAppBar, AddPillButton, ModuleContextPill, UnderlineInputField, BorderlessDescriptionField | 1/0 | 0 | ✅ |
| 5 | `archived_courses_screen.dart` | CustomAppBar, CourseIconChip | 4/2 | 0 | ⚠️ own empty state + list row |
| 6 | `archived_course_detail_screen.dart` | CustomAppBar, CourseIconChip | 10/9 | 0 | ⚠️ own rows/headers/empty |
| 7 | `archived_topic_detail_sheet.dart` | SheetContainer/Header/HandleBar/Badge/CancelButton | 4/2 | 0 | ✅ |
| 8 | `courses_screen.dart` | CustomAppBar, AddPillButton, CompactListItem, CourseIconChip | 5/2 | 0 | ⚠️ own search field + empty state |
| 9 | `course_detail_screen.dart` | CustomAppBar, AddPillButton ×2, CourseContextPill, CompactListItem | 6/1 | 0 | ⚠️ own module row/empty/tabs |
| 10 | `home_screen.dart` | TabHeader | 7/3 | 2 | ⚠️ greeting header + progress dialog inline |
| 11 | `main_navigation_screen.dart` | **none** | **0/0 (no import)** | 1 | ❌ hand-rolled nav; no spacers |
| 12 | `module_detail_screen.dart` | CustomAppBar, AddPillButton ×2, EntityDetailHeader, DetailStatusBadge, StudyConfirmationDialog ×2, TopicListItem ×2 | 8/0 | 1 | ⚠️ inline FAB, own empty/header |
| 13 | `my_progress_screen.dart` | CustomAppBar | 11/10 | 6 | ❌ 5 public cards defined here, not in `widgets/` |
| 14 | `notification_settings_screen.dart` | CustomAppBar | 14/9 | 0 | ⚠️ own tiles, chips, dialogs, TextField |
| 15 | `profile_screen.dart` | TabHeader | 6/8 | 1 | ⚠️ own menu card/rows + duplicated progress dialog |
| 16 | `recent_activity_screen.dart` | CustomAppBar | 9/8 | 9 | ⚠️ own rows, date strip, empty, badges |
| 17 | `revision_detail_screen.dart` | CustomAppBar, EntityDetailHeader, DetailStatusBadge, TopicListItem | 3/0 | 1 | ⚠️ private `_RevisionFAB`, own empty |
| 18 | `revision_screen.dart` | TabHeader, AppEmptyState, CompactListItem, CourseIconChip | 7/9 | 4 | ⚠️ own filter sheet, chips, rows |
| 19 | `session_setup_screen.dart` | CustomAppBar, SheetContainer/Header/HandleBar (1 of 3 sheets) | 17/11 | 2 | ⚠️ 2 sheets hand-rolled, own buttons |
| 20 | `session_timer_screen.dart` | SheetContainer ×2, SheetHeader ×2, SheetHandleBar ×2, SheetActionRow ×4, SheetCancelButton ×2 | 18/6 | 5 | ⚠️ hand-rolled top bar + ElevButtons |
| 21 | `settings_screen.dart` | CustomAppBar, StudyConfirmationDialog | 7/5 | 3 | ⚠️ own tiles/cards, 4 AlertDialogs, 5 TextButtons |
| 22 | `splash_screen.dart` | **none** | 2/0 | 0 | ✅ (immersive by design) |
| 23 | `todo_detail_edit_screen.dart` | CustomAppBar, AddPillButton, StudyConfirmationDialog, UnderlineInputField, BorderlessDescriptionField | 10/9 | 0 | ⚠️ own subtask rows + direct TextField |
| 24 | `todo_screen.dart` | TabHeader, AppEmptyState, TodoListItem, todo_group_header | 1/0 | 1 | ✅ |
| 25 | `topic_detail_screen.dart` | CustomAppBar, EntityDetailHeader, DetailStatusBadge ×3, StudyConfirmationDialog ×2 | 5/13 | 5 | ⚠️ own FAB, tabs, headers; unused text-field import |
| 26 | `upload_json_screen.dart` | CustomAppBar | 5/6 | 2 | ⚠️ own info cards, module labels, button |

**Highest raw-`SizedBox` counts:** `recent_activity_screen` (9), `my_progress_screen` (6),
`topic_detail_screen` (5), `session_timer_screen` (5), `revision_screen` (4).

---

## 3. Duplication Catalog

### 3.1 Components re-implemented instead of shared

| Gap | Hand-rolled sites | Shared component that exists | Action |
|---|---|---|---|
| Empty states | 8 clones: `courses_screen:297`, `archived_courses_screen:167`, `recent_activity_screen:1058`, `revision_detail_screen:606`, `home_screen:598`, `archived_course_detail_screen:797`, `course_detail_screen:468`, `module_detail_screen:1156` | `AppEmptyState` | Replace all 8; only `revision_screen` + `todo_screen` use it today |
| Confirm dialogs | `settings_screen:188/703`, `notification_settings_screen:530`, `session_timer_screen:552`, `edit_course_sheet:117`, `share_course_json_sheet:82` | `StudyConfirmationDialog` | `edit_course_sheet:117` duplicates the existing `showDeleteCourse` helper |
| Bottom sheets | `session_setup_screen:104/214`, `add_course_screen:127`, `revision_screen:261`, `add_module_sheet:23`, `appearance_sheet:17`, `profile_sheet:12`, `edit_course_sheet:18`, `revision_interval_sheet:12` | `SheetContainer`/`SheetHeader`/`SheetHandleBar` | 9 sheets bypass the shell |
| Buttons | `session_setup_screen:493/679`, `session_timer_screen:597/627`, `module_detail_screen:850`, `settings_screen:200/717`, `notification_settings_screen:494/502/551/559`, `topic_detail_screen:1133/1210`, `upload_json_screen:782`, `share_course_json_sheet:_ActionButton:381` | `PillButton` (0 live consumers), themed `ElevatedButton` | Adopt one button pattern |
| Text fields | `courses_screen:156`, `notification_settings_screen:414`, `todo_detail_edit_screen:583`, `add_module_sheet`, `edit_course_sheet` | `UnderlineInputField` | Replace search + form fields where applicable |
| List rows | `archived_courses_screen`, `archived_course_detail_screen`, `course_detail_screen`, `recent_activity_screen`, `settings_screen`, `notification_settings_screen`, `profile_screen`, `revision_screen`, `upload_json_screen`, `todo_detail_edit_screen` | `CompactListItem` | Consolidate where structure matches |
| FABs | `topic_detail:_TopicFloatingActionButton:436`, `revision_detail:_RevisionFAB:413`, inline at `module_detail:951`, `todo_detail_edit:345` | none (create one) | 4 variants |

### 3.2 Duplicate private widget definitions across files

| Private name | Files (class line) | Similarity |
|---|---|---|
| `_TabItem` | `course_detail_screen.dart:275` · `topic_detail_screen.dart:903` | **byte-identical** |
| `_SectionHeader` | `profile_screen.dart:588` · `settings_screen.dart:472` | identical except fontSize 11 vs 10.5 |
| `_TileDivider` | `settings_screen.dart:872` · `notification_settings_screen.dart:1021` | same Divider; indent 48 vs 42 |
| `_Dot` | `move_to_revision_dialog.dart:288` · `revision_completion_dialog.dart:433` | **byte-identical** |
| "Connecting to Google…" dialog | `home_screen.dart:224` · `profile_screen.dart:148` | **copy-pasted block**, identical text/styles |
| Two-colour progress bar | `study_schedule_card.dart:152` · `topic_progress_header.dart:61` | same logic, radius 2 vs 4, height 4 vs 6 |
| Sheet handle (36–40×4 Container) | `revision_screen:1228` · `session_setup:122` · `add_course:145` · `profile_sheet:51` · `revision_interval_sheet:35` | 5 copies of `SheetHandleBar` |
| Section header (uppercase, ls 0.8) | `profile:588` · `settings:472` · `recent_activity:1013` · `revision:946` · `notification:_SectionLabel` · `upload_json:581` | 6 variants |
| Tab strip (underline tabs) | `course_detail:_CourseTabsRow` · `topic_detail:_TopicTabsRow:862` | 2 variants |
| Filter/toggle chips | `revision_screen:701/748/797/872/1535`, `notification:_SlotToggleChip:836`, `add_module_sheet:_StatusChip`, `recent_activity:_DateStripPill:653`, `course_detail:_CourseTabsRow`, `topic_detail:_TopicTabsRow` | 0 uses of Material `Chip(` anywhere |

---

## 4. Gaps by Component Type

### Headers
- 18 screens ✅ `CustomAppBar`; 4 ✅ `TabHeader`; 3 immersive (by design).
- ❌ `session_timer_screen:_buildTopBar:1036` hand-rolls a top bar (title + STRICT badge + gear).
- ⚠️ `home_screen:_HomeGreetingHeader:216` and `profile_screen:_UserProfileCard:142`
  stack custom headers on top of `TabHeader` — acceptable, but both hand-roll title text styles.
- ⚠️ All screen headers emit raw `TextStyle`; `AppTheme.heading*` used in **0 of 26 screens**.

### Buttons
- `PillButton` has **0 live consumers** (only dead `add_module_sheet` + `edit_course_sheet`).
- Every CTA is a bespoke `ElevatedButton` / `FilledButton` / `TextButton.styleFrom`:
  `session_setup` (2), `session_timer` (2), `module_detail` (1), `settings` (7),
  `notification_settings` (4), `topic_detail` (2), `upload_json` (1), `share_course_json_sheet` (`_ActionButton:381`).
- `OutlinedButton(` = **0 occurrences** app-wide.
- 4 FAB variants (see §3.1).

### Text fields
- ✅ Shared used in 4 form screens (`add_course`, `add_module`, `add_topic`, `todo_detail_edit`).
- ⚠️ Hand-rolled: `courses_screen:156` (search), `notification_settings_screen:414`
  (reminder dialog), `todo_detail_edit_screen:583` (subtask rows — same screen also
  uses shared fields), `add_module_sheet`, `edit_course_sheet`.
- ⚠️ No shared search-bar component; `courses_screen:_CoursesSearchBar:126` is the only search UI.

### Empty states
- ⚠️ Only 2 consumers (`revision_screen:571`, `todo_screen:134`) vs **8 structural clones**.
  `courses_screen:_CoursesEmptyState:297` is an exact clone (same pastelIndigo box, 30px icon, VGap sequence).

### Dialogs
- ✅ `StudyConfirmationDialog` in 10 files / 17 sites.
- ⚠️ 12 files use direct `showDialog(` (17+ sites); see §3.1 for confirms that duplicate the shared helper.
- ❌ `module_detail_screen:_showModuleCompletedDialog:759` is a theme twin of the dead `revision_completion_dialog.dart`.
- ⚠️ `showDatePicker` at 4 sites and `showTimePicker` at 4 sites with no shared wrapper
  (only `todo_detail_edit` themes its picker via `_buildPickerTheme`).

### Bottom sheets
- ✅ 10 sheets use the shared shell.
- ⚠️ 9 sheets hand-roll the container/handle (see §3.1).

### List rows
- ✅ `CompactListItem` in 7 consumers; still 10 files hand-roll rows (§3.1).

### Section headers / chips / progress bars
- ⚠️ 6 section-header variants, 0 Material `Chip(` uses, 2 two-colour progress-bar
  implementations, `LinearProgressIndicator` raw in `course_detail` + `archived_course_detail`.

### Spacers
- ✅ `AppSpacers` in 61 files; ❌ `main_navigation_screen.dart` imports none (0 VGap/HGap).
- ⚠️ 88 raw `SizedBox(` remain, heaviest in §2.

### Typography
- ⚠️ `AppTheme.heading*`/`body*` used in **0 of 26 screens** (only 7 widgets); screens emit
  200+ raw `TextStyle(` literals. `GoogleFonts.inter` directly used only in `todo_detail_edit` (2).

---

## 5. Dead & Under-Used Inventory

**Dead widget files (0 consumers):**
`activity_card.dart`, `activity_list_tile.dart`, `full_screen_page.dart`,
`topic_status_label.dart`, `topic_progress_header.dart`, `edit_course_sheet.dart`,
`profile_sheet.dart`, `add_module_sheet.dart`, `revision_completion_dialog.dart`
(+ `utils/responsive.dart` reachable only from `full_screen_page.dart`).

**Under-used (1–3 consumers):** `AppEmptyState`, `CourseContextPill`,
`ModuleContextPill`, `TopicListItem`, `TodoListItem`, `todo_group_header`,
`PillButton` (0 live), `AppBackButton`.

**Unused imports / buried utilities:**
- `module_detail_screen.dart:9` imports `module_context_pill.dart` but never uses `ModuleContextPill`.
- `topic_detail_screen.dart:21` imports `study_text_fields.dart` solely for `UrlLauncherHelper`
  (a utility class buried in a text-fields file — consider moving to `lib/utils/`).

---

## 6. Per-Screen Fix Checklist

Priority: **P0** = duplicated shared component with an exact twin · **P1** = shared shell/adoption gaps · **P2** = cleanup.

### P0 — Swap for the exact shared component
- [ ] `courses_screen.dart` — `_CoursesEmptyState:297` → `AppEmptyState`; `_CoursesSearchBar:156` → `UnderlineInputField`.
- [ ] `archived_courses_screen.dart` — `_ArchivedEmptyState:167` → `AppEmptyState`; `_ArchivedCourseRow:93` → `CompactListItem` where structure matches.
- [ ] `recent_activity_screen.dart` — `_EmptyLogsPlaceholder:1058` → `AppEmptyState`; `_StudyLogListItem:1118`; section header → shared.
- [ ] `revision_detail_screen.dart` — `_RevisionTopicsEmptyState:606` → `AppEmptyState`.
- [ ] `home_screen.dart` — `_EmptyOngoingModulesCard:598` → `AppEmptyState`; extract "Connecting to Google…" dialog (`:224`) into a shared widget used by `profile_screen:148` too.
- [ ] `archived_course_detail_screen.dart` — `_ArchivedEmptyDetail:797` / `_ArchivedNoModulesCard` → `AppEmptyState`.
- [ ] `course_detail_screen.dart:468` + `module_detail_screen.dart:1156` — inline "No modules/topics" → `AppEmptyState`.
- [ ] `edit_course_sheet.dart:117` — delete AlertDialog, call existing `StudyConfirmationDialog.showDeleteCourse`.
- [ ] Dedupe `_TabItem` (course_detail/topic_detail), `_SectionHeader` (profile/settings), `_TileDivider`, `_Dot`.

### P1 — Adopt shared shell / unify patterns
- [ ] `session_setup_screen.dart` — sheets `:104` and `:214` → `SheetContainer` shell; buttons `:493`/`:679` → shared button.
- [ ] `add_course_screen.dart:127` — sheet → `SheetContainer`.
- [ ] `revision_screen.dart:261` (`_RevisionFilterSheet:1199`) — → shared shell (drop own handle `:1228`).
- [ ] `appearance_sheet`, `profile_sheet`, `revision_interval_sheet`, `add_module_sheet`, `edit_course_sheet` — hand-rolled containers → `SheetContainer`/`SheetHeader`/`SheetHandleBar`.
- [ ] `session_timer_screen.dart:1036` `_buildTopBar` — use `CustomAppBar`; dialog buttons → shared.
- [ ] `settings_screen.dart` — `_SettingsTile:522`/`_SettingsCard:494` → `CompactListItem`; confirms `:188`/`:703` → `StudyConfirmationDialog`.
- [ ] `notification_settings_screen.dart` — `_NotificationOptionTile`, `_SlotToggleChip`, `_SlotRowItem`, delete confirm `:530`, `TextField:414` → shared equivalents.
- [ ] `profile_screen.dart` — `_MenuTile:665`/`_ProfileMenuCard` → `CompactListItem`; dedupe Google dialog with home_screen.
- [ ] Consolidate 4 FAB variants into one shared FAB helper.
- [ ] Consolidate the 2 two-colour progress bars (`study_schedule_card:152`, `topic_progress_header:61`) into one.

### P2 — Cleanup & consistency
- [ ] `main_navigation_screen.dart` — import `app_spacers.dart`; replace raw `SizedBox`.
- [ ] Replace raw `SizedBox(` with `VGap*/HGap*` in the 5 heaviest screens (§2).
- [ ] Delete dead widgets: `activity_card`, `activity_list_tile`, `full_screen_page`,
      `topic_status_label`, `topic_progress_header`, `edit_course_sheet`, `profile_sheet`,
      `add_module_sheet`, `revision_completion_dialog` (+ unused `utils/responsive.dart`).
- [ ] Remove unused imports (`module_detail_screen:9`); move `UrlLauncherHelper` out of `study_text_fields.dart`.
- [ ] `my_progress_screen.dart` — move the 5 public cards (`StreakHighlightsCard`,
      `StrikeHeatmapCard`, `SummaryStatsCard`, `WeeklyProgressActivity`, `ActivityBreakdownCard`)
      into `lib/widgets/`.
- [ ] Replace screen-level raw `TextStyle(` with `AppTheme.heading*`/`body*` typography getters.
- [ ] Introduce a shared `AppFab` and (optionally) a shared search-bar / section-header component.

---

*Generated from a full grep-level cross-reference of `lib/` (73 files). Re-run after
remediation to confirm adoption. See `design_system_audit.md` for token/theme rules.*
