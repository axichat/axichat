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

  test('transport resolves to email for non-axi contacts', () {
    final emailChat = Chat(
      jid: 'peer@example.com',
      title: 'Peer',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime(2024, 1, 1),
    );

    expect(emailChat.transport, MessageTransport.email);
    expect(emailChat.supportsEmail, isTrue);
    expect(emailChat.isEmailOnlyContact, isTrue);
    expect(emailChat.isAxiContact, isFalse);
  });

  test('transport remains XMPP for axi.im contacts even with email metadata', () {
    final chat = Chat(
      jid: 'peer@axi.im',
      title: 'Peer',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime(2024, 1, 1),
      emailAddress: 'friend@example.com',
    );

    expect(chat.transport, MessageTransport.xmpp);
    expect(chat.supportsEmail, isFalse);
    expect(chat.isEmailOnlyContact, isFalse);
    expect(chat.isAxiContact, isTrue);
  });
}
