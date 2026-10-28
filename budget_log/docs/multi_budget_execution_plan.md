# Execution Plan: Multiple Active Budgets & Tag Mapping

> **Target App**: `budget_log`
>
> **Source Plan**: [multiple_budgets_and_tag_mapping_plan.md](multiple_budgets_and_tag_mapping_plan.md)
>
> **Schema Evolution**: v2 -> v3
>
> **Active Budget Limit**: 3 budgets (not a tag limit)

---

## 1. Locked Decisions

| Decision | Value |
|---|---|
| Active budget limit | Maximum **3 active budgets** |
| 4th active budget | Block save with a clear error |
| Tag source | Existing `categories` rows |
| Misc tags | Distinct `misc_exp` and `misc_inc` pseudo-tags |
| Category relation | `expense`, `income`, or `both` |
| Budget tag storage | One row per `(budget_id, type)` with JSON `tag_ids` |
| Transaction matching | Dynamic tag matching, not `transactions.budget_id` |
| Transaction Log dropdown | Active budgets only (maximum 3), combined with type/date/search filters |
| Threshold | Budget-level 70% alert threshold |
| Backfill | Not required; existing budgets have no mappings until edited |

---

## 2. Phase Status

| Phase | Scope | Status |
|---|---|---|
| 1 | Schema v3, `budget_tags`, max-3 enforcement, backup | **Completed** |
| 2 | `BudgetTagMapping`, `Category` relation getters, tag-aware `Budget` | **Completed** |
| 3 | `FinanceController` tag cache and aggregations | **Completed** |
| 4 | Category/Tag management UI | **Completed** |
| 5 | Add/Edit Budget tag selector and max-3 validation | **Completed** |
| 6 | Home, Budget, Manage Budgets, Transaction Log UI | **Completed** |
| 7 | Tests, design docs, final verification | **Completed** |

---

## 3. Phase 1: Database & Migration

### 3.1 Schema
- [x] Bump `DatabaseService.schemaVersion` from `2` to `3`.
- [x] Create `budget_tags`:
  - `id` TEXT primary key.
  - `budget_id` TEXT, `ON DELETE CASCADE`.
  - `type` TEXT (`exp` or `income`).
  - `tag_ids` TEXT JSON array.
  - `created_at`, `updated_at`.
  - `UNIQUE(budget_id, type)`.
- [x] Add `idx_budget_tags_lookup` on `(budget_id, type)`.
- [x] Add the table to `_onCreate`.
- [x] Add ordered `case 3` migration.

### 3.2 Active Budget Limit
- [x] Add `DatabaseService.maxActiveBudgets = 3`.
- [x] Remove blanket `is_active = 0` updates from `addBudget` and `updateBudget`.
- [x] Validate active count inside the same transaction.
- [x] Add `setBudgetActive(String id, bool active)` with the same validation.
- [x] Keep `setActiveBudget` compatible by delegating to `setBudgetActive(id, true)`.
- [x] Throw `StateError` when a 4th budget would become active.

### 3.3 Backup & Reset
- [x] Add `_budgetTagColumns`.
- [x] Add `budgetTags` to backup export.
- [x] Bump backup format version to `2`.
- [x] Accept version `1` backups without `budgetTags`.
- [x] Restore `budget_tags` inside the import transaction.
- [x] Keep missing tag mappings from older backups empty.
- [x] Delete `budget_tags` during `clearAllData`.

### 3.4 Acceptance Criteria
- [x] Fresh database reports schema version `3` and contains `budget_tags`.
- [x] A v2 database upgrades and has an empty `budget_tags` table.
- [x] Adding/activating a 4th active budget throws and leaves 3 active.
- [x] Deleting a budget removes its tag mappings.
- [x] JSON backup round-trip preserves tag mappings.
- [x] Saved v1 backups still import successfully.
- [x] `dart analyze` reports no issues in changed files.
- [x] `flutter test test/database_service_test.dart` passes (18 tests).

---

## 4. Phase 2: Domain Models

### 4.1 Budget tag mapping
- [x] Add `BudgetTagMapping` model.
- [x] Add `expenseType` / `incomeType` constants.
- [x] Add `miscExpenseTag = misc_exp` and `miscIncomeTag = misc_inc`.
- [x] Serialize `tag_ids` as a JSON string with safe parsing.
- [x] Add misc/type helper getters.

### 4.2 Category relation
- [x] `Category.isExpense` includes `both`.
- [x] `Category.isIncome` includes `both`.
- [x] Add `Category.isBoth`.

