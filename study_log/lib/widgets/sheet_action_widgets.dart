import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

/// Top centered drag handle bar for modal bottom sheets.
class SheetHandleBar extends StatelessWidget {
  const SheetHandleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppTheme.borderColor(context),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// 42x42 Squircle badge container for bottom sheet headers.
class SheetHeaderBadge extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;

  const SheetHeaderBadge({
    super.key,
    required this.child,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.pastelBlue(context),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// Standardized header with squircle badge, bold title, and subtitle.
class SheetHeader extends StatelessWidget {
  final Widget? badge;
  final String title;
  final String? subtitle;
  final int? subtitleMaxLines;

  const SheetHeader({
    super.key,
    this.badge,
    required this.title,
    this.subtitle,
    this.subtitleMaxLines,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (badge != null) ...[
          badge!,
          const HGapSm(),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                softWrap: true,
                style: TextStyle(
                  fontSize: 15.5,
                  height: 1.2,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor(context),
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                  maxLines: subtitleMaxLines,
                  overflow: subtitleMaxLines != null ? TextOverflow.ellipsis : null,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Interactive action row with circular icon container, title, and trailing chevron.
class SheetActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const SheetActionRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rowContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
      child: Row(
        crossAxisAlignment: subtitle != null ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant(context),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: AppTheme.textPrimaryColor(context),
              size: 16,
            ),
          ),
          const HGapSm(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor(context),
                    letterSpacing: -0.2,
                  ),
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textSecondaryColor(context),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondaryColor(context),
              size: 18,
            ),
        ],
      ),
    );

    if (onTap == null) {
      return rowContent;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: rowContent,
    );
  }
}

/// Destructive action button styled as a soft red pill with red circle icon and text (no chevron).
class SheetDestructiveButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const SheetDestructiveButton({
    super.key,
    this.icon = Icons.delete_outline_rounded,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.errorColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: AppTheme.errorColor,
                size: 16,
              ),
            ),
            const HGapSm(),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.errorColor,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-width rounded Cancel button for dismissing the bottom sheet.
class SheetCancelButton extends StatelessWidget {
  final VoidCallback? onTap;

  const SheetCancelButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () => Navigator.pop(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        height: 42,
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant(context),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          'Cancel',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
      ),
    );
  }
}

/// Full-width primary action button for modal bottom sheets.
class SheetSubmitButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  const SheetSubmitButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const HGapSm(),
                  ],
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Outer container wrapper for consistent bottom sheet presentation.
class SheetContainer extends StatelessWidget {
  final List<Widget> children;

  const SheetContainer({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(18, 10, 18, bottomPadding + 12),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
