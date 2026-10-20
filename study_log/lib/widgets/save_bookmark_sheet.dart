import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/bookmark.dart';
import '../theme/app_theme.dart';
import '../services/service_locator.dart';
import '../controllers/bookmarks_controller.dart';
import 'app_spacers.dart';
import 'sheet_action_widgets.dart';
import 'study_text_fields.dart';

/// Modal bottom sheet for adding or editing a web bookmark.
///
/// Streamlined for external URLs with title, notes, and pin toggle.
class SaveBookmarkSheet extends StatefulWidget {
  final Bookmark? existingBookmark;
  final String? initialUrl;

  const SaveBookmarkSheet({
    super.key,
    this.existingBookmark,
    this.initialUrl,
  });

  static Future<void> show(
    BuildContext context, {
    Bookmark? existingBookmark,
    String? initialUrl,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SaveBookmarkSheet(
        existingBookmark: existingBookmark,
        initialUrl: initialUrl,
      ),
    );
  }

  @override
  State<SaveBookmarkSheet> createState() => _SaveBookmarkSheetState();
}

class _SaveBookmarkSheetState extends State<SaveBookmarkSheet> {
  late final TextEditingController _urlController;
  late final TextEditingController _titleController;
  late final TextEditingController _descController;

  bool _isPinned = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.existingBookmark;
    _urlController = TextEditingController(text: b?.url ?? widget.initialUrl ?? '');
    _titleController = TextEditingController(text: b?.title ?? '');
    _descController = TextEditingController(text: b?.description ?? '');
    _isPinned = b?.isPinned ?? false;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _handlePaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      _urlController.text = text;
      final parsed = BookmarksController.extractUrlAndMetadata(text);
      if (parsed != null && _titleController.text.trim().isEmpty) {
        _titleController.text = parsed['title'] ?? '';
      }
      setState(() {});
    }
  }

  Future<void> _onSave() async {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid URL'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final formattedUrl = (rawUrl.startsWith('http://') || rawUrl.startsWith('https://'))
        ? rawUrl
        : 'https://$rawUrl';

    setState(() => _isSaving = true);

    String host = '';
    try {
      host = Uri.parse(formattedUrl).host;
    } catch (_) {}

    String title = _titleController.text.trim();
    if (title.isEmpty) {
      title = host.isNotEmpty ? (host.startsWith('www.') ? host.substring(4) : host) : formattedUrl;
    }

    final bookmarksCtrl = getIt<BookmarksController>();

    if (widget.existingBookmark != null) {
      final updated = widget.existingBookmark!.copyWith(
        url: formattedUrl,
        title: title,
        description: _descController.text.trim(),
        host: host,
        isPinned: _isPinned,
        updatedAt: DateTime.now(),
      );
      await bookmarksCtrl.updateBookmark(updated);
    } else {
      final newBookmark = Bookmark(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        url: formattedUrl,
        title: title,
        description: _descController.text.trim(),
        host: host,
        isPinned: _isPinned,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await bookmarksCtrl.addBookmark(newBookmark);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;
    final paddingBottom = MediaQuery.paddingOf(context).bottom;
    final isEdit = widget.existingBookmark != null;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: viewInsetsBottom + paddingBottom + 20,
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
                    isEdit ? Icons.edit_note_rounded : Icons.bookmark_add_rounded,
                    color: AppTheme.pastelPurpleText(context),
                    size: 22,
                  ),
                ),
                title: isEdit ? 'Edit Bookmark' : 'Add Bookmark',
                subtitle: isEdit
                    ? 'Update web link details and notes'
                    : 'Save webpage, video, or documentation link',
              ),
              const VGapLg(),
              UnderlineInputField(
                label: 'URL',
                controller: _urlController,
                hintText: 'https://...',
                isRequired: true,
                keyboardType: TextInputType.url,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste_rounded, size: 18),
                  tooltip: 'Paste link',
                  onPressed: _handlePaste,
                ),
              ),
              const VGapMd(),
              UnderlineInputField(
                label: 'Title',
                controller: _titleController,
                hintText: 'Auto-derived from link if empty',
              ),
              const VGapMd(),
              UnderlineInputField(
                label: 'Notes / Description',
                controller: _descController,
                hintText: 'Optional notes, takeaways, or tags',
                maxLines: 3,
                minLines: 1,
              ),
              const VGapMd(),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _isPinned,
                title: Text(
                  'Pin to Top',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                subtitle: Text(
                  'Keep this bookmark prioritized at the top of the list',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.textMutedColor(context),
                  ),
                ),
                activeTrackColor: AppTheme.primaryColor,
                onChanged: (val) => setState(() => _isPinned = val),
              ),
              const VGapLg(),
              SheetSubmitButton(
                text: isEdit ? 'Update Bookmark' : 'Save Bookmark',
                icon: isEdit ? Icons.check_rounded : Icons.bookmark_add_rounded,
                isLoading: _isSaving,
                onPressed: _onSave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
