// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:axichat/src/calendar/models/calendar_availability_share_state.dart';
import 'package:axichat/src/calendar/models/calendar_availability_message.dart';
import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_sync_message.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/storage/chat_calendar_storage.dart';
import 'package:axichat/src/calendar/storage/storage_builders.dart';
import 'package:axichat/src/calendar/sync/calendar_availability_share_coordinator.dart';
import 'package:axichat/src/calendar/sync/calendar_availability_share_store.dart';
import 'package:axichat/src/calendar/sync/calendar_sync_manager.dart';
import 'package:axichat/src/calendar/sync/calendar_snapshot_codec.dart';
import 'package:axichat/src/calendar/sync/calendar_sync_state.dart';
import 'package:axichat/src/calendar/sync/chat_calendar_sync_envelope.dart';
import 'package:axichat/src/calendar/sync/chat_calendar_sync_coordinator.dart';
import 'package:axichat/src/calendar/interop/calendar_transfer_service.dart';
import 'package:axichat/src/common/compose_recipient.dart';
import 'package:axichat/src/common/safe_logging.dart';
import 'package:axichat/src/common/file_metadata_tools.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/demo/demo_mode.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/storage/models/chat_models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'base_calendar_bloc.dart';
import 'calendar_event.dart';
import 'calendar_state.dart';

CalendarSyncManager buildPersonalCalendarSyncManager(CalendarBloc owner) {
  return CalendarSyncManager(
    readModel: () => owner.currentModel,
    applyModel: owner._applySyncedPersonalCalendarModel,
    sendCalendarMessage: owner.sendPersonalCalendarSync,
    publishCalendarSnapshot: owner.publishPersonalCalendarSnapshot,
    refreshCalendarSnapshot: owner.syncPersonalCalendarSnapshot,
    onSnapshotPublishStatusChanged: owner._handleSnapshotPublishStatus,
  );
}

class CalendarBloc extends BaseCalendarBloc {
  CalendarBloc({
    required CalendarSyncManager Function(CalendarBloc owner)
    syncManagerBuilder,
    required Storage storage,
    super.storageId,
    super.reminderController,
    CalendarAvailabilityShareCoordinator? availabilityCoordinator,
    required XmppService xmppService,
    EmailService? emailService,
    VoidCallback? onDispose,
  }) : _syncManagerBuilder = syncManagerBuilder,
       _availabilityCoordinator = availabilityCoordinator,
       _xmppService = xmppService,
       _emailService = emailService,
       _onDispose = onDispose,
       super(storage: storage, storagePrefix: authStoragePrefix) {
    _syncManager = _syncManagerBuilder(this);
    _calendarSyncFlushCallback = _syncManager.flushPending;
    _xmppService.registerCalendarSyncFlushCallback(_calendarSyncFlushCallback);
    _attachCalendarSyncSubscriptions();
    _configureHomeCoordinators(storage: storage);
    on<CalendarSyncRequested>(_onCalendarSyncRequested);
    on<CalendarSyncPushed>(_onCalendarSyncPushed);
    on<CalendarRemoteModelApplied>(_onRemoteModelApplied);
    on<CalendarRemoteTaskApplied>(_onRemoteTaskApplied);
    on<CalendarTaskShareRequested>(_onCalendarTaskShareRequested);
    on<CalendarCriticalPathShareRequested>(
      _onCalendarCriticalPathShareRequested,
    );
    on<CalendarAvailabilityShareRequested>(
      _onCalendarAvailabilityShareRequested,
    );
  }

