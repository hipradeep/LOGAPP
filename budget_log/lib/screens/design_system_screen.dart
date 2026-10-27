import 'package:flutter/material.dart';
import '../controllers/theme_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_fab.dart';
import '../widgets/app_provider.dart';
import '../widgets/app_spacers.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/sheet_action_widgets.dart';

class DesignSystemScreen extends StatelessWidget {
  final bool showBackButton;

  const DesignSystemScreen({super.key, this.showBackButton = false});

  void _showSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SheetContainer(
        children: [
          const SheetHandleBar(),
          const VGapMd(),
          const SheetHeader(
            badge: SheetHeaderBadge(
              child: Icon(Icons.receipt_long_outlined, size: 20),
            ),
            title: 'Add transaction',
            subtitle: 'Shared SheetContainer, header, rows and actions.',
          ),
          const VGapMd(),
          SheetActionRow(
            icon: Icons.arrow_upward_rounded,
            title: 'Expense',
            subtitle: 'Money going out',
            onTap: () => Navigator.pop(ctx),
          ),
          SheetActionRow(
            icon: Icons.arrow_downward_rounded,
            title: 'Income',
            subtitle: 'Money coming in',
            onTap: () => Navigator.pop(ctx),
          ),
          const VGapMd(),
          SheetDestructiveButton(
            title: 'Delete transaction',
            onTap: () => Navigator.pop(ctx),
          ),
          const VGapSm(),
          SheetCancelButton(onTap: () => Navigator.pop(ctx)),
        ],
      ),
    );
  }

  void _showDialog(BuildContext context) {
    ConfirmationDialog.showDelete(context, entityName: 'Transaction');
  }

  @override
  Widget build(BuildContext context) {
    final themeController = AppProvider.watch<ThemeController>(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            CustomAppBar(
              title: 'Design System',
              subtitle: 'Native Minimalist · Budget Log',
              showBackButton: showBackButton,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacingMd,
                  AppTheme.spacingSm,
                  AppTheme.spacingMd,
                  AppTheme.spacingXl,
                ),
                children: [
                  const _SectionHeader('APPEARANCE'),
                  _ThemeSelector(controller: themeController),
                  const VGapLg(),
                  const _SectionHeader('SEMANTIC COLORS'),
                  const _ColorGrid(),
                  const VGapLg(),
                  const _SectionHeader('CATEGORY TINTS'),
                  const _TintRow(),
                  const VGapLg(),
                  const _SectionHeader('TYPOGRAPHY'),
                  const _TypographySample(),
                  const VGapLg(),
                  const _SectionHeader('RADII'),
                  const _ShapeRow(),
                  const VGapLg(),
                  const _SectionHeader('SPACING'),
                  const _SpacingRow(),
                  const VGapLg(),
                  const _SectionHeader('BUTTONS'),
                  const _ButtonsSample(),
                  const VGapLg(),
                  const _SectionHeader('TEXT FIELDS'),
                  const _FieldsSample(),
                  const VGapLg(),
                  const _SectionHeader('CONTROLS'),
                  const _ControlsSample(),
                  const VGapLg(),
                  const _SectionHeader('CARD & LIST ROW'),
                  const _CardSample(),
                  const VGapLg(),
                  const _SectionHeader('BOTTOM NAVIGATION'),
                  const _NavigationSample(),
                  const VGapLg(),
                  const _SectionHeader('BOTTOM SHEET'),
                  _SheetSample(onPressed: () => _showSheet(context)),
                  const VGapLg(),
                  const _SectionHeader('CONFIRMATION DIALOG'),
                  _DialogSample(onPressed: () => _showDialog(context)),
                  const VGapLg(),
                  const _SectionHeader('EMPTY STATE'),
                  const AppEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No transactions yet',
                    description:
                        'Your expenses and income will appear here once you add them.',
                    actionLabel: 'Add transaction',
                  ),
                  const VGapLg(),
                  Center(
                    child: Text(
                      'Tap the FAB to preview the add-transaction sheet.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: AppFab(
        onPressed: () => _showSheet(context),
        icon: Icons.add_rounded,
        label: 'Add',
        tooltip: 'Add transaction',
      ),
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  final ThemeController controller;

  const _ThemeSelector({required this.controller});

  String _label(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => 'System',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppTheme.spacingSm,
          runSpacing: AppTheme.spacingSm,
          children: ThemeMode.values.map((mode) {
            return ChoiceChip(
              label: Text(_label(mode)),
              selected: controller.themeMode == mode,
              onSelected: (_) => controller.setThemeMode(mode),
            );
          }).toList(),
        ),
        const VGapSm(),
        Text(
          'Active brightness: ${Theme.of(context).brightness.name}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppTheme.textMutedColor(context),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ColorGrid extends StatelessWidget {
  const _ColorGrid();

  @override
  Widget build(BuildContext context) {
    final swatches = [
      ('Background', AppTheme.background(context)),
      ('Surface', AppTheme.surface(context)),
      ('Surface variant', AppTheme.surfaceVariant(context)),
      ('Border', AppTheme.borderColor(context)),
      ('Text primary', AppTheme.textPrimaryColor(context)),
      ('Text secondary', AppTheme.textSecondaryColor(context)),
      ('Primary', AppTheme.primaryColor),
      ('Income', AppTheme.incomeColor),
      ('Expense', AppTheme.expenseColor),
      ('Warning', AppTheme.warningColor),
    ];

    return Wrap(
      spacing: AppTheme.spacingSm,
      runSpacing: AppTheme.spacingSm,
      children: swatches.map((entry) {
        return _ColorSwatch(label: entry.$1, color: entry.$2);
      }).toList(),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final String label;
  final Color color;

  const _ColorSwatch({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(AppTheme.spacingSm),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.borderColor(context)),
            ),
          ),
          const HGapSm(),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _TintRow extends StatelessWidget {
  const _TintRow();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppTheme.spacingSm,
      runSpacing: AppTheme.spacingSm,
      children: List.generate(AppTheme.tintCount, (index) {
        final tint = AppTheme.tintFor(context, index);
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingSm,
            vertical: AppTheme.spacingXs,
          ),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant(context),
            borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
            border: Border.all(color: AppTheme.borderColor(context)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: tint.$2,
                  shape: BoxShape.circle,
                ),
              ),
              const HGapXs(),
              Text(
                'Tint ${index + 1}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tint.$2),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _TypographySample extends StatelessWidget {
  const _TypographySample();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final rows = [
      ('displaySmall', textTheme.displaySmall, '₹ 1,25,000'),
      ('headlineSmall', textTheme.headlineSmall, 'Budget/Log'),
      ('titleLarge', textTheme.titleLarge, 'Section title'),
      ('titleMedium', textTheme.titleMedium, 'Card title'),
      ('bodyLarge', textTheme.bodyLarge, 'Primary body text'),
      ('bodyMedium', textTheme.bodyMedium, 'Secondary body text'),
      ('bodySmall', textTheme.bodySmall, 'Supporting metadata'),
      ('labelLarge', textTheme.labelLarge, 'Action label'),
      ('labelSmall', textTheme.labelSmall, 'CAPTION'),
    ];

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              SizedBox(
                width: 96,
                child: Text(
                  row.$1,
                  style: textTheme.labelSmall?.copyWith(
                    color: AppTheme.textMutedColor(context),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  row.$3,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: row.$2,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ShapeRow extends StatelessWidget {
  const _ShapeRow();

  @override
  Widget build(BuildContext context) {
    final shapes = [
      ('Card 12', AppTheme.cardBorderRadius),
      ('Small 8', AppTheme.smallBorderRadius),
      ('Pill 20', AppTheme.pillBorderRadius),
      ('Sheet 16', 16.0),
    ];

    return Wrap(
      spacing: AppTheme.spacingSm,
      runSpacing: AppTheme.spacingSm,
      children: shapes.map((shape) {
        return Container(
          width: 76,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant(context),
            borderRadius: BorderRadius.circular(shape.$2),
            border: Border.all(color: AppTheme.borderColor(context)),
          ),
          child: Text(shape.$1, style: Theme.of(context).textTheme.bodySmall),
        );
      }).toList(),
    );
  }
}

class _SpacingRow extends StatelessWidget {
  const _SpacingRow();

  @override
  Widget build(BuildContext context) {
    final spacings = [
      ('4', AppTheme.spacingXs),
      ('8', AppTheme.spacingSm),
      ('16', AppTheme.spacingMd),
      ('24', AppTheme.spacingLg),
      ('32', AppTheme.spacingXl),
      ('48', AppTheme.spacingXxl),
    ];

    return Column(
      children: spacings.map((spacing) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  spacing.$1,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Container(
                width: spacing.$2,
                height: 6,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ButtonsSample extends StatelessWidget {
  const _ButtonsSample();

  void _notify(BuildContext context, String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label pressed')));
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppTheme.spacingSm,
      runSpacing: AppTheme.spacingSm,
      children: [
        FilledButton(
          onPressed: () => _notify(context, 'Filled'),
          child: const Text('Filled'),
        ),
        OutlinedButton(
          onPressed: () => _notify(context, 'Outlined'),
          child: const Text('Outlined'),
        ),
        TextButton(
          onPressed: () => _notify(context, 'Text'),
          child: const Text('Text'),
        ),
      ],
    );
  }
}

class _FieldsSample extends StatelessWidget {
  const _FieldsSample();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        TextField(
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Amount',
            hintText: '0.00',
            prefixText: '₹ ',
          ),
        ),
        VGapSm(),
        TextField(
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Note',
            hintText: 'Optional description',
          ),
        ),
      ],
    );
  }
}

class _ControlsSample extends StatelessWidget {
  const _ControlsSample();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppTheme.spacingSm,
      runSpacing: AppTheme.spacingSm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Switch(value: true, onChanged: (_) {}),
        Checkbox(value: true, onChanged: (_) {}),
        const Chip(label: Text('Chip')),
        FilterChip(
          label: const Text('Filter'),
          selected: true,
          onSelected: (_) {},
        ),
      ],
    );
  }
}

class _CardSample extends StatelessWidget {
  const _CardSample();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.pastelGreen(context),
          child: Icon(
            Icons.shopping_basket_outlined,
            color: AppTheme.pastelGreenText(context),
          ),
        ),
        title: const Text('Groceries'),
        subtitle: const Text('Today · UPI'),
        trailing: Text(
          '₹ 1,250',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}

class _NavigationSample extends StatelessWidget {
  const _NavigationSample();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
      child: AppBottomNavigation(
        selectedIndex: 0,
        onDestinationSelected: (_) {},
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Budget',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Log',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _SheetSample extends StatelessWidget {
  final VoidCallback onPressed;

  const _SheetSample({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.open_in_new_rounded),
      label: const Text('Open bottom sheet'),
    );
  }
}

class _DialogSample extends StatelessWidget {
  final VoidCallback onPressed;

  const _DialogSample({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.delete_outline_rounded),
      label: const Text('Open confirmation dialog'),
    );
  }
}
