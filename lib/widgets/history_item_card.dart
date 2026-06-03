import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';
import 'app_icons.dart';

class HistoryItemCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String status;
  final Color statusColor;
  final IconData icon;

  const HistoryItemCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.statusColor,
    this.icon = Icons.fitness_center_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconSm(icon, color: AppTheme.primaryLight),
          ),
          const HGapMd(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title, 
                  style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle, 
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const HGapSm(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor.withValues(alpha: 0.2)),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                color: statusColor, 
                fontSize: 9, 
                fontWeight: FontWeight.w800, 
                letterSpacing: 0.5
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HistoryMonthHeader extends StatelessWidget {
  final String month;

  const HistoryMonthHeader({super.key, required this.month});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        month.toUpperCase(),
        style: AppTheme.bodySmall.copyWith(
          color: AppTheme.textSecondary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
