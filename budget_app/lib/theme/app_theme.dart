import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppThemeType {
  light,
  dark,
  orix,
  logo,
  earth,
  system,
}

class AppTheme {
  // Dynamic theme state updated from MyApp root
  static bool isDark = true;
  static AppThemeType activeThemeType = AppThemeType.dark;

  // === App Colors ===
  
  // Brand Primary
  static Color get primaryColor {
    switch (activeThemeType) {
      case AppThemeType.orix:
        return const Color(0xFFF0C38E);
      case AppThemeType.logo:
        return const Color(0xFF206070);
      case AppThemeType.earth:
        return const Color(0xFF6D9773);
      default:
        return const Color(0xFF8B5CF6);
    }
  }
  
  // Brand Light
  static Color get primaryLight {
    switch (activeThemeType) {
      case AppThemeType.orix:
        return const Color(0xFFF1AA9B);
      case AppThemeType.logo:
        return const Color(0xFF389EB5);
      case AppThemeType.earth:
        return const Color(0xFF8FBA95);
      default:
        return const Color(0xFFC4B5FD);
    }
  }
  
  // Brand Dark
  static Color get primaryDark {
    switch (activeThemeType) {
      case AppThemeType.orix:
        return const Color(0xFF312C51);
      case AppThemeType.logo:
        return const Color(0xFF0F3E48);
      case AppThemeType.earth:
        return const Color(0xFF4E7053);
      default:
        return const Color(0xFF6D28D9);
    }
  }
  
  // Secondary Accent
  static Color get secondaryColor {
    switch (activeThemeType) {
      case AppThemeType.orix:
        return const Color(0xFFF1AA9B);
      case AppThemeType.logo:
        return const Color(0xFF3090D0);
      case AppThemeType.earth:
        return const Color(0xFFB46617);
      default:
        return const Color(0xFF3B82F6);
    }
  }
  
  // Background Deep
  static Color get backgroundColor {
    switch (activeThemeType) {
      case AppThemeType.orix:
        return const Color(0xFF312C51);
      case AppThemeType.logo:
        return const Color(0xFF0A1518);
      case AppThemeType.earth:
        return const Color(0xFF071F1A);
      default:
        return const Color(0xFF0F172A);
    }
  }
  
  // Surface Elevated
  static Color get surfaceColor {
    switch (activeThemeType) {
      case AppThemeType.orix:
        return const Color(0xFF48426D);
      case AppThemeType.logo:
        return const Color(0xFF122327);
      case AppThemeType.earth:
        return const Color(0xFF0E322A);
      default:
        return const Color(0xFF1E293B);
    }
  }    
  
  // Destructive/Error
  static const errorColor = Color(0xFFF43F5E);   
  
  // Success
  static const successColor = Color(0xFF10B981); 
  
  // Warning
  static const warningColor = Colors.orangeAccent;
  
