import 'dart:async';
import 'package:flutter/material.dart';
import '../models/bookmark.dart';
import '../controllers/bookmarks_controller.dart';
import '../services/service_locator.dart';
import '../theme/app_theme.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_spacers.dart';
import '../widgets/bookmark_card.dart';
import '../widgets/bookmark_options_sheet.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/save_bookmark_sheet.dart';

/// Screen displaying all bookmarked web resources, videos, and articles.
///
/// Features:
/// - Fast text search debounced for smooth rendering
/// - Filter chips for All, Pinned, and Category-specific bookmarks
/// - Highlight animation for newly received shared URLs
/// - Quick add action button
class BookmarksScreen extends StatefulWidget {
  final String? highlightBookmarkId;

  const BookmarksScreen({
    super.key,
    this.highlightBookmarkId,
  });

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  late final BookmarksController _controller;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  Timer? _highlightTimer;
  String? _highlightId;

  @override
  void initState() {
    super.initState();
    _controller = getIt<BookmarksController>();
    _highlightId = widget.highlightBookmarkId;

    if (_highlightId != null) {
      _highlightTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() => _highlightId = null);
        }
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.refresh();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _highlightTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      _controller.setSearchQuery(query);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _controller.setSearchQuery('');
  }

  void _openAddBookmark(BuildContext context) {
    SaveBookmarkSheet.show(context);
  }

  void _openOptions(BuildContext context, Bookmark bookmark) {
    BookmarkOptionsSheet.show(context, bookmark);
  }

  String _getEmptyTitle() {
    if (_controller.searchQuery.isNotEmpty) {
      return 'No Matching Bookmarks';
    }
    if (_controller.selectedCategory == 'Archive') {
      return 'Archive is Empty';
    }
    if (_controller.selectedCategory != null) {
      return 'No ${_controller.selectedCategory} Bookmarks';
    }
    return 'No Bookmarks Yet';
  }

  String _getEmptyDescription() {
    if (_controller.searchQuery.isNotEmpty) {
      return 'Try searching with another keyword.';
    }
    if (_controller.selectedCategory == 'Archive') {
      return 'Bookmarks you archive will be stored here safely.';
    }
    if (_controller.selectedCategory != null) {
      return 'No bookmarks found in this category.';
    }
    return 'Share links from Chrome, YouTube, or browser apps to Study Log, or tap + to save reference notes.';
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            // 1. App Bar with dynamic title/count
            ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                final isArchiveView = _controller.selectedCategory == 'Archive';
                final count = isArchiveView
                    ? _controller.bookmarks.length
                    : _controller.activeTotalCount;
                return CustomAppBar(
                  title: isArchiveView ? 'Archive' : 'Bookmarks',
                  subtitle: count > 0
                      ? '$count ${count == 1 ? "link" : "links"}${isArchiveView ? " archived" : " saved"}'
                      : null,
                  onBack: () => Navigator.of(context).pop(),
                  actions: [
                    IconButton(
                      icon: Icon(
                        Icons.add_rounded,
                        color: AppTheme.textPrimaryColor(context),
                        size: 24,
                      ),
                      onPressed: () => _openAddBookmark(context),
                      tooltip: 'Add Bookmark',
                    ),
                  ],
                );
              },
            ),

            // 2. Search bar isolated from ListenableBuilder
            _BookmarkSearchBar(
              controller: _searchController,
              onChanged: _onSearchChanged,
              onClear: _clearSearch,
            ),
            const VGapSm(),

            // 3. Category Filter Chips with targeted rebuild scope
            ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => BookmarkFilterChips(controller: _controller),
            ),
            const VGapSm(),

            // 4. Virtualized Bookmarks List
            Expanded(
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) {
                  final bookmarks = _controller.bookmarks;

                  if (_controller.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }

                  if (bookmarks.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: AppEmptyState(
                          icon: _controller.selectedCategory == 'Archive'
                              ? Icons.archive_outlined
                              : Icons.bookmark_outline_rounded,
                          title: _getEmptyTitle(),
                          description: _getEmptyDescription(),
                          actionLabel: _controller.searchQuery.isNotEmpty
                              ? 'Clear Search'
                              : (_controller.selectedCategory != null
                                  ? 'Show All Bookmarks'
                                  : 'Add Bookmark'),
                          onActionPressed: _controller.searchQuery.isNotEmpty
                              ? _clearSearch
                              : (_controller.selectedCategory != null
                                  ? () => _controller.selectCategory(null)
                                  : () => _openAddBookmark(context)),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      4,
                      16,
                      bottomSafe + 24,
                    ),
                    itemCount: bookmarks.length,
                    itemBuilder: (context, index) {
                      final bookmark = bookmarks[index];
                      final isHighlight = bookmark.id == _highlightId;
                      return BookmarkCard(
                        key: ValueKey(bookmark.id),
                        bookmark: bookmark,
                        isHighlighted: isHighlight,
                        onOptionsTap: () => _openOptions(context, bookmark),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Search input bar decoupled from reactive controller listeners.
class _BookmarkSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _BookmarkSearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderColor(context)),
        ),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textPrimaryColor(context),
          ),
          decoration: InputDecoration(
            hintText: 'Search bookmarks, links, tags...',
            hintStyle: TextStyle(
              fontSize: 13,
              color: AppTheme.textMutedColor(context),
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 19,
              color: AppTheme.textMutedColor(context),
            ),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 16),
                    onPressed: onClear,
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }
}

