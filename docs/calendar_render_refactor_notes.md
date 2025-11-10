Calendar Grid + Task Layer Refactor Targets
===========================================

Legacy widget-only layout introduced a number of fragile helpers that we will
remove once the grid and tiles become custom render objects. Keep this list
as the source of truth for code paths that only exist to patch layout,
painting, or hit-testing limitations.

Status notes
------------
- The grid body now renders through `CalendarRenderSurface` (see
  `lib/src/calendar/view/widgets/calendar_render_surface.dart`), which owns
  time columns, slot stripes, and task layout. The legacy
  `CalendarTaskLayer`/`_CalendarSlot` widgets have been removed.
- Task geometry and popover anchors should be read from
  `CalendarSurfaceController` instead of `_visibleTaskRects` or local caches.
- Slot hit-testing, drag/drop updates, and edge auto-scroll bands are now
  wired through `RenderCalendarSurface` callbacks so there are no overlay
  `DragTarget`s layered above the grid.
- `CalendarSlotDragController` has been deleted; the render surface now
  computes preview slots, overlap detection, and narrowed widths directly
  from render-time metrics and parent data.
- `CalendarTaskSurface` no longer wraps each tile in a `DragTarget`. Drag
  hover state is driven by the render surface via
  `TaskInteractionController.dropHoverTaskId`, and split previews are rendered
  without widget-layer geometry hacks.
- Task tiles now use `CalendarTaskTileRenderRegion` (see
  `lib/src/calendar/view/widgets/calendar_task_tile_render.dart`) so tap,
  drag, resize, semantics, and handle painting live entirely inside the render
  layer. `ResizableTaskWidget` is reduced to presentation + context menu
  plumbing.

Calendar Grid (`lib/src/calendar/view/calendar_grid.dart`)
---------------------------------------------------------
- `_CalendarScrollController`, `_pending*` scroll fields, and `_visibleTask*`
  maps cache layout/viewport state purely so we can fake scroll anchoring and
  hit tests outside of render phase.
- `_restoreScrollAnchor`, `_scheduleAutoScroll`, `_flushPendingScrollTargets`,
  `_fulfillFocusRequestIfReady`, and `_maybeAutoScroll` continuously
  re-request scroll positions because we cannot hook into layout completion.
- Edge auto-scroll ticker plus the four invisible `DragTarget` bands
  (`_buildEdgeScrollTargets`) are overlays that simulate proximity-based drag
  scrolling.
- Day columns use nested `LayoutBuilder`, `Stack`, `Positioned.fill`,
  `Listener`, and `ShadContextMenuRegion` layers to combine slots, tasks,
  clipboard paste zones, and the current-time indicator.
- `_slotContextMenuControllers`, `_activeSlotControllerKeys`,
  `_cleanupSlotContextControllers`, and `_updateActivePopoverLayoutForTask`
  are bookkeeping scaffolds for dozens of popover widgets; they exist because
  we have no render-surface aware context menu support.
- `_tapHitsTask` walks `_visibleTaskRects` to guess whether a tap hit a task,
  since hit testing cannot use the real geometry directly.
- Task popovers rely on `OverlayEntry` + `GlobalKey` lookups +
  `RenderBox.localToGlobal` calculations to rebuild positions.

Task Layer (`lib/src/calendar/view/widgets/calendar_task_layer.dart`)
---------------------------------------------------------------------
- `CalendarTaskLayer` precomputes every task’s `Rect`/narrowed width on the
  widget side and pushes a `geometryMap` into the render object. The render
  object never measures its children; it just trusts the widget math.
- `_CalendarTaskEntryWidget` mutates parent data during build to pass layout
  info, another symptom of pushing layout out of `performLayout`.

Task Surface (`lib/src/calendar/view/widgets/calendar_task_surface.dart`)
-------------------------------------------------------------------------
- Each task surface nests `DragTarget`, `Stack`, `FractionallySizedBox`, and
  opacity layers to fake split previews and drag-width adjustments. Width
  recalculations happen on every drag frame due to lack of render control.

Resizable Task Widget (`lib/src/calendar/view/resizable_task_widget.dart`)
--------------------------------------------------------------------------
- Now purely responsible for building visual content + context menus; all
  gesture handling is delegated to `CalendarTaskTileRenderRegion`.
