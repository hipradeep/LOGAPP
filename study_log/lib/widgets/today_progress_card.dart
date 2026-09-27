import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

/// "Today's Progress" card widget matching the reference design:
/// - Header with "Today's Progress" and dynamic formatted date
/// - Surface card with 4 stats: Completed (3), Revisions Due (5), Daily Goal (62%), Day Streak (4)
class TodayProgressCard extends StatelessWidget {
  const TodayProgressCard({super.key});

  static final DateFormat _dateFormat = DateFormat('EEE, d MMM yyyy');

  @override
  Widget build(BuildContext context) {
    final dateString = _dateFormat.format(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              "Today's Progress",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              dateString,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        const VGapMd(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
            border: Border.all(color: AppTheme.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(
                icon: Icons.check_circle_rounded,
                iconColor: Color(0xFF10B981),
                value: '3',
                label: 'Completed',
              ),
              _StatItem(
                icon: Icons.sync_rounded,
                iconColor: Color(0xFF6366F1),
                value: '5',
                label: 'Revisions Due',
                isCircleFilled: true,
              ),
              _StatItem(
                icon: Icons.calendar_today_rounded,
                iconColor: Color(0xFF3B82F6),
                value: '62%',
                label: 'Daily Goal',
              ),
              _StatItem(
                icon: Icons.local_fire_department_rounded,
                iconColor: Color(0xFFF97316),
                value: '4',
                label: 'Day Streak',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final bool isCircleFilled;

  const _StatItem({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.isCircleFilled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (isCircleFilled)
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: iconColor,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: Colors.white, size: 12),
              )
            else
              Icon(icon, color: iconColor, size: 18),
            const HGapXs(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const VGapXs(),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
