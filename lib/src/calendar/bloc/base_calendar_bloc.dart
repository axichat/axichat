import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:uuid/uuid.dart';

import 'package:axichat/src/calendar/constants.dart';
import 'package:axichat/src/calendar/models/calendar_exceptions.dart';
import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:axichat/src/calendar/reminders/calendar_reminder_controller.dart';
import 'package:axichat/src/calendar/storage/calendar_storage_registry.dart';
import 'package:axichat/src/calendar/storage/calendar_state_storage_codec.dart';
import 'package:axichat/src/calendar/utils/nl_parser_service.dart';
import 'package:axichat/src/calendar/utils/nl_schedule_adapter.dart';
import 'package:axichat/src/calendar/utils/recurrence_utils.dart';
import 'calendar_event.dart';
import 'calendar_state.dart';

class _CalendarUndoSnapshot {
  const _CalendarUndoSnapshot({
    required this.model,
    required this.isSelectionMode,
    required this.selectedTaskIds,
    required this.focusedCriticalPathId,
  });

  final CalendarModel model;
  final bool isSelectionMode;
  final Set<String> selectedTaskIds;
  final String? focusedCriticalPathId;
}

abstract class BaseCalendarBloc
    extends HydratedBloc<CalendarEvent, CalendarState> {
  BaseCalendarBloc({
    required Storage storage,
    required String storagePrefix,
    String storageId = '',
    CalendarReminderController? reminderController,
    DateTime Function()? now,
    NlScheduleParserService? parserService,
  })  : _reminderController = reminderController,
        _now = now ?? DateTime.now,
        _storagePrefix = storagePrefix,
        _storageId = storageId,
        _storage = storage,
        _nlParserService = parserService ?? NlScheduleParserService(),
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
    on<CalendarDayEventAdded>(_onDayEventAdded);
    on<CalendarDayEventUpdated>(_onDayEventUpdated);
    on<CalendarDayEventDeleted>(_onDayEventDeleted);
    on<CalendarQuickTaskAdded>(_onQuickTaskAdded);
    on<CalendarViewChanged>(_onViewChanged);
    on<CalendarDayViewSelected>(_onDayViewSelected);
    on<CalendarDateSelected>(_onDateSelected);
    on<CalendarErrorCleared>(_onErrorCleared);
    on<CalendarSelectionModeEntered>(_onSelectionModeEntered);
    on<CalendarSelectionAllRequested>(_onSelectionAllRequested);
    on<CalendarSelectionToggled>(_onSelectionToggled);
    on<CalendarSelectionCleared>(_onSelectionCleared);
    on<CalendarSelectionPriorityChanged>(_onSelectionPriorityChanged);
    on<CalendarSelectionCompletedToggled>(_onSelectionCompletedToggled);
    on<CalendarSelectionDeleted>(_onSelectionDeleted);
    on<CalendarSelectionRecurrenceChanged>(_onSelectionRecurrenceChanged);
    on<CalendarSelectionTitleChanged>(_onSelectionTitleChanged);
    on<CalendarSelectionDescriptionChanged>(_onSelectionDescriptionChanged);
    on<CalendarSelectionLocationChanged>(_onSelectionLocationChanged);
    on<CalendarSelectionChecklistChanged>(_onSelectionChecklistChanged);
    on<CalendarSelectionTimeShifted>(_onSelectionTimeShifted);
    on<CalendarSelectionRemindersChanged>(_onSelectionRemindersChanged);
    on<CalendarSelectionIdsAdded>(_onSelectionIdsAdded);
    on<CalendarSelectionIdsRemoved>(_onSelectionIdsRemoved);
    on<CalendarUndoRequested>(_onUndoRequested);
    on<CalendarRedoRequested>(_onRedoRequested);
    on<CalendarTaskFocusRequested>(_onTaskFocusRequested);
    on<CalendarTaskFocusCleared>(_onTaskFocusCleared);
    on<CalendarTasksImported>(_onTasksImported);
    on<CalendarModelImported>(_onModelImported);
    on<CalendarSyncWarningRaised>(_onSyncWarningRaised);
    on<CalendarSyncWarningCleared>(_onSyncWarningCleared);
    on<CalendarCriticalPathCreated>(_onCriticalPathCreated);
    on<CalendarCriticalPathRenamed>(_onCriticalPathRenamed);
    on<CalendarCriticalPathDeleted>(_onCriticalPathDeleted);
    on<CalendarCriticalPathTaskAdded>(_onCriticalPathTaskAdded);
    on<CalendarCriticalPathTaskRemoved>(_onCriticalPathTaskRemoved);
    on<CalendarCriticalPathFocused>(_onCriticalPathFocused);
    on<CalendarCriticalPathReordered>(_onCriticalPathReordered);
  }

  final CalendarReminderController? _reminderController;
  final DateTime Function() _now;
  final String _storagePrefix;
  final String _storageId;
  final Storage _storage;
  final NlScheduleParserService _nlParserService;
  Future<void> _pendingReminderSync = Future.value();
  static const int _undoHistoryLimit = 50;
  final List<_CalendarUndoSnapshot> _undoStack = <_CalendarUndoSnapshot>[];
  final List<_CalendarUndoSnapshot> _redoStack = <_CalendarUndoSnapshot>[];
  int _focusSequence = 0;

  @override
  String get id => _storageId;

  @override
  String get storagePrefix => _storagePrefix;

  @override
  CalendarState? fromJson(Map<String, dynamic> json) {
    try {
      final restored = CalendarStateStorageCodec.decode(json);
      if (restored == null) {
        return null;
      }
      return _stateWithDerived(restored);
    } catch (error) {
      logError('Failed to restore calendar state', error);
      return null;
    }
  }

  @override
  Map<String, dynamic>? toJson(CalendarState state) {
    try {
      return CalendarStateStorageCodec.encode(state);
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

  void commitTaskInteraction(CalendarTask snapshot) {
    final DateTime? scheduled = snapshot.scheduledTime;
    if (scheduled == null) {
      logError(
        'commitTaskInteraction requires a scheduledTime',
        ArgumentError.notNull('scheduledTime'),
      );
      return;
    }

    final CalendarTask normalized =
        snapshot.withScheduled(scheduledTime: scheduled);
    final CalendarTask? directTask = state.model.tasks[normalized.id];
    if (directTask != null) {
      if (directTask.scheduledTime == null) {
        add(
          CalendarEvent.taskDropped(
            taskId: directTask.id,
            time: scheduled,
          ),
        );
        return;
      }

      final Duration? previousDuration = directTask.effectiveDuration;
      final Duration? nextDuration = normalized.effectiveDuration;
      final bool startChanged =
          !(directTask.scheduledTime?.isAtSameMomentAs(scheduled) ?? false);
      final bool durationChanged = previousDuration != null &&
          nextDuration != null &&
          previousDuration.inMinutes != nextDuration.inMinutes;
      final bool endChanged =
          directTask.effectiveEndDate != normalized.effectiveEndDate;

      if (durationChanged || endChanged) {
        add(
          CalendarEvent.taskResized(
            taskId: directTask.id,
            scheduledTime: scheduled,
            duration: normalized.duration,
            endDate: normalized.effectiveEndDate,
          ),
        );
      } else if (startChanged) {
        add(
          CalendarEvent.taskDropped(
            taskId: directTask.id,
            time: scheduled,
          ),
        );
      }
      return;
    }

    final String baseId = normalized.baseId;
    final CalendarTask? baseTask = state.model.tasks[baseId];

    if (normalized.isOccurrence && baseTask != null) {
      add(
        CalendarEvent.taskOccurrenceUpdated(
          taskId: baseId,
          occurrenceId: normalized.id,
          scheduledTime: scheduled,
          duration: normalized.duration,
          endDate: normalized.effectiveEndDate,
        ),
      );
      return;
    }

    if (baseTask != null) {
      final Duration? previousDuration = baseTask.effectiveDuration;
      final Duration? nextDuration = normalized.effectiveDuration;
      final bool startChanged =
          !(baseTask.scheduledTime?.isAtSameMomentAs(scheduled) ?? false);
      final bool durationChanged = previousDuration != null &&
          nextDuration != null &&
          previousDuration.inMinutes != nextDuration.inMinutes;
      final bool endChanged =
          baseTask.effectiveEndDate != normalized.effectiveEndDate;

      if (durationChanged || endChanged || startChanged) {
        add(
          CalendarEvent.taskResized(
            taskId: baseId,
            scheduledTime: scheduled,
            duration: normalized.duration,
            endDate: normalized.effectiveEndDate,
          ),
        );
      }
      return;
    }

    add(
      CalendarEvent.taskDropped(
        taskId: normalized.id,
        time: scheduled,
      ),
    );
  }

  void _recordUndoSnapshot() {
    _undoStack.add(
      _CalendarUndoSnapshot(
        model: state.model,
        isSelectionMode: state.isSelectionMode,
        selectedTaskIds: Set<String>.from(state.selectedTaskIds),
        focusedCriticalPathId: state.focusedCriticalPathId,
      ),
    );
    if (_undoStack.length > _undoHistoryLimit) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  void _restoreLastUndoSnapshot(
    Emitter<CalendarState> emit, {
    bool clearRedo = true,
  }) {
    if (_undoStack.isEmpty) {
      return;
    }
    final _CalendarUndoSnapshot snapshot = _undoStack.removeLast();
    if (clearRedo) {
      _redoStack.clear();
    }
    emitModel(
      snapshot.model,
      emit,
      selectedDate: state.selectedDate,
      isSelectionMode: snapshot.isSelectionMode,
      selectedTaskIds: snapshot.selectedTaskIds,
      focusedCriticalPathId: snapshot.focusedCriticalPathId,
      focusedCriticalPathSpecified: true,
      isLoading: false,
    );
  }

  void _emitSelectionState({
    required Emitter<CalendarState> emit,
    required bool isSelectionMode,
    required Set<String> selectedTaskIds,
  }) {
    final Set<String> sanitizedSelection = _filterSelectionForFocus(
      focusedPathId: state.focusedCriticalPathId,
      model: state.model,
      selection: selectedTaskIds,
    );
    final bool nextMode = isSelectionMode && sanitizedSelection.isNotEmpty;
    emit(
      state.copyWith(
        isSelectionMode: nextMode,
        selectedTaskIds: nextMode ? sanitizedSelection : const <String>{},
        canUndo: _undoStack.isNotEmpty,
        canRedo: _redoStack.isNotEmpty,
      ),
    );
  }

  Future<void> _onStarted(
    CalendarStarted event,
    Emitter<CalendarState> emit,
  ) async {
    emitModel(state.model, emit, selectedDate: state.selectedDate);
  }

  Future<void> _onDataChanged(
    CalendarDataChanged event,
    Emitter<CalendarState> emit,
  ) async {
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
      if (event.title.length > calendarTaskTitleMaxLength) {
        throw const CalendarValidationException(
          'title',
          'Title too long (max $calendarTaskTitleMaxLength characters)',
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
      final DateTime? computedEndDate = event.endDate ??
          (event.scheduledTime != null && event.duration != null
              ? event.scheduledTime!.add(event.duration!)
              : null);

      final List<TaskChecklistItem> checklist =
          _normalizedChecklist(event.checklist);

      final task = CalendarTask.create(
        title: event.title,
        description: event.description,
        scheduledTime: event.scheduledTime,
        duration: event.duration,
        location: event.location,
        deadline: event.deadline,
        endDate: computedEndDate,
        priority: event.priority,
        recurrence: event.recurrence,
        checklist: checklist,
        reminders: event.reminders,
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

      final List<TaskChecklistItem> checklist =
          _normalizedChecklist(event.task.checklist);

      final updatedTask = event.task.copyWith(
        modifiedAt: _now(),
        checklist: checklist,
      );
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
      final DateTime now = _now();
      final CalendarTask? directTaskEntry = state.model.tasks[event.taskId];
      if (directTaskEntry != null && event.taskId.contains('::')) {
        final CalendarTask task = directTaskEntry.copyWith(modifiedAt: now);
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

      if (occurrenceKey != null && taskToDelete.hasRecurrenceData) {
        emit(state.copyWith(isLoading: true, error: null));
        _recordUndoSnapshot();

        final overrides = Map<String, TaskOccurrenceOverride>.from(
            taskToDelete.occurrenceOverrides);
        final TaskOccurrenceOverride? existing = overrides[occurrenceKey];
        final TaskOccurrenceOverride baseOverride =
            existing ?? const TaskOccurrenceOverride();
        overrides[occurrenceKey] = baseOverride.copyWith(isCancelled: true);

        final updatedTask = taskToDelete.copyWith(
          occurrenceOverrides: overrides,
          modifiedAt: now,
        );
        final updatedModel = state.model.updateTask(updatedTask);
        emitModel(updatedModel, emit, isLoading: false);

        await onTaskUpdated(updatedTask);
        return;
      }

      emit(state.copyWith(isLoading: true, error: null));

      _recordUndoSnapshot();

      final CalendarTask deletedTask = taskToDelete.copyWith(modifiedAt: now);
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

      await onTaskDeleted(deletedTask);
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

      final DateTime? scheduled = task.scheduledTime;
      if (scheduled == null) {
        final DateTime newStart = event.time;
        final Duration preservedDuration = task.duration ??
            (task.endDate != null && task.scheduledTime != null
                ? task.endDate!.difference(task.scheduledTime!)
                : _taskDuration(task));
        final Duration ensuredDuration = preservedDuration.inMinutes > 0
            ? preservedDuration
            : const Duration(hours: 1);
        final DateTime newEndDate = newStart.add(ensuredDuration);

        final CalendarTask scheduledTask = task.copyWith(
          scheduledTime: newStart,
          duration: ensuredDuration,
          endDate: newEndDate,
          modifiedAt: _now(),
        );

        _recordUndoSnapshot();
        final CalendarModel updatedModel =
            state.model.updateTask(scheduledTask);
        emitModel(updatedModel, emit);

        await onTaskUpdated(scheduledTask);
        return;
      }

      final Duration startDelta = event.time.difference(scheduled);
      final CalendarTask? shifted =
          _shiftTaskTiming(task, startDelta, Duration.zero);
      if (shifted == null || identical(shifted, task)) {
        return;
      }

      final updatedTask = shifted.copyWith(modifiedAt: _now());
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
      final DateTime? scheduled = task.scheduledTime;
      if (scheduled == null) {
        throw const CalendarValidationException(
          'scheduledTime',
          'Task requires a scheduled time before resizing',
        );
      }

      final DateTime newStart = event.scheduledTime ?? scheduled;
      Duration? newDuration = event.duration ?? task.duration;
      DateTime? newEndDate = event.endDate ?? task.endDate;

      if (newDuration == null && newEndDate == null) {
        newDuration = _taskDuration(task);
        newEndDate = newStart.add(newDuration);
      } else {
        if (newDuration == null && newEndDate != null) {
          newDuration = newEndDate.difference(newStart);
        } else if (newEndDate == null && newDuration != null) {
          newEndDate = newStart.add(newDuration);
        }
      }

      if (newDuration != null && newDuration.inMinutes < 15) {
        newDuration = const Duration(minutes: 15);
        newEndDate = newStart.add(newDuration);
      }

      final updatedTask = task.copyWith(
        scheduledTime: newStart,
        duration: newDuration,
        endDate: newEndDate,
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

      final TaskOccurrenceOverride baseOverride =
          existing ?? const TaskOccurrenceOverride();
      final TaskOccurrenceOverride updatedOverride = baseOverride.copyWith(
        scheduledTime: event.scheduledTime ?? baseOverride.scheduledTime,
        duration: event.duration ?? baseOverride.duration,
        endDate: event.endDate ?? baseOverride.endDate,
        isCancelled: event.isCancelled ?? baseOverride.isCancelled,
        checklist: event.checklist ?? baseOverride.checklist,
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
      final CalendarTask requestedTarget = event.target;
      final CalendarTask? baseTask = state.model.tasks[requestedTarget.baseId];
      if (baseTask == null) {
        throw CalendarTaskNotFoundException(requestedTarget.baseId);
      }

      final CalendarTask effectiveTarget =
          _resolveSplitTarget(requestedTarget, baseTask);

      final DateTime? start = effectiveTarget.scheduledTime;
      if (start == null) {
        return;
      }

      final Duration totalDuration = _taskDuration(effectiveTarget);
      if (totalDuration.inMinutes <= 0) {
        return;
      }

      final DateTime end = start.add(totalDuration);
      final DateTime splitTime = event.splitTime;
      if (!splitTime.isAfter(start) || !splitTime.isBefore(end)) {
        return;
      }

      final Duration leftDuration = splitTime.difference(start);
      final Duration rightDuration = end.difference(splitTime);
      if (leftDuration.inMicroseconds <= 0 ||
          rightDuration.inMicroseconds <= 0) {
        return;
      }

      final now = _now();

      _recordUndoSnapshot();

      CalendarModel model = state.model;
      final updates = <String, CalendarTask>{};
      CalendarTask? createdTask;

      final bool targetIsOccurrence = effectiveTarget.id != baseTask.id;
      final String targetId = requestedTarget.id;
      final DateTime leftEnd = splitTime;
      final DateTime rightEnd = end;

      if (baseTask.hasRecurrenceData && targetId.contains('::')) {
        final String? occurrenceKey = occurrenceKeyFrom(targetId);
        if (occurrenceKey != null && occurrenceKey.isNotEmpty) {
          final overrides = Map<String, TaskOccurrenceOverride>.from(
            baseTask.occurrenceOverrides,
          );
          final TaskOccurrenceOverride? existing = overrides[occurrenceKey];
          final TaskOccurrenceOverride baseOverride =
              existing ?? const TaskOccurrenceOverride();
          final TaskOccurrenceOverride updatedOverride = baseOverride.copyWith(
            scheduledTime: start,
            duration: leftDuration,
            endDate: leftEnd,
          );

          if (_isOccurrenceOverrideEmpty(updatedOverride)) {
            overrides.remove(occurrenceKey);
          } else {
            overrides[occurrenceKey] = updatedOverride;
          }

          final CalendarTask updatedBase = baseTask.copyWith(
            occurrenceOverrides: overrides,
            modifiedAt: now,
          );
          updates[baseTask.id] = updatedBase;

          createdTask = effectiveTarget.copyWith(
            id: '${effectiveTarget.baseId}::${const Uuid().v4()}',
            scheduledTime: splitTime,
            duration: rightDuration,
            endDate: rightEnd,
            recurrence: null,
            occurrenceOverrides: const {},
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

      if (targetIsOccurrence && !baseTask.hasRecurrenceData) {
        final CalendarTask updatedOccurrence = effectiveTarget.copyWith(
          duration: leftDuration,
          endDate: leftEnd,
          modifiedAt: now,
        );
        updates[updatedOccurrence.id] = updatedOccurrence;

        createdTask = effectiveTarget.copyWith(
          id: '${effectiveTarget.baseId}::${const Uuid().v4()}',
          scheduledTime: splitTime,
          duration: rightDuration,
          endDate: rightEnd,
          recurrence: null,
          occurrenceOverrides: const {},
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

        await onTaskUpdated(updatedOccurrence);
        await onTaskAdded(createdTask);
        return;
      }

      final DateTime originalStart = baseTask.scheduledTime ?? start;
      final DateTime baseEnd = leftEnd;

      final CalendarTask updatedBaseTask = baseTask.copyWith(
        scheduledTime: originalStart,
        duration: leftDuration,
        endDate: baseEnd,
        modifiedAt: now,
      );
      updates[baseTask.id] = updatedBaseTask;

      createdTask = baseTask.copyWith(
        id: '${baseTask.baseId}::${const Uuid().v4()}',
        scheduledTime: splitTime,
        duration: rightDuration,
        endDate: rightEnd,
        recurrence: null,
        occurrenceOverrides: const {},
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
      final CalendarTask source = template;

      final now = _now();
      final String newId = const Uuid().v4();
      final DateTime newStart = event.scheduledTime;

      Duration appliedDuration =
          template.duration ?? baseTask?.duration ?? _taskDuration(source);

      if (template.scheduledTime != null && template.effectiveEndDate != null) {
        final Duration derived =
            template.effectiveEndDate!.difference(template.scheduledTime!);
        if (derived.inMinutes > 0) {
          appliedDuration = derived;
        }
      } else if (baseTask?.scheduledTime != null &&
          baseTask?.effectiveEndDate != null) {
        final Duration derived =
            baseTask!.effectiveEndDate!.difference(baseTask.scheduledTime!);
        if (derived.inMinutes > 0) {
          appliedDuration = derived;
        }
      }

      if (appliedDuration.inMinutes <= 0) {
        appliedDuration = const Duration(hours: 1);
      }
      final DateTime newEndDate = newStart.add(appliedDuration);

      final CalendarTask newTask = source.copyWith(
        id: newId,
        scheduledTime: newStart,
        duration: appliedDuration,
        endDate: newEndDate,
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

  Future<void> _onDayEventAdded(
    CalendarDayEventAdded event,
    Emitter<CalendarState> emit,
  ) async {
    bool snapshotRecorded = false;
    try {
      if (event.title.trim().isEmpty) {
        throw const CalendarValidationException(
          'title',
          'Title cannot be empty',
        );
      }

      emit(state.copyWith(isLoading: true, error: null));
      _recordUndoSnapshot();
      snapshotRecorded = true;

      if (event.endDate != null && event.endDate!.isBefore(event.startDate)) {
        throw const CalendarValidationException(
          'date',
          'End date cannot be before the start date',
        );
      }

      final DayEvent dayEvent = DayEvent.create(
        title: event.title,
        startDate: event.startDate,
        endDate: event.endDate,
        description: event.description,
        reminders: event.reminders,
      );

      final CalendarModel updatedModel = state.model.addDayEvent(dayEvent);
      emitModel(updatedModel, emit, isLoading: false);
      await onDayEventAdded(dayEvent);
    } catch (error) {
      if (snapshotRecorded) {
        _restoreLastUndoSnapshot(emit);
      }
      await _handleError(error, 'Failed to add day event', emit);
    }
  }

  Future<void> _onDayEventUpdated(
    CalendarDayEventUpdated event,
    Emitter<CalendarState> emit,
  ) async {
    bool snapshotRecorded = false;
    try {
      final DayEvent? existing = state.model.dayEvents[event.event.id];
      if (existing == null) {
        throw CalendarDayEventNotFoundException(event.event.id);
      }
      if (event.event.title.trim().isEmpty) {
        throw const CalendarValidationException(
          'title',
          'Title cannot be empty',
        );
      }

      emit(state.copyWith(isLoading: true, error: null));
      _recordUndoSnapshot();
      snapshotRecorded = true;

      if (event.event.normalizedEnd.isBefore(event.event.normalizedStart)) {
        throw const CalendarValidationException(
          'date',
          'End date cannot be before the start date',
        );
      }

      final DayEvent normalized = event.event.normalizedCopy(
        modifiedAt: _now(),
      );
      final CalendarModel updatedModel = state.model.updateDayEvent(normalized);
      emitModel(updatedModel, emit, isLoading: false);
      await onDayEventUpdated(normalized);
    } catch (error) {
      if (snapshotRecorded) {
        _restoreLastUndoSnapshot(emit);
      }
      await _handleError(error, 'Failed to update day event', emit);
    }
  }

  Future<void> _onDayEventDeleted(
    CalendarDayEventDeleted event,
    Emitter<CalendarState> emit,
  ) async {
    bool snapshotRecorded = false;
    try {
      final DayEvent? existing = state.model.dayEvents[event.eventId];
      if (existing == null) {
        throw CalendarDayEventNotFoundException(event.eventId);
      }
      emit(state.copyWith(isLoading: true, error: null));
      _recordUndoSnapshot();
      snapshotRecorded = true;

      final DayEvent deleted = existing.copyWith(modifiedAt: _now());
      final CalendarModel updatedModel =
          state.model.deleteDayEvent(event.eventId);
      emitModel(updatedModel, emit, isLoading: false);
      await onDayEventDeleted(deleted);
    } catch (error) {
      if (snapshotRecorded) {
        _restoreLastUndoSnapshot(emit);
      }
      await _handleError(error, 'Failed to delete day event', emit);
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

      final NlAdapterResult parsedResult =
          await _nlParserService.parse(event.text);
      final CalendarTask parsed = parsedResult.task;
      final now = _now();
      final task = parsed.copyWith(
        description: event.description ?? parsed.description,
        deadline: event.deadline ?? parsed.deadline,
        priority: event.priority == TaskPriority.none
            ? parsed.priority
            : event.priority,
        checklist: _normalizedChecklist(event.checklist),
        modifiedAt: now,
        reminders: (event.reminders ?? parsed.reminders)?.normalized() ??
            ReminderPreferences.defaults(),
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
      updatedSelection.addAll(_selectionGroupFor(event.taskId!));
    }
    _emitSelectionState(
      emit: emit,
      isSelectionMode: true,
      selectedTaskIds: updatedSelection,
    );
  }

  void _onSelectionAllRequested(
    CalendarSelectionAllRequested event,
    Emitter<CalendarState> emit,
  ) {
    if (state.model.tasks.isEmpty) {
      return;
    }
    _emitSelectionState(
      emit: emit,
      isSelectionMode: true,
      selectedTaskIds: state.model.tasks.keys.toSet(),
    );
  }

  void _onSelectionToggled(
    CalendarSelectionToggled event,
    Emitter<CalendarState> emit,
  ) {
    final toggledId = event.taskId;
    final currentSelection = <String>{...state.selectedTaskIds};
    final group = _selectionGroupFor(toggledId);
    final bool groupSelected =
        group.isNotEmpty && group.every((id) => currentSelection.contains(id));
    if (groupSelected) {
      currentSelection.removeAll(group);
    } else {
      currentSelection.addAll(group);
    }

    if (!state.isSelectionMode && !groupSelected) {
      currentSelection
        ..clear()
        ..addAll(group);
      _emitSelectionState(
        emit: emit,
        isSelectionMode: true,
        selectedTaskIds: currentSelection,
      );
      return;
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

  void _onSelectionIdsAdded(
    CalendarSelectionIdsAdded event,
    Emitter<CalendarState> emit,
  ) {
    if (event.taskIds.isEmpty) {
      return;
    }
    final updated = <String>{...state.selectedTaskIds, ...event.taskIds};
    _emitSelectionState(
      emit: emit,
      isSelectionMode: true,
      selectedTaskIds: updated,
    );
  }

  void _onSelectionIdsRemoved(
    CalendarSelectionIdsRemoved event,
    Emitter<CalendarState> emit,
  ) {
    if (event.taskIds.isEmpty) {
      return;
    }
    final updated = <String>{...state.selectedTaskIds}
      ..removeAll(event.taskIds);
    final bool nextMode = updated.isNotEmpty;
    _emitSelectionState(
      emit: emit,
      isSelectionMode: nextMode,
      selectedTaskIds: updated,
    );
  }

  Future<void> _onSelectionTitleChanged(
    CalendarSelectionTitleChanged event,
    Emitter<CalendarState> emit,
  ) async {
    final title = event.title.trim();
    if (title.isEmpty || state.selectedTaskIds.isEmpty) {
      return;
    }

    final now = _now();
    final updates = <String, CalendarTask>{};
    final baseOverrideUpdates = <String, Map<String, TaskOccurrenceOverride>>{};

    for (final id in state.selectedTaskIds) {
      final CalendarTask? direct = state.model.tasks[id];
      if (direct != null) {
        if (direct.title != title) {
          updates[id] = direct.copyWith(title: title, modifiedAt: now);
        }
        continue;
      }

      final String baseId = baseTaskIdFrom(id);
      final CalendarTask? baseTask = state.model.tasks[baseId];
      if (baseTask == null) {
        continue;
      }

      final String? occurrenceKey = occurrenceKeyFrom(id);
      if (occurrenceKey == null || occurrenceKey.isEmpty) {
        continue;
      }

      final CalendarTask baseReference = updates[baseId] ?? baseTask;
      final overrides = baseOverrideUpdates.putIfAbsent(
        baseId,
        () => Map<String, TaskOccurrenceOverride>.from(
          baseReference.occurrenceOverrides,
        ),
      );

      final TaskOccurrenceOverride existing = overrides[occurrenceKey] ??
          baseReference.occurrenceOverrides[occurrenceKey] ??
          const TaskOccurrenceOverride();
      final String? overrideTitle = title == baseTask.title ? null : title;
      final TaskOccurrenceOverride updatedOverride =
          existing.copyWith(title: overrideTitle);

      if (_overrideIsEmpty(updatedOverride)) {
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
      final CalendarTask? baseTask =
          mergedUpdates[baseId] ?? state.model.tasks[baseId];
      if (baseTask == null) {
        continue;
      }
      mergedUpdates[baseId] = baseTask.copyWith(
        occurrenceOverrides: entry.value,
        modifiedAt: now,
      );
    }

    final updatedModel = state.model.replaceTasks(mergedUpdates);
    emitModel(
      updatedModel,
      emit,
      selectedTaskIds: state.selectedTaskIds,
    );

    for (final task in mergedUpdates.values) {
      await onTaskUpdated(task);
    }
  }

  Future<void> _onSelectionDescriptionChanged(
    CalendarSelectionDescriptionChanged event,
    Emitter<CalendarState> emit,
  ) async {
    if (state.selectedTaskIds.isEmpty) {
      return;
    }
    final String? normalized = event.description?.trim();
    final String? description =
        normalized == null || normalized.isEmpty ? null : normalized;

    final now = _now();
    final updates = <String, CalendarTask>{};
    final baseOverrideUpdates = <String, Map<String, TaskOccurrenceOverride>>{};

    for (final id in state.selectedTaskIds) {
      final CalendarTask? direct = state.model.tasks[id];
      if (direct != null) {
        if (direct.description != description) {
          updates[id] = direct.copyWith(
            description: description,
            modifiedAt: now,
          );
        }
        continue;
      }

      final String baseId = baseTaskIdFrom(id);
      final CalendarTask? baseTask = state.model.tasks[baseId];
      if (baseTask == null) {
        continue;
      }

      final String? occurrenceKey = occurrenceKeyFrom(id);
      if (occurrenceKey == null || occurrenceKey.isEmpty) {
        continue;
      }

      final CalendarTask baseReference = updates[baseId] ?? baseTask;
      final overrides = baseOverrideUpdates.putIfAbsent(
        baseId,
        () => Map<String, TaskOccurrenceOverride>.from(
          baseReference.occurrenceOverrides,
        ),
      );

      final TaskOccurrenceOverride existing = overrides[occurrenceKey] ??
          baseReference.occurrenceOverrides[occurrenceKey] ??
          const TaskOccurrenceOverride();
      final String baseDescription = baseTask.description ?? '';
      final String newDescription = description ?? '';
      final String? overrideDescription =
          newDescription == baseDescription ? null : newDescription;
      final TaskOccurrenceOverride updatedOverride =
          existing.copyWith(description: overrideDescription);

      if (_overrideIsEmpty(updatedOverride)) {
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
      final CalendarTask? baseTask =
          mergedUpdates[baseId] ?? state.model.tasks[baseId];
      if (baseTask == null) {
        continue;
      }
      mergedUpdates[baseId] = baseTask.copyWith(
        occurrenceOverrides: entry.value,
        modifiedAt: now,
      );
    }

    final updatedModel = state.model.replaceTasks(mergedUpdates);
    emitModel(
      updatedModel,
      emit,
      selectedTaskIds: state.selectedTaskIds,
    );

    for (final task in mergedUpdates.values) {
      await onTaskUpdated(task);
    }
  }

  Future<void> _onSelectionLocationChanged(
    CalendarSelectionLocationChanged event,
    Emitter<CalendarState> emit,
  ) async {
    if (state.selectedTaskIds.isEmpty) {
      return;
    }
    final String? normalized = event.location?.trim();
    final String? location =
        normalized == null || normalized.isEmpty ? null : normalized;

    final now = _now();
    final updates = <String, CalendarTask>{};
    final baseOverrideUpdates = <String, Map<String, TaskOccurrenceOverride>>{};

    for (final id in state.selectedTaskIds) {
      final CalendarTask? direct = state.model.tasks[id];
      if (direct != null) {
        if (direct.location != location) {
          updates[id] = direct.copyWith(
            location: location,
            modifiedAt: now,
          );
        }
        continue;
      }

      final String baseId = baseTaskIdFrom(id);
      final CalendarTask? baseTask = state.model.tasks[baseId];
      if (baseTask == null) {
        continue;
      }

      final String? occurrenceKey = occurrenceKeyFrom(id);
      if (occurrenceKey == null || occurrenceKey.isEmpty) {
        continue;
      }

      final CalendarTask baseReference = updates[baseId] ?? baseTask;
      final overrides = baseOverrideUpdates.putIfAbsent(
        baseId,
        () => Map<String, TaskOccurrenceOverride>.from(
          baseReference.occurrenceOverrides,
        ),
      );

      final TaskOccurrenceOverride existing = overrides[occurrenceKey] ??
          baseReference.occurrenceOverrides[occurrenceKey] ??
          const TaskOccurrenceOverride();
      final String baseLocation = baseTask.location ?? '';
      final String newLocation = location ?? '';
      final String? overrideLocation =
          newLocation == baseLocation ? null : newLocation;
      final TaskOccurrenceOverride updatedOverride =
          existing.copyWith(location: overrideLocation);

      if (_overrideIsEmpty(updatedOverride)) {
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
      final CalendarTask? baseTask =
          mergedUpdates[baseId] ?? state.model.tasks[baseId];
      if (baseTask == null) {
        continue;
      }
      mergedUpdates[baseId] = baseTask.copyWith(
        occurrenceOverrides: entry.value,
        modifiedAt: now,
      );
    }

    final updatedModel = state.model.replaceTasks(mergedUpdates);
    emitModel(
      updatedModel,
      emit,
      selectedTaskIds: state.selectedTaskIds,
    );

    for (final task in mergedUpdates.values) {
      await onTaskUpdated(task);
    }
  }

  Future<void> _onSelectionChecklistChanged(
    CalendarSelectionChecklistChanged event,
    Emitter<CalendarState> emit,
  ) async {
    if (state.selectedTaskIds.isEmpty) {
      return;
    }
    final List<TaskChecklistItem> checklist =
        _normalizedChecklist(event.checklist);
    final now = _now();
    final updates = <String, CalendarTask>{};
    final baseOverrideUpdates = <String, Map<String, TaskOccurrenceOverride>>{};

    for (final id in state.selectedTaskIds) {
      final CalendarTask? direct = state.model.tasks[id];
      if (direct != null) {
        if (!_checklistsEqual(direct.checklist, checklist)) {
          updates[id] = direct.copyWith(
            checklist: checklist,
            modifiedAt: now,
          );
        }
        continue;
      }

      final String baseId = baseTaskIdFrom(id);
      final CalendarTask? baseTask = state.model.tasks[baseId];
      if (baseTask == null) {
        continue;
      }

      final String? occurrenceKey = occurrenceKeyFrom(id);
      if (occurrenceKey == null || occurrenceKey.isEmpty) {
        continue;
      }

      final CalendarTask baseReference = updates[baseId] ?? baseTask;
      final Map<String, TaskOccurrenceOverride> overrides =
          baseOverrideUpdates.putIfAbsent(
        baseId,
        () => Map<String, TaskOccurrenceOverride>.from(
          baseReference.occurrenceOverrides,
        ),
      );

      final TaskOccurrenceOverride existing = overrides[occurrenceKey] ??
          baseReference.occurrenceOverrides[occurrenceKey] ??
          const TaskOccurrenceOverride();
      final bool matchesBase = _checklistsEqual(checklist, baseTask.checklist);
      final TaskOccurrenceOverride updatedOverride = existing.copyWith(
        checklist: matchesBase ? null : checklist,
      );

      if (_overrideIsEmpty(updatedOverride)) {
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
      final CalendarTask? baseTask =
          mergedUpdates[baseId] ?? state.model.tasks[baseId];
      if (baseTask == null) {
        continue;
      }
      mergedUpdates[baseId] = baseTask.copyWith(
        occurrenceOverrides: entry.value,
        modifiedAt: now,
      );
    }

    final updatedModel = state.model.replaceTasks(mergedUpdates);
    emitModel(
      updatedModel,
      emit,
      selectedTaskIds: state.selectedTaskIds,
    );

    for (final task in mergedUpdates.values) {
      await onTaskUpdated(task);
    }
  }

  Future<void> _onSelectionTimeShifted(
    CalendarSelectionTimeShifted event,
    Emitter<CalendarState> emit,
  ) async {
    final Duration startDelta = event.startDelta ?? Duration.zero;
    final Duration endDelta = event.endDelta ?? Duration.zero;
    if (state.selectedTaskIds.isEmpty ||
        (startDelta == Duration.zero && endDelta == Duration.zero)) {
      return;
    }

    final now = _now();
    final updates = <String, CalendarTask>{};
    final baseOverrideUpdates = <String, Map<String, TaskOccurrenceOverride>>{};

    for (final id in state.selectedTaskIds) {
      final CalendarTask? direct = state.model.tasks[id];
      if (direct != null) {
        final CalendarTask? shifted =
            _shiftTaskTiming(direct, startDelta, endDelta);
        if (shifted != null && shifted != direct) {
          updates[id] = shifted.copyWith(modifiedAt: now);
        }
        continue;
      }

      final String baseId = baseTaskIdFrom(id);
      final CalendarTask? baseTask = state.model.tasks[baseId];
      if (baseTask == null) {
        continue;
      }

      if (id == baseId) {
        final CalendarTask? shifted =
            _shiftTaskTiming(baseTask, startDelta, endDelta);
        if (shifted != null && shifted != baseTask) {
          updates[baseId] = shifted.copyWith(modifiedAt: now);
        }
        continue;
      }

      final String? occurrenceKey = occurrenceKeyFrom(id);
      if (occurrenceKey == null || occurrenceKey.isEmpty) {
        continue;
      }

      final CalendarTask? occurrence = baseTask.occurrenceForId(id);
      if (occurrence?.scheduledTime == null) {
        continue;
      }
      final CalendarTask? shiftedOccurrence =
          _shiftTaskTiming(occurrence!, startDelta, endDelta);
      if (shiftedOccurrence == null) {
        continue;
      }

      final overrides = baseOverrideUpdates.putIfAbsent(
        baseId,
        () => Map<String, TaskOccurrenceOverride>.from(
          baseTask.occurrenceOverrides,
        ),
      );
      final TaskOccurrenceOverride existing =
          overrides[occurrenceKey] ?? const TaskOccurrenceOverride();
      overrides[occurrenceKey] = existing.copyWith(
        scheduledTime: shiftedOccurrence.scheduledTime,
        duration: shiftedOccurrence.duration,
        endDate: shiftedOccurrence.effectiveEndDate,
      );
    }

    if (updates.isEmpty && baseOverrideUpdates.isEmpty) {
      return;
    }

    _recordUndoSnapshot();

    final mergedUpdates = <String, CalendarTask>{...updates};
    for (final entry in baseOverrideUpdates.entries) {
      final String baseId = entry.key;
      final CalendarTask? baseTask =
          mergedUpdates[baseId] ?? state.model.tasks[baseId];
      if (baseTask == null) {
        continue;
      }
      mergedUpdates[baseId] = baseTask.copyWith(
        occurrenceOverrides: entry.value,
        modifiedAt: now,
      );
    }

    final updatedModel = state.model.replaceTasks(mergedUpdates);
    emitModel(
      updatedModel,
      emit,
      selectedTaskIds: state.selectedTaskIds,
    );

    for (final task in mergedUpdates.values) {
      await onTaskUpdated(task);
    }
  }

  Future<void> _onSelectionRemindersChanged(
    CalendarSelectionRemindersChanged event,
    Emitter<CalendarState> emit,
  ) async {
    if (state.selectedTaskIds.isEmpty) {
      return;
    }
    final ReminderPreferences normalized = event.reminders.normalized();
    final DateTime now = _now();
    final Set<String> baseIds = state.selectedTaskIds
        .map(baseTaskIdFrom)
        .where(state.model.tasks.containsKey)
        .toSet();
    if (baseIds.isEmpty) {
      return;
    }

    _recordUndoSnapshot();
    final Map<String, CalendarTask> updates = <String, CalendarTask>{};
    for (final String id in baseIds) {
      final CalendarTask? task = state.model.tasks[id];
      if (task == null) {
        continue;
      }
      updates[id] = task.copyWith(
        reminders: normalized,
        modifiedAt: now,
      );
    }
    if (updates.isEmpty) {
      return;
    }
    final CalendarModel updatedModel = state.model.replaceTasks(updates);
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

  Set<String> _selectionGroupFor(String id) {
    return {id};
  }

  bool _overrideIsEmpty(TaskOccurrenceOverride override) {
    return override.scheduledTime == null &&
        override.duration == null &&
        override.endDate == null &&
        override.isCancelled == null &&
        override.priority == null &&
        override.isCompleted == null &&
        override.title == null &&
        override.description == null &&
        override.location == null &&
        (override.checklist == null || override.checklist!.isEmpty) &&
        override.rawProperties.isEmpty &&
        override.rawComponents.isEmpty;
  }

  List<TaskChecklistItem> _normalizedChecklist(
    List<TaskChecklistItem> source,
  ) {
    final List<TaskChecklistItem> normalized = <TaskChecklistItem>[];
    for (final TaskChecklistItem item in source) {
      final String label = item.label.trim();
      if (label.isEmpty) {
        continue;
      }
      normalized.add(item.copyWith(label: label));
    }
    return List<TaskChecklistItem>.unmodifiable(normalized);
  }

  bool _checklistsEqual(
    List<TaskChecklistItem> a,
    List<TaskChecklistItem> b,
  ) {
    if (identical(a, b)) {
      return true;
    }
    final List<TaskChecklistItem> normalizedA = _normalizedChecklist(a);
    final List<TaskChecklistItem> normalizedB = _normalizedChecklist(b);
    if (normalizedA.length != normalizedB.length) {
      return false;
    }
    for (var i = 0; i < normalizedA.length; i++) {
      final TaskChecklistItem left = normalizedA[i];
      final TaskChecklistItem right = normalizedB[i];
      if (left.label != right.label || left.isCompleted != right.isCompleted) {
        return false;
      }
    }
    return true;
  }

  Duration _taskDuration(CalendarTask task) {
    final DateTime? start = task.scheduledTime;
    if (start == null) {
      return const Duration(hours: 1);
    }
    final Duration? explicit = task.duration;
    if (explicit != null && explicit.inMinutes > 0) {
      return explicit;
    }
    final DateTime? end = task.effectiveEndDate;
    if (end != null && end.isAfter(start)) {
      return end.difference(start);
    }
    return const Duration(hours: 1);
  }

  CalendarTask _resolveSplitTarget(
    CalendarTask request,
    CalendarTask baseTask,
  ) {
    final CalendarTask? direct = state.model.tasks[request.id];
    if (direct != null) {
      return direct;
    }
    if (request.id == baseTask.id) {
      return baseTask;
    }
    return baseTask.occurrenceForId(request.id) ?? request;
  }

  CalendarTask? _shiftTaskTiming(
    CalendarTask task,
    Duration startDelta,
    Duration endDelta,
  ) {
    if (startDelta == Duration.zero && endDelta == Duration.zero) {
      return task;
    }
    final DateTime? start = task.scheduledTime;
    if (start == null) {
      return null;
    }

    final Duration originalDuration = _taskDuration(task);
    Duration newDuration = originalDuration + endDelta;
    if (newDuration.inMinutes < 15) {
      newDuration = const Duration(minutes: 15);
    }

    final DateTime newStart = start.add(startDelta);
    final DateTime newEnd = newStart.add(newDuration);

    DateTime? newEndDate = newEnd;
    if (task.endDate == null && task.duration == null) {
      newEndDate = null;
    }

    return task.copyWith(
      scheduledTime: newStart,
      duration: newDuration,
      endDate: newEndDate,
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

  void _onTaskFocusRequested(
    CalendarTaskFocusRequested event,
    Emitter<CalendarState> emit,
  ) {
    final DateTime? anchor = _focusAnchorFor(event.taskId);
    if (anchor == null) {
      return;
    }

    _focusSequence += 1;

    final DateTime anchorDate = DateTime(anchor.year, anchor.month, anchor.day);
    final int weekday = anchorDate.weekday;
    final DateTime weekStart = anchorDate.subtract(
      Duration(days: weekday - DateTime.monday),
    );
    final int dayIndex = anchorDate.difference(weekStart).inDays;

    emit(
      state.copyWith(
        selectedDate: anchorDate,
        selectedDayIndex: dayIndex,
        pendingFocus: TaskFocusRequest(
          taskId: event.taskId,
          anchor: anchor,
          token: _focusSequence,
        ),
      ),
    );
  }

  void _onTaskFocusCleared(
    CalendarTaskFocusCleared event,
    Emitter<CalendarState> emit,
  ) {
    if (state.pendingFocus == null) {
      return;
    }
    emit(state.copyWith(pendingFocus: null));
  }

  Future<void> _onTasksImported(
    CalendarTasksImported event,
    Emitter<CalendarState> emit,
  ) async {
    final List<CalendarTask> incoming = event.tasks;
    if (incoming.isEmpty) {
      return;
    }
    try {
      emit(state.copyWith(isLoading: true, error: null));
      _recordUndoSnapshot();
      final now = _now();
      final existingIds = state.model.tasks.keys.toSet();
      final additions = <String, CalendarTask>{};
      for (final original in incoming) {
        CalendarTask next = original;
        if (next.id.isEmpty || existingIds.contains(next.id)) {
          next = next.copyWith(id: const Uuid().v4());
        }
        additions[next.id] = next.copyWith(
          modifiedAt: now,
        );
        existingIds.add(next.id);
      }
      final updatedModel = state.model.replaceTasks(additions);
      emitModel(
        updatedModel,
        emit,
        isLoading: false,
        isSelectionMode: false,
        selectedTaskIds: const <String>{},
      );
      for (final task in additions.values) {
        await onTaskAdded(task);
      }
    } catch (error) {
      await _handleError(error, 'Failed to import tasks', emit);
    }
  }

  Future<void> _onModelImported(
    CalendarModelImported event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      emit(state.copyWith(isLoading: true, error: null));
      _recordUndoSnapshot();
      final merged = state.model.mergeWith(event.model);
      emitModel(
        merged,
        emit,
        isLoading: false,
        isSelectionMode: false,
        selectedTaskIds: const <String>{},
      );
      await onModelImported(merged);
    } catch (error) {
      await _handleError(error, 'Failed to import calendar', emit);
    }
  }

  Future<void> _onCriticalPathCreated(
    CalendarCriticalPathCreated event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      final String trimmedName = event.name.trim();
      if (trimmedName.isEmpty) {
        throw const CalendarValidationException(
          'criticalPath',
          'Path name cannot be empty',
        );
      }
      _recordUndoSnapshot();
      final DateTime now = _now();
      final CalendarCriticalPath path = CalendarCriticalPath.create(
        name: trimmedName,
      ).copyWith(
        createdAt: now,
        modifiedAt: now,
      );
      CalendarModel updatedModel = state.model.addCriticalPath(path);
      var shouldFocus = false;
      final String? initialTaskId = event.taskId;
      if (initialTaskId != null) {
        final CalendarTask? task =
            updatedModel.resolveTaskInstance(initialTaskId);
        if (task != null) {
          updatedModel = updatedModel.addTaskToCriticalPath(
            pathId: path.id,
            taskId: task.baseId,
          );
          shouldFocus = true;
        }
      }
      emitModel(
        updatedModel,
        emit,
        focusedCriticalPathId:
            shouldFocus ? path.id : state.focusedCriticalPathId,
        focusedCriticalPathSpecified: shouldFocus,
      );
      final createdPath = updatedModel.criticalPaths[path.id]!;
      await onCriticalPathAdded(createdPath);
    } catch (error) {
      await _handleError(error, 'Failed to create critical path', emit);
    }
  }

  Future<void> _onCriticalPathRenamed(
    CalendarCriticalPathRenamed event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      final CalendarCriticalPath? existing =
          state.model.criticalPaths[event.pathId];
      if (existing == null) {
        throw const CalendarValidationException(
          'criticalPath',
          'Critical path not found',
        );
      }
      final String trimmedName = event.name.trim();
      if (trimmedName.isEmpty) {
        throw const CalendarValidationException(
          'criticalPath',
          'Path name cannot be empty',
        );
      }
      _recordUndoSnapshot();
      final CalendarCriticalPath renamed = existing.rename(trimmedName);
      final CalendarModel updatedModel =
          state.model.updateCriticalPath(renamed);
      emitModel(
        updatedModel,
        emit,
        focusedCriticalPathId: state.focusedCriticalPathId,
        focusedCriticalPathSpecified: true,
      );
      await onCriticalPathUpdated(renamed);
    } catch (error) {
      await _handleError(error, 'Failed to rename critical path', emit);
    }
  }

  Future<void> _onCriticalPathDeleted(
    CalendarCriticalPathDeleted event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      final existingPath = state.model.criticalPaths[event.pathId];
      if (existingPath == null) {
        return;
      }
      _recordUndoSnapshot();
      final CalendarModel updatedModel =
          state.model.removeCriticalPath(event.pathId);
      final bool shouldClearFocus = state.focusedCriticalPathId == event.pathId;
      emitModel(
        updatedModel,
        emit,
        focusedCriticalPathId:
            shouldClearFocus ? null : state.focusedCriticalPathId,
        focusedCriticalPathSpecified: true,
      );
      await onCriticalPathDeleted(existingPath);
    } catch (error) {
      await _handleError(error, 'Failed to delete critical path', emit);
    }
  }

  Future<void> _onCriticalPathTaskAdded(
    CalendarCriticalPathTaskAdded event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      final CalendarCriticalPath? path =
          state.model.criticalPaths[event.pathId];
      if (path == null || path.isArchived) {
        throw const CalendarValidationException(
          'criticalPath',
          'Critical path not found',
        );
      }

      final CalendarTask? task = state.model.resolveTaskInstance(event.taskId);
      if (task == null) {
        throw CalendarTaskNotFoundException(event.taskId);
      }

      _recordUndoSnapshot();
      final CalendarModel updatedModel = state.model.addTaskToCriticalPath(
        pathId: path.id,
        taskId: task.baseId,
        index: event.index,
      );
      emitModel(
        updatedModel,
        emit,
        focusedCriticalPathId: state.focusedCriticalPathId,
        focusedCriticalPathSpecified: true,
      );
      final updatedPath = updatedModel.criticalPaths[path.id]!;
      await onCriticalPathUpdated(updatedPath);
    } catch (error) {
      await _handleError(
        error,
        'Failed to add task to critical path',
        emit,
      );
    }
  }

  Future<void> _onCriticalPathTaskRemoved(
    CalendarCriticalPathTaskRemoved event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      if (!state.model.criticalPaths.containsKey(event.pathId)) {
        return;
      }
      _recordUndoSnapshot();
      final CalendarModel updatedModel = state.model.removeTaskFromCriticalPath(
        pathId: event.pathId,
        taskId: baseTaskIdFrom(event.taskId),
      );
      emitModel(
        updatedModel,
        emit,
        focusedCriticalPathId: state.focusedCriticalPathId,
        focusedCriticalPathSpecified: true,
      );
      final updatedPath = updatedModel.criticalPaths[event.pathId]!;
      await onCriticalPathUpdated(updatedPath);
    } catch (error) {
      await _handleError(
        error,
        'Failed to remove task from critical path',
        emit,
      );
    }
  }

  Future<void> _onCriticalPathReordered(
    CalendarCriticalPathReordered event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      final CalendarCriticalPath? path =
          state.model.criticalPaths[event.pathId];
      if (path == null || path.isArchived) {
        throw const CalendarValidationException(
          'criticalPath',
          'Critical path not found',
        );
      }

      _recordUndoSnapshot();
      final CalendarModel updatedModel = state.model.reorderCriticalPath(
        pathId: event.pathId,
        orderedTaskIds: event.orderedTaskIds,
      );
      emitModel(
        updatedModel,
        emit,
        focusedCriticalPathId: state.focusedCriticalPathId,
        focusedCriticalPathSpecified: true,
      );
      final reorderedPath = updatedModel.criticalPaths[event.pathId]!;
      await onCriticalPathUpdated(reorderedPath);
    } catch (error) {
      await _handleError(
        error,
        'Failed to reorder critical path',
        emit,
      );
    }
  }

  void _onCriticalPathFocused(
    CalendarCriticalPathFocused event,
    Emitter<CalendarState> emit,
  ) {
    final String? normalized = _normalizeFocusedPath(
      event.pathId,
      state.model,
    );
    final Set<String> filteredSelection = _filterSelectionForFocus(
      focusedPathId: normalized,
      model: state.model,
      selection: state.selectedTaskIds,
    );
    final bool nextSelectionMode =
        state.isSelectionMode && filteredSelection.isNotEmpty;
    emit(
      state.copyWith(
        focusedCriticalPathId: normalized,
        isSelectionMode: nextSelectionMode,
        selectedTaskIds:
            nextSelectionMode ? filteredSelection : const <String>{},
        canUndo: _undoStack.isNotEmpty,
        canRedo: _redoStack.isNotEmpty,
      ),
    );
  }

  DateTime? _focusAnchorFor(String taskId) {
    final CalendarTask? direct = state.model.tasks[taskId];
    if (direct != null) {
      return direct.scheduledTime ?? direct.deadline;
    }

    final String baseId = baseTaskIdFrom(taskId);
    final CalendarTask? baseTask = state.model.tasks[baseId];
    if (baseTask == null) {
      return null;
    }

    final String? occurrenceKey = occurrenceKeyFrom(taskId);
    if (occurrenceKey == null || occurrenceKey.isEmpty) {
      return baseTask.scheduledTime ?? baseTask.deadline;
    }

    final TaskOccurrenceOverride? override =
        baseTask.occurrenceOverrides[occurrenceKey];
    if (override?.scheduledTime != null) {
      return override!.scheduledTime;
    }

    final CalendarTask? occurrence = baseTask.occurrenceForId(taskId);
    if (occurrence?.scheduledTime != null) {
      return occurrence!.scheduledTime;
    }

    DateTime? anchor;
    if (occurrenceKey == baseTask.baseOccurrenceKey) {
      anchor = baseTask.scheduledTime;
    } else {
      final int? micros = int.tryParse(occurrenceKey);
      if (micros != null) {
        anchor = DateTime.fromMicrosecondsSinceEpoch(micros);
      }
    }

    if (anchor == null) {
      final DateTime? parsed = DateTime.tryParse(occurrenceKey);
      if (parsed != null) {
        anchor = parsed;
      }
    }

    return anchor ?? baseTask.scheduledTime ?? baseTask.deadline;
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
      if (baseTask == null || !baseTask.hasRecurrenceData) {
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
        final TaskOccurrenceOverride? existing = overrides[occurrenceKey];
        final TaskOccurrenceOverride baseOverride =
            existing ?? const TaskOccurrenceOverride();
        overrides[occurrenceKey] = baseOverride.copyWith(isCancelled: true);
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
    final RecurrenceRule? normalizedRecurrence =
        (event.recurrence == null || event.recurrence!.isNone)
            ? null
            : event.recurrence;
    final Set<String> processedBaseIds = <String>{};

    bool recurrenceMatches(CalendarTask task) {
      final RecurrenceRule? current =
          (task.recurrence == null || task.recurrence!.isNone)
              ? null
              : task.recurrence;
      if (current == null && normalizedRecurrence == null) {
        return true;
      }
      if (current != null && normalizedRecurrence != null) {
        return current == normalizedRecurrence;
      }
      return false;
    }

    void queueUpdate(String taskId, CalendarTask task) {
      if (recurrenceMatches(task)) {
        return;
      }
      updates[taskId] = task.copyWith(
        recurrence: normalizedRecurrence,
        occurrenceOverrides: const {},
        modifiedAt: now,
      );
    }

    for (final id in state.selectedTaskIds) {
      final CalendarTask? direct = state.model.tasks[id];
      if (direct != null) {
        processedBaseIds.add(direct.id);
        queueUpdate(direct.id, direct);
        continue;
      }

      final String baseId = baseTaskIdFrom(id);
      if (baseId.isEmpty || processedBaseIds.contains(baseId)) {
        continue;
      }

      processedBaseIds.add(baseId);
      final CalendarTask? baseTask = state.model.tasks[baseId];
      if (baseTask == null) {
        continue;
      }

      queueUpdate(baseId, baseTask);
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

    final _CalendarUndoSnapshot previousSnapshot = _undoStack.removeLast();
    _redoStack.add(
      _CalendarUndoSnapshot(
        model: state.model,
        isSelectionMode: state.isSelectionMode,
        selectedTaskIds: Set<String>.from(state.selectedTaskIds),
        focusedCriticalPathId: state.focusedCriticalPathId,
      ),
    );

    emitModel(
      previousSnapshot.model,
      emit,
      selectedDate: state.selectedDate,
      isSelectionMode: previousSnapshot.isSelectionMode,
      selectedTaskIds: Set<String>.from(previousSnapshot.selectedTaskIds),
      focusedCriticalPathId: previousSnapshot.focusedCriticalPathId,
      focusedCriticalPathSpecified: true,
    );
  }

  void _onRedoRequested(
    CalendarRedoRequested event,
    Emitter<CalendarState> emit,
  ) {
    if (_redoStack.isEmpty) {
      return;
    }

    final _CalendarUndoSnapshot nextSnapshot = _redoStack.removeLast();
    _undoStack.add(
      _CalendarUndoSnapshot(
        model: state.model,
        isSelectionMode: state.isSelectionMode,
        selectedTaskIds: Set<String>.from(state.selectedTaskIds),
        focusedCriticalPathId: state.focusedCriticalPathId,
      ),
    );

    emitModel(
      nextSnapshot.model,
      emit,
      selectedDate: state.selectedDate,
      isSelectionMode: nextSnapshot.isSelectionMode,
      selectedTaskIds: Set<String>.from(nextSnapshot.selectedTaskIds),
      focusedCriticalPathId: nextSnapshot.focusedCriticalPathId,
      focusedCriticalPathSpecified: true,
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

  void _onSyncWarningRaised(
    CalendarSyncWarningRaised event,
    Emitter<CalendarState> emit,
  ) {
    emit(state.copyWith(syncWarning: event.warning));
  }

  void _onSyncWarningCleared(
    CalendarSyncWarningCleared event,
    Emitter<CalendarState> emit,
  ) {
    emit(state.copyWith(syncWarning: null));
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
    String? focusedCriticalPathId,
    bool focusedCriticalPathSpecified = false,
  }) {
    final String? targetFocus = focusedCriticalPathSpecified
        ? focusedCriticalPathId
        : (focusedCriticalPathId ?? state.focusedCriticalPathId);
    final String? normalizedFocus = _normalizeFocusedPath(
      targetFocus,
      model,
    );

    final Set<String> nextSelectionIds =
        selectedTaskIds ?? state.selectedTaskIds;
    final Set<String> filteredSelection = _filterSelectionForFocus(
      focusedPathId: normalizedFocus,
      model: model,
      selection: nextSelectionIds,
    );
    final bool resolvedSelectionMode =
        (isSelectionMode ?? state.isSelectionMode) &&
            filteredSelection.isNotEmpty;

    final nextState = state.copyWith(
      model: model,
      dueReminders: _getDueReminders(model),
      nextTask: _getNextTask(model),
      selectedDate: selectedDate ?? state.selectedDate,
      isLoading: isLoading ?? state.isLoading,
      lastSyncTime: lastSyncTime ?? state.lastSyncTime,
      isSelectionMode: resolvedSelectionMode,
      selectedTaskIds:
          resolvedSelectionMode ? filteredSelection : const <String>{},
      canUndo: _undoStack.isNotEmpty,
      canRedo: _redoStack.isNotEmpty,
      focusedCriticalPathId: normalizedFocus,
    );
    emit(nextState);
    _pendingReminderSync = _pendingReminderSync.then(
      (_) => _reminderController?.syncWithTasks(
        model.tasks.values,
        dayEvents: model.dayEvents.values,
      ),
    );
  }

  String? _normalizeFocusedPath(String? candidate, CalendarModel model) {
    if (candidate == null) {
      return null;
    }
    final CalendarCriticalPath? path = model.criticalPaths[candidate];
    if (path == null || path.isArchived) {
      return null;
    }
    return candidate;
  }

  Set<String> _filterSelectionForFocus({
    required String? focusedPathId,
    required CalendarModel model,
    required Set<String> selection,
  }) {
    if (selection.isEmpty) {
      return selection;
    }

    final CalendarCriticalPath? focus =
        focusedPathId == null ? null : model.criticalPaths[focusedPathId];

    final Set<String> normalizedSelection = selection.where((id) {
      final String baseId = baseTaskIdFrom(id);
      return model.tasks.containsKey(id) || model.tasks.containsKey(baseId);
    }).toSet();

    if (focus == null || focus.isArchived) {
      return normalizedSelection;
    }

    if (focus.taskIds.isEmpty) {
      return <String>{};
    }

    final Set<String> allowedBaseIds =
        focus.taskIds.map(baseTaskIdFrom).toSet();
    return normalizedSelection
        .where((id) => allowedBaseIds.contains(baseTaskIdFrom(id)))
        .toSet();
  }

  List<CalendarTask> _getDueReminders(CalendarModel model) {
    final now = _now();

    return model.tasks.values.where((task) {
      if (task.isCompleted || task.deadline == null) {
        return false;
      }
      return task.deadline!.isBefore(now);
    }).toList()
      ..sort((a, b) => a.deadline!.compareTo(b.deadline!));
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

  /// Called when any critical path changes. Override for bulk sync fallback.
  @protected
  Future<void> onCriticalPathsChanged(CalendarModel model) async {}

  /// Called when a new critical path is created.
  @protected
  Future<void> onCriticalPathAdded(CalendarCriticalPath path) async {}

  /// Called when a critical path is updated (renamed, tasks added/removed/reordered).
  @protected
  Future<void> onCriticalPathUpdated(CalendarCriticalPath path) async {}

  /// Called when a critical path is deleted.
  @protected
  Future<void> onCriticalPathDeleted(CalendarCriticalPath path) async {}

  /// Called when a full calendar model is imported.
  @protected
  Future<void> onModelImported(CalendarModel model) async {}

  // Abstract methods for subclasses to implement
  Future<void> onTaskAdded(CalendarTask task);
  Future<void> onTaskUpdated(CalendarTask task);
  Future<void> onTaskDeleted(CalendarTask task);
  Future<void> onTaskCompleted(CalendarTask task);
  Future<void> onDayEventAdded(DayEvent event);
  Future<void> onDayEventUpdated(DayEvent event);
  Future<void> onDayEventDeleted(DayEvent event);
  void logError(String message, Object error);
}

bool _isOccurrenceOverrideEmpty(TaskOccurrenceOverride override) {
  final isCancelled = override.isCancelled ?? false;
  return !isCancelled &&
      override.scheduledTime == null &&
      override.duration == null &&
      override.endDate == null &&
      override.priority == null &&
      override.isCompleted == null &&
      override.title == null &&
      override.description == null &&
      override.location == null &&
      (override.checklist == null || override.checklist!.isEmpty) &&
      override.rawProperties.isEmpty &&
      override.rawComponents.isEmpty;
}
