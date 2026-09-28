import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Available app themes.
enum AppThemeType {
  studyMinimalist,
  studyDark,
}

/// Resolved colours for one brightness.
///
/// Semantic colours live here rather than as top-level constants so that
/// [AppTheme] helpers can hand back the right value for the active brightness
/// without any call site performing its own brightness check.
class _Palette {
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color border;
  final Color borderSubtle;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color shadow;
  final Color badgeFill;

  final Color purpleBg;
  final Color purpleText;
  final Color purpleBorder;

  final Color greenBg;
  final Color greenText;
  final Color greenBorder;

  final Color orangeBg;
  final Color orangeText;
  final Color orangeBorder;

  final Color blueBg;
  final Color blueText;
  final Color blueBorder;

  final Color skyBg;
  final Color skyText;
  final Color skyBorder;

  final Color indigoBg;
  final Color indigoText;
  final Color indigoBorder;

  final Color coralBg;
  final Color coralText;
  final Color coralBorder;

  const _Palette({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.border,
    required this.borderSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.shadow,
    required this.badgeFill,
    required this.purpleBg,
    required this.purpleText,
    required this.purpleBorder,
    required this.greenBg,
    required this.greenText,
    required this.greenBorder,
    required this.orangeBg,
    required this.orangeText,
    required this.orangeBorder,
    required this.blueBg,
    required this.blueText,
    required this.blueBorder,
    required this.skyBg,
    required this.skyText,
    required this.skyBorder,
    required this.indigoBg,
    required this.indigoText,
    required this.indigoBorder,
    required this.coralBg,
    required this.coralText,
    required this.coralBorder,
  });

  static const _Palette light = _Palette(
    background: Color(0xFFF8F9FE),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF3F4F8),
    border: Color(0xFFEEF0F5),
    borderSubtle: Color(0xFFF5F6FA),
    textPrimary: Color(0xFF18181B),
    textSecondary: Color(0xFF6B7280),
    textMuted: Color(0xFF9CA3AF),
    shadow: Color(0x0C000000),
    badgeFill: Color(0xFFEDE9FE),
    purpleBg: Color(0xFFF0EEFF),
    purpleText: Color(0xFF5B4DFB),
    purpleBorder: Color(0xFFE2DCFF),
    greenBg: Color(0xFFE8F8F0),
    greenText: Color(0xFF10B981),
    greenBorder: Color(0xFFD1F2E2),
    orangeBg: Color(0xFFFFF3EA),
    orangeText: Color(0xFFF97316),
    orangeBorder: Color(0xFFFFE3D1),
    blueBg: Color(0xFFEBF5FF),
    blueText: Color(0xFF3B82F6),
    blueBorder: Color(0xFFD4EAFF),
    skyBg: Color(0xFFE0F2FE),
    skyText: Color(0xFF0284C7),
    skyBorder: Color(0xFFBAE6FD),
    indigoBg: Color(0xFFEEF2FF),
    indigoText: Color(0xFF4F46E5),
    indigoBorder: Color(0xFFE0E7FF),
    coralBg: Color(0xFFFEF2F2),
    coralText: Color(0xFFEF4444),
    coralBorder: Color(0xFFFEE2E2),
  );

  /// Pastels become deep, low-chroma tints in dark mode so that the lighter
  /// foreground tones keep enough contrast against them.
  static const _Palette dark = _Palette(
    background: Color(0xFF0F0F14),
    surface: Color(0xFF1A1A21),
    surfaceVariant: Color(0xFF24242D),
    border: Color(0xFF2C2C36),
    borderSubtle: Color(0xFF22222A),
    textPrimary: Color(0xFFF4F4F5),
    textSecondary: Color(0xFFA1A1AA),
    textMuted: Color(0xFF71717A),
    shadow: Color(0x40000000),
    badgeFill: Color(0xFF2C2C3A),
    purpleBg: Color(0xFF241F45),
    purpleText: Color(0xFFA99BFF),
    purpleBorder: Color(0xFF3A3168),
    greenBg: Color(0xFF12301F),
    greenText: Color(0xFF5FD3A0),
    greenBorder: Color(0xFF1D4A32),
    orangeBg: Color(0xFF3A2415),
    orangeText: Color(0xFFFB9A5B),
    orangeBorder: Color(0xFF573A22),
    blueBg: Color(0xFF122A3F),
    blueText: Color(0xFF6FB0F5),
    blueBorder: Color(0xFF1D4060),
    skyBg: Color(0xFF0C2A3D),
    skyText: Color(0xFF6FC5F5),
    skyBorder: Color(0xFF164055),
    indigoBg: Color(0xFF1E2145),
    indigoText: Color(0xFF9BA3F5),
    indigoBorder: Color(0xFF2F3465),
    coralBg: Color(0xFF3B1D1D),
    coralText: Color(0xFFF98A8A),
    coralBorder: Color(0xFF5C2B2B),
  );
}

