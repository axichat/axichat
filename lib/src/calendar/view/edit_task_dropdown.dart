import 'package:axichat/src/app.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/calendar/constants.dart';
import 'package:axichat/src/calendar/bloc/base_calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_alarm.dart';
import 'package:axichat/src/calendar/models/calendar_attachment.dart';
import 'package:axichat/src/calendar/models/calendar_date_time.dart';
import 'package:axichat/src/calendar/models/calendar_ics_meta.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:axichat/src/calendar/utils/alarm_reminder_bridge.dart';
import 'package:axichat/src/calendar/utils/calendar_ics_meta_utils.dart';
import 'package:axichat/src/calendar/utils/location_autocomplete.dart';
import 'package:axichat/src/calendar/utils/recurrence_utils.dart';
import 'package:axichat/src/calendar/utils/schedule_range_utils.dart';
import 'package:axichat/src/calendar/utils/task_title_validation.dart';
import 'models/task_context_action.dart';
import 'controllers/task_checklist_controller.dart';
import 'widgets/deadline_picker_field.dart';
import 'widgets/critical_path_panel.dart';
import 'widgets/ics_meta_fields.dart';
import 'widgets/calendar_categories_field.dart';
import 'widgets/calendar_attachments_field.dart';
import 'widgets/calendar_link_geo_fields.dart';
import 'widgets/recurrence_editor.dart';
import 'widgets/task_field_character_hint.dart';
import 'widgets/task_form_section.dart';
import 'widgets/task_checklist.dart';
import 'widgets/reminder_preferences_field.dart';

const List<String> _emptyCategories = <String>[];
const List<CalendarAttachment> _emptyAttachments = <CalendarAttachment>[];
const List<CalendarAlarm> _emptyAdvancedAlarms = <CalendarAlarm>[];
const String _occurrenceScopeTitle = 'Apply changes to';
const String _occurrenceScopeInstanceLabel = 'This instance';
const String _occurrenceScopeFutureLabel = 'This and future';
const String _occurrenceScopeHint = 'Schedule edits affect the selected range.';

enum OccurrenceUpdateScope {
  thisInstance,
  thisAndFuture;

  bool get isThisInstance => this == OccurrenceUpdateScope.thisInstance;

  bool get isThisAndFuture => this == OccurrenceUpdateScope.thisAndFuture;

  RecurrenceRange? get range =>
      isThisAndFuture ? RecurrenceRange.thisAndFuture : null;

  String get label => switch (this) {
        OccurrenceUpdateScope.thisInstance => _occurrenceScopeInstanceLabel,
        OccurrenceUpdateScope.thisAndFuture => _occurrenceScopeFutureLabel,
      };
}

class EditTaskDropdown<B extends BaseCalendarBloc> extends StatefulWidget {
  const EditTaskDropdown({
    super.key,
    required this.task,
    required this.onClose,
    required this.onTaskUpdated,
    required this.onTaskDeleted,
    this.maxHeight = 520,
    this.onOccurrenceUpdated,
    this.scaffoldMessenger,
    this.isSheet = false,
    this.inlineActionsBuilder,
    this.inlineActionsBloc,
    required this.locationHelper,
  });

  final CalendarTask task;
  final VoidCallback onClose;
  final void Function(CalendarTask task) onTaskUpdated;
  final void Function(String taskId) onTaskDeleted;
  final double maxHeight;
  final void Function(CalendarTask task, OccurrenceUpdateScope scope)?
      onOccurrenceUpdated;
  final ScaffoldMessengerState? scaffoldMessenger;
  final bool isSheet;
  final List<TaskContextAction> Function(CalendarState state)?
      inlineActionsBuilder;
  final B? inlineActionsBloc;
  final LocationAutocompleteHelper locationHelper;

  @override
  State<EditTaskDropdown<B>> createState() => _EditTaskDropdownState<B>();
}

