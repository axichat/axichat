// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:axichat/src/calendar/bloc/base_calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/utils/calendar_state_waiter.dart';
import 'package:axichat/src/calendar/utils/location_autocomplete.dart';
import 'package:axichat/src/calendar/utils/recurrence_utils.dart';
import 'package:axichat/src/calendar/utils/responsive_helper.dart';
import 'package:axichat/src/calendar/utils/time_formatter.dart';
import 'package:axichat/src/calendar/view/edit_task_dropdown.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_modal_scope.dart';
import 'package:axichat/src/calendar/view/feedback_system.dart';
import 'package:axichat/src/calendar/view/task_edit_session_tracker.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'widgets/calendar_sheet_header.dart';
import 'widgets/calendar_task_title_hover_reporter.dart';
import 'widgets/task_text_field.dart';

typedef CalendarSearchTileBuilder = Widget Function(
  CalendarTask task, {
  Widget? trailing,
  bool requiresLongPress,
  VoidCallback? onTap,
  VoidCallback? onDragStart,
  bool allowContextMenu,
});

const int _taskSearchSingleCount = 1;
const String _queryKeyCategory = 'category';
const String _queryKeyCategoryShort = 'cat';
const String _queryKeyTag = 'tag';
const String _queryKeyTags = 'tags';

