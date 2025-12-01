import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:axichat/src/calendar/bloc/base_calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/utils/responsive_helper.dart';
import 'calendar_grid.dart';
import 'error_display.dart';
import 'feedback_system.dart';
import 'loading_indicator.dart';
import 'sync_controls.dart';

abstract class BaseCalendarWidget<T extends BaseCalendarBloc>
    extends StatefulWidget {
  const BaseCalendarWidget({super.key, required this.isGuestMode});

  final bool isGuestMode;
}

abstract class BaseCalendarWidgetState<W extends BaseCalendarWidget<T>,
    T extends BaseCalendarBloc> extends State<W> {
  Widget buildTaskTile(CalendarTask task, bool compact);
  void showTaskInput(BuildContext context, DateTime initialDate);

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<T, CalendarState>(
      listener: (context, state) {
        if (state.error != null) {
          if (context.mounted) {
            final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
            if (scaffoldMessenger != null) {
              ErrorSnackBar.show(
                context,
                state.error!,
                onRetry: () {
                  if (context.mounted) {
                    context.read<T>().add(const CalendarEvent.errorCleared());
                  }
                },
              );
            }
          }
        }
      },
      builder: (context, state) {
        final tasks = _getTasksForSelectedDate(state);
        final dateLabel = _formatDate(state.selectedDate, state.viewMode);
        Future<void> handleRefresh() async {
          context.read<T>().add(const CalendarEvent.dataChanged());
          await Future.delayed(const Duration(milliseconds: 500));
        }

        return Scaffold(
          backgroundColor: calendarBackgroundColor,
          appBar: _CalendarAppBar(
            isGuestMode: widget.isGuestMode,
            title: widget.isGuestMode ? 'Guest Calendar' : 'Calendar',
            subtitle: dateLabel,
            canPop: Navigator.canPop(context),
            onBack:
                Navigator.canPop(context) ? () => Navigator.pop(context) : null,
            selectedView: state.viewMode,
            onViewChanged: (view) {
              context.read<T>().add(CalendarEvent.viewChanged(view: view));
            },
            syncButton: widget.isGuestMode
                ? null
                : _CalendarSyncButton(
                    state: state,
                  ),
          ),
          body: Container(
            color: calendarBackgroundColor,
            child: Column(
              children: [
                if (widget.isGuestMode) const _CalendarGuestBanner(),
                if (state.error != null)
                  Container(
                    margin: calendarPaddingXl,
                    child: ErrorDisplay(
                      error: state.error!,
                      onRetry: () {
                        context
                            .read<T>()
                            .add(const CalendarEvent.errorCleared());
                      },
                      onDismiss: () {
                        context
                            .read<T>()
                            .add(const CalendarEvent.errorCleared());
                      },
                    ),
                  ),
                Expanded(
                  child: Container(
                    margin: calendarPaddingXl,
                    child: ResponsiveHelper.layoutBuilder(
                      context,
                      mobile: _CalendarMobileLayout(
                        dateLabel: dateLabel,
                        onPrevious: () => _changeDate(-1),
                        onNext: () => _changeDate(1),
                        isLoading: state.isLoading,
                        tasks: tasks,
                        onRefresh: handleRefresh,
                        taskBuilder: (task, isCompact) =>
                            buildTaskTile(task, isCompact),
                      ),
                      tablet: _CalendarTabletLayout<T>(
                        state: state,
                        isLoading: state.isLoading,
                        tasks: tasks,
                        onRefresh: handleRefresh,
                        taskBuilder: (task, isCompact) =>
                            buildTaskTile(task, isCompact),
                        onTaskDragEnd: (task, newTime) {
                          final normalized =
                              task.normalizedForInteraction(newTime);
                          context.read<T>().commitTaskInteraction(normalized);
                        },
                        onDateSelected: (date) => context
                            .read<T>()
                            .add(CalendarEvent.dateSelected(date: date)),
                        onViewChanged: (view) => context
                            .read<T>()
                            .add(CalendarEvent.viewChanged(view: view)),
                      ),
                      desktop: _CalendarDesktopLayout<T>(
                        state: state,
                        isLoading: state.isLoading,
                        tasks: tasks,
                        onRefresh: handleRefresh,
                        taskBuilder: (task, isCompact) =>
                            buildTaskTile(task, isCompact),
                        onTaskDragEnd: (task, newTime) {
                          final normalized =
                              task.normalizedForInteraction(newTime);
                          context.read<T>().commitTaskInteraction(normalized);
                        },
                        onDateSelected: (date) => context
                            .read<T>()
                            .add(CalendarEvent.dateSelected(date: date)),
                        onViewChanged: (view) => context
                            .read<T>()
                            .add(CalendarEvent.viewChanged(view: view)),
                        isGuestMode: widget.isGuestMode,
                        dateLabel: dateLabel,
                        onPrevious: () => _changeDate(-1),
                        onNext: () => _changeDate(1),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: _CalendarAddTaskFab<T>(
            onShowInput: (context, selectedDate) {
              showTaskInput(context, selectedDate);
            },
          ),
        );
      },
    );
  }

  void _changeDate(int direction) {
    context.read<T>().add(
          CalendarEvent.dateSelected(
            date: context
                .read<T>()
                .state
                .selectedDate
                .add(Duration(days: direction)),
          ),
        );
  }

  String _formatDate(DateTime date, CalendarView view) {
    switch (view) {
      case CalendarView.day:
        return '${date.day}/${date.month}/${date.year}';
      case CalendarView.week:
        return 'Week of ${date.day}/${date.month}';
      case CalendarView.month:
        return '${_getMonthName(date.month)} ${date.year}';
    }
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }

  List<CalendarTask> _getTasksForSelectedDate(CalendarState state) {
    final selectedDate = state.selectedDate;
    final tasks =
        state.model.tasks.values.whereType<CalendarTask>().where((task) {
      if (task.scheduledTime == null) return false;
      final taskDate = task.scheduledTime!;
      return taskDate.year == selectedDate.year &&
          taskDate.month == selectedDate.month &&
          taskDate.day == selectedDate.day;
    }).toList();

    tasks.sort((a, b) {
      if (a.scheduledTime == null && b.scheduledTime == null) return 0;
      if (a.scheduledTime == null) return 1;
      if (b.scheduledTime == null) return -1;
      return a.scheduledTime!.compareTo(b.scheduledTime!);
    });

    return tasks;
  }
}

class _CalendarGuestBanner extends StatelessWidget {
  const _CalendarGuestBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: calendarSelectedDayColor,
        border: Border(
          bottom: BorderSide(color: calendarBorderColor, width: 1),
        ),
      ),
      padding: calendarMarginMedium,
      child: const Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 20,
            color: calendarSubtitleColor,
          ),
          SizedBox(width: 8),
          Text(
            'Guest Mode - No Sync',
            style: calendarSubtitleTextStyle,
          ),
        ],
      ),
    );
  }
}

