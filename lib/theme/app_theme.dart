import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // === App Colors ===
  
  // Brand Primary (Violet 500)
  // Use for: Main buttons, primary active states, and dominant branding elements.
  static const primaryColor = Color(0xFF8B5CF6); 
  
  // Brand Light (Violet 300)
  // Use for: Active text labels, glowing indicators, highlights on dark backgrounds.
  static const primaryLight = Color(0xFFC4B5FD); 
  
  // Brand Dark (Violet 700)
  // Use for: Gradients, deep shadows, and pressed button states.
  static const primaryDark = Color(0xFF6D28D9);  
  
  // Secondary Accent (Blue 500)
  // Use for: Secondary actions, links, or contrasting gradient blends.
  static const secondaryColor = Color(0xFF3B82F6); 
  
  // Background Deep (Slate 900)
  // Use for: The absolute bottom layer of the app, main screen backgrounds.
  static const backgroundColor = Color(0xFF0F172A); 
  
  // Surface Elevated (Slate 800)
  // Use for: Cards, bottom navigation bars, dialogs, and text fields.
  static const surfaceColor = Color(0xFF1E293B);    
  
  // Destructive/Error (Rose 500)
  // Use for: Error messages, delete buttons, missed attendance, failed actions.
  static const errorColor = Color(0xFFF43F5E);   
  
  // Success (Emerald 500)
  // Use for: Active memberships, successful saves, positive stats.
  static const successColor = Color(0xFF10B981); 
  
  // Warning
  // Use for: Expiring memberships, warnings, missing information.
  static const warningColor = Colors.orangeAccent;
  
  // Text Colors
  // Use for: Main headings and primary body text.
  static const textPrimary = Colors.white;
  
  // Text Secondary (Slate 400)
  // Use for: Subtitles, helper text, inactive tabs, and placeholders.
  static const textSecondary = Color(0xFF94A3B8); 
  
  // Text Muted (White 54% Opacity)
  // Use for: Extremely low-emphasis text, borders, subtle dividers.
  static const textMuted = Colors.white54;

  // === Layout Constants ===
  // Standard horizontal padding for most screens
  static const EdgeInsets defaultScreenPadding = EdgeInsets.symmetric(horizontal: 24.0);
  
  // Standard padding inside cards and containers
  static const EdgeInsets defaultCardPadding = EdgeInsets.all(16.0);
  
  // Standard corner radius for buttons, cards, and text fields
  static const double defaultBorderRadius = 16.0;
  static const double smallBorderRadius = 8.0;
  
  // Standard heights
  static const double buttonHeight = 56.0;
  
  // Standard Spacing (Gaps between elements)
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
  static const double iconSizeXxl = 64.0;

  // Common Gradients
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [backgroundColor, surfaceColor],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryColor, secondaryColor],
  );

  // === Typography (Text Styles) ===
  
  // Display/Large Headings (32px, Bold, Outfit font)
  // Use for: Massive screen titles (e.g., "Join Core" on Signup screen).
  static TextStyle get headingLarge => GoogleFonts.outfit(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );

  // Section Headings (24px, Bold, Outfit font)
  // Use for: Major section headers, modal titles, profile names.
  static TextStyle get headingMedium => GoogleFonts.outfit(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );

  // Sub-headings (18px, SemiBold, Outfit font)
  // Use for: Card titles, list headers, prominent labels.
  static TextStyle get headingSmall => GoogleFonts.outfit(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  // Primary Body Text (16px, Normal, Inter font)
  // Use for: Main descriptive text, primary subtitles, standard input text.
  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 16,
    color: textPrimary,
  );

  // Secondary Body Text (14px, Normal, Inter font)
  // Use for: Secondary descriptions, helper texts, inactive tab labels.
  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 14,
    color: textSecondary,
  );

  // Small Text (12px, Normal, Inter font)
  // Use for: Captions, dates, timestamps, small tags.
  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 12,
    color: textSecondary,
  );

  // Micro Text (10px, Normal, Inter font)
  // Use for: Bottom navigation labels, extreme fine print.
  static TextStyle get bodyMicro => GoogleFonts.inter(
    fontSize: 10,
    color: textMuted,
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
          borderSide: BorderSide(color: Colors.white10),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(defaultBorderRadius),
          borderSide: BorderSide(color: Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(defaultBorderRadius),
          borderSide: BorderSide(color: primaryColor),
        ),
        labelStyle: TextStyle(color: textSecondary),
        hintStyle: TextStyle(color: Colors.white24),
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
