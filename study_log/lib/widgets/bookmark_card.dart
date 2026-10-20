import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bookmark.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';
import 'study_text_fields.dart';

/// Highly polished, informative bookmark card matching the Study Log design system.
///
/// Follows [optimize_view.md] and [aa-rules.md] by decomposing layout into
/// dedicated StatelessWidget components and isolating image decoding.
class BookmarkCard extends StatelessWidget {
  final Bookmark bookmark;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onOptionsTap;
  final bool isHighlighted;

  static final DateFormat _dateFormat = DateFormat('d MMM yyyy');

  const BookmarkCard({
    super.key,
    required this.bookmark,
    this.onTap,
    this.onLongPress,
    this.onOptionsTap,
    this.isHighlighted = false,
  });

  void _handleTap(BuildContext context) {
    if (onTap != null) {
      onTap!();
    } else {
      UrlLauncherHelper.openUrl(bookmark.url, context: context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isHighlighted
            ? AppTheme.primaryColor.withValues(alpha: isDark ? 0.22 : 0.08)
            : AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        border: Border.all(
          color: isHighlighted
              ? AppTheme.primaryColor
              : AppTheme.borderColor(context),
          width: isHighlighted ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor(context),
            blurRadius: isHighlighted ? 10 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleTap(context),
          onLongPress: onLongPress ?? onOptionsTap,
          borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BookmarkThumbnail(bookmark: bookmark),
                    const HGapSm(),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (bookmark.isPinned) ...[
                                const Icon(
                                  Icons.push_pin_rounded,
                                  size: 13,
                                  color: Color(0xFFF59E0B),
                                ),
                                const HGapXs(),
                              ],
                              Expanded(
                                child: Text(
                                  bookmark.displayTitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimaryColor(context),
                                    height: 1.25,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const VGapXs(),
                          Row(
                            children: [
                              if (bookmark.isArchived) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.borderColor(context),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Archived',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textMutedColor(context),
                                    ),
                                  ),
                                ),
                                const HGapXs(),
                              ],
                              BookmarkHostChip(host: bookmark.cleanHost),
                              const HGapXs(),
                              Text(
                                '•  ${_dateFormat.format(bookmark.createdAt)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textMutedColor(context),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.more_horiz_rounded,
                        size: 20,
                        color: AppTheme.textMutedColor(context),
                      ),
                      onPressed: onOptionsTap,
                      tooltip: 'Options',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
                if (bookmark.description.isNotEmpty) ...[
                  const VGapXs(),
                  Text(
                    bookmark.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor(context),
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Thumbnail component with memory cache constraints and fallback badge.
class BookmarkThumbnail extends StatelessWidget {
  final Bookmark bookmark;

  const BookmarkThumbnail({
    super.key,
    required this.bookmark,
  });

  @override
  Widget build(BuildContext context) {
    final thumb = bookmark.thumbnailUrl;
    if (thumb == null || thumb.isEmpty) {
      return BookmarkPlatformBadge(bookmark: bookmark);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 68,
        height: 50,
        color: AppTheme.borderColor(context).withValues(alpha: 0.3),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.network(
              thumb,
              width: 68,
              height: 50,
              cacheWidth: 150,
              cacheHeight: 110,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  BookmarkPlatformBadge(bookmark: bookmark),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: 68,
                  height: 50,
                  color: AppTheme.surfaceVariant(context),
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryColor.withValues(alpha: 0.5),
                    ),
                  ),
                );
              },
            ),
            if (bookmark.isYouTube)
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 15,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Visual platform badge (YouTube, Twitter, GitHub, etc.) displayed when thumbnail is absent.
class BookmarkPlatformBadge extends StatelessWidget {
  final Bookmark bookmark;

  const BookmarkPlatformBadge({
    super.key,
    required this.bookmark,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color iconColor;
    IconData icon;

    if (bookmark.isYouTube) {
      bg = const Color(0xFFFEE2E2);
      iconColor = const Color(0xFFDC2626);
      icon = Icons.play_arrow_rounded;
    } else if (bookmark.isTwitter) {
      bg = const Color(0xFFE2E8F0);
      iconColor = const Color(0xFF0F1419);
      icon = Icons.tag_rounded;
    } else if (bookmark.isInstagram) {
      bg = const Color(0xFFFCE7F3);
      iconColor = const Color(0xFFDB2777);
      icon = Icons.camera_alt_rounded;
    } else if (bookmark.isLinkedIn) {
      bg = const Color(0xFFE0F2FE);
      iconColor = const Color(0xFF0284C7);
      icon = Icons.business_center_rounded;
    } else if (bookmark.isSubstack) {
      bg = const Color(0xFFFFEDD5);
      iconColor = const Color(0xFFEA580C);
      icon = Icons.bookmark_border_rounded;
    } else if (bookmark.isPinterest) {
      bg = const Color(0xFFFFE4E6);
      iconColor = const Color(0xFFE11D48);
      icon = Icons.push_pin_rounded;
    } else if (bookmark.isGitHub) {
      bg = const Color(0xFFE2E8F0);
      iconColor = const Color(0xFF1E293B);
      icon = Icons.code_rounded;
    } else if (bookmark.isMedium) {
      bg = const Color(0xFFE8F5E9);
      iconColor = const Color(0xFF2E7D32);
      icon = Icons.article_rounded;
    } else if (bookmark.isWikipedia) {
      bg = const Color(0xFFE0F7FA);
      iconColor = const Color(0xFF00838F);
      icon = Icons.menu_book_rounded;
    } else if (bookmark.isPdf) {
      bg = const Color(0xFFFFF3E0);
      iconColor = const Color(0xFFE65100);
      icon = Icons.picture_as_pdf_rounded;
    } else {
      bg = AppTheme.pastelPurple(context);
      iconColor = AppTheme.pastelPurpleText(context);
      icon = Icons.language_rounded;
    }

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: iconColor, size: 20),
    );
  }
}

/// Compact chip displaying the host domain.
class BookmarkHostChip extends StatelessWidget {
  final String host;

  const BookmarkHostChip({
    super.key,
    required this.host,
  });

  @override
  Widget build(BuildContext context) {
    if (host.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.borderColor(context).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        host,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondaryColor(context),
        ),
      ),
    );
  }
}