  final CalendarSyncManager Function(CalendarBloc owner) _syncManagerBuilder;
  late final CalendarSyncManager _syncManager;
  CalendarAvailabilityShareCoordinator? _availabilityCoordinator;
  ChatCalendarSyncCoordinator? _chatCalendarCoordinator;
  Storage? _chatCalendarStorage;
  Future<void> _pendingAvailabilitySync = Future.value();
  final XmppService _xmppService;
  EmailService? _emailService;
  final VoidCallback? _onDispose;
  StreamSubscription<CalendarSyncDispatch>? _calendarSyncSubscription;
  StreamSubscription<ChatCalendarSyncDispatch>? _chatCalendarSyncSubscription;
  StreamSubscription<PersonalCalendarSnapshotSyncSignal>?
  _personalCalendarSnapshotSubscription;
  StreamSubscription<CalendarSyncWarning>? _calendarSyncWarningSubscription;
  Future<void> _pendingCalendarDispatch = Future<void>.value();
  Future<void> _pendingChatCalendarDispatch = Future<void>.value();
  Future<void> _pendingPersonalCalendarSnapshotDispatch = Future<void>.value();
  late final Future<void> Function() _calendarSyncFlushCallback;

  void updateEmailService(EmailService? emailService) {
    _emailService = emailService;
  }

  @protected
  CalendarAvailabilityShareSource get availabilityShareSource =>
      const CalendarAvailabilityShareSource.personal();

  ChatCalendarSyncCoordinator? get chatCalendarCoordinator =>
      _chatCalendarCoordinator;

  CalendarAvailabilityShareCoordinator? get availabilityCoordinator =>
      _availabilityCoordinator;

  String? get accountJid => _xmppService.myJid;

  void _configureHomeCoordinators({required Storage storage}) {
    if (_chatCalendarStorage == storage &&
        _chatCalendarCoordinator != null &&
        _availabilityCoordinator != null) {
      _ensureChatCalendarSyncSubscription();
      return;
    }
    _chatCalendarStorage = storage;
    _chatCalendarCoordinator = ChatCalendarSyncCoordinator(
      storage: ChatCalendarStorage(storage: storage),
      sendMessage:
          ({
            required String jid,
            required CalendarSyncOutbound outbound,
            required ChatType chatType,
          }) {
            return sendCalendarSyncMessage(
              jid: jid,
              outbound: outbound,
              chatType: chatType,
            );
          },
      applyPrimaryView:
          ({required String chatJid, required ChatPrimaryView primaryView}) {
            return _xmppService.applyRoomPrimaryView(
              roomJid: chatJid,
              primaryView: primaryView,
            );
          },
      sendSnapshotFile: uploadCalendarSnapshot,
    );
    final availabilityCoordinator = CalendarAvailabilityShareCoordinator(
      store: CalendarAvailabilityShareStore(),
      sendMessage:
          ({
            required String jid,
            required CalendarAvailabilityMessage message,
            required ChatType chatType,
          }) {
            return sendAvailabilityMessage(
              jid: jid,
              message: message,
              chatType: chatType,
            );
          },
    );
    attachAvailabilityCoordinator(availabilityCoordinator);
    _ensureChatCalendarSyncSubscription();
  }

  void attachAvailabilityCoordinator(
    CalendarAvailabilityShareCoordinator coordinator,
  ) {
    if (_availabilityCoordinator == coordinator) return;
    _availabilityCoordinator = coordinator;
    final model = state.model;
    _queueAvailabilitySync(coordinator, model);
  }

  Future<void> sendCalendarSyncMessage({
    required String jid,
    required CalendarSyncOutbound outbound,
    required ChatType chatType,
  }) async {
    await _xmppService.sendCalendarSyncMessage(
      jid: jid,
      outbound: outbound,
      chatType: chatType,
    );
  }

  Future<void> sendPersonalCalendarSync(CalendarSyncOutbound outbound) async {
    final jid = _xmppService.myJid;
    if (jid == null) {
      return;
    }
    await sendCalendarSyncMessage(
      jid: jid,
      outbound: outbound,
      chatType: ChatType.chat,
    );
  }

  Future<CalendarSnapshotPublishStatus> publishPersonalCalendarSnapshot(
    CalendarModel model,
  ) {
    return _xmppService.publishPersonalCalendarSnapshot(
      readModel: () =>
          currentModel.checksum == model.checksum ? model : currentModel,
      applyModel: _applySyncedPersonalCalendarModel,
      onSnapshotPublishStatusChanged: _handleSnapshotPublishStatus,
    );
  }

