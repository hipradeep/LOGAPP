import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../models/bookmark.dart';
import '../models/todo_item.dart';
import '../services/database_service.dart';
import '../services/service_locator.dart';
import '../services/notification_service.dart';
import '../services/url_metadata_service.dart';

/// Central state controller managing web bookmarks, incoming URL shares,
/// tagging, search filtering, and deep study syllabus integration.
///
/// Follows zero-dependency ChangeNotifier architecture conforming to
/// [aa-rules.md], [optimize_data.md], and [optimize_view.md].
class BookmarksController extends ChangeNotifier {
  static const MethodChannel _shareChannel =
      MethodChannel('com.logapp.studylog/share');

  final DatabaseService _dbService;
  StreamSubscription<List<Bookmark>>? _subscription;

  List<Bookmark> _rawBookmarks = [];
  Map<String, Bookmark> _bookmarksById = const {};
  final Set<String> _enrichmentAttempted = {};

  // Pre-computed filtered bookmarks (Rule 1 of optimize_data.md)
  List<Bookmark> _cachedFilteredBookmarks = [];
  List<Bookmark> _cachedPinnedBookmarks = [];

  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedCategory;
  bool _onlyPinned = false;

  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String? get selectedCategory => _selectedCategory;
  bool get onlyPinned => _onlyPinned;

  int get totalCount => _rawBookmarks.length;
  int get activeTotalCount => _rawBookmarks.where((b) => !b.isArchived).length;
  int get archivedCount => _rawBookmarks.where((b) => b.isArchived).length;
  int get pinnedCount => _rawBookmarks.where((b) => b.isPinned && !b.isArchived).length;

  int countForCategory(String category) {
    if (category == 'Pinned') {
      return pinnedCount;
    }
    return _rawBookmarks
        .where((b) => !b.isArchived && b.platformCategory == category)
        .length;
  }

  /// Platform categories with active (non-archived) bookmarks,
  /// sorted descending by item count (max count first).
  List<String> get filterCategoriesSortedByCount {
    final Map<String, int> counts = {};

    for (final b in _rawBookmarks) {
      if (!b.isArchived) {
        final cat = b.platformCategory;
        counts[cat] = (counts[cat] ?? 0) + 1;
      }
    }

    final categories = counts.keys.toList();
    categories.sort((a, b) {
      final cA = counts[a] ?? 0;
      final cB = counts[b] ?? 0;
      if (cA != cB) {
        return cB.compareTo(cA); // max count first!
      }
      return a.compareTo(b);
    });

    return categories;
  }

  List<Bookmark> get bookmarks => _cachedFilteredBookmarks;
  List<Bookmark> get pinnedBookmarks => _cachedPinnedBookmarks;

  BookmarksController({DatabaseService? databaseService})
      : _dbService = databaseService ?? getIt<DatabaseService>() {
    _init();
  }

