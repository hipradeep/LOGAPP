import 'package:flutter/material.dart';

import '../controllers/theme_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/app_provider.dart';
import '../widgets/app_spacers.dart';

/// Bottom sheet offering the three theme choices: Dark, Light and System.
///
/// Reads the mode with `AppProvider.watch` so selecting an option repaints the
/// sheet immediately instead of waiting for a reopen.
class AppearanceSheet extends StatelessWidget {
  const AppearanceSheet({super.key});

  static Future<void> show(BuildContext context) {
    final themeController = AppProvider.read<ThemeController>(context);
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => AppProvider<ThemeController>(
        notifier: themeController,
        child: const AppearanceSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeController = AppProvider.watch<ThemeController>(context);
    final mode = themeController.themeMode;

    const options = <_ThemeOption>[
      _ThemeOption(ThemeMode.light, 'Light', Icons.light_mode_rounded),
      _ThemeOption(ThemeMode.dark, 'Dark', Icons.dark_mode_rounded),
      _ThemeOption(ThemeMode.system, 'System', Icons.brightness_auto_rounded),
    ];

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
          border: Border.all(color: AppTheme.borderColor(context)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'Appearance',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
            ),
            for (final option in options)
              _ThemeOptionTile(
                option: option,
                isSelected: option.mode == mode,
                onTap: () => themeController.setThemeMode(option.mode),
              ),
            const VGapSm(),
          ],
        ),
      ),
    );
  }
}

class _ThemeOption {
  final ThemeMode mode;
  final String label;
  final IconData icon;

  const _ThemeOption(this.mode, this.label, this.icon);
}

class _ThemeOptionTile extends StatelessWidget {
  final _ThemeOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOptionTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = isSelected
        ? AppTheme.primaryColor
        : AppTheme.textPrimaryColor(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(option.icon, color: foreground, size: 22),
            const HGapMd(),
            Expanded(
              child: Text(
                option.label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: foreground,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_rounded,
                  color: AppTheme.primaryColor, size: 20),
          ],
        ),
      ),
    );
  }
}
