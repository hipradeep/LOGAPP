import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/bookmark.dart';
import '../models/todo_item.dart';
import '../theme/app_theme.dart';
import '../controllers/bookmarks_controller.dart';
import '../controllers/todo_controller.dart';
import '../screens/todo_detail_edit_screen.dart';
import '../services/service_locator.dart';
import 'app_spacers.dart';
import 'sheet_action_widgets.dart';
import 'study_confirmation_dialog.dart';
import 'study_text_fields.dart';

/// Modal bottom sheet providing streamlined actions for a bookmarked resource:
/// - Open in browser
/// - Toggle pin status
/// - Bookmark title, link, and description info preview
/// - Copy link
/// - Delete bookmark
class BookmarkOptionsSheet extends StatelessWidget {
  final Bookmark bookmark;

  const BookmarkOptionsSheet({
    super.key,
    required this.bookmark,
  });

  static Future<void> show(BuildContext context, Bookmark bookmark) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BookmarkOptionsSheet(bookmark: bookmark),
    );
  }

  void _handleOpen(BuildContext context) {
    Navigator.pop(context);
    UrlLauncherHelper.openUrl(bookmark.url, context: context);
  }

  Future<void> _handleTogglePin(BuildContext context) async {
    Navigator.pop(context);
    final ctrl = getIt<BookmarksController>();
    await ctrl.togglePin(bookmark.id);
  }

  Future<void> _handleToggleArchive(BuildContext context) async {
    Navigator.pop(context);
    final ctrl = getIt<BookmarksController>();
    await ctrl.toggleArchive(bookmark.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(bookmark.isArchived
              ? 'Bookmark restored from archive'
              : 'Bookmark archived'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleAddToTodo(BuildContext context) async {
    Navigator.pop(context);
    final now = DateTime.now();
    final descriptionParts = <String>[];
    if (bookmark.url.isNotEmpty) {
      descriptionParts.add(bookmark.url);
    }
    if (bookmark.description.isNotEmpty) {
      descriptionParts.add(bookmark.description);
    }

    final newTodo = TodoItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: bookmark.displayTitle,
      description: descriptionParts.join('\n\n'),
      status: TodoStatus.todo,
      priority: TodoPriority.med,
      createdAt: now,
      updatedAt: now,
    );

    if (getIt.isRegistered<TodoController>()) {
      await getIt<TodoController>().addTodo(newTodo);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Added to TODO'),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Edit',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TodoDetailEditScreen(todo: newTodo),
                ),
              );
            },
          ),
        ),
      );
    }
  }

  Future<void> _handleCopyLink(BuildContext context) async {
    Navigator.pop(context);
    await Clipboard.setData(ClipboardData(text: bookmark.url));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link copied to clipboard'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleDelete(BuildContext context) async {
    Navigator.pop(context);
    final confirmed = await StudyConfirmationDialog.showDeleteBookmark(context, bookmarkTitle: bookmark.displayTitle);

    if (confirmed == true) {
      final ctrl = getIt<BookmarksController>();
      await ctrl.deleteBookmark(bookmark.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: bottomPadding + 20,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandleBar(),
          const VGapMd(),
          SheetHeader(
            badge: SheetHeaderBadge(
              backgroundColor: AppTheme.pastelPurple(context),
              child: Icon(
                Icons.bookmark_rounded,
                color: AppTheme.pastelPurpleText(context),
                size: 22,
              ),
            ),
            title: bookmark.displayTitle,
            subtitle: bookmark.cleanHost.isNotEmpty ? bookmark.cleanHost : bookmark.url,
            subtitleMaxLines: 1,
          ),
          const VGapSm(),
          _buildBookmarkInfoCard(context),
          const VGapSm(),
          SheetActionRow(
            icon: Icons.open_in_browser_rounded,
            title: 'Open in Browser',
            onTap: () => _handleOpen(context),
          ),
          SheetActionRow(
            icon: Icons.add_task_rounded,
            title: 'Add to TODO',
            onTap: () => _handleAddToTodo(context),
          ),
          if (!bookmark.isArchived)
            SheetActionRow(
              icon: bookmark.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
              title: bookmark.isPinned ? 'Unpin Bookmark' : 'Pin to Top',
              onTap: () => _handleTogglePin(context),
            ),
          SheetActionRow(
            icon: bookmark.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
            title: bookmark.isArchived ? 'Restore' : 'Archive',
            onTap: () => _handleToggleArchive(context),
          ),
          SheetActionRow(
            icon: Icons.copy_rounded,
            title: 'Copy Link',
            onTap: () => _handleCopyLink(context),
          ),
          const VGapXs(),
          SheetDestructiveButton(
            title: 'Delete',
            onTap: () => _handleDelete(context),
          ),
          const VGapSm(),
          const SheetCancelButton(),
        ],
      ),
    );
  }

  Widget _buildBookmarkInfoCard(BuildContext context) {
    final thumb = bookmark.thumbnailUrl;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant(context),
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (thumb != null && thumb.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  thumb,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),
              ),
            ),
            const VGapSm(),
          ],
          Row(
            children: [
              Icon(
                Icons.link_rounded,
                size: 15,
                color: AppTheme.primaryColor,
              ),
              const HGapXs(),
              Expanded(
                child: Text(
                  bookmark.displayTitle,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
              ),
            ],
          ),
          const VGapXs(),
          GestureDetector(
            onTap: () => UrlLauncherHelper.openUrl(bookmark.url, context: context),
            child: Text(
              bookmark.url,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.primaryColor,
                decoration: TextDecoration.underline,
                decorationColor: AppTheme.primaryColor.withValues(alpha: 0.5),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (bookmark.description.isNotEmpty) ...[
            const VGapSm(),
            Text(
              bookmark.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryColor(context),
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
