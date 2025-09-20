import 'dart:developer' as developer;

import 'package:hydrated_bloc/hydrated_bloc.dart';

import '../models/calendar_model.dart';
import '../models/calendar_task.dart';
import '../reminders/calendar_reminder_controller.dart';
import '../storage/storage_builders.dart';
import '../sync/calendar_sync_manager.dart';
import 'base_calendar_bloc.dart';
import 'calendar_event.dart';
import 'calendar_state.dart';

class CalendarBloc extends BaseCalendarBloc {
  CalendarBloc({
    required CalendarSyncManager Function(CalendarBloc bloc) syncManagerBuilder,
    CalendarReminderController? reminderController,
  })  : _syncManagerBuilder = syncManagerBuilder,
        super(
          storagePrefix: authStoragePrefix,
          storageId: 'state',
          reminderController: reminderController,
        ) {
    _syncManager = _syncManagerBuilder(this);
    on<CalendarSyncRequested>(_onCalendarSyncRequested);
    on<CalendarSyncPushed>(_onCalendarSyncPushed);
    on<CalendarRemoteModelApplied>(_onRemoteModelApplied);
    on<CalendarRemoteTaskApplied>(_onRemoteTaskApplied);
  }

  final CalendarSyncManager Function(CalendarBloc bloc) _syncManagerBuilder;
  late final CalendarSyncManager _syncManager;

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
  void logError(String message, Object error) {
    developer.log(message, name: 'CalendarBloc');
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

  void _onRemoteModelApplied(
    CalendarRemoteModelApplied event,
    Emitter<CalendarState> emit,
  ) {
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
