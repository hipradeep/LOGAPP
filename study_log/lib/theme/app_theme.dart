import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Available app themes.
enum AppThemeType {
  studyMinimalist,
  studyDark,
}

class AppTheme {
  static const AppThemeType activeThemeType = AppThemeType.studyMinimalist;
  static bool isDark = false;

  // Brand Primary (Vibrant Violet / Indigo)
  static const Color primaryColor = Color(0xFF5B4DFB);
  static const Color primaryLight = Color(0xFF7A6EFC);
  static const Color primaryDark = Color(0xFF4536DF);

  // Backgrounds
  static const Color backgroundColor = Color(0xFFF8F9FE);
  
  // Surfaces
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF3F4F8);
  static const Color darkCardColor = Color(0xFF1E1E24);

  // Pastel Card & Icon Box Palettes (from the new reference design)
  // Purple Tint (DSA / Algorithms)
  static const Color pastelPurple = Color(0xFFF0EEFF);
  static const Color pastelPurpleText = Color(0xFF5B4DFB);
  static const Color pastelPurpleBorder = Color(0xFFE2DCFF);

  // Mint Green Tint (System Design)
  static const Color pastelGreen = Color(0xFFE8F8F0);
  static const Color pastelGreenText = Color(0xFF10B981);
  static const Color pastelGreenBorder = Color(0xFFD1F2E2);

  // Peach / Orange Tint (Gen AI / Robotics)
  static const Color pastelOrange = Color(0xFFFFF3EA);
  static const Color pastelOrangeText = Color(0xFFF97316);
  static const Color pastelOrangeBorder = Color(0xFFFFE3D1);

  // Soft Blue Tint (Recursion / Networking)
  static const Color pastelBlue = Color(0xFFEBF5FF);
  static const Color pastelBlueText = Color(0xFF3B82F6);
  static const Color pastelBlueBorder = Color(0xFFD4EAFF);

  // Borders & Dividers
  static const Color borderColor = Color(0xFFEEF0F5);
  static const Color borderSubtle = Color(0xFFF5F6FA);

  // Text Colors
  static const Color textPrimary = Color(0xFF18181B);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color textOnDark = Color(0xFFFFFFFF);
  static const Color textOnDarkSecondary = Color(0xFFD1D5DB);

  // Badges & Accents
  static const Color darkBadgeFill = Color(0xFF2C2C2E);
  static const Color lightBadgeFill = Color(0xFFEDE9FE);

  // Feedback Colors
  static const Color errorColor = Color(0xFFEF4444);
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);

  // Bottom Navigation Bar
  static const Color bnbActiveColor = Color(0xFF5B4DFB);
  static const Color bnbInactiveColor = Color(0xFF9CA3AF);
  static const double bnbHeight = 72.0;

  static const EdgeInsets defaultScreenPadding = EdgeInsets.symmetric(horizontal: 20.0);
  static const EdgeInsets defaultCardPadding = EdgeInsets.all(18.0);
  
  // Radii matching modern soft rounded cards
  static const double cardBorderRadius = 20.0;
  static const double pillBorderRadius = 28.0;
  static const double defaultBorderRadius = 16.0;
  static const double smallBorderRadius = 12.0;
  static const double iconBoxRadius = 14.0;
  
  // Standard Heights
  static const double buttonHeight = 52.0;

  // Standard Spacings
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacingXxl = 48.0;

  // Context-aware color helpers
  static Color surface(BuildContext context) => surfaceColor;
  static Color background(BuildContext context) => backgroundColor;
  static Color getBorderColor(BuildContext context) => borderColor;
  static Color shadowColor(BuildContext context) => const Color(0x0C000000);

  static TextStyle get headingLarge => GoogleFonts.outfit(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  static TextStyle get headingMedium => GoogleFonts.outfit(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.3,
  );

  static TextStyle get headingSmall => GoogleFonts.outfit(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 15,
    color: textPrimary,
    height: 1.4,
  );

  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 13,
    color: textSecondary,
    height: 1.4,
  );

  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 11,
    color: textSecondary,
  );

  static TextStyle get actionText => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    color: primaryColor,
  );

  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      cardColor: surfaceColor,
      dividerColor: borderColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
      ),
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: primaryLight,
        surface: surfaceColor,
        error: errorColor,
      ),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: headingLarge,
        displayMedium: headingMedium,
        titleLarge: headingSmall,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: textOnDark,
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
    );
  }
}
