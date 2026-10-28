# Budget Log Audit Guide

> Review rules and pass/fail checks for `budget_log`.
>
> Status: current as of 2026-10-28. Findings below are based on repository code,
> not device behavior. Re-verify on the target Android version before release.

---

## 1. How to use this guide

Use this guide for:

- Pre-merge review of changes that touch data, SMS, sync, notifications, or UI.
- Pre-release hardening.
- Periodic architecture review.

Severity levels:

| Level | Meaning |
| --- | --- |
| P0 | Data loss, privacy exposure, or security issue that blocks release |
| P1 | Serious correctness or trust issue; fix before production |
| P2 | Reliability, maintainability, or UX defect; schedule deliberately |
| P3 | Cleanup, test gap, or documentation issue |

Do not mark an item passed because the code "looks fine." Run the check or cite
the exact guard.

---

## 2. Baseline verification

Run from `budget_log/`:

```powershell
flutter analyze
flutter test
```

Expected baseline:

- `flutter analyze` reports no issues.
- Existing tests pass.
- No build command is run unless the phase explicitly authorizes it.

Manual verification for release candidates:

1. Fresh install grants SMS and notification permissions, then scans only the
   last 30 days.
2. A background bank SMS produces exactly one notification.
3. Validate and Ignore both work from a cold start and a warm start.
4. Accepting an SMS creates the transaction and removes the notification.
5. A Drive backup can be restored on a clean install.
6. Switching Google accounts with an existing cloud backup restores the expected
   data.
7. Account switching with no cloud backup does not silently destroy data.

---

## 3. Findings summary

| ID | Severity | Finding |
| --- | --- | --- |
| P0-1 | P0 | Raw SMS and financial data are stored unencrypted; Android Auto Backup is not disabled |
| P0-2 | P0 | Account switching clears local data before confirming a cloud backup exists |
| P1-1 | P1 | Notification "Validate" accepts a transaction without user review |
| P1-2 | P1 | Auth reports signed-in for Firebase-only sessions while Drive requires Google |
| P1-3 | P1 | Restore is destructive and has no pre-restore snapshot, merge, or size limit |
| P1-4 | P1 | Release uses debug signing; `READ_SMS` requires a Play policy declaration |
| P2-1 | P2 | No CHECK/UNIQUE constraints for enums, amounts, or catalog names |
| P2-2 | P2 | `ConflictAlgorithm.replace` on transactions can null linked debt ids |
| P2-3 | P2 | Full-table loads and all-domain reloads on every write |
| P2-4 | P2 | Cold-start SMS deep link helper is unused |
| P2-5 | P2 | `reminder_days_before` is stored but ignored by the planner |
| P2-6 | P2 | UI token drift and oversized screen files |
| P2-7 | P2 | SMS initialization cannot retry after a failed first attempt |
| P2-8 | P3 | Native SMS scan sends unfiltered inbox bodies across the platform channel |
| P3-1 | P3 | Highest-risk paths have no automated tests |
| P3-2 | P3 | Stream controllers are not closed by `DatabaseService.close()` |

---

## 4. Detailed findings

### P0-1: Raw SMS and financial data at rest

Evidence:

- `staged_sms_transactions.raw_body` stores the full SMS body
  (`lib/services/database_service.dart:249-262`).
- The inbox renders the raw body (`lib/screens/sms_inbox_screen.dart:511-518`).
- Backup export blanks `raw_body` only for export
  (`lib/services/database_backup_service.dart:145-148`).
- The manifest does not set `android:allowBackup="false"` or backup rules
  (`android/app/src/main/AndroidManifest.xml:10-13`).
- The native capture file uses `noBackupFilesDir`, which is good, but the SQLite
  database does not have the same exclusion
  (`android/app/src/main/kotlin/in/logapp/budget_log/sms/SmsCaptureStore.kt:40-41`).

Impact:

- SMS sender, body, account last-4, contacts, phone/UPI, notes, and transaction
  history can be captured by Android Auto Backup or extracted from an
  unencrypted device backup.
- The in-app export sanitization does not protect the database itself.

Remediation:

1. Add `android:allowBackup="false"` or a strict backup rules file that excludes
   `budget_log.db`, `shared_prefs`, and app files.
2. Add retention for staged SMS: purge rejected rows and rows older than the
   product-defined window.
3. Consider storing a redacted SMS body rather than the full body.
4. Consider SQLCipher or platform keystore-backed encryption if raw SMS must be
   retained.
5. Document the data inventory in the privacy policy.

Release gate: required.

---

### P0-2: Destructive account switching

Evidence:

