import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import 'app_spacers.dart';
import '../services/pomodoro_manager.dart';
import '../screens/pomodoro_timer_screen.dart';

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
    if (title == null && !showBackButton && leading == null && !hasDrawer && (actions == null || actions!.isEmpty)) return const SizedBox.shrink();

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: AppTheme.borderColor(context),
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
                        color: AppTheme.borderColor(context),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Theme.of(context).iconTheme.color,
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
                      child: Icon(
                        Icons.menu_rounded,
                        color: Theme.of(context).iconTheme.color,
                        size: 24,
                      ),
                    ),
                  ),
                if ((leading != null || showBackButton || hasDrawer) && title != null) const HGapMd(),
                if (title != null)
                  Expanded(
                    child: Text(
                      title!,
                      style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.bold),
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
    final double statusBarHeight = MediaQuery.paddingOf(context).top;

    final manager = PomodoroManager.instance;

    return ValueListenableBuilder<bool>(
      valueListenable: manager.isSessionActiveNotifier,
      builder: (context, isSessionActive, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: PomodoroTimerScreen.isTimerScreenActive,
          builder: (context, isTimerActive, _) {
            final bool showBanner = isSessionActive && !isTimerActive;
            final double bannerHeight = showBanner ? 38.0 : 0.0;

            final double headerPadding = (title != null || showBackButton || leading != null || hasDrawer)
                ? (statusBarHeight + (headerSpacing ?? 72.0) + bannerHeight)
                : (showBanner ? (statusBarHeight + bannerHeight) : 0.0);

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

            if (useSafeArea && !((title != null || showBackButton || leading != null || hasDrawer))) {
              content = SafeArea(child: content);
            }

            Widget body = Container(
              width: Responsive.width(context),
              height: Responsive.height(context),
              decoration: showBackground
                  ? BoxDecoration(
                      gradient: AppTheme.resolvedBackgroundGradient(context),
                    )
                  : null,
              child: Stack(
                children: [
                  if (backgroundWidgets != null) ...backgroundWidgets!,
                  content,
                  if (title != null || showBackButton || leading != null || hasDrawer || showBanner)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: RepaintBoundary(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (showBanner)
                              const MiniTimerBanner(),
                            if (title != null || showBackButton || leading != null || hasDrawer)
                              showBanner
                                  ? MediaQuery(
                                      data: MediaQuery.of(context).copyWith(
                                        padding: MediaQuery.of(context).padding.copyWith(top: 0),
                                      ),
                                      child: _buildHeader(context),
                                    )
                                  : _buildHeader(context),
                          ],
                        ),
                      ),
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
              floatingActionButton: floatingActionButton,
            );
          },
        );
      },
    );
  }
}

class MiniTimerBanner extends StatefulWidget {
  const MiniTimerBanner({super.key});

  @override
  State<MiniTimerBanner> createState() => _MiniTimerBannerState();
}

class _MiniTimerBannerState extends State<MiniTimerBanner> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _formatTime(int secs) {
    final m = (secs / 60).floor();
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final manager = PomodoroManager.instance;

    return ValueListenableBuilder<int>(
      valueListenable: manager.secondsNotifier,
      builder: (context, seconds, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: manager.isRunningNotifier,
          builder: (context, isRunning, _) {
            final String timeStr = _formatTime(seconds);

            return GestureDetector(
              onTap: () {
                if (manager.activity == null) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PomodoroTimerScreen(
                      activity: manager.activity!,
                      remainingQueue: manager.remainingQueue,
                      isRestrictMode: manager.isRestrictMode,
                      initialMilestoneTask: manager.milestoneTask,
                      focusedSubTaskIds: manager.focusedSubTaskIds,
                    ),
                  ),
                );
              },
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppTheme.surface(context).withValues(alpha: 0.85),
                      border: Border(
                        bottom: BorderSide(
                          color: AppTheme.borderColor(context),
                          width: 1,
                        ),
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      top: true,
                      child: SizedBox(
                        height: 38,
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedBuilder(
                                animation: _pulseAnimation,
                                builder: (context, child) {
                                  return Opacity(
                                    opacity: isRunning ? _pulseAnimation.value : 0.8,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: isRunning ? AppTheme.successColor : AppTheme.warningColor,
                                        shape: BoxShape.circle,
                                        boxShadow: isRunning ? [
                                          BoxShadow(
                                            color: AppTheme.successColor.withValues(alpha: 0.6),
                                            blurRadius: 6,
                                            spreadRadius: 2,
                                          ),
                                        ] : null,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const HGapSm(),
                              Text(
                                'Focusing: ',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textSecondaryColor(context),
                                ),
                              ),
                              Text(
                                manager.activity?.name ?? '',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimaryColor(context),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const HGapSm(),
                              Text(
                                '($timeStr)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
