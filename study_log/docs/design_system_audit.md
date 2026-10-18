# Study Log — Design System Audit

> Single reference for the visual language of the `study_log` app: the design
> tokens that already exist, the components built on top of them, the
> inconsistencies found across the codebase, and the rules + roadmap to restore
> uniformity.
>
> Scope audited: `lib/` (110 Dart files), `pubspec.yaml`, `assets/`.
> Legend: ✅ theme-driven · ⚠️ mixed (theme colors + inline/hardcoded values) · ❌ hardcoded.

---

## 1. Design Token Reference

All tokens live in two files — there is **no** `colors.dart`, `styles.dart`, or
`constants.dart`:

- `lib/theme/app_theme.dart` — source of truth for palettes, semantic colors, radii, spacing, typography, `ThemeData`.
- `lib/theme/revision_level_palette.dart` — R1–R5 + completed color triples, built from `AppTheme` pastels.

`main.dart` wires the ThemeData: `theme: AppTheme.themeData`,
`darkTheme: AppTheme.darkThemeData`, `themeMode: _themeController.themeMode`.

### 1.1 Core / semantic palette

Resolved per brightness via the private `_Palette` class. Access through
context-aware helpers (never constants at call sites).

| Token helper | Light | Dark | Role |
|---|---|---|---|
| `AppTheme.background(context)` | `0xFFF8F9FE` | `0xFF0F0F14` | Scaffold background |
| `AppTheme.surface(context)` | `0xFFFFFFFF` | `0xFF1A1A21` | Cards / sheets |
| `AppTheme.surfaceVariant(context)` | `0xFFF3F4F8` | `0xFF24242D` | Nested surfaces |
| `AppTheme.borderColor(context)` | `0xFFEEF0F5` | `0xFF2C2C36` | Primary borders / dividers |
| `AppTheme.borderSubtle(context)` | `0xFFF5F6FA` | `0xFF22222A` | Faint borders *(barely used)* |
| `AppTheme.textPrimaryColor(context)` | `0xFF18181B` | `0xFFF4F4F5` | Primary text |
| `AppTheme.textSecondaryColor(context)` | `0xFF6B7280` | `0xFFA1A1AA` | Secondary text |
| `AppTheme.textMutedColor(context)` | `0xFF9CA3AF` | `0xFF71717A` | Muted / captions |
| `AppTheme.shadowColor(context)` | `0x0C000000` | `0x40000000` | Card shadows |
| `AppTheme.badgeFill(context)` | `0xFFEDE9FE` | `0xFF2C2C3A` | Badge backgrounds |

### 1.2 Brand & feedback colors (theme-invariant)

| Token | Value | Role |
|---|---|---|
| `AppTheme.primaryColor` | `0xFF5B4DFB` | Brand violet / indigo |
| `AppTheme.primaryLight` | `0xFF7A6EFC` | Lighter brand |
| `AppTheme.primaryDark` | `0xFF4536DF` | Darker brand |
| `AppTheme.errorColor` | `0xFFEF4444` | Error / destructive |
| `AppTheme.successColor` | `0xFF10B981` | Success |
| `AppTheme.warningColor` | `0xFFF59E0B` | Warning |
| `AppTheme.textOnDark` | `0xFFFFFFFF` | Foreground on primary |
| `AppTheme.textOnDarkSecondary` | `0xFFD1D5DB` | Secondary on primary |

### 1.3 Pastel category triples (theme-aware)

Seven tints, each with `Bg` / `Text` / `Border`. Use `AppTheme.tintFor(context, index)`
for a stable per-item tint, or the individual helpers for semantic categories.

