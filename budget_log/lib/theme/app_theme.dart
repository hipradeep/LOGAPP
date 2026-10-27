import 'package:flutter/material.dart';

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
  static const Color primaryColor = Color(0xFF5B4DFB);
  static const Color primaryLight = Color(0xFF7A6EFC);
  static const Color primaryDark = Color(0xFF4536DF);

  static const Color lightBackgroundColor = Color(0xFFF8F9FE);
  static const Color darkBackgroundColor = Color(0xFF0F0F14);

  static const Color errorColor = Color(0xFFEF4444);
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color textOnDark = Color(0xFFFFFFFF);
  static const Color textOnDarkSecondary = Color(0xFFD1D5DB);

  static const Color expenseColor = errorColor;
  static const Color incomeColor = successColor;

  static const EdgeInsets defaultScreenPadding = EdgeInsets.symmetric(
    horizontal: 16.0,
  );
  static const EdgeInsets defaultCardPadding = EdgeInsets.all(12.0);

  static const double cardBorderRadius = 12.0;
  static const double pillBorderRadius = 20.0;
  static const double defaultBorderRadius = 12.0;
  static const double smallBorderRadius = 8.0;
  static const double iconBoxRadius = 8.0;

  static const double buttonHeight = 40.0;
  static const double navigationBarHeight = 64.0;

  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacingXxl = 48.0;

  static Color background(BuildContext context) => _resolve(context).background;
  static Color surface(BuildContext context) => _resolve(context).surface;
  static Color surfaceVariant(BuildContext context) =>
      _resolve(context).surfaceVariant;
  static Color borderColor(BuildContext context) => _resolve(context).border;
  static Color borderSubtle(BuildContext context) =>
      _resolve(context).borderSubtle;
  static Color textPrimaryColor(BuildContext context) =>
      _resolve(context).textPrimary;
  static Color textSecondaryColor(BuildContext context) =>
      _resolve(context).textSecondary;
  static Color textMutedColor(BuildContext context) =>
      _resolve(context).textMuted;
  static Color badgeFill(BuildContext context) => _resolve(context).badgeFill;
  static Color shadowColor(BuildContext context) => _resolve(context).shadow;

  static bool isDark(BuildContext context) =>
      Theme.maybeBrightnessOf(context) == Brightness.dark;

  static Color pastelPurple(BuildContext context) => _resolve(context).purpleBg;
  static Color pastelPurpleText(BuildContext context) =>
      _resolve(context).purpleText;
  static Color pastelPurpleBorder(BuildContext context) =>
      _resolve(context).purpleBorder;
  static Color pastelGreen(BuildContext context) => _resolve(context).greenBg;
  static Color pastelGreenText(BuildContext context) =>
      _resolve(context).greenText;
  static Color pastelGreenBorder(BuildContext context) =>
      _resolve(context).greenBorder;
  static Color pastelOrange(BuildContext context) => _resolve(context).orangeBg;
  static Color pastelOrangeText(BuildContext context) =>
      _resolve(context).orangeText;
  static Color pastelOrangeBorder(BuildContext context) =>
      _resolve(context).orangeBorder;
  static Color pastelBlue(BuildContext context) => _resolve(context).blueBg;
  static Color pastelBlueText(BuildContext context) =>
      _resolve(context).blueText;
  static Color pastelBlueBorder(BuildContext context) =>
      _resolve(context).blueBorder;
  static Color pastelSky(BuildContext context) => _resolve(context).skyBg;
  static Color pastelSkyText(BuildContext context) => _resolve(context).skyText;
  static Color pastelSkyBorder(BuildContext context) =>
      _resolve(context).skyBorder;
  static Color pastelIndigo(BuildContext context) => _resolve(context).indigoBg;
  static Color pastelIndigoText(BuildContext context) =>
      _resolve(context).indigoText;
  static Color pastelIndigoBorder(BuildContext context) =>
      _resolve(context).indigoBorder;
  static Color pastelCoral(BuildContext context) => _resolve(context).coralBg;
  static Color pastelCoralText(BuildContext context) =>
      _resolve(context).coralText;
  static Color pastelCoralBorder(BuildContext context) =>
      _resolve(context).coralBorder;

  static const int tintCount = 7;

  static (Color background, Color foreground, Color border) tintFor(
    BuildContext context,
    int index,
  ) {
    final palette = _resolve(context);
    return switch (index % tintCount) {
      0 => (palette.purpleBg, palette.purpleText, palette.purpleBorder),
      1 => (palette.greenBg, palette.greenText, palette.greenBorder),
      2 => (palette.orangeBg, palette.orangeText, palette.orangeBorder),
      3 => (palette.blueBg, palette.blueText, palette.blueBorder),
      4 => (palette.skyBg, palette.skyText, palette.skyBorder),
      5 => (palette.indigoBg, palette.indigoText, palette.indigoBorder),
      _ => (palette.coralBg, palette.coralText, palette.coralBorder),
    };
  }

  static _Palette _resolve(BuildContext context) {
    final brightness = Theme.maybeBrightnessOf(context);
    if (brightness != null) {
      return brightness == Brightness.dark ? _Palette.dark : _Palette.light;
    }
    return _Palette.light;
  }

  static ThemeData get themeData =>
      _buildThemeData(_Palette.light, Brightness.light);

  static ThemeData get darkThemeData =>
      _buildThemeData(_Palette.dark, Brightness.dark);

  static ThemeData _buildThemeData(_Palette palette, Brightness brightness) {
    final isDarkMode = brightness == Brightness.dark;
    final baseScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: brightness,
    );
    final colorScheme = baseScheme.copyWith(
      primary: primaryColor,
      onPrimary: textOnDark,
      primaryContainer: palette.purpleBg,
      onPrimaryContainer: palette.purpleText,
      secondary: primaryLight,
      onSecondary: textOnDark,
      surface: palette.surface,
      onSurface: palette.textPrimary,
      surfaceContainerHighest: palette.surfaceVariant,
      surfaceContainerHigh: palette.surfaceVariant,
      surfaceContainer: palette.surface,
      surfaceContainerLow: palette.background,
      surfaceContainerLowest: palette.background,
      onSurfaceVariant: palette.textSecondary,
      outline: palette.border,
      outlineVariant: palette.borderSubtle,
      error: errorColor,
      onError: textOnDark,
    );

    final baseTextTheme = ThemeData(
      brightness: brightness,
      useMaterial3: true,
    ).textTheme;

    final textTheme = baseTextTheme.copyWith(
      displaySmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: palette.textPrimary,
        letterSpacing: 0,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: palette.textPrimary,
        letterSpacing: 0,
      ),
      titleLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: palette.textPrimary,
        letterSpacing: 0,
      ),
      titleMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: palette.textPrimary,
        letterSpacing: 0,
      ),
      titleSmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: palette.textPrimary,
        letterSpacing: 0,
      ),
      bodyLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: palette.textPrimary,
        height: 1.4,
        letterSpacing: 0,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: palette.textSecondary,
        height: 1.4,
        letterSpacing: 0,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: palette.textSecondary,
        letterSpacing: 0,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: palette.textPrimary,
        letterSpacing: 0,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: palette.textMuted,
        letterSpacing: 0,
      ),
    );

    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(smallBorderRadius),
      borderSide: BorderSide(color: palette.border),
    );
    final focusedFieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(smallBorderRadius),
      borderSide: const BorderSide(color: primaryColor, width: 1.5),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      cardColor: palette.surface,
      dividerColor: palette.border,
      splashColor: primaryColor.withValues(alpha: 0.08),
      highlightColor: primaryColor.withValues(alpha: 0.04),
      textTheme: textTheme,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        },
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primaryColor,
        selectionColor: primaryColor.withValues(alpha: 0.25),
        selectionHandleColor: primaryColor,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: palette.textPrimary),
        titleTextStyle: textTheme.titleLarge,
      ),
      iconTheme: IconThemeData(color: palette.textPrimary),
      cardTheme: CardThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardBorderRadius),
          side: BorderSide(color: palette.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        modalBackgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: navigationBarHeight,
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: primaryColor.withValues(alpha: 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryColor, size: 22);
          }
          return IconThemeData(color: palette.textSecondary, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: primaryColor,
              letterSpacing: 0,
            );
          }
          return TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: palette.textSecondary,
            letterSpacing: 0,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: textOnDark,
          minimumSize: const Size(0, buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(pillBorderRadius),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
          elevation: 0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: textOnDark,
          minimumSize: const Size(0, buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(pillBorderRadius),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          minimumSize: const Size(0, buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(pillBorderRadius),
          ),
          side: BorderSide(color: palette.border),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          minimumSize: const Size(0, buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(pillBorderRadius),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: textOnDark,
        elevation: 1.5,
        highlightElevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceVariant,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        hintStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: palette.textMuted,
          letterSpacing: 0,
        ),
        labelStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: palette.textSecondary,
          letterSpacing: 0,
        ),
        floatingLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: primaryColor,
          letterSpacing: 0,
        ),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: focusedFieldBorder,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surfaceVariant,
        side: BorderSide(color: palette.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(smallBorderRadius),
        ),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: palette.textPrimary,
          letterSpacing: 0,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 8,
        iconColor: palette.textSecondary,
        textColor: palette.textPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(smallBorderRadius),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: palette.border,
        space: 1,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDarkMode
            ? palette.surfaceVariant
            : palette.textPrimary,
        contentTextStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: isDarkMode ? palette.textPrimary : palette.surface,
          letterSpacing: 0,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(defaultBorderRadius),
        ),
      ),
    );
  }
}
