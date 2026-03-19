import 'dart:async';
import 'dart:collection';

import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/chat/models/chat_message.dart';
import 'package:axichat/src/common/chat_subject_codec.dart';
import 'package:axichat/src/common/compose_recipient.dart';
import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/common/synthetic_reply.dart';
import 'package:axichat/src/chat/models/pending_attachment.dart';
import 'package:axichat/src/common/synthetic_forward.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:axichat/src/email/models/fan_out_recipient_state.dart';
import 'package:axichat/src/email/models/fan_out_recipient_status.dart';
import 'package:axichat/src/email/models/fan_out_send_report.dart';
import 'package:axichat/src/email/service/delta_chat_exception.dart';
import 'package:axichat/src/email/models/email_sync_state.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/util/synthetic_forward_html.dart';
import 'package:axichat/src/xmpp/muc/occupant.dart';
import 'package:axichat/src/xmpp/message/message_service.dart'
    show XmppAttachmentUpload;
import 'package:axichat/src/xmpp/muc/room_state.dart';
import 'package:axichat/src/settings/app_language.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart' as xmpp;
import 'package:flutter/material.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks.dart';

Future<void> _pumpBloc() async {
  await Future<void>.delayed(Duration.zero);
}

ChatSettingsSnapshot _defaultChatSettings() => const ChatSettingsSnapshot(
  language: AppLanguage.system,
  chatReadReceipts: true,
  emailReadReceipts: false,
  shareTokenSignatureEnabled: true,
  autoDownloadImages: true,
  autoDownloadVideos: false,
  autoDownloadDocuments: false,
  autoDownloadArchives: false,
);

ChatMessageSent _messageSent({
  required Chat chat,
  required String text,
  required List<ComposerRecipient> recipients,
  required ChatSettingsSnapshot settings,
  List<PendingAttachment>? pendingAttachments,
  bool supportsHttpFileUpload = false,
  String attachmentFallbackLabel = 'Attachment',
  String? subject,
  Message? quotedDraft,
  RoomState? roomState,
  Completer<List<PendingAttachment>>? completer,
}) => ChatMessageSent(
  chat: chat,
  text: text,
  recipients: recipients,
  pendingAttachments: pendingAttachments ?? const <PendingAttachment>[],
  settings: settings,
  supportsHttpFileUpload: supportsHttpFileUpload,
  attachmentFallbackLabel: attachmentFallbackLabel,
  subject: subject,
  quotedDraft: quotedDraft,
  roomState: roomState,
  completer: completer,
);