| Category | Background helper | Foreground helper | Border helper | Light fg | Dark fg |
|---|---|---|---|---|---|
| Purple | `pastelPurple` | `pastelPurpleText` | `pastelPurpleBorder` | `0xFF5B4DFB` | `0xFFA99BFF` |
| Green | `pastelGreen` | `pastelGreenText` | `pastelGreenBorder` | `0xFF10B981` | `0xFF5FD3A0` |
| Orange | `pastelOrange` | `pastelOrangeText` | `pastelOrangeBorder` | `0xFFF97316` | `0xFFFB9A5B` |
| Blue | `pastelBlue` | `pastelBlueText` | `pastelBlueBorder` | `0xFF3B82F6` | `0xFF6FB0F5` |
| Sky | `pastelSky` | `pastelSkyText` | `pastelSkyBorder` | `0xFF0284C7` | `0xFF6FC5F5` |
| Indigo | `pastelIndigo` | `pastelIndigoText` | `pastelIndigoBorder` | `0xFF4F46E5` | `0xFF9BA3F5` |
| Coral | `pastelCoral` | `pastelCoralText` | `pastelCoralBorder` | `0xFFEF4444` | `0xFFF98A8A` |

`AppTheme.tintCount = 6`. `tintFor` cycles purple → green → orange → blue → sky → indigo.

### 1.4 Revision level palette

`RevisionLevelPalette.of(context, level)` returns a `RevisionLevelColors`
(`foreground` / `background` / `border`):

| Level | Interval | Tint |
|---|---|---|
| R1 | 1 day | Purple |
| R2 | 3 days | Blue |
| R3 | 7 days | Sky |
| R4 | 14 days | Orange |
| R5 | 30 days | Coral |
| completed | — | Green (`RevisionLevelPalette.completed`) |

### 1.5 Typography scale

Google Fonts: **Outfit** for headings, **Inter** for body/action. Getters take no
context (resolve from `AppTheme.isDark`), so widgets using them must call
`Theme.of(context)` in `build` to repaint on theme change.

| Token | Font | Size | Weight | Letter spacing | Color |
|---|---|---|---|---|---|
| `headingLarge` | Outfit | 28 | bold | −0.5 | textPrimary |
| `headingMedium` | Outfit | 22 | bold | −0.3 | textPrimary |
| `headingSmall` | Outfit | 18 | w600 | 0 | textPrimary |
| `bodyLarge` | Inter | 15 | normal | 0 | textPrimary (h 1.4) |
| `bodyMedium` | Inter | 13 | normal | 0 | textSecondary (h 1.4) |
| `bodySmall` | Inter | 11 | normal | 0 | textSecondary |
| `actionText` | Inter | 13 | w700 | 0.5 | primaryColor |

These are also mapped into `ThemeData.textTheme` (`displayLarge/Medium`,
`titleLarge`, `bodyLarge/Medium/Small`) in `_buildThemeData`.

### 1.6 Radii

| Token | Value | Typical use |
|---|---|---|
| `cardBorderRadius` | 20 | Cards |
| `pillBorderRadius` | 28 | Primary buttons, pills |
| `defaultBorderRadius` | 16 | Dialogs, general containers |
| `smallBorderRadius` | 12 | Small chips/rows |
| `iconBoxRadius` | 14 | Icon containers |

> ⚠️ The single most common radius in the app is **10** (57 occurrences) and is
> **not tokenized**.

### 1.7 Spacing scale & standard metrics

| Token | Value |
|---|---|
| `spacingXs` | 4 |
| `spacingSm` | 8 |
| `spacingMd` | 16 |
| `spacingLg` | 24 |
| `spacingXl` | 32 |
| `spacingXxl` | 48 |
| `defaultScreenPadding` | `EdgeInsets.symmetric(horizontal: 20)` |
| `defaultCardPadding` | `EdgeInsets.all(18)` |
| `buttonHeight` | 52 |
| `bnbHeight` | 72 |
| `bnbActiveColor` | `0xFF5B4DFB` |
| `bnbInactiveColor` | `0xFF9CA3AF` |

Spacer widgets live in `lib/widgets/app_spacers.dart`:
`VGap{Xs,Sm,Md,Lg,Xl,Xxl}` and `HGap{Xs,Sm,Md,Lg,Xl,Xxl}`.

### 1.8 ThemeData presets

- `useMaterial3: true`
- `pageTransitionsTheme`: Cupertino transitions on all platforms
- Transparent app bar (`elevation: 0`, `scrolledUnderElevation: 0`)
- `elevatedButtonTheme`: primary bg, `onPrimary` fg, `minimumSize(0, 52)`, pill radius 28, Inter 15/w600, elevation 0
- `textButtonTheme`: primary fg
- `dialogTheme`: surface bg, radius `defaultBorderRadius`
- `bottomSheetTheme`: surface bg, top radius 28

