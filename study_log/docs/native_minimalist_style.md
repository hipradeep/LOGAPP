# Study Log — Native Minimalist Style Guide

> Target visual language for `study_log`: native Android (Material 3), minimalist,
> compact, static, no unnecessary decoration. This doc defines the style and gives
> a phased refactor roadmap. Companion to
> [`design_system_audit.md`](./design_system_audit.md) (current tokens) and
> [`component_uniformity_audit.md`](./component_uniformity_audit.md) (adoption gaps).
>
> A live implementation of every sample below ships in-app at
> **Settings → Appearance & Design → Design System** (`lib/screens/design_system_screen.dart`).

---

## 1. Principles

1. **Native first.** Lean on Material 3 defaults. Override only what the app's
   identity requires — a single accent color and category tints.
2. **Neutral-first surfaces.** Most pixels are neutral (`surface` / `background`).
   Color is an accent, never a chrome layer.
3. **Compact density.** Information-dense rows and cards, not spacious padding.
4. **Static motion.** No springs, no bounce, no confetti. Transitions are short
   (≤ 200 ms) and eased.
5. **No unnecessary style.** No gradients, custom shadows, colored pill borders,
   or decorative flourishes. If a default widget already produces the result, use it.
6. **One pattern per job.** One header, one button style, one list row, one sheet shell.

---

## 2. Typography

**System font.** Drop `google_fonts` entirely; use the platform default (Roboto on
Android) via `ThemeData.textTheme` and `GoogleFonts`-free roles.

| Role | Size | Weight | Usage |
|---|---|---|---|
| `titleLarge` | 16 | w600 | Screen / app-bar title |
| `titleMedium` | 14 | w600 | Section headers, card titles |
| `bodyLarge` | 15 | w400 | Primary body |
| `bodyMedium` | 14 | w400 | Default body / subtitles |
| `bodySmall` | 12 | w400 | Secondary / metadata |
| `labelLarge` | 14 | w500 | Buttons |
| `labelSmall` | 11 | w500 | Captions, badges |

Rules:
- `letterSpacing: 0` everywhere (kill the current −0.5/−0.3/0.2/0.8 mix).
- Two weights only: `w400` body, `w600` emphasis. Avoid `bold`/`w700`/`w800`.
- No half-point sizes (13.5, 11.5, 10.5…). Snap to the scale.
- Delete `AppTheme.heading*/body*` Outfit/Inter getters; read from
  `Theme.of(context).textTheme`.

---

## 3. Color

**Neutral base (unchanged, already neutral-friendly):** `background`, `surface`,
`surfaceVariant`, `border`, `textPrimary/Secondary/Muted`. Keep light/dark parity.

**Accent (single brand color):** `primaryColor #5B4DFB`. Used for: primary buttons,
selection, focus, active nav icon, links. Not for large fills.

**Category tints — small accents only.** The 7 pastel triples remain as *data*
encoding, but render small:

| Do | Don't |
|---|---|
| 6–8 px colored dot | Full colored chip background + border |
| Colored icon (16–20 px) on neutral surface | Colored badge container |
| 3 px left accent bar | Colored card background |
| Colored text/label on `surfaceVariant` | Pastel-filled pill rows |

- `RevisionLevelPalette` stays the source of truth, but renders as a small dot +
  text, not a full colored chip.
- Chips/rows use `surfaceVariant` + colored foreground.

---

## 4. Density & Shape

| Metric | Current | Target |
|---|---|---|
| Screen gutter | 20 | **16** |
| Card padding | 18 | **12** |
| Button height | 52 | **40** (secondary 36) |
| Card radius | 20 | **12** (M3 default) |
| Small/row radius | 12 | **8** |
| Pill radius | 28 | **20** (M3 button default) |
| List row min height | ~60 | **48** |
| Sheet top radius | 20 | **16** |

Rationale: M3 defaults (card 12, button 20, chip 8) are already native and compact.

---

## 5. Motion — No Bouncing

- **Page transitions:** replace `CupertinoPageTransitionsBuilder` (all platforms)
  with the Android-native default `ZoomPageTransitionsBuilder`.
- **Duration:** ≤ 200 ms, curve `Curves.easeOutCubic` (no `elasticOut`,
  `bounceOut`, `spring`).
- **Remove:** splash `ScaleTransition` (keep fade), confetti in
  `move_to_revision_dialog` / `revision_completion_dialog`, decorative
  `AnimatedContainer`/`AnimatedOpacity` (or cap at ≤ 150 ms fade).
- **Keep:** `Dismissible` swipe, `RefreshIndicator`, native ink ripples.
- **Scroll:** no `BouncingScrollPhysics`; use platform default physics.

