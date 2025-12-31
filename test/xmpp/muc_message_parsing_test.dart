import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

const String _accountBareJid = 'user@example.com';
const String _inviterJid = 'inviter@example.com/resource';
const String _inviterBareJid = 'inviter@example.com';
const String _inviteeBareJid = _accountBareJid;
const String _roomJid = 'room@conference.example.com';
const String _roomOccupantJid = 'room@conference.example.com/occupant';
const String _roomJidAlternate = 'room-alt@conference.example.com';
const String _roomName = 'Example Room';
const String _inviteReasonRaw = '  Join us  ';
const String _inviteReasonTrimmed = 'Join us';
const String _invitePasswordRaw = '  secret  ';
const String _invitePasswordTrimmed = 'secret';
const String _inviteTokenRaw = '  token-123  ';
const String _inviteTokenTrimmed = 'token-123';
const String _inviteBodyText = 'Hello invitee';
const String _inviteSpoofText = 'inviter=spoof@example.com';
const String _stanzaId = 'stanza-1';
const String _messageTypeChat = 'chat';
const String _messageTypeGroupchat = 'groupchat';
const String _directInviteTag = 'x';
const String _directInviteXmlns = 'jabber:x:conference';
const String _directInviteRoomAttr = 'jid';
const String _directInviteReasonAttr = 'reason';
const String _directInvitePasswordAttr = 'password';
const String _directInviteContinueAttr = 'continue';
const String _directInviteContinueTrue = 'true';
const String _directInviteContinueInvalid = 'maybe';
const String _axiInviteXmlns = 'urn:axichat:invite:1';
const String _axiInviteTag = 'invite';
const String _axiInviteRevokeTag = 'invite-revoke';
const String _axiInviteRoomAttr = 'room';
const String _axiInviteTokenAttr = 'token';
const String _axiInviteInviterAttr = 'inviter';
const String _axiInviteInviteeAttr = 'invitee';
const String _axiInviteRoomNameAttr = 'room_name';
const String _axiInviteReasonAttr = 'reason';
const String _axiInvitePasswordAttr = 'password';
const String _xmlnsAttr = 'xmlns';
const String _bodyTag = 'body';
const String _occupantId = 'occupant-123';

