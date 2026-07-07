import 'package:flutter/material.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_services/core_services.dart';
class ActivityChip extends StatefulWidget {
  final Activity activity;
  final int todayCount;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSkipped;
  final bool isSelected;
  final int? targetCountOverride;
  final bool? isCompletedOverride;

  const ActivityChip({
    super.key,
    required this.activity,
    required this.todayCount,
    required this.onTap,
    this.onLongPress,
    this.isSkipped = false,
    this.isSelected = false,
    this.targetCountOverride,
    this.isCompletedOverride,
  });

  @override
  State<ActivityChip> createState() => _ActivityChipState();
}

class _ActivityChipState extends State<ActivityChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    if (widget.isSelected) {
      _animController.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(ActivityChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _animController.forward(from: 0);
      } else {
        _animController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;
    final todayCount = widget.todayCount;
    final isSkipped = widget.isSkipped;
    final targetCount = widget.targetCountOverride ?? activity.targetCount;
    final isMultiple = targetCount > 1;
    final isCompleted = widget.isCompletedOverride ?? (todayCount >= targetCount && !isSkipped);
    final double progress = targetCount > 0
        ? (isSkipped ? 1.0 : (todayCount / targetCount).clamp(0.0, 1.0))
        : 0.0;
    final isSelected = widget.isSelected;

    final Color typeColor;
    if (isSkipped) {
      typeColor = AppTheme.warningColor;
    } else {
      switch (activity.trackingType) {
        case 'multiple':
          typeColor = AppTheme.secondaryColor;
          break;
        case 'milestone':
          typeColor = AppTheme.warningColor;
          break;
        case 'single':
        default:
          typeColor = AppTheme.primaryColor;
          break;
      }
    }

    final Color accentColor = isSkipped
        ? AppTheme.warningColor
        : (isCompleted ? AppTheme.successColor : typeColor);

    Widget leadingIcon;
    if (isSelected && !isSkipped) {
      leadingIcon = ScaleTransition(
        scale: _scaleAnim,
        child: SizedBox(
          width: 22,
          height: 22,
          child: Checkbox(
            value: true,
            onChanged: (_) => widget.onLongPress?.call(),
            activeColor: AppTheme.successColor,
            checkColor: Colors.white,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      );
    } else {
      leadingIcon = SizedBox(
        width: 22,
        height: 22,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: progress,
              strokeWidth: 2.5,
              backgroundColor: AppTheme.borderColor(context),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
            if (isSkipped)
              Icon(
                Icons.double_arrow_rounded,
                color: accentColor,
                size: 12,
              )
            else if (isCompleted)
              Icon(
                Icons.check_rounded,
                color: accentColor,
                size: 12,
              )
            else
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected && !isSkipped
              ? AppTheme.successColor.withValues(alpha: 0.15)
              : typeColor.withValues(alpha: isCompleted || isSkipped ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected && !isSkipped
                ? AppTheme.successColor.withValues(alpha: 0.4)
                : accentColor.withValues(alpha: isCompleted || isSkipped ? 0.35 : 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected && !isSkipped
                  ? AppTheme.successColor.withValues(alpha: 0.2)
                  : typeColor.withValues(alpha: isCompleted || isSkipped ? 0.15 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            leadingIcon,
            const SizedBox(width: 8),
            Text(
              activity.name,
              style: AppTheme.bodySmall.copyWith(
                color: isSkipped
                    ? AppTheme.warningColor.withValues(alpha: 0.9)
                    : (isSelected || isCompleted
                        ? AppTheme.successColor.withValues(alpha: 0.9)
                        : Theme.of(context).textTheme.bodyLarge?.color),
                fontWeight: FontWeight.w600,
                fontSize: 11,
                decoration: isSkipped ? TextDecoration.lineThrough : null,
              ),
            ),
            if (isMultiple && !isSkipped) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$todayCount/$targetCount',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
