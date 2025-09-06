import 'dart:async';
import 'dart:developer' as developer;

import 'package:bloc/bloc.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../models/calendar_exceptions.dart';
import '../models/calendar_model.dart';
import '../models/calendar_task.dart';
import 'calendar_event.dart';
import 'calendar_state.dart';

class CalendarBloc extends Bloc<CalendarEvent, CalendarState> {
  CalendarBloc({
    required Box<CalendarModel> calendarBox,
    String? deviceId,
  })  : _calendarBox = calendarBox,
        _deviceId = deviceId ?? const Uuid().v4(),
        super(CalendarState.initial(deviceId ?? const Uuid().v4())) {
    on<CalendarStarted>(_onCalendarStarted);
    on<CalendarDataChanged>(_onCalendarDataChanged);
    on<CalendarTaskAdded>(_onCalendarTaskAdded);
    on<CalendarTaskUpdated>(_onCalendarTaskUpdated);
    on<CalendarTaskDeleted>(_onCalendarTaskDeleted);
    on<CalendarTaskCompleted>(_onCalendarTaskCompleted);
    on<CalendarViewChanged>(_onCalendarViewChanged);
    on<CalendarDateSelected>(_onCalendarDateSelected);
    on<CalendarErrorCleared>(_onCalendarErrorCleared);

    _boxSubscription = _calendarBox.watch().listen((_) {
      add(const CalendarEvent.dataChanged());
    });
  }

  final Box<CalendarModel> _calendarBox;
  final String _deviceId;
  late final StreamSubscription _boxSubscription;

  @override
  Future<void> close() async {
    await _boxSubscription.cancel();
    return super.close();
  }

  void _onCalendarStarted(CalendarStarted event, Emitter<CalendarState> emit) {
    final model =
        _calendarBox.get('calendar') ?? CalendarModel.empty(_deviceId);
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
    final model =
        _calendarBox.get('calendar') ?? CalendarModel.empty(_deviceId);
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
        deviceId: _deviceId,
      );

      final updatedModel = state.model.addTask(task);
      await _calendarBox.put('calendar', updatedModel);

      emit(state.copyWith(isLoading: false));
    } catch (e) {
      final error =
          e is CalendarException ? e.message : 'Failed to add task: $e';
      developer.log('Error adding task: $e', name: 'CalendarBloc');
      emit(state.copyWith(isLoading: false, error: error));
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

      emit(state.copyWith(isLoading: false));
    } catch (e) {
      final error =
          e is CalendarException ? e.message : 'Failed to update task: $e';
      developer.log('Error updating task: $e', name: 'CalendarBloc');
      emit(state.copyWith(isLoading: false, error: error));
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

      final updatedModel = state.model.deleteTask(event.taskId);
      await _calendarBox.put('calendar', updatedModel);

      emit(state.copyWith(isLoading: false));
    } catch (e) {
      final error =
          e is CalendarException ? e.message : 'Failed to delete task: $e';
      developer.log('Error deleting task: $e', name: 'CalendarBloc');
      emit(state.copyWith(isLoading: false, error: error));
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

      emit(state.copyWith(isLoading: false));
    } catch (e) {
      final error = e is CalendarException
          ? e.message
          : 'Failed to update task completion: $e';
      developer.log('Error completing task: $e', name: 'CalendarBloc');
      emit(state.copyWith(isLoading: false, error: error));
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
}
