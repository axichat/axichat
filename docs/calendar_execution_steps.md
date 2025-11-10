# Calendar/Reminder Feature — Execution Guide

This is a precise, two‑stage implementation plan to build a beautiful, responsive calendar/reminder/schedule feature. It separates local functionality from sync so UI can ship first.

## Stage 0 — Pre‑Flight

- Create a feature branch and ensure basic commands run:
  - `flutter pub get`
  - `dart run build_runner build --delete-conflicting-outputs`
  - `flutter analyze`
  - `flutter test`
- Confirm platform lints and style are enforced by `analysis_options.yaml`.

## Parallel Strategy — Keep Legacy, Build `calendar2`

- Preserve all existing calendar code under `lib/src/calendar/` for reference and fallback.
- Implement the new calendar under `lib/src/calendar2/` with mirrored structure (models, bloc, view, utils, sync).
- Introduce a minimal feature flag to switch between legacy and new calendar without code removal:
  - Option A (compile/runtime flag): a small `CalendarConfig` that exposes `useNewCalendar` (read from env/build‑flavor or a constant for now).
  - Option B (DI): inject a `CalendarFactory` that provides either legacy or new blocs/widgets based on configuration.
- Wire the switch only at container boundaries (no changes inside shared dumb widgets):
  - Auth: in the adaptive layout secondary pane, choose `CalendarWidget2` + `CalendarBloc2` when enabled; otherwise legacy.
  - Guest: either reuse `/guest-calendar` with an internal switch to render `GuestCalendarWidget2`, or add a parallel route `/guest-calendar2` for explicit comparison.
- Document how to toggle (one line), so you can flip between implementations instantly during review and tests.

### Toggle Wiring — calendar vs calendar2

1) Configuration (one place)
- Add `lib/src/calendar2/config/calendar_config.dart` with:
  - `abstract class CalendarConfig { bool get useNewCalendar; }`
  - `class EnvCalendarConfig implements CalendarConfig` using `const bool.fromEnvironment('CALENDAR2', defaultValue: false)`.
- Allow override via constructor for tests.
- Toggle at build time with `--dart-define=CALENDAR2=true`.

2) Providers/Factories (DI boundary)
- Add `lib/src/calendar2/wiring/calendar_factory.dart` exposing:
  - `Widget buildAuthCalendar({required BuildContext context})` → returns either legacy `CalendarWidget` wrapped with legacy providers or `CalendarWidget2` wrapped with `CalendarBloc2` and its Storage.
  - `Widget buildGuestCalendar()` → returns either legacy `GuestCalendarWidget` or `GuestCalendarWidget2` similarly.
  - `List<SingleChildWidget> buildAuthCalendarProviders(BuildContext context)` → returns the appropriate bloc providers for the chosen implementation (legacy/new).
- These methods encapsulate the selection logic; containers call them instead of directly referencing calendar classes.

3) Container Wiring (no widget internals changed)
- Authenticated view (adaptive layout secondary pane):
  - Replace direct `CalendarWidget` usage with `CalendarFactory.buildAuthCalendar(context: context)`.
  - Replace manual bloc provider glue with `CalendarFactory.buildAuthCalendarProviders(context)`.
- Guest route:
  - Option A (single route): keep `/guest-calendar`, and its page builds `CalendarFactory.buildGuestCalendar()`.
  - Option B (parallel route for A/B): add `/guest-calendar2` that always selects the new calendar; keep `/guest-calendar` on legacy.

4) Open/Toggle Behavior
- Keep `ChatsCubit.toggleCalendar()` unchanged; the container logic decides which implementation to show based on config.
- Ensure both implementations accept the same external events (date/view changes) via their wrappers so UI controls stay consistent.

5) Sync Injection (Stage 2 only)
- Add methods in `CalendarFactory` to provide sync plumbing for the authenticated path:
  - `void attachAuthSync(XmppService xmpp)` → registers inbound callback for legacy or new sync manager, depending on config.
  - `Future<void> sendSync(String message)` → abstraction used by the chosen sync manager.
- Containers call these once when setting up the authenticated experience; no branching scattered around.

6) QA and Operability
- Toggling methods:
  - Build‑time: `flutter run --dart-define=CALENDAR2=true` (uses new), omit to use legacy.
  - Test‑time: inject a `TestCalendarConfig(useNewCalendar: true/false)` into `CalendarFactory`.
