# Dashboard Performance Optimization

> Discussion notes for `dashboard_screen.dart` — smooth data loading, preventing unnecessary re-renders, and avoiding unnecessary setState calls.

---

## 🔴 High Priority Issues

### 1. Triple Nested StreamBuilders (Lines 117-234)

```
StreamBuilder<Activities>        ← rebuilds ALL on any activity change
  └─ StreamBuilder<CheckIns>     ← rebuilds ALL again on any check-in
      └─ StreamBuilder<Tasks>    ← rebuilds ALL again on any subtask
```

**Problem**: Any single Firestore change (e.g. one check-in) triggers a **full rebuild of the entire dashboard** — all 3 stream builders fire, all classification logic re-runs, all widgets rebuild.

**Fix**: Combine streams using `Rx.combineLatest3` (from `rxdart`) into a single stream, or use a state management approach that only emits when the derived data actually changes.

```dart
// Example with rxdart:
final combinedStream = Rx.combineLatest3(
  _checkedActivitiesStream,
  _checkInsStream,
  _subTasksStream,
  (activities, checkIns, subTasks) => DashboardData(activities, checkIns, subTasks),
);
```

---

### 2. Expensive Filtering Repeated on Every Build (Lines 138-210)

Every rebuild re-computes:
- `todayCheckIns` — O(n) filter over ALL check-ins
- `todaySubTasks` — O(n) filter over ALL subtasks
- Classification loop — O(activities × checkIns) nested `.any()` calls
- Sorting — O(n log n) × 3 sections
- `getSortingTime()` — iterates `subTaskTemplates` with `.any()` for each activity

**Fix**: Cache/memoize derived data. Only recompute when the underlying list identity changes.

---

### 3. Unnecessary `setState(() {})` on Sheet Close (Line 409)

```dart
showModalBottomSheet(...).then((_) {
  setState(() {});  // ← empty setState, forces full widget rebuild
});
```

**Problem**: After closing the check-in sheet, this triggers a full rebuild even if nothing changed. The Firestore streams already handle data updates automatically.

**Fix**: Remove this empty `setState`. Streams auto-update the UI when data changes in Firestore.

---

## 🟡 Medium Priority Issues

### 4. `_isToday()` Creates `DateTime.now()` on Every Call (Line 58-61)

```dart
bool _isToday(DateTime date) {
  final now = DateTime.now();  // ← new DateTime object every call
  return date.day == now.day && ...;
}
```

Called **dozens of times** per build (once per check-in, per subtask, per activity). Each call creates a new `DateTime.now()`.

**Fix**: Compute `today` once at the top of the build method and pass it down, or store as a build-scoped local.

```dart
// At top of build():
final now = DateTime.now();
final todayStart = DateTime(now.year, now.month, now.day);

bool isToday(DateTime date) =>
    date.day == now.day && date.month == now.month && date.year == now.year;
```

---

### 5. `getSubTasksStream()` Fetches ALL Subtasks Globally

In `activity_service.dart` line 133-138:
```dart
Stream<List<Task>> getSubTasksStream() {
  return _subtasksCollection.snapshots()...  // ← no filter at all
}
```

**Problem**: Downloads every subtask from Firestore on every change, even though the dashboard only needs today's subtasks for checked activities.

**Fix**: Add a Firestore query filter for today's date range:

```dart
Stream<List<Task>> getTodaySubTasksStream() {
  final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  final todayEnd = todayStart.add(const Duration(days: 1));
  return _subtasksCollection
      .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
      .where('timestamp', isLessThan: Timestamp.fromDate(todayEnd))
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList());
}
```

---

### 6. No Widget Keys on ActivityChip (Line 384)

The `Wrap` rebuilds all chips when any activity changes position (e.g., moves from pending → completed). Without keys, Flutter can't efficiently match old widgets to new ones.

**Fix**: Add `key: ValueKey(activity.id)` to each `ActivityChip`.

```dart
return ActivityChip(
  key: ValueKey(activity.id),  // ← add this
  activity: activity,
  ...
);
```

---

### 7. Redundant `_isToday` in Chip Count Computation (Lines 380-382)

```dart
final int count = activity.trackingType == 'multiple'
    ? allSubTasks.where((s) => s.activityId == activity.id && s.checked && _isToday(s.timestamp)).length
    : todayCheckIns.where((c) => c.activityId == activity.id).length;
```

`allSubTasks` is filtered again with `_isToday` **per chip**, even though `todaySubTasks` was already computed above in the StreamBuilder.

**Fix**: Use the pre-filtered `todaySubTasks` list instead of re-filtering `allSubTasks`.

---

## 🟢 Low Priority Issues

### 8. Mood Section Rebuilds Unnecessarily

`_buildQuickMoodSection()` is called on every `setState` even though its content never changes (static mood list).

**Fix**: Extract as a separate `StatelessWidget` or cache the built widget.

```dart
// Option A: Separate const widget
class _QuickMoodSection extends StatelessWidget {
  const _QuickMoodSection({required this.onMoodSelected});
  final Function(String emoji, String label) onMoodSelected;
  ...
}

// Option B: Cache in state
late final Widget _moodSection = _buildQuickMoodSection();
```

---

## Summary Table

| Priority | Issue | Impact | Status |
|----------|-------|--------|--------|
| 🔴 High | Combine 3 nested StreamBuilders into 1 | Prevents 3x cascade rebuilds | ✅ Solved (Custom State Management) |
| 🔴 High | Remove empty `setState(() {})` on sheet close | Eliminates unnecessary rebuild | ✅ Solved |
| 🔴 High | Cache today's filtered lists + classification | Avoids O(n²) on every build | ✅ Solved (Calculated inside Controller) |
| 🟡 Med | Compute `today` once per build, not per call | Reduces object creation | ✅ Solved (Cached build-scoped DateTime) |
| 🟡 Med | Filter subtasks query in Firestore | Reduces network + memory | ✅ Solved (Restricted to current week) |
| 🟡 Med | Add `ValueKey` to ActivityChip | Better diff performance | ✅ Solved |
| 🟡 Med | Use pre-filtered `todaySubTasks` in chip count | Avoid re-filtering | ✅ Solved (Mapped via Controller lists) |
| 🟢 Low | Extract mood section as separate widget | Skip rebuild when unrelated setState | ✅ Solved (Cached in State) |

---

## Status Notes
All optimizations have been successfully implemented:
* **Custom State Container**: The application uses our lightweight `AppProvider` + `DashboardController` flow, eliminating the nested builder hierarchy.
* **Cached Calculations**: Sorting, parsing, and day-matching logic are computed inside the controller exactly once when new snapshots arrive, rather than on every rebuild.
* **Garbage Collection Reduction**: By calculating `_today` once at the beginning of the `build` method and storing it in a state variable, we avoid creating numerous short-lived `DateTime.now()` instances during list loops.
* **Network Query Constraints**: Stream requests to Firestore are constrained to the current calendar week with a 1-day buffer, minimizing data payload sizes.
* **Referential Caching**: The static `_moodSection` is instantiated exactly once in `initState` and cached as a state member, meaning Flutter completely skips rebuilding this subtree on subsequent frames.

