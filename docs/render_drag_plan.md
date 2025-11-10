Render-Driven Drag & Drop Plan
==============================

Context
-------
- Calendar grid and task tiles already live in custom render objects, but the
  current drag/resize flow still mimics widget-era behavior: tiles stop moving
  once the pointer leaves the grid, previews only update when the render
  surface sees pointer events, and the entire drag runs “in place” instead of
  following the cursor.
- We cannot reintroduce `Draggable`/`DragTarget` widgets because layout,
  narrowing, split previews, and auto-scroll must remain render-driven.
- We still need full interop with Flutter’s drag pipeline (e.g., dragging
  between mobile tabs, accessibility actions) and we must preserve existing
  behaviors: drop-zone highlighting, split previews, auto-narrowing, resize
  handles, edge auto-scroll, and guest/primary parity.

Rationale for Custom Render Drags
---------------------------------
1. **Render-phase geometry control** – Narrowing, overlap columns, and slot
   snapping happen in `performLayout`. Standard `Draggable` widgets can’t
   reflow children mid-drag; they only emit gesture callbacks.
2. **Single source of truth** – `CalendarSurfaceController` exposes layout
   metrics to overlays/popovers. If we let widgets reposition tiles, geometry
   would desync.
3. **Existing preview logic** – The render surface already paints drop-zone
   highlights, split ghosts, and auto-scroll bands. Keeping drag logic in the
   render layer lets us reuse that code instead of recreating it in overlays.
4. **Interop requirement** – We still use Flutter’s drag recognizer under the
   hood so pointer capture, mobile tab switching, and accessibility actions
   behave like stock draggables.

High-Level Steps
----------------
1. **RenderDraggable Task Tile**
   - Replace the gesture-based `ResizableTaskWidget` wrapper with a render box
     that owns the drag recognizer (similar to what `LongPressDraggable`
     provides).
   - When a drag starts, lift the tile into an overlay layer (render-driven
     feedback) so it follows the pointer globally; keep resize handles and
     semantics intact.
   - Emit drag start/update/end hooks back into `TaskInteractionController` so
     business logic stays centralized.

2. **Render Drop Target (`RenderCalendarSurface`)**
   - Implement drop-target semantics in the render surface (see
     `RenderDragTarget`): accept drag gestures, respond to `acceptGesture`
     calls, and receive drop notifications even if the pointer travels across
     other widgets.
   - Use the existing slot math to compute preview start times, overlap state,
     narrowed widths, and drop highlighting directly in response to drag events.
   - Continue driving edge auto-scroll bands and drop-hover IDs from the render
     surface so the widget layer remains presentation-only.

3. **Preview + Width Logic**
   - Keep the current narrowing/split-preview code in the render surface. The
     draggable tile only provides the user-visible feedback; the surface still
     calculates geometry and paints highlights every frame.
   - Ensure global drags update `_DragLayoutOverride` data so the dragging tile
     reflows inside `performLayout` (no disappearing widgets).

4. **Resize & Selection Interactions**
   - Port resize handles fully into the render draggable so duration changes
     stay synced with drag previews and auto-scroll.
   - Maintain selection/hover visuals via render geometry (no widget keys).

5. **Guest + Primary Calendars**
   - All work happens inside shared `CalendarGrid`/render components. Guest mode
     reuses the same grid, so dragging/resizing works identically across both
     experiences.

6. **Testing & Accessibility**
   - Add widget/render tests that simulate drags (including edge auto-scroll,
     hover narrowing, and drop commits) and ensure semantics expose actions for
     assistive tech.
   - Verify drags interoperate with other `Draggable`/`DragTarget` widgets (e.g.,
     dragging across mobile tabs) since we reuse Flutter’s drag pipeline.

Key Behaviors to Preserve
-------------------------
- Drop-zone highlighting at the correct column/day.
- Split previews with automatic narrowing/widening when hovering tasks.
- Slot snapping and overlap avoidance driven by render metrics.
- Edge auto-scroll bands and drag hover state (`dropHoverTaskId`).
- Resize handles, min-duration clamping, and preview painting.
- Accessibility semantics (tap, drag, resize, select) and keyboard parity.
- Parity between authenticated and guest calendars (shared render surface).

Implementation Notes
--------------------
- Task tiles become render draggables that wrap `DragGestureRecognizer` and
  emit standard drag events so they interop with Flutter’s drag/drop system.
