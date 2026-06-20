import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/app_spacers.dart';
import '../models/note_entity.dart';

import '../widgets/app_popup_menu_button.dart';
import '../services/note_service.dart';
import '../widgets/app_toast.dart';

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

class NoteWriteController extends ChangeNotifier {
  final NoteEntity? existingEntry;
  late final TextEditingController titleController;
  late final TextEditingController contentController;
  late final FocusNode titleFocusNode;
  late final FocusNode contentFocusNode;
  
  late DateTime timestamp;
  late String selectedMood;
  late bool isPinned;
  late List<String> tags;

  String? noteId;
  String _lastSavedTitle = '';
  String _lastSavedContent = '';
  String _lastSavedMood = '';
  bool _lastSavedPinned = false;
  DateTime? _lastSavedTimestamp;
  
  // History for content undo/redo
  final List<String> _history = [];
  int _historyIndex = -1;
  bool _isPerformingUndoRedo = false;

  NoteWriteController({this.existingEntry, String? initialTitle}) {
    noteId = existingEntry?.id;
    selectedMood = existingEntry?.mood ?? '📝';
    isPinned = existingEntry?.isPinned ?? false;
    tags = existingEntry?.tags ?? <String>[];
    
    final titleText = existingEntry?.title ?? initialTitle ?? '';
    
    titleController = TextEditingController(text: titleText);
    contentController = TextEditingController(text: existingEntry?.content ?? '');
    titleFocusNode = FocusNode();
    contentFocusNode = FocusNode();
    timestamp = existingEntry?.timestamp ?? DateTime.now();

    _lastSavedTitle = existingEntry?.title ?? '';
    _lastSavedContent = existingEntry?.content ?? '';
    _lastSavedMood = existingEntry?.mood ?? '';
    _lastSavedPinned = existingEntry?.isPinned ?? false;
    _lastSavedTimestamp = existingEntry?.timestamp;

    // Initialize history
    _history.add(contentController.text);
    _historyIndex = 0;

    contentController.addListener(_onContentChanged);
  }

  void _onContentChanged() {
    if (_isPerformingUndoRedo) return;
    
    final currentText = contentController.text;
    if (_historyIndex >= 0 && currentText == _history[_historyIndex]) return;

    // Clear redo history
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }

    _history.add(currentText);
    if (_history.length > 50) {
      _history.removeAt(0);
    }
    _historyIndex = _history.length - 1;
    notifyListeners();
  }

  bool get canUndo => _historyIndex > 0;
  bool get canRedo => _historyIndex < _history.length - 1;

  void undo() {
    if (!canUndo) return;
    _isPerformingUndoRedo = true;
    _historyIndex--;
    contentController.text = _history[_historyIndex];
    contentController.selection = TextSelection.fromPosition(
      TextPosition(offset: contentController.text.length),
    );
    _isPerformingUndoRedo = false;
    notifyListeners();
  }

  void redo() {
    if (!canRedo) return;
    _isPerformingUndoRedo = true;
    _historyIndex++;
    contentController.text = _history[_historyIndex];
    contentController.selection = TextSelection.fromPosition(
      TextPosition(offset: contentController.text.length),
    );
    _isPerformingUndoRedo = false;
    notifyListeners();
  }

  void updateMood(String mood) {
    selectedMood = mood;
    notifyListeners();
  }

  void togglePin() {
    isPinned = !isPinned;
    notifyListeners();
  }

  void updateTimestamp(DateTime newDate) {
    timestamp = newDate;
    notifyListeners();
  }

  void markAsSaved({
    required String id,
    required String title,
    required String content,
    required String mood,
    required bool pinned,
    required DateTime time,
  }) {
    noteId = id;
    _lastSavedTitle = title;
    _lastSavedContent = content;
    _lastSavedMood = mood;
    _lastSavedPinned = pinned;
    _lastSavedTimestamp = time;
  }

  bool get isDirty {
    final currentTitle = titleController.text.trim();
    final currentContent = contentController.text.trim();
    final currentMood = selectedMood;
    final currentPinned = isPinned;
    final currentTime = timestamp;

    if (noteId == null) {
      return currentTitle.isNotEmpty || currentContent.isNotEmpty;
    }

    return currentTitle != _lastSavedTitle ||
        currentContent != _lastSavedContent ||
        currentMood != _lastSavedMood ||
        currentPinned != _lastSavedPinned ||
        (currentTime.millisecondsSinceEpoch != _lastSavedTimestamp?.millisecondsSinceEpoch);
  }

  @override
  void dispose() {
    contentController.removeListener(_onContentChanged);
    titleController.dispose();
    contentController.dispose();
    titleFocusNode.dispose();
    contentFocusNode.dispose();
    super.dispose();
  }
}

class NoteWriteScreen extends StatefulWidget {
  final NoteEntity? existingEntry;
  final String? initialTitle;

  const NoteWriteScreen({
    super.key,
    this.existingEntry,
    this.initialTitle,
  });

  @override
  State<NoteWriteScreen> createState() => _NoteWriteScreenState();
}