class _CalendarAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _CalendarAppBar({
    required this.isGuestMode,
    required this.title,
    required this.subtitle,
    required this.canPop,
    required this.selectedView,
    required this.onViewChanged,
    this.onBack,
    this.syncButton,
  });

  final bool isGuestMode;
  final String title;
  final String subtitle;
  final bool canPop;
  final VoidCallback? onBack;
  final CalendarView selectedView;
  final ValueChanged<CalendarView> onViewChanged;
  final Widget? syncButton;

  @override
  Size get preferredSize => const Size.fromHeight(80);

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(
          bottom: BorderSide(color: colors.border),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: calendarMarginLarge,
          child: Row(
            children: [
              if (canPop)
                AxiIconButton(
                  iconData: LucideIcons.arrowLeft,
                  tooltip: 'Back',
                  color: colors.foreground,
                  borderColor: colors.border,
                  onPressed: onBack,
                ),
              const SizedBox(width: calendarGutterSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isGuestMode ? 'Guest Calendar' : title,
                      style: context.textTheme.h3.copyWith(
                        color: colors.foreground,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: calendarSubtitleTextStyle.copyWith(
                        color: colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              _CalendarViewModeSelector(
                selectedView: selectedView,
                onChanged: onViewChanged,
              ),
              const SizedBox(width: calendarGutterSm),
              if (syncButton != null) syncButton!,
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarViewModeSelector extends StatelessWidget {
  const _CalendarViewModeSelector({
    required this.selectedView,
    required this.onChanged,
  });

  final CalendarView selectedView;
  final ValueChanged<CalendarView> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: calendarSelectedDayColor,
        borderRadius: BorderRadius.circular(calendarEventRadius),
        border: Border.all(color: calendarBorderColor),
      ),
      child: ShadSelect<CalendarView>(
        initialValue: selectedView,
        placeholder: const Text(
          'View',
          style: calendarCaptionTextStyle,
        ),
        options: CalendarView.values
            .map(
              (view) => ShadOption(
                value: view,
                child: Text(view.name.toUpperCase()),
              ),
            )
            .toList(),
        selectedOptionBuilder: (context, value) => Text(
          value.name.toUpperCase(),
          style: calendarCaptionTextStyle.copyWith(
            color: calendarTitleColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        onChanged: (view) {
          if (view != null) {
            onChanged(view);
          }
        },
      ),
    );
  }
}

class _CalendarSyncButton extends StatelessWidget {
  const _CalendarSyncButton({
    required this.state,
  });

  final CalendarState state;

  @override
  Widget build(BuildContext context) {
    return SyncControls(state: state);
  }
}

class _CalendarMobileLayout extends StatelessWidget {
  const _CalendarMobileLayout({
    required this.dateLabel,
    required this.onPrevious,
    required this.onNext,
    required this.isLoading,
    required this.tasks,
    required this.onRefresh,
    required this.taskBuilder,
  });

  final String dateLabel;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool isLoading;
  final List<CalendarTask> tasks;
  final Future<void> Function() onRefresh;
  final Widget Function(CalendarTask task, bool isCompact) taskBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CalendarDateHeader(
          label: dateLabel,
          onPrevious: onPrevious,
          onNext: onNext,
        ),
        Expanded(
          child: _CalendarTaskList(
            isLoading: isLoading,
            tasks: tasks,
            onRefresh: onRefresh,
            taskBuilder: taskBuilder,
          ),
        ),
      ],
    );
  }
}

class _CalendarTabletLayout<T extends BaseCalendarBloc>
    extends StatelessWidget {
  const _CalendarTabletLayout({
    required this.state,
    required this.isLoading,
    required this.tasks,
    required this.onRefresh,
    required this.taskBuilder,
    required this.onTaskDragEnd,
    required this.onDateSelected,
    required this.onViewChanged,
  });

  final CalendarState state;
  final bool isLoading;
  final List<CalendarTask> tasks;
  final Future<void> Function() onRefresh;
  final Widget Function(CalendarTask task, bool isCompact) taskBuilder;
  final void Function(CalendarTask task, DateTime newTime) onTaskDragEnd;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<CalendarView> onViewChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _CalendarGridSection<T>(
            state: state,
            onTaskDragEnd: onTaskDragEnd,
            onDateSelected: onDateSelected,
            onViewChanged: onViewChanged,
          ),
        ),
        const VerticalDivider(),
        Expanded(
          flex: 1,
          child: _CalendarTaskList(
            isLoading: isLoading,
            tasks: tasks,
            onRefresh: onRefresh,
            taskBuilder: taskBuilder,
          ),
        ),
      ],
    );
  }
}