  // Text Colors
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFF94A3B8); 
  static const textMuted = Colors.white54;

  // === Light Theme Surface Tokens ===
  static const lightBackgroundColor = Color(0xFFEFF6FF);
  static const lightSurfaceColor = Color(0xFFFFFFFF);
  static const lightSurfaceVariant = Color(0xFFF3F8FF);
  static const lightBorderColor = Color(0xFFE0ECFC);
  static const lightTextPrimary = Color(0xFF0F172A);
  static const lightTextSecondary = Color(0xFF334155);
  static const lightTextMuted = Color(0xFF64748B);

  // === Context-Aware Helpers ===
  static bool isDarkMode(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color surface(BuildContext context) =>
      isDarkMode(context) ? surfaceColor : lightSurfaceColor;

  static Color background(BuildContext context) =>
      isDarkMode(context) ? backgroundColor : lightBackgroundColor;

  static Color borderColor(BuildContext context) =>
      isDarkMode(context)
          ? Colors.white.withValues(alpha: 0.12)
          : const Color(0xFFCBD5E1);

  static Color textPrimaryColor(BuildContext context) =>
      isDarkMode(context) ? textPrimary : lightTextPrimary;

  static Color textSecondaryColor(BuildContext context) =>
      isDarkMode(context) ? textSecondary : lightTextSecondary;

  static Color textMutedColor(BuildContext context) =>
      isDarkMode(context) ? textMuted : lightTextMuted;

  static Color primaryAccentColor(BuildContext context) =>
      isDarkMode(context) ? primaryLight : primaryColor;

  static Color hintColor(BuildContext context) =>
      isDarkMode(context)
          ? textSecondary.withValues(alpha: 0.5)
          : lightTextMuted.withValues(alpha: 0.6);

  static Color inputBorderColor(BuildContext context) =>
      isDarkMode(context)
          ? Colors.white.withValues(alpha: 0.24)
          : lightTextMuted.withValues(alpha: 0.25);

  static Color subtleFillColor(BuildContext context) =>
      isDarkMode(context)
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.07);

  static Color selectedChipTextColor(BuildContext context) =>
      isDarkMode(context) ? textPrimary : Colors.white;

  static Color shadowColor(BuildContext context) =>
      isDarkMode(context)
          ? Colors.black.withValues(alpha: 0.3)
          : const Color(0xFFC4D0FB).withValues(alpha: 0.2);

  static Color switchInactiveThumbColor(BuildContext context) =>
      isDarkMode(context) ? textSecondary : lightTextMuted;

  static Color switchInactiveTrackColor(BuildContext context) =>
      isDarkMode(context) ? Colors.white10 : Colors.black12;

  static Color segmentedSelectedBgColor(BuildContext context) =>
      primaryColor.withValues(alpha: isDarkMode(context) ? 0.2 : 0.15);

  static Color settingsContainerColor(BuildContext context) =>
      surface(context).withValues(alpha: isDarkMode(context) ? 0.45 : 0.8);

  static Color pillBadgeTextColor(BuildContext context) =>
      isDarkMode(context) ? Colors.white : primaryColor;

  // === Layout Constants ===
  static const EdgeInsets defaultScreenPadding = EdgeInsets.symmetric(horizontal: 24.0);
  static const EdgeInsets defaultCardPadding = EdgeInsets.all(16.0);
  static const double defaultBorderRadius = 16.0;
  static const double smallBorderRadius = 8.0;
  static const double buttonHeight = 56.0;
  
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacingXxl = 48.0;

  static const double iconSizeXs = 16.0;
  static const double iconSizeSm = 20.0;
  static const double iconSizeMd = 24.0;
  static const double iconSizeLg = 32.0;
  static const double iconSizeXl = 48.0;
  static const double iconSizeXxl = 64.0;

  // Common Gradients
  static LinearGradient get backgroundGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [backgroundColor, surfaceColor],
  );

  static const LinearGradient lightBackgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [lightBackgroundColor, lightSurfaceVariant],
  );

  static LinearGradient get primaryGradient => LinearGradient(
    colors: [primaryColor, secondaryColor],
  );

  static LinearGradient resolvedBackgroundGradient(BuildContext context) =>
      isDarkMode(context) ? backgroundGradient : lightBackgroundGradient;

  // === Typography ===
  static TextStyle get headingLarge => GoogleFonts.outfit(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: isDark ? textPrimary : lightTextPrimary,
  );

  static TextStyle get headingMedium => GoogleFonts.outfit(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: isDark ? textPrimary : lightTextPrimary,
  );

  static TextStyle get headingSmall => GoogleFonts.outfit(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: isDark ? textPrimary : lightTextPrimary,
  );

  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 16,
    color: isDark ? textPrimary : lightTextPrimary,
  );

  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 14,
    color: isDark ? textSecondary : lightTextSecondary,
  );

  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 12,
    color: isDark ? textSecondary : lightTextSecondary,
  );

  static TextStyle get bodyMicro => GoogleFonts.inter(
    fontSize: 10,
    color: isDark ? textMuted : lightTextMuted,
  );

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      cardColor: surfaceColor,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: headingLarge,
        displayMedium: headingMedium,
        titleLarge: headingSmall,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(defaultBorderRadius),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(defaultBorderRadius),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(defaultBorderRadius),
          borderSide: BorderSide(color: primaryColor),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: Colors.white24),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, buttonHeight),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(defaultBorderRadius)),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: lightBackgroundColor,
      cardColor: lightSurfaceColor,
      dividerColor: lightBorderColor,
      iconTheme: const IconThemeData(color: lightTextPrimary),
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).copyWith(
        displayLarge: headingLarge.copyWith(color: lightTextPrimary),
        displayMedium: headingMedium.copyWith(color: lightTextPrimary),
        titleLarge: headingSmall.copyWith(color: lightTextPrimary),
        bodyLarge: bodyLarge.copyWith(color: lightTextPrimary),
        bodyMedium: bodyMedium.copyWith(color: lightTextSecondary),
        bodySmall: bodySmall.copyWith(color: lightTextSecondary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(defaultBorderRadius),
          borderSide: const BorderSide(color: lightBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(defaultBorderRadius),
          borderSide: const BorderSide(color: lightBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(defaultBorderRadius),
          borderSide: BorderSide(color: primaryColor),
        ),
        labelStyle: const TextStyle(color: lightTextSecondary),
        hintStyle: TextStyle(color: lightTextSecondary.withValues(alpha: 0.5)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, buttonHeight),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(defaultBorderRadius)),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
