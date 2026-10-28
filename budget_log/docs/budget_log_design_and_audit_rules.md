# Budget Log: Design and Audit Rules

> Index and quick reference for the current `budget_log` architecture and review
> rules.
>
> Status: current as of 2026-10-28.

---

## Document map

| Document | Use it for |
| --- | --- |
| [Design guide](budget_log_design.md) | Current architecture, schema, navigation, domain flows, SMS pipeline, sync, testing |
| [Audit guide](budget_log_audit_guide.md) | Severity-ranked findings, pass/fail checklists, release gates |
| [Profile plan](profile_screen_plan.md) | Profile and Settings organization intent |
| [Multi-budget plan](multiple_budgets_and_tag_mapping_plan.md) | Multi-budget (max 3), tag mapping table, expense/income tag selectors, 70% threshold |
| [SMS parser notes](sms_parser/README.md) | Parser-specific reference |
| [Legacy Firebase plan](budget_app_plan.md) | Historical `budget_app` Firestore plan. Stale; do not use as current architecture |

---

## Architecture at a glance

```text
Flutter UI
  -> ChangeNotifier controllers
    -> DatabaseService
      -> budget_log.db (SQLite, WAL, foreign keys)

CloudSyncController
  -> DatabaseBackupService -> JSON
  -> GoogleAuthService -> Firebase Auth
  -> GoogleDriveService -> Drive appDataFolder

Android SMS receiver/scanner
  -> sms_capture.jsonl + native validation queue
  -> SmsBridge -> SmsInboxController -> SQLite
  -> native notification -> SmsBridge
```

Rules:

- SQLite is the source of truth.
- Firebase is authentication only. No Firestore persistence.
- Google Drive stores one replaceable backup file; there is no merge protocol.
- SMS capture is native; Dart handles parsing, staging, and review.
- Controllers are `ChangeNotifier` singletons registered with `get_it`.
- UI state uses `AppProvider` for theme and finance, and `ListenableBuilder` for
  other controllers.

---

## Current navigation

Three bottom tabs:

| Index | Tab | Screen |
| --- | --- | --- |
| 0 | Home | `HomeScreen` |
| 1 | Budgets | `BudgetScreen` |
| 2 | Profile | `ProfileScreen` |

The full transaction log is pushed from Home's "View all" action. It is not a
bottom tab. Manage Budgets is pushed from Home and Budget.

Subscriptions and Udar are pushed from Profile. Settings is pushed from the
Profile header. SMS inbox is pushed from Settings or a validation notification.

Tab screens use `TabHeader`. Pushed screens use `CustomAppBar`.

---

## Data rules

- Schema version: 3.
- Database: `budget_log.db`.
- Foreign keys are enabled on every connection.
- WAL is enabled on open.
- IDs are text; generated ids use `prefix_uuid`.
- Timestamps are epoch milliseconds.
- Money is SQLite `REAL`, formatted as INR with `en_IN`.
- Nested budget data is JSON text.
- A maximum of three active budgets is enforced in `DatabaseService`.
- Budget expense/income tag mappings live in `budget_tags`, unique by
  `(budget_id, type)`, with cascade delete from `budgets`.
- Legacy `transactions.budget_id` matching applies only when a budget has no
  explicit mapping row.
- Backup format version is 2 and includes `budgetTags`; version 1 remains
  importable.
- Backup export blanks raw SMS bodies and excludes `active_account_email`.
- Restore is a destructive full replacement inside one transaction.

Schema changes require all of:

1. A schema version increment.
2. An ordered migration branch.
3. New indexes for new query paths.
4. Updates to backup column allow-lists.
5. A database test.

---

## SMS rules

- Manual and background scans are limited to the last 30 days.
- Background capture is enabled by default and can be disabled by the user.
- The receiver applies the candidate filter; the manual native scanner does not.
- Dart parsing rejects OTPs, failures, promotions, non-bank senders, and messages
  without bank context.
- Duplicate checks: stable id, then amount + account reference + timestamp within
  five seconds.
- Acceptance requires the staged row to still be `pending`.
- Acceptance inserts the transaction and any debt records in one SQLite
  transaction.
- Accept and reject remove the native validation entry and resync the queue.
- SMS notifications show Validate and Ignore actions.
- Validate currently auto-accepts with the first matching category and first
  payment mode. This is a known P1 risk in the audit guide.

---

## Design rules

- Material 3; platform default Roboto; no `google_fonts`.
- Exactly one brand accent; neutral surfaces; semantic success, warning, and
  error colors.
- Use `Color.withValues(alpha: ...)`. Never use `Color.withOpacity()`.
- Use `AppSpacers` (`VGap*`, `HGap*`) for layout gaps.
- Use theme text styles, not literal font sizes, for new UI.
- Use shared widgets for empty states, FABs, headers, confirmations, transaction
  tiles, and sheets.
- Keep new files focused. Do not add to the monolithic budget screen.
- Destructive actions require a confirmation dialog.

---

## Review quick gate

Before merging:

- [ ] `flutter analyze` is clean.
- [ ] `flutter test` passes.
- [ ] No `.withOpacity()` was added.
- [ ] New spacing uses `AppSpacers`.
- [ ] New data paths use transactions and indexes.
- [ ] New budget paths enforce the three-active limit and tag-mapping semantics.
- [ ] New SMS paths preserve the 30-day rule and deduplication.
- [ ] New sync paths preserve backup redaction and account-email exclusion.
- [ ] New UI has empty, loading, and error states.
- [ ] Privacy and manifest impact was considered.

Before release:

- [ ] All P0 findings in the audit guide are closed.
- [ ] All P1 findings are closed or explicitly accepted.
- [ ] SMS and notification actions are tested on a physical device.
- [ ] Drive restore is tested on a clean install.
- [ ] Release signing and Play SMS policy are confirmed.
- [ ] `flutter build apk` is run only with explicit authorization.

---

## Legacy notice

`budget_app_plan.md` describes the original `budget_app` Firebase application:
Firestore collections, `in.logapp.budget`, glassmorphism, and `google_fonts`.
It is retained for history only. It does not describe `budget_log` and must not
be used for implementation or review decisions.

The migration plan and profile plan contain useful historical intent but may
also lag the code. When documents conflict, prefer:

1. The current source code.
2. [Design guide](budget_log_design.md).
3. [Audit guide](budget_log_audit_guide.md).
4. Older planning documents.

---

## Maintenance

Update the design guide whenever any of these change:

- Schema, migrations, or backup format.
- Controller or service registration.
- Navigation or route ownership.
- SMS ingestion, validation, or notification actions.
- Cloud sync behavior.
- Theme tokens or shared component conventions.

Update the audit guide when a finding is fixed, accepted, or reclassified. Keep
evidence references current.

Run `flutter analyze` after documentation-only changes only if a command is
already authorized for the active phase.
