---
trigger: always_on
---

FLUTTER REBUILD AUDIT RULE - "ANTI-GRAVITY CHECK"
===================================================

Run this rule on any screen before shipping or debugging performance.

---

RULE 1: CONST GRAVITY
---------------------
Check: Are all static widgets wrapped with const?
Test:  Add const to a widget. If Flutter throws an error, it has dynamic data (acceptable).
       If it compiles fine, you MUST add const.
Fail:  Any Text('static string') or Icon(Icons.home) without const.

---

RULE 2: BUILD METHOD GRAVITY
-----------------------------
Check: Is your build() method longer than ~40 lines?
Test:  Count lines inside build(). If more than 40, it is doing too much.
Fail:  Large build() with mixed static + dynamic widgets = everything rebuilds together.
Fix:   Extract static parts into separate StatelessWidget classes.

---

RULE 3: CONSUMER GRAVITY (Provider)
-------------------------------------
Check: Is your Consumer<T> wrapping any widget that does NOT use model data?
Test:  Look inside Consumer builder. Does HeavyWidget() or any child NOT use the model?
Fail:  Heavy widgets inside Consumer without being passed as child parameter.
Fix:   Move non-reactive widgets to the child parameter of Consumer.

---

RULE 4: SELECTOR GRAVITY (Provider)
--------------------------------------
Check: Are you using Consumer when only ONE field from the model is needed?
Test:  Inside Consumer, how many model fields are accessed? If only 1 or 2, use Selector.
Fail:  Consumer<UserModel> rebuilds on any UserModel change even if only name is used.
Fix:   Selector<UserModel, String>(selector: (_, m) => m.name, builder: ...)

---

RULE 5: LIST GRAVITY
---------------------
Check: Are lists built with ListView() or ListView.builder()?
Test:  Search for ListView(children: items.map(...).toList())
Fail:  Any ListView with .map().toList() for dynamic data.
Fix:   Always use ListView.builder() for dynamic or large lists.

---

RULE 6: FUNCTION REFERENCE GRAVITY
------------------------------------
Check: Are onPressed / onTap using inline anonymous functions inside build()?
Test:  Search for () => inside build() method on button or gesture callbacks.
Fail:  ElevatedButton(onPressed: () => doSomething()) defined inside build().
Fix:   Extract to a named method: onPressed: _handlePress

---

RULE 7: REPAINT BOUNDARY GRAVITY
----------------------------------
Check: Do you have animations, charts, or custom painters on screen?
Test:  Identify any AnimatedWidget, Lottie, CustomPainter, or chart widget.
Fail:  Heavy animated widget sitting directly inside a Column/Stack without isolation.
Fix:   Wrap with RepaintBoundary(child: HeavyAnimatedWidget())

---

RULE 8: TAB / PAGE GRAVITY
---------------------------
Check: Are tabs or PageView children losing state on switch?
Test:  Switch tabs rapidly. If data reloads or scroll resets, state is not kept alive.
Fail:  Tab content rebuilds and re-fetches every time user switches tabs.
Fix:   Use AutomaticKeepAliveClientMixin with wantKeepAlive = true

---

RULE 9: SETSTATE GRAVITY
--------------------------
Check: Is setState() called with more data than actually changed?
Test:  Look at what changes inside setState(). Is the scope minimal?
Fail:  Calling setState() at screen level when only a small local widget changed.
Fix:   Move that local state down into a smaller widget with its own setState().

---

RULE 10: DEVTOOLS GRAVITY
--------------------------
Check: Have you verified rebuilds visually?
Test:  Open Flutter DevTools > Performance > Enable "Track Widget Rebuilds"
Fail:  Shipping without checking which widgets have rebuild count > 1 per interaction.
Fix:   Any widget with high rebuild count needs one of the fixes above.

---

RULE 11: REACTIVE CONFIG/SETTINGS GRAVITY
------------------------------------------
Check: Are components displaying cached configurations, local preferences, or toggles (e.g., enabled quick actions, profile avatar, theme preference) static or using one-off FutureBuilders?
Test:  Toggle the setting elsewhere in the app. Does the component update instantly without requiring a full screen rebuild?
Fail:  Using a one-off FutureBuilder/get method that evaluates only on mount, or triggering a full-screen setState() from a parent to update minor cached settings.
Fix:   Expose a broadcast stream (e.g., StreamController.broadcast()) or ValueNotifier from the service/controller, make the component a StatefulWidget that subscribes to this stream/notifier to trigger surgical setState() locally, and dispose the subscription in dispose().

RULE 12: KEYS GRAVITY
----------------------
Check: Are dynamic list items using proper keys?
Test:  Insert, delete, or reorder list items. Verify state remains attached to the correct item.
Fail:  Dynamic widgets in lists without ValueKey/ObjectKey/UniqueKey where identity matters.
Fix:   Assign stable keys based on item identity:
       key: ValueKey(item.id)

