# Calendar Drag Migration Checklist

> Goal: align the calendar drag pipeline with Flutter’s native `Draggable`/`DragTarget`
> contract so drags remain stable across rebuilds, tab switches, and cross-surface
> drops—without relying on `addPostFrameCallback` or `scheduleMicrotask`.

## 1. Restore Geometry Flow (no post-frame hacks)
- [x] Reinstate the `CalendarSurfaceController` geometry notification so it fires **after** `RenderCalendarSurface.performLayout` completes (set a dirty flag during layout and clear it in `paint` or a queued controller callback that runs synchronously). _Implemented via `_markGeometryDirty` + paint flush in `RenderCalendarSurface`._
- [x] Reconnect `CalendarTaskSurface` to that listener and rebuild on geometry changes; remove any `scheduleMicrotask`/`addPostFrameCallback` usage. _Widget now reads geometry directly each build; queued setState is gone._
- [x] Verify `CalendarTaskSurface` now reflects narrowed width / split previews immediately during drag without calling `setState` from layout. _Geometry now flows through `CalendarSurfaceController` → bindings, so the animated container picks up split width factors as soon as `RenderCalendarSurface` flushes paint._

## 2. Promote Tasks to Flutter `Draggable`
- [x] Wrap `ResizableTaskWidget` with a new `CalendarTaskDraggable` that:
  - captures pointer-normalised X/Y before the drag starts,
  - packages the task snapshot + pointer offsets + size into the `Draggable.data`,
  - forwards drag lifecycle callbacks to `TaskInteractionController` (`beginDrag`, `updateDragPointerGlobalPosition`, `endDrag`, etc.).
- [x] Remove the `ImmediateMultiDragGestureRecognizer` and drag logic from `RenderCalendarTaskTile`; leave resize/hover handling intact.
- [ ] Update unit/widget tests interacting with `CalendarTaskSurface` so they drive the new draggable instead of poking the render object directly. _Pending: existing specs still poke render objects; new drag harness required._

## 3. Bridge Grid/Sidebar With `DragTarget`
- [x] Introduce a `CalendarSurfaceDragTarget` widget that wraps the `CalendarRenderSurface`:
  - `onMove` → `_handleSurfaceDragUpdate`,
  - `onLeave` → `_handleSurfaceDragExit`,
  - `onAccept` → `_handleSurfaceDragEnd` with payload from `DragTargetDetails`. _Implemented via `CalendarSurfaceDragTarget` which forwards drag lifecycle into the render object._
- [x] Apply the same pattern to sidebar “unscheduled” bins and tab-edge switchers; each becomes a `DragTarget<CalendarDragPayload>`. _`CalendarSidebarDraggable` now emits payloads and tab edge cues rebuild through DragTarget builders in `CalendarDragTabMixin`._
- [x] Delete `CalendarDragCoordinator`, `CalendarDragSession`, `CalendarDragTargetDelegate`, and any code paths that depend on them. _`calendar_drag_interop.dart` removed; references replaced with native DragTarget wiring._

## 4. Keep Feedback & Geometry Aligned
- [x] Replace the manual overlay code with a `CompositedTransformFollower` (or rely on `Draggable.feedback`) so drag ghosts follow the pointer without scheduling tricks. _CalendarTaskDraggable/CalendarSidebarDraggable now rely on `Draggable.feedback`; legacy overlay helpers removed._
- [x] Compute slot time directly from `DragTargetDetails` and `RenderCalendarSurface` metrics on every `onMove`/`onAccept`—no cached pointer offsets. _`CalendarSurfaceDragTarget` forwards `DragTargetDetails.offset` each frame; `RenderCalendarSurface._handleExternalDragUpdate` recomputes slots from metrics._
- [x] Confirm `_handleTaskDrop` receives accurate payload data and reschedules tasks exactly where the drop occurs. _`handleDragPayloadDrop` derives the snapped slot before `CalendarGrid._handleTaskDrop` fires, aligning drops with pointer position._

## 5. Edge Behaviour & Tab Switching
- [x] Rewire edge auto-scroll and tab switching to listen to `DragTarget.onMove` and the controller payload (instead of coordinator events). _`CalendarDragTabMixin` now updates cues via edge `DragTarget` callbacks without the legacy coordinator._
- [ ] Ensure dragging between tabs on mobile keeps the avatar alive: verify the new `DragTarget` instances re-accept the active avatar immediately after a tab swap. _Edge targets now ignore pointer input when idle, and sidebar draggables raise drag session signals—QA still pending._
- [ ] Maintain narrowed-width split preview logic inside `RenderCalendarSurface`; ensure widget rebuilds reflect it via the restored geometry listener. _Geometry listener is live, but we still need validation covering split preview redraws._

## 6. Testing & Accessibility
- [ ] Extend widget tests:
  - grid ↔ sidebar drops (both directions),
  - tab auto-switch mid-drag,
  - split-preview narrowing and final drop alignment.
  _Pending: suites still rely on legacy drag helpers; new Draggable flows untested._
- [ ] Add semantics tests or manual verification for keyboard/screen-reader drags now that `Draggable`/`DragTarget` provide the hooks. _To do: no accessibility coverage yet._
- [ ] Run `flutter analyze` and targeted `flutter test test/calendar/...` suites before landing. _Outstanding: verification commands not run after migration._

## 7. Cleanup & Verification
- [x] Sweep for any remaining `addPostFrameCallback`/`scheduleMicrotask` calls in calendar drag code (`rg 'addPostFrameCallback|scheduleMicrotask' lib/src/calendar`). _2024-03-18: `rg` confirms no matches after recent refactor._
- [ ] Update relevant docs (`docs/calendar_render_refactor_notes.md`, etc.) to reference the new drag pipeline. _Docs still describe coordinator-based flow._
- [ ] Manual QA on desktop + mobile: pick up, resize, split, move between tabs, and drop into the sidebar to confirm behaviours match expectations. _Hands-on QA not yet executed with the new drag targets._

Following this checklist keeps the render objects authoritative for geometry and tab automation while letting Flutter’s drag infrastructure handle avatar lifecycle, hit testing, and payload delivery.
