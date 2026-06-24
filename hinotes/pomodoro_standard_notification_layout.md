# Pomodoro Standard Style Notification Layout

**Date**: June 24, 2026  
**Discussion Topic**: Replacing the native Android Quick Settings Media Control Panel notification layout with a standard-style notification card.  
**User Decision**: Selected the standard notification layout with bottom text actions, as depicted in the new screenshot.

---

## 1. Context & Layout Choice
To match the user's screenshot, the Pomodoro active session background notification was reverted from the Media Player style (`MediaStyleInformation`) to a **Standard Android Notification** layout.

The benefits and characteristics of this standard layout include:
* **Header Chronometer**: The ticking countdown timer is displayed directly in the notification header next to the app name (e.g., `LOG • 44:23`).
* **Title Format**: The main title clearly identifies the activity and the exact time it was initiated (e.g., `Focusing: Gym (5:20 AM)`).
* **Body Text**: A clear placeholder body reading `Session is running in the background.`.
* **Action Buttons**: Standard horizontal text buttons (e.g. `Pause` and `Cancel` or `Resume` and `Cancel`) aligned at the bottom of the notification card instead of circular buttons on the right.

---

## 2. Technical Implementation Details

The changes span the active session countdown in the timer screen and the resume/pause hooks inside the background isolate handler.

### A. Code Modification Highlights
* **Style Information**: Removed `styleInformation: const MediaStyleInformation(),` from the `AndroidNotificationDetails` constructor.
* **Notification Payload**:
  * **Title**: `Focusing: [Activity Name] ([Start Time])` (Active/Resumed) or `Paused: [Activity Name] ([Start Time])` (Paused).
  * **Body**: `Session is running in the background.` (Active/Resumed) or `[MM]:[SS] remaining` (Paused).
* **Start Time Tracing**:
  * Set `_startTime = DateTime.now();` when focus begins in `_beginFocus()`.
  * Persisted `startTimestamp` to the cached session in `_saveSessionToCache()`.
  * Restored `_startTime` from cache in `initState()` when resuming an active session. If not found in cache, it calculates a mathematical fallback based on the elapsed duration: `DateTime.now().subtract(Duration(seconds: totalSeconds - secondsRemaining))`.
  * Formatted using `DateFormat.jm()` from the `intl` package.

---

## 3. Verification & Build
* Replaced the layouts in both [pomodoro_timer_screen.dart](file:///c:/Users/hipradeep/Documents/android_apps/log_app/log_app_firebase/lib/screens/pomodoro_timer_screen.dart) and [notification_service.dart](file:///c:/Users/hipradeep/Documents/android_apps/log_app/log_app_firebase/lib/services/notification_service.dart).
* Verified syntax and types via `flutter analyze`.
