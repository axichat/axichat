import 'package:axichat/src/common/transport.dart';
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

    test('uses actor real JID for identified group messages', () {
      const message = Message(
        stanzaID: stanzaId,
        senderJid: groupSenderJid,
        senderRealJid: 'alice@example.com',
        chatJid: groupChatBareJid,
      );

      final authorized = message.authorizedForMutation(
        from: mox.JID.fromString(groupOtherSenderJid),
        actorRealJid: 'alice@example.com',
      );
      final unverified = message.authorizedForMutation(
        from: mox.JID.fromString(groupSenderJid),
      );

      expect(authorized, isTrue);
      expect(unverified, isFalse);
    });
  });

  group('Message.countsTowardUnread', () {
    test('ignores group messages whose stored real JID is self', () {
      const message = Message(
        stanzaID: stanzaId,
        senderJid: groupSenderJid,
        senderRealJid: directSenderJid,
        chatJid: groupChatBareJid,
        body: 'hello',
      );

      expect(
        message.countsTowardUnread(
          selfJid: directSenderJid,
          isGroupChat: true,
          myOccupantJid: groupOtherSenderJid,
        ),
        isFalse,
      );
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

  group('Message.canSendXmppReaction', () {
    test('allows normal XMPP messages in XMPP chats', () {
      const message = Message(
        stanzaID: stanzaId,
        senderJid: directSenderJid,
        chatJid: directChatJid,
      );

      expect(
        message.canSendXmppReaction(
          chatDefaultTransport: MessageTransport.xmpp,
        ),
        isTrue,
      );
    });

    test('rejects normal messages in native email chats', () {
      const message = Message(
        stanzaID: stanzaId,
        senderJid: directSenderJid,
        chatJid: directChatJid,
      );

      expect(
        message.canSendXmppReaction(
          chatDefaultTransport: MessageTransport.email,
        ),
        isFalse,
      );
    });

    test('rejects email-backed messages in mixed XMPP chats', () {
      const message = Message(
        stanzaID: stanzaId,
        senderJid: directSenderJid,
        chatJid: directChatJid,
        deltaMsgId: 1,
      );

      expect(
        message.canSendXmppReaction(
          chatDefaultTransport: MessageTransport.xmpp,
        ),
        isFalse,
      );
    });
  });

  group('Message.pinReference', () {
    test('uses stanza id for direct XMPP messages', () {
      const message = Message(
        stanzaID: stanzaId,
        originID: 'origin-id',
        senderJid: directSenderJid,
        chatJid: directChatJid,
      );

      final reference = message.pinReference(isGroupChat: false);

      expect(reference?.kind, MessageReferenceKind.stanzaId);
      expect(reference?.value, stanzaId);
    });

    test('uses room stanza id for groupchat messages', () {
      const message = Message(
        stanzaID: stanzaId,
        originID: 'origin-id',
        mucStanzaId: 'muc-stanza-id',
        senderJid: groupSenderJid,
        chatJid: groupChatBareJid,
      );

      final reference = message.pinReference(isGroupChat: true);

      expect(reference?.kind, MessageReferenceKind.mucStanzaId);
      expect(reference?.value, 'muc-stanza-id');
    });

    test('uses stanza id for email-backed messages', () {
      const message = Message(
        stanzaID: stanzaId,
        originID: 'origin-id',
        senderJid: directSenderJid,
        chatJid: directChatJid,
        deltaMsgId: 1,
      );

      final reference = message.pinReference(isGroupChat: false);

      expect(reference?.kind, MessageReferenceKind.stanzaId);
      expect(reference?.value, stanzaId);
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
