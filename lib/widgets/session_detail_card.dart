import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_icons.dart';
import 'app_spacers.dart';

class SessionDetailCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final bool isChecked;
  final VoidCallback? onTap;

  const SessionDetailCard({
    super.key,
    required this.session,
    this.isChecked = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = session['icon'] as IconData? ?? Icons.fitness_center;
    final color = session['color'] as Color? ?? AppTheme.primaryColor.withValues(alpha: 0.1);
    final iconColor = session['iconColor'] as Color? ?? AppTheme.primaryLight;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: AppTheme.defaultCardPadding,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
              ),
              child: IconMd(icon, color: iconColor),
            ),
            const HGapMd(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session['title'] ?? session['name'] ?? 'Session',
                    style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    session['subtitle'] ?? session['trainer'] ?? 'Workout Session',
                    style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const HGapSm(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const IconSm(Icons.access_time, color: AppTheme.textMuted),
                const VGapXs(),
                Text(
                  session['time'] ?? session['startTime'] ?? '--:--',
                  style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
