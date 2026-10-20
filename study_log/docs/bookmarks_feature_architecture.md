# Bookmarks & Web Resource Ingestion - Architecture & Specification

**Document Version:** 1.0.0  
**Target:** Flutter / Android (`study_log`)  
**Status:** Implemented / Core Feature Specification  

---

## 1. Executive Summary & Purpose

The **Bookmarks** system enables students and learners to capture, categorize, enrich, and reference web resources (YouTube video lectures, academic papers, articles, GitHub repos, PDFs) directly within `study_log`.

Learners can share URLs from Chrome, YouTube, or any external application via Android's native share sheet directly into `study_log`, which automatically scrapes metadata (OpenGraph tags, video thumbnails, site names) in the background and indexes them for fast search and syllabus integration.

---

## 2. Core Capabilities

1. **Native Android Share Sheet Ingestion (`ACTION_SEND`)**:
   - Ingests incoming shared links seamlessly via Kotlin `MethodChannel('com.logapp.studylog/share')`.
   - Supports background sharing: links can be stored immediately with a system notification confirmation (`Saved Bookmarks` channel) or opened in `SaveBookmarkSheet`.
2. **Automated Metadata Scraping & Thumbnail Extraction**:
   - **YouTube**: Specialized zero-latency oEmbed extraction (`https://www.youtube.com/oembed`) with fallback to `img.youtube.com/vi/<id>/hqdefault.jpg`.
   - **General Web**: Background parser extracting OpenGraph image (`og:image`), Twitter card images (`twitter:image`), `<title>`, and meta description tags.
3. **Optimized Search & Tag Categorization**:
   - Debounced search query ($O(1)$ in-memory lookups) querying title, description, domain, host, and tags.
   - Dynamic platform categories sorted descending by usage frequency (YouTube, Twitter/X, GitHub, Articles, etc.).
4. **Study Syllabus & Todo Integration**:
   - One-tap conversion: "Add to TODO" turns any reference link into an actionable task inside `TodoController`.
   - Optional course/topic tagging for tying external reading materials directly to exam syllabus modules.

---

## 3. Native Android Integration

### 3.1 AndroidManifest.xml Configuration
```xml
<activity
    android:name=".MainActivity"
    ...>
    <!-- System Share Sheet Receiver -->
    <intent-filter>
        <action android:name="android.intent.action.SEND"/>
        <category android:name="android.intent.category.DEFAULT"/>
        <data android:mimeType="text/plain"/>
    </intent-filter>
</activity>
```

### 3.2 Kotlin Native MethodChannel (`MainActivity.kt`)
The platform channel `com.logapp.studylog/share` handles:
- `onSharedTextReceived`: Invoked when incoming shared plain text/URL is received while running.
- `getInitialSharedText`: Cold-start intent evaluation for links received when the app was launched from the share sheet.
- `sendToBackground`: Minimizes task back to background when quick saving without interrupting the user's primary application.

---

## 4. Database Schema & Data Models

### 4.1 SQLite Table Definition (`bookmarks`)
```sql
CREATE TABLE bookmarks (
    id TEXT PRIMARY KEY,
    url TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    host TEXT,
    imageUrl TEXT,
    tags TEXT,             -- JSON string array
    isPinned INTEGER DEFAULT 0,
    isArchived INTEGER DEFAULT 0,
    courseId TEXT,
    topicId TEXT,
    createdAt TEXT NOT NULL,
    updatedAt TEXT NOT NULL
);

CREATE INDEX idx_bookmarks_pinned_created ON bookmarks(isPinned DESC, createdAt DESC);
CREATE INDEX idx_bookmarks_course_topic ON bookmarks(courseId, topicId);
```

### 4.2 Model Structure (`Bookmark`)
- `id`: Unique identifier (microseconds timestamp).
- `url`: Validated HTTP/HTTPS web address.
- `title` / `displayTitle`: Cleaned resource title with domain fallback.
- `cleanHost`: Normalized domain name without `www.`.
- `thumbnailUrl`: High-resolution preview image with YouTube video ID thumbnail fallback.
- `platformCategory`: Deterministic categorization derived from host patterns.

---

## 5. State Management & Architecture Rules

In adherence to repository performance guidelines ([optimize_data.md](file:///c:/Users/hipradeep/Documents/android_apps/log_app/.agents/rules/optimize_data.md), [optimize_view.md](file:///c:/Users/hipradeep/Documents/android_apps/log_app/.agents/rules/optimize_view.md)):

1. **Zero Third-Party Dependencies**: Pure `ChangeNotifier` (`BookmarksController`) registered as a lazy singleton via `getIt<BookmarksController>()`.
2. **Cached Pre-Filtered Collections**: `_cachedFilteredBookmarks` and `_cachedPinnedBookmarks` are computed upon mutation, keeping `build()` $O(1)$.
3. **Surgical Widget Scopes**: `BookmarksScreen` isolates the search bar and `CustomAppBar` from dynamic rebuild boundaries, preventing full-screen re-renders during text entry.
4. **Constrained Image Decoding**: `BookmarkThumbnail` enforces memory decode bounds (`cacheWidth: 150`, `cacheHeight: 110`) preventing GPU thrashing on scroll.
5. **Static Regex Compilation**: `Bookmark.ytVideoIdRegex` is compiled once as a static class constant, eliminating regex object allocation on item render.
