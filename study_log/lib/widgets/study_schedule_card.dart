import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

/// Card component using the monochrome palette and style from the reference design:
/// - Light variant: soft grey container (#F4F4F6), dark text, black circular arrow button
/// - Featured variant: deep charcoal container (#1E1E1E), white text, duration pill badge, white circular arrow button
class StudyScheduleCard extends StatelessWidget {
  final String title;
  final String time;
  final String subtitle;
  final bool isFeatured;
  final IconData leadingIcon;
  final List<String>? avatarInitials;
  final VoidCallback? onTap;

  const StudyScheduleCard({
    super.key,
    required this.title,
    required this.time,
    required this.subtitle,
    this.isFeatured = false,
    this.leadingIcon = Icons.location_on_outlined,
    this.avatarInitials,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isFeatured ? AppTheme.darkCardColor : AppTheme.surfaceVariant;
    final titleColor = isFeatured ? AppTheme.textOnDark : AppTheme.textPrimary;
    final subtitleColor = isFeatured ? AppTheme.textOnDarkSecondary : AppTheme.textSecondary;
    final arrowBgColor = isFeatured ? AppTheme.surfaceColor : AppTheme.primaryColor;
    final arrowIconColor = isFeatured ? AppTheme.primaryColor : AppTheme.textOnDark;

    return Semantics(
      button: true,
      label: '$title at $time, $subtitle',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
              border: isFeatured
                  ? null
                  : Border.all(color: AppTheme.borderColor.withValues(alpha: 0.6)),
              boxShadow: [
                BoxShadow(
                  color: isFeatured
                      ? Colors.black.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.03),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Row: Title + Time Pill Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const HGapSm(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isFeatured
                            ? AppTheme.darkBadgeFill
                            : AppTheme.lightBadgeFill,
                        borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
                        border: Border.all(
                          color: isFeatured ? Colors.white24 : AppTheme.borderColor,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        time,
                        style: TextStyle(
                          color: isFeatured ? AppTheme.textOnDark : AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const VGapXl(),
                // Bottom Row: Location/Topic, Action Arrow Button, Avatar Stack
                Row(
                  children: [
                    // Circular action button from theme reference
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: arrowBgColor,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: arrowIconColor,
                      ),
                    ),
                    const HGapMd(),
                    // Location/Topic tag
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            leadingIcon,
                            size: 15,
                            color: subtitleColor,
                          ),
                          const HGapXs(),
                          Flexible(
                            child: Text(
                              subtitle,
                              style: TextStyle(
                                color: subtitleColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (avatarInitials != null && avatarInitials!.isNotEmpty)
                      _AvatarStack(
                        initials: avatarInitials!,
                        isDarkCard: isFeatured,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  final List<String> initials;
  final bool isDarkCard;

  const _AvatarStack({
    required this.initials,
    required this.isDarkCard,
  });

  @override
  Widget build(BuildContext context) {
    const double avatarSize = 24.0;
    const double overlap = 8.0;

    return SizedBox(
      height: avatarSize,
      width: (avatarSize * initials.length) - (overlap * (initials.length - 1)),
      child: Stack(
        children: List.generate(initials.length, (index) {
          return Positioned(
            left: index * (avatarSize - overlap),
            child: Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getAvatarBg(index),
                border: Border.all(
                  color: isDarkCard ? AppTheme.darkCardColor : AppTheme.surfaceVariant,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                initials[index],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Color _getAvatarBg(int index) {
    switch (index % 3) {
      case 0:
        return const Color(0xFF18181B);
      case 1:
        return const Color(0xFF3F3F46);
      default:
        return const Color(0xFF71717A);
    }
  }
}
