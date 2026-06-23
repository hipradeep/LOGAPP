# Implementation Plan: Activity Completion & Weightage (Firebase Only)

This plan details the step-by-step technical implementation to support:
1. **Activity Weightage and Point Fields** in Firebase Firestore.
2. **Weighted Daily Completion & Progress Calculations** in dashboards, calendars, and performance graphs (including fractional milestone day completion).
3. **Weighted Gamification Coins/XP Allocation** based on activity weight and completion rates.

---

## User Review Required

> [!IMPORTANT]
> **Firestore Schema Compatibility:** Existing activity documents in Firestore that lack the `weight` and `points` fields will automatically fallback to default values of `1.0` (weight) and `10` (points) during mapping, avoiding data issues or crashes for current users.

---

## Open Questions

> [!NOTE]
> 1. **Weight Inputs:** In the Add/Edit Activity UI, how should we expose the weight input? Should we use a dropdown (Low/Medium/High representing 1.0/2.0/3.0) or a continuous slider/input?

---

## Proposed Changes

### 1. Data Models & Database Schemas

We will add two new fields to the `Activity` model in the Firebase project:
* `weight` (double): The priority/impact multiplier of the activity.
* `points` (int): The base point/XP reward for completing this activity.

#### [MODIFY] [activity.dart](file:///c:/Users/hipradeep/Documents/android_apps/log_app/log_app_firebase/lib/models/activity.dart)
* Add `weight` (default `1.0`) and `points` (default `10`) fields to the class constructor.
* Update Firestore serializations (`toFirestore`, `fromFirestore`).
* Update the `copyWith` method.

---

### 2. Add & Edit UI with Weight/Points

#### [MODIFY] [add_activity_screen.dart](file:///c:/Users/hipradeep/Documents/android_apps/log_app/log_app_firebase/lib/screens/add_activity_screen.dart)
* Add adjustment selectors (e.g., Low/Medium/High segments or text fields) for "Weight / Priority" and "Base Points / XP".
* Pass the `weight` and `points` arguments through the `onAdd` / `onEdit` callbacks.

---

### 3. Milestone Completion Logic

We will update how milestone completions are calculated dynamically for any given day.

#### [MODIFY] [milestone_service.dart](file:///c:/Users/hipradeep/Documents/android_apps/log_app/log_app_firebase/lib/services/milestone_service.dart)
* Add a new helper `getMilestoneDailyCompletion(Activity activity, List<Task> tasks, DateTime day)`:
  * Returns the fractional progress (`completedTasks / totalTasks`) if tasks are scheduled for that milestone on that day.
  * Returns `-1.0` if no tasks are scheduled for that milestone on that day (indicating this activity should be excluded from the daily average calculation).

---

### 4. Progress & Completion Calculators

We will update all daily calculations to compute weighted fractional completion rather than binary checks.

#### [MODIFY] [dashboard_weekly_calendar.dart](file:///c:/Users/hipradeep/Documents/android_apps/log_app/log_app_firebase/lib/widgets/dashboard_weekly_calendar.dart)
* Replace simple binary calculation with weighted average completion calculation:
  $$\text{Daily Completion} = \frac{\sum (\text{Completion}_i \times \text{Weight}_i)}{\sum \text{Weight}_i}$$
* Exclude milestone activities from both numerator and denominator if `getMilestoneDailyCompletion` returns `-1.0` for that day.

#### [MODIFY] [dashboard_summary_card.dart](file:///c:/Users/hipradeep/Documents/android_apps/log_app/log_app_firebase/lib/widgets/dashboard_summary_card.dart)
* Calculate today's overall completion percentage utilizing the weighted average and the excludable milestone logic.

#### [MODIFY] [activity_bar_graph.dart](file:///c:/Users/hipradeep/Documents/android_apps/log_app/log_app_firebase/lib/widgets/activity_bar_graph.dart)
* Calculate historical weekly trends using the new weighted daily metrics.

---

### 5. Gamification Rewards Calculation

#### [MODIFY] [activity_service.dart](file:///c:/Users/hipradeep/Documents/android_apps/log_app/log_app_firebase/lib/services/activity_service.dart)
* In the check-in handlers, award XP/points and coins to the user by multiplying the action by the activity's weight:
  $$\text{XP Awarded} = \text{Activity.points} \times \text{CompletionRate}$$
  $$\text{Coins Awarded} = \text{Activity.weight} \times \text{Base Coins}$$

---

## Verification Plan

### Automated Tests
- Run unit tests on models and service calculations (if available).
- Execute check-in and database serialization tests.

### Manual Verification
1. Run the `log_app_firebase` app locally.
2. Confirm that logging/loading existing documents without the new fields works seamlessly via fallbacks.
3. Verify that on days with no milestone tasks, the daily completion ring doesn't penalize the user.
4. Perform check-ins for high-weight vs low-weight activities and verify the dashboard completion rings and points/coins adjust correctly.
