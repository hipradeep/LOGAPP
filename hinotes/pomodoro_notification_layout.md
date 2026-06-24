# Pomodoro Active Timer Notification Layouts & Rendering

This document summarizes the behavior and rendering characteristics of the native Android `MediaStyle` notification drawer for active Pomodoro focus sessions.

## 1. Notification Presentation Styles

On modern Android devices (specifically Android 13+ and custom skins like ColorOS/OxygenOS), active media notifications can render in two distinct locations:

### A. Quick Settings Media Control Panel (Media Player View)
* **Visuals**: Displays as a large card at the very top of the notification shade with a colored gradient background based on the app icon, a horizontal progress bar, and play/pause action buttons aligned on the right.
* **Header Ticking**: The system automatically pulls the ticking chronometer (`usesChronometer: true`, `chronometerCountDown: true`) and places it as the prominent main title in the center of the control card.
* **Layout Integrity**: Fills all card metadata positions natively, resulting in a premium, fluid media player UI.

### B. Standard Notifications List Card (Collapsed View)
* **Visuals**: Displays as a standard white/dark card in the main list of notifications. Action buttons are aligned horizontally at the bottom.
* **Blank Title Issue**: If the notification title is set to `null` to prevent overriding the chronometer's position in the Media Control Panel, the standard collapsed card leaves the main Title area empty. This results in a large blank space between the header and the activity name (body text).

---

## 2. Technical Limitations & Skin Specifics (Oppo/ColorOS)

Custom Android distributions (like Oppo's ColorOS, which runs on device `CPH2569`):
1. **Prioritization**: Actively running media sessions are prioritized and moved to the dedicated Media Control Panel at the top.
2. **Channel Settings**: Notification layouts and style bindings are handled natively by the Android system's notification listener.
3. **Inconsistency**: If the notification title is populated to fix the blank space in the standard list, the Media Control Panel will show the text title instead of the large ticking countdown, making it harder to check the timer at a glance.

---

## 3. Selected Approach

To align with the native Android standard for media and timer apps (like Google Clock):
* **Title configuration is kept as `null`** during active sessions.
* This ensures that when the notification is promoted to the **Quick Settings Media Control Panel** (the primary interaction widget), it displays the **large ticking chronometer** as the main title with the activity name below it.
* Once the session is **paused**, the chronometer is disabled, and the notification title is explicitly updated to `"Paused: [Activity Name]"` with the remaining time in the body. This prevents any blank spaces from rendering in standard notification list cards when in a inactive/paused state.
