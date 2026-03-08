import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/storage/models/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'spam target prefers the real email address over delta placeholder jids',
    () {
      final chat = Chat(
        jid: 'dc-1@delta.chat',
        title: 'Peer',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime(2024, 1, 1),
        transport: MessageTransport.email,
        deltaChatId: 1,
        contactID: 'friend@example.com',
        contactJid: 'friend@example.com',
        emailAddress: 'friend@example.com',
      );

      expect(chat.antiAbuseTargetAddress, 'friend@example.com');
      expect(chat.spamSyncTargetJid, 'friend@example.com');
    },
  );

  test(
    'anti abuse target still resolves email address when transport is stale',
    () {
      final chat = Chat(
        jid: 'dc-1@delta.chat',
        title: 'Peer',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime(2024, 1, 1),
        transport: MessageTransport.xmpp,
        deltaChatId: 1,
        emailAddress: 'friend@example.com',
      );

      expect(chat.isEmailBacked, isTrue);
      expect(chat.antiAbuseTargetAddress, 'friend@example.com');
    },
  );
}
