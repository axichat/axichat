import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:hive/hive.dart';

import '../models/calendar_exceptions.dart';
import '../models/calendar_model.dart';
import '../models/calendar_task.dart';
import 'calendar_event.dart';
import 'calendar_state.dart';

abstract class BaseCalendarBloc extends Bloc<CalendarEvent, CalendarState> {
  BaseCalendarBloc({
    required Box<CalendarModel> calendarBox,
  })  : _calendarBox = calendarBox,
        super(CalendarState.initial()) {
    on<CalendarStarted>(_onCalendarStarted);
    on<CalendarDataChanged>(_onCalendarDataChanged);
    on<CalendarTaskAdded>(_onCalendarTaskAdded);
    on<CalendarTaskUpdated>(_onCalendarTaskUpdated);
    on<CalendarTaskDeleted>(_onCalendarTaskDeleted);
    on<CalendarTaskCompleted>(_onCalendarTaskCompleted);
    on<CalendarTaskDropped>(_onCalendarTaskDropped);
    on<CalendarQuickTaskAdded>(_onCalendarQuickTaskAdded);
    on<CalendarViewChanged>(_onCalendarViewChanged);
    on<CalendarDateSelected>(_onCalendarDateSelected);
    on<CalendarErrorCleared>(_onCalendarErrorCleared);

    _boxSubscription = _calendarBox.watch().listen((_) {
      add(const CalendarEvent.dataChanged());
    });
  }

  final Box<CalendarModel> _calendarBox;
  late final StreamSubscription _boxSubscription;

  @override
  Future<void> close() async {
    await _boxSubscription.cancel();
    return super.close();
  }

  void _onCalendarStarted(CalendarStarted event, Emitter<CalendarState> emit) {
    final model = _calendarBox.get('calendar') ?? CalendarModel.empty();
    final dueReminders = _getDueReminders(model);
    final nextTask = _getNextTask(model);

    emit(state.copyWith(
      model: model,
      dueReminders: dueReminders,
      nextTask: nextTask,
    ));
  }

  void _onCalendarDataChanged(
      CalendarDataChanged event, Emitter<CalendarState> emit) {
    final model = _calendarBox.get('calendar') ?? CalendarModel.empty();
    final dueReminders = _getDueReminders(model);
    final nextTask = _getNextTask(model);

    emit(state.copyWith(
      model: model,
      dueReminders: dueReminders,
      nextTask: nextTask,
    ));
  }

  Future<void> _onCalendarTaskAdded(
      CalendarTaskAdded event, Emitter<CalendarState> emit) async {
    try {
      // Validate input
      if (event.title.trim().isEmpty) {
        throw const CalendarValidationException(
            'title', 'Title cannot be empty');
      }
      if (event.title.length > 200) {
        throw const CalendarValidationException(
            'title', 'Title too long (max 200 characters)');
      }
      if (event.description != null && event.description!.length > 1000) {
        throw const CalendarValidationException(
            'description', 'Description too long (max 1000 characters)');
      }

      emit(state.copyWith(isLoading: true, error: null));

      final task = CalendarTask.create(
        title: event.title,
        description: event.description,
        scheduledTime: event.scheduledTime,
        duration: event.duration,
      );

      final updatedModel = state.model.addTask(task);
      await _calendarBox.put('calendar', updatedModel);

      // Allow subclasses to handle sync logic
      await onTaskAdded(task);

      emit(state.copyWith(isLoading: false));
    } catch (e) {
      await _handleError(e, 'Failed to add task', emit);
    }
  }

  Future<void> _onCalendarTaskUpdated(
      CalendarTaskUpdated event, Emitter<CalendarState> emit) async {
    try {
      // Validate task exists
      if (!state.model.tasks.containsKey(event.task.id)) {
        throw CalendarTaskNotFoundException(event.task.id);
      }

      // Validate input
      if (event.task.title.trim().isEmpty) {
        throw const CalendarValidationException(
            'title', 'Title cannot be empty');
      }
      if (event.task.title.length > 200) {
        throw const CalendarValidationException(
            'title', 'Title too long (max 200 characters)');
      }

      emit(state.copyWith(isLoading: true, error: null));

      final updatedModel = state.model.updateTask(event.task);
      await _calendarBox.put('calendar', updatedModel);

      // Allow subclasses to handle sync logic
      await onTaskUpdated(event.task);

      emit(state.copyWith(isLoading: false));
    } catch (e) {
      await _handleError(e, 'Failed to update task', emit);
    }
  }

  Future<void> _onCalendarTaskDeleted(
      CalendarTaskDeleted event, Emitter<CalendarState> emit) async {
    try {
      // Validate task exists
      if (!state.model.tasks.containsKey(event.taskId)) {
        throw CalendarTaskNotFoundException(event.taskId);
      }

      emit(state.copyWith(isLoading: true, error: null));

      // Get the task before deleting for sync
      final taskToDelete = state.model.tasks[event.taskId]!;

      final updatedModel = state.model.deleteTask(event.taskId);
      await _calendarBox.put('calendar', updatedModel);

      // Allow subclasses to handle sync logic
      await onTaskDeleted(taskToDelete);

      emit(state.copyWith(isLoading: false));
    } catch (e) {
      await _handleError(e, 'Failed to delete task', emit);
    }
  }

