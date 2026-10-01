import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

/// Confirmation dialog matching the reference designs:
/// - Top icon (Purple calendar for Archive, Red trash for Delete)
/// - Bold title (e.g. "Archive Course?", "Delete Course?", "Delete Module?", "Delete Topic?")
/// - Descriptive message (e.g. "This action cannot be undone.")
/// - Cancel (light lavender pill) and Confirm (solid purple / solid red) side by side
class StudyConfirmationDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String confirmText;
  final Color confirmColor;

  const StudyConfirmationDialog({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.confirmText,
    required this.confirmColor,
  });

  /// Displays the "Archive Course?" dialog with explicit warning matching requirements
  static Future<bool> showArchiveCourse(BuildContext context, {String courseTitle = ''}) async {
    final title = courseTitle.isNotEmpty ? 'Archive "$courseTitle"?' : 'Archive Course?';
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StudyConfirmationDialog(
        icon: Icons.archive_outlined,
        iconColor: AppTheme.primaryColor,
        title: title,
        message: 'Warning: This course will be moved to archive and hidden from your active courses and revision schedule.\n\nAll study logs and streak records are safely preserved and will not be removed.\n\nYou can view and restore it anytime.',
        confirmText: 'Archive',
        confirmColor: AppTheme.primaryColor,
      ),
    );
    return result ?? false;
  }

  /// Displays the "Restore Course?" dialog
  static Future<bool> showRestoreCourse(BuildContext context, {String courseTitle = ''}) async {
    final title = courseTitle.isNotEmpty ? 'Restore "$courseTitle"?' : 'Restore Course?';
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StudyConfirmationDialog(
        icon: Icons.unarchive_outlined,
        iconColor: AppTheme.primaryColor,
        title: title,
        message: 'This course will be restored back to your active courses and revision schedule.',
        confirmText: 'Restore',
        confirmColor: AppTheme.primaryColor,
      ),
    );
    return result ?? false;
  }

  /// Displays the "Delete Course?" dialog matching Image 2
  static Future<bool> showDeleteCourse(BuildContext context, {String courseTitle = ''}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const StudyConfirmationDialog(
        icon: Icons.delete_outline_rounded,
        iconColor: AppTheme.errorColor,
        title: 'Delete Course?',
        message: 'This action cannot be undone.',
        confirmText: 'Delete',
        confirmColor: AppTheme.errorColor,
      ),
    );
    return result ?? false;
  }

  /// Displays the "Delete Module?" dialog (only delete, no archive)
  static Future<bool> showDeleteModule(BuildContext context, {String moduleTitle = ''}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const StudyConfirmationDialog(
        icon: Icons.delete_outline_rounded,
        iconColor: AppTheme.errorColor,
        title: 'Delete Module?',
        message: 'This action cannot be undone.',
        confirmText: 'Delete',
        confirmColor: AppTheme.errorColor,
      ),
    );
    return result ?? false;
  }

  /// Displays the "Delete Topic?" dialog (only delete, no archive)
  static Future<bool> showDeleteTopic(BuildContext context, {String topicTitle = ''}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const StudyConfirmationDialog(
        icon: Icons.delete_outline_rounded,
        iconColor: AppTheme.errorColor,
        title: 'Delete Topic?',
        message: 'This action cannot be undone.',
        confirmText: 'Delete',
        confirmColor: AppTheme.errorColor,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 40,
              color: iconColor,
            ),
            const VGapMd(),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor(context),
              ),
              textAlign: TextAlign.center,
            ),
            const VGapSm(),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondaryColor(context),
                height: 1.4,
              ),
            ),
            const VGapLg(),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.pastelIndigo(context),
                        foregroundColor: AppTheme.primaryColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const HGapMd(),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: confirmColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        confirmText,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
