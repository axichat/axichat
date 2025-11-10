0) Why a custom RenderBox for a schedule grid?

Render pipeline fit. RenderBox is designed for box layout, painting, hit testing, and semantics;
it’s the right level for a grid that positions many tiles precisely and needs smooth interaction.
Flutter API Docs

No post‑frame crutches. addPostFrameCallback runs after a frame flush; it isn’t a sizing/layout API.
scheduleMicrotask just changes async ordering; it’s not part of rendering. Keep all geometry work in
performLayout and visuals in paint.
Flutter API Docs
+1

1) Bird’s‑eye architecture (works for any grid)

Widgets configure → Elements wire → RenderObjects do the work.

Use a MultiChildRenderObjectWidget to pass configuration and children. Implement createRenderObject
and updateRenderObject.
Flutter API Docs

Back it with a custom RenderBox that mixes in:

ContainerRenderObjectMixin<RenderBox, ParentData> (maintains a doubly‑linked list of children), and

RenderBoxContainerDefaultsMixin (helpers for painting and hit testing).
Flutter API Docs

Store per‑child placement in a ParentData subclass (e.g., offset). For box‑style containers,
ContainerBoxParentData gives you offset/sibling links.
Flutter API Docs

Your tab_container package demonstrates this pattern: TabFrame (a MultiChildRenderObjectWidget)
configures RenderTabFrame (a RenderBox that uses those mixins). We’ll replicate the pattern for a
schedule grid.
Dart packages
+1

2) Decide where grid math lives (keeps things generic)

To avoid “gotcha specifics,” separate grid mapping from pixel layout:

Outside the render object: Map domain data (time ranges, columns, lanes) → a list of pixel
rectangles (Rect) for each tile.

Inside the render object: Consume those rects to lay out/paint children and handle interactions.

This separation keeps the RenderBox generic and reusable—even if the grid is time‑based,
resource‑based, or arbitrary.

3) The minimal object model (agent‑safe)

Widget inputs (immutable config):

List<Widget> tiles — one child per tile (wrapping your tile UI/gestures).

List<Rect> tileRects — pixel rect per tile (top‑left in the grid’s local space).

Optional callbacks: onProvisionalRect (live drag/resize feedback), onCommitRect (final
position/size).

Optional paints: grid line painter options (purely visual).

ParentData:

extends ContainerBoxParentData<RenderBox>; you’ll only need offset (set from each rect’s top‑left).
Flutter API Docs

This model avoids hard‑coding “rows,” “minutes,” “resources,” or “snap sizes.” If you need those
later, compute them outside and just feed rects in.

4) Lifecycle & invalidation (what setter triggers what)

Geometry‑affecting change (rects, padding, text direction, grid size): call markNeedsLayout().

Visual‑only change (colors, line thickness): call markNeedsPaint().

Semantics‑only change (labels, actions): call markNeedsSemanticsUpdate().
These responsibilities line up with the RenderBox contract.
Flutter API Docs

5) Layout: one pass, tight constraints, set offsets

Inside performLayout:

Choose your own size. Constrain to finite values (don’t assume tight constraints). A safe default
is:

final w = constraints.hasBoundedWidth ? constraints.maxWidth : 0;

final h = constraints.hasBoundedHeight ? constraints.maxHeight : 0;

size = constraints.constrain(Size(w, h));

For each tile/child:

Get its Rect r from tileRects[index] (clamp to size if desired).

child.layout(BoxConstraints.tight(r.size), parentUsesSize: false);

Set (child.parentData as …).offset = r.topLeft;

This follows the official guidance: parent lays out children with layout(...), and sets each child’s
offset in its ParentData.
Flutter API Docs

6) Paint: draw grid once, then defaultPaint

Paint lightweight grid visuals (lines/background) using PaintingContext.canvas and then call
defaultPaint(context, offset) to paint children in order. If you add layers, manage
alwaysNeedsCompositing.
Flutter API Docs

Only call markNeedsPaint() when visuals change (not geometry).
Flutter API Docs

7) Hit testing & events (two safe patterns)

Flutter gives you two reliable options; pick one to avoid complexity.

A) Widget‑level gestures (recommended for simplicity)

Wrap each tile widget with GestureDetector/Listener and handle drag/resize there.

When a tile’s rect changes, update your model and pass a new tileRects list to the widget;
updateRenderObject updates the render object properties → markNeedsLayout().

Your render object only needs to forward hit tests to children via defaultHitTestChildren.
Flutter API Docs

B) RenderObject‑level pointer handling (advanced)

Override hitTestSelf if the grid background should receive events, and handleEvent to process
pointer moves (update a provisional rect for the active tile, call markNeedsLayout() for smooth
feedback).

On pointer‑up, call onCommitRect(tileIndex, rect) so the widget layer updates the model on the next
build. Do not mutate framework state directly from the render object.

This pattern relies on handleEvent and BoxHitTestEntry.
Flutter API Docs

Either way, the defaults in RenderBoxContainerDefaultsMixin make child hit‑testing easy (
defaultHitTestChildren).
Flutter API Docs
+1

8) Accessibility (semantics)

If tiles are interactive, surface actions:

In describeSemanticsConfiguration, set isSemanticBoundary = true if appropriate and provide actions
such as onIncrease/onDecrease to nudge the active tile (or expose custom semantics). You can also
absorb a user‑provided SemanticsConfiguration.
Flutter API Docs

9) Animations (without post‑frame hacks)

When a rect changes (drag, resize, programmatic updates):

Widget‑driven: Animate your rects at the widget layer (e.g., tween the rects and feed them each
frame), and the render object will relayout/paint—no post‑frame callbacks needed.

Render‑driven: If you must tick inside the render object (e.g., controller listeners), add/remove
listeners in attach()/detach() and call markNeedsPaint() or markNeedsLayout() as needed. This
follows the render pipeline rules.
Flutter API Docs

10) “Agent‑safe” skeleton (compile‑oriented but intentionally generic)

This skeleton avoids domain specifics (no time math, no row counts). It assumes you already know
each tile’s pixel Rect. You can evolve it later by computing tileRects from any grid model.