  Future<void> _onCalendarTaskDropped(
      CalendarTaskDropped event, Emitter<CalendarState> emit) async {
    try {
      // Find the task
      final task = state.model.tasks[event.taskId];
      if (task == null) {
        throw CalendarTaskNotFoundException(event.taskId);
      }

      // Update the scheduled time
      final updatedTask = task.copyWith(scheduledTime: event.time);

      // Update in storage
      final updatedModel = state.model.copyWith(
        tasks: Map.from(state.model.tasks)..[event.taskId] = updatedTask,
      );
      await _calendarBox.put('calendar', updatedModel);

      // Call hook for subclasses
      await onTaskUpdated(updatedTask);
    } catch (e) {
      logError('Failed to drop task', e);
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onCalendarTaskCompleted(
      CalendarTaskCompleted event, Emitter<CalendarState> emit) async {
    try {
      final existingTask = state.model.tasks[event.taskId];
      if (existingTask == null) {
        throw CalendarTaskNotFoundException(event.taskId);
      }

      emit(state.copyWith(isLoading: true, error: null));

      final updatedTask = existingTask.copyWith(isCompleted: event.completed);
      final updatedModel = state.model.updateTask(updatedTask);
      await _calendarBox.put('calendar', updatedModel);

      // Allow subclasses to handle sync logic
      await onTaskCompleted(updatedTask);

      emit(state.copyWith(isLoading: false));
    } catch (e) {
      await _handleError(e, 'Failed to update task completion', emit);
    }
  }

  Future<void> _onCalendarQuickTaskAdded(
      CalendarQuickTaskAdded event, Emitter<CalendarState> emit) async {
    try {
      // Validate input
      if (event.text.trim().isEmpty) {
        throw const CalendarValidationException(
            'text', 'Task text cannot be empty');
      }

      emit(state.copyWith(isLoading: true, error: null));

      // Parse the natural language input
      final task = CalendarTask.fromNaturalLanguage(event.text);

      // Override with any explicit values passed in the event
      final finalTask = task.copyWith(
        description: event.description ?? task.description,
        deadline: event.deadline ?? task.deadline,
        priority: event.priority != TaskPriority.none
            ? event.priority
            : task.priority,
      );

      final updatedModel = state.model.addTask(finalTask);
      await _calendarBox.put('calendar', updatedModel);

      // Allow subclasses to handle sync logic
      await onTaskAdded(finalTask);

      emit(state.copyWith(isLoading: false));
    } catch (e) {
      await _handleError(e, 'Failed to add quick task', emit);
    }
  }

  void _onCalendarViewChanged(
      CalendarViewChanged event, Emitter<CalendarState> emit) {
    emit(state.copyWith(viewMode: event.view));
  }

  void _onCalendarDateSelected(
      CalendarDateSelected event, Emitter<CalendarState> emit) {
    emit(state.copyWith(selectedDate: event.date));
  }

  void _onCalendarErrorCleared(
      CalendarErrorCleared event, Emitter<CalendarState> emit) {
    emit(state.copyWith(error: null, syncError: null));
  }

  Future<void> _handleError(
    Object error,
    String defaultMessage,
    Emitter<CalendarState> emit,
  ) async {
    final errorMessage =
        error is CalendarException ? error.message : '$defaultMessage: $error';
    logError(errorMessage, error);
    emit(state.copyWith(isLoading: false, error: errorMessage));
  }

  List<CalendarTask> _getDueReminders(CalendarModel model) {
    final now = DateTime.now();
    final dueSoonCutoff = now.add(const Duration(hours: 2));

    return model.tasks.values
        .where((task) =>
            !task.isCompleted &&
            task.scheduledTime != null &&
            (task.scheduledTime!.isBefore(now) || // Overdue
                task.scheduledTime!.isBefore(dueSoonCutoff))) // Due soon
        .toList()
      ..sort((a, b) => a.scheduledTime!.compareTo(b.scheduledTime!));
  }

  CalendarTask? _getNextTask(CalendarModel model) {
    final now = DateTime.now();
    final upcomingTasks = model.tasks.values
        .where((task) =>
            !task.isCompleted &&
            task.scheduledTime != null &&
            task.scheduledTime!.isAfter(now))
        .toList()
      ..sort((a, b) => a.scheduledTime!.compareTo(b.scheduledTime!));

    return upcomingTasks.isEmpty ? null : upcomingTasks.first;
  }

  // Abstract methods for subclasses to implement
  Future<void> onTaskAdded(CalendarTask task);
  Future<void> onTaskUpdated(CalendarTask task);
  Future<void> onTaskDeleted(CalendarTask task);
  Future<void> onTaskCompleted(CalendarTask task);
  void logError(String message, Object error);
}