class AppTheme {
  static const AppThemeType activeThemeType = AppThemeType.studyMinimalist;

  /// Single source of truth for the active brightness.
  ///
  /// [ThemeController] keeps this in sync with [ThemeController.themeMode].
  /// It backs the text style getters below, which have no [BuildContext] to
  /// resolve against, per the theme rebuild registration rule.
  static bool isDark = false;

  static _Palette get _palette => isDark ? _Palette.dark : _Palette.light;

  // Brand Primary (Vibrant Violet / Indigo) - theme invariant.
  static const Color primaryColor = Color(0xFF5B4DFB);
  static const Color primaryLight = Color(0xFF7A6EFC);
  static const Color primaryDark = Color(0xFF4536DF);

  // Brand and feedback colours - theme invariant.
  static const Color errorColor = Color(0xFFEF4444);
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color textOnDark = Color(0xFFFFFFFF);
  static const Color textOnDarkSecondary = Color(0xFFD1D5DB);

  // Bottom Navigation Bar accents - theme invariant.
  static const Color bnbActiveColor = Color(0xFF5B4DFB);
  static const Color bnbInactiveColor = Color(0xFF9CA3AF);
  static const double bnbHeight = 72.0;

  static const EdgeInsets defaultScreenPadding = EdgeInsets.symmetric(horizontal: 20.0);
  static const EdgeInsets defaultCardPadding = EdgeInsets.all(18.0);

  // Radii matching modern soft rounded cards.
  static const double cardBorderRadius = 20.0;
  static const double pillBorderRadius = 28.0;
  static const double defaultBorderRadius = 16.0;
  static const double smallBorderRadius = 12.0;
  static const double iconBoxRadius = 14.0;

  // Standard Heights.
  static const double buttonHeight = 52.0;

  // Standard Spacings.
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacingXxl = 48.0;

  // Context-aware colour helpers.
  //
  // Call sites use these instead of constants so a theme switch repaints them
  // without any per-widget brightness check.
  static Color background(BuildContext context) => _resolve(context).background;
  static Color surface(BuildContext context) => _resolve(context).surface;
  static Color surfaceVariant(BuildContext context) => _resolve(context).surfaceVariant;
  static Color borderColor(BuildContext context) => _resolve(context).border;
  static Color borderSubtle(BuildContext context) => _resolve(context).borderSubtle;
  static Color textPrimaryColor(BuildContext context) => _resolve(context).textPrimary;
  static Color textSecondaryColor(BuildContext context) => _resolve(context).textSecondary;
  static Color textMutedColor(BuildContext context) => _resolve(context).textMuted;
  static Color badgeFill(BuildContext context) => _resolve(context).badgeFill;
  static Color shadowColor(BuildContext context) => _resolve(context).shadow;

  // Pastel category palettes.
  static Color pastelPurple(BuildContext context) => _resolve(context).purpleBg;
  static Color pastelPurpleText(BuildContext context) => _resolve(context).purpleText;
  static Color pastelPurpleBorder(BuildContext context) => _resolve(context).purpleBorder;
  static Color pastelGreen(BuildContext context) => _resolve(context).greenBg;
  static Color pastelGreenText(BuildContext context) => _resolve(context).greenText;
  static Color pastelGreenBorder(BuildContext context) => _resolve(context).greenBorder;
  static Color pastelOrange(BuildContext context) => _resolve(context).orangeBg;
  static Color pastelOrangeText(BuildContext context) => _resolve(context).orangeText;
  static Color pastelOrangeBorder(BuildContext context) => _resolve(context).orangeBorder;
  static Color pastelBlue(BuildContext context) => _resolve(context).blueBg;
  static Color pastelBlueText(BuildContext context) => _resolve(context).blueText;
  static Color pastelBlueBorder(BuildContext context) => _resolve(context).blueBorder;
  static Color pastelSky(BuildContext context) => _resolve(context).skyBg;
  static Color pastelSkyText(BuildContext context) => _resolve(context).skyText;
  static Color pastelSkyBorder(BuildContext context) => _resolve(context).skyBorder;
  static Color pastelIndigo(BuildContext context) => _resolve(context).indigoBg;
  static Color pastelIndigoText(BuildContext context) => _resolve(context).indigoText;
  static Color pastelIndigoBorder(BuildContext context) => _resolve(context).indigoBorder;
  static Color pastelCoral(BuildContext context) => _resolve(context).coralBg;
  static Color pastelCoralText(BuildContext context) => _resolve(context).coralText;
  static Color pastelCoralBorder(BuildContext context) => _resolve(context).coralBorder;

