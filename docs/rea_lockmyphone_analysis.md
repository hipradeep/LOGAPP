# Reverse-Engineering Comparative Analysis: Lock Apps

This document contains reverse-engineering analysis comparing the two target lock applications:
1. **App 1: Lock My Phone (Zen Mode)** (`tomka.lockmyphone`) by Thomas Kahn
2. **App 2: Zen Mode - Stay Focused** (`in.timemac.zenmode`) by TimeMac

---

## App 2: Zen Mode (`in.timemac.zenmode`) Deep Dive

### 1. Manifest & Android Security Privileges
* **Target SDK**: 37 (Android 15+ compatible), **Min SDK**: 32.
* **Permissions**:
  - `android.permission.USE_FULL_SCREEN_INTENT`: Allows pushing the lock activity to the very foreground even over calls or alarms.
  - `android.permission.BIND_DEVICE_ADMIN`: Integrates `in.timemac.zenmode.admin.DeviceAdmin` with policy settings to prevent app uninstallation during an active lock cycle.
  - `android.permission.CALL_PHONE`, `READ_PHONE_STATE`, `READ_CONTACTS`: Powers whitelist dialer and emergency calling without dropping the lock state.
  - `android.permission.SCHEDULE_EXACT_ALARM`: Alarms trigger precise lock termination.

### 2. Lock Activity Mechanics (`in.timemac.zenmode.ui.LockActivity`)
* **Task Isolation**:
  - `launchMode="singleInstance"`, `excludeFromRecents="true"`, `taskAffinity=""`
  - Prevents the user from accessing the system App Switcher / Overview screen.
* **Screen Keyguard Overrides**:
  - `showWhenLocked="true"` and `turnScreenOn="true"`: Automatically brings the lock view over Android's lock screen.
* **Navigation Traps**:
  - `onUserLeaveHint()`: Intercepts when the user presses Home or attempts to leave, immediately relaunching the `LockActivity` into the front.
  - `CountDownTimer` (`field P`): Renders the remaining focus duration in real-time.
  - `DevicePolicyManager` (`field e0`): Re-locks or disables camera/notifications if enabled by user policy.

### 3. Service Lifecycle (`in.timemac.zenmode.service.LockService`)
* Runs under `foregroundServiceType="specialUse"` with `directBootAware="true"`.
* Paired with `BootReceiver` listening to `BOOT_COMPLETED`, `LOCKED_BOOT_COMPLETED`, `TIME_SET`, and `TIMEZONE_CHANGED` to detect any clock manipulation attempts.

---

## Architectural Comparison Matrix

| Feature | App 1: Lock My Phone (`tomka.lockmyphone`) | App 2: Zen Mode (`in.timemac.zenmode`) | `study_log` Implementation |
|---|---|---|---|
| **Locking Technique** | Floating Overlay Window (`SYSTEM_ALERT_WINDOW`) + Device Admin (`lockNow`) | Dedicated Foreground Kiosk Activity (`singleInstance`, `showWhenLocked`, `onUserLeaveHint`) | Immersive Flutter Kiosk Overlay (`SystemUiMode.immersiveSticky`, `PopScope`) |
| **Emergency Calls** | Simple `tel:` dialer intent launch | Built-in Whitelist Dialer (`CALL_PHONE`, `READ_CONTACTS`) | Direct emergency action button (`tel:112`) |
| **Grace Period** | Confirmation dialog before lock | 10s countdown delay timer | Configurable 0s, 5s, 10s, 15s, 30s cancellation window |
| **Tamper Resistance** | `USER_PRESENT` broadcast receiver (priority 9999) | `TIME_SET` & `TIMEZONE_CHANGED` receiver + Boot receiver | Elapsed monotonic stopwatch verification |
| **Dev / Testing Safe Exit** | No (Strict) | No (Strict) | **Exit (Testing)** button with safety confirmation |

