import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../app.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import '../utils/responsive_helper.dart';
import '../view/calendar_grid.dart';
import '../view/error_display.dart';
import '../view/feedback_system.dart';
import '../view/loading_indicator.dart';
import '../view/task_input.dart';
import '../view/task_tile.dart';
import 'guest_calendar_bloc.dart';

class GuestCalendarWidget extends StatefulWidget {
  const GuestCalendarWidget({super.key});

  @override
  State<GuestCalendarWidget> createState() => _GuestCalendarWidgetState();
}

class _GuestCalendarWidgetState extends State<GuestCalendarWidget> {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GuestCalendarBloc, CalendarState>(
      listener: (context, state) {
        if (state.error != null) {
          ErrorSnackBar.show(
            context,
            state.error!,
            onRetry: () {
              context
                  .read<GuestCalendarBloc>()
                  .add(const CalendarEvent.errorCleared());
            },
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: _buildAppBar(context, state),
          body: Column(
            children: [
              Container(
                color: context.colorScheme.muted.withValues(alpha: 0.3),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 20, color: context.colorScheme.mutedForeground),
                    const SizedBox(width: 8),
                    Text(
                      'Guest Mode - No Sync',
                      style: context.textTheme.small.copyWith(
                        color: context.colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              if (state.error != null)
                ErrorDisplay(
                  error: state.error!,
                  onRetry: () {
                    context
                        .read<GuestCalendarBloc>()
                        .add(const CalendarEvent.errorCleared());
                  },
                  onDismiss: () {
                    context
                        .read<GuestCalendarBloc>()
                        .add(const CalendarEvent.errorCleared());
                  },
                ),
              Expanded(
                child: ResponsiveHelper.layoutBuilder(
                  context,
                  mobile: _buildMobileLayout(state),
                  tablet: _buildTabletLayout(state),
                  desktop: _buildDesktopLayout(state),
                ),
              ),
            ],
          ),
          floatingActionButton: _buildAddTaskFab(context),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, CalendarState state) {
    return AppBar(
      title: Row(
        children: [
          const Text('Guest Calendar'),
          const SizedBox(width: 8),
          Tooltip(
            message:
                'Calendar data is stored locally only and won\'t sync across devices',
            child: Icon(Icons.info_outline,
                size: 20, color: context.colorScheme.mutedForeground),
          ),
        ],
      ),
      actions: [
        _buildViewModeSelector(context, state),
      ],
    );
  }

  Widget _buildViewModeSelector(BuildContext context, CalendarState state) {
    return ShadSelect<CalendarView>(
      placeholder: const Text('View'),
      options: CalendarView.values
          .map((view) => ShadOption(
                value: view,
                child: Text(view.name.toUpperCase()),
              ))
          .toList(),
      selectedOptionBuilder: (context, value) => Text(value.name.toUpperCase()),
      onChanged: (view) {
        if (view != null) {
          context
              .read<GuestCalendarBloc>()
              .add(CalendarEvent.viewChanged(view: view));
        }
      },
    );
  }

  Widget _buildMobileLayout(CalendarState state) {
    return Column(
      children: [
        _buildDateHeader(state),
        Expanded(child: _buildTaskList(state)),
      ],
    );
  }

  Widget _buildTabletLayout(CalendarState state) {
    return Row(
      children: [
        Expanded(flex: 2, child: _buildCalendarGrid(state)),
        const VerticalDivider(),
        Expanded(flex: 1, child: _buildTaskList(state)),
      ],
    );
  }

  Widget _buildDesktopLayout(CalendarState state) {
    return Row(
      children: [
        SizedBox(width: 250, child: _buildSidebar(state)),
        const VerticalDivider(),
        Expanded(flex: 3, child: _buildCalendarGrid(state)),
        const VerticalDivider(),
        Expanded(flex: 1, child: _buildTaskList(state)),
      ],
    );
  }

  Widget _buildDateHeader(CalendarState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => _changeDate(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            _formatDate(state.selectedDate, state.viewMode),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          IconButton(
            onPressed: () => _changeDate(1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(CalendarState state) {
    return CalendarGrid(state: state);
  }

  Widget _buildTaskList(CalendarState state) {
    // Show skeleton loader while loading
    if (state.isLoading && state.model.tasks.isEmpty) {
      return ListView.builder(
        itemCount: 3,
        itemBuilder: (context, index) => const TaskSkeletonTile(),
      );
    }

    final tasks = _getTasksForSelectedDate(state);
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.task_alt,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No tasks for this date',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to create a new task',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      );
    }

    final isMobile = ResponsiveHelper.isMobile(context);
    return RefreshIndicator(
      onRefresh: () async {
        // Trigger data refresh
        context
            .read<GuestCalendarBloc>()
            .add(const CalendarEvent.dataChanged());
        // Wait a moment for the refresh to feel natural
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: ListView.builder(
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return TaskTile(
            task: task,
            compact: isMobile,
          );
        },
      ),
    );
  }

  Widget _buildSidebar(CalendarState state) {
    return Column(
      children: [
        _buildDateHeader(state),
        const Divider(),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Quick Stats',
                      style: TextStyle(fontWeight: FontWeight.bold)),
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
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Guest Mode',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        'Your tasks are saved locally on this device. Sign up to sync across devices.',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddTaskFab(BuildContext context) {
    return BlocBuilder<GuestCalendarBloc, CalendarState>(
      builder: (context, state) {
        return ActionFeedback(
          onTap: () {
            showTaskInput(context, initialDate: state.selectedDate);
          },
          feedbackMessage: 'Opening task creator...',
          child: FloatingActionButton(
            onPressed: state.isLoading
                ? null
                : () {
                    showTaskInput(context, initialDate: state.selectedDate);
                  },
            child: state.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.add),
          ),
        );
      },
    );
  }

  void _changeDate(int direction) {
    final bloc = context.read<GuestCalendarBloc>();
    final currentDate = bloc.state.selectedDate;
    final newDate = currentDate.add(Duration(days: direction));
    bloc.add(CalendarEvent.dateSelected(date: newDate));
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

  List<dynamic> _getTasksForSelectedDate(CalendarState state) {
    final selectedDate = state.selectedDate;
    final tasks = state.model.tasks.values.where((task) {
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