class _CalendarDesktopLayout<T extends BaseCalendarBloc>
    extends StatelessWidget {
  const _CalendarDesktopLayout({
    required this.state,
    required this.isLoading,
    required this.tasks,
    required this.onRefresh,
    required this.taskBuilder,
    required this.onTaskDragEnd,
    required this.onDateSelected,
    required this.onViewChanged,
    required this.isGuestMode,
    required this.dateLabel,
    required this.onPrevious,
    required this.onNext,
  });

  final CalendarState state;
  final bool isLoading;
  final List<CalendarTask> tasks;
  final Future<void> Function() onRefresh;
  final Widget Function(CalendarTask task, bool isCompact) taskBuilder;
  final void Function(CalendarTask task, DateTime newTime) onTaskDragEnd;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<CalendarView> onViewChanged;
  final bool isGuestMode;
  final String dateLabel;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 320,
          child: _CalendarSidebar(
            state: state,
            isGuestMode: isGuestMode,
            dateLabel: dateLabel,
            onPrevious: onPrevious,
            onNext: onNext,
          ),
        ),
        const VerticalDivider(),
        Expanded(
          flex: 3,
          child: _CalendarGridSection<T>(
            state: state,
            onTaskDragEnd: onTaskDragEnd,
            onDateSelected: onDateSelected,
            onViewChanged: onViewChanged,
          ),
        ),
        const VerticalDivider(),
        Expanded(
          flex: 1,
          child: _CalendarTaskList(
            isLoading: isLoading,
            tasks: tasks,
            onRefresh: onRefresh,
            taskBuilder: taskBuilder,
          ),
        ),
      ],
    );
  }
}

class _CalendarDateHeader extends StatelessWidget {
  const _CalendarDateHeader({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Container(
      padding: calendarPaddingXl,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          AxiIconButton(
            iconData: Icons.chevron_left,
            tooltip: 'Previous date',
            onPressed: onPrevious,
            backgroundColor: colors.card,
            borderColor: colors.border,
          ),
          Text(
            label,
            style: calendarTitleTextStyle,
          ),
          AxiIconButton(
            iconData: Icons.chevron_right,
            tooltip: 'Next date',
            onPressed: onNext,
            backgroundColor: colors.card,
            borderColor: colors.border,
          ),
        ],
      ),
    );
  }
}

