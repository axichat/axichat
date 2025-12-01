import 'package:flutter/material.dart';

import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:axichat/src/calendar/view/widgets/reminder_preferences_field.dart';
import 'package:axichat/src/calendar/view/widgets/schedule_range_fields.dart';
import 'package:axichat/src/calendar/view/widgets/task_form_section.dart';
import 'package:axichat/src/common/ui/ui.dart';

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
    surfacePadding: const EdgeInsets.all(calendarGutterLg),
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
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.existing != null;
    final colors = context.colorScheme;
    final TextStyle titleStyle = context.textTheme.h3.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w700,
    );
    final EdgeInsets viewInsets = MediaQuery.viewInsetsOf(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: calendarGutterLg,
            vertical: calendarGutterMd,
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
              calendarGutterLg,
              calendarGutterSm,
              calendarGutterLg,
              calendarGutterLg + viewInsets.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TaskTextField(
                  controller: _titleController,
                  autofocus: true,
                  labelText: 'Title',
                  hintText: 'Birthday, holiday, or note',
                  borderRadius: calendarBorderRadius,
                  focusBorderColor: calendarPrimaryColor,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: calendarGutterMd),
                TaskDescriptionField(
                  controller: _descriptionController,
                  hintText: 'Optional details',
                  borderRadius: calendarBorderRadius,
                  focusBorderColor: calendarPrimaryColor,
                  minLines: 3,
                  maxLines: 3,
                ),
                const TaskSectionDivider(),
                TaskSectionHeader(
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
                      _endDate = date.isBefore(_startDate) ? _startDate : date;
                    });
                  },
                ),
                const TaskSectionDivider(),
                ReminderPreferencesField(
                  value: _reminders,
                  onChanged: (ReminderPreferences next) {
                    setState(() {
                      _reminders = next;
                    });
                  },
                  showDeadlineOptions: false,
                  title: 'Reminder',
                ),
              ],
            ),
          ),
        ),
        TaskFormActionsRow(
          includeTopBorder: true,
          padding: EdgeInsets.fromLTRB(
            calendarGutterLg,
            calendarGutterMd,
            calendarGutterLg,
            calendarGutterMd + viewInsets.bottom,
          ),
          children: [
            if (isEditing)
              TaskDestructiveButton(
                label: 'Delete',
                icon: Icons.delete_outline,
                onPressed: () => Navigator.of(context).pop(
                  const DayEventEditorResult.deleted(),
                ),
              ),
            TaskSecondaryButton(
              label: 'Cancel',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            TaskPrimaryButton(
              label: isEditing ? 'Save' : 'Add',
              onPressed: _submit,
            ),
          ],
        ),
      ],
    );
  }

  void _submit() {
    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title cannot be empty')),
      );
      return;
    }
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
