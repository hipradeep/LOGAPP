import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BudgetProgressBar extends StatelessWidget {
  final double percent;
  final double? alertThreshold;
  final Color statusColor;
  final double minHeight;

  const BudgetProgressBar({
    super.key,
    required this.percent,
    this.alertThreshold,
    required this.statusColor,
    this.minHeight = 6,
  });

  @override
  Widget build(BuildContext context) {
    final double safeThreshold = alertThreshold ?? 0.7;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final thresholdX = totalWidth * safeThreshold;

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.centerLeft,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(minHeight / 2),
              child: LinearProgressIndicator(
                value: percent.clamp(0.0, 1.0),
                backgroundColor: AppTheme.surfaceVariant(context),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                minHeight: minHeight,
              ),
            ),
            Positioned(
              left: (thresholdX - 12).clamp(0.0, totalWidth - 24),
              top: (minHeight / 2) - 12,
              child: Tooltip(
                message: '${(safeThreshold * 100).round()}% Alert Threshold',
                triggerMode: TooltipTriggerMode.tap,
                preferBelow: false,
                verticalOffset: 12,
                decoration: BoxDecoration(
                  color: AppTheme.warningColor,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                child: Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.surface(context),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.warningColor.withValues(alpha: 0.4),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
