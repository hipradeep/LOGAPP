import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

/// Confirmation dialog matching the reference designs:
/// - Top icon (Purple calendar for Archive, Red trash for Delete)
/// - Bold title (e.g. "Archive Course?", "Delete Course?", "Delete Section?", "Delete Subsection?")
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

  /// Displays the "Archive Course?" dialog matching Image 2
  static Future<bool> showArchiveCourse(BuildContext context, {String courseTitle = ''}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const StudyConfirmationDialog(
        icon: Icons.calendar_today_outlined,
        iconColor: AppTheme.primaryColor,
        title: 'Archive Course?',
        message: 'This course will be moved to archive.\nYou can restore it later.',
        confirmText: 'Archive',
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
        iconColor: Color(0xFFEF4444),
        title: 'Delete Course?',
        message: 'This action cannot be undone.',
        confirmText: 'Delete',
        confirmColor: Color(0xFFEF4444),
      ),
    );
    return result ?? false;
  }

  /// Displays the "Delete Section?" dialog (only delete, no archive)
  static Future<bool> showDeleteSection(BuildContext context, {String sectionTitle = ''}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const StudyConfirmationDialog(
        icon: Icons.delete_outline_rounded,
        iconColor: Color(0xFFEF4444),
        title: 'Delete Section?',
        message: 'This action cannot be undone.',
        confirmText: 'Delete',
        confirmColor: Color(0xFFEF4444),
      ),
    );
    return result ?? false;
  }

  /// Displays the "Delete Subsection?" dialog (only delete, no archive)
  static Future<bool> showDeleteSubsection(BuildContext context, {String subsectionTitle = ''}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const StudyConfirmationDialog(
        icon: Icons.delete_outline_rounded,
        iconColor: Color(0xFFEF4444),
        title: 'Delete Subsection?',
        message: 'This action cannot be undone.',
        confirmText: 'Delete',
        confirmColor: Color(0xFFEF4444),
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceColor,
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
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const VGapSm(),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
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
                        backgroundColor: const Color(0xFFEEF2FF),
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
