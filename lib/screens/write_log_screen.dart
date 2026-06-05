import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/app_spacers.dart';
import '../models/log_entry.dart';

class WriteLogScreen extends StatefulWidget {
  final LogEntry? existingEntry;
  final bool useMockData;

  const WriteLogScreen({
    Key? key,
    this.existingEntry,
    required this.useMockData,
  }) : super(key: key);

  @override
  State<WriteLogScreen> createState() => _WriteLogScreenState();
}

class _WriteLogScreenState extends State<WriteLogScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _tagController;
  
  late String _selectedMood;
  late List<String> _tags;

  final List<String> _moods = ['😊', '🚀', '🌌', '😔', '🔥', '💤', '🎉', '🧠', '🌳', '❤️'];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existingEntry?.title ?? '');
    _contentController = TextEditingController(text: widget.existingEntry?.content ?? '');
    _tagController = TextEditingController();
    
    _selectedMood = widget.existingEntry?.mood ?? '😊';
    _tags = List<String>.from(widget.existingEntry?.tags ?? []);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _addTag() {
    final text = _tagController.text.trim();
    if (text.isNotEmpty) {
      if (!_tags.contains(text)) {
        setState(() {
          _tags.add(text);
        });
      }
      _tagController.clear();
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  void _saveLog() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, {
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'mood': _selectedMood,
        'tags': _tags,
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
        title: isEditing ? 'Edit Entry' : 'New Entry',
        showBackButton: true,
        children: [
          const VGapMd(),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title Field
                TextFormField(
                  controller: _titleController,
                  style: AppTheme.headingMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    hintText: 'Give it a title...',
                    hintStyle: TextStyle(color: Colors.white24, fontSize: 24),
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const VGapMd(),
                
                // Mood Selection Heading
                Text(
                  'Select Mood'.toUpperCase(),
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.primaryLight,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const VGapSm(),
                
                // Moods Selector List
                SizedBox(
                  height: 56,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _moods.length,
                    itemBuilder: (context, index) {
                      final mood = _moods[index];
                      final isSelected = _selectedMood == mood;

                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedMood = mood;
                            });
                          },
                          borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
                          child: Container(
                            width: 54,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryColor.withValues(alpha: 0.15)
                                  : AppTheme.surfaceColor.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : Colors.white.withValues(alpha: 0.05),
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : null,
                            ),
                            child: Text(
                              mood,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const VGapLg(),

                // Tags Header & Input
                Text(
                  'Tags'.toUpperCase(),
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.primaryLight,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const VGapSm(),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05),
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: _tagController,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          onSubmitted: (_) => _addTag(),
                          decoration: const InputDecoration(
                            hintText: 'Add a tag (e.g. Work, Ideas)',
                            hintStyle: TextStyle(color: AppTheme.textSecondary),
                            border: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                    const HGapSm(),
                    InkWell(
                      onTap: _addTag,
                      borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
                      child: Container(
                        height: 48,
                        width: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
                          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.4)),
                        ),
                        child: const Icon(Icons.add, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const VGapSm(),
                
                // Tags List Wrapper
                if (_tags.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _tags.map((tag) {
                      return InputChip(
                        label: Text(tag),
                        labelStyle: TextStyle(
                          color: AppTheme.primaryLight,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
                          side: BorderSide(
                            color: AppTheme.primaryColor.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        deleteIcon: Icon(Icons.close, size: 14, color: AppTheme.primaryLight),
                        onDeleted: () => _removeTag(tag),
                      );
                    }).toList(),
                  ),
                const VGapLg(),

                // Content Field
                Text(
                  'What\'s on your mind?'.toUpperCase(),
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.primaryLight,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const VGapSm(),
                Container(
                  constraints: const BoxConstraints(minHeight: 250),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                      width: 1,
                    ),
                  ),
                  child: TextFormField(
                    controller: _contentController,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.5,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Start writing here...',
                      hintStyle: TextStyle(color: AppTheme.textSecondary),
                      border: InputBorder.none,
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
                ),
                const VGapXxl(),
                
                // Save Button (at bottom as well for ease of use)
                ElevatedButton(
                  onPressed: _saveLog,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, AppTheme.buttonHeight),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
                    ),
                    elevation: 4,
                  ),
                  child: Text(
                    isEditing ? 'Update Log' : 'Save Log',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const VGapXxl(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
