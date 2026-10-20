import 'dart:convert';

/// Represents an external web resource, link, or video bookmarked inside the Study Log app.
///
/// Captured from external apps via Android system share sheet (e.g. Chrome,
/// YouTube, Medium, browser) or entered manually.
class Bookmark {
  final String id;
  final String url;
  final String title;
  final String description;
  final String host;
  final String? imageUrl;
  final List<String> tags;
  final bool isPinned;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Bookmark({
    required this.id,
    required this.url,
    required this.title,
    this.description = '',
    this.host = '',
    this.imageUrl,
    this.tags = const [],
    this.isPinned = false,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Extract clean domain without `www.` prefix.
  String get cleanHost {
    if (host.isEmpty) {
      try {
        final uri = Uri.parse(url);
        final h = uri.host;
        return h.startsWith('www.') ? h.substring(4) : h;
      } catch (_) {
        return '';
      }
    }
    return host.startsWith('www.') ? host.substring(4) : host;
  }

  /// User friendly title with sensible fallbacks.
  String get displayTitle {
    final t = title.trim();
    if (t.isNotEmpty) return t;
    final h = cleanHost;
    if (h.isNotEmpty) return h;
    return url;
  }

  /// Whether the link points to a YouTube video.
  bool get isYouTube {
    final h = cleanHost.toLowerCase();
    return h.contains('youtube.com') || h.contains('youtu.be');
  }

  static final RegExp ytVideoIdRegex = RegExp(
    r'(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|shorts\/|watch\?.+&v=))([\w-]{11})',
    caseSensitive: false,
  );

  /// Extracts the 11-character YouTube video ID if applicable.
  String? get youtubeVideoId {
    if (!isYouTube) return null;
    final match = ytVideoIdRegex.firstMatch(url);
    return match?.group(1);
  }

  /// Thumbnail image preview URL.
  /// Falls back to YouTube's public high-quality thumbnail if video link.
  String? get thumbnailUrl {
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      return imageUrl;
    }
    final ytId = youtubeVideoId;
    if (ytId != null && ytId.isNotEmpty) {
      return 'https://img.youtube.com/vi/$ytId/hqdefault.jpg';
    }
    return null;
  }

  /// Whether the link points to a Twitter / X post or profile.
  bool get isTwitter {
    final h = cleanHost.toLowerCase();
    return h.contains('twitter.com') || h.contains('x.com');
  }

  /// Whether the link points to Instagram.
  bool get isInstagram {
    final h = cleanHost.toLowerCase();
    return h.contains('instagram.com');
  }

  /// Whether the link points to Pinterest.
  bool get isPinterest {
    final h = cleanHost.toLowerCase();
    return h.contains('pinterest.com') || h.contains('pin.it');
  }

  /// Whether the link points to LinkedIn.
  bool get isLinkedIn {
    final h = cleanHost.toLowerCase();
    return h.contains('linkedin.com');
  }

  /// Whether the link points to a Substack newsletter or post.
  bool get isSubstack {
    final h = cleanHost.toLowerCase();
    return h.contains('substack.com');
  }

  /// Whether the link points to a GitHub repository or gist.
  bool get isGitHub {
    final h = cleanHost.toLowerCase();
    return h.contains('github.com');
  }

  /// Whether the link points to a Medium story.
  bool get isMedium {
    final h = cleanHost.toLowerCase();
    return h.contains('medium.com');
  }

  /// Whether the link points to a Wikipedia article.
  bool get isWikipedia {
    final h = cleanHost.toLowerCase();
    return h.contains('wikipedia.org');
  }

  /// Whether the link points to a direct PDF document.
  bool get isPdf {
    final u = url.toLowerCase();
    return u.endsWith('.pdf') || u.contains('.pdf?');
  }

  /// Canonical platform category name for filter chips and organization.
  String get platformCategory {
    if (isYouTube) return 'YouTube';
    if (isTwitter) return 'Twitter/X';
    if (isInstagram) return 'Instagram';
    if (isLinkedIn) return 'LinkedIn';
    if (isSubstack) return 'Substack';
    if (isPinterest) return 'Pinterest';
    if (isGitHub) return 'GitHub';
    if (isMedium || isWikipedia) return 'Articles';
    if (isPdf) return 'PDF';
    return 'Web';
  }

  Bookmark copyWith({
    String? id,
    String? url,
    String? title,
    String? description,
    String? host,
    String? imageUrl,
    List<String>? tags,
    bool? isPinned,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearImage = false,
  }) {
    return Bookmark(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      description: description ?? this.description,
      host: host ?? this.host,
      imageUrl: clearImage ? null : (imageUrl ?? this.imageUrl),
      tags: tags ?? this.tags,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'title': title,
      'description': description,
      'host': host,
      'imageUrl': imageUrl,
      'tags': jsonEncode(tags),
      'isPinned': isPinned ? 1 : 0,
      'isArchived': isArchived ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Bookmark.fromMap(Map<String, dynamic> map) {
    List<String> parsedTags = [];
    final rawTags = map['tags'];
    if (rawTags is String && rawTags.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawTags);
        if (decoded is List) {
          parsedTags = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    } else if (rawTags is List) {
      parsedTags = rawTags.map((e) => e.toString()).toList();
    }

    DateTime parsedCreated;
    try {
      parsedCreated = DateTime.parse(map['createdAt'] as String);
    } catch (_) {
      parsedCreated = DateTime.now();
    }

    DateTime parsedUpdated;
    try {
      parsedUpdated = DateTime.parse(map['updatedAt'] as String);
    } catch (_) {
      parsedUpdated = parsedCreated;
    }

    return Bookmark(
      id: map['id'] as String,
      url: (map['url'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      host: (map['host'] as String?) ?? '',
      imageUrl: map['imageUrl'] as String?,
      tags: parsedTags,
      isPinned: (map['isPinned'] as int?) == 1,
      isArchived: (map['isArchived'] as int?) == 1,
      createdAt: parsedCreated,
      updatedAt: parsedUpdated,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory Bookmark.fromJson(String source) =>
      Bookmark.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
