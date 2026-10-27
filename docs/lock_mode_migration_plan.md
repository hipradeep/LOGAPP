# Architecture Plan: Transition from Restrict Mode to Secure Lock Mode

## 1. Executive Summary & Objective
Replace the existing legacy **"Restrict Mode"** toggle with a unified, professional **"Lock Mode"** (Zen Mode) in `study_log`.
The goal is to ensure a secure, tamper-resistant focus experience while providing a professional, controlled, and safe exit mechanism with proper preconditions, permission workflows, and zero UI clutter.

---

## 2. Preconditions & Required Permissions Matrix

| Level / Feature | System Mechanism | Permission Required | UX & Security Precondition |
|---|---|---|---|
| **Level 1: Native App Pinning (Kiosk)** | `Activity.startLockTask()` | None (User-level standard Android API) | Must be called when the activity is in foreground. |
| **Level 2: Screen Wake & Keyguard Override** | `setShowWhenLocked(true)`, `setTurnScreenOn(true)` | None (Android O_MR1+) | Keeps timer top-most over standard lock screen. |
| **Level 3: Keep Display Awake** | `WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON` | `android.permission.WAKE_LOCK` (Already in manifest) | Optional toggle in Lock Mode settings. |
| **Level 4: Strict Anti-Uninstall / Hardware Screen Lock** | `DevicePolicyManager.lockNow()` | `android.permission.BIND_DEVICE_ADMIN` | Must request user to enable Device Admin via system dialog. |
| **Level 5: System Alert Window (Overlay)** | `WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY` | `android.permission.SYSTEM_ALERT_WINDOW` | Optional floating timer/overlay if leaving app. |

---

## 3. Professional & Secure Exit Architecture

To ensure discipline without trapping the user irreversibly or leaving accidental security vulnerabilities:

```
                  ┌──────────────────────────────────────────┐
                  │          Focus Session in Lock Mode       │
                  └─────────────────────┬────────────────────┘
                                        │ User attempts to Exit
                                        ▼
                  ┌──────────────────────────────────────────┐
                  │    Is within Grace Period (e.g., 10s)?    │
                  └───────┬──────────────────────────┬───────┘
                     YES  │                          │  NO
                          ▼                          ▼
               ┌─────────────────────┐    ┌────────────────────────────────────────┐
               │ Instant Cancellation│    │  Requires Secure Exit Verification:    │
               │ No penalty / abort  │    │  Option A: 5-second Hold Button        │
               └─────────────────────┘    │  Option B: Emergency Math Challenge    │
                                          │  Option C: Study PIN or Confirmation   │
                                          └──────────────────┬─────────────────────┘
                                                             │ Verification Passes
                                                             ▼
                                          ┌────────────────────────────────────────┐
                                          │ 1. Native stopLockTask() released      │
                                          │ 2. Unpins screen & restores nav bars   │
                                          │ 3. Logs partial session time cleanly   │
                                          │ 4. Safely returns to session setup     │
                                          └────────────────────────────────────────┘
```

### Exit Controls:
1. **Grace Period (0–30s)**:
   - Within the first few seconds, the user can cancel freely with a single tap.
2. **Secure Long-Press Exit Barrier (Post-Grace)**:
   - Prevents accidental exits by requiring a **3-to-5 second sustained press-and-hold** on an explicit "Emergency Exit" action with a progress circle indicator.
3. **Emergency Dialer (ICE)**:
   - Dedicated quick button directing to emergency services (`tel:112`) without dropping app security.
4. **Auto-Unlock on Timer Zero**:
   - The moment remaining seconds reach `00:00`, the app automatically calls `stopNativeLockMode()`, emits haptic feedback, and displays the session completion summary.

---

## 4. UI/UX Migration: Replacing Restrict Mode with Lock Mode

### In [session_setup_screen.dart](file:///c:/Users/hipradeep/Documents/android_apps/log_app/study_log/lib/screens/session_setup_screen.dart):
* **Remove**:
  - Legacy `_isRestrictMode` boolean and the duplicate "Restrict mode" checkbox tile.
* **Elevate**:
  - Consolidate all focus locking under a single premium **"Lock mode (Zen Mode)"** card.
  - When enabled, automatically locks `allowPause = false` and `allowReset = false`.
  - Inline "Tune" (`Icons.tune_rounded`) icon opening `PhoneLockSettingsSheet`.
  - App bar badge: Displays **LOCK** or **ZEN** badge instead of `RESTRICT`.

### In [session_timer_screen.dart](file:///c:/Users/hipradeep/Documents/android_apps/log_app/study_log/lib/screens/session_timer_screen.dart):
* **Replace**:
  - `widget.isRestrictMode` replaced by `widget.lockConfig.isLockModeEnabled`.
  - Style timer and circular gauge with sleek Zen Mode theme accents (deep obsidian background, crimson/emerald accent indicators).
* **Integrate**:
  - Secure long-press exit dialog.
  - Native Kotlin lock binding on mount and unmount.

---

## 5. Phased Implementation Roadmap

* **Phase 1: Native Channel & Preconditions Refinement**
  - Check platform version and Lock Task availability before launching.
  - Ensure graceful fallback if the device has restrictive MDM policies.
* **Phase 2: UI Consolidation in `session_setup_screen.dart`**
  - Remove all traces of `_isRestrictMode`.
  - Connect `_lockConfig` directly to session execution.
* **Phase 3: Secure Exit Widget & Timer Integration**
  - Replace casual exit popups with a dedicated secure hold-to-exit modal in `TimedLockOverlayScreen`.
* **Phase 4: Verification & Audit**
  - Run `flutter analyze` ensuring 0 diagnostics.
  - Test physical device behavior across screen lock, home button press, and timer expiration.
