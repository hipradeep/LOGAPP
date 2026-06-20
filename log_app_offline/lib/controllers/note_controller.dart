import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/note_entity.dart';
import '../services/note_service.dart';

class NoteController extends ChangeNotifier {
  final NoteService _noteService = NoteService();
  StreamSubscription<List<NoteEntity>>? _notesub;

  List<NoteEntity> _notes = [];
  List<NoteEntity> _pinnedNotes = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  int _daysLoaded = 7;

  // Getters
  List<NoteEntity> get notes => _notes;
  List<NoteEntity> get pinnedNotes => _pinnedNotes;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get errorMessage => _errorMessage;

  // Memoized grouped journals for masonry layout (unpinned only)
  Map<String, List<NoteEntity>> _groupedJournals = {};
  Map<String, List<NoteEntity>> get groupedJournals => _groupedJournals;

  String _getFormattedDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final entryDate = DateTime(date.year, date.month, date.day);

    if (entryDate == today) return 'Today';
    if (entryDate == yesterday) return 'Yesterday';
    
    return DateFormat('MMMM d, yyyy').format(date);
  }

  NoteController() {
    _initStream();
  }

  void _initStream() {
    _isLoading = true;
    notifyListeners();
    _subscribeToStream();
  }

  Future<void> refresh() async {
    _subscribeToStream();
    await Future.delayed(const Duration(milliseconds: 800));
  }

  void _subscribeToStream() {
    _notesub?.cancel();
    
    final oldestDate = DateTime.now().subtract(Duration(days: _daysLoaded));
    final oldestDateStart = DateTime(oldestDate.year, oldestDate.month, oldestDate.day);

    _notesub = _noteService.getNotesStream(oldestDate: oldestDateStart).listen(
      (journalsData) {
        _notes = journalsData;

        // Partition into pinned and unpinned
        _pinnedNotes = _notes.where((n) => n.isPinned).toList();
        final unpinned = _notes.where((n) => !n.isPinned).toList();

        // Pre-compute grouped journals (unpinned only) for masonry layout
        final Map<String, List<NoteEntity>> newGrouped = {};
        for (var entry in unpinned) {
          final label = _getFormattedDateLabel(entry.timestamp);
          newGrouped.putIfAbsent(label, () => []).add(entry);
        }
        _groupedJournals = newGrouped;

        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (error) {
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = error.toString();
        notifyListeners();
      },
    );
  }

  void loadMore() {
    if (_isLoadingMore) return;
    _isLoadingMore = true;
    _daysLoaded += 3;
    notifyListeners();
    _subscribeToStream();
  }

  @override
  void dispose() {
    _notesub?.cancel();
    super.dispose();
  }

  // ==================== ACTIONS ====================

  Future<void> createEntry(
    String title,
    String content,
    String mood,
    List<String> tags, {
    bool isPinned = false,
  }) async {
    try {
      await _noteService.createEntry(title, content, mood, tags, isPinned: isPinned);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateEntry(
    String id,
    String title,
    String content,
    String mood,
    List<String> tags, {
    bool isPinned = false,
  }) async {
    try {
      await _noteService.updateEntry(id, title, content, mood, tags, isPinned: isPinned);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> togglePin(String id, bool isPinned) async {
    try {
      await _noteService.togglePin(id, isPinned);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteEntry(String id) async {
    try {
      await _noteService.deleteEntry(id);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }
}
