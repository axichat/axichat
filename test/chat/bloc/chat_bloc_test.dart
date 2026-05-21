import 'dart:io';
import 'dart:async';
import 'dart:collection';

import 'package:async/async.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/chat/models/chat_message.dart';
import 'package:axichat/src/common/chat_subject_codec.dart';
import 'package:axichat/src/common/compose_recipient.dart';
import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/common/synthetic_reply.dart';
import 'package:axichat/src/chat/models/pending_attachment.dart';
import 'package:axichat/src/chat/models/pinned_message_item.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:axichat/src/email/models/fan_out_recipient_state.dart';
import 'package:axichat/src/email/models/fan_out_recipient_status.dart';
import 'package:axichat/src/email/models/fan_out_send_report.dart';
import 'package:axichat/src/email/models/share_context.dart';
import 'package:axichat/src/email/service/delta_chat_exception.dart';
import 'package:axichat/src/email/models/email_sync_state.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/home/view/home_screen.dart';
import 'package:axichat/src/xmpp/muc/muc_join_state.dart';
import 'package:axichat/src/xmpp/muc/occupant.dart';
import 'package:axichat/src/xmpp/muc/room_state.dart';
import 'package:axichat/src/settings/app_language.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart' as xmpp;
import 'package:flutter/widgets.dart'
    show
        AppLifecycleState,
        Builder,
        BuildContext,
        SizedBox,
        StatelessWidget,
        ValueKey,
        Widget;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;
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

void _expectFreshChatState(
  ChatState state, {
  bool emailServiceAvailable = false,
  String? emailSelfJid,
  MessageTimelineFilter expectedViewFilter =
      MessageTimelineFilter.allWithContact,
}) {
  expect(state.items, isEmpty);
  expect(state.messagesLoaded, isFalse);
  expect(state.attachmentMetadataIdsByMessageId, isEmpty);
  expect(state.attachmentGroupLeaderByMessageId, isEmpty);
  expect(state.pinnedMessages, isEmpty);
  expect(state.pinnedMessagesLoaded, isFalse);
  expect(state.pinnedMessagesHydrating, isFalse);
  expect(state.quotedMessagesById, isEmpty);
  expect(state.chat, isNull);
  expect(state.roomState, isNull);
  expect(state.roomMemberSections, isEmpty);
  expect(state.focused, isNull);
  expect(state.typing, isFalse);
  expect(state.typingParticipants, isEmpty);
  expect(state.showAlert, isTrue);
  expect(state.viewFilter, expectedViewFilter);
  expect(state.fanOutReports, isEmpty);
  expect(state.fanOutDrafts, isEmpty);
  expect(state.shareContexts, isEmpty);
  expect(state.shareReplies, isEmpty);
  expect(state.resendLoadingMessageIds, isEmpty);
  expect(state.emailRawHeadersByDeltaId, isEmpty);
  expect(state.emailRawHeadersLoading, isEmpty);
  expect(state.emailRawHeadersUnavailable, isEmpty);
  expect(state.emailFullHtmlByDeltaId, isEmpty);
  expect(state.emailFullHtmlLoading, isEmpty);
  expect(state.emailFullHtmlUnavailable, isEmpty);
  expect(state.emailQuotedTextByDeltaId, isEmpty);
  expect(state.emailQuotedTextLoading, isEmpty);
  expect(state.emailQuotedTextUnavailable, isEmpty);
  expect(state.fileMetadataById, isEmpty);
  expect(state.composerError, isNull);
  expect(state.composerHydrationId, 0);
  expect(state.composerHydrationText, isNull);
  expect(state.composerClearId, 0);
  expect(state.emailSubject, isNull);
  expect(state.emailSubjectAutofillEligible, isTrue);
  expect(state.emailSubjectAutofilled, isFalse);
  expect(state.emailSyncState, const EmailSyncState.ready());
  expect(state.xmppConnectionState, mox.XmppConnectionState.notConnected);
  expect(state.unreadBoundaryStanzaId, isNull);
  expect(state.xmppCapabilities, isNull);
  expect(state.supportsHttpFileUpload, isFalse);
  expect(state.emailServiceAvailable, emailServiceAvailable);
  expect(state.emailSelfJid, emailSelfJid);
  expect(state.openChatJid, isNull);
  expect(state.openChatRequestId, 0);
  expect(state.scrollTargetMessageId, isNull);
  expect(state.scrollTargetRequestId, 0);
  expect(state.pendingForwardDraft, isNull);
  expect(state.toast, isNull);
  expect(state.toastId, 0);
  expect(state.roomAvatarUpdateStatus, RequestStatus.none);
  expect(state.collectionActionState, isA<ChatCollectionActionIdle>());
}