- `_handlePostSignIn` clears local data when the account changes, then attempts a
  cloud restore (`lib/controllers/cloud_sync_controller.dart:278-302`).
- If `restoreDatabase()` returns null, no data is restored.

Impact:

- A user who switches to a new Google account without a backup loses all local
  transactions, budgets, contacts, debts, and subscriptions.

Remediation:

1. Download and validate the target account's backup before deleting local data.
2. If no backup exists, prompt: keep local data, export a local file, or continue
   with an empty database.
3. Keep a temporary local snapshot until the restore transaction commits.
4. Add an explicit "Switch account" confirmation that states the consequence.

Release gate: required.

---

### P1-1: Notification auto-accept

Evidence:

- `SmsInboxScreen._openInitialTarget` handles the `validate` action by calling
  `_acceptFromNotification` (`lib/screens/sms_inbox_screen.dart:72-80`).
- `_acceptFromNotification` uses the first category of the matching type and the
  first payment mode (`lib/screens/sms_inbox_screen.dart:84-109`).

Impact:

- A notification action can create a financial record without review. The
  category and payment mode may be wrong even when the amount is right.
- This is a trust and data-quality risk, especially for large amounts.

Remediation:

- Change the action label to "Review" and always open the review form.
- Or keep "Validate" but pre-fill and require confirmation of category, payment
  mode, and amount.
- Add a clear undo path after acceptance.

---

### P1-2: Auth state mismatch

Evidence:

- `isSignedIn` returns true for either a Google account or a Firebase user
  (`lib/services/google_auth_service.dart:29-30`).
- Drive operations use `_googleSignIn.currentUser` or a silent sign-in and throw
  when no Google account is available
  (`lib/services/google_drive_service.dart:35-41`).

Impact:

- The UI can show a signed-in state while backup and restore fail.

Remediation:

- Base the sync state on a live Google account with Drive scope.
- Treat Firebase-only sessions as "signed in to account, re-authenticate for
  Drive."
- Add a reconnect action and surface the error.

---

### P1-3: Destructive restore

Evidence:

- Import deletes all tables and re-inserts rows in one transaction
  (`lib/services/database_backup_service.dart:221-296`).
- There is no pre-restore local snapshot and no merge option.
- `_verifyCounts` aborts when duplicate primary keys collapse rows
  (`lib/services/database_backup_service.dart:342-358`).

Impact:

- Restoring the wrong file replaces valid local data.
- A malformed but format-valid file can abort after all tables are deleted; the
  transaction rolls back, but the user has no recovery copy if the file itself
  is wrong.
- Backup version 1 does not describe later schema features such as
  `is_autopay` or `budget_tags`. Version 2 adds `budgetTags`, but the envelope
  still is not a full schema descriptor.

Remediation:

1. Export a local safety copy before any restore.
2. Add a preview: row counts, export timestamp, and account email.
3. Version the backup against schema capabilities, not only format.
4. Add a size and row cap.
5. Consider merge-by-id as an explicit alternative to replace.

---

### P1-4: Distribution and signing

Evidence:

- Release build uses `signingConfigs.getByName("debug")`
  (`android/app/build.gradle.kts:35-40`).
- `READ_SMS` is declared
  (`android/app/src/main/AndroidManifest.xml:8`).

Impact:

- Debug signing is not acceptable for Play distribution.
- `READ_SMS` is a restricted permission; the app needs a declared core use case
  and may be rejected.

Remediation:

- Add a release keystore and signing config.
- Complete the Play SMS permission declaration.
- Provide a no-SMS mode for users who deny permission.
- Verify the OAuth client is bound to the release package and SHA-1.

---

### P2-1: Missing constraints

Evidence:

- Tables use `TEXT` and `REAL` with defaults but no `CHECK` or `UNIQUE`
  constraints (`lib/services/database_service.dart:136-278`).
- Duplicate category and payment mode names are rejected only in
  `FinanceController`.

Impact:

- Imported or SMS-created data can contain invalid types, negative amounts, or
  duplicate names.
- Aggregates and filters silently misbehave on invalid enum values.

Remediation:

- Add `CHECK` constraints for `type`, `direction`, `status`, `frequency`, and
  `period`.
- Add `CHECK (amount > 0)` where applicable.
- Add case-insensitive unique indexes for catalog names if the product requires
  uniqueness.

---

### P2-2: Replace semantics and foreign keys

Evidence:

- Transactions are written with `ConflictAlgorithm.replace`
  (`lib/services/database_service.dart:504-525, 939-943`).
- `debt_records.transaction_id` uses `ON DELETE SET NULL`
  (`lib/services/database_service.dart:225-226`).