### 1.9 Theme controller

`lib/controllers/theme_controller.dart` holds `ThemeMode`
(system/light/dark), persists to `study_theme_pref.json`, and mirrors effective
brightness into `AppTheme.isDark`.

---

## 2. Component Inventory

### 2.1 Reusable widgets — `lib/widgets/` (48 files)

| File | Purpose | Verdict |
|---|---|---|
| `app_spacers.dart` | Spacer tokens (`VGap*`/`HGap*`) | ✅ pure theme |
| `app_provider.dart` | InheritedNotifier state provider | ✅ neutral (no UI) |
| `custom_app_bar.dart` | Reusable top bar (`PreferredSizeWidget`) | ⚠️ theme colors, inline 16/11px text |
| `tab_header.dart` | BNV tab header (26px bold + 12px sub) | ⚠️ theme colors, hardcoded 26/12px |
| `app_back_button.dart` | Theme-matched back button | ✅ theme |
| `app_empty_state.dart` | Empty-state block with optional CTA | ✅ mostly theme |
| `pill_button.dart` | Primary dark pill CTA | ⚠️ |
| `add_pill_button.dart` | Outlined pastel-purple "Add" pill | ✅ theme |
| `compact_list_item.dart` | Generic compact list row (used app-wide) | ✅ mostly theme |
| `entity_detail_header.dart` | Detail header + `DetailMetaChip` / `DetailStatusBadge` | ✅ theme |
| `today_progress_card.dart` | Home "Today's Progress" card | ⚠️ mix |
| `study_schedule_card.dart` | Schedule card + `_TwoColorProgressBar` | ⚠️ mix (hardcoded `0xFFECEEF6`) |
| `recent_activity_card.dart` | Daily aggregate progress card (stateful) | ⚠️ mix, inline type |
| `your_courses_carousel.dart` | Home "Your Courses" carousel | ✅ via `AppTheme.tintFor` |
| `activity_card.dart` | Interactive activity card (featured/dark variant) | ⚠️ · **unused** |
| `activity_list_tile.dart` | Minimalist activity tile | ✅ · **unused** |
| `course_icon_chip.dart` | Rounded pastel course glyph | ✅ theme |
| `course_context_pill.dart` | Course name + icon pastel pill | ✅ theme |
| `module_context_pill.dart` | Module name + icon pastel pill | ✅ theme |
| `topic_list_item.dart` | Topic list row (wraps `CompactListItem`) | ✅ delegated |
| `todo_list_item.dart` | High-density todo row (wraps `CompactListItem`) | ⚠️ hardcoded `0xFFE8E5FF` |
| `topic_status_indicator.dart` | Circular status glyph | ⚠️ hardcoded accents |
| `topic_status_label.dart` | Caption for status indicator | ⚠️ inline 3 styles · **unused** |
| `topic_progress_header.dart` | "N / M topics" + two-color bar | ⚠️ `0xFFECEEF6` · **unused** |
| `topic_revision_badge.dart` | Spaced-repetition level badge | ✅ via palette var |
| `topic_revision_card.dart` | Revision ladder card item | ✅ theme |
| `todo_group_header.dart` | Collapsible task group header | ✅ theme |
| `sheet_action_widgets.dart` | `SheetContainer`, `SheetHeader(Badge)`, `SheetHandleBar`, action rows | ✅ shared sheet shell |
| `course_options_sheet.dart` | Course long-press options sheet | ✅ theme |
| `module_options_sheet.dart` | Module options sheet | ✅ theme |
| `topic_options_sheet.dart` | Topic options sheet | ✅ theme |
| `todo_options_sheet.dart` | Todo options sheet | ✅ theme |
| `revision_options_sheet.dart` | Revision module options sheet | ✅ theme |
| `archived_course_options_sheet.dart` | Archived course options sheet | ✅ theme |
| `add_module_sheet.dart` | Create-module sheet + `_StatusChip` | ✅ theme |
| `edit_course_sheet.dart` | Edit-course sheet | ⚠️ inline type |
| `appearance_sheet.dart` | Light/Dark/System picker sheet | ⚠️ |
| `profile_sheet.dart` | Profile action sheet | ✅ mostly theme |
| `study_text_fields.dart` | `UnderlineInputField`, `BorderlessDescriptionField`, URL helpers | ⚠️ default url color `0xFF2196F3` |
| `study_confirmation_dialog.dart` | Shared confirm dialog (12 consumers) | ✅ theme |
| `move_to_revision_dialog.dart` | Study-complete → revision dialog | ⚠️ confetti dup colors |
| `revision_completion_dialog.dart` | Revision complete dialog + confetti | ⚠️ **duplicates R1–R5 palette** |
| `revision_interval_sheet.dart` | 5-stage interval schedule sheet | ✅ theme |
| `share_course_json_sheet.dart` | Share/export course JSON + `_ActionButton` | ⚠️ |
| `full_screen_page.dart` | Generic full-screen scaffold template | ✅ theme · **unused (dead)** |

