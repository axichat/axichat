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
import 'package:axichat/src/calendar/models/calendar_sync_warning.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/storage/chat_calendar_storage.dart';
import 'package:axichat/src/calendar/storage/calendar_linked_task_registry.dart';
import 'package:axichat/src/calendar/storage/storage_builders.dart';
import 'package:axichat/src/calendar/sync/calendar_availability_share_coordinator.dart';
import 'package:axichat/src/calendar/sync/calendar_availability_share_store.dart';
import 'package:axichat/src/calendar/sync/calendar_sync_manager.dart';
import 'package:axichat/src/calendar/sync/calendar_snapshot_codec.dart';
import 'package:axichat/src/calendar/sync/chat_calendar_identifiers.dart';
import 'package:axichat/src/calendar/sync/chat_calendar_sync_envelope.dart';
import 'package:axichat/src/calendar/sync/chat_calendar_sync_coordinator.dart';
import 'package:axichat/src/calendar/utils/calendar_fragment_policy.dart';
import 'package:axichat/src/calendar/utils/calendar_transfer_service.dart';
import 'package:axichat/src/common/safe_logging.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/email/models/email_attachment.dart';
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
    applyModel: (model) async {
      owner.add(CalendarEvent.remoteModelApplied(model: model));
    },
    sendCalendarMessage: owner.sendPersonalCalendarSync,
    sendSnapshotFile: owner.uploadCalendarSnapshot,
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
  StreamSubscription<CalendarSyncWarning>? _calendarSyncWarningSubscription;
  StreamSubscription<XmppStreamReady>? _streamReadySubscription;
  StreamSubscription<XmppStreamReady>? _chatStreamReadySubscription;
  Future<void> _pendingCalendarDispatch = Future<void>.value();
  Future<void> _pendingChatCalendarDispatch = Future<void>.value();

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

  void _attachCalendarSyncSubscriptions() {
    final lastReady = _xmppService.lastStreamReady;
    if (lastReady != null) {
      _ensureCalendarSyncSubscriptions();
      return;
    }
    _streamReadySubscription ??= _xmppService.streamReadyStream.listen((_) {
      _ensureCalendarSyncSubscriptions();
    });
  }

  void _ensureCalendarSyncSubscriptions() {
    if (_calendarSyncSubscription != null &&
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
    _calendarSyncWarningSubscription ??= _xmppService.calendarSyncWarningStream
        .listen((warning) {
          add(CalendarEvent.syncWarningRaised(warning: warning));
        });
    _streamReadySubscription?.cancel();
    _streamReadySubscription = null;
  }

  void _ensureChatCalendarSyncSubscription() {
    final coordinator = _chatCalendarCoordinator;
    if (coordinator == null) {
      return;
    }
    if (_chatCalendarSyncSubscription != null) {
      return;
    }
    if (_xmppService.lastStreamReady == null) {
      _chatStreamReadySubscription ??= _xmppService.streamReadyStream.listen((
        _,
      ) {
        _ensureChatCalendarSyncSubscription();
      });
      return;
    }
    _chatCalendarSyncSubscription ??= _xmppService
        .chatCalendarSyncDispatchStream
        .listen((dispatch) {
          _pendingChatCalendarDispatch = _pendingChatCalendarDispatch.then((
            _,
          ) async {
            try {
              await coordinator.handleInbound(dispatch.envelope);
              dispatch.complete();
            } catch (error, stackTrace) {
              dispatch.completeError(error, stackTrace);
            }
          });
        });
    _chatStreamReadySubscription?.cancel();
    _chatStreamReadySubscription = null;
  }

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
      _recordSyncTimestamp();
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
      _recordSyncTimestamp();
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
      _recordSyncTimestamp();
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
      _recordSyncTimestamp();
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
      _recordSyncTimestamp();
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
      _recordSyncTimestamp();
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
      _recordSyncTimestamp();
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
      _recordSyncTimestamp();
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
      _recordSyncTimestamp();
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
      _recordSyncTimestamp();
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
    await _calendarSyncSubscription?.cancel();
    await _chatCalendarSyncSubscription?.cancel();
    await _calendarSyncWarningSubscription?.cancel();
    await _streamReadySubscription?.cancel();
    await _chatStreamReadySubscription?.cancel();
    await _pendingCalendarDispatch;
    await _pendingChatCalendarDispatch;
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
      if (recipients.isEmpty) {
        completer.complete(
          const CalendarShareResult.failure(CalendarShareFailure.sendFailed),
        );
        return;
      }
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
          final decision = _xmppService.calendarFragmentDecisionForChat(chat);
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
          _xmppService.notifyDemoOutboundAttachmentMessage(chatJid: chat.jid);
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

  Future<EmailAttachment?> _buildCalendarTaskAttachment(
    CalendarTask task,
  ) async {
    try {
      const transferService = CalendarTransferService();
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
    final nickname = chat.myNickname?.trim();
    if (nickname == null || nickname.isEmpty) {
      return trimmedOwner;
    }
    return '${chat.jid}/$nickname';
  }

  CalendarModel get currentModel => state.model;
}
