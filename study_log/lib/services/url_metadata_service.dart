import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/bookmark.dart';

/// Structured metadata extracted from a target webpage or video URL.
class UrlMetadata {
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? siteName;

  const UrlMetadata({
    this.title,
    this.description,
    this.imageUrl,
    this.siteName,
  });

  bool get hasContent =>
      (title != null && title!.isNotEmpty) ||
      (description != null && description!.isNotEmpty) ||
      (imageUrl != null && imageUrl!.isNotEmpty);
}

/// Service that fetches OpenGraph, Twitter card, HTML <title>, and YouTube
/// metadata for saved bookmark URLs in the background.
class UrlMetadataService {

  static final RegExp _titleTagRegex = RegExp(
    r'<title[^>]*>([^<]+)<\/title>',
    caseSensitive: false,
  );

  static final RegExp _metaPropertyRegex = RegExp(
    r'''<meta\s+[^>]*(?:property|name)=["']([^"']+)["'][^>]*content=["']([^"']*)["']''',
    caseSensitive: false,
  );

  static final RegExp _metaContentFirstRegex = RegExp(
    r'''<meta\s+[^>]*content=["']([^"']*)["'][^>]*(?:property|name)=["']([^"']+)["']''',
    caseSensitive: false,
  );

  static final RegExp _linkImageSrcRegex = RegExp(
    r'''<link\s+[^>]*rel=["']image_src["'][^>]*href=["']([^"']+)["']''',
    caseSensitive: false,
  );

  /// Extract metadata for a given URL.
  /// Handles YouTube official oEmbed and generic HTML OpenGraph scraping.
  static Future<UrlMetadata?> fetchMetadata(String rawUrl) async {
    final cleanUrl = rawUrl.trim();
    if (cleanUrl.isEmpty || !cleanUrl.startsWith('http')) {
      return null;
    }

    // 1. YouTube specialized fast oEmbed extraction
    final ytMatch = Bookmark.ytVideoIdRegex.firstMatch(cleanUrl);
    if (ytMatch != null) {
      final videoId = ytMatch.group(1);
      final fallbackThumbnail =
          videoId != null ? 'https://img.youtube.com/vi/$videoId/hqdefault.jpg' : null;

      try {
        final oembedUri = Uri.parse(
          'https://www.youtube.com/oembed?url=${Uri.encodeComponent(cleanUrl)}&format=json',
        );
        final response = await http
            .get(oembedUri)
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
          final ytTitle = data['title'] as String?;
          final ytAuthor = data['author_name'] as String?;
          final ytThumb = data['thumbnail_url'] as String? ?? fallbackThumbnail;

          return UrlMetadata(
            title: ytTitle?.trim(),
            description: ytAuthor != null ? 'Channel: $ytAuthor' : null,
            imageUrl: ytThumb,
            siteName: 'YouTube',
          );
        }
      } catch (e) {
        debugPrint('YouTube oEmbed lookup notice: $e');
      }

      // If network fails or timeout, return fallback YouTube thumbnail
      return UrlMetadata(
        imageUrl: fallbackThumbnail,
        siteName: 'YouTube',
      );
    }

    // 2. Twitter / X specialized oEmbed extraction
    if (cleanUrl.contains('twitter.com') || cleanUrl.contains('x.com')) {
      try {
        final publishUri = Uri.parse(
          'https://publish.twitter.com/oembed?url=${Uri.encodeComponent(cleanUrl)}&omit_script=true',
        );
        final response = await http
            .get(publishUri)
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
          final authorName = data['author_name'] as String?;
          final html = data['html'] as String? ?? '';
          final pMatch = RegExp(r'<p[^>]*>(.*?)<\/p>', caseSensitive: false).firstMatch(html);
          String? tweetText;
          if (pMatch != null) {
            tweetText = _decodeHtmlEntities(
              pMatch.group(1)?.replaceAll(RegExp(r'<[^>]*>'), '') ?? '',
            );
          }

          return UrlMetadata(
            title: authorName != null ? 'Post by $authorName' : 'Post on X',
            description: tweetText,
            siteName: 'Twitter/X',
          );
        }
      } catch (e) {
        debugPrint('Twitter oEmbed lookup notice: $e');
      }
    }

    // 3. Generic Webpage Scraping (OpenGraph / Twitter Card / HTML Title)
    try {
      final uri = Uri.parse(cleanUrl);
      final response = await http.get(
        uri,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode < 200 || response.statusCode >= 400) {
        return null;
      }

      // Limit parsing to the first 120KB of HTML to save memory & CPU
      String html = response.body;
      if (html.length > 120000) {
        html = html.substring(0, 120000);
      }

      final metaTags = <String, String>{};

      // Extract <meta property="..." content="...">
      for (final match in _metaPropertyRegex.allMatches(html)) {
        final key = match.group(1)?.toLowerCase().trim();
        final value = match.group(2)?.trim();
        if (key != null && value != null && value.isNotEmpty) {
          metaTags[key] = _decodeHtmlEntities(value);
        }
      }

      // Extract <meta content="..." property="...">
      for (final match in _metaContentFirstRegex.allMatches(html)) {
        final value = match.group(1)?.trim();
        final key = match.group(2)?.toLowerCase().trim();
        if (key != null && value != null && value.isNotEmpty) {
          metaTags.putIfAbsent(key, () => _decodeHtmlEntities(value));
        }
      }

      // Title resolution
      String? title = metaTags['og:title'] ??
          metaTags['twitter:title'] ??
          metaTags['title'];

      if (title == null || title.isEmpty) {
        final titleMatch = _titleTagRegex.firstMatch(html);
        if (titleMatch != null) {
          title = _decodeHtmlEntities(titleMatch.group(1)?.trim() ?? '');
        }
      }

      // Image resolution
      String? image = metaTags['og:image'] ??
          metaTags['og:image:url'] ??
          metaTags['twitter:image'] ??
          metaTags['twitter:image:src'];

      if (image == null || image.isEmpty) {
        final linkMatch = _linkImageSrcRegex.firstMatch(html);
        if (linkMatch != null) {
          image = linkMatch.group(1)?.trim();
        }
      }

      // Resolve relative image URLs against the base URL
      if (image != null && image.isNotEmpty) {
        try {
          final parsedImageUri = Uri.parse(image);
          if (!parsedImageUri.hasScheme) {
            image = uri.resolve(image).toString();
          }
        } catch (_) {}
      }

      // Description resolution
      final description = metaTags['og:description'] ??
          metaTags['description'] ??
          metaTags['twitter:description'];

      final siteName = metaTags['og:site_name'];

      return UrlMetadata(
        title: title?.trim(),
        description: description?.trim(),
        imageUrl: image?.trim(),
        siteName: siteName?.trim(),
      );
    } catch (e) {
      debugPrint('UrlMetadataService failed to fetch metadata for $cleanUrl: $e');
      return null;
    }
  }

  /// Clean HTML entities commonly returned in webpage meta tags.
  static String _decodeHtmlEntities(String text) {
    var result = text
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&ndash;', '–')
        .replaceAll('&mdash;', '—')
        .replaceAll('&copy;', '©')
        .replaceAll('&reg;', '®')
        .replaceAll('&#x27;', "'")
        .replaceAll('&#x2F;', '/');

    // Decode decimal entities like &#8220;
    result = result.replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
      final code = int.tryParse(match.group(1) ?? '');
      if (code != null) {
        return String.fromCharCode(code);
      }
      return match.group(0) ?? '';
    });

    // Clean multiple whitespace / newlines
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();

    return result;
  }
}