/// Filter chips carousel for switching between platform categories and tags.
class BookmarkFilterChips extends StatelessWidget {
  final BookmarksController controller;

  const BookmarkFilterChips({
    super.key,
    required this.controller,
  });

  IconData? _getCategoryIcon(String category) {
    switch (category) {
      case 'Pinned':
        return Icons.push_pin_rounded;
      case 'YouTube':
        return Icons.play_arrow_rounded;
      case 'Twitter/X':
        return Icons.tag_rounded;
      case 'Instagram':
        return Icons.camera_alt_rounded;
      case 'LinkedIn':
        return Icons.business_center_rounded;
      case 'Substack':
        return Icons.bookmark_border_rounded;
      case 'Pinterest':
        return Icons.push_pin_rounded;
      case 'GitHub':
        return Icons.code_rounded;
      case 'Articles':
        return Icons.article_rounded;
      case 'PDF':
        return Icons.picture_as_pdf_rounded;
      default:
        return Icons.language_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedCategories = controller.filterCategoriesSortedByCount;
    final selected = controller.selectedCategory;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // 1. All chip
          _CategoryChip(
            label: 'All',
            isSelected: selected == null,
            onTap: () => controller.selectCategory(null),
          ),
          const HGapXs(),

          // 2. Pinned chip
          _CategoryChip(
            label: 'Pinned',
            icon: Icons.push_pin_rounded,
            isSelected: selected == 'Pinned',
            onTap: () => controller.toggleOnlyPinned(),
          ),

          // 3. Platform categories sorted by max count
          for (final cat in sortedCategories) ...[
            const HGapXs(),
            _CategoryChip(
              label: cat,
              icon: _getCategoryIcon(cat),
              isSelected: selected == cat,
              onTap: () => controller.selectCategory(selected == cat ? null : cat),
            ),
          ],

          // 4. Archive chip
          const HGapXs(),
          _CategoryChip(
            label: 'Archive',
            icon: Icons.archive_outlined,
            isSelected: selected == 'Archive',
            onTap: () => controller.selectCategory(
              selected == 'Archive' ? null : 'Archive',
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor
                : AppTheme.surface(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryColor
                  : AppTheme.borderColor(context),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 13,
                  color: isSelected
                      ? Colors.white
                      : (label == 'Pinned'
                          ? const Color(0xFFF59E0B)
                          : AppTheme.textSecondaryColor(context)),
                ),
                const HGapXs(),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : AppTheme.textSecondaryColor(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
