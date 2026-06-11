# Discussion: Activity & Performance Graph Design

This document details the recommended visualizations and chart types for the **Analytics & Performance** section of the Activity Details view based on different tracking types.

---

## 1. Recommendations by Tracking Type

### A. Single Habits (Binary Check-in)
* **Goal**: Show consistency, streaks, and frequency over time.
* **Recommended Chart**: **GitHub-style Contribution Grid (Heatmap)** or **Calendar Strip**.
  - *Why*: A line graph is less meaningful for binary (yes/no) daily data. A contribution grid (7 rows for days of the week, columns for weeks) with colored blocks immediately highlights consistency patterns, gaps, and active streaks.
  - *Alternative*: **Consistency Ring / Progress Gauge** showing the completion percentage over the last 7, 30, and 90 days.

### B. Multiple Activities (Daily Subtask Checklist)
* **Goal**: Visualizing daily completion rates of repeating subtasks.
* **Recommended Chart**: **Daily Completion Bar Chart** or **Smooth Line/Area Chart**.
  - *Why*: Daily completion is a percentage (e.g., 2/3 tasks = 66%). A bar chart shows the completion rate for each day of the week, making it easy to compare productivity levels on different days.
  - *Details*: A gradient line chart with a glowing fill area underneath looks extremely premium and represents overall weekly trend changes cleanly.

### C. Milestone Activities (Flexible Project-style Goals)
* **Goal**: Tracking progress towards a definitive final goal/milestone.
* **Recommended Chart**: **Cumulative Progress Bar Chart** or **Burn-up/Burn-down Chart**.
  - *Why*: Milestone tasks are completed sequentially. A cumulative area graph shows the total number of tasks completed rising day-by-day towards the target line (e.g., total 10 tasks).
  - *Details*: A radial progress ring at the top showing the absolute completion percentage (e.g., "75% of milestone tasks completed") combined with a linear timeline chart of progress.

---

## 2. Integrated Analytics UI/UX Layout

To create a premium feel, we propose a tabbed or toggleable view within the Analytics card:

1. **Tab 1: Completion (Line/Area Graph)**:
   - Shows the daily completion rate (0-100%) over a selected window (7 Days, 30 Days).
   - Works uniformly across all activity types.
2. **Tab 2: Consistency Heatmap**:
   - Shows a grid of the last 12 weeks.
   - Deep green/violet fills representing fully completed days, lighter values representing partial completion, and empty cells representing missed/skipped days.
3. **Summary Stats Bar** (placed at the bottom of the graph):
   - **Current Streak**: Number of consecutive active days.
   - **Completion Rate**: Total completed vs. total scheduled.
   - **Best Day**: The day of the week with the highest completion rate.