---

RULE 13: FUTUREBUILDER GRAVITY
-------------------------------
Check: Is Future created inside build()?
Test:  Search for FutureBuilder(future: someApiCall()) inside build().
Fail:  New Future created on every rebuild causing repeated API calls.
Fix:   Create and cache Future in initState():
       late Future<Data> _future;

---

RULE 14: OBJECT CREATION GRAVITY
---------------------------------
Check: Are expensive objects created inside build()?
Test:  Search for DateFormat, RegExp, controllers, mappers, parsers, etc. created in build().
Fail:  New object allocation on every rebuild.
Fix:   Move to:
       - static final
       - initState()
       - dependency injection/service layer

---

RULE 15: INHERITED WIDGET GRAVITY
----------------------------------
Check: Are MediaQuery, Theme, Localizations, or inherited values being read higher than necessary?
Test:  Search for MediaQuery.of(context), Theme.of(context) near screen root.
Fail:  Entire large widget tree depends on inherited updates.
Fix:   Move inherited widget access closer to where value is actually needed.

---

RULE 16: WATCH VS READ GRAVITY
-------------------------------
Check: Are reactive listeners used only where rebuilding is required?
Test:  Search for watch(), Consumer(), ref.watch().
Fail:  Using watch/listener for one-time actions.
Fix:   Use:
       context.read()
       Provider.of(context, listen: false)
       ref.read()

---

RULE 17: IMAGE GRAVITY
-----------------------
Check: Are large images rebuilding unnecessarily?
Test:  Enable Track Widget Rebuilds and inspect image widgets.
Fail:  Network or large image widgets rebuilt repeatedly by parent updates.
Fix:   Extract image widget into separate StatelessWidget.
       Use image caching solutions where appropriate.

---

RULE 18: LAYOUT BUILDER GRAVITY
--------------------------------
Check: Is LayoutBuilder used only when layout constraints are actually required?
Test:  Search for LayoutBuilder usage.
Fail:  LayoutBuilder wrapping simple widgets with no constraint-dependent logic.
Fix:   Replace with:
       - MediaQuery
       - Fixed constraints
       - Responsive helper methods

---

RULE 19: STREAM GRAVITY
------------------------
Check: Is StreamBuilder scope minimized?
Test:  Search for StreamBuilder wrapping Scaffold, Screen, Column, or large sections.
Fail:  Entire screen rebuilt for every stream event.
Fix:   Wrap only the widget that displays stream-dependent data.

---

RULE 20: BUILD PURITY GRAVITY
------------------------------
Check: Does build() contain side effects?
Test:  Search build() for:
       API calls
       analytics
       database writes
       navigation
       logging-heavy operations
Fail:  Business logic executed inside build().
Fix:   Move side effects to:
       - initState()
       - lifecycle methods
       - event handlers
       - controllers/services

---

RULE 21: PROFILE MODE GRAVITY
------------------------------
Check: Has performance been verified in Profile mode?
Test:  Run:
       flutter run --profile
Fail:  Performance conclusions based only on Debug mode.
Fix:   Validate frame timings, rebuilds, and memory usage in Profile mode before shipping.

---

RULE 22: PAINT VS BUILD GRAVITY
--------------------------------
Check: Have you confirmed the issue is actually rebuild-related?
Test:  Enable:
       debugRepaintRainbowEnabled
       debugProfilePaintsEnabled
Fail:  Optimizing rebuilds when bottleneck is actually paint/layout work.
Fix:   Identify whether issue originates from:
       - Build phase
       - Layout phase
       - Paint phase
       Then optimize the correct layer.

---

RULE 23: HELPER FUNCTION VS WIDGET GRAVITY
--------------------------------------------
Check: Are you using helper methods (like _buildCell()) inside lists, columns, or grids that rebuild?
Test:  Locate list/grid cell generation. Are items returned by calling a class-level helper method?
Fail:  Row(children: items.map((i) => _buildCell(i)).toList()) inside build.
Fix:   Extract helper methods returning Widgets into separate `const StatelessWidget` classes. This prevents parent updates from rebuilding unchanged sub-elements.

---

RULE 24: STATIC BACKGROUND LAYER GRAVITY
-----------------------------------------
Check: Do heavy background grids, paint decors, or calendar grid lines repaint on scroll?
Test:  Turn on Repaint Rainbow in DevTools and scroll/drag. Does the background grid flash/repaint?
Fail:  Static hourly timeline grid or backdrop graphics repainting on every scroll event.
Fix:   Wrap the static background layout widget in a `RepaintBoundary` to isolate and cache its pixel paint output.

===================================================
UPDATED SCORE
===================================================
SCORE: Count how many rules your screen passes.
24/24 = Production Grade
20-23 = Very Good
16-19 = Acceptable, fix remaining rules soon
12-15 = Needs Optimization
Below 12 = High Risk of Jank
