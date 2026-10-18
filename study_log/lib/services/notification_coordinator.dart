import 'package:timezone/timezone.dart' as tz;
import '../models/course.dart';
import '../models/notification_payload.dart';
import '../models/notification_settings.dart';
import '../models/revision_module.dart';
import '../models/topic_revision.dart';

/// Represents a single planned notification alert after coordinator filtering and anti-collision checks.
class CoordinatedNotification {
  final int id;
  final String title;
  final String body;
  final tz.TZDateTime scheduledTime;
  final String channelId;
  final NotificationPayload payload;

  const CoordinatedNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledTime,
    required this.channelId,
    required this.payload,
  });
}

/// Anti-collision coordinator that evaluates all app events in a single pass
/// and computes at most 1 consolidated notification per time window.
class NotificationCoordinator {
  /// Minimum spacing in minutes between any two scheduled notification alerts.
  static const int minGapMinutes = 150; // 2.5 hours

  /// Channel identifiers
  static const String courseChannelId = 'study_course_channel';
  static const String streakChannelId = 'study_streak_channel';
  static const String revisionChannelId = 'study_revision_channel';
  static const String deadlineChannelId = 'study_deadline_channel';

  /// Notification IDs
  static const int morningBriefingId = 1000;
  static const int studyCourseReminderId = 1001;
  static const int streakSaverId = 1002;
  static const int middayBoostId = 1003;
  static const int lastCallId = 1004;
  static const int deadlineBaseId = 4000;

  /// Builds the consolidated daily plan for today, enforcing the 4-tier model,
  /// 2.5-hour anti-collision spacing, quiet hours, and auto-cancellation rules.
  static List<CoordinatedNotification> buildDailyPlan({
    required tz.TZDateTime now,
    required List<TopicRevision> dueTopics,
    required List<RevisionModule> dueModules,
    required List<Course> deadlineCourses,
    required bool hasStudiedToday,
    required int currentStreak,
    required NotificationSettings settings,
  }) {
    if (!settings.enabled) return const [];

    final candidates = <CoordinatedNotification>[];

    // ─────────────────────────────────────────────────────────────────────────
    // TIER 1: Morning Daily Briefing (Default 08:00 AM or settings)
    // ─────────────────────────────────────────────────────────────────────────
    final morningHour = settings.morningBriefingTime.hour;
    final morningMinute = settings.morningBriefingTime.minute;
    final morningTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      morningHour < 4 ? 4 : morningHour,
      morningMinute,
    );

    if (settings.morningBriefingEnabled && morningTime.isAfter(now)) {
      final totalDue = dueTopics.length + dueModules.length;
      String title = 'Morning Briefing ☀️';
      String body;
      NotificationPayload payload = NotificationPayload.morningBriefing();

      if (totalDue > 0 && deadlineCourses.isNotEmpty) {
        title = "Today's Priorities 📌";
        body = 'Revise $totalDue item(s) • "${deadlineCourses.first.title}" deadline today!';
      } else if (totalDue > 0) {
        if (dueTopics.isNotEmpty && dueModules.isNotEmpty) {
          body = '${dueTopics.length} topic(s) and ${dueModules.length} module(s) due for revision today.';
        } else if (dueTopics.isNotEmpty) {
          body = '${dueTopics.length} topic revision(s) due today. Ready to review?';
        } else {
          body = '${dueModules.length} module revision(s) due today. Keep your memory sharp!';
        }
      } else if (deadlineCourses.isNotEmpty) {
        title = 'Deadline Today ⚠️';
        body = 'Target deadline for "${deadlineCourses.first.title}" is today!';
        payload = NotificationPayload.courseDeadline(courseId: deadlineCourses.first.id);
      } else {
        body = currentStreak > 0
            ? 'Keep your $currentStreak-day streak alive! Ready for your next study session?'
            : 'Start strong today! Complete a quick topic to build your study habit.';
      }

      candidates.add(CoordinatedNotification(
        id: morningBriefingId,
        title: title,
        body: body,
        scheduledTime: morningTime,
        channelId: courseChannelId,
        payload: payload,
      ));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TIER 2: Midday Focus Boost (Default 02:00 PM / 14:00)
    // ─────────────────────────────────────────────────────────────────────────
    final middayTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      14, // 2:00 PM
      0,
    );

