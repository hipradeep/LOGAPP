# Lock My Phone (Zen Mode) - Reverse Engineering Feature Specification

**Target Package**: `tomka.lockmyphone` (Version: 2.4.3 / versionCode: 118)  
**Developer**: Thomas Kahn  
**APK Analyzed**: `docs/re_targets/lockmyphone/lockmyphone.apk`  
**Tooling Used**: REA Agents (`rea-agents` v6.7.0) + JADX Headless MCP  

---

## 1. Overview & Core Concept
**Lock My Phone (Zen Mode)** is designed for digital detox and extreme focus discipline. Unlike casual study timers, it enforces non-negotiable phone lockouts where secondary apps, notifications, home launchers, and task switchers are completely blocked until the allotted time expires.

---

## 2. Comprehensive Feature Breakdown

### A. Lock Timing & Scheduling
* **One-Time Timed Lock (`isOneTimeLock`)**:
  - Direct duration locks (e.g. 15m, 30m, 1h, 2h).
  - Target-time locks (*"Lock until 8:00 PM"*).
* **Recurring Lock Schedules (`recurring_lock_periods`)**:
  - Automated weekly schedules (e.g., Mon–Fri work hours, sleep hours).
* **Pre-Lock Grace Period (`select_countdown`)**:
  - 10s to 30s cancellation countdown before the lock seals, preventing accidental triggers.
* **Lock Extension (`extendedMinutes`)**:
  - Ability to add extra focus minutes to an ongoing lock session without unlocking the phone.
* **Break / Vacation Mode (`select_date_range`)**:
  - Date-range selector to temporarily suspend recurring locks during vacations.

---

### B. Security & Hardware Lockdown
* **Device Administrator (`BIND_DEVICE_ADMIN`)**:
  - Triggers hardware-level screen lock via `DevicePolicyManager.lockNow()`.
  - Prevents the app from being uninstalled or force-stopped during active locks.
* **Screen-Wake Interception (`UnlockBroadcastReceiver`)**:
  - Listens to `android.intent.action.USER_PRESENT` with high priority (`9999`).
  - Instantly re-asserts the lock or turns the screen back off if the user unlocks the device.
* **Reboot Persistence (`RECEIVE_BOOT_COMPLETED`)**:
  - Catches boot events and immediately locks the device on startup before the launcher loads.
* **Anti-Clock Tampering (`LockTimeActiveDB`)**:
  - Constantly updates `lastTimeActive` timestamps to detect manual system time rollbacks.

---

### C. UI & Accessibility Overlays
* **Floating Quick Lock Bubble (`FloatingQuickLockService`)**:
  - A persistent draggable floating bubble using `SYSTEM_ALERT_WINDOW` (`TYPE_APPLICATION_OVERLAY`) to start a lock session from any screen.
* **Quick Lock Widgets & Dialogs (`DialogLockActionActivity`)**:
  - Home screen launcher widgets for 1-tap lock sessions.
* **Immersive Lock Screen**:
  - Displays remaining countdown clock with a minimalist Zen aesthetic.

---

### D. Emergency & Telephony Handling
* **Emergency Calls (`android.intent.action.DIAL`)**:
  - Built-in emergency dialer for urgent assistance (112, 911, ICE contacts).
* **Inbound Phone Calls**:
  - Allows phone calls to ring through while keeping apps locked.

---

### E. Zen Discipline (Zero Cheating)
* **No Pause Button**: Timer cannot be paused.
* **No Reset Button**: Cannot reset countdown to zero.
* **No Backdoor / Skip**: Device remains locked until the target timestamp.

---

## 3. Comparison with `study_log` Implementation

| Feature | Lock My Phone (`tomka.lockmyphone`) | Study Log (`study_log`) |
|---|---|---|
| **Lock Type** | Hardware lock (`lockNow`) + Floating Overlay | Immersive Kiosk Overlay + Native Screen Pinning (`startLockTask`) |
| **Admin Rights** | Requires Device Administrator permission | Works out-of-the-box (no invasive Device Admin needed) |
| **Exit Mechanism** | Strict (no exit until time expires) | **Testing Exit Button** (with confirmation) + Auto-unlock on timer completion |
| **App Switching** | Blocked via `USER_PRESENT` relock | Blocked via `startLockTask()` & `onUserLeaveHint()` trap |
| **Grace Period** | 10s–30s countdown | Configurable 0s, 5s, 10s, 15s, 30s cancellation window |
| **Emergency Calls** | System dialer intent | Built-in Emergency Dialer button (`tel:112`) |
| **Keep Screen On** | Configurable | Built-in native `FLAG_KEEP_SCREEN_ON` |
