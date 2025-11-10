# Calendar Feature Plan

- Audit existing `storage` models, calendar routes, and notification services to confirm gaps; align with project BLoC patterns and security constraints before introducing new layers.
- Preserve the Axichat loop: widgets dispatch only to BLoCs; BLoCs manage state and persist via HydratedBloc with custom Storage (no box watchers). Events update state; hydration persists to encrypted Storage (authenticated) or unencrypted Storage (guest) and restores on launch.
- Define the task domain model covering unscheduled reminders, scheduled blocks, frictionless recurrence toggles for routines, overrides, and drag-adjustable durations; document schema updates and plan HydratedBloc persistence backed by custom Storage (no Drift, no direct box watching).
- Design the service layer: task repository (Hive box storage only; AES-encrypted when authenticated) with future XMPP sync hooks, a scheduling engine for recurrence expansion and conflict hints, and a reminder dispatcher wired into the existing notification infrastructure.
- Specify XMPP sync strategy for authenticated users only: send/receive calendar model diffs as normal XMPP messages (OMEMO-encrypted per app defaults) only between our own JIDs, ignore foreign senders, apply last-write-wins at task level using `updatedAt`, and silently merge incoming diffs without surfacing raw payloads in chat.
- Architect the presentation flow: calendar overview BLoC for month/week/day state, schedule timeline BLoC for time-block interactions, inbox BLoC for unscheduled tasks with deadlines; establish shared events and debounced persistence.
- Derive bloc structure per `BLOC_GUIDE.md`: authenticated and guest flows use distinct blocs backed by their respective Hydrated Storage; keep shared UI pieces "dumb"—data/callback based—so they can be wrapped by either `CalendarBloc` or `GuestCalendarBloc` without provider-type coupling.
- Hardcode the calendar conversation at the top of the chat list and support manual "push" and "request" sync triggers that fan out diffs to other devices when logged in.
- Maintain twin calendar modes: guest calendar surfaced via a button directly under the login action with unencrypted Hive storage and no sync (served from `/guest-calendar` route), authenticated calendar using AES-encrypted Hive plus sync (opened via `ChatsCubit.toggleCalendar()` and `openCalendar` state); both reuse the same presentational widgets via callbacks so styling or behavior tweaks instantly apply to both.
 - Parallel rollout: keep legacy under `lib/src/calendar/` and build the new implementation under `lib/src/calendar2/`. Gate selection behind a small feature flag or DI factory so you can switch the app wiring (containers/blocs/widgets) without altering shared dumb widgets.
- Craft a responsive UI: dual-pane layout (tasks inbox + timeline) for large screens and stacked layout for mobile; implement quick-add text field, one-tap recurrence controls, drag/drop from inbox to timeline, edge-resize handles, keyboard shortcuts, accessible semantics.
- Implement interaction details: optimistic UI updates with undo, snap-to-interval logic, overlap indicators, contextual actions (set deadline, mark done, convert to routine) using cascade operators and extension helpers per repo style; treat unscheduled deadline tasks as reminders with escalating warnings, local notifications, and app badges as due time approaches.
- Encode task priorities via an urgent/important matrix: important+urgent (red), important+not urgent (green), not important+urgent (orange), not important+not urgent (grey); reflect colors consistently across inbox chips, timeline blocks, and notifications.
- Integrate reminders: schedule local notifications on deadline and time-block changes, ensure hydration restores pending alarms, and surface snooze/dismiss actions consistent with notification CLAUDE guidance.
- Plan QA: unit tests for recurrence calculations and BLoC reducers (`bloc_test`), widget tests for drag/drop and resize flows, golden tests for responsive breakpoints, and integration tests covering creation-to-notification journey.

## Model Details

- `CalendarTask` fields (minimum): `id` (uuid), `title`, `description?`, `scheduledStart?`, `duration?`, `endDate?` (multi-day span), `deadline?`, `isAllDay=false`, `recurrence?` (see below), `priority` flags (`important`, `urgent`), `tags=[]`, `location?`, `completed=false`, `createdAt`, `updatedAt`.
- `Recurrence` shape: `type` (`none|daily|weekly|weekdays|biweekly|monthly|custom`), `interval=1`, `byWeekday` (set of `Mon..Sun`), `until?`, `count?`, `exceptions=[]` (dates), `overrides=[]` (date→time adjustments).
- `CalendarModel` fields: `version`, `tasks` (Map<id, CalendarTask>), `selectedDate`, `view` (`day|week|month`), `lastUpdated`.
- Storage: robust adapters for custom types (e.g., duration). Provide two Hydrated Storage instances: encrypted for authenticated users and unencrypted for guest. Persist through Storage (Hive-backed), do not watch boxes.

