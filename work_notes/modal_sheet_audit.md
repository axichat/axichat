# Modal/Sheet Audit Ledger

## Shared primitives

| Entry | Route/layout contract | Current finding | Status |
| --- | --- | --- | --- |
| `showAdaptiveBottomSheet` | Owns command surface, barrier/drag, root navigator, viewport, outer `AxiModalSurface`. | Callers can pass `surfacePadding: EdgeInsets.zero` for scaffolded sheets so header/action dividers reach the modal surface edge and footer bottom spacing has a single owner. | Repaired for audited scaffolded sheet callers; no broad route rewrite. |
| `AxiModalSurface` | Owns shape, background, border, clipping, radius, and optional shadows. | Current implementation keeps clipping and border composition centralized. | Preserve unless visual verification fails. |
| `AxiSheetScaffold` | Owns header/body/footer layout and body spacing. | Scroll footer now keeps the ListView directly adjacent to the footer divider while retaining body bottom padding inside the scrollable content. `hideWhenKeyboardOpen` remains available as a primitive option, but quick add and day-event editors no longer use it. | Repaired and covered by focused tests. |
| `AxiSheetHeader` | Owns title/close row and edge divider. | Divider is edge-to-edge through `_AxiSheetEdgeDivider`; default body top gutter is `context.spacing.s`. | Preserve. |
| `AxiSheetActions` | Owns action row and top divider. | Default padding is a full `context.spacing.m`; should remain footer content padding only and not stack route safe-area inset. | Preserve with scaffold footer inset repair. |
| `AxiInputDialog` | Standalone dialog wrapper for short text prompts. | Uses the scaffold contract so the header divider carries the body top gutter and input fields cannot touch the divider. | Repaired. |
| `AxiMore` | Short action list. | Uses `showAdaptiveBottomSheet(preferDialogOnMobile: true, surfacePadding: EdgeInsets.zero)` and `AxiSheetScaffold.scroll`. | Preserve short-dialog presentation. |

## Calendar

| Entry | Route/context | Padding/divider/footer | Finding | Status |
| --- | --- | --- | --- | --- |
| Quick add | `showQuickAddModal`, `context.calendarModalContext`, sheet on mobile, dialog otherwise, `surfacePadding: EdgeInsets.zero`. | Header divider; responsive body padding; `AxiSheetActions` footer. | Uses the default always-visible footer policy and the shared footer/viewport contract. | Repaired and tested. |
| New day event | `showDayEventEditor`, `context.calendarModalContext`, `surfacePadding: EdgeInsets.zero`. | Header divider; explicit body top gutter; `AxiSheetActions` footer. | Uses the default always-visible footer policy and the shared footer/viewport contract. | Repaired and tested. |
| Edit task | `CalendarGrid._showTaskEditSheet` and sidebar callers use `context.calendarModalContext`, `useBottomSafeArea: false`, `surfacePadding: EdgeInsets.zero`. | Header actions are inside edit task surface; footer spacing is local. | Header save/close actions present; spacing already single-owner. | Preserve. |
| Split task picker | `context.calendarModalContext`, `surfacePadding: EdgeInsets.zero`. | Scaffolded header/body/footer. | No hide-footer policy. | Preserve. |
| Critical path picker | Caller supplies context; calendar callers route through `calendarModalContext`; `preferDialogOnMobile: true`, `surfacePadding: EdgeInsets.zero`. | Scaffold body/footer; notifier/listener keeps open picker live. | Live update code present. | Preserve and test. |
| Critical path name/copy/share | Name/copy/share flows use dialog preference and zero surface padding where scaffolded. | Scaffolded short choice/name surfaces. | Short sheets should stay dialogs. | Preserve. |
| Task copy/transfer/export/share/view | Copy/transfer/export use `preferDialogOnMobile: true` where short; share/view use scaffolded sheets. | Zero surface padding for scaffolded sheets. | No keyboard footer regression in current audit. | Preserve. |
| Date-time picker | `CalendarDateTimeField` uses `context.calendarModalContext`, `surfacePadding: EdgeInsets.zero`. | Local picker sheet. | No footer-hide finding. | Preserve. |
| Task search/sidebar/chat task card/navigation sheets | Calendar modal context preserved in current code. | Scaffolded sheets already use zero surface padding where edge dividers are expected. | No ownership regression found. | Preserve. |
| Availability/free-busy editors | Use `context.calendarModalContext` for calendar-owned modals. | Mixed custom surfaces and scaffolded sheets. | No footer-hide finding in current audit. | Preserve. |
| Calendar grid day-event `+` button | `DayEventsStrip` uses `AxiIconButton.ghost`. | Current visual is token-sized icon button with primary-tint background. | It is not circular; no mismatch requiring code change found. | Preserve, add coverage only if later changed. |

## Folders

