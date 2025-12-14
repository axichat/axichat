import 'dart:async';

import 'package:axichat/src/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:axichat/src/calendar/bloc/base_calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/utils/recurrence_utils.dart';
import 'package:axichat/src/calendar/utils/responsive_helper.dart';
import 'package:axichat/src/calendar/utils/time_formatter.dart';
import 'package:axichat/src/calendar/view/feedback_system.dart';
import 'package:axichat/src/calendar/view/task_input.dart' as task_input;
import 'package:axichat/src/common/ui/ui.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'widgets/calendar_task_title_tooltip.dart';
import 'widgets/task_text_field.dart';

typedef CalendarSearchTileBuilder = Widget Function(
  CalendarTask task, {
  Widget? trailing,
  bool requiresLongPress,
  VoidCallback? onTap,
  VoidCallback? onDragStart,
  bool allowContextMenu,
});

Future<void> showCalendarTaskSearch<B extends BaseCalendarBloc>({
  required BuildContext context,
  required B bloc,
  CalendarCriticalPath? targetPath,
  CalendarSearchTileBuilder? taskTileBuilder,
  bool requiresLongPressForDrag = false,
  Set<String> excludedTaskIds = const <String>{},
  FutureOr<void> Function(CalendarTask task)? onTaskSelected,
  T Function<T>()? locate,
}) async {
  final CalendarCriticalPath? resolvedTargetPath = targetPath;
  B resolveBloc() {
    if (locate != null) {
      try {
        return locate<B>();
      } catch (_) {
        // Fall back to the provided bloc when locate cannot resolve in this context.
      }
    }
    return bloc;
  }

  FutureOr<void> Function(CalendarTask task) defaultHandler;
  if (resolvedTargetPath != null) {
    defaultHandler = (CalendarTask task) {
      resolveBloc().add(
        CalendarEvent.criticalPathTaskAdded(
          pathId: resolvedTargetPath.id,
          taskId: task.id,
        ),
      );
      FeedbackSystem.showSuccess(
        context,
        'Added to ${resolvedTargetPath.name}',
      );
    };
  } else {
    defaultHandler = (CalendarTask task) => task_input.showTaskInput(
          context,
          editingTask: task,
        );
  }

  await showAdaptiveBottomSheet<void>(
    context: context,
    dialogMaxWidth: 760,
    surfacePadding: const EdgeInsets.all(calendarGutterLg),
    builder: (sheetContext) {
      final B resolvedBloc = resolveBloc();
      return _CalendarTaskSearchSheet<B>(
        bloc: resolvedBloc,
        taskTileBuilder: taskTileBuilder,
        requiresLongPressForDrag: requiresLongPressForDrag,
        excludedTaskIds: excludedTaskIds,
        targetPath: resolvedTargetPath,
        onTaskSelected: onTaskSelected ?? defaultHandler,
      );
    },
  );
}

class _CalendarTaskSearchSheet<B extends BaseCalendarBloc>
    extends StatefulWidget {
  const _CalendarTaskSearchSheet({
    required this.bloc,
    required this.taskTileBuilder,
    required this.requiresLongPressForDrag,
    required this.excludedTaskIds,
    required this.targetPath,
    required this.onTaskSelected,
  });

  final B bloc;
  final CalendarSearchTileBuilder? taskTileBuilder;
  final bool requiresLongPressForDrag;
  final Set<String> excludedTaskIds;
  final CalendarCriticalPath? targetPath;
  final FutureOr<void> Function(CalendarTask task) onTaskSelected;

  @override
  State<_CalendarTaskSearchSheet<B>> createState() =>
      _CalendarTaskSearchSheetState<B>();
}

