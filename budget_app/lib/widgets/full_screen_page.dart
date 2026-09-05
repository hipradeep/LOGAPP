import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
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

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.paddingOf(context).top;
    final hasHeader = title != null || showBackButton || actions != null;

    Widget content;
    if (slivers != null) {
      content = CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          if (hasHeader)
            SliverToBoxAdapter(
              child: SizedBox(height: headerSpacing ?? (statusBarHeight + 72.0)),
            ),
          ...slivers!,
        ],
      );
    } else if (isScrollable) {
      content = SingleChildScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: padding,
        child: Column(
          mainAxisAlignment: _getMainAxisAlignment(),
          crossAxisAlignment: _getCrossAxisAlignment(),
          children: [
            if (hasHeader)
              SizedBox(height: headerSpacing ?? (statusBarHeight + 72.0)),
            ...children,
          ],
        ),
      );
    } else {
      content = Padding(
        padding: padding,
        child: Column(
          mainAxisAlignment: _getMainAxisAlignment(),
          crossAxisAlignment: _getCrossAxisAlignment(),
          children: [
            if (hasHeader)
              SizedBox(height: headerSpacing ?? (statusBarHeight + 72.0)),
            ...children,
          ],
        ),
      );
    }

    Widget mainStack = Stack(
      children: [
        if (showBackground)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: AppTheme.resolvedBackgroundGradient(context),
              ),
            ),
          ),
        if (backgroundWidgets != null) ...backgroundWidgets!,
        Positioned.fill(child: content),
        if (hasHeader)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildHeader(context, statusBarHeight),
          ),
      ],
    );

    if (!showScaffold) {
      return mainStack;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      floatingActionButton: floatingActionButton,
      body: mainStack,
    );
  }

  Widget _buildHeader(BuildContext context, double statusBarHeight) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: EdgeInsets.only(
            top: statusBarHeight + 10,
            bottom: 12,
            left: 16,
            right: 16,
          ),
          decoration: BoxDecoration(
            color: AppTheme.surface(context).withValues(alpha: 0.65),
            border: Border(
              bottom: BorderSide(
                color: AppTheme.borderColor(context),
                width: 0.8,
              ),
            ),
          ),
          child: Row(
            children: [
              if (leading != null)
                leading!
              else if (showBackButton)
                IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: AppTheme.textPrimaryColor(context),
                    size: 20,
                  ),
                  onPressed: onBackPress ?? () => Navigator.of(context).maybePop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
              if (title != null) ...[
                if (showBackButton || leading != null) const HGapSm(),
                Expanded(
                  child: Text(
                    title!,
                    style: AppTheme.headingSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else
                const Spacer(),
              if (actions != null) ...actions!,
            ],
          ),
        ),
      ),
    );
  }
}