Genuinely unused: `ActivityCard`, `ActivityListTile`, `FullScreenPage`,
`TopicProgressHeader`, `TopicStatusLabel`; spacers `VGapXxl`, `HGapXl`, `HGapXxl`.
`utils/responsive.dart` is only imported by the unused `FullScreenPage`.

### 2.2 Screens — `lib/screens/` (26 files)

Nearly every screen uses `Scaffold(backgroundColor: AppTheme.background(context))`.
There are **0 raw `AppBar(`** and no `SliverAppBar` usages.

| Screen | Header pattern | Verdict |
|---|---|---|
| `splash_screen.dart` | none (immersive) | ✅ |
| `main_navigation_screen.dart` | none | ✅ hand-rolled `_StudyBottomNav` using `bnb*` tokens |
| `home_screen.dart` | `TabHeader` | ⚠️ 1 hardcoded color |
| `courses_screen.dart` | `CustomAppBar` + `AddPillButton` | ⚠️ |
| `course_detail_screen.dart` | `CustomAppBar` | ⚠️ hardcoded `_badgeColorCycle` |
| `module_detail_screen.dart` | `CustomAppBar` | ⚠️ mixed FAB style |
| `topic_detail_screen.dart` | `CustomAppBar` | ❌ 17 hardcoded (URL blue, `0xFF6366F1`) |
| `revision_screen.dart` | `TabHeader` | ⚠️ mostly theme, 2 hardcoded + `isDark` reads |
| `revision_detail_screen.dart` | `CustomAppBar` | ⚠️ private `_RevisionFAB` |
| `todo_screen.dart` | `TabHeader` | ⚠️ `FloatingActionButton.extended` |
| `todo_detail_edit_screen.dart` | `CustomAppBar` | ❌ only screen using `GoogleFonts` directly |
| `activity_screen.dart` | `CustomAppBar` | ✅ |
| `recent_activity_screen.dart` | `CustomAppBar` | ⚠️ custom `_CalendarDateStrip` |
| `my_progress_screen.dart` | `CustomAppBar` | ❌ **38 hex literals, manual `isDark` branches** |
| `profile_screen.dart` | `TabHeader` + settings icon | ⚠️ 13 hex (gradient avatar) |
| `settings_screen.dart` | `CustomAppBar` | ❌ 23 hex duplicating tokens |
| `notification_settings_screen.dart` | `CustomAppBar` | ❌ 14 hex accent colors |
| `session_setup_screen.dart` | `CustomAppBar` | ⚠️ 11 `Colors.white` |
| `session_timer_screen.dart` | none (immersive `Stack`) | ⚠️ 12 hardcoded (strict-mode orange) |
| `add_course_screen.dart` | `CustomAppBar` + save pill | ⚠️ hardcoded `_availableColors` |
| `add_module_screen.dart` | `CustomAppBar` + `AddPillButton` | ✅ |
| `add_topic_screen.dart` | `CustomAppBar` + `AddPillButton` | ✅ |
| `archived_courses_screen.dart` | `CustomAppBar` | ✅ |
| `archived_course_detail_screen.dart` | `CustomAppBar` | ⚠️ `0xFFECEEF6` |
| `archived_topic_detail_sheet.dart` | none (sheet) | ✅ theme |
| `upload_json_screen.dart` | `CustomAppBar` | ❌ **full third dark-purple palette, theme-blind** |