class _EditTaskDropdownState<B extends BaseCalendarBloc>
    extends State<EditTaskDropdown<B>> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late final TaskChecklistController _checklistController;
  final FocusNode _titleFocusNode = FocusNode();

  bool _isImportant = false;
  bool _isUrgent = false;
  bool _isCompleted = false;
  OccurrenceUpdateScope _occurrenceScope = OccurrenceUpdateScope.thisInstance;

  DateTime? _startTime;
  DateTime? _endTime;
  DateTime? _deadline;

  RecurrenceFormValue _recurrence = const RecurrenceFormValue();
  ReminderPreferences _reminders = ReminderPreferences.defaults();
  CalendarIcsStatus? _status;
  CalendarTransparency? _transparency;
  List<String> _categories = _emptyCategories;
  String? _url;
  CalendarGeo? _geo;
  List<CalendarAttachment> _attachments = _emptyAttachments;
  List<CalendarAlarm> _advancedAlarms = _emptyAdvancedAlarms;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _locationController = TextEditingController();
    _checklistController = TaskChecklistController()..addListener(_refresh);

    _hydrateFromTask(widget.task, rebuild: false);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _checklistController
      ..removeListener(_refresh)
      ..dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant EditTaskDropdown<B> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.id != widget.task.id ||
        oldWidget.task.modifiedAt != widget.task.modifiedAt) {
      _hydrateFromTask(widget.task, rebuild: true);
    }
  }

  void _hydrateFromTask(
    CalendarTask task, {
    required bool rebuild,
  }) {
    void apply() {
      if (_titleController.text != task.title) {
        _titleController.value = TextEditingValue(
          text: task.title,
          selection: TextSelection.collapsed(offset: task.title.length),
        );
      }

      final String descriptionText = task.description ?? '';
      if (_descriptionController.text != descriptionText) {
        _descriptionController.value = TextEditingValue(
          text: descriptionText,
          selection: TextSelection.collapsed(offset: descriptionText.length),
        );
      }

      final String locationText = task.location ?? '';
      if (_locationController.text != locationText) {
        _locationController.value = TextEditingValue(
          text: locationText,
          selection: TextSelection.collapsed(offset: locationText.length),
        );
      }

      _checklistController.setItems(task.checklist);

      _isImportant = task.isImportant || task.isCritical;
      _isUrgent = task.isUrgent || task.isCritical;
      _isCompleted = task.isCompleted;
      _occurrenceScope = OccurrenceUpdateScope.thisInstance;
      _startTime = task.scheduledTime;
      final Duration fallbackDuration =
          task.duration ?? calendarDefaultTaskDuration;
      _endTime =
          task.effectiveEndDate ?? task.scheduledTime?.add(fallbackDuration);
      _deadline = task.deadline;
      _recurrence = RecurrenceFormValue.fromRule(task.recurrence)
          .resolveLinkedLimits(_startTime ?? task.scheduledTime);
      final List<CalendarAlarm> existingAlarms = List<CalendarAlarm>.from(
        task.icsMeta?.alarms ?? _emptyAdvancedAlarms,
      );
      if (existingAlarms.isNotEmpty) {
        final AlarmReminderSplit split = splitAlarms(existingAlarms);
        _reminders = split.reminders;
        _advancedAlarms = split.advancedAlarms;
      } else {
        _reminders = task.effectiveReminders;
        _advancedAlarms = _emptyAdvancedAlarms;
      }
      _status = task.icsMeta?.status;
      _transparency = task.icsMeta?.transparency;
      _categories =
          List<String>.from(task.icsMeta?.categories ?? _emptyCategories);
      _url = task.icsMeta?.url;
      _geo = task.icsMeta?.geo;
      _attachments = List<CalendarAttachment>.from(
        task.icsMeta?.attachments ?? _emptyAttachments,
      );
    }

    if (rebuild && mounted) {
      setState(apply);
    } else {
      apply();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isSheet = widget.isSheet;
    final BorderRadius radius = isSheet
        ? const BorderRadius.vertical(top: Radius.circular(24))
        : BorderRadius.circular(8);
    final Color background = isSheet
        ? Theme.of(context).colorScheme.surface
        : calendarContainerColor;
    const double dropdownShadowAlpha = 0.12;
    const double dropdownShadowBlurRadius = 24;
    const Offset dropdownShadowOffset = Offset(0, 8);
    final Color dropdownShadowColor =
        Theme.of(context).shadowColor.withValues(alpha: dropdownShadowAlpha);
    final List<BoxShadow>? boxShadow = isSheet
        ? null
        : [
            BoxShadow(
              color: dropdownShadowColor,
              blurRadius: dropdownShadowBlurRadius,
              offset: dropdownShadowOffset,
            ),
          ];
    Widget buildBody({
      required double keyboardInset,
      required double safeBottom,
    }) {
      final bool keyboardOpen = keyboardInset > safeBottom;
      Widget actionRow({required bool includeTopBorder}) {
        return ValueListenableBuilder<TextEditingValue>(
          valueListenable: _titleController,
          builder: (context, value, _) {
            final bool canSave =
                TaskTitleValidation.validate(value.text) == null;
            return _EditTaskActionsRow(
              task: widget.task,
              onDelete: () {
                widget.onTaskDeleted(widget.task.id);
                widget.onClose();
              },
              onCancel: widget.onClose,
              onSave: _handleSave,
              canSave: canSave,
              includeTopBorder: includeTopBorder,
            );
          },
        );
      }

      final Widget form = Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.disabled,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _EditTaskHeader(onClose: widget.onClose),
            const Divider(height: 1),
            Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  calendarGutterLg,
                  calendarGutterMd,
                  calendarGutterLg,
                  calendarGutterMd +
                      (isSheet && keyboardOpen ? keyboardInset : 0),
                ),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.manual,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _EditTaskInlineActionsSection<B>(
                      inlineActionsBloc: widget.inlineActionsBloc,
                      inlineActionsBuilder: widget.inlineActionsBuilder,
                    ),
                    if (widget.task.isOccurrence &&
                        widget.onOccurrenceUpdated != null) ...[
                      const SizedBox(height: calendarFormGap),
                      _EditTaskOccurrenceScopeSection(
                        scope: _occurrenceScope,
                        onChanged: (scope) =>
                            setState(() => _occurrenceScope = scope),
                      ),
                      const TaskSectionDivider(
                        verticalPadding: calendarGutterMd,
                      ),
                    ],
                    _EditTaskTitleField(
                      controller: _titleController,
                      validator: (value) =>
                          TaskTitleValidation.validate(value ?? ''),
                      onChanged: _handleTitleChanged,
                      focusNode: _titleFocusNode,
                      autovalidateMode: AutovalidateMode.disabled,
                    ),
                    const SizedBox(height: calendarFormGap),
                    _EditTaskDescriptionField(
                      controller: _descriptionController,
                    ),
                    const SizedBox(height: calendarFormGap),
                    _EditTaskLocationField(
                      controller: _locationController,
                      locationHelper: widget.locationHelper,
                    ),
                    const SizedBox(height: calendarFormGap),
                    _EditTaskPriorityRow(
                      isImportant: _isImportant,
                      isUrgent: _isUrgent,
                      onImportantChanged: (value) =>
                          setState(() => _isImportant = value),
                      onUrgentChanged: (value) =>
                          setState(() => _isUrgent = value),
                    ),
                    const SizedBox(height: calendarFormGap),
                    TaskChecklist(controller: _checklistController),
                    const TaskSectionDivider(
                      verticalPadding: calendarGutterMd,
                    ),
                    _EditTaskScheduleSection(
                      start: _startTime,
                      end: _endTime,
                      onStartChanged: _handleStartChanged,
                      onEndChanged: _handleEndChanged,
                    ),
                    const TaskSectionDivider(
                      verticalPadding: calendarGutterMd,
                    ),
                    _EditTaskDeadlineField(
                      deadline: _deadline,
                      onChanged: (value) => setState(() => _deadline = value),
                    ),
                    const TaskSectionDivider(
                      verticalPadding: calendarGutterMd,
                    ),
                    _EditTaskReminderSection(
                      reminders: _reminders,
                      deadline: _deadline,
                      referenceStart: _startTime,
                      advancedAlarms: _advancedAlarms,
                      onChanged: (value) => setState(() {
                        _reminders = value;
                      }),
                      onAdvancedAlarmsChanged: (value) => setState(() {
                        _advancedAlarms = value;
                      }),
                    ),
                    const TaskSectionDivider(
                      verticalPadding: calendarGutterMd,
                    ),
                    _EditTaskRecurrenceSection(
                      value: _recurrence,
                      fallbackWeekday: _recurrenceFallbackWeekday,
                      referenceStart: _startTime,
                      onChanged: _handleRecurrenceChanged,
                    ),
                    const TaskSectionDivider(
                      verticalPadding: calendarGutterMd,
                    ),
                    CalendarIcsMetaFields(
                      status: _status,
                      transparency: _transparency,
                      showStatus: false,
                      onStatusChanged: (value) =>
                          setState(() => _status = value),
                      onTransparencyChanged: (value) =>
                          setState(() => _transparency = value),
                    ),
                    const TaskSectionDivider(
                      verticalPadding: calendarGutterMd,
                    ),
                    CalendarCategoriesField(
                      categories: _categories,
                      onChanged: (value) => setState(() => _categories = value),
                    ),
                    const TaskSectionDivider(
                      verticalPadding: calendarGutterMd,
                    ),
                    CalendarLinkGeoFields(
                      url: _url,
                      geo: _geo,
                      onUrlChanged: (value) => setState(() => _url = value),
                      onGeoChanged: (value) => setState(() => _geo = value),
                    ),
                    if (_attachments.isNotEmpty) ...[
                      const TaskSectionDivider(
                        verticalPadding: calendarGutterMd,
                      ),
                      CalendarAttachmentsField(
                        attachments: _attachments,
                      ),
                    ],
                    const TaskSectionDivider(
                      verticalPadding: calendarGutterMd,
                    ),
                    _EditTaskCompletionToggle(
                      value: _isCompleted,
                      onChanged: (value) =>
                          setState(() => _isCompleted = value),
                    ),
                    const SizedBox(height: calendarFormGap),
                    _TaskCriticalPathMembership<B>(
                      task: widget.task,
                      blocOverride: widget.inlineActionsBloc,
                    ),
                    const SizedBox(height: calendarFormGap),
                    if (keyboardOpen) actionRow(includeTopBorder: true),
                  ],
                ),
              ),
            ),
            if (!keyboardOpen)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Divider(height: 1),
                  SafeArea(
                    top: false,
                    bottom: true,
                    child: actionRow(includeTopBorder: false),
                  ),
                ],
              ),
          ],
        ),
      );

      if (!isSheet) {
        return form;
      }

      return SafeArea(
        top: true,
        bottom: false,
        child: form,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double resolvedMaxHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : widget.maxHeight;
        final mediaQuery = MediaQuery.of(context);
        final double keyboardInset = mediaQuery.viewInsets.bottom;
        final double safeBottom = mediaQuery.viewPadding.bottom;
        final Widget surfaced = Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: radius,
            child: Container(
              width: isSheet ? double.infinity : calendarTaskPopoverWidth,
              constraints: BoxConstraints(
                maxHeight: resolvedMaxHeight,
                minWidth: 320,
              ),
              decoration: BoxDecoration(
                color: background,
                borderRadius: radius,
                border: isSheet ? null : Border.all(color: calendarBorderColor),
                boxShadow: boxShadow,
              ),
              child: buildBody(
                keyboardInset: keyboardInset,
                safeBottom: safeBottom,
              ),
            ),
          ),
        );

        if (!isSheet) {
          return SafeArea(
            top: true,
            bottom: true,
            child: surfaced,
          );
        }
        return SafeArea(
          top: true,
          bottom: false,
          child: surfaced,
        );
      },
    );
  }

  void _handleTitleChanged(String value) {}

  int get _recurrenceFallbackWeekday =>
      _startTime?.weekday ??
      widget.task.scheduledTime?.weekday ??
      DateTime.now().weekday;

  void _handleStartChanged(DateTime? value) {
    setState(() {
      final DateTime? previousStart = _startTime;
      final DateTime? previousEnd = _endTime;
      _startTime = value;
      _endTime = shiftEndTimeWithStart(
        previousStart: previousStart,
        previousEnd: previousEnd,
        nextStart: value,
      );
      if (value == null) {
        return;
      }
      _recurrence = _normalizeRecurrence(_recurrence);
    });
  }

  void _handleEndChanged(DateTime? value) {
    setState(() {
      _endTime = clampEndTime(start: _startTime, end: value);
      if (_endTime == null) {
        return;
      }
      _recurrence = _normalizeRecurrence(_recurrence);
    });
  }

  void _handleRecurrenceChanged(RecurrenceFormValue next) {
    setState(() {
      _recurrence = _normalizeRecurrence(next);
    });
  }

  RecurrenceFormValue _normalizeRecurrence(RecurrenceFormValue value) {
    final DateTime? anchor = _startTime ?? widget.task.scheduledTime;
    return value.resolveLinkedLimits(anchor);
  }

  void _handleSave() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _titleFocusNode.requestFocus();
      return;
    }

    final title = _titleController.text.trim();

    final priority = () {
      if (_isImportant && _isUrgent) return TaskPriority.critical;
      if (_isImportant) return TaskPriority.important;
      if (_isUrgent) return TaskPriority.urgent;
      return TaskPriority.none;
    }();

    DateTime? scheduledTime;
    Duration? duration;
    DateTime? endDate;
    if (_startTime != null && _endTime != null) {
      final DateTime start = _startTime!;
      DateTime end = _endTime!;
      Duration computed = end.difference(start);
      if (computed.inMinutes < 15) {
        computed = const Duration(minutes: 15);
        end = start.add(computed);
        _endTime = end;
      }
      scheduledTime = start;
      duration = computed;
      endDate = end;
    }

    if (scheduledTime == null) {
      duration = null;
      endDate = null;
    }

    final recurrenceAnchor =
        scheduledTime ?? widget.task.scheduledTime ?? DateTime.now();
    final recurrence = _recurrence.isActive
        ? _recurrence
            .resolveLinkedLimits(recurrenceAnchor)
            .toRule(start: recurrenceAnchor)
        : null;

    final List<String>? categories = resolveCategoryOverride(
      base: widget.task.icsMeta,
      categories: _categories,
    );
    final List<CalendarAlarm> mergedAlarms = mergeAdvancedAlarms(
      advancedAlarms: _advancedAlarms,
      reminders: _reminders,
    );
    final List<CalendarAlarm>? alarms = resolveAlarmOverride(
      base: widget.task.icsMeta,
      alarms: mergedAlarms,
    );
    final CalendarIcsMeta? icsMeta = applyIcsMetaOverrides(
      base: widget.task.icsMeta,
      status: _status,
      transparency: _transparency,
      categories: categories,
      url: _url,
      geo: _geo,
      alarms: alarms,
    );

    final updatedTask = widget.task.copyWith(
      title: title,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      scheduledTime: scheduledTime,
      duration: duration,
      endDate: endDate,
      deadline: _deadline,
      priority: priority == TaskPriority.none ? null : priority,
      isCompleted: _isCompleted,
      recurrence: recurrence?.isNone == true ? null : recurrence,
      checklist: _checklistController.items.toList(),
      reminders: _reminders,
      icsMeta: icsMeta,
    );

    if (widget.task.isOccurrence && widget.onOccurrenceUpdated != null) {
      widget.onOccurrenceUpdated!(updatedTask, _occurrenceScope);
    } else {
      widget.onTaskUpdated(updatedTask);
    }
    widget.onClose();
  }
}