Impact:

- Replacing a transaction with the same id is delete-plus-insert. Linked debt
  records can be nulled during the operation.

Remediation:

- Use explicit `update` for existing ids.
- Reserve `replace` for import paths where referential integrity has already been
  validated.
- Add a regression test for replace-with-linked-debt.

---

### P2-3: Full-domain reload fan-out

Evidence:

- `getTransactions()` has no limit (`lib/services/database_service.dart:490-496`).
- Every mutation re-queries and emits; every controller then re-queries its whole
  domain after a 150 ms debounce
  (`lib/controllers/finance_controller.dart:331-337`).
- The change event's table name is ignored by controllers.

Impact:

- Write latency and memory grow with transaction count.
- Budget aggregates are recomputed across all budgets and transactions on every
  change.

Remediation:

- Honor the table name and reload only affected domains.
- Add pagination or date-window limits for the log.
- Precompute monthly aggregates in SQL.
- Avoid duplicate queries between `DatabaseService` and controllers.

---

### P2-4: Cold-start SMS deep link

Evidence:

- `SmsNativeBridge.getLaunchTarget` and `SmsInboxService.getLaunchTarget` exist
  (`lib/services/sms_native_bridge.dart:52-61`,
  `lib/services/sms_inbox_service.dart:82-90`).
- No screen calls them.

Impact:

- Native keeps only one pending target. Rapid notification taps can overwrite
  each other before Dart consumes them.
- The unused Dart fallback makes the routing contract harder to reason about:
  warm-start taps replay over the event channel, while any missed intent has no
  recovery path.

Remediation:

- Consume `getLaunchTarget()` once during app startup and route it after the
  navigator is ready, or remove the helper and document event-channel replay as
  the only contract.
- Replace the single pending slot with a small queue if multiple actions can
  arrive quickly.
- Add a cold-start notification action test on a real device.

---

### P2-5: Reminder offset is ignored

Evidence:

- The database stores `reminder_days_before`
  (`lib/services/database_service.dart:239`).
- The planner always schedules D-3, D-1, and D-0 at 09:00
  (`lib/services/subscription_reminder_planner.dart`).

Impact:

- User-selected reminder settings have no effect.

Remediation:

- Either wire the field into the planner or remove it from the UI and schema.
- If keeping fixed offsets, label them clearly as fixed.

---

### P2-6: UI token drift and file size

Evidence:

- Zero `.withOpacity()` calls; 47 `.withValues()` calls currently pass the color
  rule.
- 45 `SizedBox(` occurrences exist. Thirteen are the `AppSpacers` implementation;
  the rest include legitimate explicit dimensions and some spacing use.
- `lib/screens/budget_screen.dart` is 965 lines with a monolithic build region.
- Hardcoded font sizes, radii, and paddings remain in chart and budget widgets.

Impact:

- Design changes require broad edits.
- Large build methods are hard to test and review.

Remediation:

- Extract budget cards, charts, dialogs, and section labels.
- Replace spacing-only `SizedBox` with `VGap*`/`HGap*`.
- Add named typography and radius tokens where values repeat.

Pass condition:

- No `.withOpacity()`.
- No spacing-only raw `SizedBox` outside `app_spacers.dart`.
- New UI uses theme tokens and shared components.

Verification:

```powershell
Get-ChildItem lib -Recurse -Filter *.dart |
  Select-String -Pattern '\.withOpacity\('
Get-ChildItem lib -Recurse -Filter *.dart |
  Select-String -Pattern 'SizedBox\('
```

---

### P2-7: SMS initialization cannot retry

Evidence:

- `_isInitialized = true` is set before the first load completes
  (`lib/controllers/sms_inbox_controller.dart:44-48`).

Impact:

- A transient permission or platform-channel failure leaves the inbox
  permanently uninitialized for that process.

Remediation:

- Set the flag only after success, or make `initialize()` retry-safe with an
  in-flight future and an error reset.

---

### P2-8: Unfiltered native scan boundary

Evidence:

- `SmsScanner` returns every SMS in the window
  (`android/app/src/main/kotlin/in/logapp/budget_log/sms/SmsScanner.kt:35-66`).
- The candidate filter is applied in `SmsReceiver`, not in the scanner.
- Dart parses and rejects candidates after the platform channel returns.

Impact:

- OTPs and unrelated messages cross the native-to-Dart boundary unnecessarily.

Remediation:

- Apply `SmsCandidateFilter` in `SmsScanner` before adding records.
- Keep the Dart parser as defense in depth.

---

### P3-1: Test gaps

Untested high-risk areas:

