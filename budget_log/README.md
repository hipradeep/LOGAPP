# Budget Log

Offline-first Android budget and expense tracker built with Flutter. Data lives
in a local SQLite database; Google Drive is used only for optional JSON backup
and restore. Currency is INR with Indian numbering (`en_IN`).

## Documentation

Start with the [design and audit index](docs/budget_log_design_and_audit_rules.md).

- [Design guide](docs/budget_log_design.md): architecture, schema, navigation,
  domain flows, SMS pipeline, sync, and testing.
- [Audit guide](docs/budget_log_audit_guide.md): severity-ranked findings,
  pass/fail checklists, and release gates.
- [Migration plan](docs/budget_log_migration_plan.md): historical
  Firebase-to-SQLite migration scope.
- [Profile plan](docs/profile_screen_plan.md): Profile and Settings organization.
- [SMS parser notes](docs/sms_parser/README.md): parser-specific reference.
- [Legacy Firebase plan](docs/budget_app_plan.md): historical and stale. Not
  current architecture.

## Features

- Expense and income log with search, filters, and split expenses.
- Daily, weekly, monthly, and custom budgets with one active budget.
- Categories, payment modes, and INR formatting.
- Udar (give/take) contact ledger with partial settlements.
- Subscription tracking with local reminder notifications.
- SMS capture and review for bank debit and credit messages, limited to the last
  30 days.
- Google Drive app-data backup and restore.
- Local JSON import and export.
- Light and dark Material 3 themes.

## Architecture

```text
Screens / widgets
  -> ChangeNotifier controllers (get_it)
    -> DatabaseService
      -> budget_log.db
```

- SQLite is the source of truth.
- Firebase is used for authentication only; there is no Firestore storage.
- Controllers are zero-bloc `ChangeNotifier` singletons.
- SMS ingestion runs through native Android components and a method/event
  channel bridge.
- Drive sync replaces a single backup file; it is not a merge protocol.

See the [design guide](docs/budget_log_design.md) for the full data model and
flows.

## Setup

Requirements:

- Flutter with a Dart SDK compatible with `^3.11.1`.
- Android toolchain targeting the current package `in.logapp.budget_log`.
- Firebase project configuration in `android/app/google-services.json`.
- A Google OAuth Android client registered for the package and signing SHA-1
  when testing Drive backup.

Install dependencies and run:

```powershell
flutter pub get
flutter run
```

## Verification

```powershell
flutter analyze
flutter test
```

Do not run `flutter build apk` during intermediate work. Build only at the end of
an approved phase.

## Current constraints

- Android only.
- Local database and preferences are not encrypted.
- SMS access requires `READ_SMS`; Play distribution needs a policy declaration.
- Release builds still use debug signing. Do not ship as-is.
- Raw SMS bodies are retained locally and may be included in Android Auto Backup.
  See the [audit guide](docs/budget_log_audit_guide.md) before release.
