import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

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
        color: backgroundColor ?? AppTheme.primaryColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.iconBoxRadius),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

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
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (badge != null) ...[badge!, const HGapSm()],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: textTheme.titleMedium),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const VGapXs(),
                Text(
                  subtitle!,
                  maxLines: subtitleMaxLines,
                  overflow: subtitleMaxLines != null
                      ? TextOverflow.ellipsis
                      : null,
                  style: textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

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
    final textTheme = Theme.of(context).textTheme;

    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingXs,
        vertical: AppTheme.spacingSm,
      ),
      child: Row(
        crossAxisAlignment: subtitle != null
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
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
                Text(title, style: textTheme.labelLarge),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const VGapXs(),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall,
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

    if (onTap == null) return content;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
      child: content,
    );
  }
}

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
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
      child: Container(
        height: AppTheme.buttonHeight,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSm),
        decoration: BoxDecoration(
          color: AppTheme.errorColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
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
              child: Icon(icon, color: AppTheme.errorColor, size: 16),
            ),
            const HGapSm(),
            Text(
              title,
              style: textTheme.labelLarge?.copyWith(color: AppTheme.errorColor),
            ),
          ],
        ),
      ),
    );
  }
}

class SheetCancelButton extends StatelessWidget {
  final VoidCallback? onTap;

  const SheetCancelButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppTheme.buttonHeight,
      child: TextButton(
        onPressed: onTap ?? () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    );
  }
}

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
      height: AppTheme.buttonHeight,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[Icon(icon, size: 18), const HGapSm()],
                  Text(text),
                ],
              ),
      ),
    );
  }
}

class SheetContainer extends StatelessWidget {
  final List<Widget> children;

  const SheetContainer({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppTheme.spacingMd,
        AppTheme.spacingSm + 2,
        AppTheme.spacingMd,
        bottomPadding + AppTheme.spacingSm + AppTheme.spacingXs,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
