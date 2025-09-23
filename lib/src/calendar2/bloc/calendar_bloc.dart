import 'dart:async';
import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart' show Storage;

import '../models/calendar_model.dart';
import '../models/calendar_task.dart';
import 'calendar_event.dart';
import 'calendar_state.dart';

class CalendarBloc extends Bloc<CalendarEvent, CalendarState> {
  CalendarBloc({required Storage storage})
      : _storage = storage,
        super(_restoreInitialState(storage)) {
    on<CalendarStarted>(_onStarted);
    on<CalendarErrorCleared>(_onErrorCleared);
    on<CalendarViewChanged>(_onViewChanged);
    on<CalendarDateSelected>(_onDateSelected);
    on<CalendarQuickTaskAdded>(_onQuickTaskAdded);
    on<CalendarTaskAdded>(_onTaskAdded);
    on<CalendarTaskUpdated>(_onTaskUpdated);
    on<CalendarTaskDeleted>(_onTaskDeleted);
    on<CalendarTaskCompleted>(_onTaskCompleted);
    on<CalendarTaskDropped>(_onTaskDropped);
    on<CalendarTaskResized>(_onTaskResized);
    on<CalendarTaskPriorityChanged>(_onTaskPriorityChanged);
    on<CalendarDayViewSelected>(_onDayViewSelected);

    _persist(state);
  }

  final Storage _storage;
  static const _storageKey = 'calendar_state';
  Future<void> _pendingWrite = Future.value();

  static CalendarState _restoreInitialState(Storage storage) {
    try {
      final cached = storage.read(_storageKey);
      if (cached is String) {
        final decoded = jsonDecode(cached) as Map<String, dynamic>;
        final modelJson = decoded['model'] as Map<String, dynamic>;
        final model = CalendarModel.fromJson(modelJson);
        return CalendarState(model: model);
      }
    } catch (_) {
      unawaited(storage.delete(_storageKey));
    }
    return CalendarState.initial();
  }

  void _persist(CalendarState state) {
    final payload = {
      'model':
          jsonDecode(jsonEncode(state.model.toJson())) as Map<String, dynamic>,
    };
    final jsonPayload = jsonEncode(payload);
    _pendingWrite =
        _pendingWrite.then((_) => _storage.write(_storageKey, jsonPayload));
  }

  @override
  void onChange(Change<CalendarState> change) {
    super.onChange(change);
    _persist(change.nextState);
  }

  @override
  Future<void> close() async {
    await _pendingWrite;
    await _storage.close();
    return super.close();
  }

  void _onStarted(CalendarStarted event, Emitter<CalendarState> emit) {
    emit(state.copyWith(model: state.model));
  }

  void _onErrorCleared(
    CalendarErrorCleared event,
    Emitter<CalendarState> emit,
  ) {
    emit(state.copyWith(error: null));
  }

  void _onViewChanged(
    CalendarViewChanged event,
    Emitter<CalendarState> emit,
  ) {
    final updatedModel = state.model.copyWith(
      view: event.view,
    );
    emit(state.copyWith(model: updatedModel));
  }

  void _onDateSelected(
    CalendarDateSelected event,
    Emitter<CalendarState> emit,
  ) {
    final updatedModel = state.model.copyWith(
      selectedDate: event.date,
    );
    emit(state.copyWith(model: updatedModel));
  }

  void _onQuickTaskAdded(
    CalendarQuickTaskAdded event,
    Emitter<CalendarState> emit,
  ) {
    final task = CalendarTask.create(
      title: event.text,
      description: event.description,
      deadline: event.deadline,
      important: event.important,
      urgent: event.urgent,
    );
    final updatedModel = state.model.addTask(task);
    emit(state.copyWith(model: updatedModel));
  }

  void _onTaskAdded(
    CalendarTaskAdded event,
    Emitter<CalendarState> emit,
  ) {
    final task = CalendarTask.create(
      title: event.title,
      description: event.description,
      scheduledStart: event.scheduledStart,
      duration: event.duration,
      endDate: event.endDate,
      deadline: event.deadline,
      isAllDay: event.isAllDay,
      important: event.important,
      urgent: event.urgent,
      tags: event.tags,
      location: event.location,
    );
    final updatedModel = state.model.addTask(task);
    emit(state.copyWith(model: updatedModel));
  }

  void _onTaskUpdated(
    CalendarTaskUpdated event,
    Emitter<CalendarState> emit,
  ) {
    final updatedModel = state.model.updateTask(event.task);
    emit(state.copyWith(model: updatedModel));
  }

  void _onTaskDeleted(
    CalendarTaskDeleted event,
    Emitter<CalendarState> emit,
  ) {
    final updatedModel = state.model.deleteTask(event.taskId);
    emit(state.copyWith(model: updatedModel));
  }

  void _onTaskCompleted(
    CalendarTaskCompleted event,
    Emitter<CalendarState> emit,
  ) {
    final task = state.model.tasks[event.taskId];
    if (task == null) {
      emit(state.copyWith(error: 'Task not found'));
      return;
    }
    final updatedTask = task.markCompleted(event.completed);
    final updatedModel = state.model.updateTask(updatedTask);
    emit(state.copyWith(model: updatedModel));
  }

  void _onTaskDropped(
    CalendarTaskDropped event,
    Emitter<CalendarState> emit,
  ) {
    final task = state.model.tasks[event.taskId];
    if (task == null) {
      emit(state.copyWith(error: 'Task not found'));
      return;
    }
    Duration? duration;
    DateTime? endDate;
    if (task.endDate != null && task.scheduledStart != null) {
      final delta = task.endDate!.difference(task.scheduledStart!);
      endDate = event.time.add(delta);
    } else if (task.duration != null) {
      duration = task.duration;
    } else {
      duration = const Duration(hours: 1);
    }
    final updatedTask = task.updatedCopy(
      scheduledStart: event.time,
      duration: duration,
      endDate: endDate,
      timestamp: DateTime.now(),
    );
    final updatedModel = state.model.updateTask(updatedTask);
    emit(state.copyWith(model: updatedModel));
  }

  void _onTaskResized(
    CalendarTaskResized event,
    Emitter<CalendarState> emit,
  ) {
    final task = state.model.tasks[event.taskId];
    if (task == null) {
      emit(state.copyWith(error: 'Task not found'));
      return;
    }

    final updatedTask = task.updatedCopy(
      scheduledStart: event.start,
      duration: event.duration,
      endDate: event.endDate,
      timestamp: DateTime.now(),
    );
    final updatedModel = state.model.updateTask(updatedTask);
    emit(state.copyWith(model: updatedModel));
  }

  void _onTaskPriorityChanged(
    CalendarTaskPriorityChanged event,
    Emitter<CalendarState> emit,
  ) {
    final task = state.model.tasks[event.taskId];
    if (task == null) {
      emit(state.copyWith(error: 'Task not found'));
      return;
    }

    final updatedTask = task.updatedCopy(
      important: event.important,
      urgent: event.urgent,
      timestamp: DateTime.now(),
    );
    final updatedModel = state.model.updateTask(updatedTask);
    emit(state.copyWith(model: updatedModel));
  }

  void _onDayViewSelected(
    CalendarDayViewSelected event,
    Emitter<CalendarState> emit,
  ) {
    final updatedModel = state.model.copyWith(
      selectedDate: state.weekStart.add(Duration(days: event.dayIndex)),
    );
    emit(state.copyWith(model: updatedModel));
  }
}
