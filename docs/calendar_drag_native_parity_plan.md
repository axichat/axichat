# Calendar Drag/Drop Native Parity Plan

## Context
- Desktop drag/drop still works but mobile workflows remain broken: unscheduled → grid drops fail after the Tasks tab auto-switches, highlights flicker or vanish, and drop commits land above the intended slot. Rendering code now depends on `CalendarDragTabMixin`/`CalendarDragFeedbackOverlay` files that no longer exist, leaving the tree uncompilable.
- We replaced Flutter’s widget-based drags with custom render objects but never re-created the full contract that `Draggable`/`DragTarget` deliver (hit-test arbitration, candidate tracking, overlay avatars, re-hit after layout changes, semantics). The calendar render objects therefore diverge from Flutter expectations and lose state whenever the tree rebuilds mid-drag (e.g., phone tab switch).

## Native Drag/Drop Contract (Flutter)
- `Draggable` produces a `_DragAvatar` (`Drag` subclass) that:
  - Captures the pointer via a `MultiDragGestureRecognizer`.
  - Reruns `WidgetsBinding.instance.hitTestInView` on every move, so new targets that appear under a stationary pointer immediately receive `didEnter`.
  - Tracks an ordered stack of active `_DragTargetState`s, calling `didEnter`/`didMove`/`didLeave` and delivering `DragTargetDetails` that include pointer offsets.
- `DragTarget` wraps children in `MetaData` so their render boxes surface during hit tests, stores candidate/rejected drags, exposes `onWillAccept`, `onAccept`, `onMove`, `onLeave`, and reports `DragTargetDetails` back to the avatar.
- The avatar finishes with `didDrop` or cancellation, and target states determine acceptance. Semantics and keyboard actions mirror these hooks.

## Current Calendar Pipeline
- `CalendarTaskTileRenderRegion` (lib/src/calendar/view/widgets/calendar_task_tile_render.dart:155) uses `ImmediateMultiDragGestureRecognizer` but hands control to `CalendarDragCoordinator` instead of Flutter’s `_DragAvatar`.
- `CalendarDragCoordinator` (lib/src/calendar/view/widgets/calendar_drag_interop.dart:45) keeps a flat `Set` of `CalendarDragTargetDelegate`s, manually hit-tests each update, and stores only the latest hover target; no per-target candidate bookkeeping or `Drag` integration exists.
- `RenderCalendarSurface` (lib/src/calendar/view/widgets/calendar_render_surface.dart:520) registers as a `CalendarDragTargetDelegate`, but relies on overlay machinery built with `WidgetsBinding.instance.addPostFrameCallback`, violating render rules and racing with tab switches.
- Edge auto-scroll and tab switching depended on the removed `CalendarDragTabMixin`/`CalendarDragFeedbackOverlay`, leaving no hooks for mobile drag parity.

## Gap Analysis
- **Missing avatar contract**: `CalendarDragHandle` is a custom wrapper that never joins the gesture arena nor persists after widget disposal. It cannot re-hit targets if the widget tree mutates without pointer motion, unlike `_DragAvatar`.
- **No candidate/rejected tracking**: `CalendarDragTargetDelegate` only exposes `didEnter`/`didMove`/`didLeave`/`didDrop`; the coordinator always reports the first hittable target without consulting `canAcceptDrop` or delivering details akin to `DragTargetDetails`. We cannot implement `onWillAccept`-style gating or multi-target negotiation.
- **Stale hover after layout**: When a tab switch swaps the task list for the grid, the new `RenderCalendarSurface` attaches but never receives `didEnter` because our coordinator does not automatically “rehit” with the last pointer location.
- **Drop geometry drift**: The render surface recomputes slot times (`calendar_render_surface.dart:1566`) from pointer deltas but loses the initial avatar offset; dropping schedules tasks above the intended slot.
- **Overlay scheduling**: `_ensureDragOverlayInserted` in `calendar_render_surface.dart:1801` uses `addPostFrameCallback` and `OverlayEntry`, violating repo guidance and introducing a frame delay before feedback appears.
- **Mobile tab interop**: With the mixin removed there is no listener on `CalendarDragCoordinator.dragActiveListenable` to trigger edge-tab switching or to rebuild targets while a drag is active.
- **Semantics parity**: Current render objects do not expose drag semantics actions equivalent to `SemanticsAction.moveCursorForwardByCharacter`/`dragDrop`, so accessibility parity regressed from Flutter’s stock widgets.

## Proposed Changes