---

## 6. Components (target set)

| Job | Use | Notes |
|---|---|---|
| Screen header | `CustomAppBar` (body screens) / `TabHeader` (BNV roots) | no third variant |
| Bottom navigation | Material 3 `NavigationBar` | replaces hand-rolled `_StudyBottomNav` |
| Primary action | themed `FilledButton` / `ElevatedButton` | no per-screen `styleFrom` |
| Secondary action | `OutlinedButton` / `TextButton` from theme | currently 0 `OutlinedButton` uses |
| Add/Save (app bar) | `AddPillButton` | keep, restyle to M3 tonal |
| List row | `ListTile`-based compact row | min height 48 |
| Card | themed `Card` (radius 12, elevation 0, 1px border) | |
| Empty state | `AppEmptyState` | replace 8 clones |
| Confirmation | `StudyConfirmationDialog` | replace all inline `AlertDialog` |
| Bottom sheet | `SheetContainer` + `SheetHeader` + `SheetHandleBar` | all sheets |
| Text field | `UnderlineInputField` / `BorderlessDescriptionField` | |
| Spacers | `VGap*` / `HGap*` | no raw `SizedBox` |
| Level indicator | `RevisionLevelPalette` → dot + label | |

---

## 7. Refactor Roadmap

### Phase 1 — Tokens & ThemeData (`lib/theme/app_theme.dart`)
- [ ] Remove `google_fonts`; rebuild `textTheme` from system defaults with the
      compact scale in §2; delete Outfit/Inter getters (map to M3 roles).
- [ ] Update radii: card 12, default 12, small 8, pill 20; gutters 16; card pad 12;
      button height 40.
- [ ] `pageTransitionsTheme` → `ZoomPageTransitionsBuilder`.
- [ ] Add `navigationBarTheme`, restyle `elevatedButtonTheme`/`filledButtonTheme`
      to M3 defaults; `dialogTheme` radius 16; `bottomSheetTheme` radius 16.
- [ ] Update `revision_level_palette.dart` callers to small-dot rendering.
- [ ] Remove `google_fonts` from `pubspec.yaml`.

### Phase 2 — Shared components
- [ ] Restyle `custom_app_bar`, `tab_header`, `pill_button`, `add_pill_button`,
      `app_empty_state`, `compact_list_item`, `sheet_action_widgets`,
      `study_confirmation_dialog`, `study_text_fields` to the new tokens.
- [ ] Replace `_StudyBottomNav` with M3 `NavigationBar` in `main_navigation_screen`.
- [ ] Introduce shared FAB (replaces 4 variants).

### Phase 3 — Screens (adopt shared components + strip decorative styling)
- [ ] **P0:** `upload_json_screen` (theme-blind palette), `my_progress_screen`
      (second palette + `isDark` branches).
- [ ] **P1:** dedupe `revision_completion_dialog` → `RevisionLevelPalette`;
      dedupe settings/notification pastel pairs → tokens; `0xFFECEEF6` track → token;
      8 empty-state clones → `AppEmptyState`; inline `AlertDialog`s → shared dialog.
- [ ] **P2:** remove confetti/gradients; `BouncingScrollPhysics` → default;
      raw `SizedBox` → spacers; screen-level `TextStyle` → `textTheme`.

### Phase 4 — Cleanup & verify
- [ ] Delete dead widgets (`activity_card`, `activity_list_tile`, `full_screen_page`,
      `topic_status_label`, `topic_progress_header`, `edit_course_sheet`,
      `profile_sheet`, `add_module_sheet`, `revision_completion_dialog`).
- [ ] `flutter analyze` → 0 issues.
- [ ] `flutter build apk` (final phase only).

---

## 8. Before → After (token summary)

| Token | Before | After |
|---|---|---|
| Heading font | Outfit (Google Fonts) | System (Roboto) |
| Body font | Inter (Google Fonts) | System (Roboto) |
| `cardBorderRadius` | 20 | 12 |
| `defaultBorderRadius` | 16 | 12 |
| `smallBorderRadius` | 12 | 8 |
| `pillBorderRadius` | 28 | 20 |
| `buttonHeight` | 52 | 40 |
| Screen gutter | 20 | 16 |
| Card padding | 18 | 12 |
| Page transition | Cupertino (all) | Zoom (Android-native) |
| Category chip | pastel bg + border | neutral surface + colored dot/icon |

---

*See the in-app showcase (`lib/screens/design_system_screen.dart`) for live samples
of every color, text style, radius, spacing, button, field, sheet, dialog, and list row.*
