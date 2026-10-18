import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/revision_level_palette.dart';
import '../widgets/app_spacers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/add_pill_button.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/compact_list_item.dart';
import '../widgets/course_icon_chip.dart';
import '../widgets/sheet_action_widgets.dart';
import '../widgets/study_confirmation_dialog.dart';
import '../widgets/study_text_fields.dart';

/// In-app living style guide.
///
/// Renders every design token (colors, tints, revision levels, typography,
/// radii, spacing) and every shared component (buttons, fields, list rows,
/// cards, chips, dialogs, sheets) using only [AppTheme] tokens and [AppSpacers].
///
/// Native-minimalist reference: see docs/native_minimalist_style.md.
class DesignSystemScreen extends StatefulWidget {
  const DesignSystemScreen({super.key});

  @override
  State<DesignSystemScreen> createState() => _DesignSystemScreenState();
}

class _DesignSystemScreenState extends State<DesignSystemScreen> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _showSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SheetContainer(
        children: [
          const SheetHandleBar(),
          const VGapMd(),
          const SheetHeader(
            badge: SheetHeaderBadge(child: Icon(Icons.layers_outlined, size: 20)),
            title: 'Bottom Sheet',
            subtitle: 'Shared SheetContainer shell with header, rows and cancel.',
          ),
          const VGapMd(),
          SheetActionRow(
            icon: Icons.edit_outlined,
            title: 'Action row',
            subtitle: 'Icon, title, optional subtitle and chevron.',
            onTap: () => Navigator.pop(ctx),
          ),
          SheetActionRow(
            icon: Icons.copy_outlined,
            title: 'Another row',
            onTap: () => Navigator.pop(ctx),
          ),
          const VGapMd(),
          SheetDestructiveButton(
            title: 'Destructive action',
            onTap: () => Navigator.pop(ctx),
          ),
          const VGapSm(),
          SheetCancelButton(onTap: () => Navigator.pop(ctx)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            CustomAppBar(
              title: 'Design System',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  const _SectionHeader('SEMANTIC COLORS'),
                  const _ColorGrid(),
                  const VGapLg(),
                  const _SectionHeader('CATEGORY TINTS'),
                  const _TintRow(),
                  const VGapLg(),
                  const _SectionHeader('REVISION LEVELS'),
                  const _RevisionRow(),
                  const VGapLg(),
                  const _SectionHeader('TYPOGRAPHY'),
                  const _TypographySample(),
                  const VGapLg(),
                  const _SectionHeader('RADII'),
                  const _RadiusRow(),
                  const VGapLg(),
                  const _SectionHeader('SPACING'),
                  const _SpacingRow(),
                  const VGapLg(),
                  const _SectionHeader('BUTTONS'),
                  _ButtonsSample(onShowSheet: _showSheet),
                  const VGapLg(),
                  const _SectionHeader('TEXT FIELDS'),
                  _FieldsSample(
                    textController: _textController,
                    noteController: _noteController,
                  ),
                  const VGapLg(),
                  const _SectionHeader('CONTROLS'),
                  const _ControlsSample(),
                  const VGapLg(),
                  const _SectionHeader('CARDS & LIST ROWS'),
                  const _ListSample(),
                  const VGapLg(),
                  const _SectionHeader('CHIPS & BADGES'),
                  const _ChipsSample(),
                  const VGapLg(),
                  const _SectionHeader('DIALOG'),
                  const _DialogSample(),
                  const VGapLg(),
                  const _SectionHeader('EMPTY STATE'),
                  const AppEmptyState(
                    icon: Icons.menu_book_outlined,
                    title: 'Nothing here yet',
                    description: 'Shared AppEmptyState used across list screens.',
                    showCard: true,
                  ),
                  const VGapLg(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: AppTheme.textMutedColor(context),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Colors
// --------------------------------------------------------------------------

class _ColorGrid extends StatelessWidget {
  const _ColorGrid();

  @override
  Widget build(BuildContext context) {
    final swatches = <(String, Color)>[
      ('background', AppTheme.background(context)),
      ('surface', AppTheme.surface(context)),
      ('surfaceVariant', AppTheme.surfaceVariant(context)),
      ('border', AppTheme.borderColor(context)),
      ('textPrimary', AppTheme.textPrimaryColor(context)),
      ('textSecondary', AppTheme.textSecondaryColor(context)),
      ('textMuted', AppTheme.textMutedColor(context)),
      ('primary', AppTheme.primaryColor),
      ('error', AppTheme.errorColor),
      ('success', AppTheme.successColor),
      ('warning', AppTheme.warningColor),
    ];
    return Wrap(
      spacing: AppTheme.spacingSm,
      runSpacing: AppTheme.spacingSm,
      children: [
        for (final s in swatches) _ColorSwatch(label: s.$1, color: s.$2),
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final String label;
  final Color color;
  const _ColorSwatch({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
              border: Border.all(color: AppTheme.borderColor(context)),
            ),
          ),
          const VGapXs(),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondaryColor(context),
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
    final names = ['Purple', 'Green', 'Orange', 'Blue', 'Sky', 'Indigo'];
    return Column(
      children: [
        for (var i = 0; i < AppTheme.tintCount; i++) ...[
          _TintLine(index: i, name: names[i]),
          if (i < AppTheme.tintCount - 1) const VGapSm(),
        ],
      ],
    );
  }
}

class _TintLine extends StatelessWidget {
  final int index;
  final String name;
  const _TintLine({required this.index, required this.name});

  @override
  Widget build(BuildContext context) {
    final tint = AppTheme.tintFor(context, index);
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: tint.$2, shape: BoxShape.circle),
        ),
        const HGapSm(),
        Container(
          width: 40,
          height: 24,
          decoration: BoxDecoration(
            color: tint.$1,
            borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
            border: Border.all(color: tint.$3),
          ),
        ),
        const HGapSm(),
        Text(
          name,
          style: TextStyle(fontSize: 13, color: AppTheme.textPrimaryColor(context)),
        ),
        const Spacer(),
        Text(
          'tintFor($index)',
          style: TextStyle(fontSize: 11, color: AppTheme.textMutedColor(context)),
        ),
      ],
    );
  }
}

class _RevisionRow extends StatelessWidget {
  const _RevisionRow();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final level in RevisionLevelPalette.levels) ...[
          _RevisionLine(level: level),
          const VGapSm(),
        ],
        _RevisionLine(level: null),
      ],
    );
  }
}

