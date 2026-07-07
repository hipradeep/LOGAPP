import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

/// A tappable grid of predefined emojis. Displays a highlight on the
/// currently-selected emoji and calls [onChanged] when a new one is tapped.
class EmojiPicker extends StatelessWidget {
  /// The currently selected emoji string.
  final String selected;

  /// Called with the new emoji when the user taps one.
  final ValueChanged<String> onChanged;

  /// Optional label rendered above the grid. Defaults to 'Pick an Emoji'.
  final String? label;

  /// Predefined emoji list used across the app.
  static const List<String> kEmojis = [
    '🎯', '📚', '🏋️', '🎮', '🧘', '☕', '🎨', '🎵',
    '💻', '✍️', '🌿', '🏃', '🍳', '📷', '🔬', '🧩',
    '💪', '🚀', '🌙', '⚡', '🎤', '🏊', '🛠️', '📝',
  ];

  const EmojiPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.label,
  });

  /// Opens a bottom sheet with the emoji grid and returns the selected emoji.
  /// Returns null if the user dismisses without selecting.
  static Future<String?> showAsBottomSheet(
    BuildContext context, {
    required String currentEmoji,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) => _EmojiPickerSheet(
          currentEmoji: currentEmoji,
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label ?? 'Pick an Emoji',
          style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold),
        ),
        const VGapSm(),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kEmojis.map((emoji) => _EmojiChip(
            emoji: emoji,
            isSelected: emoji == selected,
            onTap: () => onChanged(emoji),
          )).toList(),
        ),
      ],
    );
  }
}

// ── Bottom Sheet ────────────────────────────────────────────────────────────

class _EmojiPickerSheet extends StatefulWidget {
  final String currentEmoji;
  final ScrollController scrollController;

  const _EmojiPickerSheet({
    required this.currentEmoji,
    required this.scrollController,
  });

  @override
  State<_EmojiPickerSheet> createState() => _EmojiPickerSheetState();
}

class _EmojiPickerSheetState extends State<_EmojiPickerSheet> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentEmoji;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: SingleChildScrollView(
        controller: widget.scrollController,
        padding: EdgeInsets.fromLTRB(
          24, 16, 24,
          MediaQuery.paddingOf(context).bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderColor(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const VGapMd(),
            Center(
              child: Text(
                'Pick an Emoji',
                style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const VGapLg(),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: EmojiPicker.kEmojis.map((emoji) => _EmojiChip(
                emoji: emoji,
                isSelected: emoji == _selected,
                onTap: () {
                  setState(() => _selected = emoji);
                  Navigator.pop(context, emoji);
                },
              )).toList(),
            ),
            const VGapLg(),
          ],
        ),
      ),
    );
  }
}

// ── Chip ────────────────────────────────────────────────────────────────────

class _EmojiChip extends StatelessWidget {
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;

  const _EmojiChip({
    required this.emoji,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.15)
              : AppTheme.subtleFillColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : AppTheme.borderColor(context).withValues(alpha: 0.4),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(emoji, style: const TextStyle(fontSize: 24)),
        ),
      ),
    );
  }
}
