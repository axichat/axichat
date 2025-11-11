import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../common/ui/ui.dart';
import '../models/calendar_task.dart';
import '../utils/location_autocomplete.dart';
import '../utils/nl_parser_service.dart';
import '../utils/nl_schedule_adapter.dart';
import '../utils/responsive_helper.dart';
import 'controllers/quick_add_controller.dart';
import 'widgets/deadline_picker_field.dart';
import 'widgets/location_inline_suggestion.dart';
import 'widgets/recurrence_editor.dart';
import 'widgets/recurrence_spacing_tokens.dart';
import 'widgets/task_form_section.dart';
import 'widgets/task_text_field.dart';

enum QuickAddModalSurface { dialog, bottomSheet }

class QuickAddModal extends StatefulWidget {
  final DateTime? prefilledDateTime;
  final String? prefilledText;
  final VoidCallback? onDismiss;
  final void Function(CalendarTask task) onTaskAdded;
  final QuickAddModalSurface surface;
  final LocationAutocompleteHelper locationHelper;

  const QuickAddModal({
    super.key,
    this.prefilledDateTime,
    this.prefilledText,
    this.onDismiss,
    required this.onTaskAdded,
    this.surface = QuickAddModalSurface.dialog,
    required this.locationHelper,
  });

  @override
  State<QuickAddModal> createState() => _QuickAddModalState();
}

