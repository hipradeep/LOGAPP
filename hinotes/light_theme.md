# Light Theme — Color Palette, Semantic Tokens & Component Colors

This document outlines the design decisions, color definitions, and implementation strategy for adding a Light Theme to the app.

---

## Current State: Dark Only

`AppTheme` currently defines:
- A **pure dark palette** with `backgroundColor: 0xFF0F172A` (Slate 900) and `surfaceColor: 0xFF1E293B` (Slate 800)
- A **single `darkTheme`** ThemeData getter
- **No semantic token layer** — colors like `textPrimary = Colors.white` are hardcoded and will break visually in a light theme

---

## Step 1: Semantic Color Token System

Instead of using raw colors directly, define **named semantic tokens** that swap based on the theme mode.

```
Dark Theme Values          Token Name              Light Theme Values
──────────────────────────────────────────────────────────────────────
0xFF0F172A (Slate 900)  ← background         →  0xFFF8FAFC (Slate 50)
0xFF1E293B (Slate 800)  ← surface            →  0xFFFFFFFF (White)
0xFF334155 (Slate 700)  ← surfaceVariant     →  0xFFF1F5F9 (Slate 100)
Colors.white            ← textPrimary        →  0xFF0F172A (Slate 900)
0xFF94A3B8 (Slate 400)  ← textSecondary      →  0xFF64748B (Slate 500)
Colors.white54          ← textMuted          →  0xFF94A3B8 (Slate 400)
```

---

## Step 2: Light Theme Color Palette

### 🎨 Brand Colors (Shared — Do NOT Change Between Themes)

| Token | Hex | Use |
|:---|:---|:---|
| `primaryColor` | `0xFF8B5CF6` | Buttons, active states, CTAs |
| `primaryLight` | `0xFFC4B5FD` | Soft highlights, chip backgrounds |
| `primaryDark` | `0xFF6D28D9` | Pressed states, gradients |
| `secondaryColor` | `0xFF3B82F6` | Secondary actions, links |
| `successColor` | `0xFF10B981` | Completions, confirmations |
| `errorColor` | `0xFFF43F5E` | Errors, deletions |
| `warningColor` | `0xFFFB923C` | Warnings, skipped states |

### ☀️ Light Theme Surface Palette (NEW)

| Token | Hex | Use |
|:---|:---|:---|
| `lightBackground` | `0xFFF8FAFC` | Main screen background |
| `lightSurface` | `0xFFFFFFFF` | Cards, sheets, dialogs |
| `lightSurfaceVariant` | `0xFFF1F5F9` | Input fields, secondary containers |
| `lightBorder` | `0xFFE2E8F0` | Card borders, dividers |
| `lightTextPrimary` | `0xFF0F172A` | Headings, primary labels |
| `lightTextSecondary` | `0xFF64748B` | Subtitles, helper text |
| `lightTextMuted` | `0xFF94A3B8` | Timestamps, placeholders |

---

## Step 3: Component-Level Color Tokens

Semantic names tied to UI components. Both themes share the same token names but point to different raw values:

```
Component Token             Dark Value              Light Value
──────────────────────────────────────────────────────────────────────
navBarBackground          surfaceColor            lightSurface
navBarBorderTop           white @ 5%              lightBorder
cardBackground            surfaceColor @ 70%      lightSurface
cardBorder                white @ 5%              lightBorder
inputFill                 surfaceColor            lightSurfaceVariant
inputBorder               white @ 10%             lightBorder
chipBackground (active)   primaryColor @ 20%      primaryLight @ 40%
chipBackground (inactive) white @ 6%              lightSurfaceVariant
appBarBlur                black @ 60% + blur      white @ 80% + blur
activityCompleted         successColor @ 8%       successColor @ 10%
activitySkipped           warningColor @ 8%       warningColor @ 10%
```

---

## Step 4: Implementation Strategy in `AppTheme`

