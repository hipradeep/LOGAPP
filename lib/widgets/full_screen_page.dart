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

/// A reusable widget that provides a full-width, full-height container
/// with the app's standard deep gradient background.
/// By default, it wraps the child in a SafeArea and SingleChildScrollView
/// to handle standard screen behaviors (like avoiding device notches and the keyboard).
/// Features a fixed glassmorphism header.
class FullScreenPage extends StatelessWidget {
  final List<Widget> children;
  final List<Widget>? slivers;
  final bool useSafeArea;
  final bool isScrollable;
  final EdgeInsetsGeometry padding;
  final PageAlignment alignment;
  final String? title;
  final bool showBackButton;
  final VoidCallback? onBackPress;
  final List<Widget>? backgroundWidgets;
  final bool showBackground;
  final bool showScaffold;
  final List<Widget>? actions;

  const FullScreenPage({
    super.key,
    this.children = const [],
    this.slivers,
    this.useSafeArea = true,
    this.isScrollable = true,
    this.padding = AppTheme.defaultScreenPadding,
    this.alignment = PageAlignment.topLeft,
    this.title,
    this.showBackButton = false,
    this.onBackPress,
    this.backgroundWidgets,
    this.showBackground = true,
    this.showScaffold = true,
    this.actions,
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
    if (title == null && !showBackButton && (actions == null || actions!.isEmpty)) return const SizedBox.shrink();

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            AppTheme.defaultScreenPadding.left,
            12,
            AppTheme.defaultScreenPadding.right,
            12,
          ),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.05),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                if (showBackButton)
                  GestureDetector(
                    onTap: onBackPress ?? () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                if (showBackButton && title != null) const HGapMd(),
                if (title != null)
                  Expanded(
                    child: Text(
                      title!,
                      style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (actions != null) ...actions!,
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
    
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double headerPadding = (title != null || showBackButton) ? (statusBarHeight + 72.0) : 0.0;

    Widget content;
    if (isScrollable) {
      final resolvedPadding = padding.resolve(TextDirection.ltr);
      final double topGap = resolvedPadding.top + headerPadding;
      
      content = CustomScrollView(
        physics: const BouncingScrollPhysics(),
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

    if (useSafeArea && !((title != null || showBackButton))) {
      content = SafeArea(child: content);
    }

    Widget body = Container(
      width: Responsive.width(context),
      height: Responsive.height(context),
      decoration: showBackground
          ? const BoxDecoration(
              gradient: AppTheme.backgroundGradient,
            )
          : null,
      child: Stack(
        children: [
          if (backgroundWidgets != null) ...backgroundWidgets!,
          content,
          if (title != null || showBackButton)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildHeader(context),
            ),
        ],
      ),
    );

    final mainBody = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: body,
    );

    if (!showScaffold) return mainBody;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: mainBody,
    );
  }
}
