# Compact Screen Design Rules

This rule defines the guidelines for creating high-density, compact user interfaces that maximize information presentation while maintaining the application's premium aesthetics.

## 1. Spacing and Density Constraints
* **Use Minimal Spacers:** Avoid using `VGapMd()` or larger spacers inside dynamic cards or lists. Instead, strictly utilize:
  * `const VGapSm()` (8px) for separating logical card components.
  * `const VGapXs()` (4px) for separating labels from their associated fields or values.
  * Refer to [AppSpacers](file:///c:/Users/hipradeep/Documents/android_apps/log_app/lib/widgets/app_spacers.dart) for available constants.
* **Reduce Container Padding:** Override the default `AppTheme.defaultCardPadding` (16px) inside high-density lists or detail views. Use a custom tight padding of `12px` or `8px` instead:
  ```dart
  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0)
  ```

## 2. Scrollable & Nested List Spacing
* **Eliminate Default Scroll Padding:** When nesting a `ListView.builder` inside scrollable screen widgets (like [FullScreenPage](file:///c:/Users/hipradeep/Documents/android_apps/log_app/lib/widgets/full_screen_page.dart)), always set `padding: EdgeInsets.zero` to prevent unwanted nested padding:
  ```dart
  ListView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    padding: EdgeInsets.zero, // CRITICAL: Avoids compound vertical spacing
    itemCount: items.length,
    itemBuilder: (context, index) => ItemCard(item: items[index]),
  )
  ```
* **Top Spacing Control:** Do not compound the top glassmorphism app bar gap of `FullScreenPage` with excessive top padding. Use a maximum of `VGapSm()` at the start of the `children` list.

## 3. Horizontal Alignment and Tag Layouts
* **Row-Level Metadata:** Place supplementary metadata (dates, counters, types) side-by-side on the same line as titles rather than wrapping them vertically.
* **Tag Wrapping:** Group labels, check-in statuses, and milestone indicators inside a `Wrap` widget with tight spacing rules:
  ```dart
  Wrap(
    spacing: 6.0,
    runSpacing: 6.0,
    children: tags.map((t) => TagWidget(t)).toList(),
  )
  ```

## 4. Typography & Icon Scale
* **Step-Down Heading Sizes:** Avoid large screen-level heading styles like `AppTheme.headingMedium` (24px) for secondary sections. Use:
  * `AppTheme.headingSmall` (18px) for standard section cards.
  * `AppTheme.bodyMedium` (14px) with bold weights for subtitles and labels.
  * `AppTheme.bodySmall` (12px) for secondary context and descriptions.
  * `AppTheme.bodyMicro` (10px) for inner status pill text.
  * Refer to [AppTheme](file:///c:/Users/hipradeep/Documents/android_apps/log_app/lib/theme/app_theme.dart) for global styles.
* **Micro-scale Icons:** Limit icons in lists and tight cards to `iconSizeXs` (16px) or `iconSizeSm` (20px) to maintain a neat line-height.

## 5. Conditional Rendering
* **Zero-Size Offscreen Elements:** If an optional string property (e.g., descriptions, template instructions) is null or empty, always return `const SizedBox.shrink()` to keep layout space clean.
