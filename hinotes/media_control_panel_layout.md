# Pomodoro Media Control Panel Notification Layout

**Date**: June 24, 2026  
**Discussion Topic**: Choosing and implementing the native Android Quick Settings Media Control Panel notification layout for active Pomodoro focus sessions.  
**User Decision**: Confirmed that the Media Control Panel format (the format shown in the second screenshot) is the desired and required layout for active timer notifications.

---

## 1. Context & Layout Choice
Active Pomodoro sessions need high visibility and standard native media controls. Android 13+ (and custom skins like Oppo's ColorOS/OnePlus's OxygenOS running on the test device `CPH2569`) render media-style notifications in a dedicated **Quick Settings Media Control Panel** above the standard notification list. 

The user selected the **Media Control Panel Format** because:
* It places a high-fidelity ticking countdown timer directly in the main title area of the media widget.
* It uses native media styling, including a clean background gradient based on the app icon, a progress bar, and play/pause/cancel actions on the side.
* It provides a premium system-integrated feel instead of standard generic notifications.

---

## 2. Technical Implementation details

To force the Android OS to render the notification as a Media Player in the Media Control Panel, the following configuration is used:

### A. Notification Properties (Active Session)
* **Style**: `MediaStyleInformation()` from `flutter_local_notifications`.
* **Title Configuration**: Kept as `null` during active countdown.
  > [!IMPORTANT]
  > When `title` is `null` and `usesChronometer` is `true`, the Android system automatically binds the running ticking chronometer (`chronometerCountDown: true`) into the Media Control Panel's large title slot. If a text title is provided, the ticking countdown is lost.
* **Content Text**: The name of the active activity (e.g., "Plank", "Deep Work") is passed into the body parameter, displaying it as the subtitle.
* **When**: Set to `endTimestamp` (target completion time) so the ticking chronometer correctly counts down to zero.

### B. Notification Properties (Paused Session)
* **Style**: Remains `MediaStyleInformation()` to preserve the Media Control Panel layout position.
* **Title Configuration**: Changed to `'Paused: [Activity Name]'`.
  > [!NOTE]
  > When paused, the chronometer is disabled (`usesChronometer: false`). Since we no longer count down, we explicitly update the title string to show the pause state and avoid a blank header.
* **Content Text**: Updated to `'[MM]:[SS] remaining'` showing the static paused remaining time in the card body.

### C. Native Vector Asset Customization
Custom vector drawables are compiled inside the Android resources (`/android/app/src/main/res/drawable/`) to render circular cutout actions:
* `ic_pause.xml`: Solid filled circle with a transparent dual-bar pause symbol cutout.
* `ic_play.xml`: Solid filled circle with a transparent triangle play symbol cutout.
* `ic_cancel.xml`: Solid filled circle with a transparent "X" symbol cutout.

---

## 3. Discussion Summary & Confirmation
During our alignment, the user explicitly confirmed that the Media Control Panel layout (the second screenshot style) is the correct design behavior. The code has been configured to respect this layout flow:
1. When starting/resuming a focus session, the active notification displays the ticking chronometer natively in the media slot.
2. Actions are bound to `pause_pomodoro`, `resume_pomodoro`, and `cancel_pomodoro` native hooks.
3. Tapping the main body of the media panel triggers `open_pomodoro` which uses the global `navigatorKey` to resume the screen gracefully in the foreground.
