// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_sync_message.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/sync/calendar_snapshot_codec.dart';
import 'package:axichat/src/calendar/sync/calendar_sync_manager.dart';
import 'package:axichat/src/calendar/sync/calendar_sync_state.dart';
import 'package:axichat/src/calendar/sync/chat_calendar_identifiers.dart';
import 'package:axichat/src/calendar/sync/chat_calendar_sync_envelope.dart';
import 'package:axichat/src/calendar/sync/chat_calendar_sync_state_store.dart';
import 'package:axichat/src/calendar/storage/chat_calendar_storage.dart';
import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/storage/models/chat_models.dart';

typedef ChatCalendarSendMessage =
    Future<void> Function({
      required String jid,
      required CalendarSyncOutbound outbound,
      required ChatType chatType,
    });

typedef ChatCalendarSnapshotSender =
    Future<CalendarSnapshotUploadResult> Function(File file);
typedef ChatCalendarApplyPrimaryView =
    Future<void> Function({
      required String chatJid,
      required ChatPrimaryView primaryView,
    });

const String _chatCalendarTaskAddOperation = 'add';

class ChatCalendarSyncCoordinator {
  ChatCalendarSyncCoordinator({
    required ChatCalendarStorage storage,
    required ChatCalendarSendMessage sendMessage,
    required ChatCalendarApplyPrimaryView applyPrimaryView,
    ChatCalendarSnapshotSender? sendSnapshotFile,
    ChatCalendarSyncStateStore? syncStateStore,
  }) : _storage = storage,
       _sendMessage = sendMessage,
       _applyPrimaryView = applyPrimaryView,
       _sendSnapshotFile = sendSnapshotFile,
       _syncStateStore = syncStateStore ?? const ChatCalendarSyncStateStore();

  final ChatCalendarStorage _storage;
  final ChatCalendarSendMessage _sendMessage;
  final ChatCalendarApplyPrimaryView _applyPrimaryView;
  final ChatCalendarSnapshotSender? _sendSnapshotFile;
  final ChatCalendarSyncStateStore _syncStateStore;
  final Map<String, _ChatCalendarSession> _sessions =
      <String, _ChatCalendarSession>{};

  CalendarSyncManager managerFor({
    required String chatJid,
    required ChatType chatType,
  }) {
    return _ensureSession(
      chatJid: chatJid,
      chatType: chatType,
    ).manager(sendSnapshotFile: _sendSnapshotFile);
  }

  void registerBloc({
    required String chatJid,
    required ChatType chatType,
    required CalendarModel Function() readModel,
    required Future<void> Function(CalendarModel) applyModel,
  }) {
    final session = _ensureSession(chatJid: chatJid, chatType: chatType);
    session.attachBloc(
      chatType: chatType,
      readModel: readModel,
      applyModel: applyModel,
    );
  }

  void unregisterBloc({required String chatJid}) {
    final session = _sessions[_chatKey(chatJid)];
    if (session == null) {
      return;
    }
    session.detachBloc();
  }

  Future<void> handleInbound(ChatCalendarSyncEnvelope envelope) async {
    final manager = _ensureSession(
      chatJid: envelope.chatJid,
      chatType: envelope.chatType,
    ).manager(sendSnapshotFile: _sendSnapshotFile);
    await manager.onCalendarMessage(envelope.inbound);
  }

  Future<void> addTask({
    required String chatJid,
    required ChatType chatType,
    required CalendarTask task,
  }) async {
    final session = _ensureSession(chatJid: chatJid, chatType: chatType);
    final manager = session.manager(sendSnapshotFile: _sendSnapshotFile);
    final model = session.readModel();
    final updated = model.addTask(task);
    await session.applyModel(updated);
    await manager.sendTaskUpdate(task, _chatCalendarTaskAddOperation);
  }

  _ChatCalendarSession _ensureSession({
    required String chatJid,
    required ChatType chatType,
  }) {
    final normalizedJid = _normalizeChatJid(chatJid);
    final key = _chatKey(normalizedJid);
    return _sessions.putIfAbsent(
      key,
      () => _ChatCalendarSession(
        chatJid: normalizedJid,
        chatType: chatType,
        storage: _storage,
        sendMessage: _sendMessage,
        applyPrimaryView: _applyPrimaryView,
        syncStateStore: _syncStateStore,
      ),
    )..setChatType(chatType);
  }
}

String _normalizeChatJid(String chatJid) {
  return normalizeAddress(chatJid) ?? '';
}

String _chatKey(String chatJid) => chatCalendarStorageId(chatJid);

class _ChatCalendarSession {
  _ChatCalendarSession({
    required this.chatJid,
    required ChatType chatType,
    required ChatCalendarStorage storage,
    required ChatCalendarSendMessage sendMessage,
    required ChatCalendarApplyPrimaryView applyPrimaryView,
    required ChatCalendarSyncStateStore syncStateStore,
  }) : _storage = storage,
       _sendMessage = sendMessage,
       _applyPrimaryView = applyPrimaryView,
       _syncStateStore = syncStateStore,
       _chatType = chatType {
    _resetToStorage();
  }

  final String chatJid;
  final ChatCalendarStorage _storage;
  final ChatCalendarSendMessage _sendMessage;
  final ChatCalendarApplyPrimaryView _applyPrimaryView;
  final ChatCalendarSyncStateStore _syncStateStore;
  ChatType _chatType;
  CalendarSyncManager? _manager;
  late CalendarModel Function() _readModel;
  late Future<void> Function(CalendarModel) _applyModel;

  void setChatType(ChatType chatType) {
    _chatType = chatType;
  }

  void attachBloc({
    required ChatType chatType,
    required CalendarModel Function() readModel,
    required Future<void> Function(CalendarModel) applyModel,
  }) {
    _chatType = chatType;
    _readModel = readModel;
    _applyModel = applyModel;
  }

  void detachBloc() {
    _resetToStorage();
  }

  CalendarSyncManager manager({
    required ChatCalendarSnapshotSender? sendSnapshotFile,
  }) {
    return _manager ??= CalendarSyncManager(
      readModel: readModel,
      applyModel: applyModel,
      sendCalendarMessage: send,
      applyRoomPrimaryView: _chatType == ChatType.groupChat
          ? applyPrimaryView
          : null,
      sendSnapshotFile: sendSnapshotFile,
      readSyncState: readSyncState,
      writeSyncState: writeSyncState,
    );
  }

  CalendarModel readModel() => _readModel();

  Future<void> applyModel(CalendarModel model) => _applyModel(model);

  Future<void> applyPrimaryView(ChatPrimaryView primaryView) =>
      _applyPrimaryView(chatJid: chatJid, primaryView: primaryView);

  CalendarSyncState readSyncState() => _syncStateStore.read(chatJid);

  Future<void> writeSyncState(CalendarSyncState state) =>
      _syncStateStore.write(chatJid, state);

  Future<void> send(CalendarSyncOutbound outbound) async {
    if (_chatType == ChatType.note) {
      return;
    }
    await _sendMessage(jid: chatJid, outbound: outbound, chatType: _chatType);
  }

  void _resetToStorage() {
    _readModel = () => _storage.readModel(chatJid);
    _applyModel = (model) async {
      await _storage.writeModel(chatJid, model);
    };
  }
}
