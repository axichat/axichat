import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockXmppService xmppService;

  setUp(() {
    xmppService = MockXmppService();

    when(
      () => xmppService.chatsStream(),
    ).thenAnswer((_) => const Stream<List<Chat>>.empty());
    when(
      () => xmppService.recipientAddressSuggestionsStream(),
    ).thenAnswer((_) => const Stream<List<String>>.empty());
    when(
      () => xmppService.demoResetStream,
    ).thenAnswer((_) => const Stream<void>.empty());
    when(() => xmppService.cachedChatList).thenReturn(const <Chat>[]);
    when(
      () => xmppService.setSpamStatus(
        jid: any(named: 'jid'),
        spam: any(named: 'spam'),
      ),
    ).thenAnswer((_) async {});
  });

  test(
    'moveSpamToInbox uses the real email address for email-backed chats',
    () async {
      final chat = Chat(
        jid: 'dc-1@delta.chat',
        title: 'Alice',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime(2024, 1, 1),
        transport: MessageTransport.email,
        deltaChatId: 1,
        contactJid: 'alice@example.com',
        emailAddress: 'alice@example.com',
      );
      final cubit = ChatsCubit(xmppService: xmppService);
      addTearDown(cubit.close);

      final success = await cubit.moveSpamToInbox(chat: chat);

      expect(success, isTrue);
      verify(
        () => xmppService.setSpamStatus(jid: 'alice@example.com', spam: false),
      ).called(1);
      verifyNever(
        () => xmppService.setSpamStatus(jid: 'dc-1@delta.chat', spam: false),
      );
    },
  );
}