void _mockEmailSync(MockEmailService service) {
  when(() => service.syncState).thenReturn(const EmailSyncState.ready());
  when(
    () => service.syncStateStream,
  ).thenAnswer((_) => const Stream<EmailSyncState>.empty());
  when(
    () => service.messageStreamForChat(
      any(),
      start: any(named: 'start'),
      end: any(named: 'end'),
      filter: any(named: 'filter'),
    ),
  ).thenAnswer((_) => const Stream<List<Message>>.empty());
  when(
    () => service.pinnedMessagesStream(any()),
  ).thenAnswer((_) => const Stream<List<PinnedMessageEntry>>.empty());
  when(
    () => service.backfillChatHistory(
      chat: any(named: 'chat'),
      desiredWindow: any(named: 'desiredWindow'),
      beforeMessageId: any(named: 'beforeMessageId'),
      beforeTimestamp: any(named: 'beforeTimestamp'),
      filter: any(named: 'filter'),
    ),
  ).thenAnswer((_) async {});
  when(
    () => service.sendMessage(
      chat: any(named: 'chat'),
      body: any(named: 'body'),
      subject: any(named: 'subject'),
      htmlBody: any(named: 'htmlBody'),
      quotedStanzaId: any(named: 'quotedStanzaId'),
    ),
  ).thenAnswer((_) async => 1);
  when(
    () => service.sendAttachment(
      chat: any(named: 'chat'),
      attachment: any(named: 'attachment'),
      subject: any(named: 'subject'),
      htmlCaption: any(named: 'htmlCaption'),
      quotedStanzaId: any(named: 'quotedStanzaId'),
    ),
  ).thenAnswer((_) async => 1);
  when(
    () => service.fanOutSend(
      targets: any(named: 'targets'),
      body: any(named: 'body'),
      htmlBody: any(named: 'htmlBody'),
      attachment: any(named: 'attachment'),
      htmlCaption: any(named: 'htmlCaption'),
      shareId: any(named: 'shareId'),
      quotedStanzaId: any(named: 'quotedStanzaId'),
      useSubjectToken: any(named: 'useSubjectToken'),
      tokenAsSignature: any(named: 'tokenAsSignature'),
      subject: any(named: 'subject'),
    ),
  ).thenAnswer((invocation) async {
    final targets =
        invocation.namedArguments[#targets]! as List<Contact>;
    final shareId =
        invocation.namedArguments[#shareId] as String? ?? 'share-1';
    return FanOutSendReport(
      shareId: shareId,
      statuses: [
        for (var index = 0; index < targets.length; index++)
          FanOutRecipientStatus(
            chat: Chat(
              jid:
                  targets[index].chatJid ??
                  targets[index].address ??
                  'target-$index@example.com',
              title:
                  targets[index].displayName ??
                  targets[index].address ??
                  targets[index].chatJid ??
                  'target-$index',
              type: ChatType.chat,
              lastChangeTimestamp: DateTime(2024, 1, 1),
            ),
            state: FanOutRecipientState.sent,
            deltaMsgId: index + 1,
          ),
      ],
    );
  });
  when(
    () => service.sendReply(
      chat: any(named: 'chat'),
      body: any(named: 'body'),
      quotedMessage: any(named: 'quotedMessage'),
      subject: any(named: 'subject'),
      htmlBody: any(named: 'htmlBody'),
    ),
  ).thenAnswer((_) async => 1);
  when(
    () => service.shareContextForMessage(any()),
  ).thenAnswer((_) async => null);
  when(() => service.getMessageFullHtml(any())).thenAnswer((_) async => null);
  when(() => service.getQuotedMessage(any())).thenAnswer((_) async => null);
}

class FakeXmppAttachmentUpload extends Fake implements XmppAttachmentUpload {}

Chat _groupChat(String jid, {String title = 'Room'}) => Chat(
  jid: jid,
  title: title,
  type: ChatType.groupChat,
  lastChangeTimestamp: DateTime.now(),
);

Occupant _occupant({
  required String occupantId,
  required String nick,
  String? realJid,
  OccupantAffiliation affiliation = OccupantAffiliation.none,
  OccupantRole role = OccupantRole.none,
  bool isPresent = true,
}) {
  return Occupant(
    occupantId: occupantId,
    nick: nick,
    realJid: realJid,
    affiliation: affiliation,
    role: role,
    isPresent: isPresent,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMessageService messageService;
  late MockChatsService chatsService;
  late MockNotificationService notificationService;
  late MockMucService mucService;
  late StreamController<List<Message>> messageStreamController;
  late StreamController<Chat?> chatStreamController;

  setUpAll(() {
    registerFallbackValue(<Contact>[]);
    registerFallbackValue(<Message>[fallbackMessage]);
    registerFallbackValue(MessageTimelineFilter.allWithContact);
    registerFallbackValue(ChatType.chat);
    registerFallbackValue(EncryptionProtocol.none);
    registerFallbackValue(OccupantAffiliation.none);
    registerFallbackValue(OccupantRole.none);
    registerFallbackValue(fallbackMessage);
    registerFallbackValue(
      Chat(
        jid: 'fallback@axi.im',
        title: 'fallback',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime(2023),
      ),
    );
    registerFallbackValue(
      const EmailAttachment(
        path: '/tmp/mock',
        fileName: 'mock.txt',
        sizeBytes: 0,
      ),
    );
  });

  setUp(() {
    messageService = MockMessageService();
    chatsService = MockChatsService();
    notificationService = MockNotificationService();
    mucService = MockMucService();
    messageStreamController = StreamController<List<Message>>.broadcast();
    chatStreamController = StreamController<Chat?>.broadcast();

    when(
      () => notificationService.dismissMessageNotification(
        threadKey: any(named: 'threadKey'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mucService.roomStateStream(any()),
    ).thenAnswer((_) => const Stream<RoomState>.empty());
    when(
      () => mucService.warmRoomFromHistory(roomJid: any(named: 'roomJid')),
    ).thenAnswer(
      (invocation) async =>
          RoomState(roomJid: invocation.namedArguments[#roomJid] as String),
    );
    when(() => mucService.seedDummyRoomData(any())).thenAnswer((_) async {});
    when(
      () => mucService.inviteUserToRoom(
        roomJid: any(named: 'roomJid'),
        inviteeJid: any(named: 'inviteeJid'),
        reason: any(named: 'reason'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mucService.kickOccupant(
        roomJid: any(named: 'roomJid'),
        nick: any(named: 'nick'),
        reason: any(named: 'reason'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mucService.banOccupant(
        roomJid: any(named: 'roomJid'),
        jid: any(named: 'jid'),
        reason: any(named: 'reason'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mucService.changeAffiliation(
        roomJid: any(named: 'roomJid'),
        jid: any(named: 'jid'),
        affiliation: any(named: 'affiliation'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mucService.changeRole(
        roomJid: any(named: 'roomJid'),
        nick: any(named: 'nick'),
        role: any(named: 'role'),
      ),
    ).thenAnswer((_) async {});

    when(
      () => messageService.messageStreamForChat(
        any(),
        start: any(named: 'start'),
        end: any(named: 'end'),
        filter: any(named: 'filter'),
      ),
    ).thenAnswer((_) => messageStreamController.stream);
    when(
      () => messageService.httpUploadSupportStream,
    ).thenAnswer((_) => const Stream<xmpp.HttpUploadSupport>.empty());
    when(
      () => messageService.httpUploadSupport,
    ).thenReturn(const xmpp.HttpUploadSupport(supported: false));
    when(
      () => messageService.createChatArchiveSession(),
    ).thenReturn('session-1');
    when(
      () => messageService.hydrateLatestFromMamForChatSessionIfNeeded(
        sessionId: any(named: 'sessionId'),
        chat: any(named: 'chat'),
        desiredWindow: any(named: 'desiredWindow'),
        filter: any(named: 'filter'),
        visibleWindowEmpty: any(named: 'visibleWindowEmpty'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => messageService.sendMessage(
        jid: any(named: 'jid'),
        text: any(named: 'text'),
        encryptionProtocol: any(named: 'encryptionProtocol'),
        htmlBody: any(named: 'htmlBody'),
        forwarded: any(named: 'forwarded'),
        forwardedFromJid: any(named: 'forwardedFromJid'),
        quotedMessage: any(named: 'quotedMessage'),
        quotedReference: any(named: 'quotedReference'),
        calendarFragment: any(named: 'calendarFragment'),
        calendarTaskIcs: any(named: 'calendarTaskIcs'),
        calendarTaskIcsReadOnly: any(named: 'calendarTaskIcsReadOnly'),
        calendarAvailabilityMessage: any(named: 'calendarAvailabilityMessage'),
        storeLocally: any(named: 'storeLocally'),
        noStore: any(named: 'noStore'),
        extraExtensions: any(named: 'extraExtensions'),
        chatType: any(named: 'chatType'),
        onLocalMessageStored: any(named: 'onLocalMessageStored'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => messageService.sendAttachment(
        jid: any(named: 'jid'),
        attachment: any(named: 'attachment'),
        encryptionProtocol: any(named: 'encryptionProtocol'),
        htmlCaption: any(named: 'htmlCaption'),
        forwarded: any(named: 'forwarded'),
        forwardedFromJid: any(named: 'forwardedFromJid'),
        transportGroupId: any(named: 'transportGroupId'),
        attachmentOrder: any(named: 'attachmentOrder'),
        quotedMessage: any(named: 'quotedMessage'),
        quotedReference: any(named: 'quotedReference'),
        chatType: any(named: 'chatType'),
        upload: any(named: 'upload'),
        onLocalMessageStored: any(named: 'onLocalMessageStored'),
      ),
    ).thenAnswer((_) async => FakeXmppAttachmentUpload());

    when(
      () => messageService.countLocalMessages(
        jid: any(named: 'jid'),
        filter: any(named: 'filter'),
        includePseudoMessages: any(named: 'includePseudoMessages'),
      ),
    ).thenAnswer((_) async => 0);
    when(
      () => messageService.resolvePeerCapabilities(
        jid: any(named: 'jid'),
        forceRefresh: any(named: 'forceRefresh'),
      ),
    ).thenAnswer((_) async => xmpp.XmppPeerCapabilities(features: const []));
    when(
      () => messageService.loadMessageByStanzaId(any()),
    ).thenAnswer((_) async => null);
    when(
      () => messageService.loadMessageByReferenceId(
        any(),
        chatJid: any(named: 'chatJid'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => messageService.pinnedMessagesStream(any()),
    ).thenAnswer((_) => const Stream<List<PinnedMessageEntry>>.empty());
    when(
      () => messageService.syncPinnedMessagesForChat(any()),
    ).thenAnswer((_) async {});

    when(
      () => chatsService.chatStream(any()),
    ).thenAnswer((_) => chatStreamController.stream);
    when(
      () => chatsService.typingParticipantsStream(any()),
    ).thenAnswer((_) => const Stream<List<String>>.empty());

    when(() => chatsService.myJid).thenReturn('self@axi.im');
    when(() => messageService.database).thenAnswer((_) async => mockDatabase);
    when(
      () => mockDatabase.countChatMessagesThrough(
        any(),
        throughTimestamp: any(named: 'throughTimestamp'),
        throughStanzaId: any(named: 'throughStanzaId'),
        throughDeltaMsgId: any(named: 'throughDeltaMsgId'),
        filter: any(named: 'filter'),
      ),
    ).thenAnswer((_) async => 0);
    when(
      () => mockDatabase.getPinnedMessages(any()),
    ).thenAnswer((_) async => const <PinnedMessageEntry>[]);
    when(
      () => mockDatabase.getMessageAttachments(any()),
    ).thenAnswer((_) async => const <MessageAttachmentData>[]);
    when(
      () => mockDatabase.getMessageAttachmentsForGroup(any()),
    ).thenAnswer((_) async => const <MessageAttachmentData>[]);

    when(
      () => messageService.sendReadMarker(
        any(),
        any(),
        chatType: any(named: 'chatType'),
      ),
    ).thenAnswer((_) async {});

    when(
      () => chatsService.sendTyping(
        jid: any(named: 'jid'),
        typing: any(named: 'typing'),
      ),
    ).thenAnswer((_) async {});

    when(
      () => chatsService.loadChatViewFilter(any()),
    ).thenAnswer((_) async => MessageTimelineFilter.directOnly);
    when(
      () => chatsService.saveChatViewFilter(
        jid: any(named: 'jid'),
        filter: any(named: 'filter'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => messageService.saveDraft(
        id: any(named: 'id'),
        jids: any(named: 'jids'),
        body: any(named: 'body'),
        quotingReferenceKind: any(named: 'quotingReferenceKind'),
        attachments: any(named: 'attachments'),
      ),
    ).thenAnswer(
      (_) async => Draft(
        id: 1,
        jids: const <String>[],
        draftSyncId: 'draft-1',
        draftUpdatedAt: DateTime(2024, 1, 1),
        draftSourceId: 'source-1',
      ),
    );
  });

  tearDown(() async {
    await messageStreamController.close();
    await chatStreamController.close();
  });

  final initialChat = Chat(
    jid: 'peer@axi.im',
    title: 'peer',
    type: ChatType.chat,
    lastChangeTimestamp: DateTime.now(),
  );

  test(
    'hydrates quoted messages by reference id within the active chat scope',
    () async {
      const quotedOriginId = 'quoted-origin-id';
      final quotedMessage = Message(
        stanzaID: 'quoted-local-stanza-id',
        originID: quotedOriginId,
        senderJid: initialChat.jid,
        chatJid: initialChat.jid,
        body: 'Original body',
        timestamp: DateTime.now(),
      );
      final replyMessage = Message(
        stanzaID: 'reply-stanza-id',
        senderJid: 'self@axi.im',
        chatJid: initialChat.jid,
        body: 'Reply body',
        quoting: quotedOriginId,
        timestamp: DateTime.now(),
      );

      when(
        () => messageService.loadMessageByReferenceId(
          quotedOriginId,
          chatJid: initialChat.jid,
        ),
      ).thenAnswer((_) async => quotedMessage);

      final bloc = ChatBloc(
        jid: initialChat.jid,
        messageService: messageService,
        chatsService: chatsService,
        mucService: mucService,
        notificationService: notificationService,
        emailService: null,
        settings: _defaultChatSettings(),
      );

      chatStreamController.add(initialChat);
      await _pumpBloc();
      messageStreamController.add(<Message>[replyMessage]);
      await _pumpBloc();
      await _pumpBloc();

      verify(
        () => messageService.loadMessageByReferenceId(
          quotedOriginId,
          chatJid: initialChat.jid,
        ),
      ).called(1);
      verifyNever(() => messageService.loadMessageByStanzaId(quotedOriginId));
      expect(
        bloc.state.quotedMessagesById[quotedOriginId]?.stanzaID,
        quotedMessage.stanzaID,
      );

      await bloc.close();
    },
  );

  test('fan-out send uses EmailService and records report state', () async {
    final emailService = MockEmailService();
    _mockEmailSync(emailService);
    final emailChat = initialChat.copyWith(
      deltaChatId: 1,
      emailAddress: 'peer@example.com',
    );
    final extraChat = Chat(
      jid: 'dc-2@delta.chat',
      title: 'carol',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.now(),
      deltaChatId: 2,
      emailAddress: 'carol@example.com',
    );
    final report = FanOutSendReport(
      shareId: 'share-123',
      statuses: [
        FanOutRecipientStatus(
          chat: emailChat,
          state: FanOutRecipientState.sent,
          deltaMsgId: 101,
        ),
        FanOutRecipientStatus(
          chat: extraChat,
          state: FanOutRecipientState.sent,
          deltaMsgId: 102,
        ),
      ],
    );

    when(
      () => emailService.fanOutSend(
        targets: any(named: 'targets'),
        body: any(named: 'body'),
        attachment: any(named: 'attachment'),
        shareId: any(named: 'shareId'),
        quotedStanzaId: any(named: 'quotedStanzaId'),
        useSubjectToken: any(named: 'useSubjectToken'),
      ),
    ).thenAnswer((_) async => report);

    final bloc = ChatBloc(
      jid: emailChat.jid,
      messageService: messageService,
      chatsService: chatsService,
      mucService: mucService,
      notificationService: notificationService,
      emailService: emailService,
      settings: _defaultChatSettings(),
    );

    messageStreamController.add(const <Message>[]);
    chatStreamController.add(emailChat);
    await _pumpBloc();

    final recipients = <ComposerRecipient>[
      ComposerRecipient(
        target: Contact.chat(chat: emailChat, shareSignatureEnabled: true),
      ),
      ComposerRecipient(
        target: Contact.chat(chat: extraChat, shareSignatureEnabled: true),
      ),
    ];
    bloc.add(
      _messageSent(
        chat: emailChat,
        text: 'Team status update',
        recipients: recipients,
        settings: _defaultChatSettings(),
      ),
    );
    await _pumpBloc();

    final capturedTargets =
        verify(
              () => emailService.fanOutSend(
                targets: captureAny(named: 'targets'),
                body: 'Team status update',
                attachment: any(named: 'attachment'),
                shareId: any(named: 'shareId'),
                quotedStanzaId: any(named: 'quotedStanzaId'),
                useSubjectToken: any(named: 'useSubjectToken'),
              ),
            ).captured.single
            as List<Contact>;

    expect(capturedTargets.map((target) => target.key).toSet(), {
      emailChat.jid,
      extraChat.jid,
    });
    expect(bloc.state.fanOutReports[report.shareId], report);
    expect(bloc.state.fanOutDrafts[report.shareId]?.body, 'Team status update');

    await bloc.close();
  });

  test('fan-out uses normalized address keys', () async {
    final emailService = MockEmailService();
    _mockEmailSync(emailService);
    final emailChat = initialChat.copyWith(
      deltaChatId: 1,
      emailAddress: 'peer@example.com',
    );
    final typedChat = Chat(
      jid: 'dc-2@delta.chat',
      title: 'Carol',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.now(),
      deltaChatId: 2,
      emailAddress: 'carol@example.com',
    );
    final report = FanOutSendReport(
      shareId: 'share-456',
      statuses: [
        FanOutRecipientStatus(
          chat: emailChat,
          state: FanOutRecipientState.sent,
          deltaMsgId: 201,
        ),
        FanOutRecipientStatus(
          chat: typedChat,
          state: FanOutRecipientState.sent,
          deltaMsgId: 202,
        ),
      ],
    );

    when(
      () => emailService.fanOutSend(
        targets: any(named: 'targets'),
        body: any(named: 'body'),
        attachment: any(named: 'attachment'),
        shareId: any(named: 'shareId'),
        quotedStanzaId: any(named: 'quotedStanzaId'),
        useSubjectToken: any(named: 'useSubjectToken'),
      ),
    ).thenAnswer((_) async => report);

    final bloc = ChatBloc(
      jid: emailChat.jid,
      messageService: messageService,
      chatsService: chatsService,
      mucService: mucService,
      notificationService: notificationService,
      emailService: emailService,
      settings: _defaultChatSettings(),
    );

    messageStreamController.add(const <Message>[]);
    chatStreamController.add(emailChat);
    await _pumpBloc();

    final recipients = <ComposerRecipient>[
      ComposerRecipient(
        target: Contact.chat(chat: emailChat, shareSignatureEnabled: true),
      ),
      ComposerRecipient(
        target: Contact.address(
          address: 'Carol@Example.com',
          shareSignatureEnabled: true,
        ),
      ),
    ];
    bloc.add(
      _messageSent(
        chat: emailChat,
        text: 'Hello world',
        recipients: recipients,
        settings: _defaultChatSettings(),
      ),
    );
    await _pumpBloc();

    final capturedTargets =
        verify(
              () => emailService.fanOutSend(
                targets: captureAny(named: 'targets'),
                body: 'Hello world',
                attachment: any(named: 'attachment'),
                shareId: any(named: 'shareId'),
                quotedStanzaId: any(named: 'quotedStanzaId'),
                useSubjectToken: any(named: 'useSubjectToken'),
              ),
            ).captured.single
            as List<Contact>;
    expect(capturedTargets.map((target) => target.key).toSet(), {
      emailChat.jid,
      'carol@example.com',
    });

    await bloc.close();
  });

  test('prevents send when no recipients are selected', () async {
    final emailService = MockEmailService();
    _mockEmailSync(emailService);
    final emailChat = initialChat.copyWith(
      deltaChatId: 1,
      emailAddress: 'peer@example.com',
    );

    final bloc = ChatBloc(
      jid: emailChat.jid,
      messageService: messageService,
      chatsService: chatsService,
      mucService: mucService,
      notificationService: notificationService,
      emailService: emailService,
      settings: _defaultChatSettings(),
    );

    messageStreamController.add(const <Message>[]);
    chatStreamController.add(emailChat);
    await _pumpBloc();

    bloc.add(
      _messageSent(
        chat: emailChat,
        text: 'Hello world',
        recipients: const <ComposerRecipient>[],
        settings: _defaultChatSettings(),
      ),
    );
    await _pumpBloc();

    expect(
      bloc.state.composerError,
      ChatMessageKey.chatComposerSelectRecipient,
    );
    verifyNever(
      () => emailService.fanOutSend(
        targets: any(named: 'targets'),
        body: any(named: 'body'),
        attachment: any(named: 'attachment'),
        shareId: any(named: 'shareId'),
        quotedStanzaId: any(named: 'quotedStanzaId'),
        useSubjectToken: any(named: 'useSubjectToken'),
      ),
    );

    await bloc.close();
  });

  test('surface FanOutValidationException messages to the UI', () async {
    final emailService = MockEmailService();
    _mockEmailSync(emailService);
    final emailChat = initialChat.copyWith(
      deltaChatId: 1,
      emailAddress: 'peer@example.com',
    );
    final extraChat = Chat(
      jid: 'dc-2@delta.chat',
      title: 'carol',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.now(),
      deltaChatId: 2,
      emailAddress: 'carol@example.com',
    );

    when(
      () => emailService.fanOutSend(
        targets: any(named: 'targets'),
        body: any(named: 'body'),
        attachment: any(named: 'attachment'),
        shareId: any(named: 'shareId'),
        quotedStanzaId: any(named: 'quotedStanzaId'),
        useSubjectToken: any(named: 'useSubjectToken'),
      ),
    ).thenThrow(const FanOutTooManyRecipientsException(2));

    final bloc = ChatBloc(
      jid: emailChat.jid,
      messageService: messageService,
      chatsService: chatsService,
      mucService: mucService,
      notificationService: notificationService,
      emailService: emailService,
      settings: _defaultChatSettings(),
    );

    messageStreamController.add(const <Message>[]);
    chatStreamController.add(emailChat);
    await _pumpBloc();

    final recipients = <ComposerRecipient>[
      ComposerRecipient(
        target: Contact.chat(chat: emailChat, shareSignatureEnabled: true),
      ),
      ComposerRecipient(
        target: Contact.chat(chat: extraChat, shareSignatureEnabled: true),
      ),
    ];
    bloc.add(
      _messageSent(
        chat: emailChat,
        text: 'Weekly sync',
        recipients: recipients,
        settings: _defaultChatSettings(),
      ),
    );
    await _pumpBloc();

    expect(
      bloc.state.composerError,
      ChatMessageKey.fanOutErrorTooManyRecipients,
    );

    await bloc.close();
  });

  test('retry event replays only failed recipients', () async {
    final emailService = MockEmailService();
    _mockEmailSync(emailService);
    final emailChat = initialChat.copyWith(
      deltaChatId: 1,
      emailAddress: 'peer@example.com',
    );
    final extraChat = Chat(
      jid: 'dc-2@delta.chat',
      title: 'carol',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.now(),
      deltaChatId: 2,
      emailAddress: 'carol@example.com',
    );

    final failureReport = FanOutSendReport(
      shareId: 'share-abc',
      statuses: [
        FanOutRecipientStatus(
          chat: emailChat,
          state: FanOutRecipientState.sent,
          deltaMsgId: 101,
        ),
        FanOutRecipientStatus(
          chat: extraChat,
          state: FanOutRecipientState.failed,
        ),
      ],
    );
    final successReport = FanOutSendReport(
      shareId: failureReport.shareId,
      statuses: [
        FanOutRecipientStatus(
          chat: extraChat,
          state: FanOutRecipientState.sent,
          deltaMsgId: 202,
        ),
      ],
    );

    final responses = <FanOutSendReport>[failureReport, successReport];
    final capturedTargets = <List<Contact>>[];
    final capturedShareIds = <String?>[];
    when(
      () => emailService.fanOutSend(
        targets: any(named: 'targets'),
        body: any(named: 'body'),
        attachment: any(named: 'attachment'),
        shareId: any(named: 'shareId'),
        quotedStanzaId: any(named: 'quotedStanzaId'),
        useSubjectToken: any(named: 'useSubjectToken'),
      ),
    ).thenAnswer((invocation) async {
      capturedTargets.add(
        List<Contact>.from(invocation.namedArguments[#targets] as List),
      );
      capturedShareIds.add(invocation.namedArguments[#shareId] as String?);
      return responses.removeAt(0);
    });

    final bloc = ChatBloc(
      jid: emailChat.jid,
      messageService: messageService,
      chatsService: chatsService,
      mucService: mucService,
      notificationService: notificationService,
      emailService: emailService,
      settings: _defaultChatSettings(),
    );

    messageStreamController.add(const <Message>[]);
    chatStreamController.add(emailChat);
    await _pumpBloc();
    final recipients = <ComposerRecipient>[
      ComposerRecipient(
        target: Contact.chat(chat: emailChat, shareSignatureEnabled: true),
      ),
      ComposerRecipient(
        target: Contact.chat(chat: extraChat, shareSignatureEnabled: true),
      ),
    ];
    bloc.add(
      _messageSent(
        chat: emailChat,
        text: 'Initial send',
        recipients: recipients,
        settings: _defaultChatSettings(),
      ),
    );
    await _pumpBloc();

    final retryDraft = bloc.state.fanOutDrafts[failureReport.shareId]!;
    final retryRecipients = <ComposerRecipient>[
      ComposerRecipient(
        target: Contact.chat(chat: extraChat, shareSignatureEnabled: true),
        included: true,
      ),
    ];
    bloc.add(
      ChatFanOutRetryRequested(
        draft: retryDraft,
        recipients: retryRecipients,
        chat: emailChat,
        settings: _defaultChatSettings(),
      ),
    );
    await _pumpBloc();

    expect(capturedTargets.length, 2);
    expect(capturedTargets[1].map((target) => target.key), [extraChat.jid]);
    expect(capturedShareIds.every((id) => id == failureReport.shareId), isTrue);

    await bloc.close();
  });

  test('queued attachment sends when composer dispatches send', () async {
    final emailService = MockEmailService();
    _mockEmailSync(emailService);
    final emailChat = initialChat.copyWith(
      deltaChatId: 1,
      emailAddress: 'peer@example.com',
    );
    const attachment = EmailAttachment(
      path: '/tmp/file.txt',
      fileName: 'file.txt',
      sizeBytes: 2048,
      mimeType: 'text/plain',
    );
    final sendCompleter = Completer<void>();
    when(
      () => emailService.sendAttachment(
        chat: any(named: 'chat'),
        attachment: any(named: 'attachment'),
      ),
    ).thenAnswer((_) => sendCompleter.future.then((_) => 1));

    final bloc = ChatBloc(
      jid: emailChat.jid,
      messageService: messageService,
      chatsService: chatsService,
      mucService: mucService,
      notificationService: notificationService,
      emailService: emailService,
      settings: _defaultChatSettings(),
    );

    messageStreamController.add(const <Message>[]);
    chatStreamController.add(emailChat);
    await _pumpBloc();

    final recipients = <ComposerRecipient>[
      ComposerRecipient(
        target: Contact.chat(chat: emailChat, shareSignatureEnabled: true),
      ),
    ];
    final pickCompleter = Completer<PendingAttachment?>();
    bloc.add(
      ChatAttachmentPicked(
        attachment: attachment,
        recipients: recipients,
        chat: emailChat,
        quotedDraft: null,
        completer: pickCompleter,
      ),
    );
    await _pumpBloc();
    final picked = await pickCompleter.future;
    expect(picked, isNotNull);
    final pending = picked!;
    expect(pending.attachment, attachment);
    expect(pending.status, PendingAttachmentStatus.queued);
    verifyNever(
      () => emailService.sendAttachment(
        chat: any(named: 'chat'),
        attachment: any(named: 'attachment'),
      ),
    );

    final sendEventCompleter = Completer<List<PendingAttachment>>();
    bloc.add(
      _messageSent(
        chat: emailChat,
        text: 'Hello',
        recipients: recipients,
        pendingAttachments: [pending],
        settings: _defaultChatSettings(),
        completer: sendEventCompleter,
      ),
    );
    await _pumpBloc();
    expect(sendEventCompleter.isCompleted, isFalse);

    sendCompleter.complete();
    await _pumpBloc();
    expect(await sendEventCompleter.future, isEmpty);

    await bloc.close();
  });

  test('failed attachment can be retried', () async {
    final emailService = MockEmailService();
    _mockEmailSync(emailService);
    final emailChat = initialChat.copyWith(
      deltaChatId: 1,
      emailAddress: 'peer@example.com',
    );
    const attachment = EmailAttachment(
      path: '/tmp/error.txt',
      fileName: 'error.txt',
      sizeBytes: 512,
      mimeType: 'text/plain',
    );
    var attempts = 0;
    when(
      () => emailService.sendAttachment(
        chat: any(named: 'chat'),
        attachment: any(named: 'attachment'),
      ),
    ).thenAnswer((_) async {
      attempts++;
      if (attempts == 1) {
        throw const DeltaAttachmentTooLargeException(
          operation: 'send email attachment',
          message: 'failed to send',
        );
      }
      return 1;
    });

    final bloc = ChatBloc(
      jid: emailChat.jid,
      messageService: messageService,
      chatsService: chatsService,
      mucService: mucService,
      notificationService: notificationService,
      emailService: emailService,
      settings: _defaultChatSettings(),
    );

    messageStreamController.add(const <Message>[]);
    chatStreamController.add(emailChat);
    await _pumpBloc();

    final recipients = <ComposerRecipient>[
      ComposerRecipient(
        target: Contact.chat(chat: emailChat, shareSignatureEnabled: true),
      ),
    ];
    final pickCompleter = Completer<PendingAttachment?>();
    bloc.add(
      ChatAttachmentPicked(
        attachment: attachment,
        recipients: recipients,
        chat: emailChat,
        quotedDraft: null,
        completer: pickCompleter,
      ),
    );
    await _pumpBloc();
    final picked = await pickCompleter.future;
    expect(picked, isNotNull);
    final pending = picked!;
    expect(pending.status, PendingAttachmentStatus.queued);

    final sendEventCompleter = Completer<List<PendingAttachment>>();
    bloc.add(
      _messageSent(
        chat: emailChat,
        text: '',
        recipients: recipients,
        pendingAttachments: [pending],
        settings: _defaultChatSettings(),
        completer: sendEventCompleter,
      ),
    );
    await _pumpBloc();
    final failedAttachments = await sendEventCompleter.future;
    final failed = failedAttachments.single;
    expect(failed.status, PendingAttachmentStatus.failed);
    expect(failed.errorMessage, isNotEmpty);
    expect(attempts, 1);

    final retryCompleter = Completer<PendingAttachment?>();
    bloc.add(
      ChatAttachmentRetryRequested(
        attachment: failed,
        recipients: recipients,
        chat: emailChat,
        quotedDraft: null,
        subject: null,
        settings: _defaultChatSettings(),
        supportsHttpFileUpload: false,
        completer: retryCompleter,
      ),
    );
    await _pumpBloc();
    expect(await retryCompleter.future, isNull);
    expect(attempts, 2);

    await bloc.close();
  });

  test('email sync status updates composer error', () async {
    final emailService = MockEmailService();
    _mockEmailSync(emailService);
    final syncController = StreamController<EmailSyncState>.broadcast();
    when(
      () => emailService.syncStateStream,
    ).thenAnswer((_) => syncController.stream);
    when(() => emailService.syncState).thenReturn(const EmailSyncState.ready());
    final emailChat = initialChat.copyWith(
      deltaChatId: 1,
      emailAddress: 'peer@example.com',
    );

    final bloc = ChatBloc(
      jid: emailChat.jid,
      messageService: messageService,
      chatsService: chatsService,
      mucService: mucService,
      notificationService: notificationService,
      emailService: emailService,
      settings: _defaultChatSettings(),
    );

    messageStreamController.add(const <Message>[]);
    chatStreamController.add(emailChat);
    await _pumpBloc();

    syncController.add(const EmailSyncState.offline('Network down'));
    await _pumpBloc();
    expect(
      bloc.state.composerError,
      ChatMessageKey.messageErrorServiceUnavailable,
    );

    syncController.add(const EmailSyncState.ready());
    await _pumpBloc();
    expect(bloc.state.composerError, isNull);

    await bloc.close();
    await syncController.close();
  });

  test('forwarding supports a raw XMPP address target', () async {
    final syntheticForwardSubject = markSyntheticForwardSubject(
      'FWD: peer@axi.im',
    );
    final message = Message(
      stanzaID: 'forward-xmpp',
      senderJid: initialChat.jid,
      chatJid: initialChat.jid,
      body: 'Forward me',
      timestamp: DateTime.now(),
    );
    when(
      () => messageService.sendMessage(
        jid: any(named: 'jid'),
        text: any(named: 'text'),
        encryptionProtocol: EncryptionProtocol.none,
        htmlBody: any(named: 'htmlBody'),
        forwarded: true,
        forwardedFromJid: any(named: 'forwardedFromJid'),
        chatType: ChatType.chat,
      ),
    ).thenAnswer((_) async {});

    final bloc = ChatBloc(
      jid: initialChat.jid,
      messageService: messageService,
      chatsService: chatsService,
      mucService: mucService,
      notificationService: notificationService,
      settings: _defaultChatSettings(),
    );

    chatStreamController.add(initialChat);
    messageStreamController.add(const <Message>[]);
    await _pumpBloc();

    bloc.add(
      ChatMessageForwardRequested(
        message: message,
        target: Contact.address(
          address: 'fresh@axi.im',
          shareSignatureEnabled: true,
          transport: MessageTransport.xmpp,
        ),
      ),
    );
    await _pumpBloc();

    verify(
      () => messageService.sendMessage(
        jid: 'fresh@axi.im',
        text: ChatSubjectCodec.composeXmppBody(
          body: 'Forward me',
          subject: syntheticForwardSubject,
        ),
        encryptionProtocol: EncryptionProtocol.none,
        htmlBody:
            '${HtmlContentCodec.fromPlainText('FWD: peer@axi.im')}<br />\n<br />\nForward me',
        forwarded: true,
        forwardedFromJid: initialChat.jid,
        chatType: ChatType.chat,
      ),
    ).called(1);

    await bloc.close();
  });

  test('sending supports a raw XMPP address target', () async {
    when(
      () => messageService.sendMessage(
        jid: 'fresh@axi.im',
        text: 'Hello raw XMPP',
        encryptionProtocol: EncryptionProtocol.none,
        quotedMessage: any(named: 'quotedMessage'),
        calendarTaskIcs: any(named: 'calendarTaskIcs'),
        calendarTaskIcsReadOnly: any(named: 'calendarTaskIcsReadOnly'),
        chatType: ChatType.chat,
        onLocalMessageStored: any(named: 'onLocalMessageStored'),
      ),
    ).thenAnswer((_) async {});

    final bloc = ChatBloc(
      jid: initialChat.jid,
      messageService: messageService,
      chatsService: chatsService,
      mucService: mucService,
      notificationService: notificationService,
      settings: _defaultChatSettings(),
    );

    chatStreamController.add(initialChat);
    messageStreamController.add(const <Message>[]);
    await _pumpBloc();

    bloc.add(
      _messageSent(
        chat: initialChat,
        text: 'Hello raw XMPP',
        recipients: [
          ComposerRecipient(
            target: Contact.address(
              address: 'fresh@axi.im',
              shareSignatureEnabled: true,
              transport: MessageTransport.xmpp,
            ),
          ),
        ],
        settings: _defaultChatSettings(),
      ),
    );
    await _pumpBloc();

    verify(
      () => messageService.sendMessage(
        jid: 'fresh@axi.im',
        text: 'Hello raw XMPP',
        encryptionProtocol: EncryptionProtocol.none,
        quotedMessage: any(named: 'quotedMessage'),
        calendarTaskIcs: any(named: 'calendarTaskIcs'),
        calendarTaskIcsReadOnly: any(named: 'calendarTaskIcsReadOnly'),
        chatType: ChatType.chat,
        onLocalMessageStored: any(named: 'onLocalMessageStored'),
      ),
    ).called(1);

    verifyNever(
      () => messageService.sendMessage(
        jid: initialChat.jid,
        text: any(named: 'text'),
        encryptionProtocol: any(named: 'encryptionProtocol'),
        quotedMessage: any(named: 'quotedMessage'),
        calendarTaskIcs: any(named: 'calendarTaskIcs'),
        calendarTaskIcsReadOnly: any(named: 'calendarTaskIcsReadOnly'),
        chatType: any(named: 'chatType'),
        onLocalMessageStored: any(named: 'onLocalMessageStored'),
      ),
    );

    await bloc.close();
  });

  test('forwarding supports a raw email address target', () async {
    const syntheticForwardSubject = 'FWD: peer@axi.im';
    final emailService = MockEmailService();
    _mockEmailSync(emailService);
    final message = Message(
      stanzaID: 'forward-email',
      senderJid: initialChat.jid,
      chatJid: initialChat.jid,
      body: 'Forward me by email',
      timestamp: DateTime.now(),
    );
    final resolvedEmailChat = Chat(
      jid: 'dc-fresh@delta.chat',
      title: 'fresh@example.com',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.now(),
      deltaChatId: 10,
      emailAddress: 'fresh@example.com',
    );
    when(
      () => emailService.ensureChatForAddress(
        address: any(named: 'address'),
        displayName: any(named: 'displayName'),
      ),
    ).thenAnswer((_) async => resolvedEmailChat);
    when(
      () => emailService.sendMessage(
        chat: any(named: 'chat'),
        body: any(named: 'body'),
        subject: any(named: 'subject'),
        htmlBody: any(named: 'htmlBody'),
        forwarded: any(named: 'forwarded'),
        forwardedFromJid: any(named: 'forwardedFromJid'),
      ),
    ).thenAnswer((_) async => 1);

    final bloc = ChatBloc(
      jid: initialChat.jid,
      messageService: messageService,
      chatsService: chatsService,
      mucService: mucService,
      notificationService: notificationService,
      emailService: emailService,
      settings: _defaultChatSettings(),
    );

    chatStreamController.add(initialChat);
    messageStreamController.add(const <Message>[]);
    await _pumpBloc();

    bloc.add(
      ChatMessageForwardRequested(
        message: message,
        target: Contact.address(
          address: 'fresh@example.com',
          shareSignatureEnabled: true,
          transport: MessageTransport.email,
        ),
      ),
    );
    await _pumpBloc();

    verify(
      () => emailService.ensureChatForAddress(
        address: 'fresh@example.com',
        displayName: 'fresh@example.com',
      ),
    ).called(1);
    verify(
      () => emailService.sendMessage(
        chat: resolvedEmailChat,
        body: 'Forward me by email',
        subject: syntheticForwardSubject,
        htmlBody: injectSyntheticForwardHtmlMarker('Forward me by email'),
        forwarded: true,
        forwardedFromJid: initialChat.jid,
      ),
    ).called(1);

    await bloc.close();
  });

  test(
    'raw email reply fan-out synthesizes a visible reply envelope',
    () async {
      final emailService = MockEmailService();
      _mockEmailSync(emailService);
      final report = FanOutSendReport(
        shareId: 'reply-share',
        statuses: [
          FanOutRecipientStatus(
            chat: Chat(
              jid: 'dc-fresh@delta.chat',
              title: 'fresh@example.com',
              type: ChatType.chat,
              lastChangeTimestamp: DateTime.now(),
              deltaChatId: 88,
              emailAddress: 'fresh@example.com',
            ),
            state: FanOutRecipientState.sent,
            deltaMsgId: 301,
          ),
        ],
      );
      when(
        () => emailService.fanOutSend(
          targets: any(named: 'targets'),
          body: any(named: 'body'),
          htmlBody: any(named: 'htmlBody'),
          attachment: any(named: 'attachment'),
          htmlCaption: any(named: 'htmlCaption'),
          shareId: any(named: 'shareId'),
          subject: any(named: 'subject'),
          quotedStanzaId: any(named: 'quotedStanzaId'),
          useSubjectToken: any(named: 'useSubjectToken'),
          tokenAsSignature: any(named: 'tokenAsSignature'),
        ),
      ).thenAnswer((_) async => report);

      final bloc = ChatBloc(
        jid: initialChat.jid,
        messageService: messageService,
        chatsService: chatsService,
        mucService: mucService,
        notificationService: notificationService,
        emailService: emailService,
        settings: _defaultChatSettings(),
      );

      chatStreamController.add(initialChat);
      messageStreamController.add(const <Message>[]);
      await _pumpBloc();

      final quotedMessage = Message(
        stanzaID: 'quoted-reply-email',
        senderJid: 'peer@axi.im',
        chatJid: initialChat.jid,
        body: ChatSubjectCodec.composeXmppBody(
          body: 'Original body',
          subject: 'Original subject',
        ),
        timestamp: DateTime.now(),
      );
      final syntheticReply = syntheticReplyEnvelope(
        body: 'Reply body',
        subject: null,
        quotedSubject: 'Original subject',
        quotedBody: 'Original body',
        quotedSenderLabel: 'peer@axi.im',
      );

      bloc.add(
        _messageSent(
          chat: initialChat,
          text: 'Reply body',
          recipients: [
            ComposerRecipient(
              target: Contact.address(
                address: 'fresh@example.com',
                shareSignatureEnabled: true,
                transport: MessageTransport.email,
              ),
            ),
          ],
          settings: _defaultChatSettings(),
          quotedDraft: quotedMessage,
        ),
      );
      await _pumpBloc();

      verify(
        () => emailService.fanOutSend(
          targets: any(named: 'targets'),
          body: syntheticReply.body,
          htmlBody: HtmlContentCodec.fromPlainText(syntheticReply.body),
          attachment: null,
          htmlCaption: null,
          shareId: any(named: 'shareId'),
          subject: syntheticReply.subject,
          quotedStanzaId: quotedMessage.stanzaID,
          useSubjectToken: true,
          tokenAsSignature: true,
        ),
      ).called(1);
      expect(
        bloc.state.fanOutDrafts[report.shareId]?.quotedStanzaId,
        quotedMessage.stanzaID,
      );

      await bloc.close();
    },
  );

  test(
    'saves XMPP drafts with origin-id quoted references after a send failure',
    () async {
      final quotedMessage = Message(
        stanzaID: 'quoted-local-stanza-id',
        originID: 'quoted-origin-id',
        senderJid: initialChat.jid,
        chatJid: initialChat.jid,
        body: 'Original body',
        timestamp: DateTime.now(),
      );
      when(
        () => messageService.sendMessage(
          jid: initialChat.jid,
          text: 'Reply body',
          encryptionProtocol: EncryptionProtocol.none,
          htmlBody: any(named: 'htmlBody'),
          quotedMessage: quotedMessage,
          chatType: ChatType.chat,
          onLocalMessageStored: any(named: 'onLocalMessageStored'),
        ),
      ).thenThrow(xmpp.XmppMessageException());

      final bloc = ChatBloc(
        jid: initialChat.jid,
        messageService: messageService,
        chatsService: chatsService,
        mucService: mucService,
        notificationService: notificationService,
        settings: _defaultChatSettings(),
      );

      chatStreamController.add(initialChat);
      messageStreamController.add(const <Message>[]);
      await _pumpBloc();

      bloc.add(
        _messageSent(
          chat: initialChat,
          text: 'Reply body',
          recipients: [
            ComposerRecipient(
              target: Contact.chat(
                chat: initialChat,
                shareSignatureEnabled: true,
              ),
            ),
          ],
          settings: _defaultChatSettings(),
          quotedDraft: quotedMessage,
        ),
      );
      await _pumpBloc();
      await _pumpBloc();

      verify(
        () => messageService.saveDraft(
          id: null,
          jids: [initialChat.jid],
          body: 'Reply body',
          subject: null,
          quotingStanzaId: quotedMessage.originID,
          quotingReferenceKind: MessageReferenceKind.originId,
          attachments: const <EmailAttachment>[],
        ),
      ).called(1);

      await bloc.close();
    },
  );

  test('synthetic XMPP forwarding preserves original subject and HTML', () async {
    final syntheticForwardSubject = markSyntheticForwardSubject(
      'FWD: peer@axi.im',
    );
    final message = Message(
      stanzaID: 'forward-xmpp-html',
      senderJid: initialChat.jid,
      chatJid: initialChat.jid,
      body: ChatSubjectCodec.composeXmppBody(
        body: 'Bold body',
        subject: 'Original subject',
      ),
      htmlBody: '<p><strong>Bold body</strong></p>',
      timestamp: DateTime.now(),
    );
    when(
      () => messageService.sendMessage(
        jid: any(named: 'jid'),
        text: any(named: 'text'),
        encryptionProtocol: EncryptionProtocol.none,
        htmlBody: any(named: 'htmlBody'),
        forwarded: true,
        forwardedFromJid: any(named: 'forwardedFromJid'),
        chatType: ChatType.chat,
      ),
    ).thenAnswer((_) async {});

    final bloc = ChatBloc(
      jid: initialChat.jid,
      messageService: messageService,
      chatsService: chatsService,
      mucService: mucService,
      notificationService: notificationService,
      settings: _defaultChatSettings(),
    );

    chatStreamController.add(initialChat);
    messageStreamController.add(const <Message>[]);
    await _pumpBloc();

    bloc.add(
      ChatMessageForwardRequested(
        message: message,
        target: Contact.address(
          address: 'fresh@axi.im',
          shareSignatureEnabled: true,
          transport: MessageTransport.xmpp,
        ),
      ),
    );
    await _pumpBloc();

    verify(
      () => messageService.sendMessage(
        jid: 'fresh@axi.im',
        text: ChatSubjectCodec.composeXmppBody(
          body: 'Subject: Original subject\n\nBold body',
          subject: syntheticForwardSubject,
        ),
        encryptionProtocol: EncryptionProtocol.none,
        htmlBody:
            '${HtmlContentCodec.fromPlainText('FWD: peer@axi.im')}<br />\n<br />\n'
            '${HtmlContentCodec.fromPlainText('Subject: Original subject')}<br />\n<br />\n'
            '<p><strong>Bold body</strong></p>',
        forwarded: true,
        forwardedFromJid: initialChat.jid,
        chatType: ChatType.chat,
      ),
    ).called(1);

    await bloc.close();
  });

  test('offline email send attempts send and does not save drafts', () async {
    final emailService = MockEmailService();
    _mockEmailSync(emailService);
    when(
      () => emailService.syncState,
    ).thenReturn(const EmailSyncState.offline('offline'));
    when(
      () => emailService.syncStateStream,
    ).thenAnswer((_) => const Stream<EmailSyncState>.empty());
    when(
      () => emailService.sendMessage(
        chat: any(named: 'chat'),
        body: any(named: 'body'),
        subject: any(named: 'subject'),
        htmlBody: any(named: 'htmlBody'),
      ),
    ).thenThrow(
      const DeltaNetworkException(
        operation: 'send email message',
        message: 'offline',
      ),
    );
    final emailChat = initialChat.copyWith(
      deltaChatId: 4,
      emailAddress: 'ally@example.com',
    );

    final bloc = ChatBloc(
      jid: emailChat.jid,
      messageService: messageService,
      chatsService: chatsService,
      mucService: mucService,
      notificationService: notificationService,
      emailService: emailService,
      settings: _defaultChatSettings(),
    );

    chatStreamController.add(emailChat);
    messageStreamController.add(const <Message>[]);
    await _pumpBloc();

    final recipients = <ComposerRecipient>[
      ComposerRecipient(
        target: Contact.chat(chat: emailChat, shareSignatureEnabled: true),
      ),
    ];
    bloc.add(
      _messageSent(
        chat: emailChat,
        text: 'Offline draft',
        recipients: recipients,
        settings: _defaultChatSettings(),
      ),
    );
    await _pumpBloc();

    verify(
      () => emailService.sendMessage(
        chat: any(named: 'chat'),
        body: any(named: 'body'),
        subject: any(named: 'subject'),
        htmlBody: any(named: 'htmlBody'),
      ),
    ).called(1);
    verifyNever(
      () => messageService.saveDraft(
        id: null,
        jids: any(named: 'jids'),
        body: any(named: 'body'),
        quotingReferenceKind: any(named: 'quotingReferenceKind'),
        attachments: any(named: 'attachments'),
      ),
    );

    await bloc.close();
  });

  test('skips MAM hydrate when local window already cached', () async {
    when(
      () => messageService.countLocalMessages(
        jid: any(named: 'jid'),
        filter: any(named: 'filter'),
        includePseudoMessages: any(named: 'includePseudoMessages'),
      ),
    ).thenAnswer((_) async => ChatBloc.messageBatchSize);

    when(
      () => messageService.fetchLatestFromArchive(
        jid: any(named: 'jid'),
        pageSize: any(named: 'pageSize'),
        isMuc: any(named: 'isMuc'),
      ),
    ).thenAnswer((_) async => const xmpp.MamPageResult(complete: true));

    final bloc = ChatBloc(
      jid: initialChat.jid,
      messageService: messageService,
      chatsService: chatsService,
      mucService: mucService,
      notificationService: notificationService,
      settings: _defaultChatSettings(),
    );

    chatStreamController.add(initialChat);
    messageStreamController.add(const <Message>[]);
    await _pumpBloc();

    verifyNever(
      () => messageService.fetchLatestFromArchive(
        jid: any(named: 'jid'),
        pageSize: any(named: 'pageSize'),
        isMuc: any(named: 'isMuc'),
      ),
    );

    await bloc.close();
  });

  test('loads earlier via MAM when local history is short', () async {
    final counts = Queue<int>.from([0, 1, 1, 2]);

    when(
      () => messageService.countLocalMessages(
        jid: any(named: 'jid'),
        filter: any(named: 'filter'),
        includePseudoMessages: any(named: 'includePseudoMessages'),
      ),
    ).thenAnswer((_) async {
      if (counts.isEmpty) return 2;
      return counts.removeFirst();
    });

    when(
      () => messageService.fetchLatestFromArchive(
        jid: any(named: 'jid'),
        pageSize: any(named: 'pageSize'),
        isMuc: any(named: 'isMuc'),
      ),
    ).thenAnswer(
      (_) async => const xmpp.MamPageResult(
        complete: false,
        firstId: 'latest-1',
        lastId: 'latest-1',
        count: 2,
      ),
    );

    when(
      () => messageService.fetchBeforeFromArchive(
        jid: any(named: 'jid'),
        before: any(named: 'before'),
        pageSize: any(named: 'pageSize'),
        isMuc: any(named: 'isMuc'),
      ),
    ).thenAnswer(
      (_) async => const xmpp.MamPageResult(
        complete: true,
        firstId: 'earlier-1',
        lastId: 'earlier-1',
        count: 3,
      ),
    );

    final bloc = ChatBloc(
      jid: initialChat.jid,
      messageService: messageService,
      chatsService: chatsService,
      mucService: mucService,
      notificationService: notificationService,
      settings: _defaultChatSettings(),
    );

    chatStreamController.add(initialChat);
    messageStreamController.add(const <Message>[]);
    await _pumpBloc();
    await _pumpBloc();

    final completer = Completer<void>();
    bloc.add(ChatLoadEarlier(completer: completer));
    await completer.future;
    await _pumpBloc();

    verify(
      () => messageService.fetchBeforeFromArchive(
        jid: any(named: 'jid'),
        before: any(named: 'before'),
        pageSize: any(named: 'pageSize'),
        isMuc: any(named: 'isMuc'),
      ),
    ).called(1);

    await bloc.close();
  });

  test(
    'pinned message selection requests scroll when target is already loaded',
    () async {
      final message = Message(
        stanzaID: 'loaded-pin',
        senderJid: initialChat.jid,
        chatJid: initialChat.jid,
        timestamp: DateTime(2026, 1, 2, 12),
        body: 'Loaded pinned message',
      );

      final bloc = ChatBloc(
        jid: initialChat.jid,
        messageService: messageService,
        chatsService: chatsService,
        mucService: mucService,
        notificationService: notificationService,
        settings: _defaultChatSettings(),
      );

      chatStreamController.add(initialChat);
      await _pumpBloc();
      messageStreamController.add([message]);
      await _pumpBloc();
      await _pumpBloc();

      bloc.add(const ChatPinnedMessageSelected('loaded-pin'));
      await _pumpBloc();

      expect(bloc.state.scrollTargetMessageId, 'loaded-pin');
      expect(bloc.state.scrollTargetRequestId, 1);

      await bloc.close();
    },
  );

  test(
    'important message selection requests scroll when target is already loaded',
    () async {
      final message = Message(
        stanzaID: 'loaded-important',
        senderJid: initialChat.jid,
        chatJid: initialChat.jid,
        timestamp: DateTime(2026, 1, 2, 12),
        body: 'Loaded important message',
      );

      final bloc = ChatBloc(
        jid: initialChat.jid,
        messageService: messageService,
        chatsService: chatsService,
        mucService: mucService,
        notificationService: notificationService,
        settings: _defaultChatSettings(),
      );

      chatStreamController.add(initialChat);
      await _pumpBloc();
      messageStreamController.add([message]);
      await _pumpBloc();
      await _pumpBloc();

      bloc.add(const ChatImportantMessageSelected('loaded-important'));
      await _pumpBloc();

      expect(bloc.state.scrollTargetMessageId, 'loaded-important');
      expect(bloc.state.scrollTargetRequestId, 1);

      await bloc.close();
    },
  );

  test(
    'pinned message selection expands the filter window before scrolling',
    () async {
      final target = Message(
        stanzaID: 'filtered-pin',
        senderJid: initialChat.jid,
        chatJid: initialChat.jid,
        timestamp: DateTime(2026, 1, 1, 8),
        body: 'Pinned message outside the direct-only view',
      );
      when(
        () => messageService.loadMessageByStanzaId('filtered-pin'),
      ).thenAnswer((_) async => target);
      when(
        () => mockDatabase.countChatMessagesThrough(
          any(),
          throughTimestamp: any(named: 'throughTimestamp'),
          throughStanzaId: any(named: 'throughStanzaId'),
          throughDeltaMsgId: any(named: 'throughDeltaMsgId'),
          filter: MessageTimelineFilter.allWithContact,
        ),
      ).thenAnswer((_) async => 1);

      final bloc = ChatBloc(
        jid: initialChat.jid,
        messageService: messageService,
        chatsService: chatsService,
        mucService: mucService,
        notificationService: notificationService,
        settings: _defaultChatSettings(),
      );

      chatStreamController.add(initialChat);
      messageStreamController.add(const <Message>[]);
      await _pumpBloc();
      await _pumpBloc();

      bloc.add(const ChatPinnedMessageSelected('filtered-pin'));
      await _pumpBloc();
      expect(bloc.state.viewFilter, MessageTimelineFilter.allWithContact);

      messageStreamController.add([target]);
      await _pumpBloc();
      await _pumpBloc();

      expect(bloc.state.scrollTargetMessageId, 'filtered-pin');
      expect(bloc.state.scrollTargetRequestId, 1);
      verify(
        () => messageService.messageStreamForChat(
          any(),
          start: any(named: 'start'),
          end: any(named: 'end'),
          filter: MessageTimelineFilter.allWithContact,
        ),
      ).called(1);

      await bloc.close();
    },
  );

  test(
    'important message selection expands the filter window before scrolling',
    () async {
      final target = Message(
        stanzaID: 'filtered-important',
        senderJid: initialChat.jid,
        chatJid: initialChat.jid,
        timestamp: DateTime(2026, 1, 1, 8),
        body: 'Important message outside the direct-only view',
      );
      when(
        () => messageService.loadMessageByReferenceId(
          'filtered-important',
          chatJid: initialChat.jid,
        ),
      ).thenAnswer((_) async => target);
      when(
        () => mockDatabase.countChatMessagesThrough(
          any(),
          throughTimestamp: any(named: 'throughTimestamp'),
          throughStanzaId: any(named: 'throughStanzaId'),
          throughDeltaMsgId: any(named: 'throughDeltaMsgId'),
          filter: MessageTimelineFilter.allWithContact,
        ),
      ).thenAnswer((_) async => 1);

      final bloc = ChatBloc(
        jid: initialChat.jid,
        messageService: messageService,
        chatsService: chatsService,
        mucService: mucService,
        notificationService: notificationService,
        settings: _defaultChatSettings(),
      );

      chatStreamController.add(initialChat);
      messageStreamController.add(const <Message>[]);
      await _pumpBloc();
      await _pumpBloc();

      bloc.add(const ChatImportantMessageSelected('filtered-important'));
      await _pumpBloc();
      expect(bloc.state.viewFilter, MessageTimelineFilter.allWithContact);

      messageStreamController.add([target]);
      await _pumpBloc();
      await _pumpBloc();

      expect(bloc.state.scrollTargetMessageId, 'filtered-important');
      expect(bloc.state.scrollTargetRequestId, 1);

      await bloc.close();
    },
  );

  test(
    'pinned message selection backfills email history and requests scroll',
    () async {
      final emailService = MockEmailService();
      final emailMessageStreamController =
          StreamController<List<Message>>.broadcast();
      _mockEmailSync(emailService);

      final emailChat = initialChat.copyWith(
        deltaChatId: 4,
        emailAddress: 'peer@example.com',
        transport: MessageTransport.email,
      );
      final newest = Message(
        stanzaID: 'email-newest',
        senderJid: emailChat.jid,
        chatJid: emailChat.jid,
        timestamp: DateTime(2026, 1, 3, 10),
        body: 'Newest email message',
      );
      final target = Message(
        stanzaID: 'email-target',
        senderJid: emailChat.jid,
        chatJid: emailChat.jid,
        deltaMsgId: 25,
        timestamp: DateTime(2026, 1, 1, 9),
        body: 'Older pinned email message',
      );

      when(
        () => emailService.messageStreamForChat(
          any(),
          start: any(named: 'start'),
          end: any(named: 'end'),
          filter: any(named: 'filter'),
        ),
      ).thenAnswer((_) => emailMessageStreamController.stream);
      when(
        () => emailService.pinnedMessagesStream(any()),
      ).thenAnswer((_) => const Stream<List<PinnedMessageEntry>>.empty());
      when(
        () => emailService.backfillChatHistory(
          chat: any(named: 'chat'),
          desiredWindow: any(named: 'desiredWindow'),
          beforeMessageId: any(named: 'beforeMessageId'),
          beforeTimestamp: any(named: 'beforeTimestamp'),
          filter: any(named: 'filter'),
        ),
      ).thenAnswer((_) async {});

      var targetLookupCount = 0;
      when(() => messageService.loadMessageByStanzaId(any())).thenAnswer((
        invocation,
      ) async {
        final messageId = invocation.positionalArguments.first as String;
        if (messageId != target.stanzaID) {
          return null;
        }
        targetLookupCount += 1;
        return targetLookupCount >= 2 ? target : null;
      });

      var countCalls = 0;
      when(
        () => messageService.countLocalMessages(
          jid: any(named: 'jid'),
          filter: any(named: 'filter'),
          includePseudoMessages: any(named: 'includePseudoMessages'),
        ),
      ).thenAnswer((_) async {
        countCalls += 1;
        return countCalls >= 2 ? 2 : 1;
      });
      when(
        () => mockDatabase.countChatMessagesThrough(
          emailChat.jid,
          throughTimestamp: target.timestamp!,
          throughStanzaId: target.stanzaID,
          throughDeltaMsgId: target.deltaMsgId,
          filter: MessageTimelineFilter.allWithContact,
        ),
      ).thenAnswer((_) async => 75);

      final bloc = ChatBloc(
        jid: emailChat.jid,
        messageService: messageService,
        chatsService: chatsService,
        mucService: mucService,
        notificationService: notificationService,
        emailService: emailService,
        settings: _defaultChatSettings(),
      );

      chatStreamController.add(emailChat);
      await _pumpBloc();
      emailMessageStreamController.add([newest]);
      await _pumpBloc();
      await _pumpBloc();

      bloc.add(const ChatPinnedMessageSelected('email-target'));
      await _pumpBloc();

      verify(
        () => emailService.backfillChatHistory(
          chat: emailChat,
          desiredWindow: any(named: 'desiredWindow'),
          beforeMessageId: any(named: 'beforeMessageId'),
          beforeTimestamp: any(named: 'beforeTimestamp'),
          filter: MessageTimelineFilter.allWithContact,
        ),
      ).called(1);
      verify(
        () => emailService.messageStreamForChat(
          emailChat.jid,
          start: any(named: 'start'),
          end: 75,
          filter: MessageTimelineFilter.allWithContact,
        ),
      ).called(1);

      emailMessageStreamController.add([newest, target]);
      await _pumpBloc();

      expect(bloc.state.scrollTargetMessageId, 'email-target');
      expect(bloc.state.scrollTargetRequestId, 1);

      await bloc.close();
      await emailMessageStreamController.close();
    },
  );

  test(
    'important message selection backfills email history and requests scroll',
    () async {
      final emailService = MockEmailService();
      final emailMessageStreamController =
          StreamController<List<Message>>.broadcast();
      _mockEmailSync(emailService);

      final emailChat = initialChat.copyWith(
        deltaChatId: 4,
        emailAddress: 'peer@example.com',
        transport: MessageTransport.email,
      );
      final newest = Message(
        stanzaID: 'email-newest',
        senderJid: emailChat.jid,
        chatJid: emailChat.jid,
        timestamp: DateTime(2026, 1, 3, 10),
        body: 'Newest email message',
      );
      final target = Message(
        stanzaID: 'email-important-target',
        senderJid: emailChat.jid,
        chatJid: emailChat.jid,
        deltaMsgId: 25,
        timestamp: DateTime(2026, 1, 1, 9),
        body: 'Older important email message',
      );

      when(
        () => emailService.messageStreamForChat(
          any(),
          start: any(named: 'start'),
          end: any(named: 'end'),
          filter: any(named: 'filter'),
        ),
      ).thenAnswer((_) => emailMessageStreamController.stream);
      when(
        () => emailService.backfillChatHistory(
          chat: any(named: 'chat'),
          desiredWindow: any(named: 'desiredWindow'),
          beforeMessageId: any(named: 'beforeMessageId'),
          beforeTimestamp: any(named: 'beforeTimestamp'),
          filter: any(named: 'filter'),
        ),
      ).thenAnswer((_) async {});

      var targetLookupCount = 0;
      when(
        () => messageService.loadMessageByReferenceId(
          'email-important-ref',
          chatJid: emailChat.jid,
        ),
      ).thenAnswer((_) async {
        targetLookupCount += 1;
        return targetLookupCount >= 2 ? target : null;
      });

      var countCalls = 0;
      when(
        () => messageService.countLocalMessages(
          jid: any(named: 'jid'),
          filter: any(named: 'filter'),
          includePseudoMessages: any(named: 'includePseudoMessages'),
        ),
      ).thenAnswer((_) async {
        countCalls += 1;
        return countCalls >= 2 ? 2 : 1;
      });
      when(
        () => mockDatabase.countChatMessagesThrough(
          emailChat.jid,
          throughTimestamp: target.timestamp!,
          throughStanzaId: target.stanzaID,
          throughDeltaMsgId: target.deltaMsgId,
          filter: MessageTimelineFilter.allWithContact,
        ),
      ).thenAnswer((_) async => 75);

      final bloc = ChatBloc(
        jid: emailChat.jid,
        messageService: messageService,
        chatsService: chatsService,
        mucService: mucService,
        notificationService: notificationService,
        emailService: emailService,
        settings: _defaultChatSettings(),
      );

      chatStreamController.add(emailChat);
      await _pumpBloc();
      emailMessageStreamController.add([newest]);
      await _pumpBloc();
      await _pumpBloc();

      bloc.add(const ChatImportantMessageSelected('email-important-ref'));
      await _pumpBloc();

      emailMessageStreamController.add([newest, target]);
      await _pumpBloc();

      expect(bloc.state.scrollTargetMessageId, 'email-important-target');
      expect(bloc.state.scrollTargetRequestId, 1);

      await bloc.close();
      await emailMessageStreamController.close();
    },
  );

  test('self email messages do not create an unread boundary', () async {
    final emailService = MockEmailService();
    final emailMessageStreamController =
        StreamController<List<Message>>.broadcast();
    _mockEmailSync(emailService);

    final emailChat = initialChat.copyWith(
      deltaChatId: 4,
      emailAddress: 'peer@example.com',
      transport: MessageTransport.email,
      unreadCount: 1,
    );
    final selfMessage = Message(
      stanzaID: 'email-self-1',
      senderJid: 'me@example.com',
      chatJid: emailChat.jid,
      deltaMsgId: 41,
      timestamp: DateTime(2026, 1, 3, 10),
      body: 'Outbound email message',
    );

    when(() => emailService.selfSenderJid).thenReturn('me@example.com');
    when(
      () => emailService.getOldestFreshMessageId(any()),
    ).thenAnswer((_) async => null);
    when(
      () => emailService.messageStreamForChat(
        any(),
        start: any(named: 'start'),
        end: any(named: 'end'),
        filter: any(named: 'filter'),
      ),
    ).thenAnswer((_) => emailMessageStreamController.stream);
    when(
      () => emailService.pinnedMessagesStream(any()),
    ).thenAnswer((_) => const Stream<List<PinnedMessageEntry>>.empty());

    final bloc = ChatBloc(
      jid: emailChat.jid,
      messageService: messageService,
      chatsService: chatsService,
      mucService: mucService,
      notificationService: notificationService,
      emailService: emailService,
      settings: _defaultChatSettings(),
    );

    chatStreamController.add(emailChat);
    await _pumpBloc();
    emailMessageStreamController.add([selfMessage]);
    await _pumpBloc();
    await _pumpBloc();

    expect(bloc.state.unreadBoundaryStanzaId, isNull);

    await bloc.close();
    await emailMessageStreamController.close();
  });

  test(
    'email read sync does not repeat seen work for the same unseen messages',
    () async {
      final emailService = MockEmailService();
      final emailMessageStreamController =
          StreamController<List<Message>>.broadcast();
      const settings = ChatSettingsSnapshot(
        language: AppLanguage.system,
        chatReadReceipts: true,
        emailReadReceipts: true,
        shareTokenSignatureEnabled: true,
        autoDownloadImages: true,
        autoDownloadVideos: false,
        autoDownloadDocuments: false,
        autoDownloadArchives: false,
      );
      _mockEmailSync(emailService);

      final emailChat = initialChat.copyWith(
        deltaChatId: 7,
        emailAddress: 'peer@example.com',
        transport: MessageTransport.email,
        unreadCount: 1,
      );
      final incoming = Message(
        stanzaID: 'email-incoming-1',
        senderJid: 'peer@example.com',
        chatJid: emailChat.jid,
        deltaChatId: emailChat.deltaChatId,
        deltaMsgId: 91,
        timestamp: DateTime(2026, 1, 4, 12),
        body: 'Fresh email',
      );

      when(() => emailService.hasInMemoryReconnectContext).thenReturn(true);
      when(
        () => emailService.getOldestFreshMessageId(any()),
      ).thenAnswer((_) async => null);
      when(
        () => emailService.markNoticedChat(any()),
      ).thenAnswer((_) async => true);
      when(
        () => emailService.markSeenMessages(
          any(),
          sendReadReceipts: any(named: 'sendReadReceipts'),
        ),
      ).thenAnswer((_) async => true);
      when(
        () => emailService.messageStreamForChat(
          any(),
          start: any(named: 'start'),
          end: any(named: 'end'),
          filter: any(named: 'filter'),
        ),
      ).thenAnswer((_) => emailMessageStreamController.stream);
      when(
        () => emailService.pinnedMessagesStream(any()),
      ).thenAnswer((_) => const Stream<List<PinnedMessageEntry>>.empty());

      final bloc = ChatBloc(
        jid: emailChat.jid,
        messageService: messageService,
        chatsService: chatsService,
        mucService: mucService,
        notificationService: notificationService,
        emailService: emailService,
        settings: settings,
      );

      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      chatStreamController.add(emailChat);
      await _pumpBloc();
      await _pumpBloc();

      emailMessageStreamController.add([incoming]);
      await _pumpBloc();
      await _pumpBloc();

      emailMessageStreamController.add([incoming]);
      await _pumpBloc();
      await _pumpBloc();

      verify(() => emailService.markNoticedChat(any())).called(1);
      verify(
        () => emailService.markSeenMessages(any(), sendReadReceipts: true),
      ).called(1);

      await bloc.close();
      await emailMessageStreamController.close();
    },
  );

  test(
    'email read sync still notices unseen messages after local unread is cleared',
    () async {
      final emailService = MockEmailService();
      final emailMessageStreamController =
          StreamController<List<Message>>.broadcast();
      const settings = ChatSettingsSnapshot(
        language: AppLanguage.system,
        chatReadReceipts: true,
        emailReadReceipts: true,
        shareTokenSignatureEnabled: true,
        autoDownloadImages: true,
        autoDownloadVideos: false,
        autoDownloadDocuments: false,
        autoDownloadArchives: false,
      );
      _mockEmailSync(emailService);

      final emailChat = initialChat.copyWith(
        deltaChatId: 7,
        emailAddress: 'peer@example.com',
        transport: MessageTransport.email,
        unreadCount: 0,
        open: true,
      );
      final incoming = Message(
        stanzaID: 'email-incoming-opened-chat',
        senderJid: 'peer@example.com',
        chatJid: emailChat.jid,
        deltaChatId: emailChat.deltaChatId,
        deltaMsgId: 92,
        timestamp: DateTime(2026, 1, 4, 12, 1),
        body: 'Fresh email after local clear',
      );

      when(() => emailService.hasInMemoryReconnectContext).thenReturn(true);
      when(
        () => emailService.getOldestFreshMessageId(any()),
      ).thenAnswer((_) async => null);
      when(
        () => emailService.markNoticedChat(any()),
      ).thenAnswer((_) async => true);
      when(
        () => emailService.markSeenMessages(
          any(),
          sendReadReceipts: any(named: 'sendReadReceipts'),
        ),
      ).thenAnswer((_) async => true);
      when(
        () => emailService.messageStreamForChat(
          any(),
          start: any(named: 'start'),
          end: any(named: 'end'),
          filter: any(named: 'filter'),
        ),
      ).thenAnswer((_) => emailMessageStreamController.stream);
      when(
        () => emailService.pinnedMessagesStream(any()),
      ).thenAnswer((_) => const Stream<List<PinnedMessageEntry>>.empty());

      final bloc = ChatBloc(
        jid: emailChat.jid,
        messageService: messageService,
        chatsService: chatsService,
        mucService: mucService,
        notificationService: notificationService,
        emailService: emailService,
        settings: settings,
      );

      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      chatStreamController.add(emailChat);
      await _pumpBloc();
      await _pumpBloc();

      emailMessageStreamController.add([incoming]);
      await _pumpBloc();
      await _pumpBloc();

      verify(() => emailService.markNoticedChat(any())).called(1);

      await bloc.close();
      await emailMessageStreamController.close();
    },
  );

  test(
    'open XMPP chats send a live read marker once for the latest unread message',
    () async {
      final bloc = ChatBloc(
        jid: initialChat.jid,
        messageService: messageService,
        chatsService: chatsService,
        mucService: mucService,
        notificationService: notificationService,
        emailService: null,
        settings: _defaultChatSettings(),
      );
      final incoming = Message(
        stanzaID: 'live-open-chat-unread',
        senderJid: initialChat.jid,
        chatJid: initialChat.jid,
        timestamp: DateTime(2026, 1, 4, 12, 1),
        body: 'Fresh direct message',
      );

      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      chatStreamController.add(initialChat);
      await _pumpBloc();
      await _pumpBloc();

      messageStreamController.add([incoming]);
      await _pumpBloc();
      await _pumpBloc();

      messageStreamController.add([incoming]);
      await _pumpBloc();
      await _pumpBloc();

      verify(
        () => messageService.sendReadMarker(
          initialChat.jid,
          incoming.stanzaID,
          chatType: initialChat.type,
        ),
      ).called(1);

      await bloc.close();
    },
  );

  test(
    'open XMPP chats do not send duplicate read markers while one is in flight',
    () async {
      final completer = Completer<void>();
      when(
        () => messageService.sendReadMarker(
          initialChat.jid,
          any(),
          chatType: initialChat.type,
        ),
      ).thenAnswer((_) => completer.future);

      final bloc = ChatBloc(
        jid: initialChat.jid,
        messageService: messageService,
        chatsService: chatsService,
        mucService: mucService,
        notificationService: notificationService,
        emailService: null,
        settings: _defaultChatSettings(),
      );
      final incoming = Message(
        stanzaID: 'live-open-chat-unread-in-flight',
        senderJid: initialChat.jid,
        chatJid: initialChat.jid,
        timestamp: DateTime(2026, 1, 4, 12, 2),
        body: 'Fresh direct message',
      );

      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      chatStreamController.add(initialChat);
      await _pumpBloc();
      await _pumpBloc();

      messageStreamController.add([incoming]);
      await _pumpBloc();
      await _pumpBloc();

      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.inactive,
      );
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await _pumpBloc();
      await _pumpBloc();

      verify(
        () => messageService.sendReadMarker(
          initialChat.jid,
          incoming.stanzaID,
          chatType: initialChat.type,
        ),
      ).called(1);

      completer.complete();
      await _pumpBloc();
      await _pumpBloc();

      await bloc.close();
    },
  );

  test('catch-up paginates MAM when reconnecting after gap', () async {
    final xmppService = MockXmppService();
    final connectivityController =
        StreamController<xmpp.ConnectionState>.broadcast();

    when(
      () => xmppService.connectionState,
    ).thenReturn(xmpp.ConnectionState.notConnected);
    when(
      () => xmppService.connectivityStream,
    ).thenAnswer((_) => connectivityController.stream);
    when(
      () => xmppService.httpUploadSupportStream,
    ).thenAnswer((_) => const Stream<xmpp.HttpUploadSupport>.empty());
    when(
      () => xmppService.httpUploadSupport,
    ).thenReturn(const xmpp.HttpUploadSupport(supported: false));
    when(
      () => xmppService.createChatArchiveSession(),
    ).thenReturn('xmpp-session-1');
    when(
      () => xmppService.hydrateLatestFromMamForChatSessionIfNeeded(
        sessionId: any(named: 'sessionId'),
        chat: any(named: 'chat'),
        desiredWindow: any(named: 'desiredWindow'),
        filter: any(named: 'filter'),
        visibleWindowEmpty: any(named: 'visibleWindowEmpty'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => xmppService.messageStreamForChat(
        any(),
        start: any(named: 'start'),
        end: any(named: 'end'),
        filter: any(named: 'filter'),
      ),
    ).thenAnswer((_) => messageStreamController.stream);
    when(
      () => xmppService.sendReadMarker(
        any(),
        any(),
        chatType: any(named: 'chatType'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => xmppService.countLocalMessages(
        jid: any(named: 'jid'),
        filter: any(named: 'filter'),
        includePseudoMessages: any(named: 'includePseudoMessages'),
      ),
    ).thenAnswer((_) async => ChatBloc.messageBatchSize);
    when(
      () => xmppService.fetchLatestFromArchive(
        jid: any(named: 'jid'),
        pageSize: any(named: 'pageSize'),
        isMuc: any(named: 'isMuc'),
      ),
    ).thenAnswer((_) async => const xmpp.MamPageResult(complete: true));
    when(
      () => xmppService.loadArchiveCursorTimestamp(any()),
    ).thenAnswer((_) async => DateTime(2024));

    final mamPages = Queue<xmpp.MamPageResult>.from([
      const xmpp.MamPageResult(complete: false, firstId: 'p0', lastId: 'p1'),
      const xmpp.MamPageResult(complete: true, firstId: 'p1', lastId: 'p2'),
    ]);

    when(
      () => xmppService.fetchSinceFromArchive(
        jid: any(named: 'jid'),
        since: any(named: 'since'),
        pageSize: any(named: 'pageSize'),
        isMuc: any(named: 'isMuc'),
        after: any(named: 'after'),
      ),
    ).thenAnswer((_) async => mamPages.removeFirst());

    final bloc = ChatBloc(
      jid: initialChat.jid,
      messageService: xmppService,
      chatsService: chatsService,
      mucService: mucService,
      notificationService: notificationService,
      settings: _defaultChatSettings(),
    );

    chatStreamController.add(initialChat);
    messageStreamController.add(const <Message>[]);
    await _pumpBloc();

    connectivityController.add(xmpp.ConnectionState.connected);
    await _pumpBloc();
    await _pumpBloc();

    verify(
      () => xmppService.fetchSinceFromArchive(
        jid: any(named: 'jid'),
        since: any(named: 'since'),
        pageSize: any(named: 'pageSize'),
        isMuc: any(named: 'isMuc'),
        after: any(named: 'after'),
      ),
    ).called(2);

    await bloc.close();
    await connectivityController.close();
  });

  test(
    'room member sections keep participants separate from visitors and skip unresolved occupants',
    () async {
      final roomStateController = StreamController<RoomState>.broadcast();
      when(
        () => mucService.roomStateStream(any()),
      ).thenAnswer((_) => roomStateController.stream);

      const roomJid = 'room@conference.axi.im';
      const selfOccupantId = '$roomJid/self';
      const participantOccupantId = '$roomJid/alice';
      const visitorOccupantId = '$roomJid/bob';
      const unresolvedOccupantId = '$roomJid/ghost';

      final bloc = ChatBloc(
        jid: roomJid,
        messageService: messageService,
        chatsService: chatsService,
        mucService: mucService,
        notificationService: notificationService,
        emailService: null,
        settings: _defaultChatSettings(),
      );

      chatStreamController.add(_groupChat(roomJid));
      messageStreamController.add(const <Message>[]);
      await _pumpBloc();

      roomStateController.add(
        RoomState(
          roomJid: roomJid,
          myOccupantJid: selfOccupantId,
          occupants: <String, Occupant>{
            selfOccupantId: _occupant(
              occupantId: selfOccupantId,
              nick: 'self',
              realJid: 'self@axi.im',
              affiliation: OccupantAffiliation.owner,
              role: OccupantRole.moderator,
            ),
            participantOccupantId: _occupant(
              occupantId: participantOccupantId,
              nick: 'alice',
              realJid: 'alice@axi.im',
              affiliation: OccupantAffiliation.none,
              role: OccupantRole.participant,
            ),
            visitorOccupantId: _occupant(
              occupantId: visitorOccupantId,
              nick: 'bob',
              role: OccupantRole.visitor,
            ),
            unresolvedOccupantId: _occupant(
              occupantId: unresolvedOccupantId,
              nick: 'ghost',
              isPresent: false,
            ),
          },
        ),
      );
      await _pumpBloc();
      await _pumpBloc();

      final participantSection = bloc.state.roomMemberSections.firstWhere(
        (section) => section.kind == RoomMemberSectionKind.participants,
      );
      final visitorSection = bloc.state.roomMemberSections.firstWhere(
        (section) => section.kind == RoomMemberSectionKind.visitors,
      );

      expect(
        participantSection.members.map((member) => member.occupant.nick),
        equals(const <String>['alice']),
      );
      expect(
        participantSection.members.single.directChatJid,
        equals('alice@axi.im'),
      );
      expect(
        visitorSection.members.map((member) => member.occupant.nick),
        equals(const <String>['bob']),
      );
      expect(
        bloc.state.roomMemberSections
            .expand((section) => section.members)
            .map((member) => member.occupant.nick),
        isNot(contains('ghost')),
      );

      await bloc.close();
      await roomStateController.close();
    },
  );

  test(
    'warm room state replaces cached empty placeholders so member sections hydrate',
    () async {
      const roomJid = 'room@conference.axi.im';
      const selfOccupantId = '$roomJid/self';

      when(
        () => mucService.roomStateFor(roomJid),
      ).thenReturn(RoomState(roomJid: roomJid, occupants: const {}));
      when(() => mucService.warmRoomFromHistory(roomJid: roomJid)).thenAnswer(
        (_) async => RoomState(
          roomJid: roomJid,
          myOccupantJid: selfOccupantId,
          occupants: <String, Occupant>{
            selfOccupantId: _occupant(
              occupantId: selfOccupantId,
              nick: 'self',
              realJid: 'self@axi.im',
              affiliation: OccupantAffiliation.member,
              role: OccupantRole.participant,
            ),
          },
        ),
      );

      final bloc = ChatBloc(
        jid: roomJid,
        messageService: messageService,
        chatsService: chatsService,
        mucService: mucService,
        notificationService: notificationService,
        emailService: null,
        settings: _defaultChatSettings(),
      );

      chatStreamController.add(_groupChat(roomJid));
      messageStreamController.add(const <Message>[]);
      await _pumpBloc();
      await _pumpBloc();

      expect(bloc.state.roomState?.myOccupantJid, selfOccupantId);
      expect(
        bloc.state.roomMemberSections
            .expand((section) => section.members)
            .map((member) => member.occupant.nick),
        contains('self'),
      );

      await bloc.close();
    },
  );

  test('group chats subscribe to room state replay before warm-up', () async {
    const roomJid = 'room@conference.axi.im';

    when(
      () => mucService.roomStateFor(roomJid),
    ).thenReturn(RoomState(roomJid: roomJid, occupants: const {}));
    when(
      () => mucService.warmRoomFromHistory(roomJid: roomJid),
    ).thenAnswer((_) async => RoomState(roomJid: roomJid, occupants: const {}));

    final roomStreamController = StreamController<RoomState>.broadcast();
    when(
      () => mucService.roomStateStream(roomJid),
    ).thenAnswer((_) => roomStreamController.stream);

    final bloc = ChatBloc(
      jid: roomJid,
      messageService: messageService,
      chatsService: chatsService,
      mucService: mucService,
      notificationService: notificationService,
      emailService: null,
      settings: _defaultChatSettings(),
    );

    chatStreamController.add(_groupChat(roomJid));
    messageStreamController.add(const <Message>[]);
    await _pumpBloc();
    await _pumpBloc();

    verifyInOrder([
      () => mucService.roomStateFor(roomJid),
      () => mucService.roomStateStream(roomJid),
      () => mucService.warmRoomFromHistory(roomJid: roomJid),
    ]);

    await bloc.close();
    await roomStreamController.close();
  });

  test(
    'closing during room warm-up does not create a late room subscription',
    () async {
      const roomJid = 'room@conference.axi.im';
      final warmCompleter = Completer<RoomState>();
      final roomStreamController = StreamController<RoomState>.broadcast();

      when(
        () => mucService.roomStateFor(roomJid),
      ).thenReturn(RoomState(roomJid: roomJid, occupants: const {}));
      when(
        () => mucService.warmRoomFromHistory(roomJid: roomJid),
      ).thenAnswer((_) => warmCompleter.future);
      when(
        () => mucService.roomStateStream(roomJid),
      ).thenAnswer((_) => roomStreamController.stream);

      final bloc = ChatBloc(
        jid: roomJid,
        messageService: messageService,
        chatsService: chatsService,
        mucService: mucService,
        notificationService: notificationService,
        emailService: null,
        settings: _defaultChatSettings(),
      );

      chatStreamController.add(_groupChat(roomJid));
      messageStreamController.add(const <Message>[]);
      await _pumpBloc();

      await bloc.close();

      warmCompleter.complete(RoomState(roomJid: roomJid, occupants: const {}));
      await _pumpBloc();
      await _pumpBloc();

      expect(roomStreamController.hasListener, isFalse);

      await roomStreamController.close();
    },
  );

  test(
    'room member actions respect affiliation authority and exposed real JIDs',
    () async {
      final roomStateController = StreamController<RoomState>.broadcast();
      when(
        () => mucService.roomStateStream(any()),
      ).thenAnswer((_) => roomStateController.stream);

      const roomJid = 'room@conference.axi.im';
      const selfOccupantId = '$roomJid/self';
      const memberOccupantId = '$roomJid/alice';
      const offlineMemberOccupantId = '$roomJid/~dave@axi.im';
      const participantOccupantId = '$roomJid/bob';
      const ownerOccupantId = '$roomJid/carol';

      final bloc = ChatBloc(
        jid: roomJid,
        messageService: messageService,
        chatsService: chatsService,
        mucService: mucService,
        notificationService: notificationService,
        emailService: null,
        settings: _defaultChatSettings(),
      );

      chatStreamController.add(_groupChat(roomJid));
      messageStreamController.add(const <Message>[]);
      await _pumpBloc();

      roomStateController.add(
        RoomState(
          roomJid: roomJid,
          myOccupantJid: selfOccupantId,
          occupants: <String, Occupant>{
            selfOccupantId: _occupant(
              occupantId: selfOccupantId,
              nick: 'self',
              realJid: 'self@axi.im',
              affiliation: OccupantAffiliation.admin,
              role: OccupantRole.moderator,
            ),
            memberOccupantId: _occupant(
              occupantId: memberOccupantId,
              nick: 'alice',
              realJid: 'alice@axi.im',
              affiliation: OccupantAffiliation.member,
              role: OccupantRole.participant,
            ),
            offlineMemberOccupantId: _occupant(
              occupantId: offlineMemberOccupantId,
              nick: 'dave@axi.im',
              realJid: 'dave@axi.im',
              affiliation: OccupantAffiliation.member,
              role: OccupantRole.none,
              isPresent: false,
            ),
            participantOccupantId: _occupant(
              occupantId: participantOccupantId,
              nick: 'bob',
              affiliation: OccupantAffiliation.none,
              role: OccupantRole.participant,
            ),
            ownerOccupantId: _occupant(
              occupantId: ownerOccupantId,
              nick: 'carol',
              realJid: 'carol@axi.im',
              affiliation: OccupantAffiliation.owner,
              role: OccupantRole.moderator,
            ),
          },
        ),
      );
      await _pumpBloc();
      await _pumpBloc();

      RoomMemberEntry memberEntry(String nick) {
        return bloc.state.roomMemberSections
            .expand((section) => section.members)
            .firstWhere((member) => member.occupant.nick == nick);
      }

      expect(
        memberEntry('alice').actions,
        equals(const <MucModerationAction>[
          MucModerationAction.kick,
          MucModerationAction.ban,
          MucModerationAction.moderator,
        ]),
      );
      expect(memberEntry('alice').directChatJid, equals('alice@axi.im'));
      expect(
        memberEntry('dave@axi.im').actions,
        equals(const <MucModerationAction>[MucModerationAction.ban]),
      );
      expect(memberEntry('dave@axi.im').directChatJid, equals('dave@axi.im'));
      expect(
        memberEntry('bob').actions,
        equals(const <MucModerationAction>[
          MucModerationAction.kick,
          MucModerationAction.moderator,
        ]),
      );
      expect(memberEntry('bob').directChatJid, isNull);
      expect(memberEntry('carol').actions, isEmpty);
      expect(memberEntry('carol').directChatJid, equals('carol@axi.im'));

      await bloc.close();
      await roomStateController.close();
    },
  );

  test(
    'members do not receive moderation buttons and moderation completers finish',
    () async {
      final roomStateController = StreamController<RoomState>.broadcast();
      when(
        () => mucService.roomStateStream(any()),
      ).thenAnswer((_) => roomStateController.stream);

      const roomJid = 'room@conference.axi.im';
      const selfOccupantId = '$roomJid/self';
      const targetOccupantId = '$roomJid/alice';
      final groupChat = _groupChat(roomJid);

      final bloc = ChatBloc(
        jid: roomJid,
        messageService: messageService,
        chatsService: chatsService,
        mucService: mucService,
        notificationService: notificationService,
        emailService: null,
        settings: _defaultChatSettings(),
      );

      chatStreamController.add(groupChat);
      messageStreamController.add(const <Message>[]);
      await _pumpBloc();

      roomStateController.add(
        RoomState(
          roomJid: roomJid,
          myOccupantJid: selfOccupantId,
          occupants: <String, Occupant>{
            selfOccupantId: _occupant(
              occupantId: selfOccupantId,
              nick: 'self',
              realJid: 'self@axi.im',
              affiliation: OccupantAffiliation.member,
              role: OccupantRole.participant,
            ),
            targetOccupantId: _occupant(
              occupantId: targetOccupantId,
              nick: 'alice',
              realJid: 'alice@axi.im',
              affiliation: OccupantAffiliation.member,
              role: OccupantRole.participant,
            ),
          },
        ),
      );
      await _pumpBloc();
      await _pumpBloc();

      final targetEntry = bloc.state.roomMemberSections
          .expand((section) => section.members)
          .firstWhere((member) => member.occupant.nick == 'alice');
      expect(targetEntry.actions, isEmpty);

      final adminRoomState = RoomState(
        roomJid: roomJid,
        myOccupantJid: selfOccupantId,
        occupants: <String, Occupant>{
          selfOccupantId: _occupant(
            occupantId: selfOccupantId,
            nick: 'self',
            realJid: 'self@axi.im',
            affiliation: OccupantAffiliation.admin,
            role: OccupantRole.moderator,
          ),
          targetOccupantId: _occupant(
            occupantId: targetOccupantId,
            nick: 'alice',
            realJid: 'alice@axi.im',
            affiliation: OccupantAffiliation.member,
            role: OccupantRole.participant,
          ),
        },
      );
      final completer = Completer<void>();

      bloc.add(
        ChatModerationActionRequested(
          occupantId: targetOccupantId,
          action: MucModerationAction.kick,
          actionLabel: 'Kick',
          chat: groupChat,
          roomState: adminRoomState,
          completer: completer,
        ),
      );

      await completer.future.timeout(const Duration(seconds: 1));
      verify(
        () => mucService.kickOccupant(
          roomJid: roomJid,
          nick: 'alice',
          reason: null,
        ),
      ).called(1);

      await bloc.close();
      await roomStateController.close();
    },
  );
}
