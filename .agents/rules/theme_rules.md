# Theme Rules & Guidelines for Screens & Components

This rule defines design and implementation requirements to ensure every screen and component in the application supports seamless dark, light, and system-wide theme switching without rendering glitches.

---

## 1. Context-Aware Dynamic Colors
* **Rule**: Never use static, hardcoded color constants (`Colors.white`, `Colors.black`, `AppTheme.surfaceColor`) for any component background, border, icon, or text.
* **Fix**: Use context-aware helpers from `AppTheme` that resolve colors dynamically based on `BuildContext`:
  ```dart
  // Correct Dynamic Usage:
  color: AppTheme.surface(context)
  color: AppTheme.background(context)
  color: AppTheme.borderColor(context)
  ```

---

## 2. Prohibition of Inline Brightness & Theme Checks
* **Rule**: Do **NOT** perform manual brightness checks or assign conditional styles using local variables (e.g. `final isDark = AppTheme.isDarkMode(context)`).
* **Fix**: Always resolve color properties directly from context using central `AppTheme` helpers (e.g. `AppTheme.textPrimaryColor(context)`).
  ```dart
  // INCORRECT (Forbidden local boolean checks):
  color: AppTheme.isDarkMode(context) ? Colors.black : Colors.white

  // CORRECT (Centralized context helpers):
  color: AppTheme.shadowColor(context)
  ```

---

## 3. Text Style Rebuild Registration (Crucial Flutter Gotcha)
* Static text style getters (e.g., `AppTheme.bodyLarge`, `AppTheme.headingSmall`) evaluate their color dynamically using a static mutable variable (`AppTheme.isDark`).
* **Rule**: If a widget is declared as `const`, or if its parent is skipped during rebuild optimizations, its text style color will **NOT** update when toggling themes unless it explicitly registers a dependency on `Theme.of(context)`.
* **Fix**: You **MUST** call `Theme.of(context)` inside the widget's `build` method to ensure Flutter schedules a rebuild when the theme changes:
  ```dart
  @override
  Widget build(BuildContext context) {
    // CRITICAL: Registers this component to rebuild on theme switch
    Theme.of(context);
    
    return Text(
      'Settings Label',
      style: AppTheme.bodyLarge, // Re-evaluated correctly upon theme change
    );
  }
  ```

---

## 3. Reactive Theme Controller Subscription
* **Rule**: Pages displaying the theme toggle selector or holding selection states **MUST** watch theme changes reactively.
* **Fix**: Use `AppProvider.watch` to read the state instead of `AppProvider.read` for interactive components (like segmented selectors):
  ```dart
  // Correct usage for reactive selector builder:
  final themeMode = AppProvider.watch<ThemeController>(context).themeMode;
  ```

---

## 4. Input Fields & Text Fields
* **Rule**: Never hardcode `Colors.white` for the `style` or `hintStyle` properties inside a `TextField` or `TextFormField`. Hardcoded white text results in invisible input text on light-themed input containers.
* **Fix**: Always resolve text styles dynamically using context-aware helpers:
  ```dart
  style: GoogleFonts.outfit(
    color: AppTheme.textPrimaryColor(context),
  ),
  ```

---

## 5. Popup Menus and Context Sheets
* **Rule**: Standard Material `PopupMenuButton` structures must be theme-adaptive.
* **Fix**: Set the popup card color to `AppTheme.surface(context)` and dynamically adjust individual item text/icon styling:
  ```dart
  PopupMenuButton<String>(
    color: AppTheme.surface(context),
    itemBuilder: (context) {
      return [
        PopupMenuItem(
          child: Text(
            'Option',
            style: TextStyle(
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
        ),
      ];
    },
  )
  ```

---

## 6. Premium Drop Shadows
* **Rule**: Avoid muddy, thick dark drop shadows in light theme (e.g., `Colors.black.withOpacity(0.2)`).
* **Fix**: Use `AppTheme.shadowColor(context)` to resolve the shadow color dynamically:
  ```dart
  boxShadow: [
    BoxShadow(
      color: AppTheme.shadowColor(context),
      blurRadius: 15,
      offset: const Offset(0, 8),
    ),
  ]
  ```

---

## 7. Standardized Context-Aware Text Styling & Colors
* **Rule**: Avoid repeating verbose inline checks (e.g. `Theme.of(context).brightness == Brightness.dark ? ...`) across multiple related elements for text and icon colors.
* **Fix**: Standardize styling and colors by using native text styles or context-aware `AppTheme` color helpers:
  ```dart
  // Correct Standardized Text Colors:
  color: AppTheme.textPrimaryColor(context)
  color: AppTheme.textSecondaryColor(context)
  color: AppTheme.textMutedColor(context)

  // Correct Standardized Text Styles (automatically themed):
  style: Theme.of(context).textTheme.bodySmall
  style: Theme.of(context).textTheme.bodyMedium
  ```
