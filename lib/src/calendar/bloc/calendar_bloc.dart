import 'dart:async';
import 'dart:developer' as developer;

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

import 'package:axichat/src/calendar/models/calendar_availability_share_state.dart';
import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/storage/storage_builders.dart';
import 'package:axichat/src/calendar/sync/calendar_availability_share_coordinator.dart';
import 'package:axichat/src/calendar/sync/calendar_sync_manager.dart';
import 'base_calendar_bloc.dart';
import 'calendar_event.dart';
import 'calendar_state.dart';

class CalendarBloc extends BaseCalendarBloc {
  CalendarBloc({
    required CalendarSyncManager Function(CalendarBloc bloc) syncManagerBuilder,
    required super.storage,
    super.storageId = 'state',
    super.reminderController,
    CalendarAvailabilityShareCoordinator? availabilityCoordinator,
    VoidCallback? onDispose,
  })  : _syncManagerBuilder = syncManagerBuilder,
        _availabilityCoordinator = availabilityCoordinator,
        _onDispose = onDispose,
        super(
          storagePrefix: authStoragePrefix,
        ) {
    _syncManager = _syncManagerBuilder(this);
    on<CalendarSyncRequested>(_onCalendarSyncRequested);
    on<CalendarSyncPushed>(_onCalendarSyncPushed);
    on<CalendarRemoteModelApplied>(_onRemoteModelApplied);
    on<CalendarRemoteTaskApplied>(_onRemoteTaskApplied);
  }

  final CalendarSyncManager Function(CalendarBloc bloc) _syncManagerBuilder;
  late final CalendarSyncManager _syncManager;
  final CalendarAvailabilityShareCoordinator? _availabilityCoordinator;
  final VoidCallback? _onDispose;

  @protected
  CalendarAvailabilityShareSource get availabilityShareSource =>
      const CalendarAvailabilityShareSource.personal();

