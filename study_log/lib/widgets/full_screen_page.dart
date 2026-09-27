import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import 'app_spacers.dart';

enum PageAlignment {
  topLeft,
  topCenter,
  topRight,
  center,
  centerLeft,
  centerRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
}

class FullScreenPage extends StatelessWidget {
  final List<Widget> children;
  final List<Widget>? slivers;
  final bool useSafeArea;
  final bool isScrollable;
  final EdgeInsetsGeometry padding;
  final PageAlignment alignment;
  final String? title;
  final Widget? titleWidget;
  final bool showBackButton;
  final VoidCallback? onBackPress;
  final List<Widget>? backgroundWidgets;
  final bool showBackground;
  final bool showScaffold;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? leading;
  final double? headerSpacing;

  const FullScreenPage({
    super.key,
    this.children = const [],
    this.slivers,
    this.useSafeArea = true,
    this.isScrollable = true,
    this.padding = AppTheme.defaultScreenPadding,
    this.alignment = PageAlignment.topLeft,
    this.title,
    this.titleWidget,
    this.showBackButton = false,
    this.onBackPress,
    this.backgroundWidgets,
    this.showBackground = true,
    this.showScaffold = true,
    this.actions,
    this.floatingActionButton,
    this.leading,
    this.headerSpacing,
  });

  MainAxisAlignment _getMainAxisAlignment() {
    switch (alignment) {
      case PageAlignment.topLeft:
      case PageAlignment.topCenter:
      case PageAlignment.topRight:
        return MainAxisAlignment.start;
      case PageAlignment.center:
      case PageAlignment.centerLeft:
      case PageAlignment.centerRight:
        return MainAxisAlignment.center;
      case PageAlignment.bottomLeft:
      case PageAlignment.bottomCenter:
      case PageAlignment.bottomRight:
        return MainAxisAlignment.end;
    }
  }

  CrossAxisAlignment _getCrossAxisAlignment() {
    switch (alignment) {
      case PageAlignment.topLeft:
      case PageAlignment.centerLeft:
      case PageAlignment.bottomLeft:
        return CrossAxisAlignment.start;
      case PageAlignment.topCenter:
      case PageAlignment.center:
      case PageAlignment.bottomCenter:
        return CrossAxisAlignment.center;
      case PageAlignment.topRight:
      case PageAlignment.centerRight:
      case PageAlignment.bottomRight:
        return CrossAxisAlignment.end;
    }
  }

  Alignment _getAlignment() {
    switch (alignment) {
      case PageAlignment.topLeft:
        return Alignment.topLeft;
      case PageAlignment.topCenter:
        return Alignment.topCenter;
      case PageAlignment.topRight:
        return Alignment.topRight;
      case PageAlignment.center:
        return Alignment.center;
      case PageAlignment.centerLeft:
        return Alignment.centerLeft;
      case PageAlignment.centerRight:
        return Alignment.centerRight;
      case PageAlignment.bottomLeft:
        return Alignment.bottomLeft;
      case PageAlignment.bottomCenter:
        return Alignment.bottomCenter;
      case PageAlignment.bottomRight:
        return Alignment.bottomRight;
    }
  }

  Widget _buildHeader(BuildContext context) {
    final hasDrawer = Scaffold.maybeOf(context)?.hasDrawer ?? false;
    final hasTitle = title != null || titleWidget != null;
    if (!hasTitle && !showBackButton && leading == null && !hasDrawer && (actions == null || actions!.isEmpty)) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor.withValues(alpha: 0.85),
            border: Border(
              bottom: BorderSide(
                color: AppTheme.borderColor.withValues(alpha: 0.6),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                if (leading != null)
                  leading!
                else if (showBackButton)
                  GestureDetector(
                    onTap: onBackPress ?? () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: AppTheme.primaryColor,
                        size: 16,
                      ),
                    ),
                  )
                else if (hasDrawer)
                  GestureDetector(
                    onTap: () => Scaffold.of(context).openDrawer(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.transparent,
                      child: const Icon(
                        Icons.menu_rounded,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                    ),
                  ),
                if ((leading != null || showBackButton || hasDrawer) && hasTitle) const HGapMd(),
                if (titleWidget != null)
                  Expanded(child: titleWidget!)
                else if (title != null)
                  Expanded(
                    child: Text(
                      title!,
                      style: AppTheme.headingSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (actions != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: actions!,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mainAxis = _getMainAxisAlignment();
    final crossAxis = _getCrossAxisAlignment();
    
    final hasDrawer = Scaffold.maybeOf(context)?.hasDrawer ?? false;
    final hasHeader = title != null || titleWidget != null || showBackButton || leading != null || hasDrawer || (actions != null && actions!.isNotEmpty);
    final double statusBarHeight = MediaQuery.paddingOf(context).top;
    final double headerPadding = hasHeader ? (statusBarHeight + (headerSpacing ?? 72.0)) : 0.0;

    Widget content;
    if (isScrollable) {
      final resolvedPadding = padding.resolve(TextDirection.ltr);
      final double topGap = resolvedPadding.top + headerPadding;
      
      content = CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          if (topGap > 0) SliverToBoxAdapter(child: SizedBox(height: topGap)),
          ...?slivers,
          if (slivers == null)
            SliverPadding(
              padding: EdgeInsets.only(
                left: resolvedPadding.left,
                right: resolvedPadding.right,
                bottom: resolvedPadding.bottom,
                top: 0,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: mainAxis,
                  crossAxisAlignment: crossAxis,
                  children: children,
                ),
              ),
            ),
        ],
      );
    } else {
      content = Padding(
        padding: EdgeInsets.only(
          top: padding.resolve(TextDirection.ltr).top + headerPadding,
          left: padding.resolve(TextDirection.ltr).left,
          right: padding.resolve(TextDirection.ltr).right,
          bottom: padding.resolve(TextDirection.ltr).bottom,
        ),
        child: Align(
          alignment: _getAlignment(),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: mainAxis,
            crossAxisAlignment: crossAxis,
            children: children,
          ),
        ),
      );
    }

    if (useSafeArea && !hasHeader) {
      content = SafeArea(child: content);
    }

    final Widget body = Container(
      width: Responsive.width(context),
      height: Responsive.height(context),
      color: showBackground ? AppTheme.backgroundColor : Colors.transparent,
      child: Stack(
        children: [
          if (backgroundWidgets != null) ...backgroundWidgets!,
          content,
          if (hasHeader)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: RepaintBoundary(
                child: _buildHeader(context),
              ),
            ),
        ],
      ),
    );

    final mainBody = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: body,
    );

    if (!showScaffold) return mainBody;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: mainBody,
      floatingActionButton: floatingActionButton,
    );
  }
}
