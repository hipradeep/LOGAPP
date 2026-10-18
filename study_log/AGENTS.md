# Study Log Agent & Phased Execution Protocol

Dedicated autonomous execution agent and operational guidelines for the **Study Log** Flutter application (`study_log/`).

---

## 1. Workspace Permissions & Autonomous Execution
* **Pre-Approved Workspace Access**: The agent has full read, write, create, and modification permissions across the `study_log/` codebase.
* **Autonomous Operations**: The agent is authorized to create, update, refactor, and reorganize files directly to fulfill user requirements without stopping to ask repetitive conversational confirmations (e.g. "May I edit this file?").
* **Git Operations**: `git status`, `git diff`, `git add`, and `git log` are pre-approved. Automatically stage, commit, and push when the user mentions `#CNP`.

---

## 2. Phased Implementation Protocol & Command Permissions

### A. Continuous Flutter Analysis (`flutter analyze`)
* **Unconditional Permission Granted**: For `study_log/`, permission is **permanently and continuously granted each time and at any time** to execute:
  ```powershell
  # Cwd: study_log
  flutter analyze
  ```
* **Every Time Usage**: Run `flutter analyze` whenever needed—after code edits, during debugging, at the end of each phase, or before/after any changes to verify zero errors and maintain clean diagnostics. No conversational permission is required.

### B. Strict Build APK Restriction (Intermediate Phases)
* **STRICT RULE**: `flutter build apk` is **STRICTLY PROHIBITED** during intermediate phases (Phase 1 through Phase N-1).
* Never execute an APK build until **all** planned implementation phases are complete.

### C. Final Phase Completion (Build & Analysis)
* **Permission Granted**: At the end of the **final phase (Phase N)**, both analysis and APK build permissions are **fully granted**:
  1. Run `flutter analyze` in `study_log` to confirm overall project health.
  2. Run `flutter build apk` in `study_log` to produce the verified Android build.

---

## 3. Self-Healing Build Failure & Retry Protocol

If `flutter build apk` fails at the end of the final phase, execute the following autonomous remediation cycle:

```
[Build Fails] 
     │
     ▼
[Run `flutter analyze`] ──► Pinpoint compile, typing, or lint issues
     │
     ▼
[Inspect Gradle / Error Logs]
     │
     ▼
[Apply Code / Config Fixes]
     │
     ▼
[Run `flutter analyze` to Verify Clean State]
     │
     ▼
[Re-run `flutter build apk`]
     │
     ├──► Fails again? ──► Repeat loop (analyze -> fix -> build)
     └──► Succeeded!   ──► Report final status to user
```

* Build and analysis permissions remain **continuously granted** throughout this recurring failure-recovery loop until a clean build is achieved.

---

## 4. Execution Permissions
* `flutter analyze`: Permission is **granted each time and at any time** within `study_log/` to check diagnostics, lint, and verify clean compilation.
* For multi-phase workflows:
  * **Every phase / edit**: `flutter analyze` granted.
  * **End of all phases**: `flutter analyze` + `flutter build apk` granted.
  * **Strict condition**: Build APK **only and strictly** at the end of all phases.

---

## 5. Architectural & Quality Standards
* **Data Layer**: SQLite via `DatabaseService` is the single source of truth (see [persist_rules.md](file:///c:/Users/hipradeep/Documents/android_apps/log_app/study_log/docs/persist_rules.md)).
* **State Management**: Zero-dependency `ChangeNotifier` controllers. Surgical rebuilds via `ListenableBuilder` / `AnimatedBuilder`.
* **Theme & Spacers**: Strictly use `AppTheme` design tokens and `AppSpacers` (`VGapMd()`, `HGapSm()`). Never hardcode colors or use raw `SizedBox` spacers.
* **Optimization**: Adhere to the Anti-Gravity 32-rule audit (`const` gravity, build method $\le$ 40 lines, $O(1)$ lookups, list virtualization).
