import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

/// "Your Courses" horizontal carousel section matching the reference design:
/// - Section header "Your Courses" with trailing chevron navigation
/// - Horizontal list of course cards (DSA, System Design, Gen AI, Android)
/// - "More" card with "..." icon and purple highlighted border that opens course list
/// - Dynamic 3-pill carousel indicator that tracks scroll position
class YourCoursesCarousel extends StatefulWidget {
  final VoidCallback? onMoreTap;
  final ValueChanged<String>? onCourseTap;

  const YourCoursesCarousel({
    super.key,
    this.onMoreTap,
    this.onCourseTap,
  });

  @override
  State<YourCoursesCarousel> createState() => _YourCoursesCarouselState();
}

class _YourCoursesCarouselState extends State<YourCoursesCarousel> {
  late final ScrollController _scrollController;
  final ValueNotifier<int> _activeIndex = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _activeIndex.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;
    final ratio = (_scrollController.offset / maxScroll).clamp(0.0, 1.0);
    final int index;
    if (ratio < 0.33) {
      index = 0;
    } else if (ratio < 0.67) {
      index = 1;
    } else {
      index = 2;
    }
    if (_activeIndex.value != index) {
      _activeIndex.value = index;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _HeaderRow(onMoreTap: widget.onMoreTap),
        const VGapMd(),
        SizedBox(
          height: 146,
          child: _CardsHorizontalList(
            scrollController: _scrollController,
            onCourseTap: widget.onCourseTap,
            onMoreTap: widget.onMoreTap,
          ),
        ),
        const VGapSm(),
        ValueListenableBuilder<int>(
          valueListenable: _activeIndex,
          builder: (context, activeIdx, _) => _CarouselIndicatorRow(activeIndex: activeIdx),
        ),
      ],
    );
  }
}

// === Subcomponents (Rule 2 & 23: Pure, extracted StatelessWidget classes) ===

class _HeaderRow extends StatelessWidget {
  final VoidCallback? onMoreTap;

  const _HeaderRow({this.onMoreTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Your Courses',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        if (onMoreTap != null)
          GestureDetector(
            onTap: onMoreTap,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF9CA3AF),
                size: 24,
              ),
            ),
          ),
      ],
    );
  }
}

class _CardsHorizontalList extends StatelessWidget {
  final ScrollController scrollController;
  final ValueChanged<String>? onCourseTap;
  final VoidCallback? onMoreTap;

  const _CardsHorizontalList({
    required this.scrollController,
    this.onCourseTap,
    this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        _YourCourseCard(
          title: 'DSA',
          subtitle: '6 / 20 sections',
          progress: 0.30,
          progressLabel: '30%',
          icon: Icons.code_rounded,
          bgColor: AppTheme.pastelPurple,
          borderColor: AppTheme.pastelPurpleBorder,
          accentColor: AppTheme.pastelPurpleText,
          onTap: () => onCourseTap?.call('DSA'),
        ),
        const HGapMd(),
        _YourCourseCard(
          title: 'System Design',
          subtitle: '3 / 15 sections',
          progress: 0.20,
          progressLabel: '20%',
          icon: Icons.settings_suggest_rounded,
          bgColor: AppTheme.pastelGreen,
          borderColor: AppTheme.pastelGreenBorder,
          accentColor: AppTheme.pastelGreenText,
          onTap: () => onCourseTap?.call('System Design'),
        ),
        const HGapMd(),
        _YourCourseCard(
          title: 'Gen AI',
          subtitle: '1 / 10 sections',
          progress: 0.10,
          progressLabel: '10%',
          icon: Icons.smart_toy_rounded,
          bgColor: AppTheme.pastelOrange,
          borderColor: AppTheme.pastelOrangeBorder,
          accentColor: AppTheme.pastelOrangeText,
          onTap: () => onCourseTap?.call('Gen AI'),
        ),
        const HGapMd(),
        _YourCourseCard(
          title: 'Android',
          subtitle: '0 / 8 sections',
          progress: 0.0,
          progressLabel: '0%',
          icon: Icons.android_rounded,
          bgColor: const Color(0xFFE0F2FE),
          borderColor: const Color(0xFFBAE6FD),
          accentColor: const Color(0xFF0284C7),
          onTap: () => onCourseTap?.call('Android'),
        ),
        const HGapMd(),
        // "More" card - Tapping opens Course List screen
        _MoreCoursesCard(onTap: onMoreTap),
      ],
    );
  }
}

class _MoreCoursesCard extends StatelessWidget {
  final VoidCallback? onTap;

  const _MoreCoursesCard({this.onTap});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F7FF),
          borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
          border: Border.all(color: const Color(0xFFDDD6FE), width: 1.5),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.more_horiz_rounded,
                    color: AppTheme.primaryColor,
                    size: 32,
                  ),
                  VGapSm(),
                  Text(
                    'More',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _YourCourseCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double progress;
  final String progressLabel;
  final IconData icon;
  final Color bgColor;
  final Color borderColor;
  final Color accentColor;
  final VoidCallback? onTap;

  const _YourCourseCard({
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.progressLabel,
    required this.icon,
    required this.bgColor,
    required this.borderColor,
    required this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: 138,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Icon Container
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
                      border: Border.all(color: borderColor),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      icon,
                      color: accentColor,
                      size: 20,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const VGapXs(),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 4,
                            backgroundColor: Colors.white.withValues(alpha: 0.6),
                            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                          ),
                        ),
                      ),
                      const HGapSm(),
                      Text(
                        progressLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CarouselIndicatorRow extends StatelessWidget {
  final int activeIndex;

  const _CarouselIndicatorRow({required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final isActive = index == activeIndex;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isActive ? 20 : 6,
            height: 4,
            decoration: BoxDecoration(
              color: isActive ? AppTheme.primaryColor : const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
