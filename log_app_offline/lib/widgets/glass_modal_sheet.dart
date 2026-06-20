import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

class GlassModalSheet extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool isScrollable;

  const GlassModalSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.isScrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    // Register dependency for dynamic theme switching
    Theme.of(context);

    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const VGapMd(),
        // Drag handle
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.borderColor(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const VGapLg(),
        // Header (Title, Subtitle, Close Button)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.headingMedium.copyWith(fontSize: 22),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const VGapXs(),
                      Text(
                        subtitle!,
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondaryColor(context),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const HGapMd(),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.borderColor(context),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close_rounded,
                    color: Theme.of(context).iconTheme.color,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
        const VGapLg(),
        Divider(color: AppTheme.borderColor(context), height: 1, indent: 24, endIndent: 24),
        const VGapMd(),
        if (isScrollable)
          Flexible(
            child: ListView(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: children,
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...children,
                const VGapMd(),
              ],
            ),
          ),
      ],
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.background(context).withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: AppTheme.borderColor(context), width: 1),
          boxShadow: [
            BoxShadow(
              color: AppTheme.shadowColor(context),
              blurRadius: 40,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: SafeArea(
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
