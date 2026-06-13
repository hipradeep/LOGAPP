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

===================================================
SCORE: Count how many rules your screen passes.
10/10 = Optimized
7-9   = Acceptable, fix remaining rules soon
Below 7 = Screen likely has visible jank or wasted cycles
===================================================