class _EditTaskHeader extends StatelessWidget {
  const _EditTaskHeader({
    required this.onClose,
  });

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: calendarGutterLg,
        vertical: calendarGutterMd,
      ),
      child: Row(
        children: [
          Text(
            'Edit Task',
            style: calendarTitleTextStyle.copyWith(fontSize: 18),
          ),
          const Spacer(),
          AxiIconButton(
            iconData: Icons.close,
            tooltip: context.l10n.calendarCloseTooltip,
            onPressed: onClose,
            color: calendarSubtitleColor,
            backgroundColor: colors.card,
            borderColor: colors.border,
            iconSize: 18,
            buttonSize: 34,
            tapTargetSize: 40,
            cornerRadius: 12,
          ),
        ],
      ),
    );
  }
}

class _EditTaskInlineActionsSection<B extends BaseCalendarBloc>
    extends StatelessWidget {
  const _EditTaskInlineActionsSection({
    required this.inlineActionsBloc,
    required this.inlineActionsBuilder,
  });

  final B? inlineActionsBloc;
  final List<TaskContextAction> Function(CalendarState state)?
      inlineActionsBuilder;

  @override
  Widget build(BuildContext context) {
    final builder = inlineActionsBuilder;
    final bloc = inlineActionsBloc;
    if (builder == null || bloc == null) {
      return const SizedBox.shrink();
    }
    return BlocBuilder<B, CalendarState>(
      bloc: bloc,
      builder: (context, state) {
        final actions = builder(state);
        if (actions.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: calendarGutterLg,
                vertical: calendarGutterMd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Task actions',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: calendarInsetSm),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final double? width = constraints.maxWidth.isFinite
                          ? constraints.maxWidth
                          : null;
                      final chipWrap = Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        children: actions
                            .map(
                              (action) => _EditTaskInlineActionChip(
                                action: action,
                              ),
                            )
                            .toList(growable: false),
                      );
                      if (width == null) {
                        return chipWrap;
                      }
                      return SizedBox(width: width, child: chipWrap);
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: calendarFormGap),
          ],
        );
      },
    );
  }
}

