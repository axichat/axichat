// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:axichat/src/calendar/models/calendar_availability.dart';
import 'package:axichat/src/calendar/models/calendar_availability_share_state.dart';
import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_date_time.dart';
import 'package:axichat/src/calendar/models/calendar_fragment.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/storage/calendar_linked_task_registry.dart';
import 'package:axichat/src/calendar/storage/storage_builders.dart';
import 'package:axichat/src/calendar/sync/calendar_availability_share_coordinator.dart';
import 'package:axichat/src/calendar/sync/calendar_sync_manager.dart';
import 'package:axichat/src/calendar/sync/chat_calendar_identifiers.dart';
import 'package:axichat/src/calendar/utils/calendar_fragment_policy.dart';
import 'package:axichat/src/calendar/utils/calendar_transfer_service.dart';
import 'package:axichat/src/common/safe_logging.dart';
import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/service/fan_out_models.dart';
import 'package:axichat/src/storage/models/chat_models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'base_calendar_bloc.dart';
import 'calendar_event.dart';
import 'calendar_state.dart';

class CalendarBloc extends BaseCalendarBloc {
  CalendarBloc({
    required CalendarSyncManager Function(CalendarBloc bloc) syncManagerBuilder,
    required super.storage,
    super.storageId,
    super.reminderController,
    CalendarAvailabilityShareCoordinator? availabilityCoordinator,
    required XmppService xmppService,
    EmailService? emailService,
    VoidCallback? onDispose,
  })  : _syncManagerBuilder = syncManagerBuilder,
        _availabilityCoordinator = availabilityCoordinator,
        _xmppService = xmppService,
        _emailService = emailService,
        _onDispose = onDispose,
        super(storagePrefix: authStoragePrefix) {
    _syncManager = _syncManagerBuilder(this);
    on<CalendarSyncRequested>(_onCalendarSyncRequested);
    on<CalendarSyncPushed>(_onCalendarSyncPushed);
    on<CalendarRemoteModelApplied>(_onRemoteModelApplied);
    on<CalendarRemoteTaskApplied>(_onRemoteTaskApplied);
    on<CalendarTaskShareRequested>(_onCalendarTaskShareRequested);
    on<CalendarCriticalPathShareRequested>(
        _onCalendarCriticalPathShareRequested);
    on<CalendarAvailabilityShareRequested>(
        _onCalendarAvailabilityShareRequested);
  }