class _CalendarGridSection<T extends BaseCalendarBloc> extends StatelessWidget {
  const _CalendarGridSection({
    required this.state,
    required this.onTaskDragEnd,
    required this.onDateSelected,
    required this.onViewChanged,
    this.onEmptySlotTapped,
  });

  final CalendarState state;
  final void Function(CalendarTask task, DateTime newTime) onTaskDragEnd;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<CalendarView> onViewChanged;
  final void Function(DateTime time, Offset position)? onEmptySlotTapped;

  @override
  Widget build(BuildContext context) {
    return CalendarGrid<T>(
      state: state,
      onEmptySlotTapped: onEmptySlotTapped,
      onTaskDragEnd: onTaskDragEnd,
      onDateSelected: onDateSelected,
      onViewChanged: onViewChanged,
    );
  }
}

class _CalendarTaskList extends StatelessWidget {
  const _CalendarTaskList({
    required this.isLoading,
    required this.tasks,
    required this.onRefresh,
    required this.taskBuilder,
  });

  final bool isLoading;
  final List<CalendarTask> tasks;
  final Future<void> Function() onRefresh;
  final Widget Function(CalendarTask task, bool isCompact) taskBuilder;

  @override
  Widget build(BuildContext context) {
    if (isLoading && tasks.isEmpty) {
      return ListView.builder(
        itemCount: 3,
        itemBuilder: (context, index) => const TaskSkeletonTile(),
      );
    }

    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.task_alt,
              size: 64,
              color: calendarTimeLabelColor,
            ),
            const SizedBox(height: calendarGutterLg),
            Text(
              'No tasks for this date',
              style: calendarTitleTextStyle.copyWith(
                fontSize: 16,
                color: calendarSubtitleColor,
              ),
            ),
            const SizedBox(height: calendarGutterSm),
            const Text(
              'Tap + to create a new task',
              style: calendarSubtitleTextStyle,
            ),
          ],
        ),
      );
    }

    final isMobile = ResponsiveHelper.isCompact(context);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return taskBuilder(task, isMobile);
        },
      ),
    );
  }
}

class _CalendarSidebar extends StatelessWidget {
  const _CalendarSidebar({
    required this.state,
    required this.isGuestMode,
    required this.dateLabel,
    required this.onPrevious,
    required this.onNext,
  });

  final CalendarState state;
  final bool isGuestMode;
  final String dateLabel;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CalendarDateHeader(
          label: dateLabel,
          onPrevious: onPrevious,
          onNext: onNext,
        ),
        const Divider(),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: calendarPaddingXl,
                  child: Text('Quick Stats', style: calendarBodyTextStyle),
                ),
                ListTile(
                  leading: const Icon(Icons.today),
                  title: const Text('Due Reminders'),
                  trailing: Text('${state.dueReminders?.length ?? 0}'),
                ),
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('Next Task'),
                  subtitle: Text(state.nextTask?.title ?? 'None'),
                ),
                const Divider(),
                Padding(
                  padding: calendarPaddingXl,
                  child: isGuestMode
                      ? const _CalendarGuestModeInfo()
                      : SyncControls(state: state),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CalendarGuestModeInfo extends StatelessWidget {
  const _CalendarGuestModeInfo();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Guest Mode', style: calendarBodyTextStyle),
        const SizedBox(height: calendarGutterSm),
        Text(
          'Your tasks are saved locally on this device. Sign up to sync across devices.',
          style: calendarSubtitleTextStyle.copyWith(fontSize: 12),
        ),
      ],
    );
  }
}

class _CalendarAddTaskFab<T extends BaseCalendarBloc> extends StatelessWidget {
  const _CalendarAddTaskFab({required this.onShowInput});

  final void Function(BuildContext context, DateTime initialDate) onShowInput;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<T, CalendarState>(
      builder: (context, state) {
        final themeColors = context.colorScheme;
        final accent = calendarPrimaryColor;
        final onAccent = themeColors.primaryForeground;
        return ActionFeedback(
          onTap: () {
            onShowInput(context, state.selectedDate);
          },
          feedbackMessage: 'Opening task creator...',
          child: AnimatedContainer(
            duration: baseAnimationDuration,
            curve: Curves.easeInOut,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                boxShadow: calendarMediumShadow,
              ),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: state.isLoading
                      ? null
                      : () {
                          onShowInput(context, state.selectedDate);
                        },
                  borderRadius: BorderRadius.circular(28),
                  child: Center(
                    child: state.isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: onAccent,
                            ),
                          )
                        : Icon(
                            Icons.add,
                            color: onAccent,
                            size: 24,
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
