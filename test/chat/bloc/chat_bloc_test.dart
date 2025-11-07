import 'dart:async';

import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMessageService messageService;
  late MockChatsService chatsService;
  late MockNotificationService notificationService;

  late StreamController<List<Message>> messageStreamController;
  late StreamController<Chat?> chatStreamController;

  setUp(() {
    messageService = MockMessageService();
    chatsService = MockChatsService();
    notificationService = MockNotificationService();

    messageStreamController = StreamController<List<Message>>.broadcast();
    chatStreamController = StreamController<Chat?>.broadcast();

    when(() => notificationService.dismissNotifications())
        .thenAnswer((_) async {});

    when(
      () => messageService.messageStreamForChat(
        any(),
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer((_) => messageStreamController.stream);

    when(() => chatsService.chatStream(any()))
        .thenAnswer((_) => chatStreamController.stream);

    when(() => chatsService.myJid).thenReturn('self@axi.im');

    when(() => messageService.sendReadMarker(any(), any()))
        .thenAnswer((_) async {});

    when(
      () => chatsService.saveChatTransportPreference(
        jid: any(named: 'jid'),
        transport: any(named: 'transport'),
      ),
    ).thenAnswer((_) async {});
    when(() => chatsService.loadChatTransportPreference(any()))
        .thenAnswer((_) async => MessageTransport.xmpp);
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

  blocTest<ChatBloc, ChatState>(
    'persists transport change and updates state',
    build: () {
      final bloc = ChatBloc(
        jid: initialChat.jid,
        messageService: messageService,
        chatsService: chatsService,
        notificationService: notificationService,
      );
      chatStreamController.add(initialChat);
      messageStreamController.add(const <Message>[]);
      return bloc;
    },
    act: (bloc) => bloc.add(const ChatTransportChanged(MessageTransport.email)),
    expect: () => [
      ChatState(items: const <Message>[], chat: initialChat),
    ],
    verify: (_) {
      verify(
        () => chatsService.saveChatTransportPreference(
          jid: initialChat.jid,
          transport: MessageTransport.email,
        ),
      ).called(1);
    },
  );
}
