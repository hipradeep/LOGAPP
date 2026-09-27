import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Available app themes. The app currently defaults to [studyMinimalist]
/// as designed in the minimalist monochrome palette, but the architecture
/// provides a clear path for future theme upgrades.
enum AppThemeType {
  studyMinimalist,
  // Extensible for future upgrades:
  // dark,
  // warmSepia,
}

class AppTheme {
  // Active theme configuration (locked to studyMinimalist by default)
  static const AppThemeType activeThemeType = AppThemeType.studyMinimalist;
  static bool isDark = false;

  // === Core Palette (Monochrome / Duo-tone Minimalist) ===
  
  // Brand Primary (Deep Charcoal / Black)
  static const Color primaryColor = Color(0xFF18181B);
  static const Color primaryLight = Color(0xFF27272A);
  static const Color primaryDark = Color(0xFF09090B);

  // Backgrounds
  // Off-white soft porcelain background
  static const Color backgroundColor = Color(0xFFFBFBFC);
  
  // Surfaces
  static const Color surfaceColor = Color(0xFFFFFFFF);
  // Elevated / Soft Grey Surface for light cards and icon containers (#F4F4F6)
  static const Color surfaceVariant = Color(0xFFF4F4F6);
  // Inverted / Dark Surface for featured cards & dark sections (#1E1E1E)
  static const Color darkCardColor = Color(0xFF1E1E1E);

  // Borders & Dividers
  static const Color borderColor = Color(0xFFE5E7EB);
  static const Color borderSubtle = Color(0xFFF0F0F2);

  // Text Colors
  static const Color textPrimary = Color(0xFF111827);    // Charcoal/Near Black
  static const Color textSecondary = Color(0xFF6B7280);  // Slate Grey
  static const Color textMuted = Color(0xFF9CA3AF);      // Light Slate Grey
  static const Color textOnDark = Color(0xFFFFFFFF);     // White for dark cards
  static const Color textOnDarkSecondary = Color(0xFFD1D5DB);

  // Badges & Accents
  static const Color darkBadgeFill = Color(0xFF2C2C2E);
  static const Color lightBadgeFill = Color(0xFFEFEFF2);

  // Feedback Colors
  static const Color errorColor = Color(0xFFEF4444);
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);

  // === Layout Constants ===
  static const EdgeInsets defaultScreenPadding = EdgeInsets.symmetric(horizontal: 24.0);
  static const EdgeInsets defaultCardPadding = EdgeInsets.all(20.0);
  
  // Radii matching the modern rounded aesthetic from the image
  static const double cardBorderRadius = 22.0;
  static const double pillBorderRadius = 28.0;
  static const double defaultBorderRadius = 16.0;
  static const double smallBorderRadius = 12.0;
  static const double iconBoxRadius = 14.0;
  
  // Standard Heights
  static const double buttonHeight = 54.0;
  static const double bnbHeight = 68.0;

  // Standard Spacings
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacingXxl = 48.0;

  // Standard Icon Sizes
  static const double iconSizeXs = 16.0;
  static const double iconSizeSm = 20.0;
  static const double iconSizeMd = 24.0;
  static const double iconSizeLg = 32.0;
  static const double iconSizeXl = 48.0;

  // Context-aware color helpers
  static Color surface(BuildContext context) => surfaceColor;
  static Color background(BuildContext context) => backgroundColor;
  static Color getBorderColor(BuildContext context) => borderColor;
  static Color shadowColor(BuildContext context) => Colors.black.withValues(alpha: 0.05);

  // === Typography ===
  
  // Large Hero Heading (e.g., "Keep your mind Healthy")
  static TextStyle get headingLarge => GoogleFonts.outfit(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  // Section Heading (e.g., "Self Care Activity", "Explore new activities")
  static TextStyle get headingMedium => GoogleFonts.outfit(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.3,
  );

  // Sub-heading / Card Title (e.g., "Go out for a walk & explore")
  static TextStyle get headingSmall => GoogleFonts.outfit(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  // Lead / Greeting text (e.g., "Choose your", "Keep your")
  static TextStyle get textLead => GoogleFonts.outfit(
    fontSize: 20,
    fontWeight: FontWeight.w400,
    color: textSecondary,
  );

  // Primary Body
  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 16,
    color: textPrimary,
    height: 1.4,
  );

  // Secondary Body (e.g., subtitles, list item descriptions)
  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 14,
    color: textSecondary,
    height: 1.4,
  );

  // Small Text / Badges / Duration
  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 12,
    color: textSecondary,
  );

  // Action / Button Text (e.g., "ADD", "Get started")
  static TextStyle get actionText => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    color: textPrimary,
  );

  // === ThemeData ===
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
        iconTheme: IconThemeData(color: primaryColor),
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
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