class _RevisionLine extends StatelessWidget {
  final int? level;
  const _RevisionLine({required this.level});

  @override
  Widget build(BuildContext context) {
    final colors = level == null
        ? RevisionLevelPalette.completed(context)
        : RevisionLevelPalette.of(context, level!);
    final label = level == null ? 'Completed' : 'R$level';
    final interval =
        level == null ? '' : RevisionLevelPalette.interval(level!);
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: colors.background,
            shape: BoxShape.circle,
            border: Border.all(color: colors.border),
          ),
        ),
        const HGapSm(),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.foreground,
          ),
        ),
        const Spacer(),
        Text(
          interval,
          style: TextStyle(fontSize: 11, color: AppTheme.textMutedColor(context)),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------------
// Typography
// --------------------------------------------------------------------------

class _TypographySample extends StatelessWidget {
  const _TypographySample();

  @override
  Widget build(BuildContext context) {
    final rows = <(String, TextStyle)>[
      ('Heading Large', AppTheme.headingLarge),
      ('Heading Medium', AppTheme.headingMedium),
      ('Heading Small', AppTheme.headingSmall),
      ('Body Large', AppTheme.bodyLarge),
      ('Body Medium', AppTheme.bodyMedium),
      ('Body Small', AppTheme.bodySmall),
      ('Action Text', AppTheme.actionText),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final r in rows) ...[
          _TypographyLine(label: r.$1, style: r.$2),
          const VGapSm(),
        ],
      ],
    );
  }
}

class _TypographyLine extends StatelessWidget {
  final String label;
  final TextStyle style;
  const _TypographyLine({required this.label, required this.style});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: style),
        Text(
          '${style.fontSize?.toStringAsFixed(0)}px · ${style.fontWeight}',
          style: TextStyle(fontSize: 10, color: AppTheme.textMutedColor(context)),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------------
// Radii & Spacing
// --------------------------------------------------------------------------

class _RadiusRow extends StatelessWidget {
  const _RadiusRow();

  @override
  Widget build(BuildContext context) {
    final radii = <(String, double)>[
      ('card', AppTheme.cardBorderRadius),
      ('default', AppTheme.defaultBorderRadius),
      ('small', AppTheme.smallBorderRadius),
      ('pill', AppTheme.pillBorderRadius),
      ('iconBox', AppTheme.iconBoxRadius),
    ];
    return Wrap(
      spacing: AppTheme.spacingSm,
      runSpacing: AppTheme.spacingSm,
      children: [
        for (final r in radii) _RadiusBox(label: r.$1, radius: r.$2),
      ],
    );
  }
}

class _RadiusBox extends StatelessWidget {
  final String label;
  final double radius;
  const _RadiusBox({required this.label, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant(context),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: AppTheme.borderColor(context)),
          ),
        ),
        const VGapXs(),
        Text(
          '$label ${radius.toStringAsFixed(0)}',
          style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryColor(context)),
        ),
      ],
    );
  }
}

class _SpacingRow extends StatelessWidget {
  const _SpacingRow();