String? _resolveCriticalPathName({
  required BaseCalendarBloc bloc,
  required String pathId,
  required String fallbackName,
}) {
  final String? name = bloc.state.model.criticalPaths[pathId]?.name;
  final String trimmedFallback = fallbackName.trim();
  if (name != null && name.trim().isNotEmpty) {
    return name;
  }
  if (trimmedFallback.isNotEmpty) {
    return trimmedFallback;
  }
  return null;
}

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
    defaultHandler = (CalendarTask task) async {
      final B resolvedBloc = resolveBloc();
      final CalendarCriticalPath? latestPath =
          resolvedBloc.state.model.criticalPaths[resolvedTargetPath.id];
      final CalendarCriticalPath effectivePath =
          latestPath ?? resolvedTargetPath;
      if (effectivePath.taskIds.contains(task.baseId)) {
        FeedbackSystem.showError(
          context,
          context.l10n
              .calendarCriticalPathAlreadyContainsTasks(_taskSearchSingleCount),
        );
        return;
      }
      resolvedBloc.add(
        CalendarEvent.criticalPathTaskAdded(
          pathId: resolvedTargetPath.id,
          taskId: task.id,
        ),
      );
      final Set<String> taskIds = <String>{}..add(task.baseId);
      final bool added = await waitForCriticalPathTasks(
        bloc: resolvedBloc,
        pathId: resolvedTargetPath.id,
        taskIds: taskIds,
      );
      if (!context.mounted) {
        return;
      }
      if (!added) {
        FeedbackSystem.showError(
          context,
          context.l10n.calendarCriticalPathAddFailed(_taskSearchSingleCount),
        );
        return;
      }
      final String? resolvedName = _resolveCriticalPathName(
        bloc: resolvedBloc,
        pathId: resolvedTargetPath.id,
        fallbackName: resolvedTargetPath.name,
      );
      if (resolvedName == null) {
        FeedbackSystem.showError(
          context,
          context.l10n.calendarCriticalPathAddFailed(_taskSearchSingleCount),
        );
        return;
      }
      FeedbackSystem.showSuccess(
        context,
        context.l10n.calendarCriticalPathAddSuccess(
          _taskSearchSingleCount,
          resolvedName,
        ),
      );
    };
  } else {
    defaultHandler = (CalendarTask task) async {
      final B resolvedBloc = resolveBloc();
      final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
      final LocationAutocompleteHelper locationHelper =
          LocationAutocompleteHelper.fromState(resolvedBloc.state);
      final collectionMethod = resolvedBloc.state.model.collection?.method;
      final String baseId = baseTaskIdFrom(task.id);
      final CalendarTask latestTask =
          resolvedBloc.state.model.tasks[baseId] ?? task;
      final CalendarTask? storedTask = resolvedBloc.state.model.tasks[task.id];
      final String? occurrenceKey = occurrenceKeyFrom(task.id);
      final CalendarTask? occurrenceTask =
          storedTask == null && occurrenceKey != null
              ? latestTask.occurrenceForId(task.id)
              : null;
      final CalendarTask displayTask =
          storedTask ?? occurrenceTask ?? latestTask;
      final bool shouldUpdateOccurrence =
          storedTask == null && occurrenceTask != null;

      if (!TaskEditSessionTracker.instance.begin(task.id, resolvedBloc)) {
        return;
      }
      try {
        Navigator.of(context).maybePop();
        await Future<void>.delayed(Duration.zero);
        if (!context.mounted) {
          return;
        }
        final BuildContext modalContext = context.calendarModalContext;
        await showAdaptiveBottomSheet<void>(
          context: modalContext,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          showCloseButton: false,
          builder: (sheetContext) {
            final mediaQuery = MediaQuery.of(sheetContext);
            final double maxHeight =
                mediaQuery.size.height - mediaQuery.viewPadding.vertical;
            void closeSheet() {
              Navigator.of(sheetContext).maybePop();
            }

            return BlocProvider.value(
              value: resolvedBloc,
              child: Builder(
                builder: (context) => EditTaskDropdown<B>(
                  task: displayTask,
                  maxHeight: maxHeight,
                  isSheet: true,
                  collectionMethod: collectionMethod,
                  onClose: closeSheet,
                  scaffoldMessenger: scaffoldMessenger,
                  locationHelper: locationHelper,
                  onTaskUpdated: (updatedTask) {
                    context
                        .read<B>()
                        .add(CalendarEvent.taskUpdated(task: updatedTask));
                  },
                  onOccurrenceUpdated: shouldUpdateOccurrence
                      ? (
                          updatedTask,
                          scope, {
                          required bool scheduleTouched,
                          required bool checklistTouched,
                        }) {
                          if (scheduleTouched || checklistTouched) {
                            context.read<B>().add(
                                  CalendarEvent.taskOccurrenceUpdated(
                                    taskId: baseId,
                                    occurrenceId: task.id,
                                    scheduledTime: scheduleTouched
                                        ? updatedTask.scheduledTime
                                        : null,
                                    duration: scheduleTouched
                                        ? updatedTask.duration
                                        : null,
                                    endDate: scheduleTouched
                                        ? updatedTask.endDate
                                        : null,
                                    checklist: checklistTouched
                                        ? updatedTask.checklist
                                        : null,
                                    range: scope.range,
                                  ),
                                );
                          }
                        }
                      : null,
                  onTaskDeleted: (taskId) {
                    context
                        .read<B>()
                        .add(CalendarEvent.taskDeleted(taskId: taskId));
                    closeSheet();
                  },
                ),
              ),
            );
          },
        );
      } finally {
        TaskEditSessionTracker.instance.end(task.id, resolvedBloc);
      }
    };
  }

  final BuildContext modalContext = context.calendarModalContext;
  await showAdaptiveBottomSheet<void>(
    context: modalContext,
    isScrollControlled: true,
    dialogMaxWidth: 760,
    surfacePadding: EdgeInsets.all(context.spacing.m),
    showCloseButton: false,
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
    final spacing = context.spacing;
    final CalendarCriticalPath? targetPath = widget.targetPath;
    final l10n = context.l10n;
    final String title = targetPath != null
        ? l10n.calendarTaskSearchAddToTitle(targetPath.name)
        : l10n.calendarTaskSearchTitle;
    final String subtitle = targetPath != null
        ? l10n.calendarTaskSearchAddToSubtitle
        : l10n.calendarTaskSearchSubtitle;
    return BlocBuilder<B, CalendarState>(
      bloc: widget.bloc,
      builder: (context, state) {
        final String query = _queryController.text.trim();
        final List<CalendarTask> results = _search(state, query);
        return LayoutBuilder(
          builder: (context, constraints) {
            final mediaQuery = MediaQuery.of(context);
            final double keyboardInset = mediaQuery.viewInsets.bottom;
            final double maxHeight = constraints.hasBoundedHeight
                ? constraints.maxHeight
                : mediaQuery.size.height;
            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: CustomScrollView(
                shrinkWrap: true,
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CalendarSheetHeader(
                          title: title,
                          subtitle: subtitle,
                          onClose: () => Navigator.of(context).maybePop(),
                        ),
                        SizedBox(height: spacing.s),
                        TaskTextField(
                          controller: _queryController,
                          focusNode: _queryFocusNode,
                          hintText: l10n.calendarTaskSearchHint,
                          textInputAction: TextInputAction.search,
                          onSubmitted: _handleSubmitted,
                          onChanged: (_) => setState(() {}),
                          prefix: Icon(
                            Icons.search,
                            color: calendarSubtitleColor,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: spacing.m,
                            vertical: spacing.s,
                          ),
                        ),
                        SizedBox(height: spacing.xxs),
                        _FilterRow(
                          filters: _filters,
                          onFilterToggled: _toggleFilter,
                        ),
                        SizedBox(height: spacing.xxs),
                      ],
                    ),
                  ),
                  if (results.isEmpty)
                    SliverToBoxAdapter(
                      child: _EmptySearchState(
                        key: const ValueKey('empty-search'),
                        showHint: query.isEmpty,
                        isCompact: isCompact,
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.only(
                        top: spacing.xxs,
                        bottom: spacing.xs + keyboardInset,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((
                          context,
                          index,
                        ) {
                          if (index.isOdd) {
                            return SizedBox(height: spacing.xxs);
                          }
                          final CalendarTask task = results[index ~/ 2];
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
                        }, childCount: (results.length * 2) - 1),
                      ),
                    ),
                ],
              ),
            );
          },
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
  const _FilterRow({required this.filters, required this.onFilterToggled});

  final Set<_QuickFilter> filters;
  final void Function(_QuickFilter filter, bool enabled) onFilterToggled;

  @override
  Widget build(BuildContext context) {
    final ShadColorScheme colors = context.colorScheme;
    final double iconSize = context.sizing.menuItemIconSize;
    final spacing = context.spacing;
    return Wrap(
      spacing: spacing.xxs,
      runSpacing: spacing.xxs,
      children: _QuickFilter.values.map((filter) {
        final bool active = filters.contains(filter);
        final Color background =
            active ? colors.primary.withValues(alpha: 0.12) : colors.card;
        final Color border =
            active ? colors.primary : colors.muted.withValues(alpha: 0.25);
        final Color textColor =
            active ? colors.primary : colors.mutedForeground;
        final RoundedSuperellipseBorder shape = RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(context.radii.squircle));
        final RoundedSuperellipseBorder decoratedShape =
            RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(context.radii.squircle),
          side: BorderSide(color: border, width: context.borderSide.width),
        );
        return AxiTapBounce(
          child: ShadFocusable(
            canRequestFocus: true,
            builder: (context, _, __) {
              return Material(
                type: MaterialType.transparency,
                shape: shape,
                clipBehavior: Clip.antiAlias,
                child: ShadGestureDetector(
                  cursor: SystemMouseCursors.click,
                  onTap: () => onFilterToggled(filter, !active),
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: background,
                      shape: decoratedShape,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: spacing.s,
                        vertical: spacing.xs,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(filter.icon, size: iconSize, color: textColor),
                          SizedBox(width: spacing.xxs),
                          Text(
                            filter.label(context),
                            style: context.textTheme.label.strong.copyWith(
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      }).toList(),
    );
  }
}

String _formatDeadlineLabel(BuildContext context, DateTime deadline) {
  final DateTime now = DateTime.now();
  final String formatted = TimeFormatter.formatFriendlyDate(deadline);
  if (deadline.isBefore(now)) {
    return context.l10n.calendarTaskSearchOverdueDate(formatted);
  }
  return context.l10n.calendarTaskSearchDueDate(formatted);
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
          label: TimeFormatter.formatFriendlyDateTime(
            context.l10n,
            scheduled,
          ),
        ),
      );
    }
    if (deadline != null) {
      tags.add(
        _MetadataTag(
          icon: Icons.calendar_today_outlined,
          label: _formatDeadlineLabel(context, deadline),
        ),
      );
    }
    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: context.spacing.xxs,
      runSpacing: context.spacing.xxs,
      children: tags,
    );
  }
}

