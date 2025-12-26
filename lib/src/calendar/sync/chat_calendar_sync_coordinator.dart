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
import 'package:axichat/src/storage/models/chat_models.dart';

typedef ChatCalendarSendMessage = Future<void> Function({
  required String jid,
  required CalendarSyncOutbound outbound,
  required ChatType chatType,
});

typedef ChatCalendarSnapshotSender = Future<CalendarSnapshotUploadResult>
    Function(File file);

const String _chatCalendarTaskAddOperation = 'add';

class ChatCalendarSyncCoordinator {
  ChatCalendarSyncCoordinator({
    required ChatCalendarStorage storage,
    required ChatCalendarSendMessage sendMessage,
    ChatCalendarSnapshotSender? sendSnapshotFile,
    ChatCalendarSyncStateStore? syncStateStore,
  })  : _storage = storage,
        _sendMessage = sendMessage,
        _sendSnapshotFile = sendSnapshotFile,
        _syncStateStore = syncStateStore ?? const ChatCalendarSyncStateStore();

  final ChatCalendarStorage _storage;
  final ChatCalendarSendMessage _sendMessage;
  final ChatCalendarSnapshotSender? _sendSnapshotFile;
  final ChatCalendarSyncStateStore _syncStateStore;
  final Map<String, _ChatCalendarSyncContext> _contexts =
      <String, _ChatCalendarSyncContext>{};
  final Map<String, CalendarSyncManager> _managers =
      <String, CalendarSyncManager>{};

  CalendarSyncManager managerFor({
    required String chatJid,
    required ChatType chatType,
  }) {
    return _ensureManager(chatJid: chatJid, chatType: chatType);
  }

  void registerBloc({
    required String chatJid,
    required ChatType chatType,
    required CalendarModel Function() readModel,
    required Future<void> Function(CalendarModel) applyModel,
  }) {
    final context = _ensureContext(chatJid: chatJid, chatType: chatType);
    context.attachBloc(
      chatType: chatType,
      readModel: readModel,
      applyModel: applyModel,
    );
  }

  void unregisterBloc({
    required String chatJid,
  }) {
    final context = _contexts[_chatKey(chatJid)];
    if (context == null) {
      return;
    }
    context.detachBloc();
  }

  Future<void> handleInbound(ChatCalendarSyncEnvelope envelope) async {
    final manager = _ensureManager(
      chatJid: envelope.chatJid,
      chatType: envelope.chatType,
    );
    await manager.onCalendarMessage(envelope.inbound);
  }

  Future<void> addTask({
    required String chatJid,
    required ChatType chatType,
    required CalendarTask task,
  }) async {
    if (chatType == ChatType.note) {
      return;
    }
    final context = _ensureContext(chatJid: chatJid, chatType: chatType);
    final manager = _ensureManager(chatJid: chatJid, chatType: chatType);
    final model = context.readModel();
    final updated = model.addTask(task);
    await context.applyModel(updated);
    await manager.sendTaskUpdate(task, _chatCalendarTaskAddOperation);
  }

  CalendarSyncManager _ensureManager({
    required String chatJid,
    required ChatType chatType,
  }) {
    final normalizedJid = _normalizeChatJid(chatJid);
    final key = _chatKey(normalizedJid);
    return _managers.putIfAbsent(key, () {
      final context =
          _ensureContext(chatJid: normalizedJid, chatType: chatType);
      return CalendarSyncManager(
        readModel: context.readModel,
        applyModel: context.applyModel,
        sendCalendarMessage: context.send,
        sendSnapshotFile: _sendSnapshotFile,
        readSyncState: context.readSyncState,
        writeSyncState: context.writeSyncState,
      );
    });
  }

  _ChatCalendarSyncContext _ensureContext({
    required String chatJid,
    required ChatType chatType,
  }) {
    final normalizedJid = _normalizeChatJid(chatJid);
    final key = _chatKey(normalizedJid);
    return _contexts.putIfAbsent(
      key,
      () => _ChatCalendarSyncContext(
        chatJid: normalizedJid,
        chatType: chatType,
        storage: _storage,
        sendMessage: _sendMessage,
        syncStateStore: _syncStateStore,
      ),
    )..setChatType(chatType);
  }
}

String _normalizeChatJid(String chatJid) {
  return chatJid.trim();
}

String _chatKey(String chatJid) => chatCalendarStorageId(chatJid);

class _ChatCalendarSyncContext {
  _ChatCalendarSyncContext({
    required this.chatJid,
    required ChatType chatType,
    required ChatCalendarStorage storage,
    required ChatCalendarSendMessage sendMessage,
    required ChatCalendarSyncStateStore syncStateStore,
  })  : _storage = storage,
        _sendMessage = sendMessage,
        _syncStateStore = syncStateStore,
        _chatType = chatType {
    _resetToStorage();
  }

  final String chatJid;
  final ChatCalendarStorage _storage;
  final ChatCalendarSendMessage _sendMessage;
  final ChatCalendarSyncStateStore _syncStateStore;
  ChatType _chatType;
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

  CalendarModel readModel() => _readModel();

  Future<void> applyModel(CalendarModel model) => _applyModel(model);

  CalendarSyncState readSyncState() => _syncStateStore.read(chatJid);

  Future<void> writeSyncState(CalendarSyncState state) =>
      _syncStateStore.write(chatJid, state);

  Future<void> send(CalendarSyncOutbound outbound) async {
    await _sendMessage(
      jid: chatJid,
      outbound: outbound,
      chatType: _chatType,
    );
  }

  void _resetToStorage() {
    _readModel = () => _storage.readModel(chatJid);
    _applyModel = (model) async {
      await _storage.writeModel(chatJid, model);
    };
  }
}
