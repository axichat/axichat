# Common Module

## Shared Components

- All styles, themes, and components should be global and controlled from this directory
- This is to minimise number of edits required to update the UI
- @ui/dynamic_inline_text.dart makes message metadata appear on the same line as the last line of
- `@ui/dynamic_inline_text.dart` makes message metadata appear on the same line as the last line of
  text if there is enough horizontal space, otherwise on the line below

## Shared Values

- Magic values must be avoided. UI related values should be turned into constants in @ui/ui.dart

## Utility Functions

- Functions and classes that handle common procedures or could be in any layer belong here