### 4.3 Tag-aware budget calculations
- [x] `spentForCurrentPeriod` accepts optional `expenseTagIds`.
- [x] Add `incomeForCurrentPeriod` accepting optional `incomeTagIds`.
- [x] Match uncategorized entries through `misc_exp` / `misc_inc`.
- [x] Fall back to `transactions.budget_id` when tags are omitted.
- [x] Forward tags through `safeToSpendDaily` and `isOverBudget`.
- [x] Extract shared period matching into `_isInCurrentPeriod`.

### 4.4 Database helpers
- [x] Add `getBudgetTags(budgetId)`.
- [x] Add `setBudgetTags(...)` with both expense and income rows.
- [x] Add `getActiveBudgets()` limited to `maxActiveBudgets`.

### 4.5 Acceptance Criteria
- [x] Mapping JSON round-trips.
- [x] Shared categories report both expense and income.
- [x] Expense/income aggregation matches selected tags and misc tags.
- [x] Legacy `budget_id` matching still works without tag lists.
- [x] Tag mappings upsert without duplicate rows.
- [x] `dart analyze` reports no issues in changed model/service files.
- [x] `flutter test` passes for model, mapping, and database tests (26 tests).

---

## 5. Phase 3: Finance Controller

### 5.1 Database helpers
- [x] Add `getAllBudgetTagMappings()` for cache loading and presence checks.
- [x] Extend `addBudget` / `updateBudget` with optional expense/income tag lists.
- [x] Write budget and tag rows in the same transaction.
- [x] Remove deleted category IDs from all tag mappings in the same transaction.
- [x] Notify `budget_tags` changes after tag writes or cleanup.

### 5.2 Shared matching
- [x] Add public `Budget.matchesTransaction(...)` for expense/income tag matching.
- [x] Keep misc pseudo-tag handling in one place.
- [x] Preserve legacy `budget_id` fallback when tag lists are absent.
- [x] Treat an explicit empty tag mapping as no matches.

### 5.3 Controller cache and selection
- [x] Load tag mappings during `_performLoad`.
- [x] Cache expense/income tag lists per budget.
- [x] Add `activeBudgets` (maximum 3) and `hasActiveBudgets`.
- [x] Add `setBudgetActive(id, active)`.
- [x] Fall back to the first active budget when the stored selection is inactive.
- [x] Add `expenseTagsForBudget` / `incomeTagsForBudget` with all-category defaults.
- [x] Add `hasBudgetTagMapping` for editing UI.

### 5.4 Aggregations and filtering
- [x] Make budget spent, income, safe-daily, and over-budget checks tag-aware.
- [x] Add `incomeForBudget`, `isThresholdExceeded`, and `isOverBudget`.
- [x] Make `transactionsForBudget` return matching expense and income transactions.
- [x] Add `LogFilter.budgetId` and include it in `isActive`.
- [x] Combine budget filtering with type, query, and date filters.
- [x] Ignore stale budget filter IDs.

### 5.5 Budget CRUD and categories
- [x] `createBudget` accepts expense/income tags and defaults to all categories plus misc tags.
- [x] `updateBudget` accepts optional tags and preserves mappings when omitted.
- [x] Normalize tags by trimming, de-duplicating, and dropping stale IDs.
- [x] Accept category type `both` in controller validation.

### 5.6 Read-path consistency
- [x] `budget_screen` uses controller budget aggregates and `transactionsForBudget`.
- [x] Daily/monthly expense graphs trust caller-scoped transactions instead of `budget_id`.
- [x] Category breakdown continues to filter expenses only.

### 5.7 Acceptance Criteria
- [x] New budgets receive default expense/income tag mappings.
- [x] Custom tags include only matching expense/income transactions.
- [x] Legacy budgets use `budget_id` until an explicit mapping exists.
- [x] Empty mappings produce zero matches.
- [x] Budget log filter combines with type, query, and date.
- [x] Selected budget falls back after deactivation.
- [x] Activating a 4th budget still throws.
- [x] Category deletion removes stale tag IDs.
- [x] `both` categories are accepted and included in both default tag sets.
- [x] Targeted `flutter test` suite passes (39 tests).
- [x] Full `flutter test` has only the three pre-existing `screens_smoke_test.dart` failures.
- [x] `dart analyze lib test` reports no new issues (existing `settings_screen.dart` warning remains).

---

## 6. Phase 4: Category/Tag Management UI