  /// Number of distinct tints available from [tintFor].
  static const int tintCount = 6;

  /// Background, foreground and border for one pastel category tint.
  ///
  /// Callers cycle this by a stable per-item index so a given course or
  /// module keeps the same tint across rebuilds.
  static (Color background, Color foreground, Color border) tintFor(
      BuildContext context, int index) {
    final palette = _resolve(context);
    return switch (index % tintCount) {
      0 => (palette.purpleBg, palette.purpleText, palette.purpleBorder),
      1 => (palette.greenBg, palette.greenText, palette.greenBorder),
      2 => (palette.orangeBg, palette.orangeText, palette.orangeBorder),
      3 => (palette.blueBg, palette.blueText, palette.blueBorder),
      4 => (palette.skyBg, palette.skyText, palette.skyBorder),
      _ => (palette.indigoBg, palette.indigoText, palette.indigoBorder),
    };
  }

  /// Reads the palette for [context]'s brightness.
  ///
  /// [Theme.maybeBrightnessOf] registers an inherited dependency, so the
  /// calling widget rebuilds when the theme changes. Falls back to [_palette]
  /// when neither a [Theme] ancestor nor a platform brightness is available.
  static _Palette _resolve(BuildContext context) {
    final brightness = Theme.maybeBrightnessOf(context);
    if (brightness != null) {
      return brightness == Brightness.dark ? _Palette.dark : _Palette.light;
    }
    return _palette;
  }

  // Typography. These getters take no context, so their colours resolve from
  // [isDark]; every widget using them MUST call `Theme.of(context)` inside its
  // build method so Flutter schedules a rebuild when the theme changes.
  // [_buildThemeData] uses the palette-taking variants below so a ThemeData is
  // never built with the opposite mode's text colours.
  static TextStyle get headingLarge => _headingLarge(_palette);
  static TextStyle get headingMedium => _headingMedium(_palette);
  static TextStyle get headingSmall => _headingSmall(_palette);
  static TextStyle get bodyLarge => _bodyLarge(_palette);
  static TextStyle get bodyMedium => _bodyMedium(_palette);
  static TextStyle get bodySmall => _bodySmall(_palette);
  static TextStyle get actionText => _actionText(_palette);

  static TextStyle _headingLarge(_Palette p) => GoogleFonts.outfit(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: p.textPrimary,
        letterSpacing: -0.5,
      );

  static TextStyle _headingMedium(_Palette p) => GoogleFonts.outfit(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: p.textPrimary,
        letterSpacing: -0.3,
      );

  static TextStyle _headingSmall(_Palette p) => GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: p.textPrimary,
      );

  static TextStyle _bodyLarge(_Palette p) => GoogleFonts.inter(
        fontSize: 15,
        color: p.textPrimary,
        height: 1.4,
      );

  static TextStyle _bodyMedium(_Palette p) => GoogleFonts.inter(
        fontSize: 13,
        color: p.textSecondary,
        height: 1.4,
      );

  static TextStyle _bodySmall(_Palette p) => GoogleFonts.inter(
        fontSize: 11,
        color: p.textSecondary,
      );

  static TextStyle _actionText(_Palette p) => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: primaryColor,
      );

  static ThemeData get themeData => _buildThemeData(_Palette.light, Brightness.light);

  static ThemeData get darkThemeData => _buildThemeData(_Palette.dark, Brightness.dark);

  static ThemeData _buildThemeData(_Palette palette, Brightness brightness) {
    final onPrimary = brightness == Brightness.dark ? const Color(0xFF15152B) : textOnDark;

    return ThemeData(
      useMaterial3: true,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
      brightness: brightness,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: palette.background,
      cardColor: palette.surface,
      dividerColor: palette.border,
      canvasColor: palette.background,
      splashColor: primaryColor.withValues(alpha: 0.08),
      highlightColor: primaryColor.withValues(alpha: 0.04),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: palette.textPrimary),
      ),
      iconTheme: IconThemeData(color: palette.textPrimary),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(defaultBorderRadius)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primaryColor,
        secondary: primaryLight,
        surface: palette.surface,
        error: errorColor,
        onPrimary: onPrimary,
        onSecondary: onPrimary,
        onSurface: palette.textPrimary,
        onError: textOnDark,
      ),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: _headingLarge(palette),
        displayMedium: _headingMedium(palette),
        titleLarge: _headingSmall(palette),
        bodyLarge: _bodyLarge(palette),
        bodyMedium: _bodyMedium(palette),
        bodySmall: _bodySmall(palette),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: onPrimary,
          minimumSize: const Size(0, buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(pillBorderRadius),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primaryColor),
      ),
      dividerTheme: DividerThemeData(color: palette.border, space: 1, thickness: 1),
    );
  }
}
