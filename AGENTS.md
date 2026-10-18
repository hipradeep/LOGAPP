# Log App Workspace Agent Rules

Operational guidelines and workspace execution permissions for the `log_app` repository.

---

## 1. Workspace Permissions
- **Scope**: Full read, write, create, and refactor permissions across all subprojects (`study_log`, `hinotes`, `budget_app`, `budget_app2`, `test_app`, etc.).
- **Autonomous Execution**: The agent is authorized to edit and create files directly without conversational prompts asking for permission.
- **Git Operations**: Automatically stage, commit, and push whenever `#CNP` is specified.

---

## 2. Flutter Command Permissions

### `study_log/` Project
- **`flutter analyze`**: **Permanently and unconditionally granted each time and at any time** within `study_log/`. The agent is pre-approved to run `flutter analyze` after every change, phase, or fix to inspect diagnostics and maintain 0 errors.
- **`flutter build apk`**: Strictly prohibited on intermediate phases; permitted **only and strictly at the end of all phases**.
- **Build Recovery**: Self-healing retry cycle (`flutter analyze` -> fix -> `flutter build apk`) is fully permitted until a successful build is achieved.

### Other Projects
- Retain default policy: do not run Flutter commands unless explicitly requested or authorized.

---

## 3. Reference Rules
- See [.agents/rules/study_log_agent.md](file:///.agents/rules/study_log_agent.md)
- See [.agents/rules/workspace_permissions.md](file:///.agents/rules/workspace_permissions.md)
- See [study_log/AGENTS.md](file:///study_log/AGENTS.md)
