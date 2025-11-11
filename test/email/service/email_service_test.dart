import 'dart:async';

import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/sync/delta_event_consumer.dart';
import 'package:axichat/src/email/transport/email_delta_transport.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:delta_ffi/delta_safe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks.dart';

class MockEmailDeltaTransport extends Mock implements EmailDeltaTransport {}

void main() {
  late MockCredentialStore credentialStore;
  late MockXmppDatabase database;
  late MockNotificationService notificationService;
  late MockEmailDeltaTransport transport;

  late void Function(DeltaCoreEvent) listener;

  setUpAll(() {
    registerFallbackValue(MessageTransport.xmpp);
    registerFallbackValue(<FutureOr<bool>>[]);
  });

  setUp(() {
    credentialStore = MockCredentialStore();
    database = MockXmppDatabase();
    notificationService = MockNotificationService();
    transport = MockEmailDeltaTransport();

    when(() => transport.addEventListener(any())).thenAnswer((invocation) {
      listener =
          invocation.positionalArguments.first as void Function(DeltaCoreEvent);
    });
    when(() => transport.removeEventListener(any())).thenAnswer((_) {});
    when(() => transport.events)
        .thenAnswer((_) => const Stream<DeltaCoreEvent>.empty());
    when(() => transport.selfJid).thenReturn('dc-self@user.delta.chat');
    when(() => transport.start()).thenAnswer((_) async {});
    when(() => transport.stop()).thenAnswer((_) async {});
    when(() => notificationService.sendNotification(
          title: any(named: 'title'),
          body: any(named: 'body'),
          extraConditions: any(named: 'extraConditions'),
          allowForeground: any(named: 'allowForeground'),
        )).thenAnswer((_) async {});
  });

  Future<void> pumpMicrotasks() async {
    await Future<void>.delayed(Duration.zero);
  }

  test('marks chats as email and raises notifications on incoming events',
      () async {
    const chatId = 7;
    const msgId = 42;
    final message = Message(
      stanzaID: 'dc-msg-$msgId',
      senderJid: 'peer@axi.im',
      chatJid: 'dc-$chatId@delta.chat',
      timestamp: DateTime.now(),
      body: 'Hello from email',
      encryptionProtocol: EncryptionProtocol.none,
    );
    final chat = Chat(
      jid: 'dc-$chatId@delta.chat',
      title: 'Peer',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.now(),
      deltaChatId: chatId,
      emailAddress: 'peer@example.com',
    );

    when(() => database.getMessageByStanzaID('dc-msg-$msgId'))
        .thenAnswer((_) async => message);
    when(() => database.getChat(chat.jid)).thenAnswer((_) async => chat);

    final service = EmailService(
      credentialStore: credentialStore,
      databaseBuilder: () async => database,
      transport: transport,
      notificationService: notificationService,
    );

    listener(
      const DeltaCoreEvent(
        type: DeltaEventType.incomingMsg,
        data1: chatId,
        data2: msgId,
      ),
    );

    await pumpMicrotasks();

    verify(
      () => notificationService.sendNotification(
        title: chat.title,
        body: message.body,
        extraConditions: any(named: 'extraConditions'),
        allowForeground: any(named: 'allowForeground'),
      ),
    ).called(1);

    addTearDown(service.shutdown);
  });

  test('setClientState keeps IO in sync with app lifecycle', () async {
    final service = EmailService(
      credentialStore: credentialStore,
      databaseBuilder: () async => database,
      transport: transport,
      notificationService: notificationService,
    );

    await service.start();
    verify(() => transport.start()).called(1);

    await service.setClientState(false);
    verify(() => transport.stop()).called(1);

    await service.setClientState(true);
    verify(() => transport.start()).called(2);

    addTearDown(service.shutdown);
  });
}
