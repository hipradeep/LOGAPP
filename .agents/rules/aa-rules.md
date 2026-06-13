---
trigger: always_on
---

1. Do not use Deprecated: 
   - AppTheme.primaryColor.withOpacity() use .withValues()

2. State Management Optimization & Rules:
   - Zero-dependency custom state: Rely strictly on `ChangeNotifier` pattern inside dedicated controllers (e.g., `MilestonesController`, `JournalController`). Do NOT introduce third-party state packages like Provider, Riverpod, or GetX.
   - Surgical Rebuilds: Prefer `ListenableBuilder`, `AnimatedBuilder`, or the custom `AppProvider<T>.watch(context)` over triggering full-screen `setState()`. Limit widget rebuilds strictly to the smallest component possible.
   - Controller Segregation: Encapsulate stream subscriptions, loading states, error handling, and business logic inside controller classes. Keep UI views purely declarative.
   - Dispose Resources: Always override `dispose()` in controllers and State objects to cancel `StreamSubscription`s and dispose `TextEditingController`s/`FocusNode`s to prevent memory leaks.

3. Theming & Styling:
   - Always rely on `AppTheme` for all colors, textiles, and radii. Never hardcode colors or styles (e.g., use `AppTheme.primaryColor`, `AppTheme.headingSmall`).
   
4. UI Spacing & Layouts:
   - Spacers: Strictly use `AppSpacers` for padding and gaps (e.g., `VGapSm()`, `HGapMd()`). Do not use raw `SizedBox(height: ...)` for structural spacing unless explicitly required for edge cases.

5. Responsiveness & Scrolling:
   - Dynamic Padding: When rendering lists inside `BaseManagementTab` or `RefreshIndicator`, always wrap the core `Column` inside a `SingleChildScrollView`.
   - Scroll Physics: Use `BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())` to ensure over-scroll works correctly with pull-to-refresh.
   - Safe Area Accommodations: Always inject bottom padding to avoid FAB/keyboard occlusion: `padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 100 + MediaQuery.of(context).viewInsets.bottom)`.