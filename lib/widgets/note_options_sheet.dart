import 'package:flutter/material.dart';
import '../models/note_entity.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

class NoteOptionsSheet extends StatelessWidget {
  final NoteEntity entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const NoteOptionsSheet({
    super.key,
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppTheme.defaultBorderRadius),
          topRight: Radius.circular(AppTheme.defaultBorderRadius),
        ),
        border: Border(
          top: BorderSide(color: AppTheme.borderColor(context), width: 1),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const VGapSm(),
            // Handle bar
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderColor(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const VGapMd(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text(
                entry.title.isNotEmpty ? entry.title : 'note Entry',
                style: AppTheme.headingSmall.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (entry.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 8),
                child: Text(
                  entry.content,
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondaryColor(context), fontSize: 13),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            Divider(color: AppTheme.borderColor(context)),
            ListTile(
              leading: Icon(Icons.edit_rounded, color: AppTheme.primaryAccentColor(context)),
              title: Text('Edit Entry', style: AppTheme.bodyLarge),
              onTap: () {
                Navigator.pop(context);
                onEdit();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: AppTheme.errorColor),
              title: Text('Delete Entry', style: AppTheme.bodyLarge.copyWith(color: AppTheme.errorColor)),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
            const VGapSm(),
          ],
        ),
      ),
    );
  }
}
