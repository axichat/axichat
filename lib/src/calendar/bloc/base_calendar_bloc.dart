import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:uuid/uuid.dart';

import '../models/calendar_exceptions.dart';
import '../models/calendar_model.dart';
import '../models/calendar_task.dart';
import '../reminders/calendar_reminder_controller.dart';
import '../storage/calendar_storage_registry.dart';
import '../utils/recurrence_utils.dart';
import 'calendar_event.dart';
import 'calendar_state.dart';

abstract class BaseCalendarBloc
    extends HydratedBloc<CalendarEvent, CalendarState> {
  BaseCalendarBloc({
    required Storage storage,
    required String storagePrefix,
    String storageId = '',
    CalendarReminderController? reminderController,
    DateTime Function()? now,
  })  : _reminderController = reminderController,
        _now = now ?? DateTime.now,
        _storagePrefix = storagePrefix,
        _storageId = storageId,
        _storage = storage,
        super(CalendarState.initial()) {
    _assertStorageRegistered();
    on<CalendarStarted>(_onStarted);
    on<CalendarDataChanged>(_onDataChanged);
    on<CalendarTaskAdded>(_onTaskAdded);
    on<CalendarTaskUpdated>(_onTaskUpdated);
    on<CalendarTaskDeleted>(_onTaskDeleted);
    on<CalendarTaskCompleted>(_onTaskCompleted);
    on<CalendarTaskDropped>(_onTaskDropped);
    on<CalendarTaskResized>(_onTaskResized);
    on<CalendarTaskOccurrenceUpdated>(_onTaskOccurrenceUpdated);
    on<CalendarTaskPriorityChanged>(_onTaskPriorityChanged);
    on<CalendarTaskSplit>(_onTaskSplit);
    on<CalendarTaskRepeated>(_onTaskRepeated);
    on<CalendarQuickTaskAdded>(_onQuickTaskAdded);
    on<CalendarViewChanged>(_onViewChanged);
    on<CalendarDayViewSelected>(_onDayViewSelected);
    on<CalendarDateSelected>(_onDateSelected);
    on<CalendarErrorCleared>(_onErrorCleared);
    on<CalendarSelectionModeEntered>(_onSelectionModeEntered);
    on<CalendarSelectionToggled>(_onSelectionToggled);
    on<CalendarSelectionCleared>(_onSelectionCleared);
    on<CalendarSelectionPriorityChanged>(_onSelectionPriorityChanged);
    on<CalendarSelectionCompletedToggled>(_onSelectionCompletedToggled);
    on<CalendarSelectionDeleted>(_onSelectionDeleted);
    on<CalendarSelectionRecurrenceChanged>(_onSelectionRecurrenceChanged);
    on<CalendarUndoRequested>(_onUndoRequested);
    on<CalendarRedoRequested>(_onRedoRequested);
  }

  final CalendarReminderController? _reminderController;
  final DateTime Function() _now;
  final String _storagePrefix;
  final String _storageId;
  final Storage _storage;
  Future<void> _pendingReminderSync = Future.value();
  static const int _undoHistoryLimit = 50;
  final List<CalendarModel> _undoStack = <CalendarModel>[];
  final List<CalendarModel> _redoStack = <CalendarModel>[];

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

  void _assertStorageRegistered() {
    final hydratedStorage = HydratedBloc.storage;
    if (hydratedStorage is CalendarStorageRegistry) {
      final registered = hydratedStorage.storageForPrefix(storagePrefix);
      assert(
        registered != null,
        '$runtimeType requires storage for prefix "$storagePrefix" to be registered.',
      );
      assert(
        identical(registered, _storage),
        '$runtimeType received an unregistered storage instance for prefix "$storagePrefix".',
      );
    }
  }

  void _recordUndoSnapshot() {
    _undoStack.add(state.model);
    if (_undoStack.length > _undoHistoryLimit) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  void _emitSelectionState({
    required Emitter<CalendarState> emit,
    required bool isSelectionMode,
    required Set<String> selectedTaskIds,
  }) {
    final sanitizedSelection = <String>{};
    for (final id in selectedTaskIds) {
      if (state.model.tasks.containsKey(id)) {
        sanitizedSelection.add(id);
        continue;
      }
      final String baseId = baseTaskIdFrom(id);
      if (baseId != id && state.model.tasks.containsKey(baseId)) {
        sanitizedSelection.add(id);
      }
    }
    final nextMode = isSelectionMode && sanitizedSelection.isNotEmpty;
    emit(
      state.copyWith(
        isSelectionMode: nextMode,
        selectedTaskIds: nextMode ? sanitizedSelection : const <String>{},
        canUndo: _undoStack.isNotEmpty,
        canRedo: _redoStack.isNotEmpty,
      ),
    );
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

      _recordUndoSnapshot();

      final now = _now();
      final double? computedStartHour = event.startHour ??
          (event.scheduledTime != null
              ? event.scheduledTime!.hour + (event.scheduledTime!.minute / 60.0)
              : null);
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
        startHour: computedStartHour,
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

      _recordUndoSnapshot();

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
      final CalendarTask? directTaskEntry = state.model.tasks[event.taskId];
      if (directTaskEntry != null && event.taskId.contains('::')) {
        final CalendarTask task = directTaskEntry;
        emit(state.copyWith(isLoading: true, error: null));
        _recordUndoSnapshot();

        final updatedModel = state.model.deleteTask(event.taskId);
        final remainingSelection =
            state.selectedTaskIds.where((id) => id != event.taskId).toSet();
        final bool nextSelectionMode =
            state.isSelectionMode && remainingSelection.isNotEmpty;

        emitModel(
          updatedModel,
          emit,
          isLoading: false,
          isSelectionMode: nextSelectionMode,
          selectedTaskIds: remainingSelection,
        );

        await onTaskDeleted(task);
        return;
      }

      final occurrenceKey = occurrenceKeyFrom(event.taskId);
      final targetTaskId =
          occurrenceKey == null ? event.taskId : baseTaskIdFrom(event.taskId);
      final taskToDelete = state.model.tasks[targetTaskId];
      if (taskToDelete == null) {
        throw CalendarTaskNotFoundException(event.taskId);
      }

      if (occurrenceKey != null && !taskToDelete.effectiveRecurrence.isNone) {
        emit(state.copyWith(isLoading: true, error: null));
        _recordUndoSnapshot();

        final overrides = Map<String, TaskOccurrenceOverride>.from(
            taskToDelete.occurrenceOverrides);
        final existing = overrides[occurrenceKey];
        overrides[occurrenceKey] = TaskOccurrenceOverride(
          scheduledTime: existing?.scheduledTime,
          duration: existing?.duration,
          endDate: existing?.endDate,
          daySpan: existing?.daySpan,
          isCancelled: true,
          priority: existing?.priority,
          isCompleted: existing?.isCompleted,
        );

        final updatedTask = taskToDelete.copyWith(
          occurrenceOverrides: overrides,
          modifiedAt: _now(),
        );
        final updatedModel = state.model.updateTask(updatedTask);
        emitModel(updatedModel, emit, isLoading: false);

        await onTaskUpdated(updatedTask);
        return;
      }

      emit(state.copyWith(isLoading: true, error: null));

      _recordUndoSnapshot();

      final CalendarModel updatedModel = state.model.deleteTask(targetTaskId);
      final remainingSelection =
          state.selectedTaskIds.where((id) => id != targetTaskId).toSet();
      final bool nextSelectionMode =
          state.isSelectionMode && remainingSelection.isNotEmpty;

      emitModel(
        updatedModel,
        emit,
        isLoading: false,
        isSelectionMode: nextSelectionMode,
        selectedTaskIds: remainingSelection,
      );

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

      _recordUndoSnapshot();

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
      _recordUndoSnapshot();
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
        throw const CalendarValidationException(
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
      _recordUndoSnapshot();
      final updatedModel = state.model.updateTask(updatedTask);
      emitModel(updatedModel, emit);

      await onTaskUpdated(updatedTask);
    } catch (error) {
      logError('Failed to resize task', error);
      emit(state.copyWith(error: error.toString()));
    }
  }

  Future<void> _onTaskOccurrenceUpdated(
    CalendarTaskOccurrenceUpdated event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      final task = state.model.tasks[event.taskId];
      if (task == null) {
        throw CalendarTaskNotFoundException(event.taskId);
      }

      final occurrenceKey = occurrenceKeyFrom(event.occurrenceId);
      if (occurrenceKey == null || occurrenceKey.isEmpty) {
        throw const CalendarValidationException(
          'occurrenceId',
          'Invalid occurrence identifier',
        );
      }

      final overrides =
          Map<String, TaskOccurrenceOverride>.from(task.occurrenceOverrides);
      final existing = overrides[occurrenceKey];

      final updatedOverride = TaskOccurrenceOverride(
        scheduledTime: event.scheduledTime ?? existing?.scheduledTime,
        duration: event.duration ?? existing?.duration,
        endDate: event.endDate ?? existing?.endDate,
        daySpan: event.daySpan ?? existing?.daySpan,
        isCancelled: event.isCancelled ?? existing?.isCancelled,
      );

      if (_isOccurrenceOverrideEmpty(updatedOverride)) {
        overrides.remove(occurrenceKey);
      } else {
        overrides[occurrenceKey] = updatedOverride;
      }

      final updatedTask = task.copyWith(
        occurrenceOverrides: overrides,
        modifiedAt: _now(),
      );
      _recordUndoSnapshot();
      final updatedModel = state.model.updateTask(updatedTask);
      emitModel(updatedModel, emit);

      await onTaskUpdated(updatedTask);
    } catch (error) {
      logError('Failed to update occurrence', error);
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
      _recordUndoSnapshot();
      final updatedModel = state.model.updateTask(updatedTask);
      emitModel(updatedModel, emit);

      await onTaskUpdated(updatedTask);
    } catch (error) {
      logError('Failed to change priority', error);
      emit(state.copyWith(error: error.toString()));
    }
  }

  Future<void> _onTaskSplit(
    CalendarTaskSplit event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      final CalendarTask target = event.target;
      final CalendarTask? baseTask = state.model.tasks[target.baseId];
      if (baseTask == null) {
        throw CalendarTaskNotFoundException(target.baseId);
      }

      final DateTime? start = target.scheduledTime;
      DateTime? end = target.effectiveEndDate;
      final Duration? duration = target.duration;
      if (end == null && duration != null && duration.inMinutes > 0) {
        end = start?.add(duration);
      }

      if (start == null || end == null || !end.isAfter(start)) {
        return;
      }

      final DateTime splitTime = event.splitTime;
      if (!splitTime.isAfter(start) || !splitTime.isBefore(end)) {
        return;
      }

      final int leftMinutes = splitTime.difference(start).inMinutes;
      final int rightMinutes = end.difference(splitTime).inMinutes;
      if (leftMinutes <= 0 || rightMinutes <= 0) {
        return;
      }

      final Duration leftDuration = Duration(minutes: leftMinutes);
      final Duration rightDuration = Duration(minutes: rightMinutes);
      final now = _now();

      _recordUndoSnapshot();

      CalendarModel model = state.model;
      final updates = <String, CalendarTask>{};
      CalendarTask? createdTask;

      if (!baseTask.effectiveRecurrence.isNone && target.id.contains('::')) {
        final String? occurrenceKey = occurrenceKeyFrom(target.id);
        if (occurrenceKey != null && occurrenceKey.isNotEmpty) {
          final overrides = Map<String, TaskOccurrenceOverride>.from(
            baseTask.occurrenceOverrides,
          );
          final TaskOccurrenceOverride? existing = overrides[occurrenceKey];
          overrides[occurrenceKey] = TaskOccurrenceOverride(
            scheduledTime: start,
            duration: leftDuration,
            endDate: start.add(leftDuration),
            daySpan: existing?.daySpan,
            isCancelled: existing?.isCancelled,
            priority: existing?.priority,
            isCompleted: existing?.isCompleted,
          );

          final CalendarTask updatedBase = baseTask.copyWith(
            occurrenceOverrides: overrides,
            modifiedAt: now,
          );
          updates[baseTask.id] = updatedBase;

          createdTask = baseTask.copyWith(
            id: const Uuid().v4(),
            scheduledTime: splitTime,
            duration: rightDuration,
            startHour: splitTime.hour + (splitTime.minute / 60.0),
            recurrence: null,
            occurrenceOverrides: const {},
            daySpan: null,
            endDate: null,
            createdAt: now,
            modifiedAt: now,
          );

          model = model.replaceTasks(updates);
          model = model.addTask(createdTask);

          emitModel(
            model,
            emit,
            selectedTaskIds: state.selectedTaskIds,
          );

          await onTaskUpdated(updatedBase);
          await onTaskAdded(createdTask);
          return;
        }
      }

      final DateTime originalStart = baseTask.scheduledTime ?? start;
      final CalendarTask updatedBaseTask = baseTask.copyWith(
        scheduledTime: originalStart,
        duration: leftDuration,
        daySpan: null,
        endDate: null,
        startHour: originalStart.hour + (originalStart.minute / 60.0),
        modifiedAt: now,
      );
      updates[baseTask.id] = updatedBaseTask;

      createdTask = baseTask.copyWith(
        id: const Uuid().v4(),
        scheduledTime: splitTime,
        duration: rightDuration,
        daySpan: null,
        endDate: null,
        recurrence: null,
        occurrenceOverrides: const {},
        startHour: splitTime.hour + (splitTime.minute / 60.0),
        createdAt: now,
        modifiedAt: now,
      );

      model = model.replaceTasks(updates);
      model = model.addTask(createdTask);

      emitModel(
        model,
        emit,
        selectedTaskIds: state.selectedTaskIds,
      );

      await onTaskUpdated(updatedBaseTask);
      await onTaskAdded(createdTask);
    } catch (error) {
      logError('Failed to split task', error);
      emit(state.copyWith(error: error.toString()));
    }
  }

  Future<void> _onTaskRepeated(
    CalendarTaskRepeated event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      final CalendarTask template = event.template;
      final String baseId = template.baseId;
      final CalendarTask? baseTask = state.model.tasks[baseId];
      final CalendarTask source = baseTask ?? template;

      final now = _now();
      final String newId = '$baseId::${const Uuid().v4()}';
      final Duration? duration =
          template.duration ?? baseTask?.duration ?? source.duration;

      final CalendarTask newTask = source.copyWith(
        id: newId,
        scheduledTime: event.scheduledTime,
        startHour:
            event.scheduledTime.hour + (event.scheduledTime.minute / 60.0),
        duration: duration,
        occurrenceOverrides: const {},
        createdAt: now,
        modifiedAt: now,
      );

      _recordUndoSnapshot();

      final updatedModel = state.model.addTask(newTask);
      final selectedIds = state.selectedTaskIds.contains(template.id)
          ? <String>{...state.selectedTaskIds, newTask.id}
          : state.selectedTaskIds;

      emitModel(
        updatedModel,
        emit,
        isSelectionMode: state.isSelectionMode,
        selectedTaskIds: selectedIds,
      );

      await onTaskAdded(newTask);
    } catch (error) {
      logError('Failed to repeat task', error);
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

      _recordUndoSnapshot();

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

  void _onSelectionModeEntered(
    CalendarSelectionModeEntered event,
    Emitter<CalendarState> emit,
  ) {
    final updatedSelection = <String>{...state.selectedTaskIds};
    if (event.taskId != null) {
      updatedSelection.add(event.taskId!);
    }
    _emitSelectionState(
      emit: emit,
      isSelectionMode: true,
      selectedTaskIds: updatedSelection,
    );
  }

  void _onSelectionToggled(
    CalendarSelectionToggled event,
    Emitter<CalendarState> emit,
  ) {
    final toggledId = event.taskId;
    final currentSelection = <String>{...state.selectedTaskIds};
    final wasSelected = currentSelection.remove(toggledId);

    if (!state.isSelectionMode && !wasSelected) {
      currentSelection
        ..clear()
        ..add(toggledId);
      _emitSelectionState(
        emit: emit,
        isSelectionMode: true,
        selectedTaskIds: currentSelection,
      );
      return;
    }

    if (!wasSelected) {
      currentSelection.add(toggledId);
    }

    final nextMode = currentSelection.isNotEmpty;
    _emitSelectionState(
      emit: emit,
      isSelectionMode: nextMode,
      selectedTaskIds: nextMode ? currentSelection : <String>{},
    );
  }

  void _onSelectionCleared(
    CalendarSelectionCleared event,
    Emitter<CalendarState> emit,
  ) {
    _emitSelectionState(
      emit: emit,
      isSelectionMode: false,
      selectedTaskIds: const <String>{},
    );
  }

  Future<void> _onSelectionPriorityChanged(
    CalendarSelectionPriorityChanged event,
    Emitter<CalendarState> emit,
  ) async {
    if (state.selectedTaskIds.isEmpty) {
      return;
    }

    final updates = <String, CalendarTask>{};
    final baseOverrideUpdates = <String, Map<String, TaskOccurrenceOverride>>{};
    final now = _now();
    final TaskPriority? targetPriority =
        event.priority == TaskPriority.none ? null : event.priority;

    for (final id in state.selectedTaskIds) {
      final task = state.model.tasks[id];
      if (task != null) {
        updates[id] = task.copyWith(
          priority: targetPriority,
          modifiedAt: now,
        );
        continue;
      }

      final baseId = baseTaskIdFrom(id);
      final CalendarTask? baseTask = state.model.tasks[baseId];
      final String? occurrenceKey = occurrenceKeyFrom(id);
      if (baseTask == null || occurrenceKey == null) {
        continue;
      }

      final TaskPriority? basePriority = baseTask.priority;
      final TaskPriority? overridePriority =
          targetPriority == basePriority ? null : targetPriority;
      final overrides = baseOverrideUpdates.putIfAbsent(
        baseId,
        () => Map<String, TaskOccurrenceOverride>.from(
          baseTask.occurrenceOverrides,
        ),
      );
      final TaskOccurrenceOverride existing =
          overrides[occurrenceKey] ?? const TaskOccurrenceOverride();
      final TaskOccurrenceOverride updatedOverride =
          existing.copyWith(priority: overridePriority);

      if (_isOccurrenceOverrideEmpty(updatedOverride)) {
        overrides.remove(occurrenceKey);
      } else {
        overrides[occurrenceKey] = updatedOverride;
      }
    }

    if (updates.isEmpty && baseOverrideUpdates.isEmpty) {
      return;
    }

    _recordUndoSnapshot();

    final mergedUpdates = <String, CalendarTask>{...updates};
    for (final entry in baseOverrideUpdates.entries) {
      final String baseId = entry.key;
      final CalendarTask? baseSource =
          mergedUpdates[baseId] ?? state.model.tasks[baseId];
      if (baseSource == null) {
        continue;
      }
      final CalendarTask updatedBase = baseSource.copyWith(
        occurrenceOverrides: entry.value,
        modifiedAt: now,
      );
      mergedUpdates[baseId] = updatedBase;
    }

    final updatedModel = state.model.replaceTasks(mergedUpdates);
    emitModel(
      updatedModel,
      emit,
      isSelectionMode: state.isSelectionMode,
      selectedTaskIds: state.selectedTaskIds,
    );

    for (final task in mergedUpdates.values) {
      await onTaskUpdated(task);
    }
  }

  Future<void> _onSelectionCompletedToggled(
    CalendarSelectionCompletedToggled event,
    Emitter<CalendarState> emit,
  ) async {
    if (state.selectedTaskIds.isEmpty) {
      return;
    }

    final updates = <String, CalendarTask>{};
    final baseOverrideUpdates = <String, Map<String, TaskOccurrenceOverride>>{};
    final now = _now();

    for (final id in state.selectedTaskIds) {
      final task = state.model.tasks[id];
      if (task != null) {
        updates[id] = task.copyWith(
          isCompleted: event.completed,
          modifiedAt: now,
        );
        continue;
      }

      final baseId = baseTaskIdFrom(id);
      final CalendarTask? baseTask = state.model.tasks[baseId];
      final String? occurrenceKey = occurrenceKeyFrom(id);
      if (baseTask == null || occurrenceKey == null) {
        continue;
      }

      final bool baseCompleted = baseTask.isCompleted;
      final bool? overrideCompleted =
          event.completed == baseCompleted ? null : event.completed;
      final overrides = baseOverrideUpdates.putIfAbsent(
        baseId,
        () => Map<String, TaskOccurrenceOverride>.from(
          baseTask.occurrenceOverrides,
        ),
      );
      final TaskOccurrenceOverride existing =
          overrides[occurrenceKey] ?? const TaskOccurrenceOverride();
      final TaskOccurrenceOverride updatedOverride =
          existing.copyWith(isCompleted: overrideCompleted);

      if (_isOccurrenceOverrideEmpty(updatedOverride)) {
        overrides.remove(occurrenceKey);
      } else {
        overrides[occurrenceKey] = updatedOverride;
      }
    }

    if (updates.isEmpty && baseOverrideUpdates.isEmpty) {
      return;
    }

    _recordUndoSnapshot();

    final mergedUpdates = <String, CalendarTask>{...updates};
    for (final entry in baseOverrideUpdates.entries) {
      final String baseId = entry.key;
      final CalendarTask? baseSource =
          mergedUpdates[baseId] ?? state.model.tasks[baseId];
      if (baseSource == null) {
        continue;
      }
      final CalendarTask updatedBase = baseSource.copyWith(
        occurrenceOverrides: entry.value,
        modifiedAt: now,
      );
      mergedUpdates[baseId] = updatedBase;
    }

    final updatedModel = state.model.replaceTasks(mergedUpdates);
    emitModel(
      updatedModel,
      emit,
      isSelectionMode: state.isSelectionMode,
      selectedTaskIds: state.selectedTaskIds,
    );

    for (final task in mergedUpdates.values) {
      await onTaskUpdated(task);
    }
  }

  Future<void> _onSelectionDeleted(
    CalendarSelectionDeleted event,
    Emitter<CalendarState> emit,
  ) async {
    if (state.selectedTaskIds.isEmpty) {
      return;
    }

    final baseIds = <String>{};
    final occurrencesByBase = <String, Set<String>>{};

    for (final id in state.selectedTaskIds) {
      if (state.model.tasks.containsKey(id)) {
        baseIds.add(id);
        continue;
      }
      final String baseId = baseTaskIdFrom(id);
      if (baseId == id) {
        continue;
      }
      final CalendarTask? baseTask = state.model.tasks[baseId];
      if (baseTask == null || baseTask.effectiveRecurrence.isNone) {
        continue;
      }
      occurrencesByBase.putIfAbsent(baseId, () => <String>{}).add(id);
    }

    final baseTasksToDelete = baseIds
        .map((id) => state.model.tasks[id])
        .whereType<CalendarTask>()
        .toList();

    final updatedBases = <String, CalendarTask>{};
    for (final entry in occurrencesByBase.entries) {
      final CalendarTask? baseTask = state.model.tasks[entry.key];
      if (baseTask == null) {
        continue;
      }
      final overrides = Map<String, TaskOccurrenceOverride>.from(
        baseTask.occurrenceOverrides,
      );
      var modified = false;
      for (final occurrenceId in entry.value) {
        final occurrenceKey = occurrenceKeyFrom(occurrenceId);
        if (occurrenceKey == null) {
          continue;
        }
        final existing = overrides[occurrenceKey];
        overrides[occurrenceKey] = TaskOccurrenceOverride(
          scheduledTime: existing?.scheduledTime,
          duration: existing?.duration,
          endDate: existing?.endDate,
          daySpan: existing?.daySpan,
          isCancelled: true,
          priority: existing?.priority,
          isCompleted: existing?.isCompleted,
        );
        modified = true;
      }
      if (!modified) {
        continue;
      }
      updatedBases[entry.key] = baseTask.copyWith(
        occurrenceOverrides: overrides,
        modifiedAt: _now(),
      );
    }

    _recordUndoSnapshot();

    CalendarModel model = state.model;

    if (updatedBases.isNotEmpty) {
      model = model.replaceTasks(updatedBases);
    }

    if (baseIds.isNotEmpty) {
      model = model.removeTasks(baseIds);
    }

    emitModel(
      model,
      emit,
      isSelectionMode: false,
      selectedTaskIds: const <String>{},
    );

    for (final task in updatedBases.values) {
      await onTaskUpdated(task);
    }

    for (final task in baseTasksToDelete) {
      await onTaskDeleted(task);
    }
  }

  Future<void> _onSelectionRecurrenceChanged(
    CalendarSelectionRecurrenceChanged event,
    Emitter<CalendarState> emit,
  ) async {
    if (state.selectedTaskIds.isEmpty) {
      return;
    }

    final updates = <String, CalendarTask>{};
    final now = _now();

    for (final id in state.selectedTaskIds) {
      final task = state.model.tasks[id];
      if (task == null) continue;

      final recurrence = event.recurrence;
      updates[id] = task.copyWith(
        recurrence: recurrence == null || recurrence.isNone ? null : recurrence,
        occurrenceOverrides: const {},
        modifiedAt: now,
      );
    }

    if (updates.isEmpty) {
      return;
    }

    _recordUndoSnapshot();

    final updatedModel = state.model.replaceTasks(updates);
    emitModel(
      updatedModel,
      emit,
      isSelectionMode: state.isSelectionMode,
      selectedTaskIds: state.selectedTaskIds,
    );

    for (final task in updates.values) {
      await onTaskUpdated(task);
    }
  }

  void _onUndoRequested(
    CalendarUndoRequested event,
    Emitter<CalendarState> emit,
  ) {
    if (_undoStack.isEmpty) {
      return;
    }

    final previousModel = _undoStack.removeLast();
    _redoStack.add(state.model);

    emitModel(
      previousModel,
      emit,
      selectedDate: state.selectedDate,
      isSelectionMode: false,
      selectedTaskIds: const <String>{},
    );
  }

  void _onRedoRequested(
    CalendarRedoRequested event,
    Emitter<CalendarState> emit,
  ) {
    if (_redoStack.isEmpty) {
      return;
    }

    final nextModel = _redoStack.removeLast();
    _undoStack.add(state.model);

    emitModel(
      nextModel,
      emit,
      selectedDate: state.selectedDate,
      isSelectionMode: false,
      selectedTaskIds: const <String>{},
    );
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
    bool? isSelectionMode,
    Set<String>? selectedTaskIds,
  }) {
    final nextState = state.copyWith(
      model: model,
      dueReminders: _getDueReminders(model),
      nextTask: _getNextTask(model),
      selectedDate: selectedDate ?? state.selectedDate,
      isLoading: isLoading ?? state.isLoading,
      lastSyncTime: lastSyncTime ?? state.lastSyncTime,
      isSelectionMode: isSelectionMode ?? state.isSelectionMode,
      selectedTaskIds: selectedTaskIds ?? state.selectedTaskIds,
      canUndo: _undoStack.isNotEmpty,
      canRedo: _redoStack.isNotEmpty,
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

bool _isOccurrenceOverrideEmpty(TaskOccurrenceOverride override) {
  final isCancelled = override.isCancelled ?? false;
  return !isCancelled &&
      override.scheduledTime == null &&
      override.duration == null &&
      override.endDate == null &&
      override.daySpan == null &&
      override.priority == null &&
      override.isCompleted == null;
}
