import 'package:flutter/material.dart';

import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:axichat/src/calendar/utils/time_formatter.dart';
import 'package:axichat/src/calendar/view/widgets/reminder_preferences_field.dart';
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
  return showModalBottomSheet<DayEventEditorResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return _DayEventEditorSheet(
        initialDate: normalized,
        existing: existing,
      );
    },
  );
}

class _DayEventEditorSheet extends StatelessWidget {
  const _DayEventEditorSheet({
    required this.initialDate,
    this.existing,
  });

  final DateTime initialDate;
  final DayEvent? existing;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets viewInsets = MediaQuery.of(context).viewInsets;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.all(calendarGutterLg),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: _DayEventEditorForm(
            initialDate: initialDate,
            existing: existing,
          ),
        ),
      ),
    );
  }
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
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextStyle titleStyle = theme.textTheme.titleMedium!.copyWith(
      fontWeight: FontWeight.w700,
    );

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
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: calendarGutterLg,
              vertical: calendarGutterMd,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _titleController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'Birthday, holiday, or note',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: calendarGutterMd),
                TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Optional details',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: calendarGutterMd),
                TaskSectionHeader(
                  title: 'Dates',
                  trailing: TextButton(
                    onPressed: () => setState(() {
                      _startDate = widget.initialDate;
                      _endDate = widget.initialDate;
                    }),
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(height: 8),
                _DateRow(
                  startDate: _startDate,
                  endDate: _endDate,
                  onStartChanged: (DateTime date) => setState(() {
                    _startDate = date;
                    if (_endDate.isBefore(date)) {
                      _endDate = date;
                    }
                  }),
                  onEndChanged: (DateTime date) => setState(() {
                    _endDate = date.isBefore(_startDate) ? _startDate : date;
                  }),
                ),
                const SizedBox(height: calendarGutterMd),
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
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(calendarGutterMd),
          child: Row(
            children: [
              if (isEditing)
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(
                    const DayEventEditorResult.deleted(),
                  ),
                  icon: Icon(
                    Icons.delete_outline,
                    color: colors.error,
                  ),
                  label: Text(
                    'Delete',
                    style: TextStyle(color: colors.error),
                  ),
                ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: calendarGutterSm),
              FilledButton(
                onPressed: _submit,
                child: Text(isEditing ? 'Save' : 'Add'),
              ),
            ],
          ),
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

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.startDate,
    required this.endDate,
    required this.onStartChanged,
    required this.onEndChanged,
  });

  final DateTime startDate;
  final DateTime endDate;
  final ValueChanged<DateTime> onStartChanged;
  final ValueChanged<DateTime> onEndChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _DateField(
            label: 'Starts',
            date: startDate,
            onChanged: onStartChanged,
          ),
        ),
        const SizedBox(width: calendarGutterSm),
        Expanded(
          child: _DateField(
            label: 'Ends',
            date: endDate,
            onChanged: onEndChanged,
          ),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.onChanged,
  });

  final String label;
  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = Theme.of(context).textTheme.labelLarge!;
    final String formatted = TimeFormatter.formatFriendlyDate(date);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: 6),
        OutlinedButton(
          onPressed: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(date.year - 5),
              lastDate: DateTime(date.year + 5),
            );
            if (picked != null) {
              onChanged(DateTime(picked.year, picked.month, picked.day));
            }
          },
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(formatted),
          ),
        ),
      ],
    );
  }
}
