import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/storage/models/chat_models.dart';
import 'package:test/test.dart';

void main() {
  final baseChat = Chat(
    jid: 'peer@axi.im',
    title: 'Peer',
    type: ChatType.chat,
    lastChangeTimestamp: DateTime(2024, 1, 1),
  );

  test('transport defaults to XMPP when no email metadata present', () {
    expect(baseChat.transport, MessageTransport.xmpp);
  });

  test('transport resolves to email when delta chat id is set', () {
    final emailChat = Chat(
      jid: 'dc-1@delta.chat',
      title: 'Peer',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime(2024, 1, 1),
      deltaChatId: 1,
    );

    expect(emailChat.transport, MessageTransport.email);
  });

  test('transport resolves to email when email address metadata present', () {
    final emailChat = Chat(
      jid: 'peer@axi.im',
      title: 'Peer',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime(2024, 1, 1),
      emailAddress: 'peer@example.com',
    );

    expect(emailChat.transport, MessageTransport.email);
  });
}
