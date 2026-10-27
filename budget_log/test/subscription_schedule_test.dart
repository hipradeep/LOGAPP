import 'dart:convert';

import 'package:budget_log/models/subscription.dart';
import 'package:budget_log/services/subscription_reminder_planner.dart';
import 'package:budget_log/utils/subscription_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Subscription createSubscription({
    String id = 'sub_1',
    DateTime? dueDate,
    String frequency = 'monthly',
    bool isActive = true,
  }) {
    return Subscription(
      id: id,
      name: 'Music',
      amount: 199,
      frequency: frequency,
      nextDueDate: dueDate ?? DateTime(2026, 10, 30),
      isActive: isActive,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  group('nextDueDate', () {
    test('keeps end-of-month dates clamped', () {
      expect(
        SubscriptionSchedule.nextDueDate(DateTime(2026, 1, 31), 'monthly'),
        DateTime(2026, 2, 28),
      );
      expect(
        SubscriptionSchedule.nextDueDate(DateTime(2024, 1, 31), 'monthly'),
        DateTime(2024, 2, 29),
      );
      expect(
        SubscriptionSchedule.nextDueDate(DateTime(2024, 2, 29), 'monthly'),
        DateTime(2024, 3, 31),
      );
    });

    test('handles weekly, quarterly and yearly schedules', () {
      expect(
        SubscriptionSchedule.nextDueDate(DateTime(2026, 10, 27), 'weekly'),
        DateTime(2026, 11, 3),
      );
      expect(
        SubscriptionSchedule.nextDueDate(DateTime(2026, 11, 30), 'quarterly'),
        DateTime(2027, 2, 28),
      );
      expect(
        SubscriptionSchedule.nextDueDate(DateTime(2024, 2, 29), 'yearly'),
        DateTime(2025, 2, 28),
      );
    });
  });

  group('dueLabel', () {
    final now = DateTime(2026, 10, 27, 12);

    test('describes overdue and upcoming days', () {
      expect(
        SubscriptionSchedule.dueLabel(DateTime(2026, 10, 25), now: now),
        'Overdue by 2 days',
      );
      expect(
        SubscriptionSchedule.dueLabel(DateTime(2026, 10, 27), now: now),
        'Due today',
      );
      expect(
        SubscriptionSchedule.dueLabel(DateTime(2026, 10, 28), now: now),
        'Due tomorrow',
      );
      expect(
        SubscriptionSchedule.dueLabel(DateTime(2026, 10, 30), now: now),
        'Due in 3 days',
      );
      expect(
        SubscriptionSchedule.dueLabel(DateTime(2026, 11, 20), now: now),
        'Due 20 Nov',
      );
    });
  });

  group('SubscriptionReminderPlanner', () {
    test('plans reminders at 9 AM for D-3, D-1 and the due date', () {
      final reminders = SubscriptionReminderPlanner.plan(
        subscription: createSubscription(),
        now: DateTime(2026, 10, 27, 8),
      );

      expect(reminders, hasLength(3));
      expect(reminders.map((item) => item.scheduledAt).toList(), [
        DateTime(2026, 10, 27, 9),
        DateTime(2026, 10, 29, 9),
        DateTime(2026, 10, 30, 9),
      ]);
      expect(reminders.map((item) => item.title).toList(), [
        'Bill due in 3 days',
        'Bill due tomorrow',
        'Bill due today',
      ]);

      final baseId = SubscriptionReminderPlanner.notificationBaseId('sub_1');
      expect(reminders.map((item) => item.id).toList(), [
        baseId,
        baseId + 1,
        baseId + 2,
      ]);
    });

    test('skips reminders whose time has already passed', () {
      final reminders = SubscriptionReminderPlanner.plan(
        subscription: createSubscription(),
        now: DateTime(2026, 10, 28, 10),
      );

      expect(reminders, hasLength(2));
      expect(reminders.first.offsetDays, 1);
      expect(reminders.first.scheduledAt, DateTime(2026, 10, 29, 9));
    });

    test('does not plan reminders for paused subscriptions', () {
      final reminders = SubscriptionReminderPlanner.plan(
        subscription: createSubscription(isActive: false),
        now: DateTime(2026, 10, 27, 8),
      );

      expect(reminders, isEmpty);
    });

    test('encodes a stable subscription payload', () {
      final subscription = createSubscription();
      final reminders = SubscriptionReminderPlanner.plan(
        subscription: subscription,
        now: DateTime(2026, 10, 27, 8),
      );
      final payload = jsonDecode(reminders.first.payload) as Map;

      expect(payload['type'], 'subscription');
      expect(payload['subscriptionId'], 'sub_1');
      expect(payload['dueDate'], DateTime(2026, 10, 30).millisecondsSinceEpoch);
      expect(
        SubscriptionReminderPlanner.notificationBaseId('sub_1'),
        SubscriptionReminderPlanner.notificationBaseId('sub_1'),
      );
      expect(
        SubscriptionReminderPlanner.notificationBaseId('sub_1'),
        isNot(SubscriptionReminderPlanner.notificationBaseId('sub_2')),
      );
    });
  });
}