| Entry | Route/context | Padding/divider/footer | Finding | Status |
| --- | --- | --- | --- | --- |
| Add-to-folder | `showAdaptiveBottomSheet`, root navigator, `surfacePadding: EdgeInsets.zero`. | Scaffolded header/body/footer own padding inside the modal surface. | Header/action dividers are edge-to-edge. | Repaired and tested. |
| Contact folder rule | Same as add-to-folder. | Same scaffold pattern. | Header/action dividers are edge-to-edge. | Repaired. |
| New folder | `showFadeScaleDialog` with `AxiInputDialog`. | Shared scaffold body gutter. | Text field stays below the header divider gutter. | Repaired and tested. |

## Other affected users

| Area | Finding | Status |
| --- | --- | --- |
| Contact export, task copy, critical path copy/name, room member short choices, `AxiMore` | `preferDialogOnMobile: true` is present for short command flows audited by search. | Preserve. |
| Contacts details, chat sheets, draft sheets, endpoint config, email forwarding, attachment gallery | Use existing `showAdaptiveBottomSheet`, `showFadeScaleDialog`, `AxiInputDialog`, or `AxiModalSurface` patterns. No specific keyboard/footer regression from this plan found. | Affected by shared primitive repair only. |

## Repair log

- Done: shared scaffold footer keyboard contract keeps visible footers mounted without adding keyboard inset below them.
- Done: `showAdaptiveBottomSheet` no longer adds bottom safe-area padding when callers intentionally pass zero surface padding.
- Done: quick add uses the default always-visible footer policy.
- Done: day event editor uses the default always-visible footer policy.
- Done: folder sheets use `surfacePadding: EdgeInsets.zero` and `AxiSheetActions` for footer spacing/dividers.
- Done: `AxiInputDialog` uses `AxiSheetScaffold.scroll` for shared header/body/footer spacing.
- Done: focused tests added/updated for quick add, day event, critical path live updates, add-to-folder surface padding, and new-folder body spacing.
- Done: self-audit found `AxiSheetSectionDivider` was incorrectly behaving like an edge divider; it now stays within body content while `_AxiSheetEdgeDivider` remains the surface-edge divider.
- Done: `dart format .` completed; `dart fix --apply` reported nothing to fix.
- Done: scoped analyzer pass completed for the modal/sheet repair files and focused test files.

## Post-implementation self-audit, 2026-05-19

| Area | Result | Evidence |
| --- | --- | --- |
| Shared reminder/repeat grouping | Quick add, edit task, selection sidebar, and sidebar advanced task form all route through `TaskReminderRepeatSection`; no remaining quick-add/edit local reminder or recurrence sections were found. | `rg` shows only four production callers of `TaskReminderRepeatSection`, plus the shared widget definition and tests. |
| Repeat section placement | Repeat is now rendered inside the reminders grouping with no section divider between `ReminderPreferencesField` and `TaskRecurrenceSection`. | Focused quick-add and edit-task grouping tests pass. Sidebar callers are structurally wired to the same shared widget; no sidebar-specific widget test was added in this pass. |
| Footer divider gap | `AxiSheetScaffold.scroll` no longer inserts a spacer between the ListView and footer; the viewport ends at the footer divider while content bottom padding remains inside the ListView. | `test/common/ui/axi_sheet_scaffold_test.dart` includes and passes `scroll viewport ends at the footer divider`. |
| Keyboard retention | Quick add and day-event editors keep their submit footers visible through keyboard inset changes. | Focused quick-add and day-event keyboard tests pass. |
| Submit/loading state | Quick add disabled and loading submit states are still represented through `AxiButton`. | Focused quick-add submit-state test passes. |
| Critical path live update | Open picker updates when a path is created while the modal stays open. | Focused critical-path picker test passes. |
| Static checks | Scoped analyzer and diff whitespace checks pass for touched implementation/test files. | `analyze_files` returned no errors; `git diff --check` returned clean. |
| Known unrelated state | Full `calendar_view_interaction_test.dart` remains outside this audit because existing broader CalendarWidget/context-menu expectations fail in the dirty worktree. | Earlier full-file run failed in non-modal CalendarWidget/header/context-menu cases; focused modal regressions are green. |

## Follow-up implementation pass, 2026-05-19

