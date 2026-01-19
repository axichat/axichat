// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'package:axichat/src/xmpp/xmpp_service.dart';

enum _DemoInteractivePhase {
  idle,
  overlaysRunning,
  waitingForFirstReply,
  waitingForSecondReply,
  waitingForFinalReply,
  completed,
}

mixin DemoScriptService on XmppBase, MessageService {
  final List<Timer> _demoTimers = <Timer>[];
  final Map<XmppOperationKind, Queue<Timer>> _demoOperationTimers =
      <XmppOperationKind, Queue<Timer>>{};
  final StreamController<void> _demoResetController =
      StreamController<void>.broadcast();
  bool _demoOverlayGateOpen = false;
  _DemoInteractivePhase _demoInteractivePhase = _DemoInteractivePhase.idle;

  Stream<void> get demoResetStream => _demoResetController.stream;

  void startDemoInteractivePhase() {
    if (!kEnableDemoChats || !demoOfflineMode) return;
    if (_demoInteractivePhase != _DemoInteractivePhase.idle) return;
    _demoInteractivePhase = _DemoInteractivePhase.overlaysRunning;
    const startDelay = Duration(seconds: 3);
    const overlayWindow = Duration(seconds: 5);
    _scheduleDemoTimer(startDelay, () {
      _demoOverlayGateOpen = true;
      _runDemoOperationSequence();
    });
    _scheduleDemoTimer(startDelay + overlayWindow, () async {
      _demoOverlayGateOpen = false;
      await _sendDemoContact1DocumentsMessage();
      _demoInteractivePhase = _DemoInteractivePhase.waitingForFirstReply;
    });
  }

  void _resetDemoScript() {
    for (final timer in _demoTimers) {
      timer.cancel();
    }
    _demoTimers.clear();
    for (final queues in _demoOperationTimers.values) {
      for (final timer in queues) {
        timer.cancel();
      }
    }
    _demoOperationTimers.clear();
    _demoOverlayGateOpen = false;
    _demoInteractivePhase = _DemoInteractivePhase.idle;
  }

  bool _shouldAllowOperationEvent(XmppOperationEvent event) {
    if (!kEnableDemoChats || !demoOfflineMode) return true;
    return _demoOverlayGateOpen;
  }

  Future<void> resetDemoInteractivePhase() async {
    if (!kEnableDemoChats) return;
    _resetDemoScript();
    if (this case final XmppService service) {
      await service._dbOp<XmppDatabase>(
        (db) async => db.deleteAll(),
        awaitDatabase: true,
      );
      service
        .._demoSeedAttempted = false
        ..clearCachedChatList();
      await service._seedDemoChatsIfNeeded();
    }
    if (_demoResetController.isClosed) return;
    _demoResetController.add(null);
  }

  Future<void> _closeDemoScript() async {
    _resetDemoScript();
    if (_demoResetController.isClosed) return;
    await _demoResetController.close();
  }

  void _handleDemoXmppOperationEvent(XmppOperationEvent event) {
    if (!kEnableDemoChats || !demoOfflineMode) return;
    if (event.stage.isStart) {
      _scheduleDemoOperationCompletion(event.kind);
      return;
    }
    _cancelDemoOperationCompletion(event.kind);
  }

  void _scheduleDemoAck(String stanzaId) {
    if (!kEnableDemoChats || !demoOfflineMode) return;
    const delay = Duration(milliseconds: 500);
    _scheduleDemoTimer(delay, () async {
      await _dbOp<XmppDatabase>(
        (db) async => db.markMessageAcked(stanzaId),
        awaitDatabase: true,
      );
    });
  }

  void _handleDemoOutboundTextMessage({
    required Message message,
    required PseudoMessageType? pseudoMessageType,
  }) {
    if (!kEnableDemoChats || !demoOfflineMode) return;
    if (pseudoMessageType != null) return;
    if (message.chatJid != DemoChats.contact1Jid) return;
    if ((message.body ?? '').trim().isEmpty) return;
    const responseDelay = Duration(seconds: 1);
    switch (_demoInteractivePhase) {
      case _DemoInteractivePhase.waitingForFirstReply:
        _demoInteractivePhase = _DemoInteractivePhase.waitingForSecondReply;
        _scheduleDemoTimer(responseDelay, () async {
          await _sendDemoContact1Message(
            body: 'Do you want to hang out on Saturday at 1pm?',
          );
        });
      case _DemoInteractivePhase.waitingForSecondReply:
        _demoInteractivePhase = _DemoInteractivePhase.waitingForFinalReply;
        _scheduleDemoTimer(responseDelay, () async {
          await _sendDemoContact1Message(body: 'Sounds good');
        });
      case _DemoInteractivePhase.waitingForFinalReply:
        _demoInteractivePhase = _DemoInteractivePhase.completed;
        _scheduleDemoTimer(responseDelay, () async {
          await _sendDemoContact1Message(body: 'Copied, see you then');
        });
      case _DemoInteractivePhase.idle:
      case _DemoInteractivePhase.overlaysRunning:
      case _DemoInteractivePhase.completed:
        return;
    }
  }

  void _runDemoOperationSequence() {
    final operations = <XmppOperationKind>[
      XmppOperationKind.pubSubConversations,
      XmppOperationKind.pubSubBookmarks,
      XmppOperationKind.pubSubDrafts,
      XmppOperationKind.pubSubAvatarMetadata,
      XmppOperationKind.mamLoginSync,
      XmppOperationKind.mamFetch,
    ];
    const staggerDelay = Duration(milliseconds: 100);
    for (var i = 0; i < operations.length; i += 1) {
      final delay = Duration(milliseconds: staggerDelay.inMilliseconds * i);
      _scheduleDemoTimer(delay, () {
        emitXmppOperation(
          XmppOperationEvent(
            kind: operations[i],
            stage: XmppOperationStage.start,
          ),
        );
      });
    }
  }

  void _scheduleDemoOperationCompletion(XmppOperationKind kind) {
    const completionDelay = Duration(seconds: 3);
    final pending = _demoOperationTimers.putIfAbsent(
      kind,
      () => Queue<Timer>(),
    );
    late final Timer timer;
    timer = Timer(completionDelay, () {
      pending.remove(timer);
      if (pending.isEmpty) {
        _demoOperationTimers.remove(kind);
      }
      emitXmppOperation(
        XmppOperationEvent(
          kind: kind,
          stage: XmppOperationStage.end,
          isSuccess: true,
        ),
      );
    });
    pending.add(timer);
  }

  void _cancelDemoOperationCompletion(XmppOperationKind kind) {
    final pending = _demoOperationTimers[kind];
    if (pending == null || pending.isEmpty) return;
    final timer = pending.removeFirst();
    timer.cancel();
    if (pending.isEmpty) {
      _demoOperationTimers.remove(kind);
    }
  }

  Future<void> _sendDemoContact1DocumentsMessage() async {
    final attachments = <DemoAttachmentAsset>[
      DemoChats.gmailDocAttachment,
      DemoChats.gmailDocAttachment2,
    ];
    await _ensureDemoAttachments(attachments);
    await _sendDemoContact1Message(
      body: 'Here are the templates I told you about',
      attachments: attachments,
    );
  }

  Future<void> _sendDemoContact1Message({
    required String body,
    List<DemoAttachmentAsset> attachments = const <DemoAttachmentAsset>[],
  }) async {
    final timestamp = demoNow();
    final fileMetadataId = attachments.isEmpty ? null : attachments.first.id;
    final message = Message(
      stanzaID: _connection.generateId(),
      senderJid: DemoChats.contact1Jid,
      chatJid: DemoChats.contact1Jid,
      body: body,
      timestamp: timestamp,
      acked: true,
      received: true,
      displayed: false,
      fileMetadataID: fileMetadataId,
    );
    await _dbOp<XmppDatabase>((db) async {
      await db.saveMessage(message);
      final chat = await db.getChat(message.chatJid);
      if (chat != null &&
          message.timestamp != null &&
          chat.lastChangeTimestamp.isBefore(message.timestamp!)) {
        await db.updateChat(
          chat.copyWith(
            lastChangeTimestamp: message.timestamp!,
            lastMessage: body,
          ),
        );
      }
      if (attachments.length <= 1) return;
      final persisted = await db.getMessageByStanzaID(message.stanzaID);
      final messageId = persisted?.id;
      if (messageId == null || messageId.isEmpty) return;
      for (var index = 1; index < attachments.length; index += 1) {
        await db.addMessageAttachment(
          messageId: messageId,
          fileMetadataId: attachments[index].id,
          sortOrder: index,
        );
      }
    }, awaitDatabase: true);
  }

  Future<void> _ensureDemoAttachments(
    List<DemoAttachmentAsset> attachments,
  ) async {
    final owner = this;
    await _dbOp<XmppDatabase>((db) async {
      for (final attachment in attachments) {
        final existing = await db.getFileMetadata(attachment.id);
        if (existing != null) continue;
        if (owner is! XmppService) return;
        final metadata = await owner._seedDemoAttachment(attachment);
        if (metadata != null) {
          await db.saveFileMetadata(metadata);
        }
      }
    }, awaitDatabase: true);
  }

  void _scheduleDemoTimer(
    Duration delay,
    FutureOr<void> Function() action,
  ) {
    late final Timer timer;
    timer = Timer(delay, () async {
      _demoTimers.remove(timer);
      await action();
    });
    _demoTimers.add(timer);
  }
}