class _MetadataTag extends StatelessWidget {
  const _MetadataTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ShadColorScheme colors = context.colorScheme;
    final spacing = context.spacing;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.s,
        vertical: spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colors.muted.withValues(alpha: 0.06),
        borderRadius: context.radius,
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: context.sizing.menuItemIconSize,
            color: colors.mutedForeground,
          ),
          SizedBox(width: spacing.xxs),
          Text(
            label,
            style: context.textTheme.label.strong
                .copyWith(color: colors.mutedForeground),
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
    final spacing = context.spacing;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: isCompact ? spacing.m : spacing.l,
          horizontal: spacing.m,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search,
              size: context.sizing.menuItemHeight,
              color: colors.mutedForeground,
            ),
            SizedBox(height: spacing.s),
            Text(
              showHint
                  ? context.l10n.calendarTaskSearchEmptyPrompt
                  : context.l10n.calendarTaskSearchEmptyNoResults,
              style: context.textTheme.small.strong,
            ),
            SizedBox(height: spacing.xxs),
            Text(
              context.l10n.calendarTaskSearchEmptyHint,
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
  const _SearchResultTile({required this.task, required this.onTap});

  final CalendarTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ShadColorScheme colors = context.colorScheme;
    final String? subtitle = _subtitle(context);
    return CalendarTaskTitleHoverReporter(
      title: task.title,
      child: AxiTapBounce(
        child: ShadFocusable(
          canRequestFocus: true,
          builder: (context, _, __) {
            final RoundedSuperellipseBorder shape = RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(context.radii.squircle));
            return Material(
              type: MaterialType.transparency,
              shape: shape,
              clipBehavior: Clip.antiAlias,
              child: ShadGestureDetector(
                cursor: SystemMouseCursors.click,
                onTap: onTap,
                child: DecoratedBox(
                  decoration: ShapeDecoration(color: colors.card, shape: shape),
                  child: Padding(
                    padding: EdgeInsets.all(context.spacing.m),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: context.textTheme.small.strong,
                        ),
                        if (subtitle != null) ...[
                          SizedBox(height: context.spacing.xxs),
                          Text(subtitle, style: context.textTheme.muted),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String? _subtitle(BuildContext context) {
    if (task.scheduledTime != null) {
      return TimeFormatter.formatFriendlyDateTime(
        context.l10n,
        task.scheduledTime!,
      );
    }
    if (task.deadline != null) {
      return _formatDeadlineLabel(context, task.deadline!);
    }
    return task.description?.isNotEmpty == true ? task.description : null;
  }
}

enum _QuickFilter {
  scheduled(Icons.event_available),
  unscheduled(Icons.list_alt_outlined),
  reminders(Icons.alarm),
  open(Icons.radio_button_unchecked),
  completed(Icons.check_circle_outline);

  const _QuickFilter(this.icon);

  final IconData icon;
}

extension _QuickFilterLabelX on _QuickFilter {
  String label(BuildContext context) => switch (this) {
        _QuickFilter.scheduled =>
          context.l10n.calendarTaskSearchFilterScheduled,
        _QuickFilter.unscheduled =>
          context.l10n.calendarTaskSearchFilterUnscheduled,
        _QuickFilter.reminders =>
          context.l10n.calendarTaskSearchFilterReminders,
        _QuickFilter.open => context.l10n.calendarTaskSearchFilterOpen,
        _QuickFilter.completed =>
          context.l10n.calendarTaskSearchFilterCompleted,
      };
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
          if (!task.isUnscheduled) return false;
          break;
        case _QuickFilter.reminders:
          if (!task.isReminder) return false;
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
    required this.categoryTerms,
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
  final List<String> categoryTerms;
  final TaskPriority? priority;
  final bool? statusCompleted;
  final _ScheduledFilter? scheduledFilter;
  final _DeadlineFilter? deadlineFilter;
  final _RecurrenceFilter? recurrenceFilter;
  final List<String> pathTerms;
  final List<String> idTerms;

  static _ParsedQuery parse(String raw, {CalendarCriticalPath? targetPath}) {
    final String normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const _ParsedQuery(
        generalTerms: <String>[],
        titleTerms: <String>[],
        descriptionTerms: <String>[],
        locationTerms: <String>[],
        categoryTerms: <String>[],
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
    final List<String> categories = <String>[];
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
          case _queryKeyCategory:
          case _queryKeyCategoryShort:
          case _queryKeyTag:
          case _queryKeyTags:
            categories.add(value);
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
      categoryTerms: categories,
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
    if (!_categoryMatches(task, query.categoryTerms)) {
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
        query.locationTerms.isNotEmpty ||
        query.categoryTerms.isNotEmpty;
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
      _categoryHaystack(task),
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

  static bool _categoryMatches(CalendarTask task, List<String> terms) {
    if (terms.isEmpty) {
      return true;
    }
    final List<String> categories =
        task.icsMeta?.categories ?? const <String>[];
    if (categories.isEmpty) {
      return false;
    }
    final String haystack = categories
        .map((category) => category.trim().toLowerCase())
        .where((category) => category.isNotEmpty)
        .join(' ');
    if (haystack.isEmpty) {
      return false;
    }
    return terms.every(haystack.contains);
  }

  static String? _categoryHaystack(CalendarTask task) {
    final List<String> categories =
        task.icsMeta?.categories ?? const <String>[];
    if (categories.isEmpty) {
      return null;
    }
    final String joined = categories
        .map((category) => category.trim())
        .where((category) => category.isNotEmpty)
        .join(' ');
    return joined.isEmpty ? null : joined;
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

  static bool _scheduledMatches(CalendarTask task, _ScheduledFilter? filter) {
    if (filter == null) {
      return true;
    }
    switch (filter) {
      case _ScheduledFilter.any:
        return true;
      case _ScheduledFilter.scheduled:
        return task.scheduledTime != null;
      case _ScheduledFilter.unscheduled:
        return task.isUnscheduled;
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
        final DateTime tomorrow = DateUtils.dateOnly(
          now,
        ).add(const Duration(days: 1));
        return DateUtils.isSameDay(deadline, tomorrow);
      case _DeadlineFilter.thisWeek:
        final DateTime today = DateUtils.dateOnly(now);
        final DateTime endOfWeek = today.add(const Duration(days: 6));
        return !deadline.isBefore(today) && !deadline.isAfter(endOfWeek);
    }
  }

  static bool _recurrenceMatches(CalendarTask task, _RecurrenceFilter? filter) {
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