  void _init() {
    _subscription = _dbService.watchBookmarks().listen(_onBookmarksChanged);
    initShareListener();
    refresh();
  }

  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    try {
      final list = await _dbService.getBookmarks();
      _processBookmarks(list);
    } catch (e) {
      debugPrint('Error refreshing bookmarks: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _onBookmarksChanged(List<Bookmark> list) {
    _processBookmarks(list);
    notifyListeners();
  }

  void _processBookmarks(List<Bookmark> list) {
    _rawBookmarks = list;
    final map = <String, Bookmark>{};
    for (final b in list) {
      map[b.id] = b;
    }
    _bookmarksById = map;
    _recomputeFiltered();
    _checkMissingMetadata(list);
  }

  void _checkMissingMetadata(List<Bookmark> list) {
    for (final b in list) {
      if (_enrichmentAttempted.contains(b.id)) continue;
      final isGenericTitle = b.title.isEmpty ||
          b.title == b.url ||
          b.title == b.host ||
          b.title == b.cleanHost;
      final isMissingThumbnail = b.thumbnailUrl == null || b.thumbnailUrl!.isEmpty;

      if ((isGenericTitle || isMissingThumbnail) && b.url.startsWith('http')) {
        _enrichmentAttempted.add(b.id);
        unawaited(_enrichBookmarkMetadata(b.id, b.url));
      }
    }
  }

  Future<void> _enrichBookmarkMetadata(String bookmarkId, String url) async {
    _enrichmentAttempted.add(bookmarkId);
    try {
      final metadata = await UrlMetadataService.fetchMetadata(url);
      if (metadata == null || !metadata.hasContent) return;

      final current = _bookmarksById[bookmarkId] ??
          (await _dbService.getBookmarks()).cast<Bookmark?>().firstWhere(
                (b) => b?.id == bookmarkId,
                orElse: () => null,
              );
      if (current == null) return;

      final isGenericTitle = current.title.isEmpty ||
          current.title == current.url ||
          current.title == current.host ||
          current.title == current.cleanHost;

      final updatedTitle = (isGenericTitle &&
              metadata.title != null &&
              metadata.title!.isNotEmpty)
          ? metadata.title!
          : current.title;

      final updatedDesc = (current.description.isEmpty &&
              metadata.description != null &&
              metadata.description!.isNotEmpty)
          ? metadata.description!
          : current.description;

      final updatedImage = metadata.imageUrl ?? current.imageUrl;

      if (updatedTitle != current.title ||
          updatedDesc != current.description ||
          updatedImage != current.imageUrl) {
        final updated = current.copyWith(
          title: updatedTitle,
          description: updatedDesc,
          imageUrl: updatedImage,
          updatedAt: DateTime.now(),
        );
        await _dbService.updateBookmark(updated);
      }
    } catch (e) {
      debugPrint('Error enriching bookmark metadata: $e');
    }
  }

  void _recomputeFiltered() {
    final query = _searchQuery.trim().toLowerCase();

    final filtered = _rawBookmarks.where((b) {
      if (_selectedCategory == 'Archive') {
        if (!b.isArchived) return false;
      } else {
        // Hide archived bookmarks from regular views
        if (b.isArchived) return false;

        if (_selectedCategory == 'Pinned') {
          if (!b.isPinned) return false;
        } else if (_selectedCategory != null) {
          if (b.platformCategory != _selectedCategory) return false;
        }
      }
      if (query.isNotEmpty) {
        final inTitle = b.title.toLowerCase().contains(query);
        final inUrl = b.url.toLowerCase().contains(query);
        final inHost = b.host.toLowerCase().contains(query);
        final inDesc = b.description.toLowerCase().contains(query);
        final inTags = b.tags.any((t) => t.toLowerCase().contains(query));
        if (!inTitle && !inUrl && !inHost && !inDesc && !inTags) {
          return false;
        }
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      if (_selectedCategory != 'Archive') {
        if (a.isPinned != b.isPinned) {
          return a.isPinned ? -1 : 1;
        }
      }
      // Latest added on top
      return b.createdAt.compareTo(a.createdAt);
    });

    _cachedFilteredBookmarks = filtered;
    _cachedPinnedBookmarks =
        _rawBookmarks.where((b) => b.isPinned && !b.isArchived).toList();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Native Share Sheet Listener & Direct Auto-Save Handler
  // ─────────────────────────────────────────────────────────────────────────

  void initShareListener() {
    _shareChannel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedTextReceived') {
        final text = call.arguments as String?;
        if (text != null && text.trim().isNotEmpty) {
          await handleIncomingSharedText(text);
        }
      }
    });

    // Check for initial cold-launch share text
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkInitialShare();
    });
  }

  Future<void> checkInitialShare() async {
    try {
      final initialText =
          await _shareChannel.invokeMethod<String>('getInitialSharedText');
      if (initialText != null && initialText.trim().isNotEmpty) {
        await handleIncomingSharedText(initialText);
      }
    } catch (e) {
      debugPrint('Error reading initial shared text: $e');
    }
  }

  /// Parses shared text, auto-saves the Bookmark into SQLite, and
  /// navigates directly to BookmarksScreen with the new bookmark visible.
  Future<void> handleIncomingSharedText(String rawText) async {
    final parsed = extractUrlAndMetadata(rawText);
    if (parsed == null) return;

    final newBookmark = Bookmark(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      url: parsed['url'] ?? '',
      title: parsed['title'] ?? '',
      description: parsed['description'] ?? '',
      host: parsed['host'] ?? '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _dbService.insertBookmark(newBookmark);

    // Asynchronously fetch and enrich metadata (title, og:image, thumbnail)
    if (newBookmark.url.startsWith('http')) {
      unawaited(_enrichBookmarkMetadata(newBookmark.id, newBookmark.url));
    }

    // Trigger system notification with deep-link payload
    try {
      if (getIt.isRegistered<NotificationService>()) {
        await getIt<NotificationService>().showBookmarkSavedNotification(
          title: newBookmark.displayTitle,
          url: newBookmark.url,
          bookmarkId: newBookmark.id,
        );
      }
    } catch (e) {
      debugPrint('Error showing bookmark notification: $e');
    }

    // Keep user in their current app (Chrome, Twitter, YouTube) by sending task to back
    try {
      await _shareChannel.invokeMethod('sendToBackground');
    } catch (e) {
      debugPrint('Error sending task to background: $e');
    }
  }

  /// Extracts http/https URL and titles from mixed text shared from browsers or apps.
  static Map<String, String>? extractUrlAndMetadata(String rawText) {
    final urlRegex = RegExp(r'(https?://[^\s]+)', caseSensitive: false);
    final match = urlRegex.firstMatch(rawText);
    if (match == null) return null;

    final url = match.group(0)?.trim() ?? '';
    if (url.isEmpty) return null;

    // Remaining text before or after URL can be used as title or note
    final beforeUrl = rawText.substring(0, match.start).trim();
    final afterUrl = rawText.substring(match.end).trim();

    String title = '';
    String description = '';

    if (beforeUrl.isNotEmpty) {
      title = beforeUrl;
      description = afterUrl;
    } else if (afterUrl.isNotEmpty) {
      title = afterUrl;
    }

    String host = '';
    try {
      final uri = Uri.parse(url);
      host = uri.host;
      if (title.isEmpty) {
        // Fallback title derived from domain or path
        final segments =
            uri.pathSegments.where((s) => s.isNotEmpty).toList();
        if (segments.isNotEmpty) {
          final last = segments.last
              .replaceAll('-', ' ')
              .replaceAll('_', ' ')
              .replaceAll('.html', '')
              .replaceAll('.htm', '');
          title = last.isNotEmpty
              ? '${last[0].toUpperCase()}${last.substring(1)}'
              : host;
        } else {
          title = host.startsWith('www.') ? host.substring(4) : host;
        }
      }
    } catch (_) {
      host = '';
    }

    return {
      'url': url,
      'title': title,
      'description': description,
      'host': host,
    };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Filtering & Search
  // ─────────────────────────────────────────────────────────────────────────

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    _recomputeFiltered();
    notifyListeners();
  }

  void selectCategory(String? category) {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    _recomputeFiltered();
    notifyListeners();
  }

  void toggleOnlyPinned() {
    if (_selectedCategory == 'Pinned') {
      _selectedCategory = null;
    } else {
      _selectedCategory = 'Pinned';
    }
    _recomputeFiltered();
    notifyListeners();
  }

  void resetFilters() {
    _searchQuery = '';
    _selectedCategory = null;
    _onlyPinned = false;
    _recomputeFiltered();
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CRUD Operations
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> addBookmark(Bookmark bookmark) async {
    await _dbService.insertBookmark(bookmark);
    if (bookmark.url.startsWith('http')) {
      unawaited(_enrichBookmarkMetadata(bookmark.id, bookmark.url));
    }
  }

  Future<void> updateBookmark(Bookmark bookmark) async {
    await _dbService.updateBookmark(bookmark);
  }

  Future<void> togglePin(String id) async {
    final b = _bookmarksById[id];
    if (b == null) return;
    await _dbService.toggleBookmarkPinned(id, !b.isPinned);
  }

  Future<void> toggleArchive(String id) async {
    final b = _bookmarksById[id];
    if (b == null) return;
    await _dbService.toggleBookmarkArchived(id, !b.isArchived);
  }

  Future<void> deleteBookmark(String id) async {
    await _dbService.deleteBookmark(id);
  }

  /// Converts a bookmark into a dedicated study Todo item.
  Future<void> convertToTodo(Bookmark bookmark) async {
    final todo = TodoItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: 'Review: ${bookmark.displayTitle}',
      description: 'Bookmark link: ${bookmark.url}\n${bookmark.description}',
      status: TodoStatus.todo,
      priority: TodoPriority.med,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _dbService.insertTodo(todo);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