class _EditTaskInlineActionChip extends StatelessWidget {
  const _EditTaskInlineActionChip({
    required this.action,
  });

  final TaskContextAction action;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color baseColor =
        action.destructive ? scheme.error : calendarPrimaryColor;
    final Color background = baseColor.withValues(alpha: 0.12);
    return TextButton.icon(
      onPressed: action.onSelected,
      style: TextButton.styleFrom(
        foregroundColor: baseColor,
        backgroundColor: background,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        visualDensity: VisualDensity.compact,
      ),
      icon: Icon(action.icon, size: 16),
      label: Text(
        action.label,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _EditTaskTitleField extends StatelessWidget {
  const _EditTaskTitleField({
    required this.controller,
    required this.validator,
    required this.onChanged,
    this.focusNode,
    required this.autovalidateMode,
  });

  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final ValueChanged<String> onChanged;
  final FocusNode? focusNode;
  final AutovalidateMode autovalidateMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaskTitleField(
          controller: controller,
          focusNode: focusNode,
          autofocus: true,
          hintText: context.l10n.calendarTaskTitleHint,
          onChanged: onChanged,
          validator: validator,
          autovalidateMode: autovalidateMode,
          textInputAction: TextInputAction.done,
        ),
        TaskFieldCharacterHint(controller: controller),
      ],
    );
  }
}

