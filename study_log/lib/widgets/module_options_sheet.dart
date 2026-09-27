import 'package:flutter/material.dart';
import '../models/section.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';
import 'study_confirmation_dialog.dart';
import '../controllers/sections_controller.dart';
import '../screens/add_section_screen.dart';

enum SectionOptionAction { edit, delete }

/// Bottom action sheet presented when long-pressing a Module row.
/// Presents Edit and Delete options matching the course options sheet.
class SectionOptionsSheet extends StatelessWidget {
  final Section section;
  final String courseTitle;
  final SectionsController? sectionsController;

  const SectionOptionsSheet({
    super.key,
    required this.section,
    required this.courseTitle,
    this.sectionsController,
  });

  static Future<void> show(
    BuildContext context, {
    required Section section,
    required String courseTitle,
    SectionsController? sectionsController,
  }) async {
    final action = await showModalBottomSheet<SectionOptionAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SectionOptionsSheet(
        section: section,
        courseTitle: courseTitle,
        sectionsController: sectionsController,
      ),
    );

    if (!context.mounted || action == null) return;

    switch (action) {
      case SectionOptionAction.edit:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddSectionScreen(
              courseId: section.courseId,
              courseTitle: courseTitle,
              sectionsController: sectionsController,
              sectionToEdit: section,
            ),
          ),
        );
        break;
      case SectionOptionAction.delete:
        final confirmed = await StudyConfirmationDialog.showDeleteSection(
          context,
          sectionTitle: section.title,
        );
        if (confirmed && context.mounted) {
          await sectionsController?.deleteSection(section.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Module "${section.title}" deleted'),
                backgroundColor: AppTheme.primaryColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
                ),
              ),
            );
          }
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: bottomPadding + 16,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.cardBorderRadius),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _HandleBar(),
          const VGapLg(),
          _SectionHeader(section: section, courseTitle: courseTitle),
          const VGapMd(),
          Divider(
            color: AppTheme.borderColor.withValues(alpha: 0.6),
            height: 1,
          ),
          const VGapMd(),
          _SectionOptionTile(
            icon: Icons.edit_outlined,
            title: 'Edit Module',
            subtitle: 'Change name, description, or order',
            onTap: () => Navigator.pop(context, SectionOptionAction.edit),
          ),
          const VGapSm(),
          _SectionOptionTile(
            icon: Icons.delete_outline_rounded,
            title: 'Delete Module',
            subtitle: 'Permanently remove this module',
            isDestructive: true,
            onTap: () => Navigator.pop(context, SectionOptionAction.delete),
          ),
          const VGapSm(),
        ],
      ),
    );
  }
}

class _HandleBar extends StatelessWidget {
  const _HandleBar();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppTheme.borderColor,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final Section section;
  final String courseTitle;

  const _SectionHeader({required this.section, required this.courseTitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
            border: Border.all(color: AppTheme.borderColor),
          ),
          alignment: Alignment.center,
          child: Text(
            '${section.orderIndex + 1}',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
        const HGapMd(),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                section.title,
                style: AppTheme.headingSmall.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const VGapXs(),
              Text(
                section.description.isEmpty ? courseTitle : section.description,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SectionOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isDestructive ? AppTheme.errorColor : AppTheme.primaryColor;
    final titleColor = isDestructive ? AppTheme.errorColor : AppTheme.textPrimary;
    final tileBg = isDestructive
        ? AppTheme.errorColor.withValues(alpha: 0.06)
        : AppTheme.surfaceVariant;
    final borderColor = isDestructive
        ? AppTheme.errorColor.withValues(alpha: 0.2)
        : AppTheme.borderColor.withValues(alpha: 0.6);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: tileBg,
            borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDestructive
                      ? AppTheme.errorColor.withValues(alpha: 0.12)
                      : AppTheme.primaryColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const HGapMd(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                    const VGapXs(),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDestructive
                            ? AppTheme.errorColor.withValues(alpha: 0.8)
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDestructive
                    ? AppTheme.errorColor.withValues(alpha: 0.5)
                    : AppTheme.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