class _NoteWriteScreenState extends State<NoteWriteScreen> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  late final NoteWriteController _writeController;
  final NoteService _noteService = NoteService();
  bool _isExplicitlySavingOrDeleting = false;

  final List<MoodItem> _moods = const [
    MoodItem(emoji: '📝', label: 'Note', glowColor: Colors.grey),
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
    WidgetsBinding.instance.addObserver(this);
    _writeController = NoteWriteController(
      existingEntry: widget.existingEntry,
      initialTitle: widget.initialTitle,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _writeController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _saveOnLifecycleChange();
    }
  }

  Future<void> _saveOnLifecycleChange() async {
    if (_isExplicitlySavingOrDeleting) return;

    final id = _writeController.noteId;
    final title = _writeController.titleController.text.trim();
    final content = _writeController.contentController.text.trim();
    final mood = _writeController.selectedMood;
    final pinned = _writeController.isPinned;
    final time = _writeController.timestamp;
    final tags = _writeController.tags;

    if (_writeController.isDirty) {
      try {
        if (id == null) {
          final newId = await _noteService.createEntry(title, content, mood, tags, isPinned: pinned);
          _writeController.markAsSaved(
            id: newId,
            title: title,
            content: content,
            mood: mood,
            pinned: pinned,
            time: time,
          );
        } else {
          await _noteService.updateEntry(id, title, content, mood, tags, isPinned: pinned);
          _writeController.markAsSaved(
            id: id,
            title: title,
            content: content,
            mood: mood,
            pinned: pinned,
            time: time,
          );
        }
      } catch (e) {
        debugPrint('Error auto-creating/updating note on lifecycle: $e');
      }
    }
  }

  Future<void> _saveOnPop() async {
    if (_isExplicitlySavingOrDeleting) return;

    final id = _writeController.noteId;
    final title = _writeController.titleController.text.trim();
    final content = _writeController.contentController.text.trim();
    final mood = _writeController.selectedMood;
    final pinned = _writeController.isPinned;
    final tags = _writeController.tags;

    if (_writeController.isDirty) {
      _isExplicitlySavingOrDeleting = true;
      try {
        if (id == null) {
          await _noteService.createEntry(title, content, mood, tags, isPinned: pinned);
        } else {
          await _noteService.updateEntry(id, title, content, mood, tags, isPinned: pinned);
        }
      } catch (e) {
        debugPrint('Error auto-creating/updating note on pop: $e');
      }
    }
  }



  void _handleDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        ),
        title: Text(
          'Delete Note?',
          style: AppTheme.headingSmall,
        ),
        content: Text(
          'Are you sure you want to delete this note? This action cannot be undone.',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: _popDialog,
            child: Text(
              'CANCEL',
              style: TextStyle(color: AppTheme.textSecondaryColor(context)),
            ),
          ),
          TextButton(
            onPressed: _confirmDelete,
            child: const Text(
              'DELETE',
              style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _popDialog() {
    Navigator.pop(context);
  }

  void _confirmDelete() async {
    _isExplicitlySavingOrDeleting = true;
    Navigator.pop(context); // Pop dialog
    
    final id = _writeController.noteId;
    if (id != null) {
      try {
        await _noteService.deleteEntry(id);
        if (mounted) {
          AppToast.show(
            context: context,
            message: 'Note deleted 🗑️',
            backgroundColor: AppTheme.errorColor,
          );
        }
      } catch (e) {
        debugPrint('Error deleting note: $e');
      }
    }
    
    if (mounted) {
      Navigator.pop(context); // Return to notes list
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _saveOnPop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: FullScreenPage(
          showScaffold: false,
          isScrollable: true,
          title: widget.existingEntry != null ? 'Edit note' : 'New note',
          showBackButton: true,
          padding: AppTheme.defaultScreenPadding.resolve(TextDirection.ltr).copyWith(
                bottom: AppTheme.defaultScreenPadding.resolve(TextDirection.ltr).bottom +
                    MediaQuery.viewInsetsOf(context).bottom,
              ),

        actions: [

          Transform.translate(
            offset: const Offset(8, 0),
            child: ListenableBuilder(
              listenable: _writeController,
              builder: (context, _) {
                return AppPopupMenuButton(
                  onSelected: (value) {
                    if (value == 'pin') {
                      _writeController.togglePin();
                    } else if (value == 'delete') {
                      _handleDelete();
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    PopupMenuItem<String>(
                      value: 'pin',
                      child: Row(
                        children: [
                          Icon(
                            _writeController.isPinned
                                ? Icons.push_pin_rounded
                                : Icons.push_pin_outlined,
                            color: _writeController.isPinned
                                ? AppTheme.primaryColor
                                : Theme.of(context).iconTheme.color,
                            size: 20,
                          ),
                          const HGapSm(),
                          Text(_writeController.isPinned ? 'Unpin Note' : 'Pin Note'),
                        ],
                      ),
                    ),
                    if (widget.existingEntry != null)
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, color: AppTheme.errorColor, size: 20),
                            HGapSm(),
                            Text('Delete Note', style: TextStyle(color: AppTheme.errorColor)),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
        children: [
          const VGapSm(),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NoteTitleField(controller: _writeController),
                Divider(color: AppTheme.borderColor(context), height: 1),
                const VGapXs(),
                NoteDateField(controller: _writeController),
                const VGapSm(),
                NoteMoodSelector(controller: _writeController, moods: _moods),
                const VGapSm(),
                Divider(color: AppTheme.borderColor(context), height: 1),
                const VGapMd(),
                NoteContentField(controller: _writeController),
                const VGapXl(),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
}

class NoteTitleField extends StatelessWidget {
  final NoteWriteController controller;

  const NoteTitleField({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller.titleController,
      focusNode: controller.titleFocusNode,
      style: GoogleFonts.outfit(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimaryColor(context),
      ),
      maxLines: null,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      decoration: InputDecoration(
        hintText: 'Title',
        hintStyle: GoogleFonts.outfit(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppTheme.hintColor(context),
        ),
        border: InputBorder.none,
        focusedBorder: InputBorder.none,
        enabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        filled: false,
      ),
      validator: (val) {
        if (val == null || val.trim().isEmpty) {
          return 'Please enter a title';
        }
        return null;
      },
    );
  }
}

class NoteDateField extends StatelessWidget {
  final NoteWriteController controller;

  const NoteDateField({
    super.key,
    required this.controller,
  });

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: controller.timestamp,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: AppTheme.isDarkMode(context)
              ? AppTheme.darkTheme.copyWith(
                  colorScheme: ColorScheme.dark(
                    primary: AppTheme.primaryColor,
                    onPrimary: Colors.white,
                    surface: AppTheme.surfaceColor,
                    onSurface: Colors.white,
                  ),
                )
              : AppTheme.lightTheme.copyWith(
                  colorScheme: ColorScheme.light(
                    primary: AppTheme.primaryColor,
                    onPrimary: Colors.white,
                    surface: AppTheme.lightSurfaceColor,
                    onSurface: AppTheme.lightTextPrimary,
                  ),
                ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final originalTime = controller.timestamp;
      final newDateTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        originalTime.hour,
        originalTime.minute,
        originalTime.second,
      );
      controller.updateTimestamp(newDateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final formattedDate = DateFormat('d MMMM yyyy').format(controller.timestamp);
        return InkWell(
          onTap: () => _selectDate(context),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: AppTheme.textSecondaryColor(context),
                ),
                const HGapSm(),
                Text(
                  formattedDate,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondaryColor(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class NoteContentField extends StatelessWidget {
  final NoteWriteController controller;

  const NoteContentField({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller.contentController,
      focusNode: controller.contentFocusNode,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      style: TextStyle(
        color: AppTheme.textPrimaryColor(context),
        fontSize: 16,
        height: 1.6,
      ),
      decoration: InputDecoration(
        hintText: 'Description',
        hintStyle: TextStyle(
          color: AppTheme.hintColor(context),
          fontSize: 16,
        ),
        border: InputBorder.none,
        focusedBorder: InputBorder.none,
        enabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        filled: false,
      ),
      validator: (val) {
        if (val == null || val.trim().isEmpty) {
          return 'Please write something before saving';
        }
        return null;
      },
    );
  }
}

class NoteMoodSelector extends StatelessWidget {
  final NoteWriteController controller;
  final List<MoodItem> moods;

  const NoteMoodSelector({
    super.key,
    required this.controller,
    required this.moods,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final activeMood = moods.firstWhere(
          (m) => m.emoji == controller.selectedMood,
          orElse: () => moods.first,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: moods.length,
                itemBuilder: (context, index) {
                  final moodItem = moods[index];
                  final isSelected = controller.selectedMood == moodItem.emoji;
                  final accentColor = isSelected ? moodItem.glowColor : AppTheme.borderColor(context);

                  return Padding(
                    padding: const EdgeInsets.only(right: 8, top: 2, bottom: 2),
                    child: InkWell(
                      onTap: () => controller.updateMood(moodItem.emoji),
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? moodItem.glowColor.withValues(alpha: 0.15)
                              : AppTheme.surface(context).withValues(alpha: 0.4),
                          border: Border.all(
                            color: accentColor,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: moodItem.glowColor.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 1),
                                  )
                                ]
                              : null,
                        ),
                        child: Center(
                          child: moodItem.emoji.isEmpty
                              ? Icon(
                                  Icons.edit_note_rounded,
                                  color: isSelected ? AppTheme.textPrimaryColor(context) : AppTheme.textSecondaryColor(context),
                                  size: 18,
                                )
                              : Text(
                                  moodItem.emoji,
                                  style: const TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const VGapSm(),
            Text(
              activeMood.label,
              style: AppTheme.bodySmall.copyWith(
                color: activeMood.emoji.isEmpty ? AppTheme.textSecondaryColor(context) : activeMood.glowColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      },
    );
  }
}