- Resize handles are painted + hit-tested by the render object, so no
  `GestureDetector`/`MouseRegion` stacks remain in the widget tree.
- Remaining follow-up: migrate the rich text/layout body itself into a
  render-driven painter to remove the final `Stack`/`ClipRect` layers.

Overall
-------
Moving the grid, slots, and task tiles into `MultiChildRenderObjectWidget`s
lets us drop all of these hacks: geometry stays in the render tree, hover and
drag states can be painted directly, and hit testing no longer depends on
cached rectangles or overlay math.

Regression Notes
----------------
- Do **not** treat `DragTargetDetails.offset` as the real pointer location.
  It represents the avatar position relative to its original drag anchor.
  We briefly relied on that value (Feb 2025) and fed it straight into
  `_ensureExternalDragInitialized`, which broke unscheduled→grid drops and
  caused dragged tasks from the grid to disappear. Always rebuild the pointer
  coordinates from the payload (source bounds + pointer fractions) or from
  the controller’s tracked global position before updating the render surface.

RenderBox Conversion Guidance (from `RENDER.md`)
===============================================

Why RenderBox
-------------
- Render pipeline fit: RenderBox owns layout, paint, hit test, semantics—
  perfect for a schedule grid that needs pixel-perfect placement and fluid
  interaction.
- No post-frame crutches: `addPostFrameCallback`/`scheduleMicrotask` are not
  sizing APIs; keep geometry in `performLayout` and visuals in `paint`.

Architecture Pattern
--------------------
- Widgets configure → Elements wire → RenderObjects execute.
- Use a `MultiChildRenderObjectWidget` (like `TabFrame`) that creates/updates
  a custom `RenderBox` mixing in `ContainerRenderObjectMixin` +
  `RenderBoxContainerDefaultsMixin`.
- Store per-child placement via a `ParentData` subclass (e.g.,
  `ContainerBoxParentData` for offsets/sibling links).

Interaction updates
-------------------
- `RenderCalendarSurface` exposes `onDragUpdate`, `onDragEnd`, and
  `onDragExit` so the widget layer can keep `TaskInteractionController`
  state in sync without layering gesture widgets above the render tree.
- Edge auto-scroll is driven by pointer positions reported from the
  render object rather than translucent overlay widgets.

Grid Math Ownership
-------------------
- Keep domain math outside the render object: map time/resources → `Rect`s.
- Render object consumes those `Rect`s to lay out, paint, and hit test. This
  keeps the render layer reusable across grid types.

Minimal Object Model
--------------------
- Widget inputs: `List<Widget> tiles`, matching `List<Rect> tileRects`, plus
  optional callbacks (provisional/commit) and paint configs.
- ParentData: extend `ContainerBoxParentData<RenderBox>` for offsets.

Lifecycle & Invalidation
------------------------
- Geometry changes → `markNeedsLayout()`.
- Visual-only changes → `markNeedsPaint()`.
- Semantics changes → `markNeedsSemanticsUpdate()`.

Layout Flow
-----------
```
final w = constraints.hasBoundedWidth ? constraints.maxWidth : 0;
final h = constraints.hasBoundedHeight ? constraints.maxHeight : 0;
size = constraints.constrain(Size(w, h));
for each child/rect:
  child.layout(BoxConstraints.tight(rect.size));
  (child.parentData as …).offset = rect.topLeft;
```

Painting & Hit Testing
----------------------
- Paint grid chrome via `PaintingContext.canvas`, then `defaultPaint` to draw
  children.
- Hit testing can defer to `defaultHitTestChildren`. Use widget-level gesture
  detectors for simplicity, or override `handleEvent` if the render object
  needs pointer control.

Accessibility & Animations
--------------------------
- Provide semantics via `describeSemanticsConfiguration` (actions, labels,
  `isSemanticBoundary`).
- For animations, drive rect changes at the widget layer or listen to
  controllers in `attach()`/`detach()` and mark layout/paint accordingly—no
  frame callbacks needed.

Skeleton Strategy
-----------------
- Start with the minimal model (rects + children), verify layout/paint/hit
  testing, then layer in grid-specific math outside the render object. This
  keeps the render layer deterministic and “agent-safe.”
