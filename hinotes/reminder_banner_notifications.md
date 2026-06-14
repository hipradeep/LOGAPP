# Reminder Banner Notifications & Exact Alarm Scheduling

This document summarizes the discussion and technical design for implementing banner notifications for scheduled reminders and the daily note reminder in the LOG application.

---

## 1. Core Goal
Deliver standard system banner notifications (local push alerts) at the exact minute specified by the user's scheduled reminders (e.g., a task at **10:00 PM**), ensuring high precision even when the device is idle or in low-power mode.

---

## 2. Notification Delivery Mechanism: Banner vs. Alarm Clock
A critical design distinction exists between a standard reminder notification and an alarm clock:

* **Notification Banner (Selected)**: Shows a standard system pop-up banner, plays a single alert sound, vibrates, and leaves a persistent card in the notification shade until tapped or dismissed. This is the optimal, standard user experience for task reminders.
* **Alarm Clock (Continuous Ringing)**: Continually rings until the user manually triggers a full-screen action to dismiss or snooze. This is typically reserved for wake-up alarms.

---

## 3. Scheduling & Next-Occurrence Logic
To schedule a reminder (e.g., `"10:00 PM"`):
1. **Parsing**: The time string (e.g. `"10:00 PM"`) is parsed into hours (`22`) and minutes (`0`).
2. **Comparison**:
   - Compare the target time against the current time in the user's local timezone.
   - **Scenario A (Future)**: Current time is `04:55 AM`. The target 10:00 PM is in the future. The app schedules the alarm for **10:00 PM today**.
   - **Scenario B (Past)**: Current time is `11:00 PM`. The target 10:00 PM has already passed. The app schedules the alarm for **10:00 PM tomorrow**.
3. **Weekly Repeat**: If a reminder repeats on certain days, it schedules the next occurrence for the upcoming day in the schedule.

---

## 4. Android Exact Alarm Requirements
Android restricts background tasks and alarms to save battery (Doze Mode). To ensure reminders trigger exactly on time, the following integration is required:

### Android Manifest Permissions
We must declare the permission to schedule exact alarms:
```xml
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
```

### Flutter Scheduling Configuration
In the Flutter codebase (using `flutter_local_notifications`), scheduled alarms must use:
* **Mode**: `AndroidScheduleMode.exactAllowWhileIdle` (forces the OS to wake up and show the notification immediately at the designated time, even in low-power states).
* **Time Interpretation**: `UILocalNotificationDateInterpretation.absoluteTime` using local time zones via the `timezone` package.
* **Notification Channel**: A dedicated channel with `Importance.max` and `Priority.high` to ensure the banner pops up on top of the current screen.