- Validation:
  - Verify both guest/auth paths flip correctly with the same toggle.
  - Ensure there’s no shared singleton state between implementations (e.g., distinct hydrated storage keys/namespaces: `calendar2_*`).

7) Naming Conventions in `calendar2`
- Mirror legacy folder layout for easy diffing:
  - `lib/src/calendar2/models/`, `bloc/`, `view/`, `utils/`, `sync/`, `wiring/`
- Suffix classes with `2` only at the container edge (e.g., `CalendarWidget2`, `GuestCalendarWidget2`, `CalendarBloc2`). Inside modules prefer clean names (`Task`, `Model`) scoped to the `calendar2` namespace.

8) Rollback Plan
- Because legacy remains intact, rollback is one toggle change.
- Avoid editing legacy imports/usages except where replaced by `CalendarFactory` to keep diffs small and reversible.

## Stage 1 — Local Core (Guest + Auth)

1) Models
- Create `lib/src/calendar/models/calendar_task.dart` with:
  - Fields: `id` (uuid), `title`, `description?`, `scheduledStart?` (DateTime), `duration?` (Duration), `endDate?` (DateTime, spans across days), `deadline?` (DateTime), `isAllDay=false`, `priority` flags: `important` (bool), `urgent` (bool), `tags` (List<String>), `location?`, `completed=false`, `createdAt`, `updatedAt`.
  - Methods: `toJson()`, `fromJson()`, `copyWith()`, computed `isScheduled`, `priorityColor` (mapping below), multi‑day helpers (effective end/start, span days count).
  - Update `updatedAt` on every meaningful mutation.
- Create `lib/src/calendar/models/calendar_model.dart` with:
  - Fields: `version`, `lastUpdated`, `selectedDate`, `view` (enum: day|week|month), `tasks` (Map<String, CalendarTask>).
  - Mutators: `addTask()`, `updateTask()`, `deleteTask()`, each bump `lastUpdated` and task `updatedAt`.
- Provide robust type adapters:
  - `lib/src/calendar/models/duration_adapter.dart` (Duration → microseconds)
  - Register adapters at app init.

Deliverables
- Models compile; JSON adapters/codegen generated.
- `dart run build_runner build --delete-conflicting-outputs` succeeds.

2) Hydrated Storage (no box watchers)
- Implement two Hydrated Storage instances:
  - Authenticated: AES‑encrypted Hive storage under box `calendar`.
  - Guest: Unencrypted Hive storage under box `guest_calendar`.
- Wrap via the Hydrated `Storage` interface; expose simple factories:
  - `lib/src/calendar/storage/auth_calendar_storage.dart`
  - `lib/src/calendar/storage/guest_calendar_storage.dart`
- DO NOT watch Hive boxes directly; persistence flows through HydratedBloc only.

Checks
- Can initialize each storage independently and read/write a dummy payload.

3) Bloc layer
- Create `lib/src/calendar/bloc/calendar_event.dart` with events:
  - `started`, `errorCleared`, `viewChanged(view)`, `dateSelected(date)`
  - `quickTaskAdded(text, description?, deadline?, important?, urgent?)`
  - `taskAdded(title, scheduledStart?, description?, duration?)`
  - `taskUpdated(task)`, `taskDeleted(taskId)`, `taskCompleted(taskId, completed)`
  - `taskDropped(taskId, time)`, `taskResized(taskId, startHour, durationHours, endDate?)`
  - `dayViewSelected(dayIndex)`, `taskPriorityChanged(taskId, important, urgent)`
- Create `lib/src/calendar/bloc/calendar_state.dart` with:
  - Fields: `model`, `isLoading`, `error?`, `viewMode`, `selectedDate`.
  - Derived getters: `unscheduledTasks`, `scheduledTasks`, `weekStart`, `weekEnd`, `tasksForSelectedWeek`, `tasksForSelectedDay`.
  - Do not persist ephemeral “due soon/next task” lists; compute or notify at runtime.
- Create `lib/src/calendar/bloc/calendar_bloc.dart` and `guest_calendar_bloc.dart`:
  - Both extend HydratedBloc with the same `Event/State` API.
  - Inject proper Storage (encrypted for auth, unencrypted for guest).
  - Implement reducers with optimistic updates; update `updatedAt` consistently.
  - No direct Hive box access; no streams/watchers.

Checks
- Hydrated restore persists and reloads model across restarts.
- `bloc_test` can assert event→state transitions for add/update/delete/drag/resize.