  Future<bool> syncPersonalCalendarSnapshot() async {
    final status = await _syncPersonalCalendarSnapshotStatus();
    return status == CalendarSnapshotPublishStatus.idle;
  }

  Future<CalendarSnapshotPublishStatus> _syncPersonalCalendarSnapshotStatus({
    bool publishIfChanged = true,
  }) {
    return _xmppService.syncPersonalCalendarSnapshot(
      readModel: () => currentModel,
      applyModel: _applySyncedPersonalCalendarModel,
      publishIfChanged: publishIfChanged,
      onSnapshotPublishStatusChanged: _handleSnapshotPublishStatus,
    );
  }

  Future<CalendarSnapshotPublishStatus> _bootstrapPersonalCalendarSnapshot() {
    return _xmppService.bootstrapPersonalCalendarSnapshot(
      readModel: () => currentModel,
      applyModel: _applySyncedPersonalCalendarModel,
      onSnapshotPublishStatusChanged: _handleSnapshotPublishStatus,
    );
  }

  Future<void> _applySyncedPersonalCalendarModel(CalendarModel model) async {
    if (currentModel.checksum == model.checksum) {
      return;
    }
    add(CalendarEvent.remoteModelApplied(model: model));
    await stream
        .firstWhere((state) => state.model.checksum == model.checksum)
        .timeout(const Duration(seconds: 5));
  }

  Future<void> sendAvailabilityMessage({
    required String jid,
    required CalendarAvailabilityMessage message,
    required ChatType chatType,
  }) async {
    await _xmppService.sendAvailabilityMessage(
      jid: jid,
      message: message,
      chatType: chatType,
    );
  }

  Future<CalendarSnapshotUploadResult> uploadCalendarSnapshot(File file) {
    return _xmppService.uploadCalendarSnapshot(file);
  }

  Future<void> _handleSnapshotPublishStatus(
    CalendarSnapshotPublishStatus status,
  ) async {
    switch (status) {
      case CalendarSnapshotPublishStatus.idle:
        return;
      case CalendarSnapshotPublishStatus.pending:
        add(
          const CalendarEvent.syncWarningRaised(
            warning: CalendarSyncWarning(
              type: CalendarSyncWarningType.snapshotPublishPending,
            ),
          ),
        );
        return;
      case CalendarSnapshotPublishStatus.blocked:
        add(
          const CalendarEvent.syncWarningRaised(
            warning: CalendarSyncWarning(
              type: CalendarSyncWarningType.snapshotPublishBlocked,
            ),
          ),
        );
        return;
    }
  }

  void _attachCalendarSyncSubscriptions() {
    _ensureCalendarSyncSubscriptions();
  }

  void _ensureCalendarSyncSubscriptions() {
    if (_calendarSyncSubscription != null &&
        _personalCalendarSnapshotSubscription != null &&
        _calendarSyncWarningSubscription != null) {
      return;
    }
    _calendarSyncSubscription ??= _xmppService.calendarSyncDispatchStream
        .listen((dispatch) {
          _pendingCalendarDispatch = _pendingCalendarDispatch.then((_) async {
            try {
              final applied = await _syncManager.onCalendarMessage(
                dispatch.inbound,
              );
              dispatch.complete(applied);
            } catch (error, stackTrace) {
              dispatch.completeError(error, stackTrace);
            }
          });
        });
    _personalCalendarSnapshotSubscription ??= _xmppService
        .personalCalendarSnapshotStream
        .listen((signal) {
          _pendingPersonalCalendarSnapshotDispatch =
              _pendingPersonalCalendarSnapshotDispatch.then((_) async {
                try {
                  final status = await _handlePersonalCalendarSnapshotSignal(
                    signal,
                  );
                  signal.complete(status);
                } catch (error, stackTrace) {
                  signal.completeError(error, stackTrace);
                  SafeLogging.debugLog(
                    'Failed to sync personal calendar snapshot: $error',
                    name: 'CalendarBloc',
                  );
                }
              });
        });
    _calendarSyncWarningSubscription ??= _xmppService.calendarSyncWarningStream
        .listen((warning) {
          add(CalendarEvent.syncWarningRaised(warning: warning));
        });
    final pendingWarning = _xmppService.takePendingCalendarSyncWarning();
    if (pendingWarning != null) {
      add(CalendarEvent.syncWarningRaised(warning: pendingWarning));
    }
  }