class _EditTaskDescriptionField extends StatelessWidget {
  const _EditTaskDescriptionField({
    required this.controller,
  });

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TaskDescriptionField(
      controller: controller,
      hintText: context.l10n.calendarDescriptionOptionalHint,
      minLines: 2,
      maxLines: 4,
      textCapitalization: TextCapitalization.sentences,
      borderRadius: calendarBorderRadius,
      focusBorderColor: calendarPrimaryColor,
      contentPadding: calendarFieldPadding,
    );
  }
}

class _EditTaskLocationField extends StatelessWidget {
  const _EditTaskLocationField({
    required this.controller,
    required this.locationHelper,
  });

  final TextEditingController controller;
  final LocationAutocompleteHelper locationHelper;

  @override
  Widget build(BuildContext context) {
    return TaskLocationField(
      controller: controller,
      hintText: context.l10n.calendarLocationOptionalHint,
      textCapitalization: TextCapitalization.words,
      contentPadding: calendarFieldPadding,
      borderRadius: calendarBorderRadius,
      focusBorderColor: calendarPrimaryColor,
      autocomplete: locationHelper,
    );
  }
}

class _EditTaskScheduleSection extends StatelessWidget {
  const _EditTaskScheduleSection({
    required this.start,
    required this.end,
    required this.onStartChanged,
    required this.onEndChanged,
  });