## Sync Protocol (Authenticated Only)

- Envelope schema (JSON over normal XMPP message body):
  - `type`: `calendar_update | calendar_full | calendar_request | calendar_push`
  - `timestamp`: ISO 8601
  - `ops`: list of `{ op: add|update|delete, taskId, patch? }`
- Security checks: accept only from our own bare JID; discard others silently. Never display raw payloads in chat UI; route to the sync handler only.
- Merge policy: for task updates and full-state messages, apply last-write-wins by comparing each task's `updatedAt` with local. Equal timestamps are treated as no-ops with optional diagnostics. Handle out-of-order delivery by trusting per-task `updatedAt`.
- Manual triggers: expose "Push Update" (broadcast current diffs/full) and "Request Update" (ask other devices for latest); available only when logged in.
  - Transport: begin with JSON-in-body; keep the sync layer transport-agnostic to allow moving to an XMPP extension payload later without touching domain logic.

## Reminders & Notifications

- Unscheduled tasks with `deadline` act as reminders with escalating notifications: default schedule at T-24h (if applicable), T-1h, T-15m, and at due time; provide snooze actions (5/15/30 minutes) and dismiss.
- Map priority matrix to notification channels/importance (where supported); reflect badge count for overdue tasks; reschedule alarms on app restart via hydration restore.

## Bloc & Routing

- Authenticated: `CalendarBloc` provided under the main app tree; calendar opened via `ChatsCubit.toggleCalendar()` and `openCalendar` flag; shown in the `AxiAdaptiveLayout` secondary pane; persistence via encrypted Hydrated Storage.
- Guest: `GuestCalendarBloc` scoped to route `/guest-calendar` and launched from a button under the login form; no sync; persistence via unencrypted Hydrated Storage.
- Shared widgets remain dumb and callback-driven; container widgets (route/secondary pane) adapt them to either bloc.

## Interaction & UI Specifics

- Week/day grid: hourly slots for week view; 15-minute slots for day view; drag from inbox to schedule; edge-resize with snapping; overlap-aware layout. Multi-day events span across day columns directly in-grid (no separate overlay lane). Horizontal resizing extends or reduces the span across adjacent days; overlapping items narrow side-by-side.
- Quick-add: single text field supporting natural language (“3pm next Fri”, “every weekday”, “due in 2h”); minimal taps to set recurrence. Keep the parser pluggable to allow a future local ML replacement.
- Color coding: important+urgent=red, important+not urgent=green, not important+urgent=orange, not important+not urgent=grey; apply across chips, events, and reminders.

## Testing Milestones

- Unit: recurrence expansion, natural language parsing, diff merge (security + LWW by task `updatedAt`), priority color mapping.
- Widget: drag/drop scheduling, resize handles, view toggles, quick-add flows, guest vs. auth containers with dumb widgets.
- Integration: multi-device sync simulation (own JID only), manual push/request, hydration restoring notifications, chat list toggle behavior, guest route isolation.

## Actionable Checklist (Staged)

### Stage 1 — Local Core (Guest + Auth)

- Models & Storage
  - [ ] Define `CalendarTask` and `CalendarModel`; add robust adapters for custom types (e.g., duration) and JSON serialization.
  - [ ] Implement two Hydrated Storage instances: encrypted for authenticated users, unencrypted for guest; wire them into the respective blocs.
  - [ ] No direct box watchers; persistence flows through HydratedBloc Storage.

- Blocs
  - [ ] Implement `CalendarBloc` (auth) and `GuestCalendarBloc` (guest), both as HydratedBlocs using the configured Storage; no box streams.
  - [ ] Events: `started`, `quickTaskAdded`, `taskUpdated`, `taskDeleted`, `taskCompleted`, `taskDropped`, `taskResized`, `dayViewSelected`, `viewChanged`, `deadlineSet`, `recurrenceSet`, `prioritySet`.
  - [ ] State: selected date/view, computed getters for unscheduled vs scheduled tasks, and derived week/day collections. Do not persist ephemeral “due soon/next task” lists in state; compute or notify at runtime.