ChatState _dirtyEveryChatStateField(ChatState state, Chat chat) {
  const dirtyMessage = Message(
    stanzaID: 'dirty-message',
    senderJid: 'peer@axi.im',
    chatJid: 'peer@axi.im',
    body: 'dirty',
  );
  const dirtyFileMetadata = FileMetadataData(
    id: 'dirty-file',
    filename: 'dirty.txt',
  );
  return state.copyWith(
    items: const [dirtyMessage],
    messagesLoaded: true,
    attachmentMetadataIdsByMessageId: const {
      'dirty-message': ['dirty-file'],
    },
    attachmentGroupLeaderByMessageId: const {'dirty-message': 'dirty-message'},
    pinnedMessages: [
      PinnedMessageItem(
        messageStanzaId: 'dirty-message',
        chatJid: chat.jid,
        pinnedAt: DateTime.utc(2024, 1, 1),
        message: dirtyMessage,
        attachmentMetadataIds: const ['dirty-file'],
      ),
    ],
    pinnedMessagesLoaded: true,
    pinnedMessagesHydrating: true,
    quotedMessagesById: const {'quoted-message': dirtyMessage},
    chat: chat,
    roomState: RoomState(roomJid: 'dirty-room@conference.axi.im'),
    roomMemberSections: const [
      RoomMemberSection(kind: RoomMemberSectionKind.members, members: []),
    ],
    focused: dirtyMessage,
    typing: true,
    typingParticipants: const ['peer@axi.im'],
    showAlert: false,
    viewFilter: MessageTimelineFilter.directOnly,
    fanOutReports: const {
      'dirty-share': FanOutSendReport(shareId: 'dirty-share', statuses: []),
    },
    fanOutDrafts: const {
      'dirty-share': FanOutDraft(shareId: 'dirty-share', body: 'dirty'),
    },
    shareContexts: {
      'dirty-share': ShareContext(
        shareId: 'dirty-share',
        participants: [chat],
        subject: 'dirty subject',
      ),
    },
    shareReplies: {
      'dirty-share': [chat],
    },
    resendLoadingMessageIds: const {'dirty-message'},
    emailRawHeadersByDeltaId: const {1: 'X-Dirty: yes'},
    emailRawHeadersLoading: const {2},
    emailRawHeadersUnavailable: const {3},
    emailFullHtmlByDeltaId: const {4: '<p>dirty</p>'},
    emailFullHtmlLoading: const {5},
    emailFullHtmlUnavailable: const {6},
    emailQuotedTextByDeltaId: const {7: 'dirty quote'},
    emailQuotedTextLoading: const {8},
    emailQuotedTextUnavailable: const {9},
    fileMetadataById: const {'dirty-file': dirtyFileMetadata},
    composerError: ChatMessageKey.chatComposerEmptyMessage,
    composerHydrationId: 1,
    composerHydrationText: 'dirty composer',
    composerClearId: 2,
    emailSubject: 'dirty subject',
    emailSubjectAutofillEligible: false,
    emailSubjectAutofilled: true,
    emailSyncState: const EmailSyncState.offline('offline'),
    xmppConnectionState: mox.XmppConnectionState.connected,
    unreadBoundaryStanzaId: 'dirty-message',
    xmppCapabilities: xmpp.XmppPeerCapabilities(features: const ['dirty']),
    supportsHttpFileUpload: true,
    emailServiceAvailable: true,
    emailSelfJid: 'self@example.com',
    openChatJid: 'dirty-open@axi.im',
    openChatRequestId: 3,
    scrollTargetMessageId: 'dirty-scroll',
    scrollTargetRequestId: 4,
    pendingForwardDraft: const ChatForwardDraft(
      sources: [
        ChatForwardDraftSource(
          sourceMessageId: 'dirty-message',
          senderJid: 'peer@axi.im',
          resolvedSenderLabel: 'peer@axi.im',
          timestamp: null,
          originalSubject: 'dirty subject',
          originalPlainTextBody: 'dirty body',
          originalHtmlBody: null,
          attachmentMetadataIds: ['dirty-file'],
        ),
      ],
    ),
    toast: const ChatToast(message: ChatMessageKey.chatDraftSaved),
    toastId: 5,
    roomAvatarUpdateStatus: RequestStatus.loading,
    collectionActionState: const ChatCollectionActionLoading(
      collectionId: 'dirty-collection',
      messageReferenceId: 'dirty-message',
      active: true,
    ),
  );
}

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
  CalendarTask? calendarTaskIcs,
  bool calendarTaskIcsReadOnly = true,
  String? calendarTaskShareText,
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
  calendarTaskIcs: calendarTaskIcs,
  calendarTaskIcsReadOnly: calendarTaskIcsReadOnly,
  calendarTaskShareText: calendarTaskShareText,
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
    final targets = invocation.namedArguments[#targets]! as List<Contact>;
    final shareId = invocation.namedArguments[#shareId] as String? ?? 'share-1';
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
              title: targets[index].displayName.isNotEmpty
                  ? targets[index].displayName
                  : (targets[index].address ??
                        targets[index].chatJid ??
                        'target-$index'),
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

class MockXmppAttachmentUpload extends Mock
    implements xmpp.XmppAttachmentUpload {}

class _TestChatBloc extends ChatBloc {
  _TestChatBloc({
    required super.jid,
    required super.messageService,
    required super.chatsService,
    required super.notificationService,
    required super.mucService,
    required super.settings,
  });

  final closeStarted = Completer<void>();

  void emitForTest(ChatState state) {
    emit(state);
  }

  @override
  Future<void> close() async {
    if (!closeStarted.isCompleted) {
      closeStarted.complete();
    }
    return super.close();
  }
}

class _ChatBlocScopeHarness extends StatelessWidget {
  const _ChatBlocScopeHarness({
    super.key,
    required this.pane,
    required this.messageService,
    required this.chatsService,
    required this.mucService,
    required this.notificationService,
    required this.onBlocCreated,
  });

  final HomeSecondaryPane pane;
  final MockMessageService messageService;
  final MockChatsService chatsService;
  final MockMucService mucService;
  final MockNotificationService notificationService;
  final void Function(_TestChatBloc bloc) onBlocCreated;

  @override
  Widget build(BuildContext context) {
    final resolvedJid = pane.jid;
    if (resolvedJid == null || resolvedJid.isEmpty) {
      return const SizedBox.shrink();
    }
    return MultiBlocProvider(
      providers: [
        BlocProvider<ChatBloc>(
          lazy: false,
          create: (_) {
            final bloc = _TestChatBloc(
              jid: resolvedJid,
              messageService: messageService,
              chatsService: chatsService,
              mucService: mucService,
              notificationService: notificationService,
              settings: _defaultChatSettings(),
            );
            onBlocCreated(bloc);
            return bloc;
          },
        ),
      ],
      child: Builder(
        builder: (context) {
          context.read<ChatBloc>();
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMessageService messageService;
  late MockChatsService chatsService;
  late MockNotificationService notificationService;
  late MockMucService mucService;
  late MockXmppAttachmentUpload attachmentUpload;
  late StreamController<List<Message>> messageStreamController;
  late StreamController<Chat?> chatStreamController;

  setUpAll(() {
    registerFallbackValue(<Contact>[]);
    registerFallbackValue(
      Contact.address(
        address: 'fallback@example.com',
        shareSignatureEnabled: true,
        transport: MessageTransport.email,
      ),
    );
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
    attachmentUpload = MockXmppAttachmentUpload();
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
    when(() => mucService.roomStateForOrEmpty(any())).thenAnswer(
      (invocation) =>
          RoomState(roomJid: invocation.positionalArguments.first as String),
    );
    when(
      () => mucService.warmRoomFromHistory(roomJid: any(named: 'roomJid')),
    ).thenAnswer(
      (invocation) async =>
          RoomState(roomJid: invocation.namedArguments[#roomJid] as String),
    );
    when(
      () => mucService.ensureJoined(
        roomJid: any(named: 'roomJid'),
        nickname: any(named: 'nickname'),
        allowRejoin: any(named: 'allowRejoin'),
      ),
    ).thenAnswer((_) async {});
    when(() => mucService.refreshRoomAvatar(any())).thenAnswer((_) async {});
    when(() => mucService.seedDummyRoomData(any())).thenAnswer((_) async {});
    when(
      () => mucService.inviteUserToRoom(
        roomJid: any(named: 'roomJid'),
        inviteeJid: any(named: 'inviteeJid'),
        reason: any(named: 'reason'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mucService.resendInvitePseudoMessage(
        any(),
        onLocalMessageStored: any(named: 'onLocalMessageStored'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mucService.acceptRoomInvite(
        roomJid: any(named: 'roomJid'),
        roomName: any(named: 'roomName'),
        inviteToken: any(named: 'inviteToken'),
        inviterJid: any(named: 'inviterJid'),
        inviteeJid: any(named: 'inviteeJid'),
        password: any(named: 'password'),
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
      () => mucService.fetchRoomMembers(roomJid: any(named: 'roomJid')),
    ).thenAnswer((_) async => []);
    when(
      () => mucService.fetchRoomOwners(roomJid: any(named: 'roomJid')),
    ).thenAnswer((_) async => []);
    when(
      () => mucService.fetchRoomAdmins(roomJid: any(named: 'roomJid')),
    ).thenAnswer((_) async => []);

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
      () => messageService.verifyUnackedMessagesFromMamForChat(
        chat: any(named: 'chat'),
        candidates: any(named: 'candidates'),
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
        forwardedOriginalSenderLabel: any(
          named: 'forwardedOriginalSenderLabel',
        ),
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
      () => messageService.sendLocalOnlyMessage(
        jid: any(named: 'jid'),
        text: any(named: 'text'),
        encryptionProtocol: any(named: 'encryptionProtocol'),
        htmlBody: any(named: 'htmlBody'),
        forwarded: any(named: 'forwarded'),
        forwardedFromJid: any(named: 'forwardedFromJid'),
        forwardedOriginalSenderLabel: any(
          named: 'forwardedOriginalSenderLabel',
        ),
        quotedMessage: any(named: 'quotedMessage'),
        quotedReference: any(named: 'quotedReference'),
        calendarFragment: any(named: 'calendarFragment'),
        calendarTaskIcs: any(named: 'calendarTaskIcs'),
        calendarTaskIcsReadOnly: any(named: 'calendarTaskIcsReadOnly'),
        calendarAvailabilityMessage: any(named: 'calendarAvailabilityMessage'),
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
        forwardedOriginalSenderLabel: any(
          named: 'forwardedOriginalSenderLabel',
        ),
        transportGroupId: any(named: 'transportGroupId'),
        attachmentOrder: any(named: 'attachmentOrder'),
        quotedMessage: any(named: 'quotedMessage'),
        quotedReference: any(named: 'quotedReference'),
        groupQuotedReference: any(named: 'groupQuotedReference'),
        chatType: any(named: 'chatType'),
        upload: any(named: 'upload'),
        onLocalMessageStored: any(named: 'onLocalMessageStored'),
      ),
    ).thenAnswer((_) async => attachmentUpload);
    when(
      () => messageService.sendLocalOnlyAttachment(
        jid: any(named: 'jid'),
        attachment: any(named: 'attachment'),
        encryptionProtocol: any(named: 'encryptionProtocol'),
        htmlCaption: any(named: 'htmlCaption'),
        forwarded: any(named: 'forwarded'),
        forwardedFromJid: any(named: 'forwardedFromJid'),
        forwardedOriginalSenderLabel: any(
          named: 'forwardedOriginalSenderLabel',
        ),
        transportGroupId: any(named: 'transportGroupId'),
        attachmentOrder: any(named: 'attachmentOrder'),
        quotedMessage: any(named: 'quotedMessage'),
        quotedReference: any(named: 'quotedReference'),
        groupQuotedReference: any(named: 'groupQuotedReference'),
        chatType: any(named: 'chatType'),
        upload: any(named: 'upload'),
        onLocalMessageStored: any(named: 'onLocalMessageStored'),
      ),
    ).thenAnswer((_) async => attachmentUpload);
    when(
      () => messageService.reactToMessageLocally(
        stanzaID: any(named: 'stanzaID'),
        emoji: any(named: 'emoji'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => messageService.setMessageCollectionMembership(
        collectionId: any(named: 'collectionId'),
        chat: any(named: 'chat'),
        message: any(named: 'message'),
        active: any(named: 'active'),
      ),
    ).thenAnswer((_) async => true);
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
      () => messageService.loadMessagesByReferenceIds(
        any(),
        chatJid: any(named: 'chatJid'),
      ),
    ).thenAnswer((_) async => const <Message>[]);
    when(
      () => messageService.pinnedMessagesStream(any()),
    ).thenAnswer((_) => const Stream<List<PinnedMessageEntry>>.empty());
    when(
      () => messageService.syncPinnedMessagesForChat(any()),
    ).thenAnswer((_) async {});
    when(
      () =>
          messageService.resendMessage(any(), chatType: any(named: 'chatType')),
    ).thenAnswer((_) async => true);
    when(
      () => messageService.resendMessage(
        any(),
        chatType: any(named: 'chatType'),
        onLocalMessageStored: any(named: 'onLocalMessageStored'),
      ),
    ).thenAnswer((invocation) async {
      final callback =
          invocation.namedArguments[#onLocalMessageStored]
              as void Function(String)?;
      callback?.call('manual-send-again-copy');
      return true;
    });
    when(
      () => messageService.markMessageManualSendAgain(
        stanzaID: any(named: 'stanzaID'),
        sendAgainStanzaID: any(named: 'sendAgainStanzaID'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => messageService.loadEarlierFromMamForChatSession(
        sessionId: any(named: 'sessionId'),
        chat: any(named: 'chat'),
        fallbackBeforeId: any(named: 'fallbackBeforeId'),
        filter: any(named: 'filter'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => messageService.ensureMessageAvailableFromMamForChatSession(
        sessionId: any(named: 'sessionId'),
        chat: any(named: 'chat'),
        messageId: any(named: 'messageId'),
        filter: any(named: 'filter'),
        visibleWindowEmpty: any(named: 'visibleWindowEmpty'),
        fallbackBeforeId: any(named: 'fallbackBeforeId'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => null);

    when(
      () => chatsService.chatStream(any()),
    ).thenAnswer((_) => chatStreamController.stream);
    when(
      () => chatsService.typingParticipantsStream(any()),
    ).thenAnswer((_) => const Stream<List<String>>.empty());

    when(() => chatsService.myJid).thenReturn('self@axi.im');
    when(
      () => messageService.countChatMessagesThrough(
        any(),
        throughTimestamp: any(named: 'throughTimestamp'),
        throughStanzaId: any(named: 'throughStanzaId'),
        throughDeltaMsgId: any(named: 'throughDeltaMsgId'),
        filter: any(named: 'filter'),
      ),
    ).thenAnswer((_) async => 0);
    when(
      () => messageService.loadPinnedMessages(any()),
    ).thenAnswer((_) async => const <PinnedMessageEntry>[]);
    when(
      () => messageService.loadFileMetadata(any()),
    ).thenAnswer((_) async => null);
    when(
      () => messageService.loadFileMetadataByIds(any()),
    ).thenAnswer((_) async => const <FileMetadataData>[]);
    when(
      () => messageService.fileMetadataByIdsStream(any()),
    ).thenAnswer((_) => const Stream<Map<String, FileMetadataData?>>.empty());
    when(
      () => messageService.loadMessageAttachments(any()),
    ).thenAnswer((_) async => const <MessageAttachmentData>[]);
    when(
      () => messageService.loadMessageAttachmentsForGroup(any()),
    ).thenAnswer((_) async => const <MessageAttachmentData>[]);
    when(
      () => messageService.loadMessageAttachmentsForMessages(any()),
    ).thenAnswer((_) async => const <String, List<MessageAttachmentData>>{});
    when(
      () => messageService.markMessagesDisplayedLocally(
        messages: any(named: 'messages'),
        chatJid: any(named: 'chatJid'),
        selfJid: any(named: 'selfJid'),
      ),
    ).thenAnswer((_) async {});
    when(() => chatsService.loadChat(any())).thenAnswer(
      (invocation) async =>
          Chat.fromJid(invocation.positionalArguments.first as String),
    );

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
  final welcomeChat = Chat(
    jid: 'axichat@welcome.axichat.invalid',
    title: 'Axichat',
    type: ChatType.chat,
    lastChangeTimestamp: DateTime.now(),
    contactJid: 'axichat@welcome.axichat.invalid',
  );

  test('new chat bloc starts with every chat-scoped field reset', () async {
    final bloc = _TestChatBloc(
      jid: initialChat.jid,
      messageService: messageService,
      chatsService: chatsService,
      mucService: mucService,
      notificationService: notificationService,
      settings: _defaultChatSettings(),
    );

    _expectFreshChatState(bloc.state);

    await bloc.close();
  });

  testWidgets('switching chat keys disposes the previous chat bloc subtree', (
    tester,
  ) async {
    final firstPane = HomeSecondaryPane.openChat(initialChat.jid);
    const secondPane = HomeSecondaryPane.openChat('second@axi.im');
    final createdBlocs = <_TestChatBloc>[];

    await tester.pumpWidget(
      SizedBox(
        child: _ChatBlocScopeHarness(
          key: ValueKey(firstPane.scopeKey),
          pane: firstPane,
          messageService: messageService,
          chatsService: chatsService,
          mucService: mucService,
          notificationService: notificationService,
          onBlocCreated: createdBlocs.add,
        ),
      ),
    );
    await tester.pump();
    final firstBloc = createdBlocs.single;
    firstBloc.emitForTest(
      _dirtyEveryChatStateField(firstBloc.state, initialChat),
    );

    expect(firstPane.scopeKey, isNot(secondPane.scopeKey));

    await tester.pumpWidget(
      SizedBox(
        child: _ChatBlocScopeHarness(
          key: ValueKey(secondPane.scopeKey),
          pane: secondPane,
          messageService: messageService,
          chatsService: chatsService,
          mucService: mucService,
          notificationService: notificationService,
          onBlocCreated: createdBlocs.add,
        ),
      ),
    );
    await tester.pump();
    final secondBloc = createdBlocs.last;
    await tester.pump(const Duration(milliseconds: 1));

    expect(createdBlocs, hasLength(2));
    expect(firstBloc.closeStarted.isCompleted, isTrue);
    expect(secondBloc, isNot(same(firstBloc)));
    _expectFreshChatState(
      secondBloc.state,
      expectedViewFilter: MessageTimelineFilter.directOnly,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(secondBloc.closeStarted.isCompleted, isTrue);
  });

  test('close cancels active chat subscriptions and archive session', () async {
    final pinnedController =
        StreamController<List<PinnedMessageEntry>>.broadcast();
    final typingController = StreamController<List<String>>.broadcast();
    final uploadController =
        StreamController<xmpp.HttpUploadSupport>.broadcast();
    final emailSyncController = StreamController<EmailSyncState>.broadcast();
    final metadataController =
        StreamController<Map<String, FileMetadataData?>>.broadcast();
    final emailService = MockEmailService();
    const attachedMessage = Message(
      id: 'attached-message',
      stanzaID: 'attached-message',
      senderJid: 'peer@axi.im',
      chatJid: 'peer@axi.im',
    );

    when(
      () => messageService.httpUploadSupportStream,
    ).thenAnswer((_) => uploadController.stream);
    when(
      () => messageService.pinnedMessagesStream(any()),
    ).thenAnswer((_) => pinnedController.stream);
    when(
      () => messageService.loadMessageAttachmentsForMessages(any()),
    ).thenAnswer(
      (_) async => const {
        'attached-message': [
          MessageAttachmentData(
            id: 1,
            messageId: 'attached-message',
            fileMetadataId: 'file-1',
            sortOrder: 0,
          ),
        ],
      },
    );
    when(
      () => messageService.fileMetadataByIdsStream(any()),
    ).thenAnswer((_) => metadataController.stream);
    when(
      () => chatsService.typingParticipantsStream(any()),
    ).thenAnswer((_) => typingController.stream);
    _mockEmailSync(emailService);
    when(
      () => emailService.syncStateStream,
    ).thenAnswer((_) => emailSyncController.stream);

    final bloc = ChatBloc(
      jid: initialChat.jid,
      messageService: messageService,
      chatsService: chatsService,
      mucService: mucService,
      notificationService: notificationService,
      emailService: emailService,
      settings: _defaultChatSettings(),
    );
    await _pumpBloc();
    await _pumpBloc();
    chatStreamController.add(initialChat);
    await _pumpBloc();
    await _pumpBloc();
    messageStreamController.add(const [attachedMessage]);
    await _pumpBloc();
    await _pumpBloc();

    expect(chatStreamController.hasListener, isTrue);
    expect(messageStreamController.hasListener, isTrue);
    expect(pinnedController.hasListener, isTrue);
    expect(typingController.hasListener, isTrue);
    expect(uploadController.hasListener, isTrue);
    expect(emailSyncController.hasListener, isTrue);
    expect(metadataController.hasListener, isTrue);

    await bloc.close();

    expect(chatStreamController.hasListener, isFalse);
    expect(messageStreamController.hasListener, isFalse);
    expect(pinnedController.hasListener, isFalse);
    expect(typingController.hasListener, isFalse);
    expect(uploadController.hasListener, isFalse);
    expect(emailSyncController.hasListener, isFalse);
    expect(metadataController.hasListener, isFalse);
    verify(
      () => messageService.disposeChatArchiveSession('session-1'),
    ).called(1);

    chatStreamController.add(initialChat.copyWith(title: 'after close'));
    messageStreamController.add(const []);
    pinnedController.add(const []);
    typingController.add(const []);
    uploadController.add(const xmpp.HttpUploadSupport(supported: true));
    emailSyncController.add(const EmailSyncState.recovering('after close'));
    metadataController.add(const {});
    await _pumpBloc();
    expect(bloc.state.chat, initialChat);

    await pinnedController.close();
    await typingController.close();
    await uploadController.close();
    await emailSyncController.close();
    await metadataController.close();
  });

  test('rejects chat stream updates for another jid', () async {
    ChatBloc? bloc;
    Object? caughtError;

    await runZonedGuarded(
      () async {
        bloc = ChatBloc(
          jid: initialChat.jid,
          messageService: messageService,
          chatsService: chatsService,
          mucService: mucService,
          notificationService: notificationService,
          settings: _defaultChatSettings(),
        );
        chatStreamController.add(Chat.fromJid('other@axi.im'));
        await _pumpBloc();
        await _pumpBloc();
      },
      (error, _) {
        caughtError = error;
      },
    );

    expect(caughtError, isA<StateError>());
    expect(bloc!.state.chat, isNull);

    await bloc!.close();
  });

  test('same-jid chat updates do not clear chat-scoped state', () async {
    final bloc = _TestChatBloc(
      jid: initialChat.jid,
      messageService: messageService,
      chatsService: chatsService,
      mucService: mucService,
      notificationService: notificationService,
      settings: _defaultChatSettings(),
    );
    final dirtyState = _dirtyEveryChatStateField(bloc.state, initialChat);
    bloc.emitForTest(dirtyState);

    chatStreamController.add(initialChat.copyWith(title: 'Renamed peer'));
    await _pumpBloc();

    expect(bloc.state.chat?.title, 'Renamed peer');
    expect(bloc.state.items, dirtyState.items);
    expect(bloc.state.messagesLoaded, isTrue);
    expect(
      bloc.state.attachmentMetadataIdsByMessageId,
      dirtyState.attachmentMetadataIdsByMessageId,
    );
    expect(bloc.state.quotedMessagesById, dirtyState.quotedMessagesById);
    expect(bloc.state.fileMetadataById, dirtyState.fileMetadataById);
    expect(bloc.state.pinnedMessages, dirtyState.pinnedMessages);
    expect(bloc.state.pinnedMessagesLoaded, isTrue);
    expect(bloc.state.fanOutReports, dirtyState.fanOutReports);
    expect(
      bloc.state.resendLoadingMessageIds,
      dirtyState.resendLoadingMessageIds,
    );
    expect(bloc.state.fanOutDrafts, dirtyState.fanOutDrafts);
    expect(bloc.state.shareContexts, dirtyState.shareContexts);
    expect(bloc.state.shareReplies, dirtyState.shareReplies);
    expect(bloc.state.composerError, dirtyState.composerError);
    expect(bloc.state.composerHydrationText, dirtyState.composerHydrationText);
    expect(bloc.state.emailSubject, dirtyState.emailSubject);
    expect(
      bloc.state.emailRawHeadersByDeltaId,
      dirtyState.emailRawHeadersByDeltaId,
    );
    expect(
      bloc.state.emailFullHtmlByDeltaId,
      dirtyState.emailFullHtmlByDeltaId,
    );
    expect(
      bloc.state.emailQuotedTextByDeltaId,
      dirtyState.emailQuotedTextByDeltaId,
    );
    expect(
      bloc.state.unreadBoundaryStanzaId,
      dirtyState.unreadBoundaryStanzaId,
    );
    expect(bloc.state.focused, dirtyState.focused);

    await bloc.close();
  });

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
        () => messageService.loadMessagesByReferenceIds({
          quotedOriginId,
        }, chatJid: initialChat.jid),
      ).thenAnswer((_) async => [quotedMessage]);

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
        () => messageService.loadMessagesByReferenceIds({
          quotedOriginId,
        }, chatJid: initialChat.jid),
      ).called(1);
      verifyNever(
        () => messageService.loadMessageByReferenceId(
          quotedOriginId,
          chatJid: initialChat.jid,
        ),
      );
      verifyNever(() => messageService.loadMessageByStanzaId(quotedOriginId));
      expect(
        bloc.state.quotedMessagesById[quotedOriginId]?.stanzaID,
        quotedMessage.stanzaID,
      );

      await bloc.close();
    },
  );

  test(
    'presentation hydration queues later requests without cancelling in-flight work',
    () async {
      final emailService = MockEmailService();
      _mockEmailSync(emailService);
      const quotedOriginId = 'queued-quoted-origin-id';
      final quoteLookupStarted = Completer<void>();
      final quoteLoadCompleter = Completer<List<Message>>();
      final htmlLookupStarted = Completer<void>();
      final quotedMessage = Message(
        stanzaID: 'queued-quoted-local-stanza-id',
        originID: quotedOriginId,
        senderJid: initialChat.jid,
        chatJid: initialChat.jid,
        body: 'Original body',
        timestamp: DateTime.now(),
      );
      final replyMessage = Message(
        stanzaID: 'queued-reply-stanza-id',
        senderJid: 'self@axi.im',
        chatJid: initialChat.jid,
        body: 'Reply body',
        quoting: quotedOriginId,
        displayed: true,
        timestamp: DateTime.now(),
      );
      final renderedMessage = Message(
        stanzaID: 'queued-rendered-email-html',
        senderJid: initialChat.jid,
        chatJid: initialChat.jid,
        deltaMsgId: 207,
        deltaAccountId: 3,
        displayed: true,
        timestamp: DateTime.now(),
      );

      when(
        () => messageService.loadMessagesByReferenceIds(
          any(),
          chatJid: initialChat.jid,
        ),
      ).thenAnswer((invocation) {
        final ids = invocation.positionalArguments.single as Set<String>;
        if (ids.contains(quotedOriginId)) {
          if (!quoteLookupStarted.isCompleted) {
            quoteLookupStarted.complete();
          }
          return quoteLoadCompleter.future;
        }
        return Future.value(const <Message>[]);
      });
      when(() => emailService.getMessageFullHtml(any())).thenAnswer((
        invocation,
      ) async {
        final message = invocation.positionalArguments.single as Message;
        if (message.stanzaID == renderedMessage.stanzaID &&
            !htmlLookupStarted.isCompleted) {
          htmlLookupStarted.complete();
        }
        return '<p>Rendered html</p>';
      });

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
      await _pumpBloc();
      messageStreamController.add(<Message>[replyMessage]);
      await quoteLookupStarted.future;

      bloc.add(ChatRenderedMessagesHydrationRequested([renderedMessage]));
      await _pumpBloc();
      expect(htmlLookupStarted.isCompleted, isFalse);

      quoteLoadCompleter.complete([quotedMessage]);
      await htmlLookupStarted.future;
      await _pumpBloc();

      expect(
        bloc.state.quotedMessagesById[quotedOriginId]?.stanzaID,
        quotedMessage.stanzaID,
      );
      expect(
        bloc.state.emailFullHtmlByDeltaId[renderedMessage.deltaMsgId],
        '<p>Rendered html</p>',
      );

      await bloc.close();
    },
  );

  test(
    'hydrates grouped attachment quote from attachment group metadata',
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
      final attachmentMessage = Message(
        id: 'remaining-attachment-message',
        stanzaID: 'remaining-attachment-stanza',
        senderJid: 'self@axi.im',
        chatJid: initialChat.jid,
        body: 'file.txt',
        timestamp: DateTime.now(),
      );

      when(
        () => messageService.loadMessageAttachmentsForMessages(any()),
      ).thenAnswer(
        (_) async => const {
          'remaining-attachment-message': [
            MessageAttachmentData(
              id: 1,
              messageId: 'remaining-attachment-message',
              fileMetadataId: 'file-1',
              sortOrder: 1,
              transportGroupId: 'attachment-group',
              groupQuotedReference: quotedOriginId,
              groupQuotedReferenceKind: MessageReferenceKind.originId,
            ),
          ],
        },
      );
      when(
        () => messageService.loadMessagesByReferenceIds({
          quotedOriginId,
        }, chatJid: initialChat.jid),
      ).thenAnswer((_) async => [quotedMessage]);

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
      messageStreamController.add(<Message>[attachmentMessage]);
      await _pumpBloc();
      await _pumpBloc();

      expect(bloc.state.items.single.quoting, quotedOriginId);
      expect(
        bloc.state.items.single.quotingReferenceKind,
        MessageReferenceKind.originId,
      );
      expect(
        bloc.state.quotedMessagesById[quotedOriginId]?.stanzaID,
        quotedMessage.stanzaID,
      );

      await bloc.close();
    },
  );

  test(
    'clears file metadata subscription when message window becomes empty',
    () async {
      final metadataController =
          StreamController<Map<String, FileMetadataData?>>.broadcast();
      final message = Message(
        id: 'message-with-metadata',
        stanzaID: 'message-with-metadata',
        senderJid: initialChat.jid,
        chatJid: initialChat.jid,
        body: 'file.txt',
        timestamp: DateTime.now(),
        fileMetadataID: 'file-1',
      );

      when(
        () => messageService.fileMetadataByIdsStream(any()),
      ).thenAnswer((_) => metadataController.stream);

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
      messageStreamController.add(<Message>[message]);
      await _pumpBloc();
      await _pumpBloc();
      await _pumpBloc();

      expect(metadataController.hasListener, isTrue);

      messageStreamController.add(const <Message>[]);
      await _pumpBloc();
      await _pumpBloc();
      await _pumpBloc();

      expect(metadataController.hasListener, isFalse);

      await bloc.close();
      await metadataController.close();
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
                htmlBody: HtmlContentCodec.fromPlainText('Team status update'),
                attachment: any(named: 'attachment'),
                htmlCaption: any(named: 'htmlCaption'),
                shareId: any(named: 'shareId'),
                subject: any(named: 'subject'),
                quotedStanzaId: any(named: 'quotedStanzaId'),
                useSubjectToken: any(named: 'useSubjectToken'),
                tokenAsSignature: any(named: 'tokenAsSignature'),
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
                htmlBody: HtmlContentCodec.fromPlainText('Hello world'),
                attachment: any(named: 'attachment'),
                htmlCaption: any(named: 'htmlCaption'),
                shareId: any(named: 'shareId'),
                subject: any(named: 'subject'),
                quotedStanzaId: any(named: 'quotedStanzaId'),
                useSubjectToken: any(named: 'useSubjectToken'),
                tokenAsSignature: any(named: 'tokenAsSignature'),
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
        htmlBody: any(named: 'htmlBody'),
        attachment: any(named: 'attachment'),
        htmlCaption: any(named: 'htmlCaption'),
        shareId: any(named: 'shareId'),
        subject: any(named: 'subject'),
        quotedStanzaId: any(named: 'quotedStanzaId'),
        useSubjectToken: any(named: 'useSubjectToken'),
        tokenAsSignature: any(named: 'tokenAsSignature'),
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
        htmlBody: any(named: 'htmlBody'),
        attachment: any(named: 'attachment'),
        htmlCaption: any(named: 'htmlCaption'),
        shareId: any(named: 'shareId'),
        subject: any(named: 'subject'),
        quotedStanzaId: any(named: 'quotedStanzaId'),
        useSubjectToken: any(named: 'useSubjectToken'),
        tokenAsSignature: any(named: 'tokenAsSignature'),
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
        htmlBody: any(named: 'htmlBody'),
        attachment: any(named: 'attachment'),
        htmlCaption: any(named: 'htmlCaption'),
        shareId: any(named: 'shareId'),
        subject: any(named: 'subject'),
        quotedStanzaId: any(named: 'quotedStanzaId'),
        useSubjectToken: any(named: 'useSubjectToken'),
        tokenAsSignature: any(named: 'tokenAsSignature'),
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
    final pickCompleter = CancelableCompleter<PendingAttachment?>();
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
    final picked = await pickCompleter.operation.value;
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
    final pickCompleter = CancelableCompleter<PendingAttachment?>();
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
    final picked = await pickCompleter.operation.value;
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

  test('cancelled attachment pick ignores late completion', () async {
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
    final pickCompleter = CancelableCompleter<PendingAttachment?>();
    await pickCompleter.operation.cancel();
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

    expect(await pickCompleter.operation.valueOrCancellation(), isNull);

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

  test('single forward emits a pending draft without sending', () async {
    final timestamp = DateTime.utc(2024, 1, 2, 3, 4);
    final message = Message(
      stanzaID: 'forward-xmpp',
      senderJid: initialChat.jid,
      chatJid: initialChat.jid,
      body: ChatSubjectCodec.composeXmppBody(
        body: 'Forward me',
        subject: 'Original subject',
      ),
      timestamp: timestamp,
      fileMetadataID: 'forward-meta',
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

    bloc.add(ChatMessageForwardRequested(message: message));
    await _pumpBloc();

    final draft = bloc.state.pendingForwardDraft;
    expect(draft, isNotNull);
    expect(draft!.attachmentMetadataIds, ['forward-meta']);
    expect(draft.sources, hasLength(1));
    expect(draft.sources.single.sourceMessageId, 'forward-xmpp');
    expect(draft.sources.single.senderJid, initialChat.jid);
    expect(draft.sources.single.resolvedSenderLabel, 'peer@axi.im');
    expect(draft.sources.single.timestamp, timestamp);
    expect(draft.sources.single.originalSubject, 'Original subject');
    expect(draft.sources.single.originalPlainTextBody, 'Forward me');
    expect(draft.sources.single.originalHtmlBody, isNull);
    expect(draft.sources.single.attachmentMetadataIds, ['forward-meta']);
    verifyNever(
      () => messageService.sendMessage(
        jid: any(named: 'jid'),
        text: any(named: 'text'),
        encryptionProtocol: any(named: 'encryptionProtocol'),
      ),
    );

    bloc.add(const ChatForwardDraftConsumed());
    await _pumpBloc();
    expect(bloc.state.pendingForwardDraft, isNull);

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

  test('welcome chat sends text through the local-only message path', () async {
    final bloc = ChatBloc(
      jid: welcomeChat.jid,
      messageService: messageService,
      chatsService: chatsService,
      mucService: mucService,
      notificationService: notificationService,
      settings: _defaultChatSettings(),
    );

    chatStreamController.add(welcomeChat);
    messageStreamController.add(const <Message>[]);
    await _pumpBloc();

    bloc.add(
      _messageSent(
        chat: welcomeChat,
        text: 'Hello welcome',
        recipients: [
          ComposerRecipient(
            target: Contact.chat(
              chat: welcomeChat,
              shareSignatureEnabled: false,
            ),
          ),
        ],
        settings: _defaultChatSettings(),
      ),
    );
    await _pumpBloc();

    verify(
      () => messageService.sendLocalOnlyMessage(
        jid: welcomeChat.jid,
        text: 'Hello welcome',
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
        jid: welcomeChat.jid,
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

  test('single forward emits only the requested message draft', () async {
    final first = Message(
      stanzaID: 'forward-first',
      senderJid: initialChat.jid,
      chatJid: initialChat.jid,
      body: 'First',
      timestamp: DateTime.utc(2024),
      fileMetadataID: 'first-meta',
    );
    final second = Message(
      stanzaID: 'forward-second',
      senderJid: 'other@axi.im',
      chatJid: initialChat.jid,
      body: 'Second',
      timestamp: DateTime.utc(2024, 1, 1, 0, 1),
      fileMetadataID: 'second-meta',
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
    messageStreamController.add([first, second]);
    await _pumpBloc();
    await _pumpBloc();

    bloc.add(ChatMessageForwardRequested(message: second));
    await _pumpBloc();

    final draft = bloc.state.pendingForwardDraft;
    expect(draft, isNotNull);
    expect(draft!.sources.map((source) => source.sourceMessageId), [
      'forward-second',
    ]);
    expect(draft.attachmentMetadataIds, ['second-meta']);
    verifyNever(
      () => messageService.sendLocalOnlyMessage(
        jid: any(named: 'jid'),
        text: any(named: 'text'),
        encryptionProtocol: any(named: 'encryptionProtocol'),
      ),
    );

    await bloc.close();
  });

  test(
    'invite-only forward shows forbidden feedback and emits no draft',
    () async {
      final message = Message(
        stanzaID: 'forward-invite',
        senderJid: initialChat.jid,
        chatJid: initialChat.jid,
        body: 'Invite',
        timestamp: DateTime.now(),
        pseudoMessageType: PseudoMessageType.mucInvite,
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

      bloc.add(ChatMessageForwardRequested(message: message));
      await _pumpBloc();

      expect(bloc.state.pendingForwardDraft, isNull);
      expect(
        bloc.state.toast?.message,
        ChatMessageKey.chatForwardInviteForbidden,
      );
      verifyNever(
        () => messageService.sendAttachment(
          jid: any(named: 'jid'),
          attachment: any(named: 'attachment'),
          encryptionProtocol: any(named: 'encryptionProtocol'),
        ),
      );

      await bloc.close();
    },
  );

  test(
    'non-invite pseudo-message forward shows forbidden feedback and emits no draft',
    () async {
      final message = Message(
        stanzaID: 'forward-calendar-pseudo',
        senderJid: initialChat.jid,
        chatJid: initialChat.jid,
        body: 'Calendar payload',
        timestamp: DateTime.now(),
        pseudoMessageType: PseudoMessageType.calendarTaskIcs,
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

      bloc.add(ChatMessageForwardRequested(message: message));
      await _pumpBloc();

      expect(bloc.state.pendingForwardDraft, isNull);
      expect(
        bloc.state.toast?.message,
        ChatMessageKey.chatForwardInviteForbidden,
      );

      await bloc.close();
    },
  );

  test('welcome chat bootstrap skips XMPP hydrate and pin sync', () async {
    final bloc = ChatBloc(
      jid: welcomeChat.jid,
      messageService: messageService,
      chatsService: chatsService,
      mucService: mucService,
      notificationService: notificationService,
      settings: _defaultChatSettings(),
    );

    chatStreamController.add(welcomeChat);
    messageStreamController.add(const <Message>[]);
    await _pumpBloc();

    verifyNever(
      () => messageService.hydrateLatestFromMamForChatSessionIfNeeded(
        sessionId: any(named: 'sessionId'),
        chat: any(named: 'chat'),
        desiredWindow: any(named: 'desiredWindow'),
        filter: any(named: 'filter'),
        visibleWindowEmpty: any(named: 'visibleWindowEmpty'),
        pageSize: any(named: 'pageSize'),
      ),
    );
    verifyNever(() => messageService.syncPinnedMessagesForChat(any()));

    await bloc.close();
  });

  test('email chat syncs pins while open', () async {
    final emailService = MockEmailService();
    final emailMessageStreamController =
        StreamController<List<Message>>.broadcast();
    _mockEmailSync(emailService);

    final emailChat = initialChat.copyWith(
      deltaChatId: 4,
      emailAddress: 'peer@example.com',
      transport: MessageTransport.email,
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
    emailMessageStreamController.add(const <Message>[]);
    await _pumpBloc();
    await _pumpBloc();

    verify(
      () => messageService.syncPinnedMessagesForChat(emailChat.jid),
    ).called(1);

    await bloc.close();
    await emailMessageStreamController.close();
  });

  test('adding a message to a folder emits success action state', () async {
    final message = Message(
      stanzaID: 'folder-message',
      senderJid: initialChat.jid,
      chatJid: initialChat.jid,
      body: 'Save me',
      timestamp: DateTime(2026, 5, 10),
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

    bloc.add(
      ChatMessageCollectionMembershipChanged(
        message: message,
        collectionId: 'receipts',
        chat: initialChat,
        active: true,
      ),
    );
    await _pumpBloc();

    verify(
      () => messageService.setMessageCollectionMembership(
        collectionId: 'receipts',
        chat: initialChat,
        message: message,
        active: true,
      ),
    ).called(1);
    expect(
      bloc.state.collectionActionState,
      const ChatCollectionActionSuccess(
        collectionId: 'receipts',
        messageReferenceId: 'folder-message',
        active: true,
      ),
    );

    await bloc.close();
  });

  test('adding a message to a folder reports membership failures', () async {
    final message = Message(
      stanzaID: 'folder-message',
      senderJid: initialChat.jid,
      chatJid: initialChat.jid,
      body: 'Save me',
      timestamp: DateTime(2026, 5, 10),
    );
    when(
      () => messageService.setMessageCollectionMembership(
        collectionId: 'receipts',
        chat: initialChat,
        message: message,
        active: true,
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
      ChatMessageCollectionMembershipChanged(
        message: message,
        collectionId: 'receipts',
        chat: initialChat,
        active: true,
      ),
    );
    await _pumpBloc();

    expect(
      bloc.state.collectionActionState,
      const ChatCollectionActionFailure(
        collectionId: 'receipts',
        messageReferenceId: 'folder-message',
        active: true,
        reason: ChatCollectionActionFailureReason.updateFailed,
      ),
    );

    await bloc.close();
  });

  test(
    'adding a message to a folder reports no-op membership results',
    () async {
      final message = Message(
        stanzaID: 'folder-message',
        senderJid: initialChat.jid,
        chatJid: initialChat.jid,
        body: 'Save me',
        timestamp: DateTime(2026, 5, 10),
      );
      when(
        () => messageService.setMessageCollectionMembership(
          collectionId: 'receipts',
          chat: initialChat,
          message: message,
          active: true,
        ),
      ).thenAnswer((_) async => false);
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
        ChatMessageCollectionMembershipChanged(
          message: message,
          collectionId: 'receipts',
          chat: initialChat,
          active: true,
        ),
      );
      await _pumpBloc();

      expect(
        bloc.state.collectionActionState,
        const ChatCollectionActionFailure(
          collectionId: 'receipts',
          messageReferenceId: 'folder-message',
          active: true,
          reason: ChatCollectionActionFailureReason.updateFailed,
        ),
      );

      await bloc.close();
    },
  );

  test('adding an unsupported message to a folder reports failure', () async {
    final message = Message(
      stanzaID: '',
      senderJid: initialChat.jid,
      chatJid: initialChat.jid,
      body: 'No stable reference',
      timestamp: DateTime(2026, 5, 10),
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

    bloc.add(
      ChatMessageCollectionMembershipChanged(
        message: message,
        collectionId: 'receipts',
        chat: initialChat,
        active: true,
      ),
    );
    await _pumpBloc();

    verifyNever(
      () => messageService.setMessageCollectionMembership(
        collectionId: any(named: 'collectionId'),
        chat: any(named: 'chat'),
        message: any(named: 'message'),
        active: any(named: 'active'),
      ),
    );
    expect(
      bloc.state.collectionActionState,
      const ChatCollectionActionFailure(
        collectionId: 'receipts',
        messageReferenceId: '',
        active: true,
        reason: ChatCollectionActionFailureReason.unsupported,
      ),
    );

    await bloc.close();
  });

  test('welcome chat typing never sends chat-state traffic', () async {
    final bloc = ChatBloc(
      jid: welcomeChat.jid,
      messageService: messageService,
      chatsService: chatsService,
      mucService: mucService,
      notificationService: notificationService,
      settings: _defaultChatSettings(),
    );

    chatStreamController.add(welcomeChat);
    messageStreamController.add(const <Message>[]);
    await _pumpBloc();

    bloc.add(ChatTypingStarted(chat: welcomeChat));
    await _pumpBloc();

    verifyNever(
      () => chatsService.sendTyping(
        jid: any(named: 'jid'),
        typing: any(named: 'typing'),
      ),
    );

    await bloc.close();
  });

  test(
    'welcome chat attachments use the local-only attachment path without upload support',
    () async {
      final bloc = ChatBloc(
        jid: welcomeChat.jid,
        messageService: messageService,
        chatsService: chatsService,
        mucService: mucService,
        notificationService: notificationService,
        settings: _defaultChatSettings(),
      );

      chatStreamController.add(welcomeChat);
      messageStreamController.add(const <Message>[]);
      await _pumpBloc();

      bloc.add(
        _messageSent(
          chat: welcomeChat,
          text: '',
          recipients: [
            ComposerRecipient(
              target: Contact.chat(
                chat: welcomeChat,
                shareSignatureEnabled: false,
              ),
            ),
          ],
          pendingAttachments: const [
            PendingAttachment(
              id: 'welcome-attachment',
              attachment: EmailAttachment(
                path: '/tmp/mock',
                fileName: 'mock.txt',
                sizeBytes: 0,
              ),
            ),
          ],
          settings: _defaultChatSettings(),
          supportsHttpFileUpload: false,
        ),
      );
      await _pumpBloc();

      verify(
        () => messageService.sendLocalOnlyAttachment(
          jid: welcomeChat.jid,
          attachment: any(named: 'attachment'),
          encryptionProtocol: EncryptionProtocol.none,
          chatType: ChatType.chat,
          quotedMessage: any(named: 'quotedMessage'),
          groupQuotedReference: any(named: 'groupQuotedReference'),
          htmlCaption: any(named: 'htmlCaption'),
          transportGroupId: any(named: 'transportGroupId'),
          attachmentOrder: any(named: 'attachmentOrder'),
          upload: any(named: 'upload'),
          onLocalMessageStored: any(named: 'onLocalMessageStored'),
        ),
      ).called(1);
      verifyNever(
        () => messageService.sendAttachment(
          jid: welcomeChat.jid,
          attachment: any(named: 'attachment'),
          encryptionProtocol: any(named: 'encryptionProtocol'),
          chatType: any(named: 'chatType'),
          quotedMessage: any(named: 'quotedMessage'),
          htmlCaption: any(named: 'htmlCaption'),
          transportGroupId: any(named: 'transportGroupId'),
          attachmentOrder: any(named: 'attachmentOrder'),
          upload: any(named: 'upload'),
          onLocalMessageStored: any(named: 'onLocalMessageStored'),
        ),
      );
      expect(bloc.state.composerError, isNull);

      await bloc.close();
    },
  );

  test('XMPP attachments do not drop calendar task payloads', () async {
    final task = CalendarTask(
      id: 'task-with-attachment',
      title: 'Review launch plan',
      createdAt: DateTime.utc(2026, 3, 11, 8),
      modifiedAt: DateTime.utc(2026, 3, 11, 9),
    );
    final completer = Completer<List<PendingAttachment>>();
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
        text: 'Please review',
        recipients: [
          ComposerRecipient(
            target: Contact.chat(
              chat: initialChat,
              shareSignatureEnabled: true,
            ),
          ),
        ],
        pendingAttachments: const [
          PendingAttachment(
            id: 'task-normal-attachment',
            attachment: EmailAttachment(
              path: '/tmp/mock',
              fileName: 'mock.txt',
              sizeBytes: 0,
            ),
          ),
        ],
        settings: _defaultChatSettings(),
        supportsHttpFileUpload: true,
        calendarTaskIcs: task,
        calendarTaskIcsReadOnly: false,
        calendarTaskShareText: 'Review launch plan',
        completer: completer,
      ),
    );
    await completer.future;

    verify(
      () => messageService.sendAttachment(
        jid: initialChat.jid,
        attachment: any(named: 'attachment'),
        encryptionProtocol: EncryptionProtocol.none,
        chatType: ChatType.chat,
        quotedMessage: any(named: 'quotedMessage'),
        groupQuotedReference: any(named: 'groupQuotedReference'),
        htmlCaption: any(named: 'htmlCaption'),
        transportGroupId: any(named: 'transportGroupId'),
        attachmentOrder: any(named: 'attachmentOrder'),
        upload: any(named: 'upload'),
        onLocalMessageStored: any(named: 'onLocalMessageStored'),
      ),
    ).called(1);
    verify(
      () => messageService.sendMessage(
        jid: initialChat.jid,
        text: 'Please review',
        encryptionProtocol: EncryptionProtocol.none,
        quotedMessage: any(named: 'quotedMessage'),
        calendarTaskIcs: task,
        calendarTaskIcsReadOnly: false,
        chatType: ChatType.chat,
        onLocalMessageStored: any(named: 'onLocalMessageStored'),
      ),
    ).called(1);
    expect(bloc.state.composerClearId, 1);

    await bloc.close();
  });

  test('resending welcome text uses the local-only message path', () async {
    final message = Message(
      stanzaID: 'resend-welcome-text',
      senderJid: welcomeChat.jid,
      chatJid: welcomeChat.jid,
      body: 'Retry welcome',
      timestamp: DateTime.now(),
    );

    final bloc = ChatBloc(
      jid: welcomeChat.jid,
      messageService: messageService,
      chatsService: chatsService,
      mucService: mucService,
      notificationService: notificationService,
      settings: _defaultChatSettings(),
    );

    chatStreamController.add(welcomeChat);
    messageStreamController.add(const <Message>[]);
    await _pumpBloc();

    bloc.add(
      ChatMessageResendRequested(message: message, chatType: ChatType.chat),
    );
    await _pumpBloc();

    verify(
      () => messageService.sendLocalOnlyMessage(
        jid: welcomeChat.jid,
        text: 'Retry welcome',
        encryptionProtocol: EncryptionProtocol.none,
        htmlBody: any(named: 'htmlBody'),
        quotedMessage: any(named: 'quotedMessage'),
        calendarFragment: any(named: 'calendarFragment'),
        calendarTaskIcs: any(named: 'calendarTaskIcs'),
        calendarTaskIcsReadOnly: any(named: 'calendarTaskIcsReadOnly'),
        calendarAvailabilityMessage: any(named: 'calendarAvailabilityMessage'),
        forwarded: any(named: 'forwarded'),
        forwardedFromJid: any(named: 'forwardedFromJid'),
        forwardedOriginalSenderLabel: any(
          named: 'forwardedOriginalSenderLabel',
        ),
        chatType: ChatType.chat,
      ),
    ).called(1);
    verifyNever(
      () => messageService.resendMessage(
        'resend-welcome-text',
        chatType: ChatType.chat,
      ),
    );

    await bloc.close();
  });

  test(
    'send again marks the original stale unacked message after local copy',
    () async {
      final message = Message(
        stanzaID: 'stale-unacked-message',
        senderJid: 'self@axi.im',
        chatJid: initialChat.jid,
        body: 'Still pending',
        timestamp: DateTime.timestamp().subtract(
          xmpp.XmppStreamManagementManager.ackTimeoutDuration +
              const Duration(minutes: 1),
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
      messageStreamController.add([message]);
      await _pumpBloc();

      bloc.add(
        ChatMessageResendRequested(message: message, chatType: ChatType.chat),
      );
      await _pumpBloc();
      await _pumpBloc();

      verify(
        () => messageService.resendMessage(
          'stale-unacked-message',
          chatType: ChatType.chat,
          onLocalMessageStored: any(named: 'onLocalMessageStored'),
        ),
      ).called(1);
      verify(
        () => messageService.markMessageManualSendAgain(
          stanzaID: 'stale-unacked-message',
          sendAgainStanzaID: 'manual-send-again-copy',
        ),
      ).called(1);

      await bloc.close();
    },
  );

  test('resend action clears loading and shows success toast', () async {
    final message = Message(
      stanzaID: 'resend-loading-message',
      senderJid: 'self@axi.im',
      chatJid: initialChat.jid,
      body: 'Retry me',
      timestamp: DateTime.timestamp(),
    );
    final resendCompleter = Completer<bool>();
    when(
      () => messageService.resendMessage(
        'resend-loading-message',
        chatType: ChatType.chat,
      ),
    ).thenAnswer((_) => resendCompleter.future);

    final bloc = ChatBloc(
      jid: initialChat.jid,
      messageService: messageService,
      chatsService: chatsService,
      mucService: mucService,
      notificationService: notificationService,
      settings: _defaultChatSettings(),
    );

    chatStreamController.add(initialChat);
    messageStreamController.add([message]);
    await _pumpBloc();

    bloc.add(
      ChatMessageResendRequested(message: message, chatType: ChatType.chat),
    );
    await _pumpBloc();

    expect(
      bloc.state.resendLoadingMessageIds,
      contains('resend-loading-message'),
    );
    expect(bloc.state.toast, isNull);

    resendCompleter.complete(true);
    await _pumpBloc();
    await _pumpBloc();

    expect(bloc.state.resendLoadingMessageIds, isEmpty);
    expect(
      bloc.state.toast,
      const ChatToast(message: ChatMessageKey.chatMessageSentAgain),
    );
    expect(bloc.state.toastId, 1);

    await bloc.close();
  });

  test('resend action clears loading when resend fails', () async {
    final message = Message(
      stanzaID: 'resend-failed-message',
      senderJid: 'self@axi.im',
      chatJid: initialChat.jid,
      body: 'Retry me',
      timestamp: DateTime.timestamp(),
    );
    final resendCompleter = Completer<bool>();
    when(
      () => messageService.resendMessage(
        'resend-failed-message',
        chatType: ChatType.chat,
      ),
    ).thenAnswer((_) => resendCompleter.future);

    final bloc = ChatBloc(
      jid: initialChat.jid,
      messageService: messageService,
      chatsService: chatsService,
      mucService: mucService,
      notificationService: notificationService,
      settings: _defaultChatSettings(),
    );

    chatStreamController.add(initialChat);
    messageStreamController.add([message]);
    await _pumpBloc();

    bloc.add(
      ChatMessageResendRequested(message: message, chatType: ChatType.chat),
    );
    await _pumpBloc();

    expect(
      bloc.state.resendLoadingMessageIds,
      contains('resend-failed-message'),
    );

    resendCompleter.completeError(Exception('resend failed'));
    await _pumpBloc();
    await _pumpBloc();

    expect(bloc.state.resendLoadingMessageIds, isEmpty);
    expect(bloc.state.toast, isNull);

    await bloc.close();
  });

  test(
    'send again clears loading and suppresses success toast when resend no-ops',
    () async {
      final message = Message(
        stanzaID: 'send-again-no-op',
        senderJid: 'self@axi.im',
        chatJid: initialChat.jid,
        body: 'Still pending',
        timestamp: DateTime.timestamp().subtract(
          xmpp.XmppStreamManagementManager.ackTimeoutDuration +
              const Duration(minutes: 1),
        ),
      );
      final resendCompleter = Completer<bool>();
      when(
        () => messageService.resendMessage(
          'send-again-no-op',
          chatType: ChatType.chat,
          onLocalMessageStored: any(named: 'onLocalMessageStored'),
        ),
      ).thenAnswer((_) => resendCompleter.future);

      final bloc = ChatBloc(
        jid: initialChat.jid,
        messageService: messageService,
        chatsService: chatsService,
        mucService: mucService,
        notificationService: notificationService,
        settings: _defaultChatSettings(),
      );

      chatStreamController.add(initialChat);
      messageStreamController.add([message]);
      await _pumpBloc();

      bloc.add(
        ChatMessageResendRequested(message: message, chatType: ChatType.chat),
      );
      await _pumpBloc();

      expect(bloc.state.resendLoadingMessageIds, contains('send-again-no-op'));

      resendCompleter.complete(false);
      await _pumpBloc();
      await _pumpBloc();

      expect(bloc.state.resendLoadingMessageIds, isEmpty);
      expect(bloc.state.toast, isNull);
      expect(bloc.state.toastId, 0);
      verifyNever(
        () => messageService.markMessageManualSendAgain(
          stanzaID: 'send-again-no-op',
          sendAgainStanzaID: any(named: 'sendAgainStanzaID'),
        ),
      );

      await bloc.close();
    },
  );

  test(
    'send again does not mark or toast when resend fails after local copy',
    () async {
      final message = Message(
        stanzaID: 'send-again-copy-then-fails',
        senderJid: 'self@axi.im',
        chatJid: initialChat.jid,
        body: 'Still pending',
        timestamp: DateTime.timestamp().subtract(
          xmpp.XmppStreamManagementManager.ackTimeoutDuration +
              const Duration(minutes: 1),
        ),
      );
      final resendCompleter = Completer<void>();
      when(
        () => messageService.resendMessage(
          'send-again-copy-then-fails',
          chatType: ChatType.chat,
          onLocalMessageStored: any(named: 'onLocalMessageStored'),
        ),
      ).thenAnswer((invocation) async {
        final callback =
            invocation.namedArguments[#onLocalMessageStored]
                as void Function(String)?;
        callback?.call('send-again-copy-before-failure');
        await resendCompleter.future;
        throw Exception('resend failed after local copy');
      });

      final bloc = ChatBloc(
        jid: initialChat.jid,
        messageService: messageService,
        chatsService: chatsService,
        mucService: mucService,
        notificationService: notificationService,
        settings: _defaultChatSettings(),
      );

      chatStreamController.add(initialChat);
      messageStreamController.add([message]);
      await _pumpBloc();

      bloc.add(
        ChatMessageResendRequested(message: message, chatType: ChatType.chat),
      );
      await _pumpBloc();

      expect(
        bloc.state.resendLoadingMessageIds,
        contains('send-again-copy-then-fails'),
      );

      resendCompleter.complete();
      await _pumpBloc();
      await _pumpBloc();

      expect(bloc.state.resendLoadingMessageIds, isEmpty);
      expect(bloc.state.toast, isNull);
      expect(bloc.state.toastId, 0);
      verifyNever(
        () => messageService.markMessageManualSendAgain(
          stanzaID: 'send-again-copy-then-fails',
          sendAgainStanzaID: 'send-again-copy-before-failure',
        ),
      );

      await bloc.close();
    },
  );

  test(
    'send again clears loading and suppresses success toast when marker fails',
    () async {
      final message = Message(
        stanzaID: 'send-again-marker-fails',
        senderJid: 'self@axi.im',
        chatJid: initialChat.jid,
        body: 'Still pending',
        timestamp: DateTime.timestamp().subtract(
          xmpp.XmppStreamManagementManager.ackTimeoutDuration +
              const Duration(minutes: 1),
        ),
      );
      final resendCompleter = Completer<bool>();
      when(
        () => messageService.resendMessage(
          'send-again-marker-fails',
          chatType: ChatType.chat,
          onLocalMessageStored: any(named: 'onLocalMessageStored'),
        ),
      ).thenAnswer((invocation) async {
        final callback =
            invocation.namedArguments[#onLocalMessageStored]
                as void Function(String)?;
        callback?.call('send-again-marker-fails-copy');
        return resendCompleter.future;
      });
      when(
        () => messageService.markMessageManualSendAgain(
          stanzaID: 'send-again-marker-fails',
          sendAgainStanzaID: 'send-again-marker-fails-copy',
        ),
      ).thenAnswer((_) async => throw Exception('marker failed'));

      final bloc = ChatBloc(
        jid: initialChat.jid,
        messageService: messageService,
        chatsService: chatsService,
        mucService: mucService,
        notificationService: notificationService,
        settings: _defaultChatSettings(),
      );

      chatStreamController.add(initialChat);
      messageStreamController.add([message]);
      await _pumpBloc();

      bloc.add(
        ChatMessageResendRequested(message: message, chatType: ChatType.chat),
      );
      await _pumpBloc();

      expect(
        bloc.state.resendLoadingMessageIds,
        contains('send-again-marker-fails'),
      );

      resendCompleter.complete(true);
      await _pumpBloc();
      await _pumpBloc();

      expect(bloc.state.resendLoadingMessageIds, isEmpty);
      expect(bloc.state.toast, isNull);
      expect(bloc.state.toastId, 0);

      await bloc.close();
    },
  );

  test(
    'send again clears loading and suppresses success toast without copy id',
    () async {
      final message = Message(
        stanzaID: 'send-again-copy-missing',
        senderJid: 'self@axi.im',
        chatJid: initialChat.jid,
        body: 'Still pending',
        timestamp: DateTime.timestamp().subtract(
          xmpp.XmppStreamManagementManager.ackTimeoutDuration +
              const Duration(minutes: 1),
        ),
      );
      final resendCompleter = Completer<bool>();
      when(
        () => messageService.resendMessage(
          'send-again-copy-missing',
          chatType: ChatType.chat,
          onLocalMessageStored: any(named: 'onLocalMessageStored'),
        ),
      ).thenAnswer((_) => resendCompleter.future);

      final bloc = ChatBloc(
        jid: initialChat.jid,
        messageService: messageService,
        chatsService: chatsService,
        mucService: mucService,
        notificationService: notificationService,
        settings: _defaultChatSettings(),
      );

      chatStreamController.add(initialChat);
      messageStreamController.add([message]);
      await _pumpBloc();

      bloc.add(
        ChatMessageResendRequested(message: message, chatType: ChatType.chat),
      );
      await _pumpBloc();

      expect(
        bloc.state.resendLoadingMessageIds,
        contains('send-again-copy-missing'),
      );

      resendCompleter.complete(true);
      await _pumpBloc();
      await _pumpBloc();

      expect(bloc.state.resendLoadingMessageIds, isEmpty);
      expect(bloc.state.toast, isNull);
      expect(bloc.state.toastId, 0);
      verifyNever(
        () => messageService.markMessageManualSendAgain(
          stanzaID: 'send-again-copy-missing',
          sendAgainStanzaID: any(named: 'sendAgainStanzaID'),
        ),
      );

      await bloc.close();
    },
  );

  test(
    'verifies stale unacked messages from MAM before initial messages load',
    () async {
      final message = Message(
        stanzaID: 'initial-stale-unacked-message',
        senderJid: 'self@axi.im',
        chatJid: initialChat.jid,
        body: 'Still pending',
        timestamp: DateTime.timestamp().subtract(
          xmpp.XmppStreamManagementManager.ackTimeoutDuration +
              const Duration(minutes: 1),
        ),
      );
      final verificationCompleter = Completer<void>();
      when(
        () => messageService.verifyUnackedMessagesFromMamForChat(
          chat: any(named: 'chat'),
          candidates: any(named: 'candidates'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer((_) => verificationCompleter.future);
      when(
        () => messageService.loadMessagesByReferenceIds(
          any(),
          chatJid: any(named: 'chatJid'),
        ),
      ).thenAnswer((_) async => [message.copyWith(acked: true)]);
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
      await _pumpBloc();
      messageStreamController.add([message]);
      await _pumpBloc();
      expect(bloc.state.messagesLoaded, isFalse);

      verificationCompleter.complete();
      await _pumpBloc();
      await _pumpBloc();

      expect(bloc.state.messagesLoaded, isTrue);
      expect(bloc.state.items.single.acked, isTrue);

      final verification = verify(
        () => messageService.verifyUnackedMessagesFromMamForChat(
          chat: any(named: 'chat'),
          candidates: captureAny(named: 'candidates'),
          pageSize: ChatBloc.messageBatchSize,
        ),
      );
      verification.called(1);
      final candidates = verification.captured.single as Iterable<Message>;
      expect(
        candidates.map((message) => message.stanzaID),
        contains('initial-stale-unacked-message'),
      );

      await bloc.close();
    },
  );

  test(
    'keeps pre-chat stale unacked messages unloaded until MAM verification',
    () async {
      final message = Message(
        stanzaID: 'pre-chat-stale-unacked-message',
        senderJid: 'self@axi.im',
        chatJid: initialChat.jid,
        body: 'Still pending',
        timestamp: DateTime.timestamp().subtract(
          xmpp.XmppStreamManagementManager.ackTimeoutDuration +
              const Duration(minutes: 1),
        ),
      );
      final verificationCompleter = Completer<void>();
      when(
        () => messageService.verifyUnackedMessagesFromMamForChat(
          chat: any(named: 'chat'),
          candidates: any(named: 'candidates'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer((_) => verificationCompleter.future);
      when(
        () => messageService.loadMessagesByReferenceIds(
          any(),
          chatJid: any(named: 'chatJid'),
        ),
      ).thenAnswer((_) async => [message.copyWith(acked: true)]);
      final bloc = ChatBloc(
        jid: initialChat.jid,
        messageService: messageService,
        chatsService: chatsService,
        mucService: mucService,
        notificationService: notificationService,
        settings: _defaultChatSettings(),
      );

      await _pumpBloc();
      messageStreamController.add([message]);
      await _pumpBloc();
      await _pumpBloc();

      expect(bloc.state.chat, isNull);
      expect(bloc.state.items.single.stanzaID, message.stanzaID);
      expect(bloc.state.messagesLoaded, isFalse);

      chatStreamController.add(initialChat);
      await _pumpBloc();
      await _pumpBloc();

      expect(bloc.state.chat, initialChat);
      expect(bloc.state.messagesLoaded, isFalse);

      verificationCompleter.complete();
      await _pumpBloc();
      await _pumpBloc();

      expect(bloc.state.messagesLoaded, isTrue);
      expect(bloc.state.items.single.acked, isTrue);

      final verification = verify(
        () => messageService.verifyUnackedMessagesFromMamForChat(
          chat: any(named: 'chat'),
          candidates: captureAny(named: 'candidates'),
          pageSize: ChatBloc.messageBatchSize,
        ),
      );
      verification.called(1);
      final candidates = verification.captured.single as Iterable<Message>;
      expect(
        candidates.map((message) => message.stanzaID),
        contains('pre-chat-stale-unacked-message'),
      );

      await bloc.close();
    },
  );

  test(
    'marks empty pre-chat message batches loaded after chat initializes',
    () async {
      final bloc = ChatBloc(
        jid: initialChat.jid,
        messageService: messageService,
        chatsService: chatsService,
        mucService: mucService,
        notificationService: notificationService,
        settings: _defaultChatSettings(),
      );

      await _pumpBloc();
      messageStreamController.add(const <Message>[]);
      await _pumpBloc();
      await _pumpBloc();

      expect(bloc.state.chat, isNull);
      expect(bloc.state.items, isEmpty);
      expect(bloc.state.messagesLoaded, isFalse);

      chatStreamController.add(initialChat);
      await _pumpBloc();
      await _pumpBloc();

      expect(bloc.state.chat, initialChat);
      expect(bloc.state.messagesLoaded, isTrue);
      verifyNever(
        () => messageService.verifyUnackedMessagesFromMamForChat(
          chat: any(named: 'chat'),
          candidates: any(named: 'candidates'),
          pageSize: any(named: 'pageSize'),
        ),
      );

      await bloc.close();
    },
  );

  test(
    'send again marks the original stale unacked invite after local copy',
    () async {
      when(
        () => mucService.resendInvitePseudoMessage(
          any(),
          onLocalMessageStored: any(named: 'onLocalMessageStored'),
        ),
      ).thenAnswer((invocation) async {
        final callback =
            invocation.namedArguments[#onLocalMessageStored]
                as void Function(String)?;
        callback?.call('manual-send-again-invite-copy');
      });

      final message = Message(
        stanzaID: 'stale-unacked-invite',
        senderJid: 'self@axi.im',
        chatJid: initialChat.jid,
        body: 'You have been invited to a group chat',
        timestamp: DateTime.timestamp().subtract(
          xmpp.XmppStreamManagementManager.ackTimeoutDuration +
              const Duration(minutes: 1),
        ),
        pseudoMessageType: PseudoMessageType.mucInvite,
        pseudoMessageData: const <String, dynamic>{
          'roomJid': 'room@conference.axi.im',
          'invitee': 'peer@axi.im',
          'token': 'invite-token',
        },
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
      messageStreamController.add([message]);
      await _pumpBloc();

      bloc.add(
        ChatMessageResendRequested(message: message, chatType: ChatType.chat),
      );
      await _pumpBloc();
      await _pumpBloc();

      verify(
        () => mucService.resendInvitePseudoMessage(
          message,
          onLocalMessageStored: any(named: 'onLocalMessageStored'),
        ),
      ).called(1);
      verify(
        () => messageService.markMessageManualSendAgain(
          stanzaID: 'stale-unacked-invite',
          sendAgainStanzaID: 'manual-send-again-invite-copy',
        ),
      ).called(1);

      await bloc.close();
    },
  );

  test(
    'accepting an invite passes acceptance metadata to the MUC service',
    () async {
      final message = Message(
        stanzaID: 'invite-to-accept',
        senderJid: 'peer@axi.im',
        chatJid: initialChat.jid,
        body: 'You have been invited to a group chat',
        timestamp: DateTime(2024, 1, 1),
        pseudoMessageType: PseudoMessageType.mucInvite,
        pseudoMessageData: const <String, dynamic>{
          'roomJid': 'room@conference.axi.im',
          'roomName': 'Planning',
          'inviter': 'peer@axi.im',
          'invitee': 'self@axi.im',
          'token': 'invite-token',
          'password': 'secret',
        },
      );
      final bloc = ChatBloc(
        jid: initialChat.jid,
        messageService: messageService,
        chatsService: chatsService,
        mucService: mucService,
        notificationService: notificationService,
        settings: _defaultChatSettings(),
      );

      bloc.add(ChatInviteJoinRequested(message));
      await _pumpBloc();
      await _pumpBloc();

      verify(
        () => mucService.acceptRoomInvite(
          roomJid: 'room@conference.axi.im',
          roomName: 'Planning',
          inviteToken: 'invite-token',
          inviterJid: 'peer@axi.im',
          inviteeJid: 'self@axi.im',
          password: 'secret',
        ),
      ).called(1);
      expect(
        bloc.state.toast,
        const ChatToast(message: ChatMessageKey.chatInviteJoinSuccess),
      );

      await bloc.close();
    },
  );

  test(
    'resending welcome attachments uses the local-only attachment path',
    () async {
      final file = File(
        '${Directory.systemTemp.path}/axichat-resend-welcome-attachment.txt',
      );
      await file.writeAsString('resend welcome attachment');
      addTearDown(() async {
        if (await file.exists()) {
          await file.delete();
        }
      });
      when(
        () => messageService.loadFileMetadata('resend-welcome-meta'),
      ).thenAnswer(
        (_) async => FileMetadataData(
          id: 'resend-welcome-meta',
          filename: 'resend.txt',
          mimeType: 'text/plain',
          path: file.path,
          sizeBytes: await file.length(),
        ),
      );
      final message = Message(
        stanzaID: 'resend-welcome-attachment',
        senderJid: welcomeChat.jid,
        chatJid: welcomeChat.jid,
        body: 'Resend caption',
        fileMetadataID: 'resend-welcome-meta',
        timestamp: DateTime.now(),
      );

      final bloc = ChatBloc(
        jid: welcomeChat.jid,
        messageService: messageService,
        chatsService: chatsService,
        mucService: mucService,
        notificationService: notificationService,
        settings: _defaultChatSettings(),
      );

      chatStreamController.add(welcomeChat);
      messageStreamController.add(const <Message>[]);
      await _pumpBloc();

      bloc.add(
        ChatMessageResendRequested(message: message, chatType: ChatType.chat),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      verify(
        () => messageService.sendLocalOnlyAttachment(
          jid: welcomeChat.jid,
          attachment: any(named: 'attachment'),
          encryptionProtocol: EncryptionProtocol.none,
          quotedMessage: any(named: 'quotedMessage'),
          groupQuotedReference: any(named: 'groupQuotedReference'),
          htmlCaption: any(named: 'htmlCaption'),
          transportGroupId: any(named: 'transportGroupId'),
          attachmentOrder: any(named: 'attachmentOrder'),
          chatType: ChatType.chat,
        ),
      ).called(1);
      verify(
        () => messageService.loadFileMetadata('resend-welcome-meta'),
      ).called(1);
      verifyNever(
        () => messageService.sendAttachment(
          jid: welcomeChat.jid,
          attachment: any(named: 'attachment'),
          encryptionProtocol: any(named: 'encryptionProtocol'),
          quotedMessage: any(named: 'quotedMessage'),
          htmlCaption: any(named: 'htmlCaption'),
          transportGroupId: any(named: 'transportGroupId'),
          attachmentOrder: any(named: 'attachmentOrder'),
          chatType: any(named: 'chatType'),
        ),
      );
      verifyNever(
        () => messageService.resendMessage(
          'resend-welcome-attachment',
          chatType: ChatType.chat,
        ),
      );

      await bloc.close();
    },
  );

  test(
    'resending non-local forwarded attachments preserves forwarded metadata',
    () async {
      final file = File(
        '${Directory.systemTemp.path}/axichat-resend-forwarded-attachment.txt',
      );
      await file.writeAsString('resend forwarded attachment');
      addTearDown(() async {
        if (await file.exists()) {
          await file.delete();
        }
      });
      when(
        () => messageService.loadFileMetadata('resend-forwarded-meta'),
      ).thenAnswer(
        (_) async => FileMetadataData(
          id: 'resend-forwarded-meta',
          filename: 'resend-forwarded.txt',
          mimeType: 'text/plain',
          path: file.path,
          sizeBytes: await file.length(),
        ),
      );
      final message = Message(
        stanzaID: 'resend-forwarded-attachment',
        senderJid: initialChat.jid,
        chatJid: initialChat.jid,
        body: 'Forwarded caption',
        fileMetadataID: 'resend-forwarded-meta',
        timestamp: DateTime.now(),
        pseudoMessageData: const <String, dynamic>{
          'forwarded': true,
          'forwardedFromJid': 'forwarder@axi.im',
          'forwardedOriginalSenderLabel': 'Forwarder',
        },
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

      bloc.add(
        ChatMessageResendRequested(message: message, chatType: ChatType.chat),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      verify(
        () => messageService.sendAttachment(
          jid: initialChat.jid,
          attachment: any(named: 'attachment'),
          encryptionProtocol: EncryptionProtocol.none,
          quotedMessage: any(named: 'quotedMessage'),
          groupQuotedReference: any(named: 'groupQuotedReference'),
          htmlCaption: any(named: 'htmlCaption'),
          forwarded: true,
          forwardedFromJid: 'forwarder@axi.im',
          forwardedOriginalSenderLabel: 'Forwarder',
          transportGroupId: any(named: 'transportGroupId'),
          attachmentOrder: any(named: 'attachmentOrder'),
          chatType: ChatType.chat,
          quotedReference: any(named: 'quotedReference'),
          upload: any(named: 'upload'),
          onLocalMessageStored: any(named: 'onLocalMessageStored'),
        ),
      ).called(1);
      verify(
        () => messageService.loadFileMetadata('resend-forwarded-meta'),
      ).called(1);
      verifyNever(
        () => messageService.resendMessage(
          'resend-forwarded-attachment',
          chatType: ChatType.chat,
        ),
      );

      await bloc.close();
    },
  );

  test(
    'resending grouped attachments preserves stored quote metadata without loaded quoted message',
    () async {
      final firstFile = File(
        '${Directory.systemTemp.path}/axichat-resend-grouped-attachment-1.txt',
      );
      final secondFile = File(
        '${Directory.systemTemp.path}/axichat-resend-grouped-attachment-2.txt',
      );
      await firstFile.writeAsString('first grouped attachment');
      await secondFile.writeAsString('second grouped attachment');
      addTearDown(() async {
        if (await firstFile.exists()) {
          await firstFile.delete();
        }
        if (await secondFile.exists()) {
          await secondFile.delete();
        }
      });
      when(
        () => messageService.loadMessageAttachments('group-message-id'),
      ).thenAnswer(
        (_) async => const [
          MessageAttachmentData(
            id: 1,
            messageId: 'group-message-id',
            fileMetadataId: 'resend-group-meta-1',
            sortOrder: 0,
            transportGroupId: 'stored-group',
          ),
        ],
      );
      when(
        () => messageService.loadMessageAttachmentsForGroup('stored-group'),
      ).thenAnswer(
        (_) async => const [
          MessageAttachmentData(
            id: 1,
            messageId: 'group-message-id',
            fileMetadataId: 'resend-group-meta-1',
            sortOrder: 0,
            transportGroupId: 'stored-group',
          ),
          MessageAttachmentData(
            id: 2,
            messageId: 'group-message-id-2',
            fileMetadataId: 'resend-group-meta-2',
            sortOrder: 1,
            transportGroupId: 'stored-group',
          ),
        ],
      );
      when(
        () => messageService.loadFileMetadata('resend-group-meta-1'),
      ).thenAnswer(
        (_) async => FileMetadataData(
          id: 'resend-group-meta-1',
          filename: 'group-1.txt',
          mimeType: 'text/plain',
          path: firstFile.path,
          sizeBytes: await firstFile.length(),
        ),
      );
      when(
        () => messageService.loadFileMetadata('resend-group-meta-2'),
      ).thenAnswer(
        (_) async => FileMetadataData(
          id: 'resend-group-meta-2',
          filename: 'group-2.txt',
          mimeType: 'text/plain',
          path: secondFile.path,
          sizeBytes: await secondFile.length(),
        ),
      );
      when(
        () => messageService.loadMessageByReferenceId(
          'quoted-origin',
          chatJid: initialChat.jid,
        ),
      ).thenAnswer((_) async => null);
      final sendCalls = <Map<Symbol, dynamic>>[];
      when(
        () => messageService.sendAttachment(
          jid: any(named: 'jid'),
          attachment: any(named: 'attachment'),
          encryptionProtocol: any(named: 'encryptionProtocol'),
          htmlCaption: any(named: 'htmlCaption'),
          forwarded: any(named: 'forwarded'),
          forwardedFromJid: any(named: 'forwardedFromJid'),
          forwardedOriginalSenderLabel: any(
            named: 'forwardedOriginalSenderLabel',
          ),
          transportGroupId: any(named: 'transportGroupId'),
          attachmentOrder: any(named: 'attachmentOrder'),
          quotedMessage: any(named: 'quotedMessage'),
          quotedReference: any(named: 'quotedReference'),
          groupQuotedReference: any(named: 'groupQuotedReference'),
          chatType: any(named: 'chatType'),
          upload: any(named: 'upload'),
          onLocalMessageStored: any(named: 'onLocalMessageStored'),
        ),
      ).thenAnswer((invocation) async {
        sendCalls.add(Map<Symbol, dynamic>.from(invocation.namedArguments));
        return attachmentUpload;
      });
      const message = Message(
        id: 'group-message-id',
        stanzaID: 'resend-grouped-attachment',
        senderJid: 'peer@axi.im',
        chatJid: 'peer@axi.im',
        body: 'Grouped caption',
        quoting: 'quoted-origin',
        quotingReferenceKind: MessageReferenceKind.originId,
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

      bloc.add(
        const ChatMessageResendRequested(
          message: message,
          chatType: ChatType.chat,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(sendCalls, hasLength(2));
      final firstQuotedReference =
          sendCalls.first[#quotedReference] as MessageReference?;
      final secondQuotedReference =
          sendCalls.last[#quotedReference] as MessageReference?;
      expect(firstQuotedReference?.value, 'quoted-origin');
      expect(firstQuotedReference?.kind, MessageReferenceKind.originId);
      expect(secondQuotedReference, isNull);
      expect(sendCalls.first[#quotedMessage], isNull);
      for (final call in sendCalls) {
        final groupQuotedReference =
            call[#groupQuotedReference] as MessageReference?;
        expect(groupQuotedReference?.value, 'quoted-origin');
        expect(groupQuotedReference?.kind, MessageReferenceKind.originId);
      }
      expect(
        sendCalls.first[#transportGroupId],
        sendCalls.last[#transportGroupId],
      );

      await bloc.close();
    },
  );

  test(
    'resending failed invite pseudo-messages uses the MUC resend path',
    () async {
      final message = Message(
        stanzaID: 'failed-invite',
        senderJid: 'self@axi.im',
        chatJid: initialChat.jid,
        body: 'You have been invited to a group chat',
        timestamp: DateTime.now(),
        pseudoMessageType: PseudoMessageType.mucInvite,
        pseudoMessageData: const <String, dynamic>{
          'roomJid': 'room@conference.axi.im',
          'invitee': 'friend@axi.im',
          'token': 'invite-token',
        },
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

      bloc.add(
        ChatMessageResendRequested(message: message, chatType: ChatType.chat),
      );
      await _pumpBloc();

      verify(
        () => mucService.resendInvitePseudoMessage(
          message,
          onLocalMessageStored: any(named: 'onLocalMessageStored'),
        ),
      ).called(1);
      verifyNever(
        () => messageService.resendMessage(
          'failed-invite',
          chatType: ChatType.chat,
        ),
      );

      await bloc.close();
    },
  );

  test(
    'email resend fallback preserves forwarded metadata for message bodies',
    () async {
      final emailService = MockEmailService();
      _mockEmailSync(emailService);
      when(
        () => emailService.resendMessages(any()),
      ).thenAnswer((_) async => false);
      when(
        () => emailService.sendMessage(
          chat: any(named: 'chat'),
          body: any(named: 'body'),
          subject: any(named: 'subject'),
          htmlBody: any(named: 'htmlBody'),
          forwarded: any(named: 'forwarded'),
          forwardedFromJid: any(named: 'forwardedFromJid'),
          forwardedOriginalSenderLabel: any(
            named: 'forwardedOriginalSenderLabel',
          ),
          quotedStanzaId: any(named: 'quotedStanzaId'),
        ),
      ).thenAnswer((_) async => 1);
      final emailChat = Chat(
        jid: 'peer@delta.chat',
        title: 'peer@example.com',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.now(),
        deltaChatId: 11,
        emailAddress: 'peer@example.com',
      );
      final message = Message(
        stanzaID: 'failed-email-forward',
        senderJid: 'self@example.com',
        chatJid: emailChat.jid,
        body: 'Retry forwarded email',
        timestamp: DateTime.now(),
        deltaChatId: emailChat.deltaChatId,
        deltaMsgId: 44,
        deltaAccountId: 1,
        pseudoMessageData: const <String, dynamic>{
          'forwarded': true,
          'forwardedFromJid': 'forwarder@example.com',
          'forwardedOriginalSenderLabel': 'Forwarder',
        },
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

      bloc.add(
        ChatMessageResendRequested(message: message, chatType: ChatType.chat),
      );
      await _pumpBloc();

      verify(() => emailService.resendMessages([message])).called(1);
      verify(
        () => emailService.sendMessage(
          chat: emailChat,
          body: 'Retry forwarded email',
          subject: any(named: 'subject'),
          htmlBody: any(named: 'htmlBody'),
          forwarded: true,
          forwardedFromJid: 'forwarder@example.com',
          forwardedOriginalSenderLabel: 'Forwarder',
          quotedStanzaId: any(named: 'quotedStanzaId'),
        ),
      ).called(1);

      await bloc.close();
    },
  );

  test(
    'email resend fallback preserves forwarded metadata for attachments',
    () async {
      final file = File(
        '${Directory.systemTemp.path}/axichat-email-resend-forwarded.txt',
      );
      await file.writeAsString('email resend forwarded attachment');
      addTearDown(() async {
        if (await file.exists()) {
          await file.delete();
        }
      });
      final emailService = MockEmailService();
      _mockEmailSync(emailService);
      when(
        () => emailService.resendMessages(any()),
      ).thenAnswer((_) async => false);
      when(
        () => emailService.sendAttachment(
          chat: any(named: 'chat'),
          attachment: any(named: 'attachment'),
          subject: any(named: 'subject'),
          htmlCaption: any(named: 'htmlCaption'),
          forwarded: any(named: 'forwarded'),
          forwardedFromJid: any(named: 'forwardedFromJid'),
          forwardedOriginalSenderLabel: any(
            named: 'forwardedOriginalSenderLabel',
          ),
          quotedStanzaId: any(named: 'quotedStanzaId'),
        ),
      ).thenAnswer((_) async => 1);
      when(
        () => messageService.loadFileMetadata('email-forwarded-meta'),
      ).thenAnswer(
        (_) async => FileMetadataData(
          id: 'email-forwarded-meta',
          filename: 'email-forwarded.txt',
          mimeType: 'text/plain',
          path: file.path,
          sizeBytes: await file.length(),
        ),
      );
      final emailChat = Chat(
        jid: 'peer@delta.chat',
        title: 'peer@example.com',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.now(),
        deltaChatId: 11,
        emailAddress: 'peer@example.com',
      );
      final message = Message(
        stanzaID: 'failed-email-forward-attachment',
        senderJid: 'self@example.com',
        chatJid: emailChat.jid,
        body: 'Retry forwarded attachment',
        fileMetadataID: 'email-forwarded-meta',
        timestamp: DateTime.now(),
        deltaChatId: emailChat.deltaChatId,
        deltaMsgId: 45,
        deltaAccountId: 1,
        pseudoMessageData: const <String, dynamic>{
          'forwarded': true,
          'forwardedFromJid': 'forwarder@example.com',
          'forwardedOriginalSenderLabel': 'Forwarder',
        },
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

      bloc.add(
        ChatMessageResendRequested(message: message, chatType: ChatType.chat),
      );
      await untilCalled(
        () => emailService.sendAttachment(
          chat: any(named: 'chat'),
          attachment: any(named: 'attachment'),
          subject: any(named: 'subject'),
          htmlCaption: any(named: 'htmlCaption'),
          forwarded: any(named: 'forwarded'),
          forwardedFromJid: any(named: 'forwardedFromJid'),
          forwardedOriginalSenderLabel: any(
            named: 'forwardedOriginalSenderLabel',
          ),
          quotedStanzaId: any(named: 'quotedStanzaId'),
        ),
      );

      verify(() => emailService.resendMessages([message])).called(1);
      verify(
        () => emailService.sendAttachment(
          chat: emailChat,
          attachment: any(named: 'attachment'),
          subject: any(named: 'subject'),
          htmlCaption: any(named: 'htmlCaption'),
          forwarded: true,
          forwardedFromJid: 'forwarder@example.com',
          forwardedOriginalSenderLabel: 'Forwarder',
          quotedStanzaId: any(named: 'quotedStanzaId'),
        ),
      ).called(1);

      await bloc.close();
    },
  );

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

  test('forward draft falls back to plain text from XMPP HTML', () async {
    final message = Message(
      stanzaID: 'forward-xmpp-html',
      senderJid: initialChat.jid,
      chatJid: initialChat.jid,
      body: null,
      htmlBody: '<p><strong>Bold body</strong></p>',
      timestamp: DateTime.now(),
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

    bloc.add(ChatMessageForwardRequested(message: message));
    await _pumpBloc();

    expect(
      bloc.state.pendingForwardDraft?.sources.single.originalPlainTextBody,
      'Bold body',
    );
    expect(
      bloc.state.pendingForwardDraft?.sources.single.originalHtmlBody,
      isNull,
    );

    await bloc.close();
  });

  test(
    'forward draft keeps visible quote context as forwarded content',
    () async {
      const quotedMessage = Message(
        stanzaID: 'quoted-stanza',
        originID: 'quoted-origin',
        senderJid: 'original@axi.im',
        chatJid: 'peer@axi.im',
        body: 'Original text',
      );
      const message = Message(
        stanzaID: 'forward-reply',
        senderJid: 'peer@axi.im',
        chatJid: 'peer@axi.im',
        body: 'Reply text',
        quoting: 'quoted-origin',
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
      messageStreamController.add(const <Message>[quotedMessage, message]);
      await _pumpBloc();
      await _pumpBloc();

      expect(
        bloc.state.quotedMessagesById['quoted-origin']?.stanzaID,
        quotedMessage.stanzaID,
      );
      final forwardedMessage = bloc.state.items.singleWhere(
        (item) => item.stanzaID == message.stanzaID,
      );

      bloc.add(ChatMessageForwardRequested(message: forwardedMessage));
      await _pumpBloc();

      final quotedContext =
          bloc.state.pendingForwardDraft?.forwardedBlocks.single.quotedContext;
      expect(quotedContext?.senderLabel, 'original@axi.im');
      expect(quotedContext?.plainText, 'Original text');

      await bloc.close();
    },
  );

  test('forward draft treats basic email HTML as plain text', () async {
    const message = Message(
      stanzaID: 'forward-email-basic-html',
      senderJid: 'sender@example.com',
      chatJid: 'sender@example.com',
      body: 'Forwarded body',
      htmlBody: '<p><strong>Forwarded body</strong></p>',
      deltaChatId: 1,
      deltaMsgId: 2,
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

    bloc.add(const ChatMessageForwardRequested(message: message));
    await _pumpBloc();

    expect(
      bloc.state.pendingForwardDraft?.sources.single.originalPlainTextBody,
      'Forwarded body',
    );
    expect(
      bloc.state.pendingForwardDraft?.sources.single.originalHtmlBody,
      isNull,
    );

    await bloc.close();
  });

  test('forward draft retains rich email HTML', () async {
    const message = Message(
      stanzaID: 'forward-email-rich-html',
      senderJid: 'sender@example.com',
      chatJid: 'sender@example.com',
      body: 'Plain fallback',
      htmlBody: '<table><tr><td>Rich body</td></tr></table>',
      deltaChatId: 1,
      deltaMsgId: 2,
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

    bloc.add(const ChatMessageForwardRequested(message: message));
    await _pumpBloc();

    expect(
      bloc.state.pendingForwardDraft?.sources.single.originalPlainTextBody,
      'Plain fallback',
    );
    expect(
      bloc.state.pendingForwardDraft?.sources.single.originalHtmlBody,
      '<table><tr><td>Rich body</td></tr></table>',
    );

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

  test(
    'chat send uses the event recipient list as the source of truth',
    () async {
      final emailService = MockEmailService();
      _mockEmailSync(emailService);
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
          included: false,
        ),
      ];
      bloc.add(
        _messageSent(
          chat: emailChat,
          text: 'Hello from UI list',
          recipients: recipients,
          settings: _defaultChatSettings(),
        ),
      );
      await _pumpBloc();

      verify(
        () => emailService.sendMessage(
          chat: emailChat,
          body: 'Hello from UI list',
          subject: null,
          htmlBody: HtmlContentCodec.fromPlainText('Hello from UI list'),
        ),
      ).called(1);

      await bloc.close();
    },
  );

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
        () => messageService.loadMessageByReferenceId(
          'filtered-pin',
          chatJid: initialChat.jid,
        ),
      ).thenAnswer((_) async => target);
      when(
        () => messageService.countChatMessagesThrough(
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
      );
      verify(
        () => messageService.countChatMessagesThrough(
          initialChat.jid,
          throughTimestamp: target.timestamp!,
          throughStanzaId: target.stanzaID,
          throughDeltaMsgId: target.deltaMsgId,
          filter: MessageTimelineFilter.allWithContact,
        ),
      );

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
        () => messageService.countChatMessagesThrough(
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
      verify(
        () => messageService.countChatMessagesThrough(
          initialChat.jid,
          throughTimestamp: target.timestamp!,
          throughStanzaId: target.stanzaID,
          throughDeltaMsgId: target.deltaMsgId,
          filter: MessageTimelineFilter.allWithContact,
        ),
      ).called(1);

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
      when(
        () => messageService.loadMessageByReferenceId(
          any(),
          chatJid: emailChat.jid,
        ),
      ).thenAnswer((invocation) async {
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
        () => messageService.countChatMessagesThrough(
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
      );
      verify(
        () => messageService.countChatMessagesThrough(
          emailChat.jid,
          throughTimestamp: target.timestamp!,
          throughStanzaId: target.stanzaID,
          throughDeltaMsgId: target.deltaMsgId,
          filter: MessageTimelineFilter.allWithContact,
        ),
      );
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
        () => messageService.countChatMessagesThrough(
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
      verify(
        () => messageService.countChatMessagesThrough(
          emailChat.jid,
          throughTimestamp: target.timestamp!,
          throughStanzaId: target.stanzaID,
          throughDeltaMsgId: target.deltaMsgId,
          filter: MessageTimelineFilter.allWithContact,
        ),
      );

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
    'email unread bootstrap keeps the first page available for backfill',
    () async {
      final emailService = MockEmailService();
      final emailMessageStreamController =
          StreamController<List<Message>>.broadcast();
      _mockEmailSync(emailService);

      final emailChat = initialChat.copyWith(
        deltaChatId: 8,
        emailAddress: 'peer@example.com',
        transport: MessageTransport.email,
        unreadCount: ChatBloc.messageBatchSize + 5,
      );
      final newest = Message(
        stanzaID: 'email-newest-for-bootstrap',
        senderJid: 'peer@example.com',
        chatJid: emailChat.jid,
        deltaChatId: emailChat.deltaChatId,
        deltaMsgId: 205,
        deltaAccountId: 3,
        timestamp: DateTime(2026, 1, 5, 10),
        body: 'Newest visible email',
      );

      when(
        () => emailService.getOldestFreshMessageId(any()),
      ).thenAnswer((_) async => 101);
      when(
        () => emailService.messageStreamForChat(
          any(),
          start: any(named: 'start'),
          end: any(named: 'end'),
          filter: any(named: 'filter'),
        ),
      ).thenAnswer((_) => emailMessageStreamController.stream);
      when(
        () => messageService.loadMessageByDeltaId(
          any(),
          chatJid: any(named: 'chatJid'),
        ),
      ).thenAnswer((_) async => null);

      late ChatBloc bloc;
      when(
        () => emailService.backfillChatHistory(
          chat: any(named: 'chat'),
          desiredWindow: any(named: 'desiredWindow'),
          beforeMessageId: any(named: 'beforeMessageId'),
          beforeTimestamp: any(named: 'beforeTimestamp'),
          filter: any(named: 'filter'),
        ),
      ).thenAnswer((invocation) async {
        expect(bloc.state.items, [newest]);
        expect(invocation.namedArguments[#beforeMessageId], newest.deltaMsgId);
      });

      bloc = ChatBloc(
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
      await _pumpBloc();

      verify(
        () => emailService.backfillChatHistory(
          chat: emailChat,
          desiredWindow: ChatBloc.messageBatchSize + 5,
          beforeMessageId: newest.deltaMsgId,
          beforeTimestamp: newest.timestamp,
          filter: MessageTimelineFilter.allWithContact,
        ),
      ).called(1);
      expect(bloc.state.items, [newest]);

      await bloc.close();
      await emailMessageStreamController.close();
    },
  );

  test(
    'no-service full html request marks email content unavailable',
    () async {
      final emailChat = initialChat.copyWith(
        deltaChatId: 8,
        emailAddress: 'peer@example.com',
        transport: MessageTransport.email,
      );
      final message = Message(
        stanzaID: 'email-no-service-content',
        senderJid: 'peer@example.com',
        chatJid: emailChat.jid,
        deltaChatId: emailChat.deltaChatId,
        deltaMsgId: 106,
        deltaAccountId: 3,
        timestamp: DateTime(2026, 1, 5, 10),
      );

      final bloc = ChatBloc(
        jid: emailChat.jid,
        messageService: messageService,
        chatsService: chatsService,
        mucService: mucService,
        notificationService: notificationService,
        emailService: null,
        settings: _defaultChatSettings(),
      );

      chatStreamController.add(emailChat);
      await _pumpBloc();
      messageStreamController.add([message]);
      await _pumpBloc();
      await _pumpBloc();
      await _pumpBloc();

      expect(bloc.state.emailFullHtmlLoading, isNot(contains(106)));
      expect(bloc.state.emailFullHtmlUnavailable, contains(106));

      await bloc.close();
    },
  );

  test('rendered off-window email messages hydrate full html', () async {
    final emailService = MockEmailService();
    final emailMessageStreamController =
        StreamController<List<Message>>.broadcast();
    _mockEmailSync(emailService);

    final emailChat = initialChat.copyWith(
      deltaChatId: 8,
      emailAddress: 'peer@example.com',
      transport: MessageTransport.email,
    );
    final renderedMessage = Message(
      stanzaID: 'email-search-result-html',
      senderJid: 'peer@example.com',
      chatJid: emailChat.jid,
      deltaChatId: emailChat.deltaChatId,
      deltaMsgId: 107,
      deltaAccountId: 3,
      timestamp: DateTime(2026, 1, 5, 10),
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
      () => emailService.getMessageFullHtml(any()),
    ).thenAnswer((_) async => '<p>Search result html</p>');

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
    emailMessageStreamController.add(const <Message>[]);
    await _pumpBloc();
    await _pumpBloc();

    bloc.add(ChatRenderedMessagesHydrationRequested([renderedMessage]));
    await untilCalled(() => emailService.getMessageFullHtml(renderedMessage));
    await _pumpBloc();

    verify(() => emailService.getMessageFullHtml(renderedMessage)).called(1);
    expect(
      bloc.state.emailFullHtmlByDeltaId[renderedMessage.deltaMsgId],
      '<p>Search result html</p>',
    );

    await bloc.close();
    await emailMessageStreamController.close();
  });

  test('rendered email hydration ignores messages from another chat', () async {
    final emailService = MockEmailService();
    final emailMessageStreamController =
        StreamController<List<Message>>.broadcast();
    _mockEmailSync(emailService);

    final emailChat = initialChat.copyWith(
      deltaChatId: 8,
      emailAddress: 'peer@example.com',
      transport: MessageTransport.email,
    );
    final otherChatMessage = Message(
      stanzaID: 'email-other-search-result-html',
      senderJid: 'other@example.com',
      chatJid: 'other@example.com',
      deltaChatId: emailChat.deltaChatId,
      deltaMsgId: 108,
      deltaAccountId: 3,
      timestamp: DateTime(2026, 1, 5, 10),
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
      () => emailService.getMessageFullHtml(any()),
    ).thenAnswer((_) async => '<p>Wrong chat html</p>');

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
    emailMessageStreamController.add(const <Message>[]);
    await _pumpBloc();
    await _pumpBloc();

    bloc.add(ChatRenderedMessagesHydrationRequested([otherChatMessage]));
    await _pumpBloc();
    await _pumpBloc();

    verifyNever(() => emailService.getMessageFullHtml(any()));
    expect(bloc.state.emailFullHtmlByDeltaId, isEmpty);
    expect(bloc.state.emailFullHtmlLoading, isEmpty);

    await bloc.close();
    await emailMessageStreamController.close();
  });

  test(
    'rendered off-window email share messages preserve share context',
    () async {
      final emailService = MockEmailService();
      final emailMessageStreamController =
          StreamController<List<Message>>.broadcast();
      _mockEmailSync(emailService);

      final emailChat = initialChat.copyWith(
        deltaChatId: 8,
        emailAddress: 'peer@example.com',
        transport: MessageTransport.email,
      );
      final renderedMessage = Message(
        stanzaID: 'email-search-share',
        senderJid: 'peer@example.com',
        chatJid: emailChat.jid,
        deltaChatId: emailChat.deltaChatId,
        deltaMsgId: 110,
        deltaAccountId: 3,
        timestamp: DateTime(2026, 1, 5, 10),
      );
      final responder = Chat(
        jid: 'responder@example.com',
        title: 'Responder',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime(2026, 1, 5, 11),
      );
      final shareContext = ShareContext(
        shareId: 'share-off-window',
        subject: 'Shared subject',
        participants: [responder],
        originatorDeltaMsgId: renderedMessage.deltaMsgId,
        participantCount: 1,
      );
      final replyMessage = Message(
        stanzaID: 'email-search-share-reply',
        senderJid: responder.jid,
        chatJid: responder.jid,
        deltaMsgId: 111,
        timestamp: DateTime(2026, 1, 5, 11),
        body: 'Reply',
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
        () => emailService.shareContextForMessage(renderedMessage),
      ).thenAnswer((_) async => shareContext);
      when(
        () => messageService.loadMessagesForShare('share-off-window'),
      ).thenAnswer((_) async => [replyMessage]);

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
      emailMessageStreamController.add(const <Message>[]);
      await _pumpBloc();
      await _pumpBloc();

      bloc.add(ChatRenderedMessagesHydrationRequested([renderedMessage]));
      await untilCalled(
        () => messageService.loadMessagesForShare('share-off-window'),
      );
      await _pumpBloc();

      expect(bloc.state.shareContexts[renderedMessage.stanzaID], shareContext);
      expect(bloc.state.shareReplies[renderedMessage.stanzaID], [responder]);

      await bloc.close();
      await emailMessageStreamController.close();
    },
  );

  test('off-window pinned email messages hydrate full html', () async {
    final emailService = MockEmailService();
    final emailMessageStreamController =
        StreamController<List<Message>>.broadcast();
    final pinnedController =
        StreamController<List<PinnedMessageEntry>>.broadcast();
    _mockEmailSync(emailService);

    final emailChat = initialChat.copyWith(
      deltaChatId: 8,
      emailAddress: 'peer@example.com',
      transport: MessageTransport.email,
    );
    final pinnedMessage = Message(
      stanzaID: 'email-pinned-result-html',
      senderJid: 'peer@example.com',
      chatJid: emailChat.jid,
      deltaChatId: emailChat.deltaChatId,
      deltaMsgId: 109,
      deltaAccountId: 3,
      timestamp: DateTime(2026, 1, 5, 10),
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
      () => messageService.pinnedMessagesStream(any()),
    ).thenAnswer((_) => pinnedController.stream);
    when(
      () => messageService.loadMessagesByReferenceIds(
        any(),
        chatJid: any(named: 'chatJid'),
      ),
    ).thenAnswer((_) async => [pinnedMessage]);
    when(
      () => emailService.getMessageFullHtml(any()),
    ).thenAnswer((_) async => '<p>Pinned html</p>');

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
    emailMessageStreamController.add(const <Message>[]);
    await _pumpBloc();
    await _pumpBloc();

    pinnedController.add([
      PinnedMessageEntry(
        messageStanzaId: pinnedMessage.stanzaID,
        chatJid: emailChat.jid,
        pinnedAt: DateTime(2026, 1, 5, 11),
        active: true,
      ),
    ]);
    await untilCalled(() => emailService.getMessageFullHtml(pinnedMessage));
    await _pumpBloc();

    verify(() => emailService.getMessageFullHtml(pinnedMessage)).called(1);
    expect(
      bloc.state.emailFullHtmlByDeltaId[pinnedMessage.deltaMsgId],
      '<p>Pinned html</p>',
    );

    await bloc.close();
    await emailMessageStreamController.close();
    await pinnedController.close();
  });

  test(
    'html-only persisted email marks messages loaded before full html completes',
    () async {
      final emailService = MockEmailService();
      final emailMessageStreamController =
          StreamController<List<Message>>.broadcast();
      final fullHtmlCompleter = Completer<String>();
      _mockEmailSync(emailService);

      final emailChat = initialChat.copyWith(
        deltaChatId: 8,
        emailAddress: 'peer@example.com',
        transport: MessageTransport.email,
      );
      final message = Message(
        stanzaID: 'email-html-only',
        senderJid: 'peer@example.com',
        chatJid: emailChat.jid,
        deltaChatId: emailChat.deltaChatId,
        deltaMsgId: 103,
        deltaAccountId: 3,
        timestamp: DateTime(2026, 1, 5, 10),
        htmlBody: '<p>Inline html</p>',
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
        () => emailService.getMessageFullHtml(any()),
      ).thenAnswer((_) => fullHtmlCompleter.future);

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
      emailMessageStreamController.add([message]);
      await _pumpBloc();
      await _pumpBloc();

      expect(bloc.state.messagesLoaded, isTrue);
      expect(bloc.state.items.single.htmlBody, '<p>Inline html</p>');
      expect(bloc.state.emailFullHtmlByDeltaId, isEmpty);
      verify(() => emailService.getMessageFullHtml(message)).called(1);

      fullHtmlCompleter.complete('<p>Full html</p>');
      await _pumpBloc();

      expect(
        bloc.state.emailFullHtmlByDeltaId[message.deltaMsgId],
        '<p>Full html</p>',
      );

      await bloc.close();
      await emailMessageStreamController.close();
    },
  );

  test(
    'stale full html completion clears loading without writing irrelevant html',
    () async {
      final emailService = MockEmailService();
      final emailMessageStreamController =
          StreamController<List<Message>>.broadcast();
      final fullHtmlCompleter = Completer<String>();
      _mockEmailSync(emailService);

      final emailChat = initialChat.copyWith(
        deltaChatId: 8,
        emailAddress: 'peer@example.com',
        transport: MessageTransport.email,
      );
      final message = Message(
        stanzaID: 'email-full-html-stale',
        senderJid: 'peer@example.com',
        chatJid: emailChat.jid,
        deltaChatId: emailChat.deltaChatId,
        deltaMsgId: 104,
        deltaAccountId: 3,
        timestamp: DateTime(2026, 1, 5, 10),
        body: 'Rendered fallback body',
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
        () => emailService.getMessageFullHtml(any()),
      ).thenAnswer((_) => fullHtmlCompleter.future);

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
      emailMessageStreamController.add([message]);
      await _pumpBloc();
      await _pumpBloc();

      expect(bloc.state.emailFullHtmlLoading, contains(message.deltaMsgId));

      emailMessageStreamController.add(const <Message>[]);
      await _pumpBloc();
      await _pumpBloc();

      fullHtmlCompleter.complete('<p>Stale full html</p>');
      await _pumpBloc();

      expect(
        bloc.state.emailFullHtmlLoading,
        isNot(contains(message.deltaMsgId)),
      );
      expect(
        bloc.state.emailFullHtmlByDeltaId,
        isNot(contains(message.deltaMsgId)),
      );
      expect(
        bloc.state.emailFullHtmlUnavailable,
        isNot(contains(message.deltaMsgId)),
      );

      await bloc.close();
      await emailMessageStreamController.close();
    },
  );

  test(
    'loaded email window requests full html even when inline html is present',
    () async {
      final emailService = MockEmailService();
      final emailMessageStreamController =
          StreamController<List<Message>>.broadcast();
      _mockEmailSync(emailService);

      final emailChat = initialChat.copyWith(
        deltaChatId: 8,
        emailAddress: 'peer@example.com',
        transport: MessageTransport.email,
      );
      final message = Message(
        stanzaID: 'email-inline-html',
        senderJid: 'peer@example.com',
        chatJid: emailChat.jid,
        deltaChatId: emailChat.deltaChatId,
        deltaMsgId: 102,
        deltaAccountId: 3,
        timestamp: DateTime(2026, 1, 5, 10),
        body: 'Rendered fallback body',
        htmlBody: '<p>Inline html</p>',
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
        () => emailService.getMessageFullHtml(any()),
      ).thenAnswer((_) async => '<p>Full html</p>');

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
      emailMessageStreamController.add([message]);
      await _pumpBloc();
      await _pumpBloc();

      expect(bloc.state.messagesLoaded, isTrue);
      verify(() => emailService.getMessageFullHtml(message)).called(1);
      expect(
        bloc.state.emailFullHtmlByDeltaId[message.deltaMsgId],
        '<p>Full html</p>',
      );

      await bloc.close();
      await emailMessageStreamController.close();
    },
  );

  test(
    'email details keep html and quoted preloading but load raw headers only on request',
    () async {
      final emailService = MockEmailService();
      final emailMessageStreamController =
          StreamController<List<Message>>.broadcast();
      _mockEmailSync(emailService);

      final emailChat = initialChat.copyWith(
        deltaChatId: 8,
        emailAddress: 'peer@example.com',
        transport: MessageTransport.email,
      );
      final message = Message(
        stanzaID: 'email-details-target',
        senderJid: 'peer@example.com',
        chatJid: emailChat.jid,
        deltaChatId: emailChat.deltaChatId,
        deltaMsgId: 101,
        deltaAccountId: 3,
        timestamp: DateTime(2026, 1, 5, 9),
        body: 'Rendered fallback body',
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
        () => emailService.getMessageFullHtml(any()),
      ).thenAnswer((_) async => '<p>Full html</p>');
      when(
        () => emailService.getQuotedMessage(any()),
      ).thenAnswer((_) async => null);
      when(
        () => emailService.getMessageRawHeaders(
          any(),
          accountId: any(named: 'accountId'),
        ),
      ).thenAnswer((_) async => 'X-Test: yes');

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
      emailMessageStreamController.add([message]);
      await _pumpBloc();
      await _pumpBloc();

      verify(() => emailService.getMessageFullHtml(message)).called(1);
      verify(() => emailService.getQuotedMessage(message)).called(1);
      expect(
        bloc.state.emailFullHtmlByDeltaId[message.deltaMsgId],
        '<p>Full html</p>',
      );
      expect(
        bloc.state.emailQuotedTextUnavailable.contains(message.deltaMsgId),
        isTrue,
      );

      clearInteractions(emailService);

      bloc.add(const ChatMessageFocused('email-details-target'));
      await _pumpBloc();
      await _pumpBloc();

      verifyNever(
        () => emailService.getMessageRawHeaders(
          any(),
          accountId: any(named: 'accountId'),
        ),
      );

      bloc.add(ChatEmailHeadersRequested(message));
      await _pumpBloc();
      await _pumpBloc();

      verify(
        () => emailService.getMessageRawHeaders(101, accountId: 3),
      ).called(1);
      expect(bloc.state.emailRawHeadersByDeltaId[101], 'X-Test: yes');

      await bloc.close();
      await emailMessageStreamController.close();
    },
  );

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

  test('opening a direct chat prefetches that peer avatar once', () async {
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
      () => xmppService.messageStreamForChat(
        any(),
        start: any(named: 'start'),
        end: any(named: 'end'),
        filter: any(named: 'filter'),
      ),
    ).thenAnswer((_) => messageStreamController.stream);
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
      () => xmppService.pinnedMessagesStream(any()),
    ).thenAnswer((_) => const Stream<List<PinnedMessageEntry>>.empty());
    when(
      () => xmppService.syncPinnedMessagesForChat(any()),
    ).thenAnswer((_) async {});
    when(
      () => xmppService.resolvePeerCapabilities(
        jid: any(named: 'jid'),
        forceRefresh: any(named: 'forceRefresh'),
      ),
    ).thenAnswer((_) async => xmpp.XmppPeerCapabilities(features: const []));
    when(
      () => xmppService.prefetchAvatarForJid(initialChat.jid),
    ).thenAnswer((_) async {});

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
    await _pumpBloc();

    verify(() => xmppService.prefetchAvatarForJid(initialChat.jid)).called(1);

    chatStreamController.add(initialChat.copyWith(title: 'Renamed peer'));
    await _pumpBloc();
    await _pumpBloc();

    verifyNever(() => xmppService.prefetchAvatarForJid(initialChat.jid));

    await bloc.close();
    await connectivityController.close();
  });

  test('adding a contact from chat does not emit a success toast', () async {
    final xmppService = MockXmppService();
    final connectivityController =
        StreamController<xmpp.ConnectionState>.broadcast();
    final acceptedCompleter = Completer<bool>();

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
      () => xmppService.messageStreamForChat(
        any(),
        start: any(named: 'start'),
        end: any(named: 'end'),
        filter: any(named: 'filter'),
      ),
    ).thenAnswer((_) => messageStreamController.stream);
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
      () => xmppService.pinnedMessagesStream(any()),
    ).thenAnswer((_) => const Stream<List<PinnedMessageEntry>>.empty());
    when(
      () => xmppService.syncPinnedMessagesForChat(any()),
    ).thenAnswer((_) async {});
    when(
      () => xmppService.resolvePeerCapabilities(
        jid: any(named: 'jid'),
        forceRefresh: any(named: 'forceRefresh'),
      ),
    ).thenAnswer((_) async => xmpp.XmppPeerCapabilities(features: const []));
    when(
      () => xmppService.prefetchAvatarForJid(initialChat.jid),
    ).thenAnswer((_) async {});
    when(
      () => xmppService.addToRoster(
        jid: any(named: 'jid'),
        title: any(named: 'title'),
      ),
    ).thenAnswer((_) async {});

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
    await _pumpBloc();

    bloc.add(
      ChatContactAddRequested(
        chat: initialChat,
        failureMessage: 'failed',
        acceptedCompleter: acceptedCompleter,
      ),
    );
    await _pumpBloc();
    await _pumpBloc();

    verify(
      () => xmppService.addToRoster(jid: initialChat.jid, title: 'peer'),
    ).called(1);
    expect(await acceptedCompleter.future, isTrue);
    expect(bloc.state.toast, isNull);

    await bloc.close();
    await connectivityController.close();
  });

  test(
    'reconnecting a direct chat does not prefetch that peer avatar again',
    () async {
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
        () => xmppService.messageStreamForChat(
          any(),
          start: any(named: 'start'),
          end: any(named: 'end'),
          filter: any(named: 'filter'),
        ),
      ).thenAnswer((_) => messageStreamController.stream);
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
        () => xmppService.catchUpChatFromMamOnConnectForSession(
          sessionId: any(named: 'sessionId'),
          chat: any(named: 'chat'),
          filter: any(named: 'filter'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => xmppService.pinnedMessagesStream(any()),
      ).thenAnswer((_) => const Stream<List<PinnedMessageEntry>>.empty());
      when(
        () => xmppService.syncPinnedMessagesForChat(any()),
      ).thenAnswer((_) async {});
      when(
        () => xmppService.resolvePeerCapabilities(
          jid: any(named: 'jid'),
          forceRefresh: any(named: 'forceRefresh'),
        ),
      ).thenAnswer((_) async => xmpp.XmppPeerCapabilities(features: const []));
      when(
        () => xmppService.prefetchAvatarForJid(initialChat.jid),
      ).thenAnswer((_) async {});

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
      await _pumpBloc();

      verify(() => xmppService.prefetchAvatarForJid(initialChat.jid)).called(1);

      connectivityController.add(xmpp.ConnectionState.connected);
      await _pumpBloc();
      await _pumpBloc();

      verifyNever(() => xmppService.prefetchAvatarForJid(initialChat.jid));
      verify(
        () => xmppService.catchUpChatFromMamOnConnectForSession(
          sessionId: any(named: 'sessionId'),
          chat: any(named: 'chat'),
          filter: any(named: 'filter'),
          pageSize: any(named: 'pageSize'),
        ),
      ).called(1);

      await bloc.close();
      await connectivityController.close();
    },
  );

  test(
    'closing during reconnect catch-up does not sync pins afterward',
    () async {
      final xmppService = MockXmppService();
      final connectivityController =
          StreamController<xmpp.ConnectionState>.broadcast();
      final catchUpCompleter = Completer<void>();

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
        () => xmppService.messageStreamForChat(
          any(),
          start: any(named: 'start'),
          end: any(named: 'end'),
          filter: any(named: 'filter'),
        ),
      ).thenAnswer((_) => messageStreamController.stream);
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
        () => xmppService.catchUpChatFromMamOnConnectForSession(
          sessionId: any(named: 'sessionId'),
          chat: any(named: 'chat'),
          filter: any(named: 'filter'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer((_) => catchUpCompleter.future);
      when(
        () => xmppService.pinnedMessagesStream(any()),
      ).thenAnswer((_) => const Stream<List<PinnedMessageEntry>>.empty());
      when(
        () => xmppService.syncPinnedMessagesForChat(any()),
      ).thenAnswer((_) async {});
      when(
        () => xmppService.resolvePeerCapabilities(
          jid: any(named: 'jid'),
          forceRefresh: any(named: 'forceRefresh'),
        ),
      ).thenAnswer((_) async => xmpp.XmppPeerCapabilities(features: const []));
      when(
        () => xmppService.prefetchAvatarForJid(initialChat.jid),
      ).thenAnswer((_) async {});

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
      await _pumpBloc();
      clearInteractions(xmppService);

      connectivityController.add(xmpp.ConnectionState.connected);
      await _pumpBloc();

      await bloc.close();
      catchUpCompleter.complete();
      await _pumpBloc();
      await _pumpBloc();

      verify(
        () => xmppService.catchUpChatFromMamOnConnectForSession(
          sessionId: any(named: 'sessionId'),
          chat: any(named: 'chat'),
          filter: any(named: 'filter'),
          pageSize: any(named: 'pageSize'),
        ),
      ).called(1);
      verifyNever(() => xmppService.syncPinnedMessagesForChat(any()));

      await connectivityController.close();
    },
  );

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

  test('opening a group chat refreshes that room avatar once', () async {
    const roomJid = 'room@conference.axi.im';

    when(
      () => mucService.roomStateFor(roomJid),
    ).thenReturn(RoomState(roomJid: roomJid, occupants: const {}));
    when(
      () => mucService.warmRoomFromHistory(roomJid: roomJid),
    ).thenAnswer((_) async => RoomState(roomJid: roomJid, occupants: const {}));

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
      () => mucService.ensureJoined(
        roomJid: roomJid,
        nickname: null,
        allowRejoin: true,
      ),
      () => mucService.refreshRoomAvatar(roomJid),
    ]);

    chatStreamController.add(_groupChat(roomJid, title: 'Renamed room'));
    await _pumpBloc();
    await _pumpBloc();

    verifyNever(() => mucService.refreshRoomAvatar(roomJid));

    await bloc.close();
  });

  test(
    'closing during room join does not refresh the room avatar afterward',
    () async {
      const roomJid = 'room@conference.axi.im';
      final joinCompleter = Completer<void>();

      when(
        () => mucService.roomStateFor(roomJid),
      ).thenReturn(RoomState(roomJid: roomJid, occupants: const {}));
      when(() => mucService.warmRoomFromHistory(roomJid: roomJid)).thenAnswer(
        (_) async => RoomState(roomJid: roomJid, occupants: const {}),
      );
      when(
        () => mucService.ensureJoined(
          roomJid: roomJid,
          nickname: any(named: 'nickname'),
          allowRejoin: any(named: 'allowRejoin'),
        ),
      ).thenAnswer((_) => joinCompleter.future);

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

      await bloc.close();
      joinCompleter.complete();
      await _pumpBloc();
      await _pumpBloc();

      verifyNever(() => mucService.refreshRoomAvatar(roomJid));
    },
  );

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
    'closing during room-members join does not fetch affiliations afterward',
    () async {
      const roomJid = 'room@conference.axi.im';
      const selfOccupantId = '$roomJid/self';
      final joinCompleter = Completer<void>();
      final freshRoomState = RoomState(
        roomJid: roomJid,
        myOccupantJid: selfOccupantId,
        selfPresenceStatusCodes: {MucStatusCode.selfPresence.code},
        occupants: <String, Occupant>{
          selfOccupantId: _occupant(
            occupantId: selfOccupantId,
            nick: 'self',
            realJid: 'self@axi.im',
            affiliation: OccupantAffiliation.owner,
            role: OccupantRole.moderator,
          ),
        },
      );

      when(
        () => mucService.ensureJoined(
          roomJid: roomJid,
          nickname: null,
          allowRejoin: true,
        ),
      ).thenAnswer((_) => joinCompleter.future);
      when(
        () => mucService.roomStateForOrEmpty(roomJid),
      ).thenReturn(freshRoomState);

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
      clearInteractions(mucService);

      bloc.add(const ChatRoomMembersOpened());
      await _pumpBloc();

      await bloc.close();
      joinCompleter.complete();
      await _pumpBloc();
      await _pumpBloc();

      verifyNever(() => mucService.fetchRoomMembers(roomJid: roomJid));
      verifyNever(() => mucService.fetchRoomOwners(roomJid: roomJid));
      verifyNever(() => mucService.fetchRoomAdmins(roomJid: roomJid));
    },
  );

  test(
    'room state updates do not prefetch room affiliations automatically',
    () async {
      final roomStateController = StreamController<RoomState>.broadcast();
      const roomJid = 'room@conference.axi.im';
      const selfOccupantId = '$roomJid/self';

      when(
        () => mucService.roomStateStream(roomJid),
      ).thenAnswer((_) => roomStateController.stream);
      when(
        () => mucService.roomStateFor(roomJid),
      ).thenReturn(RoomState(roomJid: roomJid, occupants: const {}));
      when(() => mucService.warmRoomFromHistory(roomJid: roomJid)).thenAnswer(
        (_) async => RoomState(roomJid: roomJid, occupants: const {}),
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
          },
        ),
      );
      await _pumpBloc();
      await _pumpBloc();

      verifyNever(() => mucService.fetchRoomMembers(roomJid: roomJid));
      verifyNever(() => mucService.fetchRoomOwners(roomJid: roomJid));
      verifyNever(() => mucService.fetchRoomAdmins(roomJid: roomJid));

      await bloc.close();
      await roomStateController.close();
    },
  );

  test('opening room members fetches room affiliations', () async {
    const roomJid = 'room@conference.axi.im';
    const selfOccupantId = '$roomJid/self';
    final roomState = RoomState(
      roomJid: roomJid,
      myOccupantJid: selfOccupantId,
      selfPresenceStatusCodes: {MucStatusCode.selfPresence.code},
      occupants: <String, Occupant>{
        selfOccupantId: _occupant(
          occupantId: selfOccupantId,
          nick: 'self',
          realJid: 'self@axi.im',
          affiliation: OccupantAffiliation.owner,
          role: OccupantRole.moderator,
        ),
      },
    );

    when(() => mucService.roomStateForOrEmpty(roomJid)).thenReturn(roomState);
    when(
      () => mucService.warmRoomFromHistory(roomJid: roomJid),
    ).thenAnswer((_) async => roomState);

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
    clearInteractions(mucService);

    bloc.add(const ChatRoomMembersOpened());
    await _pumpBloc();
    await _pumpBloc();

    verifyInOrder([
      () => mucService.ensureJoined(
        roomJid: roomJid,
        nickname: null,
        allowRejoin: true,
      ),
      () => mucService.fetchRoomMembers(roomJid: roomJid),
      () => mucService.fetchRoomOwners(roomJid: roomJid),
      () => mucService.fetchRoomAdmins(roomJid: roomJid),
    ]);

    await bloc.close();
  });

  test('opening room members uses fresh room state after join', () async {
    const roomJid = 'room@conference.axi.im';
    const selfOccupantId = '$roomJid/self';
    final staleRoomState = RoomState(roomJid: roomJid, occupants: const {});
    final freshRoomState = RoomState(
      roomJid: roomJid,
      myOccupantJid: selfOccupantId,
      selfPresenceStatusCodes: {MucStatusCode.selfPresence.code},
      occupants: <String, Occupant>{
        selfOccupantId: _occupant(
          occupantId: selfOccupantId,
          nick: 'self',
          realJid: 'self@axi.im',
          affiliation: OccupantAffiliation.owner,
          role: OccupantRole.moderator,
        ),
      },
    );
    var roomStateReads = 0;
    when(() => mucService.roomStateForOrEmpty(roomJid)).thenAnswer((_) {
      roomStateReads += 1;
      if (roomStateReads == 1) return staleRoomState;
      return freshRoomState;
    });
    when(
      () => mucService.warmRoomFromHistory(roomJid: roomJid),
    ).thenAnswer((_) async => staleRoomState);

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
    clearInteractions(mucService);

    bloc.add(const ChatRoomMembersOpened());
    await _pumpBloc();
    await _pumpBloc();

    verifyInOrder([
      () => mucService.ensureJoined(
        roomJid: roomJid,
        nickname: null,
        allowRejoin: true,
      ),
      () => mucService.roomStateForOrEmpty(roomJid),
      () => mucService.fetchRoomMembers(roomJid: roomJid),
      () => mucService.fetchRoomOwners(roomJid: roomJid),
      () => mucService.fetchRoomAdmins(roomJid: roomJid),
    ]);
    expect(bloc.state.roomState?.hasSelfPresence, isTrue);

    await bloc.close();
  });

  test('reopening room members fetches room affiliations again', () async {
    const roomJid = 'room@conference.axi.im';
    const selfOccupantId = '$roomJid/self';
    final roomState = RoomState(
      roomJid: roomJid,
      myOccupantJid: selfOccupantId,
      selfPresenceStatusCodes: {MucStatusCode.selfPresence.code},
      occupants: <String, Occupant>{
        selfOccupantId: _occupant(
          occupantId: selfOccupantId,
          nick: 'self',
          realJid: 'self@axi.im',
          affiliation: OccupantAffiliation.owner,
          role: OccupantRole.moderator,
        ),
      },
    );

    when(() => mucService.roomStateForOrEmpty(roomJid)).thenReturn(roomState);
    when(
      () => mucService.warmRoomFromHistory(roomJid: roomJid),
    ).thenAnswer((_) async => roomState);

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
    clearInteractions(mucService);

    bloc.add(const ChatRoomMembersOpened());
    await _pumpBloc();
    await _pumpBloc();

    bloc.add(const ChatRoomMembersOpened());
    await _pumpBloc();
    await _pumpBloc();

    verify(() => mucService.fetchRoomMembers(roomJid: roomJid)).called(2);
    verify(() => mucService.fetchRoomOwners(roomJid: roomJid)).called(2);
    verify(() => mucService.fetchRoomAdmins(roomJid: roomJid)).called(2);

    await bloc.close();
  });

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