4) Routing & Entry Points
- Authenticated calendar:
  - Add an `openCalendar` boolean to the chats/app state (e.g., a cubit) and a `toggleCalendar()` action.
  - When `openCalendar` is true, render the calendar in the secondary pane of the adaptive layout.
  - Provide `CalendarBloc` above the calendar view with encrypted Storage.
- Guest calendar:
  - Add route `/guest-calendar` from the login screen.
  - Provide `GuestCalendarBloc` with unencrypted Storage scoped to this route.

Acceptance
- From login screen: a button opens guest calendar route.
- From main app: toggling shows the authenticated calendar in the secondary pane.

5) Presentational (dumb) widgets
- All widgets take `state` + callbacks; no bloc lookups inside.
- Create under `lib/src/calendar/view/`:
  - `calendar_navigation.dart` — previous/next/today, week/day title, dropdown month picker; props: `state`, `onDateSelected`, `onViewChanged`, `onErrorCleared`.
  - `calendar_grid.dart` — week/day grid; drag targets, overlap‑aware layout, 15‑minute slots in day view; props: `state`, `bloc`, `onEmptySlotTapped`, `onTaskDragEnd`, `onDateSelected`, `onViewChanged`.
  - `calendar_event_widget.dart` — task card with hover, drag, and vertical/horizontal resize handles; props: task + layout metrics + callbacks.
  - `task_sidebar.dart` — resizable sidebar with quick‑add form, optional description, optional deadline, important/urgent toggles, unscheduled list as a drag target; emits proper callbacks to parent.
  - `quick_add_modal.dart`, `edit_task_dropdown.dart` — forms for quick creation and editing.
- Multi‑day events span across day columns in-grid; horizontal resize extends/reduces the span; events colliding in time render side‑by‑side (narrowed columns).

Visual tokens
- Define color mapping constants (applied consistently):
  - important+urgent = red, important+not urgent = green, not important+urgent = orange, neither = grey.
- Ensure responsiveness: mobile (stacked), tablet/desktop (dual pane); smooth animations.

6) Natural language parser (pluggable)
- Create `lib/src/calendar/utils/smart_parser.dart`:
  - Parse times (2pm/14:00), relative days (today/tomorrow), weekdays, “next/this” week/month, “in X hours/days”, and location hints.
  - Return a structured result; keep the module swappable for a future ML parser.

7) Recurrence (initial)
- Create a lightweight `Recurrence` model and expansion helpers for week/day views:
  - Types: none|daily|weekly|weekdays|biweekly|monthly|custom
  - Fields: `interval`, `byWeekday?`, `until?`, `count?`, `exceptions[]`, `overrides[]`.
- Expand occurrences lazily for visible ranges.

8) Reminders & notifications
- Integrate with the app’s local notification service:
  - On deadline add/update: schedule T‑24h, T‑1h, T‑15m, and at‑due notifications.
  - Provide snooze (5/15/30 minutes) and dismiss actions.
  - On hydration restore: re‑schedule outstanding alarms.
- Do not store derived “due soon” lists; compute UI indicators from current time vs deadline.

9) QA for Stage 1
- Unit tests: recurrence expansion, parser basics, reducers for add/update/delete/drag/resize/priority/complete.
- Widget tests: grid drag‑drop, vertical/horizontal resize, view toggles, quick‑add, sidebar resize, unscheduled drag target.
- Integration tests: guest route UX; authenticated calendar toggle; persistence across restart; notifications scheduled and restored.

## Stage 2 — Sync (Authenticated Only)

10) Envelope & serialization
- Define a JSON envelope sent via normal XMPP messages:
  - `{ type: 'calendar_request'|'calendar_full'|'calendar_update', timestamp: ISO8601, ops: [ { op: 'add'|'update'|'delete', taskId, patch? } ] }`
- Implement serializer/validator helpers under `lib/src/calendar/sync/`.

11) Sync manager
- Create `lib/src/calendar/sync/calendar_sync_manager.dart`:
  - Outbound: on local change, produce minimal diffs (per task), debounce/batch; provide manual actions to send `calendar_request`/`calendar_full`.
  - Inbound: accept messages only from our own bare JID; never render raw payloads in chats; for each op apply LWW using task `updatedAt`; equal timestamps → no‑op; for full messages, iterate tasks and apply the same rule.
  - Report non‑fatal errors to logs, not UI.

12) XMPP integration
- Provide two injection points without UI coupling:
  - A function to send a calendar sync message to other logged‑in devices (normal message path).
  - A callback registration to receive calendar envelopes and pass to the sync manager.
