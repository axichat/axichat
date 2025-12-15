import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:axichat/src/calendar/view/widgets/reminder_preferences_field.dart';
import 'package:axichat/src/calendar/view/widgets/schedule_range_fields.dart';
import 'package:axichat/src/calendar/view/widgets/task_form_section.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';

class DayEventDraft {
  const DayEventDraft({
    required this.title,
    required this.startDate,
    required this.endDate,
    this.description,
    required this.reminders,
  });

  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final String? description;
  final ReminderPreferences reminders;
}

class DayEventEditorResult {
  const DayEventEditorResult.save(this.draft) : deleted = false;

  const DayEventEditorResult.deleted()
      : draft = null,
        deleted = true;

  final DayEventDraft? draft;
  final bool deleted;
}

Future<DayEventEditorResult?> showDayEventEditor({
  required BuildContext context,
  required DateTime initialDate,
  DayEvent? existing,
}) {
  final DateTime normalized =
      DateTime(initialDate.year, initialDate.month, initialDate.day);
  return showAdaptiveBottomSheet<DayEventEditorResult>(
    context: context,
    isScrollControlled: true,
    dialogMaxWidth: 720,
    surfacePadding: const EdgeInsets.symmetric(
      horizontal: calendarGutterSm,
      vertical: calendarInsetSm,
    ),
    showCloseButton: false,
    builder: (BuildContext sheetContext) {
      return _DayEventEditorForm(
        initialDate: normalized,
        existing: existing,
      );
    },
  );
}

class _DayEventEditorForm extends StatefulWidget {
  const _DayEventEditorForm({
    required this.initialDate,
    this.existing,
  });

  final DateTime initialDate;
  final DayEvent? existing;

  @override
  State<_DayEventEditorForm> createState() => _DayEventEditorFormState();
}

class _DayEventEditorFormState extends State<_DayEventEditorForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  final FocusNode _titleFocusNode = FocusNode();
  late DateTime _startDate;
  late DateTime _endDate;
  late ReminderPreferences _reminders;

  @override
  void initState() {
    super.initState();
    _startDate = widget.existing?.normalizedStart ?? widget.initialDate;
    _endDate = widget.existing?.normalizedEnd ?? widget.initialDate;
    _reminders =
        widget.existing?.effectiveReminders ?? ReminderPreferences.defaults();
    _titleController = TextEditingController(text: widget.existing?.title);
    _descriptionController =
        TextEditingController(text: widget.existing?.description);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.existing != null;
    final colors = context.colorScheme;
    final TextStyle titleStyle = calendarTitleTextStyle.copyWith(fontSize: 18);
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final double safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    final bool keyboardOpen = keyboardInset > safeBottom;
    final double scrollBottomPadding = calendarGutterMd + keyboardInset;
    final Widget actions = ValueListenableBuilder<TextEditingValue>(
      valueListenable: _titleController,
      builder: (context, value, _) {
        final bool canSubmit = value.text.trim().isNotEmpty;
        return TaskFormActionsRow(
          includeTopBorder: true,
          gap: calendarGutterSm,
          padding: const EdgeInsets.fromLTRB(
            calendarGutterLg,
            calendarGutterMd,
            calendarGutterLg,
            calendarGutterMd,
          ),
          children: [
            const Spacer(),
            if (isEditing)
              TaskDestructiveButton(
                label: 'Delete',
                icon: Icons.delete_outline,
                onPressed: () => Navigator.of(context).pop(
                  const DayEventEditorResult.deleted(),
                ),
              ),
            TaskSecondaryButton(
              label: context.l10n.commonCancel,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            TaskPrimaryButton(
              label: isEditing ? 'Save' : 'Add',
              onPressed: canSubmit ? _submit : null,
            ),
          ],
        );
      },
    );

    return SafeArea(
      top: true,
      bottom: false,
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.disabled,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: calendarGutterMd,
                vertical: calendarInsetSm,
              ),
              child: Row(
                children: [
                  Text(
                    isEditing ? 'Edit day event' : 'New day event',
                    style: titleStyle,
                  ),
                  const Spacer(),
                  AxiIconButton(
                    iconData: Icons.close,
                    iconSize: 16,
                    buttonSize: 34,
                    tapTargetSize: 40,
                    color: colors.mutedForeground,
                    backgroundColor: Colors.transparent,
                    borderColor: Colors.transparent,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  calendarGutterMd,
                  calendarInsetLg,
                  calendarGutterMd,
                  scrollBottomPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TaskTitleField(
                      controller: _titleController,
                      autofocus: true,
                      labelText: 'Title',
                      hintText: 'Birthday, holiday, or note',
                      focusNode: _titleFocusNode,
                      onChanged: _handleTitleChanged,
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? context.l10n.calendarErrorTitleEmptyFriendly
                          : null,
                      autovalidateMode: AutovalidateMode.disabled,
                    ),
                    const SizedBox(height: calendarGutterMd),
                    TaskDescriptionField(
                      controller: _descriptionController,
                      hintText: 'Optional details',
                      borderRadius: calendarBorderRadius,
                      focusBorderColor: calendarPrimaryColor,
                      contentPadding: calendarFieldPadding,
                      minLines: 3,
                      maxLines: 3,
                    ),
                    TaskSectionDivider(
                      color: colors.border,
                      verticalPadding: calendarGutterMd,
                    ),
                    const TaskSectionHeader(
                      title: 'Dates',
                    ),
                    const SizedBox(height: calendarInsetLg),
                    ScheduleRangeFields(
                      start: _startDate,
                      end: _endDate,
                      showTimeSelectors: false,
                      onStartChanged: (DateTime? date) {
                        if (date == null) {
                          return;
                        }
                        setState(() {
                          _startDate = date;
                          if (_endDate.isBefore(date)) {
                            _endDate = date;
                          }
                        });
                      },
                      onEndChanged: (DateTime? date) {
                        if (date == null) {
                          return;
                        }
                        setState(() {
                          _endDate =
                              date.isBefore(_startDate) ? _startDate : date;
                        });
                      },
                    ),
                    TaskSectionDivider(
                      color: colors.border,
                      verticalPadding: calendarGutterMd,
                    ),
                    ReminderPreferencesField(
                      value: _reminders,
                      onChanged: (ReminderPreferences next) {
                        setState(() {
                          _reminders = next;
                        });
                      },
                      title: 'Reminder',
                      anchor: ReminderAnchor.start,
                    ),
                    if (keyboardOpen) ...[
                      const SizedBox(height: calendarGutterMd),
                      actions,
                    ],
                  ],
                ),
              ),
            ),
            if (!keyboardOpen)
              SafeArea(
                top: false,
                bottom: true,
                child: actions,
              ),
          ],
        ),
      ),
    );
  }

  void _handleTitleChanged(String value) {}

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _titleFocusNode.requestFocus();
      return;
    }
    final String title = _titleController.text.trim();
    final DateTime normalizedStart =
        DateTime(_startDate.year, _startDate.month, _startDate.day);
    final DateTime normalizedEnd =
        DateTime(_endDate.year, _endDate.month, _endDate.day);
    final DayEventDraft draft = DayEventDraft(
      title: title,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      startDate: normalizedStart,
      endDate: normalizedEnd,
      reminders: _reminders.normalized(),
    );
    Navigator.of(context).pop(DayEventEditorResult.save(draft));
  }
}
