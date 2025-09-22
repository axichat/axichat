# Repository Guidelines

## Project Structure & Module Organization

- `lib/` contains the Flutter app; feature folders under `lib/src/` (chat, calendar, notifications,
  storage, xmpp) own UI and services.
- Tests mirror the source tree (`test/` for unit/widget, `integration_test/` for end-to-end,
  `test_driver/` legacy harness).
- Platform shells (`android/`, `ios/`, `linux/`, `macos/`, `windows/`, `web/`) and shared assets (
  `assets/images/`) mirror lib features.
- Read every `CLAUDE.md` in the current and parent directories for agent-specific rules, and keep
  `analysis_options.yaml`, `l10n.yaml`, `shorebird.yaml`, `build.yaml` aligned with tooling or
  release updates.

## Build, Test, and Development Commands

- USE THE DART MCP, if that is broken then use the following as fallbacks:
- `flutter pub get` — install dependencies after modifying `pubspec.yaml`.
- `dart run build_runner build --delete-conflicting-outputs` — regenerate Drift, Freezed, and router
  artifacts whenever schemas or annotated models change.
- `flutter analyze` — enforce the lint suite; run before every commit.
- `flutter test` — execute unit and widget suites; pass a path (e.g. `flutter test test/chat`) to
  narrow scope.
- `flutter test integration_test` — drive the integration scenarios on an attached emulator or
  device.

## Coding Style & Naming Conventions

- Use 2-space indentation, trailing commas to aid `dart format`, and snake_case file names;
  classes/enums stay in PascalCase.
- Name BLoC layers consistently (`FeatureBloc`, `FeatureState`, `FeatureEvent`) and place them
  inside the owning feature folder.
- Always run `dart format .` (or IDE auto-format) and address analyzer feedback from
  `flutter_lints`.
- Follow patterns in `BLOC_GUIDE.md` to keep widgets presentation-only and move business logic into
  blocs or services.

### Shared UI Components

- Apply DRY aggressively: build small, composable widgets and reuse them everywhere rather than
  branching inside “super widgets.”
- Treat `DeadlinePickerField` as the single source of truth for calendar/date picking. Update it
  once and only adjust parameters (e.g., `showTimeSelectors`) for each use-case.
- When a screen needs a unique tweak, factor that logic into reusable helpers or slots (
  header/body/footer builders) instead of forking the widget.
- Before creating a variant, diff against the original implementation (scheduled task editor) to
  confirm behaviour stays aligned—no local hacks.

## Testing Guidelines

- Co-locate tests with their feature folders (`lib/src/chat` ↔ `test/chat`).
- Use `bloc_test` for deterministic bloc specs, `mocktail` for stubs, and prefer golden/widget tests
  for UI states.
- Integration coverage should lock down sign-in, roster sync, messaging with visible assertions.

## Commit & Pull Request Guidelines

- Match the existing history: concise, present-tense subjects (`Add calendar sync`); avoid prefixes
  unless required by automation.
- PRs should include a short summary, linked issue, screenshots or GIFs for UI updates, and a
  checklist of local `flutter analyze`/`flutter test` runs.
- Call out config or data migrations (database versions, notification keys) so reviewers can verify
  downstream impacts.

## State Management & Configuration Notes

- Hydrated BLoC persists critical state; when introducing new storage, update `lib/src/storage`
  helpers and migration enums.
- XMPP protocol work belongs in `lib/src/xmpp`; consult `XMPP_STYLE_GUIDE.md` before altering stanza
  builders or parsers.
- Keep secrets out of source control and rely on platform secure storage for environment values.
