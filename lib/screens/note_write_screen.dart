import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/app_spacers.dart';
import '../models/note_entity.dart';
import '../widgets/app_title_input.dart';

class MoodItem {
  final String emoji;
  final String label;
  final Color glowColor;

  const MoodItem({
    required this.emoji,
    required this.label,
    required this.glowColor,
  });
}

class NoteWriteScreen extends StatefulWidget {
  final NoteEntity? existingEntry;

  const NoteWriteScreen({
    super.key,
    this.existingEntry,
  });

  @override
  State<NoteWriteScreen> createState() => _NoteWriteScreenState();
}

class _NoteWriteScreenState extends State<NoteWriteScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  
  String _selectedMood = '😊';

  // Focus nodes to manage glassmorphic border highlights
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _contentFocusNode = FocusNode();

  bool _isContentFocused = false;

  int _wordCount = 0;
  int _charCount = 0;

  final List<MoodItem> _moods = const [
    MoodItem(emoji: '', label: 'None', glowColor: Colors.grey),
    MoodItem(emoji: '😊', label: 'Happy', glowColor: Colors.amber),
    MoodItem(emoji: '🚀', label: 'Productive', glowColor: Colors.blue),
    MoodItem(emoji: '🌌', label: 'Peaceful', glowColor: Colors.purple),
    MoodItem(emoji: '😔', label: 'Sad', glowColor: Colors.teal),
    MoodItem(emoji: '🔥', label: 'Energized', glowColor: Colors.deepOrange),
    MoodItem(emoji: '💤', label: 'Tired', glowColor: Colors.blueGrey),
    MoodItem(emoji: '🎉', label: 'Excited', glowColor: Colors.pink),
    MoodItem(emoji: '🧠', label: 'Focused', glowColor: Colors.indigo),
    MoodItem(emoji: '🌳', label: 'Grateful', glowColor: Colors.green),
    MoodItem(emoji: '❤️', label: 'Loved', glowColor: Colors.red),
  ];

  @override
  void initState() {
    super.initState();
    _selectedMood = widget.existingEntry?.mood ?? '';

    String titleText = widget.existingEntry?.title ?? '';
    // Strip the mood emoji if it exists at the start of the title to avoid duplicating it
    if (_selectedMood.isNotEmpty) {
      if (titleText.startsWith('$_selectedMood ')) {
        titleText = titleText.substring(_selectedMood.length + 1).trim();
      } else if (titleText.startsWith(_selectedMood)) {
        titleText = titleText.substring(_selectedMood.length).trim();
      }
    }

    _titleController = TextEditingController(text: titleText);
    _contentController = TextEditingController(text: widget.existingEntry?.content ?? '');

    _updateCounts(_contentController.text);

    // Add listener to rebuild on focus changes
    _contentFocusNode.addListener(() {
      setState(() {
        _isContentFocused = _contentFocusNode.hasFocus;
      });
    });

    // Add listener for word/char counts
    _contentController.addListener(() {
      _updateCounts(_contentController.text);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  void _updateCounts(String text) {
    setState(() {
      _charCount = text.length;
      _wordCount = text.trim().isEmpty 
          ? 0 
          : text.trim().split(RegExp(r'\s+')).length;
    });
  }

  void _saveLog() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, {
        'title': _selectedMood.isNotEmpty ? '$_selectedMood ${_titleController.text.trim()}' : _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'mood': _selectedMood,
        'tags': <String>[], // Return empty tags list since we removed tags
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingEntry != null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FullScreenPage(
        showScaffold: false,
        isScrollable: true,
        title: isEditing ? 'Edit note' : 'New note',
        showBackButton: true,
        actions: [
          TextButton(
            onPressed: _saveLog,
            child: Text(
              isEditing ? 'UPDATE' : 'SAVE',
              style: const TextStyle(
                color: AppTheme.primaryLight,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
        children: [
          const VGapMd(),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title Field
                AppTitleInput(
                  controller: _titleController,
                  focusNode: _titleFocusNode,
                  label: 'Note Title',
                  hintText: 'Give your entry a title...',
                  icon: Icons.edit_note_rounded,
                ),
                const VGapLg(),
                
                // Content Field
                Text(
                  'What\'s on your mind?'.toUpperCase(),
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.primaryLight,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const VGapSm(),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  constraints: const BoxConstraints(minHeight: 280),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isContentFocused
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
                    border: Border.all(
                      color: _isContentFocused
                          ? AppTheme.primaryColor
                          : Colors.white.withValues(alpha: 0.08),
                      width: _isContentFocused ? 2 : 1,
                    ),
                    boxShadow: _isContentFocused
                        ? [
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(alpha: 0.2),
                              blurRadius: 12,
                              spreadRadius: 1,
                            )
                          ]
                        : [],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _contentController,
                        focusNode: _contentFocusNode,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.6,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Start writing your story...',
                          hintStyle: TextStyle(color: AppTheme.textSecondary),
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please write something before saving';
                          }
                          return null;
                        },
                      ),
                      const VGapMd(),
                      const Divider(color: Colors.white12, height: 1),
                      const VGapSm(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '$_wordCount words',
                            style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                          ),
                          const HGapMd(),
                          Text(
                            '$_charCount characters',
                            style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const VGapLg(),
                
                // Mood Selection Heading
                Text(
                  'How are you feeling?'.toUpperCase(),
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.primaryLight,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const VGapSm(),
                
                // Moods Selector List
                SizedBox(
                  height: 84,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    clipBehavior: Clip.none,
                    itemCount: _moods.length,
                    itemBuilder: (context, index) {
                      final moodItem = _moods[index];
                      final isSelected = _selectedMood == moodItem.emoji;

                      return Padding(
                        padding: EdgeInsets.only(
                          left: index == 0 ? 12 : 0,
                          right: 12, 
                          top: 8, 
                          bottom: 8
                        ),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedMood = moodItem.emoji;
                            });
                          },
                          borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
                          child: AnimatedScale(
                            scale: isSelected ? 1.06 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 64,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? moodItem.glowColor.withValues(alpha: 0.15)
                                    : AppTheme.surfaceColor.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
                                border: Border.all(
                                  color: isSelected
                                      ? moodItem.glowColor
                                      : Colors.white.withValues(alpha: 0.05),
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: moodItem.glowColor.withValues(alpha: 0.3),
                                          blurRadius: 10,
                                          spreadRadius: 1,
                                        )
                                      ]
                                    : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (moodItem.emoji.isEmpty)
                                    const Icon(Icons.edit_note, color: Colors.white70, size: 24)
                                  else
                                    Text(
                                      moodItem.emoji,
                                      style: const TextStyle(fontSize: 20),
                                    ),
                                  const VGapXs(),
                                  Text(
                                    moodItem.label,
                                    style: AppTheme.bodyMicro.copyWith(
                                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                const VGapXl(),
                const VGapXxl(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
