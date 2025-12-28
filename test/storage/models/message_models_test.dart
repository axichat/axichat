import 'package:axichat/src/storage/models/message_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

void main() {
  const String stanzaId = 'stanza-id';
  const String groupChatBareJid = 'room@conference.example';
  const String groupSenderJid = 'room@conference.example/nick';
  const String groupOtherSenderJid = 'room@conference.example/other';
  const String directChatJid = 'alice@example.com';
  const String directSenderJid = 'alice@example.com';
  const String directSenderResourceJid = 'alice@example.com/mobile';

  group('Message.authorizedForMutation', () {
    test('requires full JID match for group messages without occupant id', () {
      const message = Message(
        stanzaID: stanzaId,
        senderJid: groupSenderJid,
        chatJid: groupChatBareJid,
      );

      final authorized = message.authorizedForMutation(
        from: mox.JID.fromString(groupOtherSenderJid),
      );
      expect(authorized, isFalse);

      final authorizedSelf = message.authorizedForMutation(
        from: mox.JID.fromString(groupSenderJid),
      );
      expect(authorizedSelf, isTrue);
    });

    test('allows bare JID matches for direct messages', () {
      const message = Message(
        stanzaID: stanzaId,
        senderJid: directSenderJid,
        chatJid: directChatJid,
      );

      final authorized = message.authorizedForMutation(
        from: mox.JID.fromString(directSenderResourceJid),
      );
      expect(authorized, isTrue);
    });
  });
}