### 6.1 Category form
- [x] Replace the two-way type selector with `Expense`, `Income`, and `Both`.
- [x] Show helper copy when `Both` is selected.
- [x] Rename the form label from "Type" to "Relation".
- [x] Keep category validation and persistence unchanged.

### 6.2 Category lists
- [x] Show `both` categories in both expense and income sections.
- [x] Add a subtle `Shared` badge to `both` category rows.
- [x] Show `Expense & income` as the shared category subtitle.
- [x] Update screen and empty-state copy to mention shared categories.
- [x] Update delete confirmation to mention budget tag cleanup.

### 6.3 Category relation changes
- [x] Do not auto-migrate existing budget tag mappings when a category relation changes.
- [x] New budgets pick up the category where applicable; existing budgets remain unchanged until edited.

### 6.4 Acceptance Criteria
- [x] Category form offers all three relation options.
- [x] Selecting `Both` shows explanatory helper text.
- [x] Shared categories render in both sections with a `Shared` badge.
- [x] `test/categories_screen_test.dart` passes (2 tests).
- [x] Full `flutter test` has only the three pre-existing `screens_smoke_test.dart` failures (72 passed).
- [x] `dart analyze` reports no new issues (existing `settings_screen.dart` warning remains).

---

## 7. Phase 5: Budget Tag Selector & Active Limit

### 7.1 Selector component
- [x] Add `BudgetTagSelector` with expense/income tabs and selection counts.
- [x] Include all categories per relation, including shared and misc tags.
- [x] Add per-chip tinting, category icons, and dynamic select/deselect all.
- [x] Show an inline warning when both tag sets are empty.

### 7.2 Add/Edit budget form
- [x] Load all tags by default for new budgets.
- [x] Load persisted mappings when editing; legacy budgets fall back to defaults.
- [x] Filter loaded tag IDs against current category options.
- [x] Pass both tag lists through create and update.
- [x] Block save when both lists are empty.
- [x] Rename the legacy free-text field to "Budget label" and hide empty label pills.

### 7.3 Active budget limit
- [x] Show the 3-budget active limit in the form copy.
- [x] Warn inline when creating/activating a budget would exceed the limit.
- [x] Block save before the database call; keep the DB guard as a final check.
- [x] Allow editing a budget that is already active.

### 7.4 Acceptance Criteria
- [x] New budgets default to every expense/income tag.
- [x] Editing loads saved mappings with valid categories only.
- [x] Both tag mappings persist on create.
- [x] Fourth active budget is blocked with a friendly warning.
- [x] `test/budget_tag_selector_test.dart` and `test/add_budget_screen_test.dart` pass (6 tests).
- [x] Full `flutter test` has only the three pre-existing `screens_smoke_test.dart` failures (78 passed).
- [x] `dart analyze` reports no new issues (existing `settings_screen.dart` warning remains).

---

## 8. Phase 6: Multi-Budget Presentation

### 8.1 Shared active-budget switcher
- [x] Add `ActiveBudgetSwitcher` for up to three active budget pills.
- [x] Keep the switch compact, horizontally scrollable, and theme-aware.
- [x] Share the controller's `selectedBudget` between Home and Budget.

### 8.2 Home
- [x] Show the active-budget card without pills when only one budget is active.
- [x] Show active-budget pills when two or three budgets are active.
- [x] Render selected budget tag labels with a `+N more` overflow pill.
- [x] Show the configured alert threshold caption and progress marker.
- [x] Select the displayed budget before opening Budget management.

### 8.3 Budget screen
- [x] Resolve the selected budget from `FinanceController`, honoring `initialBudgetId`.
- [x] Show active-budget pills alongside the all-budgets selector.
- [x] Use the budget's configured `alertThreshold` for status colors.
- [x] Keep ended and inactive budgets accessible through the selector.

### 8.4 Manage budgets
- [x] Show the active-budget count against the limit.
- [x] Add activate/deactivate actions to the budget menu.
- [x] Block activation when three budgets are already active.
- [ ] Persistent drag reordering is deferred.

### 8.5 Transaction log
- [x] Add a budget filter chip with active budgets and `All budgets`.
- [x] Include the currently selected inactive budget in the picker.
- [x] Combine budget filtering with search, type, and date filters.

### 8.6 Verification
- [x] `test/multi_budget_ui_test.dart` passes (6 tests).
- [x] Full `flutter test` passes (89 tests).
- [x] `flutter analyze` reports no issues.

---

## 9. Phase 7: Test And Documentation Finalization

