import 'dart:async';

import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/settings/app_language.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart' as xmpp;
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockXmppService xmppService;
  late MockChatsService chatsService;
  late MockNotificationService notificationService;
  late MockMucService mucService;

  setUpAll(() {
    registerFallbackValue(MessageTimelineFilter.directOnly);
  });

  setUp(() {
    xmppService = MockXmppService();
    chatsService = MockChatsService();
    notificationService = MockNotificationService();
    mucService = MockMucService();

    when(
      () => notificationService.dismissMessageNotification(
        threadKey: any(named: 'threadKey'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => chatsService.chatStream(any()),
    ).thenAnswer((_) => const Stream<Chat?>.empty());
    when(
      () => chatsService.loadChatViewFilter(any()),
    ).thenAnswer((_) async => MessageTimelineFilter.directOnly);
    when(
      () => xmppService.messageStreamForChat(
        any(),
        start: any(named: 'start'),
        end: any(named: 'end'),
        filter: any(named: 'filter'),
      ),
    ).thenAnswer((_) => const Stream<List<Message>>.empty());
    when(
      () => xmppService.connectionState,
    ).thenReturn(xmpp.ConnectionState.notConnected);
    when(
      () => xmppService.connectivityStream,
    ).thenAnswer((_) => const Stream<xmpp.ConnectionState>.empty());
    when(
      () => xmppService.httpUploadSupportStream,
    ).thenAnswer((_) => const Stream<xmpp.HttpUploadSupport>.empty());
    when(
      () => xmppService.httpUploadSupport,
    ).thenReturn(const xmpp.HttpUploadSupport(supported: false));
    when(
      () => xmppService.setSpamStatus(
        jid: any(named: 'jid'),
        spam: any(named: 'spam'),
      ),
    ).thenAnswer((_) async {});
  });

  test(
    'chat spam updates use the real email address for email-backed chats',
    () async {
      final emailChat = Chat(
        jid: 'dc-1@delta.chat',
        title: 'Alice',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime(2024, 1, 1),
        transport: MessageTransport.email,
        deltaChatId: 1,
        contactJid: 'alice@example.com',
        emailAddress: 'alice@example.com',
      );
      final bloc = ChatBloc(
        jid: emailChat.jid,
        messageService: xmppService,
        chatsService: chatsService,
        mucService: mucService,
        notificationService: notificationService,
        settings: _defaultChatSettings(),
      );
      addTearDown(bloc.close);

      bloc.add(
        ChatSpamStatusRequested(
          chat: emailChat,
          sendToSpam: true,
          successTitle: 'Updated',
          successMessage: 'Moved to spam',
          failureMessage: 'Failed',
        ),
      );
      await _pumpBloc();

      verify(
        () => xmppService.setSpamStatus(jid: 'alice@example.com', spam: true),
      ).called(1);
      verifyNever(
        () => xmppService.setSpamStatus(jid: 'dc-1@delta.chat', spam: true),
      );
    },
  );
}
