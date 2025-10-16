import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:axichat/src/common/ui/ui.dart';

import '../bloc/base_calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import '../models/calendar_task.dart';
import '../utils/responsive_helper.dart';
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
          WidgetsBinding.instance.addPostFrameCallback((_) {
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
          });
        }

        if (!widget.isGuestMode &&
            !state.isSyncing &&
            state.lastSyncTime != null &&
            state.error == null) {
          if (state.lastSyncTime!.difference(DateTime.now()).abs().inSeconds <
              5) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
                if (scaffoldMessenger != null) {
                  FeedbackSystem.showSuccess(
                      context, 'Calendar synced successfully!');
                }
              }
            });
          }
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: calendarBackgroundColor,
          appBar: _buildAppBar(context, state),
          body: Container(
            color: calendarBackgroundColor,
            child: Column(
              children: [
                if (widget.isGuestMode) _buildGuestBanner(),
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
                      mobile: _buildMobileLayout(state),
                      tablet: _buildTabletLayout(state),
                      desktop: _buildDesktopLayout(state),
                    ),
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: _buildAddTaskFab(context),
        );
      },
    );
  }

  Widget _buildGuestBanner() {
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

  PreferredSizeWidget _buildAppBar(BuildContext context, CalendarState state) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(80),
      child: Container(
        decoration: const BoxDecoration(
          color: calendarContainerColor,
          boxShadow: calendarMediumShadow,
        ),
        child: SafeArea(
          child: Padding(
            padding: calendarMarginLarge,
            child: Row(
              children: [
                if (Navigator.canPop(context))
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: calendarPaddingMd,
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          color: calendarTitleColor,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: calendarGutterSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.isGuestMode ? 'Guest Calendar' : 'Calendar',
                        style: calendarTitleTextStyle,
                      ),
                      Text(
                        _formatDate(state.selectedDate, state.viewMode),
                        style: calendarSubtitleTextStyle,
                      ),
                    ],
                  ),
                ),
                _buildViewModeSelector(context, state),
                const SizedBox(width: calendarGutterSm),
                if (!widget.isGuestMode) _buildSyncButton(context, state),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewModeSelector(BuildContext context, CalendarState state) {
    return Container(
      decoration: BoxDecoration(
        color: calendarSelectedDayColor,
        borderRadius: BorderRadius.circular(calendarEventRadius),
        border: Border.all(color: calendarBorderColor),
      ),
      child: ShadSelect<CalendarView>(
        placeholder: const Text(
          'View',
          style: calendarCaptionTextStyle,
        ),
        options: CalendarView.values
            .map((view) => ShadOption(
                  value: view,
                  child: Text(view.name.toUpperCase()),
                ))
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
            context.read<T>().add(CalendarEvent.viewChanged(view: view));
          }
        },
      ),
    );
  }

  Widget _buildSyncButton(BuildContext context, CalendarState state) {
    return SyncControls(
      state: state,
      compact: true,
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
        SizedBox(width: 320, child: _buildSidebar(state)),
        const VerticalDivider(),
        Expanded(flex: 3, child: _buildCalendarGrid(state)),
        const VerticalDivider(),
        Expanded(flex: 1, child: _buildTaskList(state)),
      ],
    );
  }

  Widget _buildDateHeader(CalendarState state) {
    return Container(
      padding: calendarPaddingXl,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => _changeDate(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            _formatDate(state.selectedDate, state.viewMode),
            style: calendarTitleTextStyle,
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
    return CalendarGrid<T>(
      state: state,
      onEmptySlotTapped: (time, position) {
        // TODO: Handle empty slot tap in base implementation
      },
      onTaskDragEnd: (task, newTime) {
        final bloc = context.read<T>();
        final CalendarTask normalized = task.normalizedForInteraction(newTime);
        bloc.commitTaskInteraction(normalized);
      },
      onDateSelected: (date) => context.read<T>().add(
            CalendarEvent.dateSelected(date: date),
          ),
      onViewChanged: (view) => context.read<T>().add(
            CalendarEvent.viewChanged(view: view),
          ),
    );
  }

  Widget _buildTaskList(CalendarState state) {
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
      onRefresh: () async {
        context.read<T>().add(const CalendarEvent.dataChanged());
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: ListView.builder(
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return buildTaskTile(task, isMobile);
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
                  child: widget.isGuestMode
                      ? _buildGuestModeInfo()
                      : SyncControls(state: state),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuestModeInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Guest Mode', style: calendarBodyTextStyle),
        const SizedBox(height: calendarGutterSm),
        Text(
          'Your tasks are saved locally on this device. Sign up to sync across devices.',
          style: calendarSubtitleTextStyle.copyWith(
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildAddTaskFab(BuildContext context) {
    return BlocBuilder<T, CalendarState>(
      builder: (context, state) {
        return ActionFeedback(
          onTap: () {
            showTaskInput(context, state.selectedDate);
          },
          feedbackMessage: 'Opening task creator...',
          child: AnimatedContainer(
            duration: baseAnimationDuration,
            curve: Curves.easeInOut,
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Colors.blue,
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
                          showTaskInput(context, state.selectedDate);
                        },
                  borderRadius: BorderRadius.circular(28),
                  child: Center(
                    child: state.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.add,
                            color: Colors.white,
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

  void _changeDate(int direction) {
    final bloc = context.read<T>();
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
