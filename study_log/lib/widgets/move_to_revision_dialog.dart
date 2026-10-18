import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/revision_level_palette.dart';
import 'app_spacers.dart';

/// Modal dialog presented when a topic completes its initial study phase,
/// inviting the learner to enroll it into the spaced repetition schedule (R1).
class MoveToRevisionDialog extends StatelessWidget {
  final String topicTitle;
  final String courseTitle;
  final String moduleTitle;

  const MoveToRevisionDialog({
    super.key,
    required this.topicTitle,
    this.courseTitle = '',
    this.moduleTitle = '',
  });

  /// Displays the dialog and returns `true` if the user confirms enrollment.
  static Future<bool> show(
    BuildContext context, {
    required String topicTitle,
    String courseTitle = '',
    String moduleTitle = '',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => MoveToRevisionDialog(
        topicTitle: topicTitle,
        courseTitle: courseTitle,
        moduleTitle: moduleTitle,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final r1Colors = RevisionLevelPalette.of(context, 1);
    final breadcrumbs = _buildBreadcrumbs();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(color: AppTheme.borderColor(context)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.shadowColor(context),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(18.0, 12.0, 18.0, 18.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Top close button
            Align(
              alignment: Alignment.topRight,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(false),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppTheme.textMutedColor(context),
                  ),
                ),
              ),
            ),

            // Top celebration badge
            const _StudyCelebrationBadge(),
            const VGapSm(),

            // Title
            Text(
              'Study Phase Complete!',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
            const VGapXs(),

            // Topic title
            Text(
              topicTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor(context),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Breadcrumbs: Course › Module
            if (breadcrumbs.isNotEmpty) ...[
              const VGapXs(),
              Text(
                breadcrumbs,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondaryColor(context),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const VGapMd(),

            // Spaced Repetition R1 preview card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.background(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: r1Colors.background,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: r1Colors.border, width: 0.8),
                        ),
                        child: Text(
                          'R1',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: r1Colors.foreground,
                          ),
                        ),
                      ),
                      const HGapSm(),
                      Expanded(
                        child: Text(
                          'Unlocks tomorrow',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryColor(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const VGapXs(),
                  Text(
                    'Add to spaced repetition to lock this topic into your long-term memory.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondaryColor(context),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),

            const VGapMd(),

            // Primary action button: Add to Revision
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  'Add to Revision (R1)',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),

            const VGapXs(),

            // Secondary action button: Not Now
            SizedBox(
              width: double.infinity,
              height: 36,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textSecondaryColor(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Not Now',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildBreadcrumbs() {
    final parts = <String>[];
    if (courseTitle.trim().isNotEmpty) parts.add(courseTitle.trim());
    if (moduleTitle.trim().isNotEmpty) parts.add(moduleTitle.trim());
    return parts.join(' › ');
  }
}

class _StudyCelebrationBadge extends StatelessWidget {
  const _StudyCelebrationBadge();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned(top: 2, left: 12, child: _Dot(color: Color(0xFF42A5F5), size: 5)),
          const Positioned(top: 0, right: 16, child: _Dot(color: Color(0xFFFF7043), size: 5)),
          const Positioned(top: 10, right: 4, child: _Dot(color: Color(0xFF7C4DFF), size: 4)),
          const Positioned(bottom: 4, left: 8, child: _Dot(color: Color(0xFFFF5252), size: 5)),
          const Positioned(bottom: 2, right: 10, child: _Dot(color: Color(0xFF26A69A), size: 4)),
          const Positioned(top: 0, left: 34, child: _Dot(color: Color(0xFFFFCA28), size: 4)),
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppTheme.successColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  final double size;

  const _Dot({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