- Google auth, Drive backup/restore, account switching, auto-push.
- Notification scheduling, timezone, exact-alarm fallback, background action.
- Native SMS receiver/scanner/store/scheduler/notifier.
- Cold-start and warm-start notification actions.
- Android backup and manifest behavior.

Remediation:

- Add unit tests with fake Drive/auth clients.
- Add integration tests for notification actions using a device or emulator.
- Add a native test for the SMS queue and candidate filter.

---

### P3-2: Stream lifecycle

Evidence:

- `DatabaseService.close()` closes the database but not its stream controllers
  (`lib/services/database_service.dart:104-110`).

Impact:

- Test isolation and hot-restart behavior can leak listeners.

Remediation:

- Close all controllers in `close()` and reset the singleton for tests.

---

## 5. Audit checklists

### 5.1 Design and UI

- [ ] No `.withOpacity()` anywhere in `lib/`.
- [ ] Spacing uses `VGap*`/`HGap*`, except explicit component dimensions.
- [ ] New colors come from `AppTheme` or category tint helpers.
- [ ] New text styles come from `Theme.of(context).textTheme`.
- [ ] New pushed screens use `CustomAppBar`; tabs use `TabHeader`.
- [ ] Empty, loading, and error states exist for new data screens.
- [ ] Lists with unbounded rows are virtualized.
- [ ] Tap targets are at least 48x48 logical pixels.
- [ ] Text scaling does not clip fixed-height rows.
- [ ] Destructive actions use `ConfirmationDialog`.

### 5.2 Data and schema

- [ ] Schema version incremented for any column or table change.
- [ ] Migration handles every prior version in order.
- [ ] New columns have defaults when non-null.
- [ ] Foreign keys declare `ON DELETE` behavior.
- [ ] New query paths have supporting indexes.
- [ ] IDs remain text and timestamps remain epoch milliseconds.
- [ ] New enum-like fields are validated in code and, where possible, by `CHECK`.
- [ ] Mutations that touch multiple tables use one SQLite transaction.
- [ ] Backup allow-lists include every new column.
- [ ] Backup version or compatibility handling is updated.

### 5.3 SMS

- [ ] Dart scan window is clamped to 1-30 days.
- [ ] Native scan window is clamped to 1-30 days.
- [ ] Records older than 30 days are dropped before staging.
- [ ] Duplicate ID and amount/account/time-window checks both run.
- [ ] Background capture respects the enable flag.
- [ ] Multipart SMS bodies are joined.
- [ ] OTP, failure, and promotion messages are rejected.
- [ ] Accept requires the row to still be `pending`.
- [ ] Accept inserts transaction and debt records atomically.
- [ ] Accept and reject remove the native validation entry and resync.
- [ ] Notification actions work on warm and cold start.
- [ ] Raw SMS retention is intentional and documented.

### 5.4 Cloud sync

- [ ] Export excludes `active_account_email`.
- [ ] Export redacts raw SMS bodies.
- [ ] Restore validates format, version, and all required tables.
- [ ] Restore is transactional.
- [ ] Restore does not wipe data before a backup is confirmed.
- [ ] Account switch has an explicit confirmation.
- [ ] Auto-push cannot run during restore.
- [ ] Sync errors are visible to the user.
- [ ] Backup size and row count are bounded.

### 5.5 Privacy and manifest

- [ ] `allowBackup` or backup rules exclude sensitive files.
- [ ] `READ_SMS` and `RECEIVE_SMS` are justified and declared for Play.
- [ ] Exported receivers are protected or intentionally public.
- [ ] Release signing is configured.
- [ ] OAuth client package and SHA-1 match the release build.
- [ ] Logs do not print SMS bodies, tokens, or full account identifiers.
- [ ] Privacy policy describes SMS, contacts, Drive, and backup data.

### 5.6 Verification

- [ ] `flutter analyze` is clean.
- [ ] `flutter test` passes.
- [ ] New tests cover the changed behavior.
- [ ] A release candidate is tested on a physical device for SMS and
  notifications.
- [ ] A clean-install restore is tested with a real Drive account.
- [ ] `flutter build apk` is run only with explicit authorization.

---

## 6. Review protocol

For each change:

1. Identify touched domains: data, SMS, notifications, sync, UI.
2. Run the matching checklist sections.
3. Cite evidence with `file:line` in the review.
4. Classify findings with the severity table.
5. Do not downgrade a P0 or P1 without a written mitigation.

For release:

1. All P0 items closed.
2. All P1 items closed or explicitly accepted with an owner and date.
3. Baseline verification and manual device checks complete.
4. Release signing and Play policy confirmed.
