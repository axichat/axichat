# Repository Guidelines

## Project Structure & Module Organization

- `lib/` contains the Flutter app; feature folders under `lib/src/` (chat, calendar, notifications, storage, xmpp) own UI and services, and mirror the mixin architecture already used inside `XmppService`.
- Tests mirror the source tree (`test/` for unit/widget, `integration_test/` for end-to-end, `test_driver/` legacy harness); keep new specs beside the features they exercise.
- Platform shells (`android/`, `ios/`, `linux/`, `macos/`, `windows/`, `web/`) and shared assets (`assets/images/`) mirror lib features so design tokens stay consistent.
- Database models and query accessors live in `lib/src/storage/models`; rerun `dart run build_runner build --delete-conflicting-outputs` whenever you touch these types to keep generated Drift/Freezed files in sync.
- Calendar UI, storage, and sync helpers stay under `lib/src/calendar`; deadline/date picking should always reuse `DeadlinePickerField`.
- UI elements that the team monitors globally (operation overlays, notifications) sit in `lib/src/notifications` and are surfaced through `lib/src/app.dart`.
- Read every `CLAUDE.md` in the current directory and its parents before editing; they override defaults. Keep `analysis_options.yaml`, `l10n.yaml`, `shorebird.yaml`, and `build.yaml` aligned with tooling or release updates.

## Build, Test, and Development Commands

- USE THE DART MCP; if it is unavailable fall back to the commands below.
- `flutter pub get` — install dependencies after modifying `pubspec.yaml`.
- `dart run build_runner build --delete-conflicting-outputs` — regenerate Drift, Freezed, router, or other annotated artifacts whenever schemas/models change.
- `flutter run` (add `--flavor dev` for staging) powers manual smoke tests.
- Always run `dart format .` followed by `dart analyze` (or equivalent IDE actions) before sharing patches to keep the lint suite predictable.
- `flutter test` — execute unit and widget suites; scope with `flutter test test/chat`.
- `flutter test integration_test` — run integration coverage on an attached emulator/device.
- `dart test` — useful for pure Dart targets (storage/xmpp) when you want CLI output and tighter filters.

## Coding Style & Naming Conventions

- Use 2-space indentation, trailing commas to aid `dart format`, and snake_case file names; classes/enums remain in PascalCase.
- Name BLoC layers consistently (`FeatureBloc`, `FeatureState`, `FeatureEvent`) inside their owning feature folders.
- Prefer explicit types, exhaustive `switch` statements, cascade operators, and intent-revealing names (`checkOmemoSupport`, `startOmemoOperation`).
- Keep logging consistent by reusing the existing `Logger` instances—never leave `print` in production paths—and avoid leaking sensitive data.
- Widgets should remain declarative/stateless whenever reasonable; move business logic into blocs/services per `BLOC_GUIDE.md`.
- Follow the design tokens and UI helpers exported by `lib/src/common/ui/ui.dart` and `lib/src/app.dart`.

### Shared UI Components

- Apply DRY aggressively: build small, composable widgets and reuse them everywhere rather than branching inside “super widgets.”
- For complex animated shells (calendar cards, tabbed panels, etc.) prefer extracting layout + painting into a custom `RenderObject` instead of layering `addPostFrameCallback`/`findRenderObject` hacks—use the render-object-driven pattern documented in `docs/tab_container_study.md`.
- Treat `DeadlinePickerField` as the single source of truth for calendar/date picking. Update it once and only adjust parameters (e.g., `showTimeSelectors`) per use-case.
- When a screen needs a unique tweak, factor that logic into reusable helpers or slots (header/body/footer builders) instead of forking the widget. Before creating a variant, diff against the original implementation (scheduled task editor) to confirm behaviour alignment.
- When a widget’s layout must react to geometry that is only known during the same pass (e.g., chat bubble cutouts), graduate it to a `MultiChildRenderObjectWidget` so the render object can size the body first, then clamp overlays without relying on `GlobalKey` lookups or post-frame measurement.
- Give render objects explicit slots via parent data (body/reactions/recipients, etc.) so layout, painting, and hit-testing stay deterministic; this avoids accidental sibling order bugs and keeps animation math centralized.
- If other subsystems need live bounds (selection hit regions, autoscroll), prefer a small render-object registry that records `RenderBox` instances on attach/detach instead of scattering duplicate `GlobalKey`s—registries are cheaper and eliminate reparenting assertions.
- Keep render-object parameters declarative (e.g., pass a `CutoutStyle` struct describing depth/radius/padding) so feature teams can change visuals without editing the render layer every time.

## Testing Guidelines

- Co-locate tests with their feature folders (`lib/src/chat` ↔ `test/chat`, calendar ↔ `test/calendar`, etc.).
- Use `bloc_test` for deterministic bloc specs, `mocktail` for stubs, and prefer golden/widget tests for UI states.
- Integration coverage should lock down sign-in, roster sync, messaging, and calendar interactions with visible assertions.
- Exercise both encrypted and plaintext messaging flows: assert badge text, message persistence, OMEMO setup progress, and fallback behaviour in `test/xmpp` and `test/chat` suites.
- Add coverage for storage fields by round-tripping through Drift DAO helpers, and ensure migrations run cleanly against existing database files.
- After OMEMO or notification changes, perform manual smoke tests on a device/emulator to confirm overlays progress through their expected states.

## Commit & Pull Request Guidelines

- Match the existing history: concise, present-tense subjects under 72 characters (e.g., `Add calendar sync`, `Fix OMEMO device migration handling`).
- PRs should summarize user-facing impact, database or notification key migrations, screenshots/GIFs for UI tweaks, and a checklist of local `flutter analyze` / `flutter test` runs.
- Call out follow-up work explicitly—especially items tracked in `.claude/plans`—so the next contributor knows what to tackle.

## State Management & Configuration Notes

- Hydrated BLoC persists critical state; when introducing new storage, update `lib/src/storage` helpers and migration enums.
- XMPP protocol work belongs in `lib/src/xmpp`; consult `XMPP_STYLE_GUIDE.md` before altering stanza builders or parsers.
- Keep secrets out of source control and rely on platform secure storage for environment values.
- Database access must continue to use SQLCipher with the registered credential key system.

## Agent Operating Notes

- Document temporary vendor edits in `VENDOR_NOTES.md` (create it if absent) so upstream patches remain traceable.
- If sandbox restrictions block a command, request approval or prefer the provided Dart MCP tooling helpers.
- Record validation steps you could not run (e.g., emulator tests) in your hand-off so incident logs stay accurate.