Screens that also define public widgets (candidates to move into `widgets/`):
`my_progress_screen.dart` (`StreakHighlightsCard`, `StrikeHeatmapCard`,
`SummaryStatsCard`, `WeeklyProgressActivity`, `ActivityBreakdownCard`),
`recent_activity_screen.dart` (`DayActivityItem`).

### 2.3 Dependencies (`pubspec.yaml`)

UI-relevant: `google_fonts ^8.0.2` (Outfit + Inter), `cupertino_icons ^1.0.8`,
`intl ^0.20.2`. No UI kit (`flutter_svg`, `lottie`, `shimmer`, `cached_network_image`,
`flutter_animate`) — consistent with the zero-dependency `ChangeNotifier` approach.
Only one asset image: `assets/images/splash_logo.png`.

---

## 3. Inconsistency Report

### 3.1 Headers / app bars

- **Two competing header widgets**: `CustomAppBar` (~20 screens) vs `TabHeader`
  (Home, Revision, Profile, TODO), plus 3 immersive screens with none
  (`splash_screen`, `session_timer_screen`, `main_navigation_screen`).
- `CustomAppBar` title = 16px bold, `letterSpacing −0.2`; `TabHeader` title =
  26px bold, `letterSpacing −0.3`. Both are hand-rolled rather than using
  `AppTheme.headingSmall` / `headingLarge`.
- Padding differs per header: `CustomAppBar` `(l:4, r:16, t:4, b:4)`,
  `TabHeader` `fromLTRB(20,12,20,8)`, `full_screen_page` `symmetric(h:20, v:12)`.

### 3.2 Buttons

Theme prescribes pill radius 28 + `minimumSize(0,52)` + Inter 15/w600, but most
`ElevatedButton.styleFrom` overrides it:

| Radius | Locations |
|---|---|
| 10 | `module_detail_screen`, `session_setup_screen` (×2), `session_timer_screen` (×2), `move_to_revision_dialog`, `revision_completion_dialog`, `study_confirmation_dialog` (×2) |
| 12 | `topic_detail_screen` (×2) |
| 8 | `settings_screen`, `add_pill_button.dart` |
| 28 (correct) | theme, `upload_json_screen`, `app_empty_state`, `pill_button` |

- Foreground is `Colors.white` in most buttons though dark theme defines
  `onPrimary = 0xFF15152B`; `pill_button` / `app_empty_state` use `AppTheme.textOnDark`. Mixed.
- Button label sizes differ: 12 / 13 / 13.5 / 14 / 15.
- **4 FAB styles**: `module_detail` + `revision_detail` (`CircleBorder`, elevation 4, primary);
  `todo_screen` (`FloatingActionButton.extended`, elevation 3, inline 13px);
  `topic_detail` (own `_TopicFloatingActionButton`).

### 3.3 Colors

- `my_progress_screen.dart` defines a second green/purple palette with manual
  `AppTheme.isDark` branches instead of `pastelGreen*` / `pastelPurple*` (38 hex).
- `upload_json_screen.dart` AI-prompt card uses an entirely dark-purple palette
  that ignores light/dark theme (18 hex).
- `settings_screen.dart` / `notification_settings_screen.dart` hardcode pastel
  icon pairs that are byte-identical (or near) to existing tokens:
  `0xFFEDE9FE` = `badgeFill`, `0xFFE0E7FF` = `indigoBorder`, `0xFFE0F2FE` = `skyBg`,
  `0xFFFEF2F2` = `coralBg`, `0xFFFEE2E2` = `coralBorder`.
- Revision-level colors defined twice: `revision_level_palette.dart` (theme-aware)
  and `revision_completion_dialog.dart:232-236` (hardcoded). Confetti dot colors
  duplicated verbatim in `move_to_revision_dialog.dart:262-267` and
  `revision_completion_dialog.dart:407-412`.