  Future<CalendarSnapshotPublishStatus> _handlePersonalCalendarSnapshotSignal(
    PersonalCalendarSnapshotSyncSignal signal,
  ) {
    return switch (signal.kind) {
      PersonalCalendarSnapshotSyncSignalKind.bootstrap =>
        _bootstrapPersonalCalendarSnapshot(),
      PersonalCalendarSnapshotSyncSignalKind.refresh =>
        _syncPersonalCalendarSnapshotStatus(),
      PersonalCalendarSnapshotSyncSignalKind.publish =>
        publishPersonalCalendarSnapshot(currentModel),
    };
  }

  void _ensureChatCalendarSyncSubscription() {
    final coordinator = _chatCalendarCoordinator;
    if (coordinator == null) {
      return;
    }
    if (_chatCalendarSyncSubscription != null) {
      return;
    }
    _chatCalendarSyncSubscription ??= _xmppService
        .chatCalendarSyncDispatchStream
        .listen((dispatch) {
          _pendingChatCalendarDispatch = _pendingChatCalendarDispatch.then((
            _,
          ) async {
            try {
              final applied = await coordinator.handleInbound(
                dispatch.envelope,
              );
              dispatch.complete(applied);
            } catch (error, stackTrace) {
              dispatch.completeError(error, stackTrace);
            }
          });
        });
  }

  @override
  void emitModel(
    CalendarModel model,
    Emitter<CalendarState> emit, {
    DateTime? selectedDate,
    String? error,
    bool? isLoading,
    DateTime? lastSyncTime,
    bool? isSelectionMode,
    Set<String>? selectedTaskIds,
    String? focusedCriticalPathId,
    bool focusedCriticalPathSpecified = false,
    bool? isTaskCreationSubmitting,
    String? taskCreationError,
    String? lastCreatedTaskId,
    String? importError,
    List<String>? lastImportedTaskIds,
    String? lastImportedModelChecksum,
    bool? isCriticalPathMutating,
    String? criticalPathMutationError,
    String? lastCreatedCriticalPathId,
    String? lastCriticalPathTaskAddedPathId,
    String? lastCriticalPathTaskAddedTaskId,
  }) {
    final bool modelChanged = model.checksum != state.model.checksum;
    super.emitModel(
      model,
      emit,
      selectedDate: selectedDate,
      error: error,
      isLoading: isLoading,
      lastSyncTime: lastSyncTime,
      isSelectionMode: isSelectionMode,
      selectedTaskIds: selectedTaskIds,
      focusedCriticalPathId: focusedCriticalPathId,
      focusedCriticalPathSpecified: focusedCriticalPathSpecified,
      isTaskCreationSubmitting: isTaskCreationSubmitting,
      taskCreationError: taskCreationError,
      lastCreatedTaskId: lastCreatedTaskId,
      importError: importError,
      lastImportedTaskIds: lastImportedTaskIds,
      lastImportedModelChecksum: lastImportedModelChecksum,
      isCriticalPathMutating: isCriticalPathMutating,
      criticalPathMutationError: criticalPathMutationError,
      lastCreatedCriticalPathId: lastCreatedCriticalPathId,
      lastCriticalPathTaskAddedPathId: lastCriticalPathTaskAddedPathId,
      lastCriticalPathTaskAddedTaskId: lastCriticalPathTaskAddedTaskId,
    );
    final coordinator = _availabilityCoordinator;
    if (!modelChanged || coordinator == null) {
      return;
    }
    _queueAvailabilitySync(coordinator, model);
  }

