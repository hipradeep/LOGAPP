import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/full_screen_page.dart';
import '../controllers/theme_controller.dart';
import '../widgets/app_provider.dart';

class ThemeSelectionScreen extends StatelessWidget {
  const ThemeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = AppProvider.watch<ThemeController>(context);
    
    final themes = [
      ThemeOption(
        type: AppThemeType.light,
        name: 'Classic Light',
        description: 'Clean and bright aesthetic with high readability.',
        primary: const Color(0xFF8B5CF6),
        secondary: const Color(0xFF3B82F6),
        background: const Color(0xFFEFF6FF),
        surface: const Color(0xFFFFFFFF),
        isDark: false,
      ),
      ThemeOption(
        type: AppThemeType.dark,
        name: 'Classic Dark',
        description: 'Sleek slate dark theme, gentle on the eyes.',
        primary: const Color(0xFF8B5CF6),
        secondary: const Color(0xFF3B82F6),
        background: const Color(0xFF0F172A),
        surface: const Color(0xFF1E293B),
        isDark: true,
      ),
      ThemeOption(
        type: AppThemeType.orix,
        name: 'Orix Gold',
        description: 'Premium gold and deep purple theme.',
        primary: const Color(0xFFF0C38E),
        secondary: const Color(0xFFF1AA9B),
        background: const Color(0xFF312C51),
        surface: const Color(0xFF48426D),
        isDark: true,
      ),
      ThemeOption(
        type: AppThemeType.logo,
        name: 'Teal Logo',
        description: 'Brand-inspired teal and cyan color palette.',
        primary: const Color(0xFF206070),
        secondary: const Color(0xFF3090D0),
        background: const Color(0xFF0A1518),
        surface: const Color(0xFF122327),
        isDark: true,
      ),
      ThemeOption(
        type: AppThemeType.earth,
        name: 'Forest Earth',
        description: 'Warm, cozy earthy colors and deep forest greens.',
        primary: const Color(0xFF6D9773),
        secondary: const Color(0xFFB46617),
        background: const Color(0xFF071F1A),
        surface: const Color(0xFF0E322A),
        isDark: true,
      ),
      ThemeOption(
        type: AppThemeType.system,
        name: 'System Default',
        description: 'Syncs automatically with your device settings.',
        primary: AppTheme.primaryColor,
        secondary: AppTheme.secondaryColor,
        background: AppTheme.isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
        surface: AppTheme.isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF),
        isDark: AppTheme.isDark,
      ),
    ];

    return FullScreenPage(
      title: 'Select Theme',
      showBackButton: true,
      isScrollable: true,
      children: [
        const VGapMd(),
        Padding(
          padding: EdgeInsets.zero,
          child: Text(
            'CHOOSE YOUR STYLE',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.primaryAccentColor(context),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const VGapSm(),
        Padding(
          padding: EdgeInsets.zero,
          child: Text(
            'Personalize your workspace with one of our premium, handcrafted themes.',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
        ),
        const VGapLg(),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: themes.length,
          itemBuilder: (context, index) {
            final theme = themes[index];
            return ThemeCard(
              option: theme,
              isSelected: themeController.themeType == theme.type,
              onTap: () => themeController.setThemeType(theme.type),
            );
          },
        ),
        const VGapXxl(),
      ],
    );
  }
}

class ThemeOption {
  final AppThemeType type;
  final String name;
  final String description;
  final Color primary;
  final Color secondary;
  final Color background;
  final Color surface;
  final bool isDark;

  const ThemeOption({
    required this.type,
    required this.name,
    required this.description,
    required this.primary,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.isDark,
  });
}

class ThemeCard extends StatelessWidget {
  final ThemeOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const ThemeCard({
    super.key,
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = AppTheme.primaryAccentColor(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: isSelected ? 0.3 : 0.15),
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        border: Border.all(
          color: isSelected ? activeColor : AppTheme.borderColor(context),
          width: isSelected ? 2.0 : 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            option.name,
                            style: AppTheme.headingSmall.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const HGapSm(),
                          if (isSelected)
                            Icon(Icons.check_circle_rounded, color: activeColor, size: 16),
                        ],
                      ),
                      const VGapXs(),
                      Text(
                        option.description,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const HGapMd(),
                _buildPalettePreview(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPalettePreview() {
    return Container(
      width: 80,
      height: 48,
      decoration: BoxDecoration(
        color: option.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // Surface preview
          Positioned(
            left: 8,
            right: 8,
            top: 8,
            bottom: 8,
            child: Container(
              decoration: BoxDecoration(
                color: option.surface,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    CircleAvatar(radius: 3, backgroundColor: option.primary),
                    CircleAvatar(radius: 3, backgroundColor: option.secondary),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
