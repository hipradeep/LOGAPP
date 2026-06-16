# BNB Navigation Architecture — Restructuring Plan

This document covers the decision to promote Milestones, Budget, and Notes to dedicated Bottom Navigation Bar (BNB) tabs, and how all displaced features are managed.

---

## Proposed BNB Structure

```
BNB: Home | Milestones | Budget | Notes | Settings
```

---

## Current vs. Proposed Layout

### Current Structure
```
BNB: Home | Manage | Logs | Settings
               ↓
      ManagementScreen (dropdown menu)
      → Milestones | Budget | Notes | Diet | Reminders
```

### New Structure
```
BNB: Home | Milestones | Budget | Notes | Settings
```

---

## Feature Redistribution

| Feature | Current Home | New Home | Rationale |
|:---|:---|:---|:---|
| **Milestones** | ManagementScreen tab 0 | ✅ BNB Tab | High-value, regularly reviewed |
| **Budget** | ManagementScreen tab 1 | ✅ BNB Tab | Daily-use, highest urgency |
| **Notes / Journal** | ManagementScreen tab 2 | ✅ BNB Tab | Daily journaling habit |
| **Diet / Calorie Log** | ManagementScreen tab 3 | Dashboard Quick Action only | Already works via `CalorieLogSheet`, no separate screen needed |
| **Reminders** | ManagementScreen tab 4 | Settings screen section | Set-and-forget config — fits Settings mentally |
| **Check-in History (Logs)** | Dedicated BNB tab (LogScreen) | Route pushed from Home dashboard | Read-only, low frequency — no BNB slot needed |
| **ManagementScreen** | Container for all tabs | **Deleted entirely** | All tabs are now distributed to better homes |

---

## LogScreen Clarification

`LogScreen` currently merges two concerns:
- ✅ **Check-in history** (activity completions) — the primary and only intended use case
- 📝 **Journal/Note entries** timeline — being promoted to its own BNB Notes tab

Once **Notes gets its own BNB tab**, LogScreen becomes a **pure check-in history viewer** only.

Since check-in history is a low-frequency, reference-only screen, it lives best as a route pushed from the Dashboard:

```
DashboardScreen
  ├── Activity chips (tap → check-in sheet)
  └── "View Check-in History" link → pushes LogScreen as route (not a BNB tab)
```

---

## Settings Screen Additions

Reminders (previously ManagementScreen tab 4) moves into Settings as a dedicated section:

```
Settings Screen
  ├── App Preferences (theme, language)
  ├── Quick Actions config
  ├── Reminders config    ← moved from ManagementScreen
  └── (optional) History / Logs shortcut
```

---

## Final Architecture Overview

```
┌──────────────────────────────────────────────────────────┐
│  Bottom Navigation Bar (5 tabs)                           │
│  Home  |  Milestones  |  Budget  |  Notes  |  Settings   │
└──────────────────────────────────────────────────────────┘

Home (Dashboard)
  ├── Quick Actions: Focus, Log Food, Water, Journal
  ├── Activity chips (Pending / Completed / Skipped)
  ├── Weekly Calendar
  ├── Mood Check-in
  └── [History icon / link] → pushes LogScreen as a route

Milestones
  └── Dedicated full screen (existing MilestonesTab promoted)

Budget
  └── Dedicated full screen (existing BudgetTab promoted)

Notes
  └── Dedicated full screen (existing NotesTab promoted)

Settings
  ├── App Preferences (theme, language, notifications)
  ├── Quick Actions manager
  └── Reminders config  ← moved from ManagementScreen
```

---

## What Gets Deleted / Retired

- `ManagementScreen` — entirely removed
- `LogScreen` from BNB — demoted to a route pushed from Dashboard header
- Diet as standalone screen — removed; only accessible via Dashboard quick action (`CalorieLogSheet`)