  void _queueAvailabilitySync(
    CalendarAvailabilityShareCoordinator coordinator,
    CalendarModel model,
  ) {
    _pendingAvailabilitySync = _pendingAvailabilitySync.then((_) async {
      try {
        await coordinator.handleModelChanged(
          source: availabilityShareSource,
          model: model,
        );
      } catch (error) {
        SafeLogging.debugLog(
          'Failed to sync availability share: $error',
          name: 'CalendarBloc',
        );
      }
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
      _recordSyncTimestamp();
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
    _xmppService.unregisterCalendarSyncFlushCallback(
      _calendarSyncFlushCallback,
    );
    try {
      await _syncManager.flushPending();
    } catch (error) {
      SafeLogging.debugLog(
        'Failed to flush pending calendar sync before close: $error',
        name: 'CalendarBloc',
      );
    } finally {
      await _calendarSyncSubscription?.cancel();
      await _personalCalendarSnapshotSubscription?.cancel();
      await _chatCalendarSyncSubscription?.cancel();
      await _calendarSyncWarningSubscription?.cancel();
      await _pendingCalendarDispatch;
      await _pendingPersonalCalendarSnapshotDispatch;
      await _pendingChatCalendarDispatch;
    }
    return super.close();
  }

  void _recordSyncTimestamp() {
    add(const CalendarEvent.syncTimestampRecorded());
  }

  Future<void> _onCalendarSyncRequested(
    CalendarSyncRequested event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      emit(state.copyWith(isSyncing: true, syncError: null));
      await _syncManager.requestFullSync();
      emit(state.copyWith(isSyncing: false, lastSyncTime: nextSyncTimestamp()));
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
      emit(state.copyWith(isSyncing: false, lastSyncTime: nextSyncTimestamp()));
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
    emitModel(event.model, emit, lastSyncTime: nextSyncTimestamp());
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
          lastSyncTime: nextSyncTimestamp(),
        );
        await propagateLinkedTaskUpdate(event.task);
      case 'delete':
        emitModel(
          state.model.deleteTask(event.task.id),
          emit,
          lastSyncTime: nextSyncTimestamp(),
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
      if (recipients.isEmpty) {
        completer.complete(
          const CalendarShareResult.failure(CalendarShareFailure.sendFailed),
        );
        return;
      }
      final shareText = _calendarTaskShareText(event.task, event.shareText);
      final emailTargets = <EmailRecipientIntent>[];
      final xmppChats = <Chat>[];
      for (final target in recipients) {
        final chat = target.chat;
        if (chat != null && !chat.defaultTransport.isEmail) {
          xmppChats.add(chat);
          continue;
        }
        final intent = ComposerRecipient(
          target: target,
        ).forcedEmailIntent(emailDomain: null);
        if (intent == null) {
          completer.complete(
            const CalendarShareResult.failure(CalendarShareFailure.sendFailed),
          );
          return;
        }
        emailTargets.add(intent);
      }
      final emailService = _emailService;
      final demoOfflineTaskShare =
          kEnableDemoChats && _xmppService.demoOfflineMode;
      if (emailTargets.isNotEmpty &&
          emailService == null &&
          !demoOfflineTaskShare) {
        completer.complete(
          const CalendarShareResult.failure(
            CalendarShareFailure.serviceUnavailable,
          ),
        );
        return;
      }
      if (demoOfflineTaskShare) {
        await _sendDemoTaskShare(
          recipients: recipients,
          task: event.task,
          shareText: shareText,
        );
        completer.complete(const CalendarShareResult.success());
        return;
      }
      final envelopeChats = <Chat>[];
      final attachmentChats = <Chat>[];
      for (final chat in xmppChats) {
        if (!_xmppService.canUseCalendarSyncWithJid(
          jid: chat.remoteJid,
          chatType: chat.type,
        )) {
          attachmentChats.add(chat);
          continue;
        }
        final decision = _xmppService.calendarFragmentDecisionForChat(chat);
        if (decision.canWrite) {
          envelopeChats.add(chat);
        } else {
          attachmentChats.add(chat);
        }
      }
      Attachment? attachment;
      if (emailTargets.isNotEmpty || attachmentChats.isNotEmpty) {
        attachment = await _buildCalendarTaskAttachment(event.task);
        if (attachment == null) {
          completer.complete(
            const CalendarShareResult.failure(
              CalendarShareFailure.attachmentFailed,
            ),
          );
          return;
        }
        attachment = attachment.copyWith(caption: shareText);
      }
      if (emailTargets.isNotEmpty) {
        final report = await emailService!.fanOutSend(
          targets: emailTargets,
          attachment: attachment!,
        );
        if (report.hasFailures) {
          completer.complete(
            const CalendarShareResult.failure(CalendarShareFailure.sendFailed),
          );
          return;
        }
      }
      if (xmppChats.isNotEmpty) {
        for (final chat in envelopeChats) {
          await _xmppService.sendMessage(
            jid: chat.jid,
            text: shareText,
            encryptionProtocol: chat.encryptionProtocol,
            calendarTaskIcs: event.task,
            calendarTaskIcsReadOnly: true,
            chatType: chat.type,
          );
          _xmppService.notifyDemoOutboundAttachmentMessage(chatJid: chat.jid);
        }
        for (final chat in attachmentChats) {
          await _xmppService.sendAttachment(
            jid: chat.jid,
            attachment: attachment!,
            encryptionProtocol: chat.encryptionProtocol,
            chatType: chat.type,
          );
          _xmppService.notifyDemoOutboundAttachmentMessage(chatJid: chat.jid);
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
      final decision = _xmppService.calendarFragmentDecisionForChat(recipient);
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

  Future<void> _sendDemoTaskShare({
    required List<Contact> recipients,
    required CalendarTask task,
    required String shareText,
  }) async {
    final seenJids = <String>{};
    for (final target in recipients) {
      final targetJid = target.recipientId?.trim();
      if (targetJid == null || targetJid.isEmpty) {
        continue;
      }
      if (!seenJids.add(targetJid)) {
        continue;
      }
      await _xmppService.sendMessage(
        jid: targetJid,
        text: shareText,
        encryptionProtocol: target.encryptionProtocol,
        calendarTaskIcs: task,
        calendarTaskIcsReadOnly: true,
        chatType: target.chatType,
      );
      _xmppService.notifyDemoOutboundAttachmentMessage(chatJid: targetJid);
    }
    if (seenJids.isEmpty) {
      throw StateError('No recipients resolved for demo task share.');
    }
  }

  Future<Attachment?> _buildCalendarTaskAttachment(CalendarTask task) async {
    try {
      const transferService = CalendarTransferService();
      final File file = await transferService.exportTaskIcs(task: task);
      CalendarTransferService.scheduleCleanup(file);
      final int sizeBytes = await file.length();
      const String calendarIcsMimeType = 'text/calendar';
      return Attachment(
        path: file.path,
        fileName: file.uri.pathSegments.last,
        sizeBytes: sizeBytes,
        mimeType: calendarIcsMimeType,
      );
    } catch (_) {
      return null;
    }
  }

  String _calendarTaskShareText(CalendarTask task, String shareText) {
    final trimmedShareText = shareText.trim();
    if (trimmedShareText.isNotEmpty) {
      return trimmedShareText;
    }
    final title = task.title.trim();
    if (title.isNotEmpty) {
      return title;
    }
    return shareText;
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
    final nickname = chat.myNickname?.trim();
    if (nickname == null || nickname.isEmpty) {
      return trimmedOwner;
    }
    return '${chat.jid}/$nickname';
  }

  CalendarModel get currentModel => state.model;
}