mox.MessageEvent _createMessageEvent({
  required mox.JID from,
  required mox.JID to,
  required List<mox.StanzaHandlerExtension> extensions,
  String id = _stanzaId,
  String? type,
}) {
  return mox.MessageEvent(
    from,
    to,
    false,
    mox.TypedMap<mox.StanzaHandlerExtension>.fromList(extensions),
    id: id,
    type: type,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Direct invite serialization (XEP-0249)', () {
    test(
      'DINV-010 [HP] direct invite XML includes required attributes',
      () {
        const data = DirectMucInviteData(
          roomJid: _roomJid,
          reason: _inviteReasonRaw,
          password: _invitePasswordRaw,
          continueFlag: true,
        );
        final node = data.toXml();

        expect(node.tag, equals(_directInviteTag));
        expect(node.attributes[_xmlnsAttr], equals(_directInviteXmlns));
        expect(
          node.attributes[_directInviteRoomAttr],
          equals(_roomJid),
        );
        expect(
          node.attributes[_directInviteReasonAttr],
          equals(_inviteReasonTrimmed),
        );
        expect(
          node.attributes[_directInvitePasswordAttr],
          equals(_invitePasswordTrimmed),
        );
        expect(
          node.attributes[_directInviteContinueAttr],
          equals(_directInviteContinueTrue),
        );
      },
    );

    test(
      'DINV-011 [UP] missing jid rejects the direct invite',
      () {
        final stanza = mox.Stanza.message(
          children: [
            mox.XMLNode.xmlns(
              tag: _directInviteTag,
              xmlns: _directInviteXmlns,
            ),
          ],
        );

        final parsed = DirectMucInviteData.fromStanza(stanza);
        expect(parsed, isNull);
      },
    );

    test(
      'DINV-012 [HP] optional reason/password are trimmed',
      () {
        const data = DirectMucInviteData(
          roomJid: _roomJid,
          reason: _inviteReasonRaw,
          password: _invitePasswordRaw,
        );
        final node = data.toXml();

        expect(
          node.attributes[_directInviteReasonAttr],
          equals(_inviteReasonTrimmed),
        );
        expect(
          node.attributes[_directInvitePasswordAttr],
          equals(_invitePasswordTrimmed),
        );
      },
    );

    test(
      'DINV-015 [EC] continue=false omits the continue attribute',
      () {
        const data = DirectMucInviteData(
          roomJid: _roomJid,
          continueFlag: false,
        );
        final node = data.toXml();

        expect(
          node.attributes.containsKey(_directInviteContinueAttr),
          isFalse,
        );
      },
    );

    test(
      'DINV-016 [UP] invalid continue values are ignored',
      () {
        final stanza = mox.Stanza.message(
          children: [
            mox.XMLNode.xmlns(
              tag: _directInviteTag,
              xmlns: _directInviteXmlns,
              attributes: {
                _directInviteRoomAttr: _roomJid,
                _directInviteContinueAttr: _directInviteContinueInvalid,
              },
            ),
          ],
        );

        final parsed = DirectMucInviteData.fromStanza(stanza);
        expect(parsed, isNotNull);
        expect(parsed?.continueFlag, isNull);
      },
    );

    test(
      'DINV-031 [EC] direct invite is accepted even with a body (policy)',
      () {
        final stanza = mox.Stanza.message(
          children: [
            mox.XMLNode(tag: _bodyTag, text: _inviteBodyText),
            mox.XMLNode.xmlns(
              tag: _directInviteTag,
              xmlns: _directInviteXmlns,
              attributes: {_directInviteRoomAttr: _roomJid},
            ),
          ],
        );

        final parsed = DirectMucInviteData.fromStanza(stanza);
        expect(parsed?.roomJid, equals(_roomJid));
      },
    );

    test(
      'DINV-032 [EC] multiple invite elements resolve deterministically',
      () {
        final stanza = mox.Stanza.message(
          children: [
            mox.XMLNode.xmlns(
              tag: _directInviteTag,
              xmlns: _directInviteXmlns,
              attributes: {_directInviteRoomAttr: _roomJid},
            ),
            mox.XMLNode.xmlns(
              tag: _directInviteTag,
              xmlns: _directInviteXmlns,
              attributes: {_directInviteRoomAttr: _roomJidAlternate},
            ),
          ],
        );

        final parsed = DirectMucInviteData.fromStanza(stanza);
        expect(parsed?.roomJid, equals(_roomJid));
      },
    );
  });

  group('Axi invite serialization', () {
    test(
      'DINV-013 [HP] Axi invites trim optional fields',
      () {
        const payload = AxiMucInvitePayload(
          roomJid: _roomJid,
          token: _inviteTokenRaw,
          inviter: _inviterBareJid,
          invitee: _inviteeBareJid,
          roomName: _roomName,
          reason: _inviteReasonRaw,
          password: _invitePasswordRaw,
        );

        final node = payload.toXml();

        expect(node.tag, equals(_axiInviteTag));
        expect(node.attributes[_xmlnsAttr], equals(_axiInviteXmlns));
        expect(node.attributes[_axiInviteRoomAttr], equals(_roomJid));
        expect(
            node.attributes[_axiInviteTokenAttr], equals(_inviteTokenTrimmed));
        expect(
          node.attributes[_axiInviteInviterAttr],
          equals(_inviterBareJid),
        );
        expect(
          node.attributes[_axiInviteInviteeAttr],
          equals(_inviteeBareJid),
        );
        expect(
          node.attributes[_axiInviteRoomNameAttr],
          equals(_roomName),
        );
        expect(
          node.attributes[_axiInviteReasonAttr],
          equals(_inviteReasonTrimmed),
        );
        expect(
          node.attributes[_axiInvitePasswordAttr],
          equals(_invitePasswordTrimmed),
        );
      },
    );

    test(
      'DINV-020 [HP] revoked Axi invites serialize as revoke tags',
      () {
        const payload = AxiMucInvitePayload(
          roomJid: _roomJid,
          token: _inviteTokenTrimmed,
          inviter: _inviterBareJid,
          invitee: _inviteeBareJid,
          revoked: true,
        );

        final node = payload.toXml();

        expect(node.tag, equals(_axiInviteRevokeTag));
        expect(node.attributes[_xmlnsAttr], equals(_axiInviteXmlns));
      },
    );
  });

  group('Invite parsing into message models', () {
    test(
      'DINV-020 [HP] direct invite produces a MUC invite pseudo-message',
      () {
        final event = _createMessageEvent(
          from: mox.JID.fromString(_inviterJid),
          to: mox.JID.fromString(_accountBareJid),
          extensions: [
            const mox.MessageBodyData(_inviteBodyText),
            const DirectMucInviteData(
              roomJid: _roomJid,
              reason: _inviteReasonRaw,
              password: _invitePasswordRaw,
            ),
          ],
          type: _messageTypeChat,
        );

        final message = Message.fromMox(
          event,
          accountJid: _accountBareJid,
        );

        expect(message.pseudoMessageType, equals(PseudoMessageType.mucInvite));
        expect(message.pseudoMessageData?['roomJid'], equals(_roomJid));
        expect(message.pseudoMessageData?['inviter'], equals(_inviterBareJid));
        expect(message.pseudoMessageData?['invitee'], equals(_inviteeBareJid));
        expect(
          message.pseudoMessageData?['reason'],
          equals(_inviteReasonTrimmed),
        );
        expect(
          message.pseudoMessageData?['password'],
          equals(_invitePasswordTrimmed),
        );
      },
    );

    test(
      'DINV-028 [SEC] inviter derives from stanza from when payload omits it',
      () {
        final event = _createMessageEvent(
          from: mox.JID.fromString(_inviterJid),
          to: mox.JID.fromString(_accountBareJid),
          extensions: [
            const DirectMucInviteData(
                roomJid: _roomJid, reason: _inviteSpoofText),
          ],
        );

        final message = Message.fromMox(
          event,
          accountJid: _accountBareJid,
        );

        expect(message.pseudoMessageData?['inviter'], equals(_inviterBareJid));
      },
    );

    test(
      'DINV-020 [HP] Axi invite payload yields MUC invite metadata',
      () {
        final event = _createMessageEvent(
          from: mox.JID.fromString(_inviterJid),
          to: mox.JID.fromString(_accountBareJid),
          extensions: [
            const AxiMucInvitePayload(
              roomJid: _roomJid,
              token: _inviteTokenTrimmed,
              inviter: _inviterBareJid,
              invitee: _inviteeBareJid,
              roomName: _roomName,
              reason: _inviteReasonTrimmed,
              password: _invitePasswordTrimmed,
            ),
          ],
        );

        final message = Message.fromMox(
          event,
          accountJid: _accountBareJid,
        );

        expect(message.pseudoMessageType, equals(PseudoMessageType.mucInvite));
        expect(message.pseudoMessageData?['roomJid'], equals(_roomJid));
        expect(
            message.pseudoMessageData?['token'], equals(_inviteTokenTrimmed));
        expect(message.pseudoMessageData?['roomName'], equals(_roomName));
        expect(
          message.pseudoMessageData?['reason'],
          equals(_inviteReasonTrimmed),
        );
        expect(
          message.pseudoMessageData?['password'],
          equals(_invitePasswordTrimmed),
        );
      },
    );

    test(
      'DINV-020 [HP] revoked Axi invites become revocation pseudo-messages',
      () {
        final event = _createMessageEvent(
          from: mox.JID.fromString(_inviterJid),
          to: mox.JID.fromString(_accountBareJid),
          extensions: [
            const AxiMucInvitePayload(
              roomJid: _roomJid,
              token: _inviteTokenRaw,
              inviter: _inviterBareJid,
              invitee: _inviteeBareJid,
              revoked: true,
            ),
          ],
        );

        final message = Message.fromMox(
          event,
          accountJid: _accountBareJid,
        );

        expect(
          message.pseudoMessageType,
          equals(PseudoMessageType.mucInviteRevocation),
        );
        expect(message.pseudoMessageData?['revoked'], isTrue);
      },
    );
  });

  group('Occupant identifiers (XEP-0421)', () {
    test(
      'OID-040 [HP] groupchat messages prefer occupant-id when available',
      () {
        final event = _createMessageEvent(
          from: mox.JID.fromString(_roomOccupantJid),
          to: mox.JID.fromString(_accountBareJid),
          extensions: const [
            mox.OccupantIdData(_occupantId),
          ],
          type: _messageTypeGroupchat,
        );

        final message = Message.fromMox(event);
        expect(message.occupantID, equals(_occupantId));
      },
    );
  });
}