| Area | Result | Evidence |
| --- | --- | --- |
| Declarative sheet sections | Added `AxiSheetScaffold.sections` and `AxiSheetSection` so top-level sections get automatic edge-to-edge dividers while padded section content stays inset. | Quick add, day-event, Widgetbook editor previews, and scaffold tests now use the declarative section model. |
| Quick add People/Critical Paths divider | People and Critical Paths are separate `AxiSheetSection`s. | The divider is inserted by the shared scaffold instead of a manual caller divider. |
| Footer viewport void | Scaffolded sheets with fixed footers no longer add bottom list padding while the footer is visible. | `AxiSheetScaffold` keeps the ListView adjacent to the footer divider; footer-hidden keyboard cases still keep keyboard inset. |
| Outside-calendar edit safe area | Zero-surface-padding sheets now receive bottom safe-area outside the modal surface, and the chat task-bubble edit route no longer opts out. | `showAdaptiveBottomSheet` applies external bottom padding when `surfacePadding.bottom == 0`; `chat_task_card.dart` uses the default bottom safe area. |
| Bottom action button size | Copy/decision footer buttons no longer force `AxiButtonSize.sm`; dense top inline task actions still use `sm`. | Removed `sm` from task copy, critical path copy, and availability request bottom action row. |
| Text-field focus tap regions | `AxiInput` defaults back to Flutter-style shared editable tap region while preserving explicit `groupId` overrides. | `AxiTextInput`, `AxiTextFormField`, and task text wrappers now expose `groupId`; draft subject/body share the composer group when provided. |
| Recipient chip wrapping | Recipient autocomplete trailing input can shrink further and uses spacing/sizing tokens instead of local hardcoded wrap gaps and field constraints. | `RecipientChipsBar` uses token spacing and sizing-based min/max constraints. |
| Verification | Focused modal, recipient, draft, folder, and calendar layout tests pass; static checks are clean. | Ran scaffold/recipient/draft tests, QuickAdd/day-event/critical-path focused tests, folder picker tests, `calendar_layout_test.dart`, `dart format .`, `dart analyze`, `dart fix --apply`, and `git diff --check`. |

## Audit correction, 2026-05-19

| Finding | Fix | Evidence |
| --- | --- | --- |
| The first audit found Quick Add and day-event footers were still present but positioned behind the simulated soft keyboard. | Restored keyboard bottom padding around visible `AxiSheetScaffold` footers while keeping zero bottom gap when the keyboard is closed. | Added footer-position assertions to the Quick Add and day-event keyboard tests; both now pass. |
| Full-file `calendar_view_interaction_test.dart` still fails outside the modal repair scope. | No modal code change made for these failures. | Modal-focused cases pass first; later failures are week header/zoom/selection/context-menu assertions and an existing `AxiButton` overflow in the broader calendar harness. |

## Post-implementation audit, 2026-05-20

| Area | Result | Evidence |
| --- | --- | --- |
| Shared modal contract | `AxiModalScaffold` remains the shared header/body/footer/divider owner; `AxiSheetScaffold`, `AxiDialogScaffold`, `AxiDialog`, and `AxiInputDialog` route through it. | Direct file audit of `axi_modal_scaffold.dart`, `axi_sheet_scaffold.dart`, `axi_dialog.dart`, and `axi_input_dialog.dart`. |
| Divider and padding sentinels | No modal `verticalPadding`, no `bodyPadding: EdgeInsets.zero`, and no nonzero `surfacePadding` adaptive sheet callers remain. | `rg` sentinel scan returned no matches for modal divider/body/surface padding regressions. |
| Keyboard footer policy | No production caller uses `hideWhenKeyboardOpen`; the enum remains only as an unused compatibility path in the shared primitive. | `rg hideWhenKeyboardOpen` returned only enum/translation code in shared primitives. |
| Bottom action sizes | Modal footer actions touched by this repair do not force `AxiButtonSize.sm`; remaining `sm` hits are inline/top/tool controls or unrelated surfaces. | `rg "size: AxiButtonSize.sm"` classification. |
| Dialog base consistency | Common dialogs are on `AxiDialog`/`AxiInputDialog`; custom raw dialog exceptions still exist and are not part of the completed modal repair. | Raw exceptions include calendar delete `AlertDialog`, email forwarding welcome, and calendar text selection. |
| Static analysis | Full project analyzer is clean after codegen state was refreshed. | MCP `analyze_files` returned `No errors`. |
| Focused verification | Shared scaffold, folder, MUC nickname/avatar dialog, quick-add, day-event, edit-task footer, critical-path live update, and calendar layout tests pass. | Focused MCP test runs passed. |
| Known unrelated state | Full `calendar_view_interaction_test.dart` still fails after the modal-focused cases in week header/zoom/selection/context-menu tests. | Full-file run failed after 8 passing modal cases with the existing `AxiButton` overflow and context-menu dismissal expectations. |

## Recipient chips-only caveat, 2026-05-20

| Area | Result | Evidence |
| --- | --- | --- |
| Chips-only modals | Recipient chips bar-only sheets opt out of section spacing so the chips bar sits directly between the header and footer dividers. | MUC invite and critical-path share recipient surfaces use `AxiSheetSection.edge(padding: EdgeInsets.zero)`. |
| Normal recipient form sections | Recipient bars inside larger forms keep the normal section gutter. | Calendar task share still keeps separate recipient, caption, and access sections. |
| Regression test | Shared scaffold now covers zero-padding edge sections for chips-only surfaces. | `test/common/ui/axi_sheet_scaffold_test.dart` includes `edge section can opt out of chips-only spacing`. |
