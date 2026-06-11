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

| Priority | Issue | Impact | Effort |
|----------|-------|--------|--------|
| 🔴 High | Combine 3 nested StreamBuilders into 1 | Prevents 3x cascade rebuilds | Medium |
| 🔴 High | Remove empty `setState(() {})` on sheet close | Eliminates unnecessary rebuild | Trivial |
| 🔴 High | Cache today's filtered lists + classification | Avoids O(n²) on every frame | Medium |
| 🟡 Med | Compute `today` once per build, not per call | Reduces object creation | Trivial |
| 🟡 Med | Filter subtasks query in Firestore | Reduces network + memory | Low |
| 🟡 Med | Add `ValueKey` to ActivityChip | Better diff performance | Trivial |
| 🟡 Med | Use pre-filtered `todaySubTasks` in chip count | Avoid re-filtering | Trivial |
| 🟢 Low | Extract mood section as separate widget | Skip rebuild when unrelated setState | Low |

---

## Recommended Implementation Order

1. Remove empty `setState` (trivial, instant win)
2. Add `ValueKey` to chips (trivial)
3. Fix `_isToday` to use single `now` (trivial)
4. Use pre-filtered lists in chip count (trivial)
5. Combine StreamBuilders with `rxdart` (medium effort, biggest impact)
6. Filter Firestore subtask query (medium effort)
7. Extract mood section widget (low effort)