  final CalendarSyncManager Function(CalendarBloc bloc) _syncManagerBuilder;
  late final CalendarSyncManager _syncManager;
  final CalendarAvailabilityShareCoordinator? _availabilityCoordinator;
  final XmppService _xmppService;
  final EmailService? _emailService;
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
    Future<void>(() async {
      await coordinator.handleModelChanged(
        source: availabilityShareSource,
        model: model,
      );
    });
  }

  @override
  Future<void> onTaskAdded(CalendarTask task) async {
    try {
      await _syncManager.sendTaskUpdate(task, 'add');
    } catch (error) {
      SafeLogging.debugLog(
        'Failed to sync task addition: $error',
        name: 'CalendarBloc',
      );
    }
  }

  @override
  Future<void> onTaskUpdated(CalendarTask task) async {
    try {
      await _syncManager.sendTaskUpdate(task, 'update');
    } catch (error) {
      SafeLogging.debugLog(
        'Failed to sync task update: $error',
        name: 'CalendarBloc',
      );
    }
  }

  @override
  Future<void> onTaskDeleted(CalendarTask task) async {
    try {
      await _syncManager.sendTaskUpdate(task, 'delete');
    } catch (error) {
      SafeLogging.debugLog(
        'Failed to sync task deletion: $error',
        name: 'CalendarBloc',
      );
    }
  }

  @override
  Future<void> onTaskCompleted(CalendarTask task) async {
    try {
      await _syncManager.sendTaskUpdate(task, 'update');
    } catch (error) {
      SafeLogging.debugLog(
        'Failed to sync task completion: $error',
        name: 'CalendarBloc',
      );
    }
  }

  @override
  Future<void> onDayEventAdded(DayEvent event) async {
    try {
      await _syncManager.sendDayEventUpdate(event, 'add');
    } catch (error) {
      SafeLogging.debugLog(
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
      SafeLogging.debugLog(
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
      SafeLogging.debugLog(
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
      SafeLogging.debugLog(
        'Failed to sync critical path change: $error',
        name: 'CalendarBloc',
      );
    }
  }

  @override
  Future<void> onAvailabilityChanged(CalendarModel model) async {
    try {
      await _syncManager.pushFullSync();
    } catch (error) {
      SafeLogging.debugLog(
        'Failed to sync availability change: $error',
        name: 'CalendarBloc',
      );
    }
  }

  @override
  Future<void> onCriticalPathAdded(CalendarCriticalPath path) async {
    try {
      await _syncManager.sendCriticalPathUpdate(path, 'add');
    } catch (error) {
      SafeLogging.debugLog(
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
      SafeLogging.debugLog(
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
      SafeLogging.debugLog(
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
      SafeLogging.debugLog(
        'Failed to sync imported calendar: $error',
        name: 'CalendarBloc',
      );
    }
  }

  @override
  void logError(String message, Object error) {
    SafeLogging.debugLog(message, name: 'CalendarBloc');
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
      emit(state.copyWith(isSyncing: false, lastSyncTime: DateTime.now()));
    } catch (error) {
      SafeLogging.debugLog(
        'Error requesting sync: $error',
        name: 'CalendarBloc',
      );
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
      emit(state.copyWith(isSyncing: false, lastSyncTime: DateTime.now()));
    } catch (error) {
      SafeLogging.debugLog('Error pushing sync: $error', name: 'CalendarBloc');
      emit(
        state.copyWith(isSyncing: false, syncError: 'Sync push failed: $error'),
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
        await propagateLinkedTaskUpdate(event.task);
      case 'delete':
        emitModel(
          state.model.deleteTask(event.task.id),
          emit,
          lastSyncTime: DateTime.now(),
        );
        await propagateLinkedTaskDelete(event.task);
      default:
        SafeLogging.debugLog(
          'Unknown remote operation: ${event.operation}',
          name: 'CalendarBloc',
        );
        return;
    }
  }

  Future<void> _onCalendarTaskShareRequested(
    CalendarTaskShareRequested event,
    Emitter<CalendarState> emit,
  ) async {
    final completer = event.completer;
    if (completer.isCompleted) {
      return;
    }
    try {
      final recipients = event.recipients;
      final emailTargets = recipients
          .where(
            (target) =>
                target.chat == null ||
                target.chat?.defaultTransport.isEmail == true,
          )
          .toList(growable: false);
      final xmppChats = recipients
          .map((target) => target.chat)
          .whereType<Chat>()
          .where((chat) => !chat.defaultTransport.isEmail)
          .toList(growable: false);
      final emailService = _emailService;
      if (emailTargets.isNotEmpty && emailService == null) {
        completer.complete(
          const CalendarShareResult.failure(
            CalendarShareFailure.serviceUnavailable,
          ),
        );
        return;
      }
      if (xmppChats.isNotEmpty) {
        for (final chat in xmppChats) {
          final decision = const CalendarFragmentPolicy().decisionForChat(
            chat: chat,
            roomState: _xmppService.roomStateFor(chat.jid),
          );
          if (!decision.canWrite) {
            completer.complete(
              const CalendarShareResult.failure(
                CalendarShareFailure.permissionDenied,
              ),
            );
            return;
          }
        }
      }
      if (emailTargets.isNotEmpty) {
        final attachment = await _buildCalendarTaskAttachment(event.task);
        if (attachment == null) {
          completer.complete(
            const CalendarShareResult.failure(
              CalendarShareFailure.attachmentFailed,
            ),
          );
          return;
        }
        final resolvedAttachment = attachment.copyWith(
          caption: event.shareText,
        );
        await emailService!.fanOutSend(
          targets: emailTargets,
          attachment: resolvedAttachment,
        );
      }
      if (xmppChats.isNotEmpty) {
        for (final chat in xmppChats) {
          await _xmppService.sendMessage(
            jid: chat.jid,
            text: event.shareText,
            encryptionProtocol: chat.encryptionProtocol,
            calendarTaskIcs: event.task,
            calendarTaskIcsReadOnly: event.readOnly,
            chatType: chat.type,
          );
          if (!event.readOnly) {
            await _linkSharedTask(chat: chat, taskId: event.task.id);
          }
        }
      }
      completer.complete(const CalendarShareResult.success());
    } catch (_) {
      if (!completer.isCompleted) {
        completer.complete(
          const CalendarShareResult.failure(CalendarShareFailure.sendFailed),
        );
      }
    }
  }

  Future<void> _onCalendarCriticalPathShareRequested(
    CalendarCriticalPathShareRequested event,
    Emitter<CalendarState> emit,
  ) async {
    final completer = event.completer;
    if (completer.isCompleted) {
      return;
    }
    try {
      final recipient = event.recipient;
      final decision = const CalendarFragmentPolicy().decisionForChat(
        chat: recipient,
        roomState: _xmppService.roomStateFor(recipient.jid),
      );
      if (!decision.canWrite) {
        completer.complete(
          const CalendarShareResult.failure(
            CalendarShareFailure.permissionDenied,
          ),
        );
        return;
      }
      await _xmppService.sendMessage(
        jid: recipient.jid,
        text: event.shareText,
        encryptionProtocol: recipient.encryptionProtocol,
        calendarFragment: event.fragment,
        chatType: recipient.type,
      );
      completer.complete(const CalendarShareResult.success());
    } catch (_) {
      if (!completer.isCompleted) {
        completer.complete(
          const CalendarShareResult.failure(CalendarShareFailure.sendFailed),
        );
      }
    }
  }

  Future<void> _onCalendarAvailabilityShareRequested(
    CalendarAvailabilityShareRequested event,
    Emitter<CalendarState> emit,
  ) async {
    final completer = event.completer;
    if (completer.isCompleted) {
      return;
    }
    final coordinator = _availabilityCoordinator;
    if (coordinator == null) {
      completer.complete(
        const CalendarShareResult.failure(
          CalendarShareFailure.serviceUnavailable,
        ),
      );
      return;
    }
    var failures = 0;
    CalendarAvailabilityShareRecord? latestRecord;
    try {
      for (final chat in event.recipients) {
        final resolvedOwner = _resolveAvailabilityOwnerJid(
          chat: chat,
          ownerJid: event.ownerJid,
        );
        if (resolvedOwner == null || resolvedOwner.isEmpty) {
          failures += 1;
          continue;
        }
        final record = await coordinator.createShare(
          source: event.source,
          model: event.model,
          ownerJid: resolvedOwner,
          chatJid: chat.jid,
          chatType: chat.type,
          rangeStart: event.rangeStart,
          rangeEnd: event.rangeEnd,
          overrideOverlay: event.overrideOverlay,
          lockOverlay: event.lockOverlay,
        );
        if (record == null) {
          failures += 1;
          continue;
        }
        latestRecord = record;
      }
    } catch (_) {
      if (!completer.isCompleted) {
        completer.complete(
          const CalendarShareResult.failure(CalendarShareFailure.sendFailed),
        );
      }
      return;
    }
    if (latestRecord == null) {
      completer.complete(
        const CalendarShareResult.failure(CalendarShareFailure.sendFailed),
      );
      return;
    }
    completer.complete(
      CalendarShareResult.success(
        partialFailure: failures > 0,
        record: latestRecord,
      ),
    );
  }

  Future<EmailAttachment?> _buildCalendarTaskAttachment(
    CalendarTask task,
  ) async {
    try {
      final transferService = CalendarTransferService();
      final File file = await transferService.exportTaskIcs(task: task);
      CalendarTransferService.scheduleCleanup(file);
      final int sizeBytes = await file.length();
      const String calendarIcsMimeType = 'text/calendar';
      return EmailAttachment(
        path: file.path,
        fileName: file.uri.pathSegments.last,
        sizeBytes: sizeBytes,
        mimeType: calendarIcsMimeType,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _linkSharedTask({
    required Chat chat,
    required String taskId,
  }) async {
    if (!chat.supportsChatCalendar) {
      return;
    }
    final String trimmedTaskId = taskId.trim();
    if (trimmedTaskId.isEmpty) {
      return;
    }
    final String chatStorageId = chatCalendarStorageId(chat.jid);
    final Set<String> storageIds = <String>{id, chatStorageId};
    if (storageIds.length < 2) {
      return;
    }
    await CalendarLinkedTaskRegistry.instance.addLinks(
      taskId: trimmedTaskId,
      storageIds: storageIds,
    );
  }

  String? _resolveAvailabilityOwnerJid({
    required Chat chat,
    required String ownerJid,
  }) {
    final String trimmedOwner = ownerJid.trim();
    if (trimmedOwner.isEmpty) {
      return null;
    }
    if (chat.type != ChatType.groupChat) {
      return trimmedOwner;
    }
    final String? occupantId =
        _xmppService.roomStateFor(chat.jid)?.myOccupantId?.trim();
    if (occupantId == null || occupantId.isEmpty) {
      return null;
    }
    return occupantId;
  }

  CalendarModel get currentModel => state.model;
}
