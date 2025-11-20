# Working Assumptions for notifications

- Manages in-app and system notifications (message alerts, calls, calendar reminders) and overlays/snackbars.
- Likely bridges platform channels for push/local notifications and ties into routing for tap actions.
- Should respect mute/do-not-disturb per chat; may aggregate unread counts for badges.
- Tests: unit tests for notification payload parsing; widget tests for overlay visibility and acknowledgement flows.
- Before edits: consider permission prompts, background handling, and interaction with app lifecycle.
