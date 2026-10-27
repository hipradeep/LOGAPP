import 'dart:convert';

import '../models/subscription.dart';
import '../utils/format_utils.dart';
import '../utils/subscription_schedule.dart';

class SubscriptionReminder {
  final int id;
  final Subscription subscription;
  final int offsetDays;
  final DateTime scheduledAt;
  final String title;
  final String body;
  final String payload;

  const SubscriptionReminder({
    required this.id,
    required this.subscription,
    required this.offsetDays,
    required this.scheduledAt,
    required this.title,
    required this.body,
    required this.payload,
  });
}

class SubscriptionReminderPlanner {
  SubscriptionReminderPlanner._();

  static const int reminderHour = 9;
  static const int reminderMinute = 0;
  static const List<int> reminderOffsets = [3, 1, 0];

  static List<SubscriptionReminder> plan({
    required Subscription subscription,
    DateTime? now,
  }) {
    if (!subscription.isActive) return const [];
    final current = now ?? DateTime.now();
    final dueDate = SubscriptionSchedule.startOfDay(subscription.nextDueDate);
    final reminders = <SubscriptionReminder>[];
    final baseId = notificationBaseId(subscription.id);

    for (var index = 0; index < reminderOffsets.length; index++) {
      final offset = reminderOffsets[index];
      final scheduledAt = DateTime(
        dueDate.year,
        dueDate.month,
        dueDate.day - offset,
        reminderHour,
        reminderMinute,
      );
      if (!scheduledAt.isAfter(current)) continue;

      reminders.add(
        SubscriptionReminder(
          id: baseId + index,
          subscription: subscription,
          offsetDays: offset,
          scheduledAt: scheduledAt,
          title: _titleForOffset(offset),
          body:
              '${subscription.name} · '
              '${AppFormat.currency(subscription.amount)} · '
              '${AppFormat.shortDate(dueDate)}',
          payload: payloadFor(subscription),
        ),
      );
    }
    return reminders;
  }

  static String payloadFor(Subscription subscription) {
    return jsonEncode({
      'type': 'subscription',
      'subscriptionId': subscription.id,
      'dueDate': SubscriptionSchedule.startOfDay(
        subscription.nextDueDate,
      ).millisecondsSinceEpoch,
    });
  }

  static int notificationBaseId(String subscriptionId) {
    var hash = 0x811c9dc5;
    for (final unit in utf8.encode(subscriptionId)) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return 100000 + (hash % 900000000);
  }

  static String _titleForOffset(int offset) {
    return switch (offset) {
      3 => 'Bill due in 3 days',
      1 => 'Bill due tomorrow',
      0 => 'Bill due today',
      _ => 'Bill reminder',
    };
  }
}