### 9.1 Test baseline
- [x] Register `FinanceController` in `screens_smoke_test.dart`.
- [x] Update the Budget empty-state expectation.
- [x] Exercise the full-screen transaction form with `isBottomSheet: false`.
- [x] Repair the three pre-existing smoke-test failures.

### 9.2 Copy budget
- [x] Add an explicit `isCopy` path without blanking the source ID.
- [x] Load copied expense/income tags from the source budget.
- [x] Preserve source repeat, schedule, salary, rule, and allocations fields.
- [x] Hide delete for copies and create a new record on save.
- [x] Enforce the three-active limit for copied active budgets.
- [x] Cover source preservation, copied tags, and the active-limit guard.

### 9.3 Coverage audit
- [x] Cover selecting an inactive budget from the all-budget selector.
- [x] Cover a non-default alert threshold on Home.
- [x] Keep the existing Manage, filter, and activation-limit tests.

### 9.4 Documentation
- [x] Update the design guide for schema v3, `budget_tags`, max-3, backup v2, and multi-budget UI.
- [x] Update design/audit rules and the stale backup-version note.
- [x] Record Phase 6/7 completion and the remaining reorder deferral.

### 9.5 Verification
- [x] `flutter test` passes (89 tests).
- [x] `flutter analyze` reports no issues.
- [x] `flutter build apk` succeeds (`build/app/outputs/flutter-apk/app-release.apk`).

---

## 10. Files Expected To Change

| File | Phase change |
|---|---|
| `lib/services/database_service.dart` | Schema v3, table, index, max-3, toggle API, tag helpers, reset |
| `lib/services/database_backup_service.dart` | Backup v2, `budgetTags` export/import, v1 compatibility |
| `lib/models/budget_tag_mapping.dart` | Tag mapping model and misc constants |
| `lib/models/category.dart` | `both` relation getters |
| `lib/models/budget.dart` | Tag-aware calculations and shared transaction matcher |
| `lib/controllers/finance_controller.dart` | Tag cache, active budgets, filtering, CRUD, selection, tag options |
| `lib/screens/budget_screen.dart` | Tag-aware budget aggregates, transaction list, empty-label guard |
| `lib/screens/categories_screen.dart` | Three-way relation selector, shared badge, copy updates |
| `lib/screens/add_budget_screen.dart` | Tag selector integration, tag persistence, max-3 guard, copy path |
| `lib/widgets/budget_tag_selector.dart` | Expense/income tag tabs, chips, bulk actions, empty warning |
| `lib/widgets/active_budget_switcher.dart` | Shared active-budget pills for Home and Budget |
| `lib/widgets/budget_selector_sheet.dart` | Optional `All budgets` option for filters |
| `lib/screens/home_screen.dart` | Active-budget pills, tag chips, threshold marker |
| `lib/screens/manage_budgets_screen.dart` | Active count, activate/deactivate actions, max guard, copy entry |
| `lib/screens/transaction_log_screen.dart` | Budget filter chip and filter wiring |
| `test/multi_budget_ui_test.dart` | Home, Budget, Manage, and Transaction Log UI tests |
| `lib/widgets/budget_daily_expense_graph.dart` | Accept caller-scoped budget transactions |
| `lib/widgets/budget_monthly_expense_graph.dart` | Accept caller-scoped budget transactions |
| `test/database_service_test.dart` | Migration, max-3, cascade, backup, tag helper tests |
| `test/budget_tag_mapping_test.dart` | Mapping and category relation tests |
| `test/budget_test.dart` | Tag, fallback, and matcher tests |
| `test/finance_controller_test.dart` | Controller cache, filtering, CRUD, and fallback tests |
| `test/categories_screen_test.dart` | Three-way form selector and shared category badge tests |
| `test/budget_tag_selector_test.dart` | Tag tab counts, shared categories, bulk actions, warning |
| `test/add_budget_screen_test.dart` | Defaults, edit loading, tag persistence, max-3 guard, copy path |
| `test/screens_smoke_test.dart` | Current empty-state and form coverage |
| `docs/budget_log_design.md` | Schema v3, `budget_tags`, max-3, backup v2, multi-budget UI |
| `docs/budget_log_design_and_audit_rules.md` | Schema and budget rules |
| `docs/budget_log_audit_guide.md` | Backup-version and schema notes |
| `docs/multiple_budgets_and_tag_mapping_plan.md` | Source plan status updated to implemented |

---

## 11. Deferred To Later Phases

- Persistent drag reordering in Manage Budgets. This requires a schema version,
  saved ordering, migration/backup updates, drag UI, and tests.
