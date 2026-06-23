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
  // Use for: Main buttons, primary active states, and dominant branding elements.
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
  // Use for: Active text labels, glowing indicators, highlights on dark backgrounds.
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
  // Use for: Gradients, deep shadows, and pressed button states.
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
  // Use for: Secondary actions, links, or contrasting gradient blends.
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
  // Use for: The absolute bottom layer of the app, main screen backgrounds.
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
  // Use for: Cards, bottom navigation bars, dialogs, and text fields.
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

  // === Light Theme Surface Tokens (Mockup Palette) ===

  // Light Background (Ambient light blue tint)
  static const lightBackgroundColor = Color(0xFFEFF6FF);

  // Light Surface (Pure white for cards/modals with soft shadows)
  static const lightSurfaceColor = Color(0xFFFFFFFF);

  // Light Surface Variant (Light tinted fill for inputs/containers)
  static const lightSurfaceVariant = Color(0xFFF3F8FF);

  // Light Border (Subtle soft periwinkle-blue border)
  static const lightBorderColor = Color(0xFFE0ECFC);

  // Light Text Primary (Slate 900 for dark premium high-contrast titles)
  static const lightTextPrimary = Color(0xFF0F172A);

  // Light Text Secondary (Slate 700 for subtitles/labels)
  static const lightTextSecondary = Color(0xFF334155);

  // Light Text Muted (Slate 500 for captions/placeholders)
  static const lightTextMuted = Color(0xFF64748B);

  // === Context-Aware Helpers ===
  // Use these in non-const widget trees that need to respond to the active theme.

  /// Returns whether the current context is in dark mode.
  static bool isDarkMode(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Returns the surface color for the current theme (card/dialog backgrounds).
  static Color surface(BuildContext context) =>
      isDarkMode(context) ? surfaceColor : lightSurfaceColor;

  /// Returns the background color for the current theme (screen backgrounds).
  static Color background(BuildContext context) =>
      isDarkMode(context) ? backgroundColor : lightBackgroundColor;

  /// Returns the border/divider color for the current theme.
  static Color borderColor(BuildContext context) =>
      isDarkMode(context)
          ? Colors.white.withValues(alpha: 0.12)
          : const Color(0xFFCBD5E1);

  /// Returns the primary text color for the current theme.
  static Color textPrimaryColor(BuildContext context) =>
      isDarkMode(context) ? textPrimary : lightTextPrimary;

  /// Returns the secondary text color for the current theme.
  static Color textSecondaryColor(BuildContext context) =>
      isDarkMode(context) ? textSecondary : lightTextSecondary;

  /// Returns the muted text color for the current theme.
  static Color textMutedColor(BuildContext context) =>
      isDarkMode(context) ? textMuted : lightTextMuted;

  /// Returns the primary accent color appropriate for the current theme.
  static Color primaryAccentColor(BuildContext context) =>
      isDarkMode(context) ? primaryLight : primaryColor;

  /// Returns the hint/placeholder text color.
  static Color hintColor(BuildContext context) =>
      isDarkMode(context)
          ? textSecondary.withValues(alpha: 0.5)
          : lightTextMuted.withValues(alpha: 0.6);

  /// Returns the border/divider color for inputs/containers.
  static Color inputBorderColor(BuildContext context) =>
      isDarkMode(context)
          ? Colors.white.withValues(alpha: 0.24)
          : lightTextMuted.withValues(alpha: 0.25);

  /// Returns the background color for quick action cards.
  static Color quickActionCardColor(BuildContext context) =>
      isDarkMode(context) ? Colors.white.withValues(alpha: 0.08) : lightSurfaceColor;

  /// Returns the shadow color for quick action cards.
  static Color quickActionShadowColor(BuildContext context, Color accentColor) =>
      isDarkMode(context) ? accentColor.withValues(alpha: 0.02) : const Color(0xFFC4D0FB).withValues(alpha: 0.15);

  /// Returns the border color for quick action cards.
  static Color quickActionBorderColor(BuildContext context) =>
      isDarkMode(context) ? Colors.white.withValues(alpha: 0.1) : borderColor(context);

  /// Returns the subtle background fill color for interactive items.
  static Color subtleFillColor(BuildContext context) =>
      isDarkMode(context)
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.07);

  /// Returns the background color for decrement/minus buttons in water logs.
  static Color waterLogMinusButtonColor(BuildContext context) =>
      isDarkMode(context)
          ? const Color(0xFFEFF6FF).withValues(alpha: 0.12)
          : const Color(0xFFEFF6FF).withValues(alpha: 0.7);

  /// Returns the text color for selected choice chips.
  static Color selectedChipTextColor(BuildContext context) =>
      isDarkMode(context) ? textPrimary : Colors.white;

  /// Returns the drop shadow color for elevated surfaces.
  static Color shadowColor(BuildContext context) =>
      isDarkMode(context)
          ? Colors.black.withValues(alpha: 0.3)
          : const Color(0xFFC4D0FB).withValues(alpha: 0.2);

  /// Returns the inactive thumb color for switches.
  static Color switchInactiveThumbColor(BuildContext context) =>
      isDarkMode(context) ? textSecondary : lightTextMuted;

  /// Returns the inactive track color for switches.
  static Color switchInactiveTrackColor(BuildContext context) =>
      isDarkMode(context) ? Colors.white10 : Colors.black12;

  /// Returns the segmented button selected background color.
  static Color segmentedSelectedBgColor(BuildContext context) =>
      primaryColor.withValues(alpha: isDarkMode(context) ? 0.2 : 0.15);

  /// Returns the background surface color with opacity for settings container.
  static Color settingsContainerColor(BuildContext context) =>
      surface(context).withValues(alpha: isDarkMode(context) ? 0.45 : 0.8);

  /// Returns the border color for active category toggle buttons.
  static Color activeToggleBorderColor(BuildContext context) =>
      isDarkMode(context)
          ? primaryLight.withValues(alpha: 0.5)
          : primaryDark.withValues(alpha: 0.5);

  /// Returns the text color for pill badges.
  static Color pillBadgeTextColor(BuildContext context) =>
      isDarkMode(context) ? Colors.white : primaryColor;

  /// Returns the category input text color.
  static Color categoryTextColor(BuildContext context, {required bool isEditing}) =>
      isDarkMode(context)
          ? (isEditing ? Colors.white54 : Colors.white)
          : (isEditing ? lightTextMuted : lightTextPrimary);

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

  // Checkbox Sizes
  static const double taskCheckboxSize = 24.0;
  static const double subtaskCheckboxSize = 20.0;

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

  /// Returns the background gradient for the current theme.
  static LinearGradient resolvedBackgroundGradient(BuildContext context) =>
      isDarkMode(context) ? backgroundGradient : lightBackgroundGradient;

  // === Typography (Text Styles) ===
  
  // Display/Large Headings (32px, Bold, Outfit font)
  // Use for: Massive screen titles (e.g., "Join Core" on Signup screen).
  static TextStyle get headingLarge => GoogleFonts.outfit(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: isDark ? textPrimary : lightTextPrimary,
  );

  // Section Headings (24px, Bold, Outfit font)
  // Use for: Major section headers, modal titles, profile names.
  static TextStyle get headingMedium => GoogleFonts.outfit(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: isDark ? textPrimary : lightTextPrimary,
  );

  // Sub-headings (18px, SemiBold, Outfit font)
  // Use for: Card titles, list headers, prominent labels.
  static TextStyle get headingSmall => GoogleFonts.outfit(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: isDark ? textPrimary : lightTextPrimary,
  );

  // Primary Body Text (16px, Normal, Inter font)
  // Use for: Main descriptive text, primary subtitles, standard input text.
  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 16,
    color: isDark ? textPrimary : lightTextPrimary,
  );

  // Secondary Body Text (14px, Normal, Inter font)
  // Use for: Secondary descriptions, helper texts, inactive tab labels.
  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 14,
    color: isDark ? textSecondary : lightTextSecondary,
  );

  // Small Text (12px, Normal, Inter font)
  // Use for: Captions, dates, timestamps, small tags.
  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 12,
    color: isDark ? textSecondary : lightTextSecondary,
  );

  // Micro Text (10px, Normal, Inter font)
  // Use for: Bottom navigation labels, extreme fine print.
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
      checkboxTheme: CheckboxThemeData(
        side: const BorderSide(color: textMuted, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
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

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: lightBackgroundColor,
      cardColor: lightSurfaceColor,
      dividerColor: lightBorderColor,
      iconTheme: const IconThemeData(color: lightTextPrimary),
      checkboxTheme: CheckboxThemeData(
        side: const BorderSide(color: lightTextMuted, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
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