- URL highlight blue `0xFF2196F3` hardcoded in `topic_detail_screen` and
  `study_text_fields.dart`, while `pastelBlueText` (`0xFF3B82F6`) exists.
- Progress-track "remaining" color `0xFFECEEF6` hardcoded in `study_schedule_card`,
  `topic_progress_header`, `course_detail_screen`, `archived_course_detail_screen`.

### 3.4 Typography

- **348 inline `TextStyle(` vs ~46 uses of `AppTheme` text styles.**
- 25 distinct `fontSize` values incl. half-points: 8.5, 9, 9.5, 10, 10.5, 11, 11.5,
  12, 12.5, 13, 13.5, 14, 14.5, 15, 15.5, 16, 16.5, 17, 18, 20, 22, 26, 28, 30, 38.
- Weights mix near-equivalents: `bold` (130), `w600` (79), `w500` (39), `w700` (18), `w800` (2).
- `letterSpacing`: −0.2 (9), 0.8 (6), 0.2 (5), −0.5, −0.3, 0.5, 0.4, 0.3.
- **Only 17 `Theme.of(context)` calls** app-wide — needed so the context-free
  typography getters repaint. Direct `AppTheme.isDark` reads exist in
  `my_progress_screen` (×2), `revision_screen` (×2), `profile_screen` (×1).
- Callers defeat tokens: `headingSmall.copyWith(fontSize: 17, fontWeight: bold)`
  (`activity_card`), `copyWith(fontSize: 20, ...)` (`edit_course_sheet`).

### 3.5 Spacing / layout

- Screen gutters vary: **14 / 16 / 20**; `defaultScreenPadding` (20) used twice.
- 88 raw `SizedBox(` remain despite `AppSpacers`; off-scale micro values 2/3/5/6.
- 3 unused spacer tokens (`VGapXxl`, `HGapXl`, `HGapXxl`).
- De-facto standard radius **10** (57×) is not a token; tokens 8/6/4/2 also common.
- `withValues(alpha:)` has no tokens: 0.12 (33), 0.35 (19), 0.25 (15), 0.08 (10),
  0.4 (9), 0.1 (7) — mixed `0.3`/`0.30` and `0.1`/`0.10` spellings.

### 3.6 Bottom navigation

`main_navigation_screen.dart` hand-rolls `_StudyBottomNav` (Container + shadow +
InkWell, radius 16, 3px gap) using `bnb*` tokens. `bnbHeight = 72` is declared but
the nav is content-sized. No Material `NavigationBar` is used.

### 3.7 Dead code & docs

- Unused widgets: `ActivityCard`, `ActivityListTile`, `FullScreenPage`,
  `TopicProgressHeader`, `TopicStatusLabel`.
- Barely-used tokens: `borderSubtle` (1), `badgeFill` (2), `defaultScreenPadding` (2),
  `defaultCardPadding` (2), `iconBoxRadius` (2), `buttonHeight` (4), `tintFor` (3).
- Code comments reference a `theme_rules` document ("theme_rules Rule 3") in 7
  places, but **no `theme_rules.md` exists**.
- Trivial re-export shims: `course_model.dart` (22 bytes), `revision.dart` (98 bytes).

---

## 4. Design Rules (Source of Truth)

Enforce these in review. They replace the missing `theme_rules` doc referenced in
code comments.

### Rule 1 — Colors come from `AppTheme`
Never write `Colors.*` or `Color(0x…)` in widgets/screens. Use the context-aware
helpers (`surface`, `background`, `textPrimaryColor`, `borderColor`, …), a pastel
triple, or `AppTheme.tintFor(context, index)` for per-item category tints.
The only exception is `Colors.transparent` for sheet/dialog shells.

### Rule 2 — Category tints are stable
Assign each course/module a stable index and use `AppTheme.tintFor(context, index)`
so tints never shift between rebuilds. Do not invent new category colors.

### Rule 3 — Revision levels use `RevisionLevelPalette`
R1–R5 and the completed state must be read from `RevisionLevelPalette.of` /
`.completed`. Never re-declare the level colors inline.

