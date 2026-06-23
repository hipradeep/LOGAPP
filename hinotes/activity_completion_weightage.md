# Activity Completion, Weightage, and Template System Design

This document outlines the rules, mathematical formulas, and structure for defining activity completion rates, weightage/priority multipliers, and predefined template blueprints.

---

## 1. Completion Metrics by Activity Type

The progress of an activity on any given day (or across its lifecycle) is measured as a fractional completion rate between `0.0` (0%) and `1.0` (100%).

### A. Single Tracking Activities (`'single'`)
Used for quick habits, logs, or quantitative goals.
*   **Binary Mode (Target Count = 1):**
    $$\text{Completion} = \text{Checked ? 1.0 : 0.0}$$
*   **Quantitative Mode (Target Count > 1):**
    $$\text{Completion} = \min\left(1.0, \frac{\text{Check-In Count}}{\text{Target Count}}\right)$$

### B. Multiple/Sub-task Activities (`'multiple'`)
Used for routine checklists (e.g., Morning/Evening Routines).
*   **Standard Checklist:**
    $$\text{Completion} = \frac{\text{Completed Subtasks}}{\text{Total Subtasks}}$$
*   **Skippable Subtasks Support:** If a subtask is skipped, it is removed from both the numerator and the denominator so as not to penalize the user:
    $$\text{Completion} = \frac{\text{Completed Subtasks}}{\text{Total Subtasks} - \text{Skipped Subtasks}}$$

### C. Milestone Activities (`'milestone'`)
Used for long-term project goals (e.g., Learning a skill, project roadmap).
*   **Equal-Weight Milestones:**
    $$\text{Completion} = \frac{\text{Completed Milestones}}{\text{Total Milestones}}$$
*   **Weighted Milestones:** Where different milestones represent different phases/difficulties:
    $$\text{Completion} = \frac{\sum (\text{Completed Milestone}_i \times \text{Weight}_i)}{\sum \text{Total Milestone Weights}}$$

### D. Avoidance Activities (e.g., Quit Smoking)
Special subclass of `'single'` tracking that rewards avoidance rather than execution.
*   **Rules:**
    *   Starts the day automatically at `1.0` completion.
    *   If checked in (logging a failure/slip-up), completion drops to `0.0` instantly.

---

## 2. Weightage & Effort System

Weightage represents the difficulty, cognitive effort, or priority of an activity. It acts as a multiplier when calculating the daily productivity score or awarding points/coins.

### A. Weight Levels
*   **Low (Weight = 1.0):** Micro-actions, simple hydration check-ins, or stretching.
*   **Medium (Weight = 2.0):** Standard daily habits, reading, minor chores.
*   **High (Weight = 3.0):** Highly important tasks, deep work, workouts, or avoidance goals.

### B. Combined Daily Score Formula
To prevent small tasks (e.g., "Drink water") from inflating the user's daily progress over large tasks (e.g., "Study 2 hours"), the **Daily Progress Score** is calculated as a weighted average:

$$\text{Daily Progress Score} = \frac{\sum_{i=1}^{n} (\text{Completion}_i \times \text{Weight}_i)}{\sum_{i=1}^{n} \text{Weight}_i}$$

Where:
*   $n$ is the total number of scheduled activities for the day.
*   $\text{Completion}_i$ is the completion rate ($0.0 \text{ to } 1.0$) of Activity $i$ for that day.
*   $\text{Weight}_i$ is the weight multiplier assigned to Activity $i$.

---

## 3. Predefined Template Blueprints

Predefined templates allow users to create structured habits or goals with a single tap. Each template dictates the activity type, target counts, subtask lists, weightage, and custom points/rules.

### 🚭 A. "Quit Smoking" (Avoidance Template)
*   **Tracking Type:** `single` (Avoidance mode)
*   **Default Weight:** `3.0` (High Impact)
*   **Points Rules:**
    *   **Successful Avoidance (Per Day):** `+50 XP` and `+10 Coins`.
    *   **Slip-up Penalty:** `-100 XP` and `-20 Coins`.
*   **Schedule:** Daily.

### 🧴 B. "Skin Care" (Routine Template)
*   **Tracking Type:** `multiple` (Subtask Checklist)
*   **Default Weight:** `1.5` (Moderate Impact)
*   **Subtask Templates:** `["Cleanse", "Tone", "Moisturize", "Sunscreen"]`
*   **Points Rules:**
    *   **Per Subtask Checked:** `+3 XP` and `+1 Coin`.
    *   **Routine Completed (All Checked):** `+15 XP` and `+5 Coins` bonus.

### 💧 C. "Daily Hydration" (Quantitative Template)
*   **Tracking Type:** `single` (Quantitative)
*   **Default Weight:** `1.0` (Standard Impact)
*   **Default Target Count:** `12` (e.g., 250ml cups)
*   **Points Rules:**
    *   **Per Check-In:** `+2 XP` and `+1 Coin`.
    *   **Target Met Bonus:** `+10 XP` and `+5 Coins`.

---

## 4. Gamification Coin & Point Integration

This template and weightage system directly feeds into the app's coin/points ledger system:

```
[Activity Checked] 
        │
        ▼
[Compute Completion Rate (0.0 - 1.0)] 
        │
        ▼
[Apply Weight Multiplier (1.0 - 3.0)]
        │
        ▼
[Calculate Rewards]
  ├── Points/XP = Base XP * Completion * Weight
  └── Coins = Base Coins * Completion * Weight
        │
        ▼
[Check Daily Caps / Apply Streak Multipliers]
```
