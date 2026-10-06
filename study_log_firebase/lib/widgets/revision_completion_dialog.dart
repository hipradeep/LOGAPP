import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/revision.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

/// Compact modal dialog shown upon completing a revision topic.
/// Displays celebration confetti badge, topic metadata, and a clean
/// horizontal R1 -> R5 step progress bar with connect bars between nodes.
class RevisionCompletionDialog extends StatelessWidget {
  final String topicTitle;
  final String courseTitle;
  final String moduleTitle;
  final int currentLevel;
  final bool isFinished;
  final DateTime? completedAt;
  final VoidCallback? onMoveToNextRevision;
  final String? actionButtonLabel;

  static final DateFormat _dateFormat = DateFormat('d MMM yyyy, hh:mm a');

  const RevisionCompletionDialog({
    super.key,
    required this.topicTitle,
    required this.courseTitle,
    required this.moduleTitle,
    required this.currentLevel,
    this.isFinished = false,
    this.completedAt,
    this.onMoveToNextRevision,
    this.actionButtonLabel,
  });

  static Future<void> show(
    BuildContext context, {
    required String topicTitle,
    required String courseTitle,
    required String moduleTitle,
    required int currentLevel,
    bool isFinished = false,
    DateTime? completedAt,
    VoidCallback? onMoveToNextRevision,
    String? actionButtonLabel,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => RevisionCompletionDialog(
        topicTitle: topicTitle,
        courseTitle: courseTitle,
        moduleTitle: moduleTitle,
        currentLevel: currentLevel,
        isFinished: isFinished,
        completedAt: completedAt,
        onMoveToNextRevision: onMoveToNextRevision,
        actionButtonLabel: actionButtonLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timestamp = completedAt ?? DateTime.now();
    final formattedDate = _dateFormat.format(timestamp);
    final hasNext = !isFinished && currentLevel < RevisionSchedule.maxLevel;

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
        padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Top close button
            Align(
              alignment: Alignment.topRight,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
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

            // Confetti celebration badge
            const _ConfettiBadge(),
            const VGapSm(),

            // Title
            Text(
              'Revision Completed!',
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
            if (courseTitle.isNotEmpty || moduleTitle.isNotEmpty) ...[
              const VGapXs(),
              Text(
                _buildBreadcrumbs(),
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

            const VGapSm(),

            // Completed on timestamp
            Text(
              'R$currentLevel completed on',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textMutedColor(context),
              ),
            ),
            Text(
              formattedDate,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondaryColor(context),
              ),
            ),

            const VGapMd(),

            // Horizontal Revision Progress with connect bars (R1 -> R5)
            _HorizontalRevisionProgress(
              currentLevel: currentLevel,
              isFinished: isFinished,
            ),

            const VGapMd(),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onMoveToNextRevision?.call();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: Text(
                  actionButtonLabel ?? (hasNext ? 'Move to Next Revision' : 'Done'),
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
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

/// Horizontal revision schedule progress bar showing R1 -> R5 with connecting bars.
class _HorizontalRevisionProgress extends StatelessWidget {
  final int currentLevel;
  final bool isFinished;

  const _HorizontalRevisionProgress({
    required this.currentLevel,
    required this.isFinished,
  });

  static const _steps = [
    (1, Color(0xFF6366F1)),
    (2, Color(0xFF3B82F6)),
    (3, Color(0xFF10B981)),
    (4, Color(0xFFF59E0B)),
    (5, Color(0xFFEF4444)),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.background(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Revision schedule',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
              Text(
                isFinished ? '5/5 completed' : '$currentLevel/5 cleared',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isFinished ? AppTheme.successColor : AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const VGapSm(),
          // Row 1: Node circles with horizontal connect bars
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (int i = 0; i < _steps.length; i++) ...[
                _StepCircle(
                  level: _steps[i].$1,
                  color: _steps[i].$2,
                  isCleared: isFinished || _steps[i].$1 <= currentLevel,
                  isNext: !isFinished && _steps[i].$1 == currentLevel + 1,
                ),
                if (i < _steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: (isFinished || _steps[i].$1 < currentLevel)
                            ? AppTheme.successColor
                            : AppTheme.borderColor(context),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                  ),
              ],
            ],
          ),
          const VGapXs(),
          // Row 2: R1..R5 labels aligned directly beneath each circle
          Row(
            children: [
              for (int i = 0; i < _steps.length; i++) ...[
                SizedBox(
                  width: 22,
                  child: Text(
                    'R${_steps[i].$1}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: (isFinished || _steps[i].$1 <= currentLevel + 1)
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: (isFinished || _steps[i].$1 <= currentLevel)
                          ? AppTheme.successColor
                          : (_steps[i].$1 == currentLevel + 1)
                              ? AppTheme.textPrimaryColor(context)
                              : AppTheme.textMutedColor(context),
                    ),
                  ),
                ),
                if (i < _steps.length - 1)
                  const Spacer(),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StepCircle extends StatelessWidget {
  final int level;
  final Color color;
  final bool isCleared;
  final bool isNext;

  const _StepCircle({
    required this.level,
    required this.color,
    required this.isCleared,
    required this.isNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: isCleared
            ? AppTheme.successColor
            : isNext
                ? color
                : color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(
          color: isCleared
              ? AppTheme.successColor
              : isNext
                  ? color
                  : color.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: isNext
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 5,
                ),
              ]
                : null,
      ),
      alignment: Alignment.center,
      child: isCleared
          ? const Icon(
              Icons.check_rounded,
              size: 13,
              color: Colors.white,
            )
          : Text(
              '$level',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isNext ? Colors.white : color,
              ),
            ),
    );
  }
}

class _ConfettiBadge extends StatelessWidget {
  const _ConfettiBadge();

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
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: AppTheme.successColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 24,
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