class _QuickAddModalState extends State<QuickAddModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  final _taskNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _taskNameFocusNode = FocusNode();

  late final QuickAddController _formController;
  late final NlScheduleParserService _parserService;
  Timer? _parserDebounce;
  int _parserRequestId = 0;
  String _lastParserInput = '';
  bool _isApplyingParser = false;

  bool _locationLocked = false;
  bool _scheduleLocked = false;
  bool _deadlineLocked = false;
  bool _recurrenceLocked = false;
  bool _priorityLocked = false;
  NlAdapterResult? _lastParserResult;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: baseAnimationDuration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    if (widget.surface == QuickAddModalSurface.dialog) {
      _animationController.forward();
    } else {
      _animationController.value = 1.0;
    }

    final prefilled = widget.prefilledDateTime;

    _formController = QuickAddController(
      initialStart: prefilled,
      initialEnd: prefilled?.add(const Duration(hours: 1)),
    );
    _parserService = NlScheduleParserService();
    _resetParserLocks();
    if (prefilled != null) {
      _scheduleLocked = true;
    }

    final seededText = widget.prefilledText?.trim();
    if (seededText != null && seededText.isNotEmpty) {
      _taskNameController.value = TextEditingValue(
        text: seededText,
        selection: TextSelection.collapsed(offset: seededText.length),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _handleTaskNameChanged(seededText);
      });
    }
  }

  @override
  void dispose() {
    _parserDebounce?.cancel();
    _animationController.dispose();
    _taskNameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _taskNameFocusNode.dispose();
    _formController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.surface == QuickAddModalSurface.bottomSheet) {
      final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: _buildModalContent(isSheet: true),
        ),
      );
    }
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Stack(
          children: [
            // Semi-transparent backdrop
            GestureDetector(
              onTap: _dismissModal,
              child: Container(
                color:
                    Colors.black.withValues(alpha: 0.4 * _fadeAnimation.value),
                width: double.infinity,
                height: double.infinity,
              ),
            ),

            // Modal content
            Center(
              child: AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: _buildModalContent(isSheet: false),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildModalContent({required bool isSheet}) {
    final responsive = ResponsiveHelper.spec(context);
    final double maxWidth =
        responsive.quickAddMaxWidth ?? calendarQuickAddModalMaxWidth;
    final double maxHeight = responsive.quickAddMaxHeight;
    final LocationAutocompleteHelper locationHelper = widget.locationHelper;
    final BorderRadius borderRadius = isSheet
        ? const BorderRadius.vertical(top: Radius.circular(24))
        : BorderRadius.circular(calendarBorderRadius);
    final Color background = isSheet
        ? Theme.of(context).colorScheme.surface
        : calendarContainerColor;
    final List<BoxShadow>? boxShadow = isSheet ? null : calendarMediumShadow;
    Widget shell = Container(
      margin: isSheet ? EdgeInsets.zero : responsive.modalMargin,
      constraints: BoxConstraints(
        maxWidth: isSheet ? double.infinity : maxWidth,
        maxHeight: maxHeight,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: borderRadius,
        boxShadow: boxShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(),

            // Form content
            Flexible(
              child: SingleChildScrollView(
                padding: responsive.contentPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTaskNameInput(locationHelper),
                    const SizedBox(height: calendarGutterMd),
                    _buildDescriptionInput(),
                    const SizedBox(height: calendarGutterMd),
                    _buildLocationField(locationHelper),
                    const SizedBox(height: calendarGutterMd),
                    _buildPriorityToggles(),
                    const TaskSectionDivider(
                      verticalPadding: calendarGutterMd,
                    ),
                    _buildScheduleSection(),
                    const SizedBox(height: calendarGutterMd),
                    _buildDeadlineField(),
                    const TaskSectionDivider(
                      verticalPadding: calendarGutterMd,
                    ),
                    _buildRecurrenceSection(),
                  ],
                ),
              ),
            ),

            // Actions
            _buildActions(),
          ],
        ),
      ),
    );
    if (isSheet) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: shell,
      );
    }
    return shell;
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: calendarGutterLg,
        vertical: calendarGutterMd,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: calendarBorderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.add_task,
            color: calendarTitleColor,
            size: 20,
          ),
          const SizedBox(width: calendarGutterSm),
          Text(
            'Add Task',
            style: calendarTitleTextStyle.copyWith(fontSize: 18),
          ),
          const Spacer(),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _dismissModal,
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.close,
                  color: calendarSubtitleColor,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleTaskNameChanged(String value) {
    final trimmed = value.trim();
    _parserDebounce?.cancel();
    if (trimmed.isEmpty) {
      _clearParserState(clearFields: true);
      return;
    }
    if (trimmed == _lastParserInput) {
      return;
    }
    _parserDebounce = Timer(const Duration(milliseconds: 350), () {
      _runParser(trimmed);
    });
  }

  Future<void> _runParser(String input) async {
    final requestId = ++_parserRequestId;
    try {
      final result = await _parserService.parse(input);
      if (!mounted || requestId != _parserRequestId) {
        return;
      }
      _lastParserInput = input;
      _lastParserResult = result;
      _applyParserResult(result);
    } catch (error) {
      if (!mounted || requestId != _parserRequestId) {
        return;
      }
      _lastParserInput = '';
      _lastParserResult = null;
      _clearParserDrivenFields();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Parser unavailable (${error.runtimeType})')),
      );
    }
  }

  void _applyParserResult(NlAdapterResult result) {
    final CalendarTask task = result.task;
    _lastParserResult = result;
    _isApplyingParser = true;

    if (!_scheduleLocked) {
      final DateTime? start = task.scheduledTime;
      final DateTime? end = task.endDate ??
          (start != null && task.duration != null
              ? start.add(task.duration!)
              : null);
      if (start != null) {
        _formController.updateStart(start);
        if (end != null) {
          _formController.updateEnd(end);
        }
      } else {
        _formController.clearSchedule();
      }
    }

    if (!_deadlineLocked) {
      _formController.setDeadline(task.deadline);
    }

    if (!_recurrenceLocked) {
      final RecurrenceFormValue value =
          RecurrenceFormValue.fromRule(task.recurrence);
      _formController.setRecurrence(value);
    }

    if (!_priorityLocked) {
      final TaskPriority priority = task.priority ?? TaskPriority.none;
      _formController.setImportant(
        priority == TaskPriority.important || priority == TaskPriority.critical,
      );
      _formController.setUrgent(
        priority == TaskPriority.urgent || priority == TaskPriority.critical,
      );
    }

    if (!_locationLocked) {
      _setLocationField(task.location);
    }

    _isApplyingParser = false;
  }

  void _setLocationField(String? value) {
    final String next = value?.trim() ?? '';
    if (_locationController.text == next) {
      return;
    }
    final selection = TextSelection.collapsed(offset: next.length);
    _locationController.value = TextEditingValue(
      text: next,
      selection: selection,
    );
  }

  String _effectiveParserTitle(String fallback) {
    final trimmed = fallback.trim();
    if (_lastParserResult == null) return trimmed;
    if (_lastParserInput != trimmed) return trimmed;
    final parserTitle = _lastParserResult!.task.title.trim();
    return parserTitle.isEmpty ? trimmed : parserTitle;
  }

  void _clearParserState({bool clearFields = false}) {
    _parserDebounce?.cancel();
    _parserRequestId++;
    _lastParserInput = '';
    _lastParserResult = null;
    if (clearFields) {
      _clearParserDrivenFields();
      _resetParserLocks();
    }
  }

  void _clearParserDrivenFields() {
    _isApplyingParser = true;
    if (!_scheduleLocked) {
      _formController.clearSchedule();
    }
    if (!_deadlineLocked) {
      _formController.setDeadline(null);
    }
    if (!_recurrenceLocked) {
      _formController.setRecurrence(const RecurrenceFormValue());
    }
    if (!_priorityLocked) {
      _formController.setImportant(false);
      _formController.setUrgent(false);
    }
    if (!_locationLocked && _locationController.text.isNotEmpty) {
      _locationController.clear();
    }
    _isApplyingParser = false;
  }

  void _handleLocationEdited(String value) {
    if (_isApplyingParser) {
      return;
    }
    _locationLocked = value.trim().isNotEmpty;
  }

  void _onUserStartChanged(DateTime? value) {
    _scheduleLocked = value != null || _formController.endTime != null;
    _formController.updateStart(value);
    if (value == null && _formController.endTime == null) {
      _scheduleLocked = false;
    }
  }

  void _onUserEndChanged(DateTime? value) {
    _scheduleLocked = value != null || _formController.startTime != null;
    _formController.updateEnd(value);
    if (value == null && _formController.startTime == null) {
      _scheduleLocked = false;
    }
  }

  void _onUserScheduleCleared() {
    _scheduleLocked = false;
    _formController.clearSchedule();
  }

  void _onUserDeadlineChanged(DateTime? value) {
    _deadlineLocked = value != null;
    _formController.setDeadline(value);
    if (value == null) {
      _deadlineLocked = false;
    }
  }

  void _onUserRecurrenceChanged(RecurrenceFormValue value) {
    _recurrenceLocked = value.isActive;
    _formController.setRecurrence(value);
    if (!value.isActive) {
      _recurrenceLocked = false;
    }
  }

  void _onUserImportantChanged(bool value) {
    _priorityLocked = true;
    _formController.setImportant(value);
  }

  void _onUserUrgentChanged(bool value) {
    _priorityLocked = true;
    _formController.setUrgent(value);
  }

  void _resetParserLocks() {
    _locationLocked = false;
    _scheduleLocked = false;
    _deadlineLocked = false;
    _recurrenceLocked = false;
    _priorityLocked = false;
  }

  Widget _buildTaskNameInput(LocationAutocompleteHelper helper) {
    const padding = EdgeInsets.symmetric(
      horizontal: calendarGutterMd,
      vertical: calendarGutterMd,
    );
    final field = Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.enter) {
          if (_taskNameController.text.trim().isNotEmpty) {
            _submitTask();
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: TaskTextField(
        controller: _taskNameController,
        focusNode: _taskNameFocusNode,
        autofocus: true,
        labelText: 'Task name *',
        hintText: 'Task name',
        borderRadius: calendarBorderRadius,
        focusBorderColor: calendarPrimaryColor,
        textCapitalization: TextCapitalization.sentences,
        contentPadding: padding,
        onChanged: _handleTaskNameChanged,
      ),
    );

    return LocationInlineSuggestion(
      controller: _taskNameController,
      helper: helper,
      contentPadding: padding,
      textStyle: const TextStyle(
        fontSize: 14,
        color: calendarTitleColor,
      ),
      suggestionColor: calendarSubtitleColor,
      child: field,
    );
  }

  Widget _buildDescriptionInput() {
    return TaskDescriptionField(
      controller: _descriptionController,
      hintText: 'Description (optional)',
      borderRadius: calendarBorderRadius,
      focusBorderColor: calendarPrimaryColor,
      textCapitalization: TextCapitalization.sentences,
    );
  }

  Widget _buildPriorityToggles() {
    return AnimatedBuilder(
      animation: _formController,
      builder: (context, _) {
        return TaskPriorityToggles(
          isImportant: _formController.isImportant,
          isUrgent: _formController.isUrgent,
          spacing: 10,
          onImportantChanged: _onUserImportantChanged,
          onUrgentChanged: _onUserUrgentChanged,
        );
      },
    );
  }

  Widget _buildLocationField(LocationAutocompleteHelper helper) {
    return TaskLocationField(
      controller: _locationController,
      hintText: 'Location (optional)',
      borderRadius: calendarBorderRadius,
      focusBorderColor: calendarPrimaryColor,
      textCapitalization: TextCapitalization.words,
      onChanged: _handleLocationEdited,
      autocomplete: helper,
    );
  }

  Widget _buildScheduleSection() {
    return AnimatedBuilder(
      animation: _formController,
      builder: (context, _) {
        return TaskScheduleSection(
          title: 'Schedule',
          headerStyle: calendarSubtitleTextStyle.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          spacing: calendarGutterSm,
          start: _formController.startTime,
          end: _formController.endTime,
          onStartChanged: _onUserStartChanged,
          onEndChanged: _onUserEndChanged,
          onClear: _onUserScheduleCleared,
        );
      },
    );
  }

  Widget _buildDeadlineField() {
    return AnimatedBuilder(
      animation: _formController,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TaskSectionHeader(
              title: 'Deadline',
              textStyle: calendarSubtitleTextStyle.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: calendarGutterSm),
            DeadlinePickerField(
              value: _formController.deadline,
              onChanged: _onUserDeadlineChanged,
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecurrenceSection() {
    return AnimatedBuilder(
      animation: _formController,
      builder: (context, _) {
        final fallbackWeekday = _formController.startTime?.weekday ??
            widget.prefilledDateTime?.weekday ??
            DateTime.now().weekday;
        return TaskRecurrenceSection(
          title: 'Repeat',
          headerStyle: calendarSubtitleTextStyle.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          spacing: calendarGutterSm,
          value: _formController.recurrence,
          fallbackWeekday: fallbackWeekday,
          spacingConfig: calendarRecurrenceSpacingCompact,
          onChanged: _onUserRecurrenceChanged,
        );
      },
    );
  }

  Widget _buildActions() {
    return AnimatedBuilder(
      animation: _formController,
      builder: (context, _) {
        return ValueListenableBuilder<TextEditingValue>(
          valueListenable: _taskNameController,
          builder: (context, value, __) {
            final bool canSubmit = value.text.trim().isNotEmpty;
            return TaskFormActionsRow(
              includeTopBorder: true,
              padding: calendarPaddingXl,
              gap: calendarGutterMd,
              children: [
                Expanded(
                  child: TaskSecondaryButton(
                    label: 'Cancel',
                    onPressed:
                        _formController.isSubmitting ? null : _dismissModal,
                    foregroundColor: calendarSubtitleColor,
                    hoverForegroundColor: calendarPrimaryColor,
                    hoverBackgroundColor:
                        calendarPrimaryColor.withValues(alpha: 0.06),
                  ),
                ),
                Expanded(
                  child: TaskPrimaryButton(
                    label: 'Add Task',
                    onPressed: canSubmit && !_formController.isSubmitting
                        ? _submitTask
                        : null,
                    isBusy: _formController.isSubmitting,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _submitTask() {
    if (_formController.isSubmitting ||
        _taskNameController.text.trim().isEmpty) {
      return;
    }

    _formController.setSubmitting(true);

    final taskName = _taskNameController.text.trim();
    final taskTitle = _effectiveParserTitle(taskName);
    final description = _descriptionController.text.trim();
    final scheduledTime = _formController.startTime;

    final recurrence =
        scheduledTime != null ? _formController.buildRecurrence() : null;

    final duration = _formController.effectiveDuration ??
        (scheduledTime != null ? const Duration(hours: 1) : null);

    // Create the task
    final task = CalendarTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: taskTitle,
      description: description.isNotEmpty ? description : null,
      scheduledTime: scheduledTime,
      duration: duration,
      priority: _formController.selectedPriority,
      isCompleted: false,
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      deadline: _formController.deadline,
      recurrence: recurrence,
      startHour: scheduledTime != null
          ? scheduledTime.hour + (scheduledTime.minute / 60.0)
          : null,
    );

    widget.onTaskAdded(task);

    _dismissModal();
  }

  Future<void> _dismissModal() async {
    Future<void> popSelfIfPossible() async {
      if (!mounted) {
        return;
      }
      final navigator = Navigator.maybeOf(context);
      if (navigator == null) {
        return;
      }
      await navigator.maybePop();
    }

    if (widget.surface == QuickAddModalSurface.dialog) {
      await _animationController.reverse();
    }

    if (!mounted) {
      return;
    }

    widget.onDismiss?.call();

    if (!mounted) {
      return;
    }

    await popSelfIfPossible();
  }
}

// Helper function to show the modal
Future<void> showQuickAddModal({
  required BuildContext context,
  DateTime? prefilledDateTime,
  String? prefilledText,
  required void Function(CalendarTask task) onTaskAdded,
  required LocationAutocompleteHelper locationHelper,
}) {
  if (ResponsiveHelper.isCompact(context)) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => QuickAddModal(
        surface: QuickAddModalSurface.bottomSheet,
        prefilledDateTime: prefilledDateTime,
        prefilledText: prefilledText,
        onTaskAdded: onTaskAdded,
        locationHelper: locationHelper,
      ),
    );
  }
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    builder: (context) => QuickAddModal(
      prefilledDateTime: prefilledDateTime,
      prefilledText: prefilledText,
      onTaskAdded: onTaskAdded,
      locationHelper: locationHelper,
      onDismiss: () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
    ),
  );
}
