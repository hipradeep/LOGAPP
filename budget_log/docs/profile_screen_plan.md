# Profile & Settings Organization Plan: `budget_log`

> **Design Goal**: Streamlined, purpose-built architecture separating the **Profile Screen** (personal user card, financial snapshot, and recurring subscriptions) from the **Settings Screen** (accounts, categories, cloud backup, theme, and data management). Exclusively designed for **INR (₹)** currency with Indian numbering system format (e.g. `₹1,50,000`).

---

## 1. Currency Specification: INR (₹) Exclusive

* All financial displays throughout `budget_log` strictly use the Indian Rupee symbol: **`₹`**.
* All numeric currency formatting follows the Indian grouping convention:
  - Thousands, Lakhs, Crores (e.g. `₹12,450`, `₹1,25,000`, `₹10,00,000`).
* No multi-currency converters or currency-picker selectors in Settings.

---

## 2. Visual Layouts & Architecture

### A. Profile Screen (`lib/screens/profile_screen.dart` — 5th BNB Tab)

```
+-------------------------------------------------------------+
| TabHeader: "Profile"  |  Subtitle  |  ⚙️ (Settings Icon)     |
+-------------------------------------------------------------+
| 1. User Hero & Financial Snapshot Card                      |
|    - Google Account Avatar / User Initial & Verified Badge  |
|    - Email / Display Name / "Guest Spender"                 |
|    - Quick Cloud Sync Indicator (Last synced / Sign In)     |
|    - 4-Column MiniStat Bar (INR ₹):                         |
|      [ ₹ Spent ]  |  [ Saved % ]  |  [ Subs ]  |  [ Udar ]  |
+-------------------------------------------------------------+
| 2. Profile Actions Card                                     |
|    - 🔄 Subscriptions & Recurring Bills                     |
|      (Active subscriptions, billing cycles & alerts)        |
+-------------------------------------------------------------+
```

---

### B. Dedicated Settings Screen (`lib/screens/settings_screen.dart` — via ⚙️ Icon)

```
+-------------------------------------------------------------+
| CustomAppBar: "Settings" (with back button)                 |
+-------------------------------------------------------------+
| 1. FINANCIAL CONFIGURATION                                  |
|    - 💳 Accounts & Payment Modes (UPI, banks, cards, cash)  |
|    - 🏷️ Categories (Expense / Income)                        |
+-------------------------------------------------------------+
| 2. CLOUD BACKUP & DRIVE SYNC                                |
|    - Google Drive Account (Sign in / Sign out)              |
|    - Backup to Drive / Restore from Drive                   |
+-------------------------------------------------------------+
| 3. TRACKING                                                 |
|    - 📥 SMS Inbox (Pending bank-message count badge)         |
+-------------------------------------------------------------+
| 4. PREFERENCES                                              |
|    - 🎨 Appearance (Light / Dark / System mode)             |
|    - 🔔 Notifications (Permission & bill reminder status)   |
|    - 📐 Design System Showcase                              |
+-------------------------------------------------------------+
| 5. DATA & SYSTEM                                            |
|    - Export Data / Import Local Backup                      |
|    - About & Privacy (100% offline-first, private INR app)  |
+-------------------------------------------------------------+
```

---

## 3. Component Specifications

### 3.1 TabHeader (Profile Tab)
* **Title**: `Profile`
* **Subtitle**: `Your financial snapshot & subscriptions`
* **Action (Top-Right)**: `IconButton(Icons.settings_rounded)` $\rightarrow$ navigates to `SettingsScreen`.

### 3.2 User Hero & Financial Snapshot Card (`_UserProfileCard`)
* Listens to: `Listenable.merge([cloudSyncController, financeController, udarController, subscriptionController])`.
* **User Information**:
  - Signed-in: Avatar image or gradient initial with verified badge, display name, and email.
  - Guest: Guest avatar with quick `"Sign In"` button and progress dialog.
* **4-Column Mini-Stat Bar (All INR ₹)**:
  1. **Spent**: `₹{thisMonthExpense}` (`Icons.arrow_upward_rounded`, Coral/Red)
  2. **Saved**: `{savingsRate}%` (`Icons.savings_rounded`, Emerald Green)
  3. **Subs**: `{activeSubsCount}` (`Icons.repeat_rounded`, Indigo)
  4. **Udar**: `₹{netDebt}` (`Icons.people_alt_rounded`, Blue)

### 3.3 Profile Action Section (`_ProfileActionsCard`)
* **Subscriptions & Recurring Bills**: Direct navigation to `SubscriptionScreen`.

---

## 4. Implementation Steps

1. **Update `main_navigation_screen.dart`**:
   - Change 5th BNB tab from `Settings` $\rightarrow$ `Profile` (`Icons.person_outline_rounded` / `Icons.person_rounded`).
2. **Build `profile_screen.dart`**:
   - Includes `TabHeader` with `Settings` action.
   - Includes `_UserProfileCard` (Hero banner + 4 mini-stats in INR ₹).
   - Includes `_ProfileActionsCard` for Subscriptions.
3. **Refactor `settings_screen.dart`**:
   - Add **Accounts & Payment Modes** tile.
   - Add **Categories** tile.
   - Retain **Cloud Backup & Drive Sync**, **SMS Inbox**, **Appearance**, **Notifications**, and **Data Management**.
   - Notifications show permission and bill-reminder status only; no daily reminder.
   - Omit any multi-currency settings (locked strictly to INR `₹`).
4. **Clean Code & Compliance**:
   - Zero raw `SizedBox` (strictly `AppSpacers`).
   - `AutomaticKeepAliveClientMixin` on `ProfileScreen`.
