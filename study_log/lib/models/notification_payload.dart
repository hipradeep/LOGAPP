import 'dart:convert';

/// Structured payload model attached to local notification alerts for deep linking and action routing.
class NotificationPayload {
  /// Navigation action type: 'open_tab', 'open_timer', 'open_home', 'open_course', etc.
  final String action;

  /// Root tab index (0: Home, 1: Revision, 2: Profile).
  final int? tabIndex;

  /// Sub-tab filter index if applicable (e.g., 0: All, 1: Topics, 2: Modules).
  final int? subTabIndex;

  /// Target entity identifier (topic ID, module ID, or revision ID).
  final String? targetId;

  /// Associated course identifier.
  final String? courseId;

  /// Associated topic identifier.
  final String? topicId;

  /// Associated module identifier.
  final String? moduleId;

  const NotificationPayload({
    required this.action,
    this.tabIndex,
    this.subTabIndex,
    this.targetId,
    this.courseId,
    this.topicId,
    this.moduleId,
  });

  /// Factory for Morning Briefing -> Revision Tab.
  factory NotificationPayload.morningBriefing({int subTabIndex = 0}) =>
      NotificationPayload(
        action: 'open_tab',
        tabIndex: 1,
        subTabIndex: subTabIndex,
      );

  /// Factory for Midday Focus Boost -> Topic Timer or Topic Revision.
  factory NotificationPayload.middayBoost({
    required String topicId,
    String? courseId,
  }) =>
      NotificationPayload(
        action: 'open_timer',
        topicId: topicId,
        targetId: topicId,
        courseId: courseId,
      );

  /// Factory for Evening Streak Saver -> Home Screen.
  factory NotificationPayload.streakSaver() => const NotificationPayload(
        action: 'open_home',
        tabIndex: 0,
      );

  /// Factory for Last Call -> Home Screen.
  factory NotificationPayload.lastCall() => const NotificationPayload(
        action: 'open_home',
        tabIndex: 0,
      );

  /// Factory for Course Deadline -> Course Detail.
  factory NotificationPayload.courseDeadline({required String courseId}) =>
      NotificationPayload(
        action: 'open_course',
        courseId: courseId,
        targetId: courseId,
      );

  /// Factory for Saved Bookmark -> Bookmarks Screen.
  factory NotificationPayload.bookmarkSaved({String? bookmarkId}) =>
      NotificationPayload(
        action: 'open_bookmarks',
        targetId: bookmarkId,
      );

  /// Factory for Active Session Notification -> Resume Timer Screen.
  factory NotificationPayload.activeSession({String? targetId}) =>
      NotificationPayload(
        action: 'open_session',
        targetId: targetId,
      );

  Map<String, dynamic> toMap() {
    return {
      'action': action,
      if (tabIndex != null) 'tabIndex': tabIndex,
      if (subTabIndex != null) 'subTabIndex': subTabIndex,
      if (targetId != null) 'targetId': targetId,
      if (courseId != null) 'courseId': courseId,
      if (topicId != null) 'topicId': topicId,
      if (moduleId != null) 'moduleId': moduleId,
    };
  }

  String toJson() => jsonEncode(toMap());

  static NotificationPayload? fromJson(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return NotificationPayload(
        action: map['action'] as String? ?? 'open_home',
        tabIndex: (map['tabIndex'] as num?)?.toInt(),
        subTabIndex: (map['subTabIndex'] as num?)?.toInt(),
        targetId: map['targetId'] as String?,
        courseId: map['courseId'] as String?,
        topicId: map['topicId'] as String?,
        moduleId: map['moduleId'] as String?,
      );
    } catch (_) {
      // Backward compatibility for raw string payloads (e.g. 'course_due_daily')
      if (raw.contains('revision')) {
        return const NotificationPayload(action: 'open_tab', tabIndex: 1);
      }
      return const NotificationPayload(action: 'open_home', tabIndex: 0);
    }
  }
}
