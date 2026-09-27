import 'package:flutter/material.dart';
import '../../models/calendar_event.dart';
import '../../models/revision.dart';
import '../../theme/app_theme.dart';
import '../app_spacers.dart';

/// Screen 8: Mark Completed (Success Celebration Sheet / Dialog)
/// Displays celebration checkmark, completed info, and next revision unlock.
class RevisionCompletionDialog extends StatelessWidget {
  final CalendarEvent event;
  final VoidCallback onViewInCalendar;

  const RevisionCompletionDialog({
    super.key,
    required this.event,
    required this.onViewInCalendar,
  });

  static Future<void> show(
    BuildContext context, {
    required CalendarEvent event,
    required VoidCallback onViewInCalendar,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: RevisionCompletionDialog(
          event: event,
          onViewInCalendar: () {
            Navigator.of(ctx).pop();
            onViewInCalendar();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nextLevel = (event.level + 1).clamp(1, 5);
    final nextInterval = RevisionSchedule.intervalFor(nextLevel);
    final nextDate = DateTime.now().add(nextInterval);
    final nextIntervalText = RevisionSchedule.intervalLabel(nextLevel);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Close button at top right
          Align(
            alignment: Alignment.topRight,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Icon(Icons.close_rounded, color: AppTheme.textSecondaryColor(context), size: 22),
            ),
          ),
          // Celebration Icon
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 44,
            ),
          ),
          const VGapMd(),
          // Heading
          Text(
            'Revision Completed!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor(context),
              letterSpacing: -0.3,
            ),
          ),
          const VGapXs(),
          // Topic title
          Text(
            event.topicTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
          const VGapXs(),
          // Breadcrumb
          Text(
            event.breadcrumb,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
          const VGapSm(),
          Text(
            'R${event.level} completed on ${_formatToday()}',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
          const VGapLg(),
          // Next Revision Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Next Revision',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ),
                const VGapSm(),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'R$nextLevel',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                    ),
                    const HGapSm(),
                    Expanded(
                      child: Text(
                        '${_formatDate(nextDate)} ($nextIntervalText)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryColor(context),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const VGapLg(),
          // Action button: View in Calendar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onViewInCalendar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text(
                'View in Calendar',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatToday() {
    final now = DateTime.now();
    return '${now.day} Oct ${now.year}, 09:00 AM';
  }

  static String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
