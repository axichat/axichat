## Critical instructions
- MUST enforce parity between the Guest and Sync calendars, except for in BLoCs and app bars. EVERY other widget must be reused between BOTH calendars so their UIs are IDENTICAL. Single source of truth widgets, ZERO code duplication across calendars. Every component should be resued in both calendars.
- Calendar sync piggy-backs off of XMPP messaging. Whenever we update the calendar, the stored model will update. We then serialize that stored model into text and send it to ourselves as an XMPP message so all our other devices can get it. These sync messages must only be consumed by the calendar and never show up in our self-chat.
- There are 3 buckets for tasks: scheduled, unscheduled, and reminder. Tasks are scheduled if they have a start time (must be given by the user - duration/end time have sane defaults), unscheduled if they have no start time or deadline, and reminder if they have a deadline but no start time.
- Scheduled tasks move to the slot in the grid corresponding to their start time.
- Tasks can be added quickly using natural language which we parse for key temporal data, priority, and location.
- This lets us add messages from a chat straight into the calendar with one press of a button.

## Calendar Feature Render Guidance

- When building or refactoring calendar surfaces (timelines, tabbed panes, animated cards), prefer custom `RenderBox` implementations to coordinate layout, painting, gestures, and semantics in one place.
- Do **not** rely on `addPostFrameCallback`, `findRenderObject`, or global keys for geometry. Compute measurements inside `performLayout` and drive animations from controller values like `TabContainer`'s `RenderTabFrame`.
- Keep the widget layer declarative: expose configuration only, delegate imperative work to render objects or dedicated services.
- Reference `docs/tab_container_study.md` before introducing new calendar UI to stay aligned with the `tab_container` approach.

## Render Pipeline Ground Rules

- All geometry lives in the render layer. Widgets configure; render objects measure, paint, and hit-test.
- Flutter contract: **constraints go down, sizes go up, parents set child offsets via `ParentData`.**
- Break complex layout into private helpers inside the `RenderBox`; never mirror layout logic in widgets or post-frame callbacks.
- Avoid `addPostFrameCallback`, `scheduleMicrotask`, `findRenderObject`, and global keys for measurement - use render objects and parent data instead.
