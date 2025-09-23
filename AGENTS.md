# Repository Guidelines

## Project Structure & Module Organization
- Flutter sources live in `lib/`; domain layers such as `lib/src/xmpp`, `lib/src/chat`, and `lib/src/storage` mirror the mixin architecture used by `XmppService`.
- Database models and query accessors are defined under `lib/src/storage/models`; rerun `dart run build_runner build --delete-conflicting-outputs` whenever you touch these types so generated files stay in sync.
- UI elements that teammates monitor (operation overlays, notifications) sit in `lib/src/notifications` and are surfaced through `lib/src/app.dart`.

## Build, Test, and Development Commands
- USE THE DART MCP, if that is broken then use the following as fallbacks:
- `flutter run` spins up the app; pass `--flavor dev` if you need the staging config.
- `dart format .` then `dart analyze` before sending patches to keep lints predictable.
- `dart test` runs the full suite; scope to a module with `dart test test/xmpp/chats_service_test.dart` for quicker iteration.
- When storage models change, run `dart run build_runner build --delete-conflicting-outputs` to refresh Drift and Freezed outputs.

## Coding Style & Naming Conventions
- Always read every `CLAUDE.md` in your working directory and its parents before editing; they override defaults.
- Prefer explicit types, exhaustive `switch` statements, and intent-revealing names (`checkOmemoSupport`, `startOmemoOperation`).
- Keep logging consistent by using the existing `Logger` instances; never drop `print` calls into production code.
- UI widgets should remain stateless where possible; promote shared styling through the theme extensions already defined in `lib/src/app.dart`.

## Testing Guidelines
- Exercise both encrypted and plaintext messaging flows: assert badge text, message persistence, and fallback behaviour in `test/xmpp` and `test/chat` suites.
- Add coverage for new persistence fields by round-tripping through the Drift DAO helpers, and ensure migrations run cleanly against an existing database file.
- Manual smoke tests still matter: after OMEMO changes, open a chat on device/emulator to confirm notifier overlays progress from “Setting up encryption…” to completion.

## Commit & Pull Request Guidelines
- Write imperative commit subjects under 72 characters (e.g., `Fix OMEMO device migration handling`).
- PR descriptions should summarise user-facing impact, database migrations, and any outstanding analyzer warnings; attach screenshots for UI tweaks.
- Call out follow-up work explicitly—especially remaining tasks in `.claude/plans`—so the next contributor knows what to tackle.

## Agent Operating Notes
- Document temporary vendor edits in `VENDOR_NOTES.md` (create it if absent) so upstream patches remain traceable.
- If sandbox restrictions block a command, ask for approval or prefer the provided Dart tooling daemon helpers.
- Record validation steps you could not run (e.g., emulator tests) in your hand-off message to keep the incident log accurate.