  @override
  Widget build(BuildContext context) {
    final gaps = <(String, double)>[
      ('Xs', AppTheme.spacingXs),
      ('Sm', AppTheme.spacingSm),
      ('Md', AppTheme.spacingMd),
      ('Lg', AppTheme.spacingLg),
      ('Xl', AppTheme.spacingXl),
      ('Xxl', AppTheme.spacingXxl),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final g in gaps) ...[
          Column(
            children: [
              Container(
                width: 14,
                height: g.$2,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const VGapXs(),
              Text(
                g.$1,
                style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryColor(context)),
              ),
            ],
          ),
          const HGapSm(),
        ],
      ],
    );
  }
}

// --------------------------------------------------------------------------
// Buttons
// --------------------------------------------------------------------------

class _ButtonsSample extends StatelessWidget {
  final VoidCallback onShowSheet;
  const _ButtonsSample({required this.onShowSheet});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppTheme.spacingSm,
          runSpacing: AppTheme.spacingSm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ElevatedButton(onPressed: () {}, child: const Text('Elevated')),
            FilledButton(onPressed: () {}, child: const Text('Filled')),
            FilledButton.tonal(onPressed: () {}, child: const Text('Tonal')),
            OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
            TextButton(onPressed: () {}, child: const Text('Text')),
            AddPillButton(label: 'Add', onPressed: () {}),
          ],
        ),
        const VGapMd(),
        Wrap(
          spacing: AppTheme.spacingSm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
            FloatingActionButton.small(onPressed: () {}, child: const Icon(Icons.add)),
            TextButton.icon(
              onPressed: onShowSheet,
              icon: const Icon(Icons.expand_more),
              label: const Text('Show sheet'),
            ),
          ],
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------------
// Fields
// --------------------------------------------------------------------------

class _FieldsSample extends StatelessWidget {
  final TextEditingController textController;
  final TextEditingController noteController;
  const _FieldsSample({required this.textController, required this.noteController});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UnderlineInputField(
          label: 'Title',
          controller: textController,
          hintText: 'Enter a title',
          isRequired: true,
        ),
        const VGapLg(),
        BorderlessDescriptionField(
          label: 'Notes',
          controller: noteController,
          hintText: 'Enter description…',
          maxLines: 3,
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------------
// Controls
// --------------------------------------------------------------------------

class _ControlsSample extends StatefulWidget {
  const _ControlsSample();

  @override
  State<_ControlsSample> createState() => _ControlsSampleState();
}

class _ControlsSampleState extends State<_ControlsSample> {
  bool _switchValue = true;
  bool _checkboxValue = true;
  double _slider = 0.4;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Switch'),
          value: _switchValue,
          onChanged: (v) => setState(() => _switchValue = v),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Checkbox'),
          value: _checkboxValue,
          onChanged: (v) => setState(() => _checkboxValue = v ?? false),
        ),
        Row(
          children: [
            const Text('Slider'),
            const HGapMd(),
            Expanded(
              child: Slider(value: _slider, onChanged: (v) => setState(() => _slider = v)),
            ),
          ],
        ),
        const Divider(),
      ],
    );
  }
}

// --------------------------------------------------------------------------
// List rows
// --------------------------------------------------------------------------

class _ListSample extends StatelessWidget {
  const _ListSample();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 0,
          color: AppTheme.surface(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
            side: BorderSide(color: AppTheme.borderColor(context)),
          ),
          child: const ListTile(
            leading: Icon(Icons.circle_outlined),
            title: Text('ListTile row'),
            subtitle: Text('Native Material 3 list row'),
            trailing: Icon(Icons.chevron_right),
          ),
        ),
        const VGapMd(),
        const CompactListItem(
          leading: CourseIconChip(courseId: 'design-system-sample'),
          title: 'CompactListItem',
          subtitle: 'Shared compact row used across list screens',
          courseName: 'Sample Course',
          moduleName: 'Module 1',
        ),
        const VGapXs(),
        const CompactListItem(
          leading: Icon(Icons.check_circle_outline, size: 22),
          title: 'Completed row',
          subtitle: 'isCompleted styling',
          isCompleted: true,
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------------
// Chips & badges
// --------------------------------------------------------------------------

class _ChipsSample extends StatelessWidget {
  const _ChipsSample();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppTheme.spacingSm,
      runSpacing: AppTheme.spacingSm,
      children: [
        const Chip(label: Text('Chip')),
        const Chip(
          avatar: Icon(Icons.bookmark_outline, size: 16),
          label: Text('With icon'),
        ),
        _Badge(label: 'Badge', color: AppTheme.primaryColor),
        _Badge(label: 'Success', color: AppTheme.successColor),
        _Badge(label: 'Error', color: AppTheme.errorColor),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Dialog
// --------------------------------------------------------------------------

class _DialogSample extends StatelessWidget {
  const _DialogSample();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton(
        onPressed: () => StudyConfirmationDialog.showDeleteCourse(
          context,
          courseTitle: 'Sample Course',
        ),
        child: const Text('Show confirmation dialog'),
      ),
    );
  }
}
