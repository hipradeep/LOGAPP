---
trigger: always_on
---

# Designing Screens Using FullScreenPage

This rule defines the guidelines for layout spacing, structure, and padding when building screens with the reusable `FullScreenPage` widget.

## 1. Top Gap and App Bar Header Spacing
* The `FullScreenPage` widget automatically positions a fixed glassmorphism app bar at the top of the screen when `title` or `showBackButton` is provided.
* It reserves layout space at the top using a top gap equal to `statusBarHeight + 72.0` (the standard header padding).
* **Rule**: Do NOT add excessive top margins at the beginning of the `children` list that compound this gap. 
  * E.g., inside the children list, use `const VGapMd()` (16px) or `const VGapSm()` (8px) before the first element to keep the layout tight.
  * Example in [expense_category_screen.dart:L149](file:///c:/Users/hipradeep/Documents/android_apps/log_app/lib/screens/expense_category_screen.dart#L149):
    ```dart
    children: [
      const VGapMd(), // Kept compact to prevent a huge gap below the app bar
      _buildSectionLabel(),
    ]
    ```

## 2. Nested List Padding (Flutter ListView Gotcha)
* Flutter's `ListView` and `ListView.builder` widgets add default vertical padding to avoid notches and status bars when nested inside a scrollable screen.
* **Rule**: When nesting a `ListView.builder` inside the `children` list of `FullScreenPage`, **always** set its padding to zero to prevent a huge, unwanted gap before the list items start:
  ```dart
  ListView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    padding: EdgeInsets.zero, // CRITICAL: Overrides default nested padding
    itemCount: items.length,
    itemBuilder: (context, index) => ItemWidget(data: items[index]),
  )
  ```

## 3. Screen-Level Padding Configuration
* By default, `FullScreenPage` applies `AppTheme.defaultScreenPadding` (24px horizontal).
* If full-bleed elements (e.g. edge-to-edge cards with background fills) are needed:
  * Set `padding: EdgeInsets.zero` on the `FullScreenPage`.
  * Manually wrap static labels and text elements in `Padding(padding: const EdgeInsets.symmetric(horizontal: 24))` to ensure alignment.

## 4. Optimization & Performance Rules
* Always adhere to the rules in [optimize.md](file:///.agents/rules/optimize.md):
  * **Rule 1 (Const Gravity)**: Ensure static text, styling, and icons are wrapped with `const`.
  * **Rule 2 (Build Method Gravity)**: Keep the screen's main `build` method under ~40 lines. Extract complex list item cards or sheet widgets into dedicated stateless widgets.
  * **Rule 5 (List Gravity)**: Always render lists using `ListView.builder` rather than static mapping for dynamic data.

## 5. Theming, Spacers & Constants
* Always follow the guidelines in [aa-rules.md](file:///.agents/rules/aa-rules.md):
  * **Colors & Typography**: Use `AppTheme` colors (e.g., `AppTheme.primaryColor`, `AppTheme.textSecondary`) and typography (e.g., `AppTheme.bodySmall`).
  * **Spacers**: Never use raw `SizedBox(height: ...)` or `SizedBox(width: ...)` for spacing. Always use predefined spacer classes from `AppSpacers` (e.g., `VGapMd()`, `HGapSm()`).