    final totalRevisionsDue = dueTopics.length + dueModules.length;
    if (settings.revisionDueEnabled &&
        !hasStudiedToday &&
        totalRevisionsDue > 0 &&
        middayTime.isAfter(now)) {
      final topTopic = dueTopics.isNotEmpty ? dueTopics.first : null;
      final itemTitle = topTopic?.title ?? 'revision';

      candidates.add(CoordinatedNotification(
        id: middayBoostId,
        title: 'Quick 15-Min Revision ⏱️',
        body: 'Review "$itemTitle" to lock in your spaced repetition memory.',
        scheduledTime: middayTime,
        channelId: revisionChannelId,
        payload: topTopic != null
            ? NotificationPayload.middayBoost(
                topicId: topTopic.topicId,
                courseId: topTopic.courseId,
              )
            : NotificationPayload.morningBriefing(subTabIndex: 1),
      ));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TIER 3: Evening Streak Saver (Default 08:00 PM / 20:00 or settings)
    // ─────────────────────────────────────────────────────────────────────────
    final streakHour = settings.streakSaverTime.hour;
    final streakMinute = settings.streakSaverTime.minute;
    final streakTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      streakHour < 4 ? 20 : streakHour,
      streakMinute,
    );

    if (settings.streakSaverEnabled && !hasStudiedToday && streakTime.isAfter(now)) {
      final String title;
      final String body;

      if (currentStreak >= 7) {
        title = 'Protect Your Streak Tonight! 🔥';
        body = "🔥 Don't lose your $currentStreak-day streak! Just 1 quick topic before midnight.";
      } else if (currentStreak >= 1) {
        title = 'Keep Your Momentum Going! 🔥';
        body = "Keep the momentum going! 🔥 Log today's study to extend your $currentStreak-day streak.";
      } else {
        title = 'Build Your Study Habit! 🔥';
        body = "Build a new study habit! Start Day 1 of your streak tonight.";
      }

      candidates.add(CoordinatedNotification(
        id: streakSaverId,
        title: title,
        body: body,
        scheduledTime: streakTime,
        channelId: streakChannelId,
        payload: NotificationPayload.streakSaver(),
      ));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TIER 4: Night Last Call (10:00 PM / 22:00)
    // ─────────────────────────────────────────────────────────────────────────
    final lastCallTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      22, // 10:00 PM
      0,
    );

    if (settings.streakSaverEnabled &&
        !hasStudiedToday &&
        currentStreak >= 3 &&
        lastCallTime.isAfter(now)) {
      candidates.add(CoordinatedNotification(
        id: lastCallId,
        title: 'Last Call for Your Streak! ⏳',
        body: 'Your $currentStreak-day streak will reset at midnight! Complete a quick session now.',
        scheduledTime: lastCallTime,
        channelId: streakChannelId,
        payload: NotificationPayload.lastCall(),
      ));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Standalone Deadline Alert (if not already consolidated in morning briefing)
    // ─────────────────────────────────────────────────────────────────────────
    if (settings.deadlineEnabled && deadlineCourses.isNotEmpty) {
      final deadlineTime = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        11, // 11:00 AM
        0,
      );
      if (deadlineTime.isAfter(now)) {
        candidates.add(CoordinatedNotification(
          id: deadlineBaseId,
          title: 'Deadline Today! ⚠️',
          body: 'Target deadline for "${deadlineCourses.first.title}" is today. Stay focused and finish on time!',
          scheduledTime: deadlineTime,
          channelId: deadlineChannelId,
          payload: NotificationPayload.courseDeadline(courseId: deadlineCourses.first.id),
        ));
      }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ANTI-COLLISION & GAP ENFORCEMENT
    // ─────────────────────────────────────────────────────────────────────────
    // Sort chronologically
    candidates.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

    final filtered = <CoordinatedNotification>[];
    for (final candidate in candidates) {
      // Rule: Automatic alerts suppressed between 10:00 PM and 04:00 AM
      final hour = candidate.scheduledTime.hour;
      if (hour < 4 || (hour >= 22 && candidate.scheduledTime.minute > 0)) {
        continue;
      }

      if (filtered.isEmpty) {
        filtered.add(candidate);
        continue;
      }

      final prev = filtered.last;
      final diffMinutes =
          candidate.scheduledTime.difference(prev.scheduledTime).inMinutes;

      if (diffMinutes < minGapMinutes) {
        // Less than 2.5 hours gap! Consolidate with previous if high value, or skip secondary
        if (candidate.id == deadlineBaseId && prev.id == morningBriefingId) {
          // Already consolidated into morning briefing
          continue;
        }
        // If there's an existing alert too close, skip the lower-priority candidate
        continue;
      }

      filtered.add(candidate);
    }

    return filtered;
  }
}
