import 'package:flutter/material.dart';
import '../controllers/theme_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/full_screen_page.dart';

class ThemeSelectionScreen extends StatelessWidget {
  final ThemeController? themeController;

  const ThemeSelectionScreen({
    super.key,
    this.themeController,
  });

  @override
  Widget build(BuildContext context) {
    final controller = themeController ?? ThemeController();
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final currentType = controller.themeType;

        return FullScreenPage(
          title: 'Theme & Appearance',
          showBackButton: true,
          children: [
            const VGapMd(),
            Text(
              'Choose Visual Theme',
              style: AppTheme.headingSmall,
            ),
            const VGapXs(),
            Text(
              'Personalize your budget experience with custom color palettes and contrast levels.',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const VGapLg(),
            _ThemeOptionCard(
              title: 'Classic Dark',
              description: 'Vibrant purple accents on deep black glass canvas.',
              isSelected: currentType == AppThemeType.dark,
              primaryColor: const Color(0xFF8B5CF6),
              secondaryColor: const Color(0xFFC4B5FD),
              surfaceColor: const Color(0xFF1E1E2D),
              onTap: () => themeController.setThemeType(AppThemeType.dark),
            ),
            const VGapMd(),
            _ThemeOptionCard(
              title: 'Classic Light',
              description: 'Clean bright layout with elegant purple highlights.',
              isSelected: currentType == AppThemeType.light,
              primaryColor: const Color(0xFF8B5CF6),
              secondaryColor: const Color(0xFF6D28D9),
              surfaceColor: const Color(0xFFF3F4F6),
              onTap: () => themeController.setThemeType(AppThemeType.light),
            ),
            const VGapMd(),
            _ThemeOptionCard(
              title: 'Orix Gold',
              description: 'Warm champagne gold tones with deep twilight backdrop.',
              isSelected: currentType == AppThemeType.orix,
              primaryColor: const Color(0xFFF0C38E),
              secondaryColor: const Color(0xFFF1AA9B),
              surfaceColor: const Color(0xFF312C51),
              onTap: () => themeController.setThemeType(AppThemeType.orix),
            ),
            const VGapMd(),
            _ThemeOptionCard(
              title: 'Teal Logo',
              description: 'Deep oceanic cyan & marine teal with modern finish.',
              isSelected: currentType == AppThemeType.logo,
              primaryColor: const Color(0xFF206070),
              secondaryColor: const Color(0xFF389EB5),
              surfaceColor: const Color(0xFF0F3E48),
              onTap: () => themeController.setThemeType(AppThemeType.logo),
            ),
            const VGapMd(),
            _ThemeOptionCard(
              title: 'Forest Earth',
              description: 'Calming botanical green with earthy organic undertones.',
              isSelected: currentType == AppThemeType.earth,
              primaryColor: const Color(0xFF6D9773),
              secondaryColor: const Color(0xFF8FBA95),
              surfaceColor: const Color(0xFF4E7053),
              onTap: () => themeController.setThemeType(AppThemeType.earth),
            ),
            const VGapMd(),
            _ThemeOptionCard(
              title: 'System Default',
              description: 'Follow your Android system light/dark display preference.',
              isSelected: currentType == AppThemeType.system,
              primaryColor: AppTheme.primaryColor,
              secondaryColor: AppTheme.primaryLight,
              surfaceColor: AppTheme.cardColor,
              onTap: () => themeController.setThemeType(AppThemeType.system),
            ),
            const VGapXxl(),
          ],
        );
      },
    );
  }
}

class _ThemeOptionCard extends StatelessWidget {
  final String title;
  final String description;
  final bool isSelected;
  final Color primaryColor;
  final Color secondaryColor;
  final Color surfaceColor;
  final VoidCallback onTap;

  const _ThemeOptionCard({
    required this.title,
    required this.description,
    required this.isSelected,
    required this.primaryColor,
    required this.secondaryColor,
    required this.surfaceColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : AppTheme.borderColor.withValues(alpha: 0.5),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.borderColor.withValues(alpha: 0.6),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const HGapXs(),
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: secondaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
            const HGapMd(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                    ),
                  ),
                  const VGapXs(),
                  Text(
                    description,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const HGapSm(),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.borderColor,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
