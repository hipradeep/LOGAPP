# Firebase App Modular Migration Design Plan

This design plan outlines how to migrate `log_app_firebase` from its current monolithic, layer-first layout (where controllers, screens, and models of all features are mixed together) to an **Option 2 (Modular Features)** local package architecture.

This migration keeps the app independent and complies with the rules in [firebase_log_rules.md](file:///c:/Users/hipradeep/Documents/android_apps/log_app/.agents/rules/firebase_log_rules.md).

---

## 1. Current Monolithic vs Target Modular Structure

Currently, `log_app_firebase/lib/` is structured by layer:
*   `lib/controllers/` (contains all controllers for Notes, Expenses, Quick Actions, etc.)
*   `lib/screens/` (contains all screens for Notes, Expenses, Dashboard, Quick Actions, etc.)
*   `lib/models/` (contains all models for Notes, Expenses, CheckIns, etc.)
*   `lib/services/` (contains Firebase, Sync, and Auth services)

### Key Disadvantages:
*   **High Coupling:** Modifying a controller can accidentally break unrelated features because imports and schemas are highly coupled.
*   **Poor Maintainability:** Finding related code for a single feature (e.g. Pomodoro) requires opening four or five directories.
*   **Difficult to Manage Feature Toggles:** Toggling features on/off dynamically requires editing complex conditional imports and navigation trees.

### Target Architecture:
We will group code by feature, placing them in local packages inside `/packages/` under the `log_app_firebase` directory:

```
log_app_firebase/
  ├── android/
  ├── ios/
  ├── pubspec.yaml              # References local packages via path dependencies
  │
  ├── lib/                      # Shell Runner
  │    ├── main.dart            # Initializes Firebase and registers modules
  │    └── app_shell.dart       # Coordinates navigation tabs and main drawer
  │
  └── packages/                 # Modular feature packages
        ├── core_ui/            # Shared widgets, themes, and design tokens (AppTheme, AppSpacers)
        ├── core_services/      # Decoupled Firebase Auth, Firestore helpers, and caching
        │
        # Feature Packages (Contain their own local screens, controllers, models)
        ├── notes_module/
        │     ├── lib/
        │     │    ├── src/
        │     │    │    ├── controllers/
        │     │    │    ├── models/
        │     │    │    └── screens/
        │     │    └── notes_module.dart  # Registry entrypoint
        │     └── pubspec.yaml
        │
        ├── expenses_module/
        │     ├── lib/
        │     │    ├── src/
        │     │    │    ├── controllers/
        │     │    │    ├── models/
        │     │    │    └── screens/
        │     │    └── expenses_module.dart
        │     └── pubspec.yaml
        │
        └── pomodoro_module/
              ├── lib/
              │    ├── src/
              │    │    ├── controllers/
              │    │    ├── models/
              │    │    └── screens/
              │    └── pomodoro_module.dart
              └── pubspec.yaml
```

---

## 2. Decoupled Feature Architecture Pattern

Each feature package is self-contained. It depends on `core_ui` (for styling) and `core_services` (for Firebase operations), but is completely unaware of other features.

### Feature Module Entrypoint
Each package implements the `AppModule` interface so the core Shell can register it:

```dart
// packages/pomodoro_module/lib/src/pomodoro_module.dart
import 'package:flutter/material.dart';
import 'package:core_services/core_services.dart';

class PomodoroModule implements AppModule {
  @override
  String get id => 'pomodoro';

  @override
  String get name => 'Pomodoro Timer';

  @override
  String get description => 'Focus sessions with habit tracking';

  @override
  bool get isPremium => false;

  @override
  Future<void> initialize() async {
    // Register local controllers / Listeners
    GetIt.instance.registerLazySingleton(() => PomodoroActivitiesController());
  }

  @override
  Future<void> shutdown() async {
    // Clean up
    GetIt.instance.unregister<PomodoroActivitiesController>();
  }

  @override
  Widget buildDashboardWidget(BuildContext context) {
    return const PomodoroDashboardCard();
  }

  @override
  List<NavigationItem> getNavigationItems(BuildContext context) {
    return [
      NavigationItem(
        icon: Icons.timer,
        label: 'Focus',
        route: '/focus',
        builder: (context) => const PomodoroScreen(),
      )
    ];
  }
}
```

---

## 3. Step-by-Step Migration Steps

### Phase 1: Local Monorepo Setup (Melos)
1. Add `melos.yaml` in `log_app_firebase/`.
2. Configure Melos to match packages under `log_app_firebase/packages/*`.
3. Run `melos bootstrap` to establish cross-package dependencies.

### Phase 2: core_ui & core_services Extraction
1. **`core_ui`:** Move the styling files, themes (`AppTheme`), and spacers (`AppSpacers`) from `lib/theme/` to `/packages/core_ui`.
2. **`core_services`:** Move Firebase initialization, authentication logic (`FirebaseAuthService`), and Firestore helpers to `/packages/core_services`.

### Phase 3: Segment Features into Packages
1. For each feature (e.g. `notes`):
   * Create `/packages/notes_module/`.
   * Move related models from `lib/models/note_entity.dart` to the package.
   * Move controllers from `lib/controllers/notes_controller.dart` to the package.
   * Move screens from `lib/screens/notes_screen.dart` to the package.
   * Add `notes_module.dart` containing the module registry entry.
2. Link the package in the root app's `pubspec.yaml`.

### Phase 4: Adapt Root App Shell
1. Refactor `lib/main.dart` to register the modules in the `ModuleRegistry` during initialization.
2. Refactor the root navigation shell to query `ModuleRegistry` for dynamic tabs and screens.
3. Validate compilation, test suites, and execute `flutter build apk` to confirm build integrity.
