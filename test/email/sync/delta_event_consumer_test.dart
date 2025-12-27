import 'package:axichat/src/email/sync/delta_event_consumer.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:delta_ffi/delta_safe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(FakeChat());
    registerFallbackValue(FakeMessage());
  });

  late MockXmppDatabase database;
  late MockDeltaContextHandle context;
  late DeltaEventConsumer consumer;

  setUp(() {
    database = MockXmppDatabase();
    context = MockDeltaContextHandle();
    consumer = DeltaEventConsumer(
      databaseBuilder: () async => database,
      context: context,
    );
  });

  test('persists incoming timestamps from Delta core', () async {
    const chatId = 7;
    const msgId = 24;
    final timestamp = DateTime.utc(2024, 1, 2, 3, 4, 5);
    final deltaMessage = DeltaMessage(
      id: msgId,
      chatId: chatId,
      text: 'Hello',
      timestamp: timestamp,
    );
    const deltaChat = DeltaChat(
      id: chatId,
      name: 'Alice',
      contactAddress: 'alice@example.com',
    );

    when(() => context.getMessage(msgId)).thenAnswer((_) async => deltaMessage);
    when(() => context.getChat(chatId)).thenAnswer((_) async => deltaChat);
    when(() => database.getMessageByStanzaID(any()))
        .thenAnswer((_) async => null);
    when(() => database.getChat(any())).thenAnswer((_) async => null);
    when(() => database.createChat(any())).thenAnswer((_) async {});
    when(() => database.saveMessage(any())).thenAnswer((_) async {});
    when(() => database.updateChat(any())).thenAnswer((_) async {});
    when(() => database.getFileMetadata(any())).thenAnswer((_) async => null);
    when(() => database.saveFileMetadata(any())).thenAnswer((_) async {});

    await consumer.handle(
      DeltaCoreEvent(
        type: DeltaEventType.msgsChanged.code,
        data1: chatId,
        data2: msgId,
      ),
    );

    final persistedMessage = verify(() => database.saveMessage(captureAny()))
        .captured
        .single as Message;
    expect(persistedMessage.timestamp, timestamp);

    final updatedChat =
        verify(() => database.updateChat(captureAny())).captured.single as Chat;
    expect(updatedChat.lastChangeTimestamp, timestamp);
  });

  test('chatModified updates stored metadata', () async {
    const chatId = 11;
    final existingChat = Chat(
      jid: 'dc-$chatId@delta.chat',
      title: 'Old title',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.utc(2024),
      encryptionProtocol: EncryptionProtocol.none,
      deltaChatId: chatId,
    );
    when(() => database.getChat(any())).thenAnswer((_) async => existingChat);
    when(() => database.updateChat(any())).thenAnswer((_) async {});
    when(() => context.getChat(chatId)).thenAnswer(
      (_) async => const DeltaChat(
        id: chatId,
        name: 'Group Alpha',
        contactAddress: 'alpha@example.com',
        contactName: 'Coordinator',
        type: DeltaChatType.group,
      ),
    );

    await consumer.handle(
      DeltaCoreEvent(
        type: DeltaEventType.chatModified.code,
        data1: chatId,
        data2: 0,
      ),
    );

    final updatedChat =
        verify(() => database.updateChat(captureAny())).captured.single as Chat;
    expect(updatedChat.title, 'Group Alpha');
    expect(updatedChat.contactDisplayName, 'Coordinator');
    expect(updatedChat.emailAddress, 'alpha@example.com');
    expect(updatedChat.type, ChatType.groupChat);
  });
}
