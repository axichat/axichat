import 'package:axichat/src/accessibility/accessibility_flow.dart';
import 'package:axichat/src/accessibility/bloc/accessibility_chat_bloc.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks.dart';

void main() {
  late MockMessageService messageService;
  late MockXmppDatabase database;

  setUp(() {
    messageService = MockMessageService();
    database = MockXmppDatabase();

    when(
      () => messageService.messageStreamForChat(any(), end: any(named: 'end')),
    ).thenAnswer((_) => const Stream<List<Message>>.empty());
    when(() => messageService.database).thenAnswer((_) async => database);
    when(
      () => messageService.sendMessage(
        jid: any(named: 'jid'),
        text: any(named: 'text'),
        encryptionProtocol: EncryptionProtocol.none,
        chatType: ChatType.chat,
      ),
    ).thenAnswer((_) async {});
    when(
      () => messageService.sendLocalOnlyMessage(
        jid: any(named: 'jid'),
        text: any(named: 'text'),
        encryptionProtocol: EncryptionProtocol.none,
        chatType: ChatType.chat,
      ),
    ).thenAnswer((_) async {});
  });

  test('downloads accessibility attachments through MessageService', () async {
    when(
      () => messageService.downloadInboundAttachment(
        metadataId: 'metadata-1',
        stanzaId: 'stanza-1',
      ),
    ).thenAnswer((_) async => '/tmp/downloaded.file');

    final bloc = AccessibilityChatBloc(
      jid: 'friend@axi.im',
      messageService: messageService,
      contacts: const <AccessibilityContact>[],
      myJid: 'me@axi.im',
      initialUnreadCount: 0,
      draftId: null,
    );
    addTearDown(bloc.close);

    final downloaded = await bloc.downloadInboundAttachment(
      metadataId: 'metadata-1',
      stanzaId: 'stanza-1',
    );

    expect(downloaded, isTrue);
    verify(
      () => messageService.downloadInboundAttachment(
        metadataId: 'metadata-1',
        stanzaId: 'stanza-1',
      ),
    ).called(1);
  });

  test(
    'reloads accessibility attachment metadata through the database',
    () async {
      final metadata = FileMetadataData(
        id: 'metadata-1',
        filename: 'photo.jpg',
        mimeType: 'image/jpeg',
      );
      when(
        () => database.getFileMetadata('metadata-1'),
      ).thenAnswer((_) async => metadata);

      final bloc = AccessibilityChatBloc(
        jid: 'friend@axi.im',
        messageService: messageService,
        contacts: const <AccessibilityContact>[],
        myJid: 'me@axi.im',
        initialUnreadCount: 0,
        draftId: null,
      );
      addTearDown(bloc.close);

      final reloaded = await bloc.reloadFileMetadata('metadata-1');

      expect(reloaded, same(metadata));
      verify(() => database.getFileMetadata('metadata-1')).called(1);
    },
  );

  test('sends welcome-chat messages through the local-only path', () async {
    final bloc = AccessibilityChatBloc(
      jid: 'axichat@welcome.axichat.invalid',
      messageService: messageService,
      contacts: const <AccessibilityContact>[],
      myJid: 'me@axi.im',
      initialUnreadCount: 0,
      draftId: null,
    );
    addTearDown(bloc.close);

    bloc.add(
      const AccessibilityChatSendRequested(
        body: 'hello welcome',
        recipients: [
          AccessibilityContact(
            jid: 'axichat@welcome.axichat.invalid',
            displayName: 'Axichat',
            subtitle: 'Axichat',
            source: AccessibilityContactSource.chat,
            encryptionProtocol: EncryptionProtocol.none,
            chatType: ChatType.chat,
            unreadCount: 0,
            transport: MessageTransport.xmpp,
          ),
        ],
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.sendCount, 1);

    verify(
      () => messageService.sendLocalOnlyMessage(
        jid: 'axichat@welcome.axichat.invalid',
        text: 'hello welcome',
        encryptionProtocol: EncryptionProtocol.none,
        chatType: ChatType.chat,
      ),
    ).called(1);
    verifyNever(
      () => messageService.sendMessage(
        jid: 'axichat@welcome.axichat.invalid',
        text: any(named: 'text'),
        encryptionProtocol: any(named: 'encryptionProtocol'),
        chatType: any(named: 'chatType'),
      ),
    );
  });
}