- Ensure both are only active when authenticated.

13) UI (auth only)
- Add sync controls to the authenticated calendar container:
  - Buttons: “Request Update” (pull) and “Push Update” (full or pending diffs).
  - Status indicator: syncing/failed/success with last‑synced relative time.

14) QA for Stage 2
- Unit tests: diff generation/apply; LWW by task `updatedAt`; invalid‑sender rejection.
- Integration: simulate inbound/outbound messages; manual push/request flows; verify raw payloads never surface in chats.

## Acceptance Criteria

- Stage 1
  - Identical UI/UX for guest and auth calendars; only differences: guest banner and absence of sync controls.
  - Quick‑add, drag‑drop, edge‑resize, multi‑day spanning, recurrence, priority colors, and reminders all work and persist.
  - Hydration restores tasks and re‑schedules deadlines; analyzer/tests clean.
- Stage 2
  - Authenticated calendars sync reliably across devices; LWW by task `updatedAt` resolves conflicts; non‑self senders ignored.
  - Manual push/request operates; raw JSON never appears in chats; no data loss in common conflict scenarios.

## Developer Workflow

- After model or route generation: `dart run build_runner build --delete-conflicting-outputs`
- Before commit: `dart format .` then `flutter analyze` then `flutter test`
- Keep shared widgets dumb and callback‑based; containers attach blocs and wire callbacks.
- Never watch Hive boxes; all persistence flows through HydratedBloc Storage.

## Accessibility & Keyboard

- Semantics & Roles
  - Add Semantics to all interactive parts: event tiles, grid slots, resize handles, sidebar items, buttons.
  - Event tile label example: "Event: {title}, {start–end}, {priority}, {completed|not completed}".
  - Empty time slot semantics: "Empty {15‑minute|1‑hour} slot at {time} on {day}" with role=button.
  - Drag targets (timeline/inbox): announce "Drop to schedule here" / "Drop to unschedule" when focused.

- Focus & Traversal
  - Group focus with FocusTraversalGroup; define order: navigation bar → sidebar input → unscheduled list → grid → floating actions.
  - Provide FocusNode for the grid selection; show a visible focus ring (high‑contrast outline) and keep it consistent across themes.
  - Ensure Tab/Shift+Tab traversal reaches all actionable controls; avoid focus traps.

- Keyboard Shortcuts (Shortcuts/Actions)
  - Navigation within grid:
    - ArrowUp/Down: move selection by 15m (day) or 1h (week).
    - Shift+ArrowUp/Down: move by 60m regardless of view.
    - ArrowLeft/Right: previous/next day column (stays at same time); in day view, horizontal arrows do nothing.
    - PageUp/PageDown: previous/next week (or day when in day view).
    - Home/End: jump to start/end of current day.
    - T: jump to Today.
  - CRUD on selection/event:
    - Enter: quick‑add at current slot; Ctrl/Cmd+Enter: confirm.
    - Escape: close modal/edit dropdown or clear selection.
    - E: edit selected event; D or Space: toggle completed; Delete/Backspace: delete with confirmation.
  - Resizing & Multi‑day span:
    - Alt+ArrowUp/Down: shrink/grow duration by 15m (Shift+Alt for 60m steps).
    - Alt+ArrowLeft/Right (when multi‑day): extend/reduce span across adjacent days.
  - Move without drag:
    - M: begin move of selected event; use arrows to pick new slot; Enter to drop.

- Screen Reader Feedback
  - Announce key state changes with `SemanticsService.announce` (e.g., "Event moved to 3:15 PM Friday", "Task marked completed").
  - Ensure live region updates for error banners and sync status to be read once.

- Touch & Pointer
  - Maintain large hit targets (>= 44px) for resize handles and buttons.
  - Long‑press acts as hover on touch devices for showing resize handles and context actions.

- Testing
  - Widget tests: verify keyboard handlers move selection, open quick‑add, edit, resize, and move without mouse.
  - Semantics tests: ensure accessible labels exist for slots/events and state changes are announced.

## Notes

- Two distinct calendars: guest (route `/guest-calendar`, unencrypted, no sync) and authenticated (toggle state, encrypted, sync‑enabled). Both share identical UI components.
- Security: accept sync envelopes only from our own JID; silently drop others and do not leak payloads to UI.
- Color mapping must be applied consistently to chips, events, and notifications.