### Phase 1 – Rebuild coordinator on top of `Drag`
1. Implement `CalendarDragAvatar` that extends `Drag`, mirrors `_DragAvatar`, and exposes calendar-specific payload (task snapshot, pointer offset, feedback size). The avatar stores `_enteredTargets` and reruns hit tests on every `update`.
2. Replace `CalendarDragHandle` with handles that wrap the avatar. `CalendarDragCoordinator.startSession` will construct a new avatar, keep a weak registry of active avatars, and expose `lastGlobalPosition`.
3. Hook into target registration: when a new delegate registers and an avatar is active, immediately re-dispatch `updateDrag` with the cached position so stationary pointers trigger `didEnter`.

### Phase 2 – Upgrade render targets
1. Refactor `RenderCalendarSurface` to implement a richer delegate protocol:
   - Provide `willAccept` to mirror `DragTarget.onWillAccept`.
   - Store candidate hover avatars so overlapping targets can reject/accept independently.
   - Supply `CalendarDragDetails` with both local and global offsets, pointer deltas, and task payload.
2. Rework `CalendarDragTargetRegion` to wrap children in a `RenderMetaData`-style proxy so widgets can participate in the same contract (sidebar bins, tab edges) without custom state objects.
3. Ensure `hitTest` continues to add `BoxHitTestEntry(this, …)` but also respects `HitTestBehavior.translucent` so drag hover survives through overlays.

### Phase 3 – Feedback + geometry alignment
1. Replace `_ensureDragOverlayInserted` with a leader/follower pair: assign each dragging tile a `LayerHandle<LeaderLayer>` and paint the feedback via a `FollowerLayer` in `paint()`, eliminating post-frame callbacks.
2. Persist the initial drag origin slot, pointer offset from top, and task height inside `TaskInteractionController`. Use those values to compute drop slots in `_computePreviewStart` / `_handlePointerUp`, guaranteeing the drop target aligns with the avatar center.
3. Normalize column width + narrowed width math so preview rectangles and final placement share identical calculations (no extra clamps when dropping).

### Phase 4 – Mobile tab + edge targets
1. Reintroduce tab switching as a standalone helper (e.g., `CalendarDragSwitcherController`) that listens to `CalendarDragCoordinator.dragActiveListenable` and `dragPositionListenable` instead of the deleted mixin. It should:
   - Spawn edge `CalendarDragTargetRegion`s that drive auto-switching.
   - Force a `rehit` when a tab swap completes so the new grid immediately receives `didEnter`.
2. Update `calendar_widget.dart` and `guest_calendar_widget.dart` to use the new controller instead of the missing mixin, keeping API limited to configuration (tab controller, duration thresholds).
3. Ensure unscheduled list → grid drags and grid → unscheduled (drop into sidebar) share the same coordinator events, eliminating per-platform branching.

### Phase 5 – Semantics and accessibility
1. Expose drag semantics on `CalendarTaskTileRenderRegion` (actions for starting/stopping drag, moving vertically/horizontally).
2. Surface drop target semantics on `RenderCalendarSurface` (announce hover column/day, allow keyboard-driven drop).

### Phase 6 – Testing & rollout
1. Add widget tests that simulate:
   - Unscheduled → grid drop on a constrained width layout (tab auto-switch).
   - Grid → unscheduled drop.
   - Drag preview alignment (verify task lands on intended slot).
2. Provide golden or screenshot tests for hover highlights to ensure narrowing and cell alignment remain intact.
3. Run `flutter analyze` and targeted `flutter test test/calendar/...` suites before landing each phase.

## Validation
- Manual reproduction on macOS (mobile width) following the user’s steps.
- Verify desktop drag remains unaffected (scheduled task reschedule and unschedule).
- Confirm no new `addPostFrameCallback` usages via `rg`.

## Open Questions / Risks
- Integrating with Flutter’s `Drag` API may surface gesture arena conflicts with existing listeners inside `CalendarTaskTileRenderRegion`; we must audit `_dragRecognizer` to avoid duplicate recognizers.
- Leader/follower feedback assumes overlay availability across tabs; we need to ensure the follower layer survives when the grid is removed from the tree mid-drag.
- Accessibility parity depends on how much of Flutter’s semantics machinery we replicate; might require additional render overrides.

## Milestones
1. **Week 1**: Implement `CalendarDragAvatar` + coordinator rehit logic; smoke test desktop/mobile drags.
2. **Week 2**: Upgrade render targets + feedback path; remove `addPostFrameCallback`.
3. **Week 3**: Restore tab switching, integrate new controller, add tests and semantics; finalize docs and cleanup.