```dart
class AppTheme {
  // === Shared Brand Tokens (unchanged) ===
  static const primaryColor = Color(0xFF8B5CF6);
  // ...

  // === Light Theme Surface Tokens ===
  static const lightBackground    = Color(0xFFF8FAFC);
  static const lightSurface       = Color(0xFFFFFFFF);
  static const lightSurfaceVar    = Color(0xFFF1F5F9);
  static const lightBorder        = Color(0xFFE2E8F0);
  static const lightTextPrimary   = Color(0xFF0F172A);
  static const lightTextSecondary = Color(0xFF64748B);
  static const lightTextMuted     = Color(0xFF94A3B8);

  // === Context-Aware Getters (read from BuildContext.Theme) ===
  static Color background(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark
          ? backgroundColor : lightBackground;

  static Color surface(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark
          ? surfaceColor : lightSurface;

  static Color textOnSurface(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark
          ? textPrimary : lightTextPrimary;

  // === ThemeData Getters ===
  static ThemeData get darkTheme { ... }   // Existing
  static ThemeData get lightTheme { ... }  // NEW
}
```

---

## Step 5: Recommended Implementation Order

> **IMPORTANT:** The current codebase uses hardcoded raw color references everywhere (e.g., `Colors.white`, `Colors.white10`, `Colors.white.withValues(alpha: 0.05)`). Before a light theme can work, these must be replaced with context-aware `AppTheme.surface(context)` getters — otherwise the light theme will show white text on white backgrounds.

1. Define all light surface tokens in `AppTheme`
2. Add context-aware helper getters (`background()`, `surface()`, `textOnSurface()`)
3. Add `lightTheme` ThemeData getter
4. Wire theme toggle in `SettingsController` (ValueNotifier/Stream)
5. Sweep through all screens and widgets replacing hardcoded `Colors.white` with tokens

---

## Codebase Audit (Session: 2026-06-14)

### Files Examined

| File | Key Finding |
|---|---|
| `lib/theme/app_theme.dart` | Single `darkTheme` getter only. No `lightTheme`. Static `const` tokens. |
| `lib/main.dart` | `themeMode: ThemeMode.dark` hardcoded. `SystemUiOverlayStyle` hardcoded for dark. No `theme:` property set. |
| `lib/controllers/settings_controller.dart` | Manages `userName`, `userAvatar`, `dailyReminder` via `CacheService`. No `themeMode` field. |
| `lib/services/cache_service.dart` | JSON file storage at `app_cache.json`. New key `theme_mode` can be added here. Already has `saveX/getX` pattern. |
| `lib/screens/settings_screen.dart` | Has a `_ComingSoonBadge()` "Custom Themes" `_MenuItem` in `_PreferencesSecuritySection` — **ideal slot for toggle**. Uses `AppProvider<SettingsController>.watch()`. |

---

## Step 6: `ThemeController` — New File

**File:** `lib/controllers/theme_controller.dart`

```dart
import 'package:flutter/material.dart';
import '../services/cache_service.dart';

class ThemeController extends ChangeNotifier {
  final CacheService _cache = CacheService();
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  ThemeController() {
    _load();
  }

  Future<void> _load() async {
    final saved = await _cache.getThemeMode();
    _themeMode = _parse(saved);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _cache.saveThemeMode(_toString(mode));
    notifyListeners();
  }

  ThemeMode _parse(String? v) {
    switch (v) {
      case 'light': return ThemeMode.light;
      case 'system': return ThemeMode.system;
      default: return ThemeMode.dark;
    }
  }

  String _toString(ThemeMode m) {
    switch (m) {
      case ThemeMode.light: return 'light';
      case ThemeMode.system: return 'system';
      default: return 'dark';
    }
  }
}
```

> **Rule compliance:** Uses `ChangeNotifier` only (no Provider/Riverpod/GetX) per `aa-rules.md`. Disposes cleanly. Business logic encapsulated in controller.

---

## Step 7: `CacheService` Additions

Add to `lib/services/cache_service.dart`:

```dart
// Cache key: 'theme_mode' → 'dark' | 'light' | 'system'
Future<void> saveThemeMode(String mode) async {
  final cache = await _readCache();
  cache['theme_mode'] = mode;
  await _writeCache(cache);
}

Future<String?> getThemeMode() async {
  final cache = await _readCache();
  return cache['theme_mode'] as String?;
}
```

---

## Step 8: `main.dart` — Wire ThemeController

Convert `MyApp` from `StatelessWidget` to `StatefulWidget`:

