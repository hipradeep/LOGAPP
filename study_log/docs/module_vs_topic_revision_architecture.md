# Architectural Evaluation: Module Revision vs. Topic Revision

## Overview & Context
The Study Log system currently maintains two parallel, independent spaced repetition engines:
1. **Module Revision (`Revision` / `RevisionController`)**: Tracks levels R1 through R5 for an entire module and its topics collectively.
2. **Topic Revision (`TopicRevision` / `TopicRevisionController`)**: Tracks levels R1 through R5 for individual topics independently.

This evaluation addresses whether to deprecate Module Revision in favor of Topic Revision or adopt a consolidated architecture.

---

## The Core Challenge: Dual Redundancy
Maintaining two separate spaced repetition progression tracks creates friction across the user experience and codebase:

```
Current Architecture (Dual Redundancy):
┌─────────────────────────┐      ┌─────────────────────────┐
│     Module Revision     │      │     Topic Revision      │
│  - Table: revisions     │      │ - Table: topic_revisions│
│  - Controller:          │      │ - Controller:           │
│    RevisionController   │      │   TopicRevController    │
│  - Tracks R1..R5        │      │ - Tracks R1..R5         │
└─────────────────────────┘      └─────────────────────────┘
              ▲                               ▲
              │          Desynced?            │
              └───────────────?───────────────┘
```

### Issues Identified:
1. **Mental Model Confusion**: Learners are unsure whether they should review at the module level or topic level, or whether completing a topic revision advances the module's revision level.
2. **State Desynchronization**: A module might be marked "Due R2" while its individual topics are sitting in different states (e.g., Topic 1 in R3, Topic 2 Not Started).
3. **Database & Code Bloat**: Duplicate SQLite tables, migration logic, stream listeners, controllers, and dialogs.

---

## Comparative Analysis

| Dimension | Option A: Module-Level Only | Option B: Topic-Level Only | Option C: Hybrid Hierarchy (Recommended) |
| :--- | :--- | :--- | :--- |
| **Granularity** | Coarse (All module topics revised together) | Atomic (Each topic revised on its own interval) | Atomic truth with module roll-ups |
| **Spaced Repetition Precision** | Low (Assumes all topics learned at same instant) | High (Accurate to when each topic was learned) | High |
| **Cognitive Load & Batching** | Good (Single prompt to review a module) | High Risk (Too many scattered topic dates) | Balanced (Batch topic sessions via Module launcher) |
| **Architecture Complexity** | Medium | Medium | Minimal (Single source of truth) |
| **User Flexibility** | Rigid | High | High |

---

## Detailed Arguments

### 1. Arguments for Eliminating Independent Module Revision
* **Atomic Learning Curve**: Learners do not master all topics in a module simultaneously. Studying Topic A on Monday and Topic D on Friday requires separate spaced repetition intervals.
* **Unified UI**: With the vertical repetition pipeline and tabs recently implemented on the Topic Details screen, individual topics now offer complete revision progression visibility.
* **Single Source of Truth**: Eliminating the separate `revisions` table eliminates dual synchronization bugs.

### 2. Risks of Removing Module-Level Context Completely
* **Revision Fatigue**: If a learner tracks 100+ topics across 10 courses, receiving dozens of individual, scattered notifications every day leads to burnout and abandonment.
* **Lack of Study Batching**: Students often prefer sitting down for a consolidated revision session dedicated to a module (e.g., "Review all due topics in Cardiovascular Physiology today").

---

## Recommended Strategy: Hybrid Roll-Up Architecture

Rather than maintaining two competing state machines or completely stripping module-level revision, adopt **Topic as the Single Source of Truth** with **Module as a Roll-Up Aggregator**:

```
Proposed Architecture:
┌────────────────────────────────────────────────────────┐
│             Topic Revision (Source of Truth)           │
│  - Table: topic_revisions (or topic.revisionLevel)     │
│  - Tracks true R1..R5 spaced repetition intervals      │
└───────────────────────────┬────────────────────────────┘
                            │ roll-up
                            ▼
┌────────────────────────────────────────────────────────┐
│             Module Revision View (Aggregator)          │
│  - No independent R1..R5 state machine in database     │
│  - Computes:                                           │
│    • Total topics due today in this module             │
│    • Overall module mastery (% of topics at R5)        │
│  - Action: "Revise Module" batches all currently       │
│    due topics into a single continuous study session   │
└────────────────────────────────────────────────────────┘
```

### Key Roadmap Steps:
1. **Unify Database Models**: Keep `topic_revisions` as the sole record of spaced repetition progress.
2. **Transform Module Revision**: Convert `ModuleRevision` from an independent entity into a computed view derived from its topics' revision dates and levels.
3. **Batch Session Launcher**: The "Start Module Revision" button launches a `SessionSetupScreen` pre-populated with only the topics from that module that are currently due (`isDue == true`).
4. **Preserve Clean UI**: Retain both Topic and Module detail screens, but ensure the Module screen reflects the aggregated state of its topics.