  final DateTime? start;
  final DateTime? end;
  final ValueChanged<DateTime?> onStartChanged;
  final ValueChanged<DateTime?> onEndChanged;

  @override
  Widget build(BuildContext context) {
    return TaskScheduleSection(
      spacing: calendarInsetLg,
      start: start,
      end: end,
      onStartChanged: onStartChanged,
      onEndChanged: onEndChanged,
    );
  }
}

class _EditTaskOccurrenceScopeSection extends StatelessWidget {
  const _EditTaskOccurrenceScopeSection({
    required this.scope,
    required this.onChanged,
  });

  final OccurrenceUpdateScope scope;
  final ValueChanged<OccurrenceUpdateScope> onChanged;

  @override
  Widget build(BuildContext context) {
    final TextStyle hintStyle = context.textTheme.muted.copyWith(
      fontWeight: FontWeight.w500,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TaskSectionHeader(title: _occurrenceScopeTitle),
        const SizedBox(height: calendarInsetSm),
        Text(
          _occurrenceScopeHint,
          style: hintStyle,
        ),
        const SizedBox(height: calendarGutterSm),
        Wrap(
          spacing: calendarGutterSm,
          runSpacing: calendarGutterSm,
          children: OccurrenceUpdateScope.values
              .map(
                (option) => _OccurrenceScopeChip(
                  label: option.label,
                  isSelected: option == scope,
                  onPressed: () => onChanged(option),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _OccurrenceScopeChip extends StatelessWidget {
  const _OccurrenceScopeChip({
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ShadButton.raw(
      variant:
          isSelected ? ShadButtonVariant.primary : ShadButtonVariant.outline,
      size: ShadButtonSize.sm,
      padding: const EdgeInsets.symmetric(
        horizontal: calendarGutterMd,
        vertical: calendarGutterSm,
      ),
      backgroundColor:
          isSelected ? calendarPrimaryColor : calendarContainerColor,
      hoverBackgroundColor: isSelected
          ? calendarPrimaryHoverColor
          : calendarPrimaryColor.withValues(alpha: 0.08),
      foregroundColor: isSelected
          ? context.colorScheme.primaryForeground
          : calendarPrimaryColor,
      hoverForegroundColor: isSelected
          ? context.colorScheme.primaryForeground
          : calendarPrimaryHoverColor,
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
    ).withTapBounce();
  }
}

class _EditTaskDeadlineField extends StatelessWidget {
  const _EditTaskDeadlineField({
    required this.deadline,
    required this.onChanged,
  });

  final DateTime? deadline;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TaskSectionHeader(title: 'Deadline'),
        const SizedBox(height: calendarInsetMd),
        DeadlinePickerField(
          value: deadline,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _EditTaskReminderSection extends StatelessWidget {
  const _EditTaskReminderSection({
    required this.reminders,
    required this.deadline,
    required this.referenceStart,
    required this.advancedAlarms,
    required this.onChanged,
    required this.onAdvancedAlarmsChanged,
  });

  final ReminderPreferences reminders;
  final DateTime? deadline;
  final DateTime? referenceStart;
  final List<CalendarAlarm> advancedAlarms;
  final ValueChanged<ReminderPreferences> onChanged;
  final ValueChanged<List<CalendarAlarm>> onAdvancedAlarmsChanged;

  @override
  Widget build(BuildContext context) {
    return ReminderPreferencesField(
      value: reminders,
      onChanged: onChanged,
      advancedAlarms: advancedAlarms,
      onAdvancedAlarmsChanged: onAdvancedAlarmsChanged,
      referenceStart: referenceStart,
      anchor: deadline == null ? ReminderAnchor.start : ReminderAnchor.deadline,
      showBothAnchors: deadline != null,
    );
  }
}

class _EditTaskRecurrenceSection extends StatelessWidget {
  const _EditTaskRecurrenceSection({
    required this.value,
    required this.fallbackWeekday,
    required this.referenceStart,
    required this.onChanged,
  });

  final RecurrenceFormValue value;
  final int fallbackWeekday;
  final DateTime? referenceStart;
  final ValueChanged<RecurrenceFormValue> onChanged;

  @override
  Widget build(BuildContext context) {
    return TaskRecurrenceSection(
      spacing: calendarInsetMd,
      value: value,
      fallbackWeekday: fallbackWeekday,
      referenceStart: referenceStart,
      spacingConfig: const RecurrenceEditorSpacing(
        chipSpacing: 6,
        chipRunSpacing: 6,
        weekdaySpacing: 10,
        advancedSectionSpacing: 12,
        endSpacing: 14,
        fieldGap: 12,
      ),
      onChanged: onChanged,
    );
  }
}

class _EditTaskPriorityRow extends StatelessWidget {
  const _EditTaskPriorityRow({
    required this.isImportant,
    required this.isUrgent,
    required this.onImportantChanged,
    required this.onUrgentChanged,
  });

  final bool isImportant;
  final bool isUrgent;
  final ValueChanged<bool> onImportantChanged;
  final ValueChanged<bool> onUrgentChanged;

  @override
  Widget build(BuildContext context) {
    return TaskPriorityToggles(
      isImportant: isImportant,
      isUrgent: isUrgent,
      onImportantChanged: onImportantChanged,
      onUrgentChanged: onUrgentChanged,
    );
  }
}

class _EditTaskCompletionToggle extends StatelessWidget {
  const _EditTaskCompletionToggle({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return TaskCompletionToggle(
      value: value,
      onChanged: onChanged,
    );
  }
}

class _TaskCriticalPathMembership<B extends BaseCalendarBloc>
    extends StatelessWidget {
  const _TaskCriticalPathMembership({
    required this.task,
    this.blocOverride,
  });

  final CalendarTask task;
  final B? blocOverride;

  @override
  Widget build(BuildContext context) {
    final B bloc = blocOverride ?? context.read<B>();
    return BlocBuilder<B, CalendarState>(
      bloc: bloc,
      builder: (context, state) {
        final paths = state.criticalPathsForTask(task);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TaskSecondaryButton(
              label: 'Add to critical path',
              icon: Icons.route,
              onPressed: () => addTaskToCriticalPath(
                context: context,
                bloc: bloc,
                task: task,
              ),
            ),
            const SizedBox(height: calendarInsetSm),
            CriticalPathMembershipList(
              paths: paths,
              onRemovePath: (pathId) => bloc.add(
                CalendarEvent.criticalPathTaskRemoved(
                  pathId: pathId,
                  taskId: task.id,
                ),
              ),
              emptyLabel: 'Not in any critical paths',
            ),
          ],
        );
      },
    );
  }
}

class _EditTaskActionsRow extends StatelessWidget {
  const _EditTaskActionsRow({
    required this.task,
    required this.onDelete,
    required this.onCancel,
    required this.onSave,
    required this.canSave,
    required this.includeTopBorder,
  });

  final CalendarTask task;
  final VoidCallback onDelete;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final bool canSave;
  final bool includeTopBorder;

  @override
  Widget build(BuildContext context) {
    return TaskFormActionsRow(
      includeTopBorder: includeTopBorder,
      padding: calendarPaddingLg,
      gap: 8,
      children: [
        TaskDestructiveButton(
          label: context.l10n.commonDelete,
          onPressed: onDelete,
        ),
        const Spacer(),
        TaskSecondaryButton(
          label: context.l10n.commonCancel,
          onPressed: onCancel,
          foregroundColor: calendarPrimaryColor,
          hoverForegroundColor: calendarPrimaryHoverColor,
          hoverBackgroundColor: calendarPrimaryColor.withValues(alpha: 0.08),
        ),
        TaskPrimaryButton(
          label: context.l10n.commonSave,
          onPressed: canSave ? onSave : null,
        ),
      ],
    );
  }
}
