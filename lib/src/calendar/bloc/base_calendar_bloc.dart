import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

import '../models/calendar_exceptions.dart';
import '../models/calendar_model.dart';
import '../models/calendar_task.dart';
import '../reminders/calendar_reminder_controller.dart';
import 'calendar_event.dart';
import 'calendar_state.dart';

abstract class BaseCalendarBloc
    extends HydratedBloc<CalendarEvent, CalendarState> {
  BaseCalendarBloc({
    required String storagePrefix,
    String storageId = '',
    CalendarReminderController? reminderController,
    DateTime Function()? now,
  })  : _reminderController = reminderController,
        _now = now ?? DateTime.now,
        _storagePrefix = storagePrefix,
        _storageId = storageId,
        super(CalendarState.initial()) {
    on<CalendarStarted>(_onStarted);
    on<CalendarDataChanged>(_onDataChanged);
    on<CalendarTaskAdded>(_onTaskAdded);
    on<CalendarTaskUpdated>(_onTaskUpdated);
    on<CalendarTaskDeleted>(_onTaskDeleted);
    on<CalendarTaskCompleted>(_onTaskCompleted);
    on<CalendarTaskDropped>(_onTaskDropped);
    on<CalendarTaskResized>(_onTaskResized);
    on<CalendarTaskPriorityChanged>(_onTaskPriorityChanged);
    on<CalendarQuickTaskAdded>(_onQuickTaskAdded);
    on<CalendarViewChanged>(_onViewChanged);
    on<CalendarDayViewSelected>(_onDayViewSelected);
    on<CalendarDateSelected>(_onDateSelected);
    on<CalendarErrorCleared>(_onErrorCleared);
  }

  final CalendarReminderController? _reminderController;
  final DateTime Function() _now;
  final String _storagePrefix;
  final String _storageId;
  Future<void> _pendingReminderSync = Future.value();

  @override
  String get id => _storageId;

  @override
  String get storagePrefix => _storagePrefix;

  @override
  CalendarState? fromJson(Map<String, dynamic> json) {
    try {
      final modelJson = json['model'] as Map<String, dynamic>?;
      final selectedDate = json['selectedDate'] as String?;
      final view = json['viewMode'] as String?;
      final selectedDayIndex = json['selectedDayIndex'] as int?;

      if (modelJson == null || selectedDate == null || view == null) {
        return null;
      }

      final model = CalendarModel.fromJson(modelJson);
      final parsedDate = DateTime.parse(selectedDate);
      final viewMode = CalendarView.values.firstWhere(
        (element) => element.name == view,
        orElse: () => CalendarView.week,
      );

      final restored = CalendarState(
        model: model,
        selectedDate: parsedDate,
        viewMode: viewMode,
        selectedDayIndex: selectedDayIndex,
      );

      return _stateWithDerived(restored);
    } catch (error) {
      logError('Failed to restore calendar state', error);
      return null;
    }
  }

  @override
  Map<String, dynamic>? toJson(CalendarState state) {
    try {
      return {
        'model': state.model.toJson(),
        'selectedDate': state.selectedDate.toIso8601String(),
        'viewMode': state.viewMode.name,
        if (state.selectedDayIndex != null)
          'selectedDayIndex': state.selectedDayIndex,
      };
    } catch (error) {
      logError('Failed to persist calendar state', error);
      return null;
    }
  }

  void _onStarted(CalendarStarted event, Emitter<CalendarState> emit) {
    emitModel(state.model, emit, selectedDate: state.selectedDate);
  }

  void _onDataChanged(
    CalendarDataChanged event,
    Emitter<CalendarState> emit,
  ) {
    // When hydration restores or an explicit refresh is requested, recompute
    // reminder snapshots without mutating the model.
    emitModel(state.model, emit, selectedDate: state.selectedDate);
  }

  Future<void> _onTaskAdded(
    CalendarTaskAdded event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      if (event.title.trim().isEmpty) {
        throw const CalendarValidationException(
          'title',
          'Title cannot be empty',
        );
      }
      if (event.title.length > 200) {
        throw const CalendarValidationException(
          'title',
          'Title too long (max 200 characters)',
        );
      }
      if (event.description != null && event.description!.length > 1000) {
        throw const CalendarValidationException(
          'description',
          'Description too long (max 1000 characters)',
        );
      }

      emit(state.copyWith(isLoading: true, error: null));

      final now = _now();
      final task = CalendarTask.create(
        title: event.title,
        description: event.description,
        scheduledTime: event.scheduledTime,
        duration: event.duration,
        location: event.location,
        deadline: event.deadline,
        daySpan: event.daySpan,
        endDate: event.endDate,
        priority: event.priority,
        startHour: event.startHour,
        recurrence: event.recurrence,
      ).copyWith(modifiedAt: now);

      final updatedModel = state.model.addTask(task);
      emitModel(updatedModel, emit, isLoading: false);

      await onTaskAdded(task);
    } catch (error) {
      await _handleError(error, 'Failed to add task', emit);
    }
  }

  Future<void> _onTaskUpdated(
    CalendarTaskUpdated event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      final existingTask = state.model.tasks[event.task.id];
      if (existingTask == null) {
        throw CalendarTaskNotFoundException(event.task.id);
      }
      if (event.task.title.trim().isEmpty) {
        throw const CalendarValidationException(
          'title',
          'Title cannot be empty',
        );
      }

      emit(state.copyWith(isLoading: true, error: null));

      final updatedTask = event.task.copyWith(modifiedAt: _now());
      final updatedModel = state.model.updateTask(updatedTask);
      emitModel(updatedModel, emit, isLoading: false);

      await onTaskUpdated(updatedTask);
    } catch (error) {
      await _handleError(error, 'Failed to update task', emit);
    }
  }

  Future<void> _onTaskDeleted(
    CalendarTaskDeleted event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      final taskToDelete = state.model.tasks[event.taskId];
      if (taskToDelete == null) {
        throw CalendarTaskNotFoundException(event.taskId);
      }

      emit(state.copyWith(isLoading: true, error: null));

      final updatedModel = state.model.deleteTask(event.taskId);
      emitModel(updatedModel, emit, isLoading: false);

      await onTaskDeleted(taskToDelete);
    } catch (error) {
      await _handleError(error, 'Failed to delete task', emit);
    }
  }

  Future<void> _onTaskCompleted(
    CalendarTaskCompleted event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      final existingTask = state.model.tasks[event.taskId];
      if (existingTask == null) {
        throw CalendarTaskNotFoundException(event.taskId);
      }

      emit(state.copyWith(isLoading: true, error: null));

      final updatedTask = existingTask.copyWith(
        isCompleted: event.completed,
        modifiedAt: _now(),
      );
      final updatedModel = state.model.updateTask(updatedTask);
      emitModel(updatedModel, emit, isLoading: false);

      await onTaskCompleted(updatedTask);
    } catch (error) {
      await _handleError(error, 'Failed to update task completion', emit);
    }
  }

  Future<void> _onTaskDropped(
    CalendarTaskDropped event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      final task = state.model.tasks[event.taskId];
      if (task == null) {
        throw CalendarTaskNotFoundException(event.taskId);
      }

      final updatedTask = task.copyWith(
        scheduledTime: event.time,
        modifiedAt: _now(),
      );
      final updatedModel = state.model.updateTask(updatedTask);
      emitModel(updatedModel, emit);

      await onTaskUpdated(updatedTask);
    } catch (error) {
      logError('Failed to drop task', error);
      emit(state.copyWith(error: error.toString()));
    }
  }

  Future<void> _onTaskResized(
    CalendarTaskResized event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      final task = state.model.tasks[event.taskId];
      if (task == null) {
        throw CalendarTaskNotFoundException(event.taskId);
      }
      final scheduled = task.scheduledTime;
      if (scheduled == null) {
        throw CalendarValidationException(
          'scheduledTime',
          'Task requires a scheduled time before resizing',
        );
      }

      final minutesFromStart = (event.startHour * 60).round();
      final newStart = DateTime(
        scheduled.year,
        scheduled.month,
        scheduled.day,
      ).add(Duration(minutes: minutesFromStart));

      final updatedTask = task.copyWith(
        scheduledTime: newStart,
        duration: Duration(minutes: (event.duration * 60).round()),
        daySpan: event.daySpan ?? task.daySpan,
        modifiedAt: _now(),
      );
      final updatedModel = state.model.updateTask(updatedTask);
      emitModel(updatedModel, emit);

      await onTaskUpdated(updatedTask);
    } catch (error) {
      logError('Failed to resize task', error);
      emit(state.copyWith(error: error.toString()));
    }
  }

  Future<void> _onTaskPriorityChanged(
    CalendarTaskPriorityChanged event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      final task = state.model.tasks[event.taskId];
      if (task == null) {
        throw CalendarTaskNotFoundException(event.taskId);
      }

      final updatedTask = task.copyWith(
        priority: event.priority == TaskPriority.none ? null : event.priority,
        modifiedAt: _now(),
      );
      final updatedModel = state.model.updateTask(updatedTask);
      emitModel(updatedModel, emit);

      await onTaskUpdated(updatedTask);
    } catch (error) {
      logError('Failed to change priority', error);
      emit(state.copyWith(error: error.toString()));
    }
  }

  Future<void> _onQuickTaskAdded(
    CalendarQuickTaskAdded event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      if (event.text.trim().isEmpty) {
        throw const CalendarValidationException(
          'text',
          'Task text cannot be empty',
        );
      }

      emit(state.copyWith(isLoading: true, error: null));

      final parsed = CalendarTask.fromNaturalLanguage(event.text);
      final now = _now();
      final task = parsed.copyWith(
        description: event.description ?? parsed.description,
        deadline: event.deadline ?? parsed.deadline,
        priority: event.priority == TaskPriority.none
            ? parsed.priority
            : event.priority,
        modifiedAt: now,
      );

      final updatedModel = state.model.addTask(task);
      emitModel(updatedModel, emit, isLoading: false);

      await onTaskAdded(task);
    } catch (error) {
      await _handleError(error, 'Failed to add quick task', emit);
    }
  }

  void _onViewChanged(
    CalendarViewChanged event,
    Emitter<CalendarState> emit,
  ) {
    emit(state.copyWith(viewMode: event.view));
  }

  void _onDayViewSelected(
    CalendarDayViewSelected event,
    Emitter<CalendarState> emit,
  ) {
    final dayDate = state.weekStart.add(Duration(days: event.dayIndex));
    emit(state.copyWith(
      viewMode: CalendarView.day,
      selectedDate: dayDate,
      selectedDayIndex: event.dayIndex,
    ));
  }

  void _onDateSelected(
    CalendarDateSelected event,
    Emitter<CalendarState> emit,
  ) {
    emit(state.copyWith(selectedDate: event.date));
  }

  void _onErrorCleared(
    CalendarErrorCleared event,
    Emitter<CalendarState> emit,
  ) {
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

  CalendarState _stateWithDerived(CalendarState state) {
    final dueReminders = _getDueReminders(state.model);
    final nextTask = _getNextTask(state.model);
    return state.copyWith(
      dueReminders: dueReminders,
      nextTask: nextTask,
    );
  }

  @protected
  void emitModel(
    CalendarModel model,
    Emitter<CalendarState> emit, {
    DateTime? selectedDate,
    bool? isLoading,
    DateTime? lastSyncTime,
  }) {
    final nextState = state.copyWith(
      model: model,
      dueReminders: _getDueReminders(model),
      nextTask: _getNextTask(model),
      selectedDate: selectedDate ?? state.selectedDate,
      isLoading: isLoading ?? state.isLoading,
      lastSyncTime: lastSyncTime ?? state.lastSyncTime,
    );
    emit(nextState);
    _pendingReminderSync = _pendingReminderSync.then(
      (_) => _reminderController?.syncWithTasks(model.tasks.values),
    );
  }

  List<CalendarTask> _getDueReminders(CalendarModel model) {
    final now = _now();
    final dueSoonCutoff = now.add(const Duration(hours: 2));

    return model.tasks.values.where((task) {
      if (task.isCompleted || task.scheduledTime == null) {
        return false;
      }
      final scheduled = task.scheduledTime!;
      return scheduled.isBefore(now) || scheduled.isBefore(dueSoonCutoff);
    }).toList()
      ..sort((a, b) => a.scheduledTime!.compareTo(b.scheduledTime!));
  }

  CalendarTask? _getNextTask(CalendarModel model) {
    final now = _now();
    final upcomingTasks = model.tasks.values
        .where((task) =>
            !task.isCompleted &&
            task.scheduledTime != null &&
            task.scheduledTime!.isAfter(now))
        .toList()
      ..sort((a, b) => a.scheduledTime!.compareTo(b.scheduledTime!));
    return upcomingTasks.isEmpty ? null : upcomingTasks.first;
  }

  @override
  Future<void> close() async {
    await _pendingReminderSync;
    return super.close();
  }

  // Abstract methods for subclasses to implement
  Future<void> onTaskAdded(CalendarTask task);
  Future<void> onTaskUpdated(CalendarTask task);
  Future<void> onTaskDeleted(CalendarTask task);
  Future<void> onTaskCompleted(CalendarTask task);
  void logError(String message, Object error);
}