- `RenderCalendarSurface` implements drop target hooks (`hitTest`,
  `handleEvent`, drag acceptance) while keeping all layout/paint responsibilities
  in `performLayout`/`paint`.
- `TaskInteractionController` continues orchestrating state (preview start,
  narrowed widths, clipboard, etc.) but now receives updates directly from the
  render drag pipeline.
- No new widget-level overlays or caches; everything stays render-driven per
  `RENDER.md`/`CLAUDE.md` guidelines.

Flutter-Parity Blueprint
------------------------
1. **Draggable session + overlay (mirrors `LongPressDraggable`)**
   - Each `RenderDraggableTaskTile` owns an `ImmediateMultiDragGestureRecognizer`
     (same class Flutter’s stock draggable uses). On drag-start we call
     `startDrag` with a `DragItem` that records the tile id, rect, and child
     render box reference.
   - Lift feedback using the same `DragAvatar` pattern: keep the tile in the
     container for layout math but paint the dragging child via a
     `LayerHandle<LeaderLayer>`/`FollowerLayer` pair that follows global
     pointer positions. This guarantees parity with Flutter’s overlay-driven
     drags and keeps resize handles/semantics intact while the avatar floats.
   - During the drag we forward `DragUpdateDetails` (global position, local
     delta, buttons) straight into `TaskInteractionController` so business logic
     matches Flutter’s callback surface and outside consumers can hook into the
     same detail object shape.

2. **Drop target contract (mirrors `RenderDragTarget`)**
   - `RenderCalendarSurface` exposes the equivalent `didEnter`, `didLeave`,
     `didMove`, and `didDrop` callbacks under a `CalendarDragTargetDelegate`
     interface. Internally it delegates to existing slot-math helpers so the
     preview and narrowing logic stay centralized in `performLayout`/`paint`.
   - Gesture arbitration follows Flutter’s pipeline: the tile’s recognizer calls
     `recognizer.addPointer`, and the surface answers `acceptGesture`/`
     rejectGesture` so drag ownership matches stock widgets even when the
     pointer roams outside the grid bounds.
   - When `didDrop` fires, we synthesize the same payload Flutter’s
     `DragTarget` would receive (`CalendarDragDetails` analogous to
     `DragTargetDetails<T>`). `TaskInteractionController` treats that payload as
     the single source of truth and issues commits/undos through its existing
     APIs.

3. **Two-way interoperability (non-negotiable)**
   - Any standard `Draggable`/`LongPressDraggable` outside the grid must be able
     to drop onto the render surface with no special cases. Provide a thin
     widget adapter that forwards the stock drag callbacks into
     `CalendarDragCoordinator` so unscheduled task lists, guest cards, etc. can
     participate without touching render code.
   - Conversely, a task dragged out of the grid must still behave like a normal
     `Draggable`: its feedback/ghost can be dropped onto traditional
     `DragTarget` widgets elsewhere in the app (e.g., sidebar bins, quick-add
     slots). Keep the payload aligned with `DragTargetDetails<T>` so existing
     drop zones continue to work.

3. **Semantics + keyboard parity**
   - Tiles expose `SemanticsAction.increment`/`decrement` for vertical slot
     nudges and `SemanticsAction.moveCursorForwardByCharacter`/`Backward`
     (repurposed) for horizontal column changes, matching the fallback actions
     Flutter’s draggable uses for accessibility drags.
   - The grid surface advertises a custom `SemanticsAction.dragStart`/
     `dragDrop` pair so assistive tech can initiate drops without relying on
     pointer events. These actions call into the same drag delegate methods,
     ensuring identical behavior between pointer, keyboard, and a11y flows.

4. **State sync guarantees**
   - `_DragLayoutOverride` stores the currently dragged tile’s rect each frame;
     `RenderDraggableTaskTile` reads it during `performLayout`, identical to how
     Flutter keeps the original child in the tree while the overlay avatar is
     painted elsewhere. This prevents disappearing tiles and keeps collision
     math deterministic.
   - Every setter that affects geometry (`tileRects`, `_DragLayoutOverride`,
     `CalendarDragTargetDelegate` outputs) calls `markNeedsLayout()`; visual-only
     overlays still rely on `markNeedsPaint()`, preserving the render contract in
     `RENDER.md`.