- Shared, Dumb UI Components (callback-based)
  - [ ] `CalendarNavigation`, `CalendarGrid`, `TaskSidebar`, `CalendarEventWidget`, `TaskTile`, `QuickAddModal`, `EditTaskDropdown` accept `state` and callbacks; no bloc lookups.
  - [ ] Presentational widgets live under `lib/src/calendar/view/` and do not reference `CalendarBloc`/`GuestCalendarBloc` directly.

- Containers & Routing
  - [ ] Authenticated container: provide `CalendarBloc` under the main tree; open via `ChatsCubit.toggleCalendar()` (`openCalendar` flag) in `AxiAdaptiveLayout` secondary pane.
  - [ ] Guest container: route `/guest-calendar` from a button under the login form; provide `GuestCalendarBloc` scoped to that route.

  - [ ] Quick-add input with basic natural language parsing (times, “tomorrow/next Fri”, simple recurrence phrases).
  - [ ] Drag-and-drop: from unscheduled sidebar to timeline; edge-resize with 15-minute snapping; overlap-aware layout; multi-day horizontal resizing extends across days.
  - [ ] Recurrence toggles for routines; store rules in `recurrence` and expand on demand for views.
  - [ ] Priority matrix colors: red (important+urgent), green (important+not urgent), orange (not important+urgent), grey (neither) across chips, events, notifications.
  - [ ] Reminders for `deadline` tasks: schedule local notifications T-24h/T-1h/T-15m/at-due; add snooze/dismiss; restore on hydration; trigger visuals automatically as deadlines approach rather than tracking explicit “due” lists in bloc state.

- Quality & Tests
  - [ ] `dart run build_runner build --delete-conflicting-outputs` after model changes.
  - [ ] `dart format .` and `flutter analyze` clean.
  - [ ] Unit tests: recurrence expansion, parser basics, bloc reducers.
  - [ ] Widget tests: drag/drop + resize, view toggles, quick-add flow, guest vs auth containers wiring.
  - [ ] Integration tests: guest route UX, authenticated calendar toggle, persistence across restarts.

### Stage 2 — Sync (Authenticated Only)

- Sync Envelope & Serialization
  - [ ] Define JSON envelope: `{ type, timestamp, ops: [ { op, taskId, patch } ] }`.
  - [ ] Implement serializer/deserializer and validators; keep transport-agnostic API to allow future XMPP extension payloads.

- Xmpp Integration
  - [ ] Wire `CalendarSyncManager` to `XmppService` to receive messages destined to our own bare JID and to send diffs as normal XMPP messages (OMEMO-encrypted by default).
  - [ ] Ensure raw payloads never render in chat; route to sync manager only.

- Outbound Sync
  - [ ] On local changes, produce minimal diffs; debounce/batch sends.
  - [ ] Add manual controls in authenticated calendar UI: “Push Update” (full/diffs) and “Request Update”.

- Inbound Sync & Merge
  - [ ] Accept only from our own bare JID; silently drop others.
  - [ ] For updates and full-state, merge by per-task `updatedAt` (LWW); equal timestamps → no-op.
  - [ ] Persist merged model via bloc persistence; bloc emits updated state.

- Tests & Observability
  - [ ] Unit: diff generation/apply, LWW by task `updatedAt`, invalid-sender rejection.
  - [ ] Integration: simulated inbound/outbound messages, manual push/request flows.
  - [ ] Logging: diagnostics without leaking JIDs or content; follow security guidance.

### Definition of Done

- Stage 1 DoD
  - [ ] Identical UI/UX for guest and auth calendars, differing only in sync controls and guest indicator.
  - [ ] All local interactions (quick-add, drag/drop, resize, recurrence, reminders, priority colors) work and persist.
  - [ ] Tests pass; analyzer clean; hydration restores reminders.

- Stage 2 DoD
  - [ ] Authenticated calendars sync across devices via XMPP diffs; last-write-wins enforced by task `updatedAt`.
  - [ ] Manual push/request available; raw JSON never surfaces in chats; non-self senders ignored.
  - [ ] Sync tests pass and no data loss occurs under common conflict scenarios.
