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

  group('Message.resolveForwardedOriginalSenderLabel', () {
    test('prefers the original author from a forwarded body header', () {
      const message = Message(
        stanzaID: stanzaId,
        senderJid: 'forwarder@example.com',
        chatJid: 'forwarder@example.com',
        subject: 'Quarterly plan',
        body:
            '-------- Forwarded message --------\n'
            'From: Original Person <original@example.com>\n'
            'Subject: Quarterly plan\n'
            '\n'
            'Forwarded body',
      );

      expect(
        message.resolveForwardedOriginalSenderLabel(),
        'original@example.com',
      );
    });
  });

  group('Message.isStaleUnackedXmppSendAgainCandidate', () {
    test('requires stale unresolved outgoing XMPP state without a marker', () {
      final staleBefore = DateTime.utc(2024, 1, 1, 12);
      final message = Message(
        stanzaID: stanzaId,
        senderJid: 'self@example.com',
        chatJid: directChatJid,
        timestamp: DateTime.utc(2024, 1, 1, 11, 57),
      );

      expect(
        message.isStaleUnackedXmppSendAgainCandidate(
          isSelf: true,
          isEmailChat: false,
          staleBefore: staleBefore,
        ),
        isTrue,
      );
      expect(
        message
            .copyWith(acked: true)
            .isStaleUnackedXmppSendAgainCandidate(
              isSelf: true,
              isEmailChat: false,
              staleBefore: staleBefore,
            ),
        isFalse,
      );
      expect(
        message
            .copyWith(manualSendAgainStanzaID: 'copy-1')
            .isStaleUnackedXmppSendAgainCandidate(
              isSelf: true,
              isEmailChat: false,
              staleBefore: staleBefore,
            ),
        isFalse,
      );
      expect(
        message.isStaleUnackedXmppSendAgainCandidate(
          isSelf: true,
          isEmailChat: true,
          staleBefore: staleBefore,
        ),
        isFalse,
      );
      expect(
        message
            .copyWith(timestamp: staleBefore)
            .isStaleUnackedXmppSendAgainCandidate(
              isSelf: false,
              isEmailChat: false,
              staleBefore: staleBefore,
            ),
        isFalse,
      );
    });
  });
}
