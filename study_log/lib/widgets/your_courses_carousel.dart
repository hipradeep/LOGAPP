import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

/// "Your Courses" horizontal carousel section matching the reference design:
/// - Section header "Your Courses"
/// - Horizontal list of pastel course cards (DSA, System Design, Gen AI) with
///   progress bar and % text
/// - Carousel indicator dots (active violet pill, inactive grey dots)
class YourCoursesCarousel extends StatelessWidget {
  final VoidCallback? onCourseTap;

  const YourCoursesCarousel({super.key, this.onCourseTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Your Courses',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const VGapMd(),
        SizedBox(
          height: 146,
          child: ListView(
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
                onTap: onCourseTap,
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
                onTap: onCourseTap,
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
                onTap: onCourseTap,
              ),
            ],
          ),
        ),
        const VGapSm(),
        const _CarouselIndicatorRow(),
      ],
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
    return Container(
      width: 138,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        border: Border.all(color: borderColor, width: 1),
      ),
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
    );
  }
}

class _CarouselIndicatorRow extends StatelessWidget {
  const _CarouselIndicatorRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 20,
          height: 4,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const HGapSm(),
        Container(
          width: 6,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFD1D5DB),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const HGapSm(),
        Container(
          width: 6,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFD1D5DB),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}
