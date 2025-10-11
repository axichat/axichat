# Calendar Implementation Review

Each section below captures a feature or behavior present in the current calendar codebase. Add
notes beneath each heading to mark whether to keep, modify, or discard it.

## Models & Storage

### Checksum-Based Integrity

- Location: `lib/src/calendar/models/calendar_model.dart:17-76`
- Summary: `CalendarModel` maintains a SHA-256 checksum and recomputes on every mutation to detect
  conflicts and short-circuit sync when identical.
- Notes: smart, keep

### Per-Task Modified Timestamps

- Location: `lib/src/calendar/models/calendar_task.dart:33-73`,
  `lib/src/calendar/sync/calendar_sync_manager.dart:148-186`
- Summary: Merge logic compares `CalendarTask.modifiedAt` to determine last-write-wins at the task
  level.
- Notes: smart, keep

### Multi-Day Task Support

- Location: `lib/src/calendar/models/calendar_task.dart:37-104`
- Summary: Tasks track `endDate`/`daySpan`; helper methods compute effective spans for backwards
  compatibility.
- Notes: daySpan is stupid

### Duration Hive Adapter

- Location: `lib/src/calendar/models/duration_adapter.dart`
- Summary: Custom Hive adapter persists `Duration` values directly.
- Notes: adapters in general are very important to get right

### Priority Enum (critical/important/urgent/none)

- Location: `lib/src/calendar/models/calendar_task.dart:11-124`
- Summary: Priority enum includes "critical" and defaults to blue for none.
- Notes: critical should be emergent when important and urgent are true, not explicit. remove

## Sync & Integration

### JSON-in-Body Sync Messages

- Location: `lib/src/xmpp/message_service.dart:463-503`,
  `lib/src/calendar/models/calendar_sync_message.dart`
- Summary: Calendar diff/full messages transmitted as JSON under `calendar_sync` key; strict sender
  filter ensures only self JID accepted.
- Notes: smart, but try to come up with a better way

### Message Types & Checksum Conflicts

- Location: `lib/src/calendar/models/calendar_sync_message.dart:10-50`,
  `lib/src/calendar/sync/calendar_sync_manager.dart:95-138`
- Summary: Supports `calendar_request`, `calendar_full`, `calendar_update`; uses checksum to detect
  conflicts before merging.
- Notes: detecting checksum is smart

### XML Extension Builder (Unused)

- Location: `lib/src/calendar/models/calendar_sync_message.dart:54-120`
- Summary: Provides XMPP extension serialization, though current flow uses plain JSON.
- Notes: if you use json then remove this, unless xml would be better

## Bloc & State

### Hive Box Watchers

- Location: `lib/src/calendar/bloc/base_calendar_bloc.dart:24-69`
- Summary: Base bloc listens to Hive `watch()` and reloads model on every change.
- Notes: this is bad. there is no need to watch a box. just emit the state and it will be
  saved without us doing anything. but you MUST still create separate storage instances by
  implementing the "Storage" interface from hydrated_bloc library. provide an encrypted instance to
  the constructor
  of CalendarBloc, and an unencrypted instance to the constructor of GuestCalendarBloc.

### Derived Reminders & Next Task

- Location: `lib/src/calendar/bloc/base_calendar_bloc.dart:45-66`, `325-349`
- Summary: State tracks `dueReminders` and `nextTask` automatically from the model.
- Notes: explicitly keeping track in dueReminders is stupid. it should automatically happen when the
  deadline gets close.

### Domain Exceptions

- Location: `lib/src/calendar/models/calendar_exceptions.dart`
- Summary: Custom exception hierarchy for validation/storage/sync/conflict errors.
- Notes: custom exceptions are good. make sure to actually integrate them and program in proper
  responses/logic/retries

### Manual Hive Persistence (Non-HydratedBloc)

- Location: `lib/src/calendar/bloc/base_calendar_bloc.dart:74-186`
- Summary: Blocs write directly to Hive; persistence mirrors HydratedBloc behavior but is
  hand-rolled.
- Notes: this is bad. just use hydratedbloc and forget about manually persisting, watching boxes.
  just fire and forget. but you MUST still create separate storage instances by implementing the "
  "Storage" interface from hydrated_bloc library. provide an encrypted instance to the constructor
  of CalendarBloc, and an unencrypted instance to the constructor of GuestCalendarBloc.

## UI & Interaction

### Multi-Day Overlay & Horizontal Resize

- Location: `lib/src/calendar/view/calendar_grid.dart:180-210`, `605-648`;
  `lib/src/calendar/view/calendar_event_widget.dart:296-324`
- Summary: Multi-day tasks render in an overlay lane with drag/resize support across days.
- Notes: overlay lane is dumb. horizontal resizing should be intuitive, making a task occupy the
  same relative cells, but in additional days depending how far it is dragged either way. if
  multiple tasks occupy the same cell, they should be narrowed to fit SIDE-BY-SIDE, not overlayed.

### Overlap Grouping for Concurrent Events

- Location: `lib/src/calendar/view/calendar_grid.dart:820-917`
- Summary: Tasks that collide in time are assigned columns for side-by-side layout.
- Notes: YES

### Drag-to-Unscheduled Area

- Location: `lib/src/calendar/view/task_sidebar.dart:744-820`
- Summary: Dropping an event onto the unscheduled list clears its scheduled time.
- Notes: YES

### Resizable Sidebar & Deadline UI

- Location: `lib/src/calendar/view/task_sidebar.dart:1-274`, `806-857`
- Summary: Sidebar width adjustment, overlay deadline picker, and status styling (overdue/due soon).
- Notes: YES

### Smart Natural Language Parser

- Location: `lib/src/calendar/utils/smart_parser.dart`
- Summary: Parses expressions like "3pm tomorrow", "next Friday", "in 2 hours", plus location hints.
- Notes: YES. eventually i would like to use a local AI to do this.

### Animated Slots & Event Hover Effects

- Location: `lib/src/calendar/view/calendar_grid.dart:116-140`, `520-660`;
  `lib/src/calendar/view/calendar_event_widget.dart:24-170`
- Summary: Animated view transitions, hover highlighting, and task drag feedback.
- Notes: YES. make the calendar task beautiful, responsive and animated, but intuitively.

## UX & Feedback

### Sync Controls & Status

- Location: `lib/src/calendar/view/sync_controls.dart`,
  `lib/src/calendar/utils/time_formatter.dart:9-22`
- Summary: Buttons for request/push, status icons, last-synced text, toasts/snackbars.
- Notes: yes, but they should actually work.

### Error & Toast Handling

- Location: `lib/src/calendar/view/error_display.dart`,
  `lib/src/calendar/view/feedback_system.dart`, used in widgets.
- Summary: Centralized error banners and feedback overlays.
- Notes: yes, but they should actually work.

## Routing & Injection

### Auth Calendar Injection & Toggle

- Location: `lib/src/home_screen.dart:120-180`
- Summary: `CalendarBloc` provided in `HomeScreen`, opened via `ChatsCubit.openCalendar` and shown
  in `AxiAdaptiveLayout` secondary pane; sync callback wired through `XmppService`.
- Notes: yes

### Guest Calendar Route & CTA

- Location: `lib/src/login_screen.dart:71-79`, `lib/src/routes.dart:91-101`,
  `lib/src/calendar/guest/guest_calendar_widget.dart`
- Summary: `/guest-calendar` route with guest banner and “Sign Up to Sync” button.
- Notes: yes