class _CalendarTaskSearchSheetState<B extends BaseCalendarBloc>
    extends State<_CalendarTaskSearchSheet<B>> {
  final TextEditingController _queryController = TextEditingController();
  final FocusNode _queryFocusNode = FocusNode();
  final Set<_QuickFilter> _filters = <_QuickFilter>{};

  @override
  void initState() {
    super.initState();
    _queryFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _queryFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isCompact = ResponsiveHelper.isCompact(context);
    final CalendarCriticalPath? targetPath = widget.targetPath;
    final String title =
        targetPath != null ? 'Add to ${targetPath.name}' : 'Search tasks';
    final String subtitle = targetPath != null
        ? 'Tap a task to append it to the critical path order.'
        : 'Search titles, descriptions, locations, priorities, and deadlines.';
    return BlocBuilder<B, CalendarState>(
      bloc: widget.bloc,
      builder: (context, state) {
        final String query = _queryController.text.trim();
        final List<CalendarTask> results = _search(state, query);
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: context.textTheme.h3.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  AxiIconButton(
                    iconData: Icons.close,
                    iconSize: 16,
                    buttonSize: 34,
                    tapTargetSize: 40,
                    backgroundColor: Colors.transparent,
                    borderColor: Colors.transparent,
                    color: context.colorScheme.mutedForeground,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
              const SizedBox(height: calendarInsetSm),
              Text(
                subtitle,
                style: context.textTheme.muted,
              ),
              const SizedBox(height: calendarGutterSm),
              TaskTextField(
                controller: _queryController,
                focusNode: _queryFocusNode,
                hintText:
                    'title:, desc:, location:, priority:urgent, status:done',
                textInputAction: TextInputAction.search,
                onSubmitted: _handleSubmitted,
                onChanged: (_) => setState(() {}),
                prefix: const Icon(Icons.search, color: calendarSubtitleColor),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: calendarGutterMd,
                  vertical: 10,
                ),
              ),
              const SizedBox(height: calendarInsetSm),
              _FilterRow(
                filters: _filters,
                onFilterToggled: _toggleFilter,
              ),
              const SizedBox(height: calendarInsetSm),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: results.isEmpty
                      ? _EmptySearchState(
                          key: const ValueKey('empty-search'),
                          showHint: query.isEmpty,
                          isCompact: isCompact,
                        )
                      : Scrollbar(
                          key: const ValueKey('results'),
                          child: ListView.separated(
                            padding: EdgeInsets.only(
                              top: calendarInsetSm,
                              bottom: MediaQuery.viewInsetsOf(context).bottom +
                                  calendarInsetMd,
                            ),
                            itemCount: results.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: calendarInsetSm),
                            itemBuilder: (context, index) {
                              final CalendarTask task = results[index];
                              final Widget trailing = _ResultMetadata(task);
                              final bool useCustomTile =
                                  widget.taskTileBuilder != null;
                              final Widget tile = useCustomTile
                                  ? widget.taskTileBuilder!.call(
                                      task,
                                      trailing: trailing,
                                      requiresLongPress:
                                          widget.requiresLongPressForDrag,
                                      onTap: () => _handleTaskSelected(task),
                                      onDragStart: () =>
                                          Navigator.of(context).maybePop(),
                                      allowContextMenu: false,
                                    )
                                  : _SearchResultTile(
                                      task: task,
                                      onTap: () => _handleTaskSelected(task),
                                    );
                              return tile;
                            },
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _toggleFilter(_QuickFilter filter, bool enabled) {
    setState(() {
      if (enabled) {
        _filters.add(filter);
      } else {
        _filters.remove(filter);
      }
    });
  }

  Future<void> _handleTaskSelected(CalendarTask task) async {
    await widget.onTaskSelected(task);
  }

  void _handleSubmitted(String _) {
    setState(() {});
  }

  List<CalendarTask> _search(CalendarState state, String queryText) {
    final Map<String, CalendarTask> tasks = state.model.tasks;
    final CalendarCriticalPath? targetPath = widget.targetPath;
    final _ParsedQuery query = _ParsedQuery.parse(
      queryText,
      targetPath: targetPath,
    );
    final Set<String> excludedBaseIds =
        widget.excludedTaskIds.map((id) => baseTaskIdFrom(id)).toSet();
    if (targetPath != null) {
      excludedBaseIds.addAll(targetPath.taskIds.map(baseTaskIdFrom));
    }

    final List<CalendarTask> matches = <CalendarTask>[];
    for (final CalendarTask task in tasks.values) {
      if (excludedBaseIds.contains(baseTaskIdFrom(task.id))) {
        continue;
      }
      if (!_QuickFilterEvaluator.matches(task, _filters)) {
        continue;
      }
      if (!_QueryMatcher.matches(
        task: task,
        query: query,
        criticalPaths: state.model.criticalPaths,
      )) {
        continue;
      }
      matches.add(task);
    }

    matches.sort(_SearchSorter.compare);
    return matches;
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.filters,
    required this.onFilterToggled,
  });

  final Set<_QuickFilter> filters;
  final void Function(_QuickFilter filter, bool enabled) onFilterToggled;

  @override
  Widget build(BuildContext context) {
    final ShadColorScheme colors = context.colorScheme;
    return Wrap(
      spacing: calendarInsetSm,
      runSpacing: calendarInsetSm,
      children: _QuickFilter.values.map((filter) {
        final bool active = filters.contains(filter);
        final Color background =
            active ? colors.primary.withValues(alpha: 0.12) : colors.card;
        final Color border =
            active ? colors.primary : colors.muted.withValues(alpha: 0.25);
        final Color textColor =
            active ? colors.primary : colors.mutedForeground;
        return InkWell(
          onTap: () => onFilterToggled(filter, !active),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: calendarGutterSm,
              vertical: calendarInsetMd,
            ),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  filter.icon,
                  size: 14,
                  color: textColor,
                ),
                const SizedBox(width: calendarInsetSm),
                Text(
                  filter.label,
                  style: context.textTheme.small.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ).withTapBounce();
      }).toList(),
    );
  }
}

class _ResultMetadata extends StatelessWidget {
  const _ResultMetadata(this.task);

  final CalendarTask task;

  @override
  Widget build(BuildContext context) {
    final DateTime? scheduled = task.scheduledTime;
    final DateTime? deadline = task.deadline;
    if (scheduled == null && deadline == null) {
      return const SizedBox.shrink();
    }
    final List<Widget> tags = <Widget>[];
    if (scheduled != null) {
      tags.add(
        _MetadataTag(
          icon: Icons.schedule,
          label: TimeFormatter.formatFriendlyDateTime(scheduled),
        ),
      );
    }
    if (deadline != null) {
      tags.add(
        _MetadataTag(
          icon: Icons.calendar_today_outlined,
          label: _deadlineLabel(deadline),
        ),
      );
    }
    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: calendarInsetSm,
      runSpacing: calendarInsetSm,
      children: tags,
    );
  }

  String _deadlineLabel(DateTime deadline) {
    final DateTime now = DateTime.now();
    if (deadline.isBefore(now)) {
      return 'Overdue · ${TimeFormatter.formatFriendlyDate(deadline)}';
    }
    return 'Due ${TimeFormatter.formatFriendlyDate(deadline)}';
  }
}

class _MetadataTag extends StatelessWidget {
  const _MetadataTag({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ShadColorScheme colors = context.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: calendarGutterSm,
        vertical: calendarInsetSm,
      ),
      decoration: BoxDecoration(
        color: colors.muted.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: colors.mutedForeground),
          const SizedBox(width: calendarInsetSm),
          Text(
            label,
            style: context.textTheme.muted.copyWith(
              color: colors.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({
    super.key,
    required this.showHint,
    required this.isCompact,
  });

  final bool showHint;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final ShadColorScheme colors = context.colorScheme;
    final TextStyle hintStyle = context.textTheme.muted.copyWith(
      color: colors.mutedForeground,
    );
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: isCompact
              ? calendarGutterLg
              : calendarGutterLg + calendarGutterMd,
          horizontal: calendarGutterLg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search,
              size: 32,
              color: colors.mutedForeground,
            ),
            const SizedBox(height: calendarGutterSm),
            Text(
              showHint ? 'Start typing to search tasks' : 'No results found',
              style: context.textTheme.small.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: calendarInsetSm),
            Text(
              'Use filters like title:, desc:, location:, priority:critical, status:done, deadline:today.',
              style: hintStyle,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.task,
    required this.onTap,
  });

  final CalendarTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ShadColorScheme colors = context.colorScheme;
    final String? subtitle = _subtitle();
    return CalendarTaskTitleTooltip(
      title: task.title,
      child: Material(
        color: colors.card,
        borderRadius: BorderRadius.circular(calendarBorderRadius.toDouble()),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(calendarBorderRadius.toDouble()),
          child: Padding(
            padding: const EdgeInsets.all(calendarGutterMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: context.textTheme.small.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: calendarInsetSm),
                  Text(
                    subtitle,
                    style: context.textTheme.muted,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _subtitle() {
    if (task.scheduledTime != null) {
      return TimeFormatter.formatFriendlyDateTime(task.scheduledTime!);
    }
    if (task.deadline != null) {
      return 'Due ${TimeFormatter.formatFriendlyDate(task.deadline!)}';
    }
    return task.description?.isNotEmpty == true ? task.description : null;
  }
}

enum _QuickFilter {
  scheduled('Scheduled', Icons.event_available),
  unscheduled('Unscheduled', Icons.list_alt_outlined),
  reminders('Reminders', Icons.alarm),
  open('Open', Icons.radio_button_unchecked),
  completed('Completed', Icons.check_circle_outline);

  const _QuickFilter(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _QuickFilterEvaluator {
  const _QuickFilterEvaluator._();

  static bool matches(CalendarTask task, Set<_QuickFilter> filters) {
    if (filters.isEmpty) {
      return true;
    }
    for (final _QuickFilter filter in filters) {
      switch (filter) {
        case _QuickFilter.scheduled:
          if (task.scheduledTime == null) return false;
          break;
        case _QuickFilter.unscheduled:
          if (task.scheduledTime != null) return false;
          break;
        case _QuickFilter.reminders:
          if (task.deadline == null || task.scheduledTime != null) {
            return false;
          }
          break;
        case _QuickFilter.open:
          if (task.isCompleted) return false;
          break;
        case _QuickFilter.completed:
          if (!task.isCompleted) return false;
          break;
      }
    }
    return true;
  }
}

class _ParsedQuery {
  const _ParsedQuery({
    required this.generalTerms,
    required this.titleTerms,
    required this.descriptionTerms,
    required this.locationTerms,
    required this.priority,
    required this.statusCompleted,
    required this.scheduledFilter,
    required this.deadlineFilter,
    required this.recurrenceFilter,
    required this.pathTerms,
    required this.idTerms,
  });

  final List<String> generalTerms;
  final List<String> titleTerms;
  final List<String> descriptionTerms;
  final List<String> locationTerms;
  final TaskPriority? priority;
  final bool? statusCompleted;
  final _ScheduledFilter? scheduledFilter;
  final _DeadlineFilter? deadlineFilter;
  final _RecurrenceFilter? recurrenceFilter;
  final List<String> pathTerms;
  final List<String> idTerms;

  static _ParsedQuery parse(
    String raw, {
    CalendarCriticalPath? targetPath,
  }) {
    final String normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const _ParsedQuery(
        generalTerms: <String>[],
        titleTerms: <String>[],
        descriptionTerms: <String>[],
        locationTerms: <String>[],
        priority: null,
        statusCompleted: null,
        scheduledFilter: null,
        deadlineFilter: null,
        recurrenceFilter: null,
        pathTerms: <String>[],
        idTerms: <String>[],
      );
    }

    final List<String> general = <String>[];
    final List<String> title = <String>[];
    final List<String> desc = <String>[];
    final List<String> location = <String>[];
    final List<String> path = <String>[];
    final List<String> ids = <String>[];
    TaskPriority? priority;
    bool? completed;
    _ScheduledFilter? scheduleFilter;
    _DeadlineFilter? deadlineFilter;
    _RecurrenceFilter? recurrenceFilter;

    final RegExp tokenExp = RegExp(r'("[^"]+"|\S+)');
    final Iterable<RegExpMatch> matches = tokenExp.allMatches(normalized);

    for (final RegExpMatch match in matches) {
      final String token = match.group(0) ?? '';
      final String trimmedToken = token.startsWith('"') && token.endsWith('"')
          ? token.substring(1, token.length - 1)
          : token;
      final int colonIndex = trimmedToken.indexOf(':');
      if (colonIndex > 0) {
        final String key = trimmedToken.substring(0, colonIndex);
        final String value = trimmedToken.substring(colonIndex + 1);
        if (value.isEmpty) {
          continue;
        }
        switch (key) {
          case 'title':
          case 't':
            title.add(value);
            break;
          case 'desc':
          case 'description':
          case 'd':
            desc.add(value);
            break;
          case 'location':
          case 'loc':
            location.add(value);
            break;
          case 'priority':
          case 'p':
            priority = _PriorityParser.parse(value);
            break;
          case 'status':
          case 'state':
            completed = _StatusParser.parse(value);
            break;
          case 'scheduled':
          case 'schedule':
            scheduleFilter = _ScheduledFilter.from(value);
            break;
          case 'deadline':
          case 'due':
            deadlineFilter = _DeadlineFilter.from(value);
            break;
          case 'recurrence':
          case 'repeat':
            recurrenceFilter = _RecurrenceFilter.from(value);
            break;
          case 'path':
            path.add(value);
            break;
          case 'id':
            ids.add(value);
            break;
          default:
            general.add(trimmedToken);
            break;
        }
      } else {
        general.add(trimmedToken);
      }
    }

    if (targetPath != null) {
      path.add(targetPath.name.toLowerCase());
    }

    return _ParsedQuery(
      generalTerms: general,
      titleTerms: title,
      descriptionTerms: desc,
      locationTerms: location,
      priority: priority,
      statusCompleted: completed,
      scheduledFilter: scheduleFilter,
      deadlineFilter: deadlineFilter,
      recurrenceFilter: recurrenceFilter,
      pathTerms: path,
      idTerms: ids,
    );
  }
}

class _QueryMatcher {
  const _QueryMatcher._();

  static bool matches({
    required CalendarTask task,
    required _ParsedQuery query,
    required Map<String, CalendarCriticalPath> criticalPaths,
  }) {
    if (!_textMatches(task.title, query.titleTerms)) {
      return false;
    }
    if (!_textMatches(task.description, query.descriptionTerms)) {
      return false;
    }
    if (!_textMatches(task.location, query.locationTerms)) {
      return false;
    }
    if (!_priorityMatches(task.priority, query.priority)) {
      return false;
    }
    if (!_statusMatches(task.isCompleted, query.statusCompleted)) {
      return false;
    }
    if (!_scheduledMatches(task, query.scheduledFilter)) {
      return false;
    }
    if (!_deadlineMatches(task.deadline, query.deadlineFilter)) {
      return false;
    }
    if (!_recurrenceMatches(task, query.recurrenceFilter)) {
      return false;
    }
    if (!_pathMatches(task, query.pathTerms, criticalPaths)) {
      return false;
    }
    if (!_idMatches(task, query.idTerms)) {
      return false;
    }

    final bool hasScopedTextTerms = query.titleTerms.isNotEmpty ||
        query.descriptionTerms.isNotEmpty ||
        query.locationTerms.isNotEmpty;
    final Iterable<String?> defaultFields = <String?>[
      task.title,
      task.description,
    ];
    final Iterable<String?> extendedFields = <String?>[
      ...defaultFields,
      task.location,
      task.deadline?.toIso8601String(),
      task.scheduledTime?.toIso8601String(),
      task.priority?.name,
    ];

    if (!_matchesAnyField(
      fields: hasScopedTextTerms ? extendedFields : defaultFields,
      terms: query.generalTerms,
    )) {
      return false;
    }
    return true;
  }

  static bool _textMatches(String? value, List<String> terms) {
    if (terms.isEmpty) {
      return true;
    }
    final String haystack = (value ?? '').toLowerCase();
    return terms.every(haystack.contains);
  }

  static bool _priorityMatches(TaskPriority? value, TaskPriority? query) {
    if (query == null) {
      return true;
    }
    return (value ?? TaskPriority.none) == query;
  }

  static bool _statusMatches(bool completed, bool? query) {
    if (query == null) {
      return true;
    }
    return completed == query;
  }

  static bool _scheduledMatches(
    CalendarTask task,
    _ScheduledFilter? filter,
  ) {
    if (filter == null) {
      return true;
    }
    switch (filter) {
      case _ScheduledFilter.any:
        return true;
      case _ScheduledFilter.scheduled:
        return task.scheduledTime != null;
      case _ScheduledFilter.unscheduled:
        return task.scheduledTime == null;
      case _ScheduledFilter.today:
        final DateTime? start = task.scheduledTime;
        if (start == null) return false;
        final DateTime today = DateUtils.dateOnly(DateTime.now());
        return DateUtils.isSameDay(start, today);
    }
  }

  static bool _deadlineMatches(DateTime? deadline, _DeadlineFilter? filter) {
    if (filter == null) {
      return true;
    }
    if (deadline == null) {
      return filter == _DeadlineFilter.none;
    }
    final DateTime now = DateTime.now();
    switch (filter) {
      case _DeadlineFilter.any:
        return true;
      case _DeadlineFilter.none:
        return false;
      case _DeadlineFilter.overdue:
        return deadline.isBefore(now);
      case _DeadlineFilter.today:
        return DateUtils.isSameDay(deadline, now);
      case _DeadlineFilter.tomorrow:
        final DateTime tomorrow = DateUtils.dateOnly(now).add(
          const Duration(days: 1),
        );
        return DateUtils.isSameDay(deadline, tomorrow);
      case _DeadlineFilter.thisWeek:
        final DateTime today = DateUtils.dateOnly(now);
        final DateTime endOfWeek = today.add(const Duration(days: 6));
        return !deadline.isBefore(today) && !deadline.isAfter(endOfWeek);
    }
  }

  static bool _recurrenceMatches(
    CalendarTask task,
    _RecurrenceFilter? filter,
  ) {
    if (filter == null) {
      return true;
    }
    final RecurrenceRule? recurrence = task.recurrence;
    switch (filter) {
      case _RecurrenceFilter.any:
        return true;
      case _RecurrenceFilter.once:
        return recurrence == null ||
            recurrence.frequency == RecurrenceFrequency.none;
      case _RecurrenceFilter.recurring:
        return recurrence != null &&
            recurrence.frequency != RecurrenceFrequency.none;
      case _RecurrenceFilter.daily:
        return recurrence?.frequency == RecurrenceFrequency.daily;
      case _RecurrenceFilter.weekly:
        return recurrence?.frequency == RecurrenceFrequency.weekly;
      case _RecurrenceFilter.monthly:
        return recurrence?.frequency == RecurrenceFrequency.monthly;
    }
  }

  static bool _pathMatches(
    CalendarTask task,
    List<String> terms,
    Map<String, CalendarCriticalPath> paths,
  ) {
    if (terms.isEmpty) {
      return true;
    }
    final String baseId = baseTaskIdFrom(task.id);
    final Iterable<CalendarCriticalPath> matchingPaths = paths.values.where(
      (path) => path.taskIds.any((id) => baseTaskIdFrom(id) == baseId),
    );
    if (matchingPaths.isEmpty) {
      return false;
    }
    final String names =
        matchingPaths.map((path) => path.name.toLowerCase()).join(' ');
    return terms.every((term) => names.contains(term));
  }

  static bool _idMatches(CalendarTask task, List<String> idTerms) {
    if (idTerms.isEmpty) {
      return true;
    }
    final String haystack = '${task.id} ${task.baseId}'.toLowerCase();
    return idTerms.every(haystack.contains);
  }

  static bool _matchesAnyField({
    required Iterable<String?> fields,
    required List<String> terms,
  }) {
    if (terms.isEmpty) {
      return true;
    }
    final String haystack = fields
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .map((value) => value.toLowerCase())
        .join(' ');
    if (haystack.isEmpty) {
      return false;
    }
    return terms.every((term) => haystack.contains(term.toLowerCase()));
  }
}

class _PriorityParser {
  const _PriorityParser._();

  static TaskPriority? parse(String value) {
    switch (value) {
      case 'critical':
        return TaskPriority.critical;
      case 'urgent':
        return TaskPriority.urgent;
      case 'important':
        return TaskPriority.important;
      case 'none':
        return TaskPriority.none;
      default:
        return null;
    }
  }
}

class _StatusParser {
  const _StatusParser._();

  static bool? parse(String value) {
    switch (value) {
      case 'done':
      case 'completed':
      case 'complete':
        return true;
      case 'open':
      case 'todo':
      case 'pending':
        return false;
      default:
        return null;
    }
  }
}

enum _ScheduledFilter {
  any,
  scheduled,
  unscheduled,
  today;

  static _ScheduledFilter? from(String value) {
    switch (value) {
      case 'any':
        return _ScheduledFilter.any;
      case 'scheduled':
        return _ScheduledFilter.scheduled;
      case 'unscheduled':
        return _ScheduledFilter.unscheduled;
      case 'today':
        return _ScheduledFilter.today;
      default:
        return null;
    }
  }
}

enum _DeadlineFilter {
  any,
  none,
  overdue,
  today,
  tomorrow,
  thisWeek;

  static _DeadlineFilter? from(String value) {
    switch (value) {
      case 'any':
        return _DeadlineFilter.any;
      case 'none':
        return _DeadlineFilter.none;
      case 'overdue':
        return _DeadlineFilter.overdue;
      case 'today':
        return _DeadlineFilter.today;
      case 'tomorrow':
        return _DeadlineFilter.tomorrow;
      case 'week':
      case 'thisweek':
        return _DeadlineFilter.thisWeek;
      default:
        return null;
    }
  }
}

enum _RecurrenceFilter {
  any,
  once,
  recurring,
  daily,
  weekly,
  monthly;

  static _RecurrenceFilter? from(String value) {
    switch (value) {
      case 'any':
        return _RecurrenceFilter.any;
      case 'once':
      case 'single':
        return _RecurrenceFilter.once;
      case 'recurring':
      case 'repeat':
        return _RecurrenceFilter.recurring;
      case 'daily':
        return _RecurrenceFilter.daily;
      case 'weekly':
        return _RecurrenceFilter.weekly;
      case 'monthly':
        return _RecurrenceFilter.monthly;
      default:
        return null;
    }
  }
}

class _SearchSorter {
  const _SearchSorter._();

  static int compare(CalendarTask a, CalendarTask b) {
    final DateTime aTime = a.scheduledTime ?? a.deadline ?? a.createdAt;
    final DateTime bTime = b.scheduledTime ?? b.deadline ?? b.createdAt;
    return aTime.compareTo(bTime);
  }
}