### Rule 4 — Buttons use the theme
Prefer the themed `ElevatedButton` (pill 28, height 52, Inter 15/w600). If an
override is unavoidable, use `pillBorderRadius` and `AppTheme.buttonHeight`, and
foreground `Theme.of(context).colorScheme.onPrimary`. One button radius, one FAB
pattern.

### Rule 5 — Typography uses the scale
Use `AppTheme.headingLarge/Medium/Small`, `bodyLarge/Medium/Small`, `actionText`,
or the mapped `Theme.of(context).textTheme`. Avoid ad-hoc `fontSize` values;
if a new size is needed, add it to `app_theme.dart` first. Any widget using the
context-free getters must call `Theme.of(context)` in `build` so it repaints.

### Rule 6 — Spacing uses tokens and spacers
Use `AppSpacers` (`VGap*/HGap*`) instead of raw `SizedBox`, and the `spacing*`
scale for paddings. Screen gutters should use `AppTheme.defaultScreenPadding`;
card padding `AppTheme.defaultCardPadding`.

### Rule 7 — Radii use tokens
Use `cardBorderRadius` (20), `pillBorderRadius` (28), `defaultBorderRadius` (16),
`smallBorderRadius` (12), `iconBoxRadius` (14). If radius 10 remains the standard,
promote it to a named token rather than scattering literals.

### Rule 8 — One header per context
Body screens use `CustomAppBar`; bottom-nav root tabs use `TabHeader`. Do not
hand-roll a third app-bar layout. Both headers should source their title style
from the typography scale.

### Rule 9 — No dead code
Remove or adopt unused widgets/tokens rather than leaving them in `lib/`.

### Rule 10 — Light and dark parity
Every color must resolve through the palette so both modes work. Do not read
`AppTheme.isDark` manually or hardcode a mode-specific color.

---

## 5. Remediation Roadmap

### P0 — Theme-killers (fix first)
1. `upload_json_screen.dart` — replace the standalone dark-purple palette with
   `AppTheme` tokens (or an intentional, documented dark-card variant tokenized in
   `app_theme.dart`).
2. `my_progress_screen.dart` — delete the manual green/purple palette + `isDark`
   branches; use `pastelGreen*` / `pastelPurple*`.

### P1 — Deduplicate palettes
3. `revision_completion_dialog.dart` — drop the inline R1–R5 table; consume
   `RevisionLevelPalette`. Extract shared confetti colors to one place (also used by
   `move_to_revision_dialog.dart`).
4. `settings_screen.dart` / `notification_settings_screen.dart` — replace hardcoded
   pastel pairs with existing tokens (`badgeFill`, `indigoBorder`, `skyBg`, `coralBg`,
   `coralBorder`).
5. `topic_detail_screen.dart` / `study_text_fields.dart` — use `pastelBlueText` for
   URL highlighting instead of `0xFF2196F3`.
6. Promote `0xFFECEEF6` progress-track color to a token and use it in all 4 sites.

### P2 — Adopt missing tokens
7. Add a named radius token for the de-facto 10 (e.g. `fieldBorderRadius`) and migrate
   the 57 literal uses.
8. Standardize screen gutters on `defaultScreenPadding` and card padding on
   `defaultCardPadding`.
9. Replace remaining inline `TextStyle`s in the worst screens with typography getters.
10. Unify button radius to `pillBorderRadius` (or the new field radius) and FAB pattern.

### P3 — Cleanup
11. Delete unused widgets (`ActivityCard`, `ActivityListTile`, `FullScreenPage`,
    `TopicProgressHeader`, `TopicStatusLabel`), unused spacers, and unused
    `utils/responsive.dart`; remove trivial re-export shims.
12. Decide whether to keep `bnbHeight` (apply it or remove it) and consider an
    `alpha*` token set for `withValues`.
13. Add this file (or a `theme_rules.md`) as the referenced rule doc, and link it
    from `AGENTS.md`.

---

*Generated from a full audit of `lib/` (110 files). File:line evidence retained in
the exploration notes; re-run the audit after remediation to confirm drift.*
