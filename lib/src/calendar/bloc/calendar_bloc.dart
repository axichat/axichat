import 'dart:developer' as developer;

import 'package:bloc/bloc.dart';

import '../models/calendar_task.dart';
import '../sync/calendar_sync_manager.dart';
import 'base_calendar_bloc.dart';
import 'calendar_event.dart';
import 'calendar_state.dart';

class CalendarBloc extends BaseCalendarBloc {
  CalendarBloc({
    required super.calendarBox,
    required CalendarSyncManager syncManager,
  }) : _syncManager = syncManager {
    on<CalendarSyncRequested>(_onCalendarSyncRequested);
    on<CalendarSyncPushed>(_onCalendarSyncPushed);
  }

  final CalendarSyncManager _syncManager;

  @override
  Future<void> onTaskAdded(CalendarTask task) async {
    try {
      await _syncManager.sendTaskUpdate(task, 'add');
    } catch (e) {
      developer.log('Failed to sync task addition: $e', name: 'CalendarBloc');
    }
  }

  @override
  Future<void> onTaskUpdated(CalendarTask task) async {
    try {
      await _syncManager.sendTaskUpdate(task, 'update');
    } catch (e) {
      developer.log('Failed to sync task update: $e', name: 'CalendarBloc');
    }
  }

  @override
  Future<void> onTaskDeleted(CalendarTask task) async {
    try {
      await _syncManager.sendTaskUpdate(task, 'delete');
    } catch (e) {
      developer.log('Failed to sync task deletion: $e', name: 'CalendarBloc');
    }
  }

  @override
  Future<void> onTaskCompleted(CalendarTask task) async {
    try {
      await _syncManager.sendTaskUpdate(task, 'update');
    } catch (e) {
      developer.log('Failed to sync task completion: $e', name: 'CalendarBloc');
    }
  }

  @override
  void logError(String message, Object error) {
    developer.log(message, name: 'CalendarBloc');
  }

  Future<void> _onCalendarSyncRequested(
      CalendarSyncRequested event, Emitter<CalendarState> emit) async {
    try {
      emit(state.copyWith(isSyncing: true, syncError: null));

      await _syncManager.requestFullSync();

      emit(state.copyWith(
        isSyncing: false,
        lastSyncTime: DateTime.now(),
      ));
    } catch (e) {
      final error = 'Sync request failed: $e';
      developer.log('Error requesting sync: $e', name: 'CalendarBloc');
      emit(state.copyWith(
        isSyncing: false,
        syncError: error,
      ));
    }
  }

  Future<void> _onCalendarSyncPushed(
      CalendarSyncPushed event, Emitter<CalendarState> emit) async {
    try {
      emit(state.copyWith(isSyncing: true, syncError: null));

      await _syncManager.pushFullSync();

      emit(state.copyWith(
        isSyncing: false,
        lastSyncTime: DateTime.now(),
      ));
    } catch (e) {
      final error = 'Sync push failed: $e';
      developer.log('Error pushing sync: $e', name: 'CalendarBloc');
      emit(state.copyWith(
        isSyncing: false,
        syncError: error,
      ));
    }
  }
}