  @override
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
    final bool modelChanged = model.checksum != state.model.checksum;
    super.emitModel(
      model,
      emit,
      selectedDate: selectedDate,
      isLoading: isLoading,
      lastSyncTime: lastSyncTime,
      isSelectionMode: isSelectionMode,
      selectedTaskIds: selectedTaskIds,
      focusedCriticalPathId: focusedCriticalPathId,
      focusedCriticalPathSpecified: focusedCriticalPathSpecified,
    );
    final coordinator = _availabilityCoordinator;
    if (!modelChanged || coordinator == null) {
      return;
    }
    unawaited(
      coordinator.handleModelChanged(
        source: availabilityShareSource,
        model: model,
      ),
    );
  }

  @override
  Future<void> onTaskAdded(CalendarTask task) async {
    try {
      await _syncManager.sendTaskUpdate(task, 'add');
    } catch (error) {
      developer.log('Failed to sync task addition: $error',
          name: 'CalendarBloc');
    }
  }

  @override
  Future<void> onTaskUpdated(CalendarTask task) async {
    try {
      await _syncManager.sendTaskUpdate(task, 'update');
    } catch (error) {
      developer.log('Failed to sync task update: $error', name: 'CalendarBloc');
    }
  }

  @override
  Future<void> onTaskDeleted(CalendarTask task) async {
    try {
      await _syncManager.sendTaskUpdate(task, 'delete');
    } catch (error) {
      developer.log('Failed to sync task deletion: $error',
          name: 'CalendarBloc');
    }
  }

  @override
  Future<void> onTaskCompleted(CalendarTask task) async {
    try {
      await _syncManager.sendTaskUpdate(task, 'update');
    } catch (error) {
      developer.log('Failed to sync task completion: $error',
          name: 'CalendarBloc');
    }
  }

  @override
  Future<void> onDayEventAdded(DayEvent event) async {
    try {
      await _syncManager.sendDayEventUpdate(event, 'add');
    } catch (error) {
      developer.log(
        'Failed to sync day event addition: $error',
        name: 'CalendarBloc',
      );
    }
  }

  @override
  Future<void> onDayEventUpdated(DayEvent event) async {
    try {
      await _syncManager.sendDayEventUpdate(event, 'update');
    } catch (error) {
      developer.log(
        'Failed to sync day event update: $error',
        name: 'CalendarBloc',
      );
    }
  }

  @override
  Future<void> onDayEventDeleted(DayEvent event) async {
    try {
      await _syncManager.sendDayEventUpdate(event, 'delete');
    } catch (error) {
      developer.log(
        'Failed to sync day event deletion: $error',
        name: 'CalendarBloc',
      );
    }
  }

  @override
  Future<void> onCriticalPathsChanged(CalendarModel model) async {
    try {
      await _syncManager.pushFullSync();
    } catch (error) {
      developer.log(
        'Failed to sync critical path change: $error',
        name: 'CalendarBloc',
      );
    }
  }

  @override
  Future<void> onCriticalPathAdded(CalendarCriticalPath path) async {
    try {
      await _syncManager.sendCriticalPathUpdate(path, 'add');
    } catch (error) {
      developer.log(
        'Failed to sync critical path addition: $error',
        name: 'CalendarBloc',
      );
    }
  }

  @override
  Future<void> onCriticalPathUpdated(CalendarCriticalPath path) async {
    try {
      await _syncManager.sendCriticalPathUpdate(path, 'update');
    } catch (error) {
      developer.log(
        'Failed to sync critical path update: $error',
        name: 'CalendarBloc',
      );
    }
  }

  @override
  Future<void> onCriticalPathDeleted(CalendarCriticalPath path) async {
    try {
      await _syncManager.sendCriticalPathUpdate(path, 'delete');
    } catch (error) {
      developer.log(
        'Failed to sync critical path deletion: $error',
        name: 'CalendarBloc',
      );
    }
  }

  @override
  Future<void> onModelImported(CalendarModel model) async {
    try {
      await _syncManager.pushFullSync();
    } catch (error) {
      developer.log(
        'Failed to sync imported calendar: $error',
        name: 'CalendarBloc',
      );
    }
  }

  @override
  void logError(String message, Object error) {
    developer.log(message, name: 'CalendarBloc');
  }

  @override
  Future<void> close() async {
    _onDispose?.call();
    return super.close();
  }

  Future<void> _onCalendarSyncRequested(
    CalendarSyncRequested event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      emit(state.copyWith(isSyncing: true, syncError: null));
      await _syncManager.requestFullSync();
      emit(
        state.copyWith(
          isSyncing: false,
          lastSyncTime: DateTime.now(),
        ),
      );
    } catch (error) {
      developer.log('Error requesting sync: $error', name: 'CalendarBloc');
      emit(
        state.copyWith(
          isSyncing: false,
          syncError: 'Sync request failed: $error',
        ),
      );
    }
  }

  Future<void> _onCalendarSyncPushed(
    CalendarSyncPushed event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      emit(state.copyWith(isSyncing: true, syncError: null));
      await _syncManager.pushFullSync();
      emit(
        state.copyWith(
          isSyncing: false,
          lastSyncTime: DateTime.now(),
        ),
      );
    } catch (error) {
      developer.log('Error pushing sync: $error', name: 'CalendarBloc');
      emit(
        state.copyWith(
          isSyncing: false,
          syncError: 'Sync push failed: $error',
        ),
      );
    }
  }

  Future<void> _onRemoteModelApplied(
    CalendarRemoteModelApplied event,
    Emitter<CalendarState> emit,
  ) async {
    emitModel(event.model, emit, lastSyncTime: DateTime.now());
  }

  Future<void> _onRemoteTaskApplied(
    CalendarRemoteTaskApplied event,
    Emitter<CalendarState> emit,
  ) async {
    switch (event.operation) {
      case 'add':
      case 'update':
        emitModel(
          state.model.updateTask(event.task),
          emit,
          lastSyncTime: DateTime.now(),
        );
      case 'delete':
        emitModel(
          state.model.deleteTask(event.task.id),
          emit,
          lastSyncTime: DateTime.now(),
        );
      default:
        developer.log('Unknown remote operation: ${event.operation}',
            name: 'CalendarBloc');
        return;
    }
  }

  CalendarModel get currentModel => state.model;
}