```dart
class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final ThemeController _themeController;

  @override
  void initState() {
    super.initState();
    _themeController = ThemeController();
    _themeController.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    final isDark = _themeController.isDark;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: isDark
          ? AppTheme.backgroundColor
          : AppTheme.lightBackground,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ));
    setState(() {});
  }

  @override
  void dispose() {
    _themeController.removeListener(_onThemeChanged);
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LOG',
      debugShowCheckedModeBanner: false,
      themeMode: _themeController.themeMode,
      theme: AppTheme.lightTheme,        // NEW
      darkTheme: AppTheme.darkTheme,
      home: SplashScreen(themeController: _themeController),
    );
  }
}
```

> **Passing `ThemeController` down:** Since the project avoids Provider/Riverpod, pass `ThemeController` via constructor through `SplashScreen` → `MainNavigationScreen` → `SettingsScreen`. Alternatively, store a `static ThemeController instance` in the controller class as a lightweight global singleton.

---

## Step 9: Settings Screen Toggle

In `_PreferencesSecuritySection`, replace the "Custom Themes" `_ComingSoonBadge` item with a real switch:

```dart
// Remove:
_MenuItem(
  icon: Icons.palette_outlined,
  iconBgColor: Colors.pinkAccent,
  title: 'Custom Themes',
  subtitle: 'Tailor the application accent and gradients',
  trailing: const _ComingSoonBadge(),
  onTap: () => onComingSoon('Custom Themes'),
),

// Add:
_SwitchItem(
  icon: Icons.dark_mode_outlined,
  iconBgColor: Colors.pinkAccent,
  title: 'Dark Mode',
  subtitle: 'Switch between light and dark appearance',
  value: themeController.isDark,
  onChanged: (val) => themeController.setThemeMode(
    val ? ThemeMode.dark : ThemeMode.light,
  ),
),
```

> `_PreferencesSecuritySection` needs a `themeController` constructor parameter added.

---

## Risk Map: Widgets That Will Break in Light Mode

| Widget / Location | Issue | Fix |
|---|---|---|
| `_Divider` in `settings_screen.dart:667` | `Colors.white.withValues(alpha:0.05)` invisible on white | Use `Theme.of(ctx).dividerColor` or `Colors.black12` |
| `_SectionCard` border | `Colors.white.withValues(alpha:0.05)` | Use `AppTheme.lightBorder` in light mode |
| `_ProfileCard` border | Same as above | Same fix |
| `_ProfileCard` avatar inner circle | `AppTheme.backgroundColor` (Slate 900) inner circle | Use `AppTheme.background(context)` |
| `settings_screen.dart:339,350` | `Container(color: Colors.white10)` stat dividers | Use `AppTheme.lightBorder` in light mode |
| All `AlertDialog` `backgroundColor: AppTheme.surfaceColor` | Slate 800 on light bg | Use `AppTheme.surface(context)` |
| `FullScreenPage` glassmorphism header | Likely `Colors.white.withValues(...)` blur overlay | Audit and adjust for light bg |
| `backgroundGradient` const | Hardcoded dark colors | Add `lightBackgroundGradient` const |
| All `TextStyle` getters in `AppTheme` | Color from `static const textPrimary = Colors.white` | Override with `lightTextPrimary` in `lightTheme.textTheme` |
| `GlowBlob` opacity | Dark bg amplifies glow; light bg will look washed out | May need to increase opacity on light or reduce size |

---

## Testing Checklist

- [ ] Toggle in Settings saves and persists across app restarts
- [ ] SystemUI status/nav bar icons flip correctly per theme
- [ ] All `_SectionCard` card borders visible on white bg
- [ ] All `_Divider` separators visible on white bg
- [ ] `FullScreenPage` glassmorphism header legible in both modes
- [ ] `AlertDialog` / `ModalBottomSheet` uses correct surface color
- [ ] Profile card avatar inner circle uses correct bg color
- [ ] `inputDecorationTheme` border colors visible in light mode
- [ ] All text meets WCAG AA contrast (≥ 4.5:1) in both themes
- [ ] `GlowBlob` not washed out on light background
- [ ] `backgroundGradient` renders correctly in both modes
- [ ] Splash screen adapts to theme on next launch
