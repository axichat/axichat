import 'package:axichat/src/xmpp/muc/muc_join_state.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

const String _accountJid = 'user@example.com/resource';
const String _accountPassword = 'password';
const String _roomJid = 'room@conference.example.com';
const String _roomNick = 'nick';
const String _roomNickUpdated = 'new-nick';
const String _roomJidWithNick = 'room@conference.example.com/nick';
const String _roomJidWithNewNick = 'room@conference.example.com/new-nick';
const String _mucJoinXmlns = 'http://jabber.org/protocol/muc';
const String _mucUserXmlns = 'http://jabber.org/protocol/muc#user';
const String _mucTag = 'x';
const String _passwordTag = 'password';
const String _statusTag = 'status';
const String _itemTag = 'item';
const String _reasonTag = 'reason';
const String _affiliationAttr = 'affiliation';
const String _roleAttr = 'role';
const String _nickAttr = 'nick';
const String _jidAttr = 'jid';
const String _codeAttr = 'code';
const String _iqTypeResult = 'result';
const String _presenceUnavailable = 'unavailable';
const String _passwordRaw = '  secret  ';
const String _passwordTrimmed = 'secret';
const String _reasonRaw = '  Updated by server  ';
const String _reasonTrimmed = 'Updated by server';
const String _destroyRoomJid = 'replacement@conference.example.com';
const String _affiliationValue = 'member';
const String _roleValue = 'participant';
const int _singleEventCount = 1;
const bool _handlerDone = false;
const bool _handlerCancel = false;

mox.XmppManagerAttributes _buildAttributes({
  required List<mox.XmppEvent> events,
}) {
  final fullJid = mox.JID.fromString(_accountJid);
  return mox.XmppManagerAttributes(
    sendStanza: (_) async => mox.Stanza.iq(type: _iqTypeResult),
    sendNonza: (_) {},
    getManagerById: <T extends mox.XmppManagerBase>(_) => null,
    sendEvent: events.add,
    getConnectionSettings: () =>
        mox.ConnectionSettings(jid: fullJid, password: _accountPassword),
    getFullJID: () => fullJid,
    getSocket: () => throw UnimplementedError(),
    getConnection: () => throw UnimplementedError(),
    getNegotiatorById: <T extends mox.XmppFeatureNegotiatorBase>(String _) =>
        null,
  );
}

mox.XMLNode _createMucUserNode({
  required String nick,
  required Set<String> statusCodes,
  String? reason,
  String? newNick,
  String? destroyReason,
  String? destroyAlternateRoomJid,
}) {
  final resolvedNick = newNick ?? nick;
  return mox.XMLNode.xmlns(
    tag: _mucTag,
    xmlns: _mucUserXmlns,
    children: [
      mox.XMLNode(
        tag: _itemTag,
        attributes: {
          _nickAttr: resolvedNick,
          _affiliationAttr: _affiliationValue,
          _roleAttr: _roleValue,
        },
        children: [
          if (reason != null) mox.XMLNode(tag: _reasonTag, text: reason),
        ],
      ),
      if (destroyReason != null || destroyAlternateRoomJid != null)
        mox.XMLNode(
          tag: 'destroy',
          attributes: {_jidAttr: ?destroyAlternateRoomJid},
          children: [
            if (destroyReason != null)
              mox.XMLNode(tag: _reasonTag, text: destroyReason),
          ],
        ),
      for (final code in statusCodes)
        mox.XMLNode(tag: _statusTag, attributes: {_codeAttr: code}),
    ],
  );
}

List<mox.XMLNode> _createEmptyXmlChildren() {
  return List<mox.XMLNode>.empty(growable: true);
}

mox.XMLNode _createMucJoinNode() {
  return mox.XMLNode.xmlns(
    tag: _mucTag,
    xmlns: _mucJoinXmlns,
    children: _createEmptyXmlChildren(),
  );
}

mox.Stanza _createPresence({
  required String from,
  required mox.XMLNode mucUser,
  String? type,
}) {
  return mox.Stanza.presence(from: from, type: type, children: [mucUser]);
}

mox.Stanza _createErrorPresence({required String from, required String to}) {
  return mox.Stanza.presence(from: from, to: to, type: 'error');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MUC join bootstrap manager', () {
    test(
      'JOIN-001 [HP] remembered passwords are injected into join presence',
      () async {
        final manager = MucJoinBootstrapManager()
          ..rememberPassword(roomJid: _roomJid, password: _passwordRaw);

        final mucJoin = _createMucJoinNode();
        final presence = mox.Stanza.presence(
          to: _roomJidWithNick,
          children: [mucJoin],
        );
        final handler = manager.getOutgoingPreStanzaHandlers().single;

        await handler.callback(
          presence,
          mox.StanzaHandlerData(
            _handlerDone,
            _handlerCancel,
            presence,
            mox.TypedMap<mox.StanzaHandlerExtension>(),
          ),
        );

        final updatedJoin = presence.firstTag(_mucTag, xmlns: _mucJoinXmlns);
        final passwordNode = updatedJoin?.firstTag(_passwordTag);
        expect(passwordNode?.innerText(), equals(_passwordTrimmed));
      },
    );

    test('JOIN-001 [HP] non-MUC presences do not receive passwords', () async {
      final manager = MucJoinBootstrapManager()
        ..rememberPassword(roomJid: _roomJid, password: _passwordRaw);

      final presence = mox.Stanza.presence(to: _roomJidWithNick);
      final handler = manager.getOutgoingPreStanzaHandlers().single;

      await handler.callback(
        presence,
        mox.StanzaHandlerData(
          _handlerDone,
          _handlerCancel,
          presence,
          mox.TypedMap<mox.StanzaHandlerExtension>(),
        ),
      );

      final updatedJoin = presence.firstTag(_mucTag, xmlns: _mucJoinXmlns);
      expect(updatedJoin, isNull);
    });

    test(
      'JOIN-001 [HP] unavailable presence does not inject passwords',
      () async {
        final manager = MucJoinBootstrapManager()
          ..rememberPassword(roomJid: _roomJid, password: _passwordRaw);

        final mucJoin = _createMucJoinNode();
        final presence = mox.Stanza.presence(
          to: _roomJidWithNick,
          type: _presenceUnavailable,
          children: [mucJoin],
        );
        final handler = manager.getOutgoingPreStanzaHandlers().single;

        await handler.callback(
          presence,
          mox.StanzaHandlerData(
            _handlerDone,
            _handlerCancel,
            presence,
            mox.TypedMap<mox.StanzaHandlerExtension>(),
          ),
        );

        final updatedJoin = presence.firstTag(_mucTag, xmlns: _mucJoinXmlns);
        expect(updatedJoin?.firstTag(_passwordTag), isNull);
      },
    );

    test(
      'JOIN-010 [HP] self-presence status 110 emits a self-presence event',
      () async {
        final events = <mox.XmppEvent>[];
        final manager = MucJoinBootstrapManager()
          ..register(_buildAttributes(events: events));

        final mucUser = _createMucUserNode(
          nick: _roomNick,
          statusCodes: {MucStatusCode.selfPresence.code},
          reason: _reasonRaw,
        );
        final presence = _createPresence(
          from: _roomJidWithNick,
          mucUser: mucUser,
        );
        final handler = manager.getIncomingStanzaHandlers().single;

        await handler.callback(
          presence,
          mox.StanzaHandlerData(
            _handlerDone,
            _handlerCancel,
            presence,
            mox.TypedMap<mox.StanzaHandlerExtension>(),
          ),
        );

        expect(events, hasLength(_singleEventCount));
        final event = events.single as MucSelfPresenceEvent;
        expect(event.roomJid, equals(_roomJid));
        expect(event.occupantJid, equals(_roomJidWithNick));
        expect(event.nick, equals(_roomNick));
        expect(event.isAvailable, isTrue);
        expect(event.isNickChange, isFalse);
        expect(event.statusCodes, contains(MucStatusCode.selfPresence.code));
        expect(event.reason, equals(_reasonTrimmed));
        expect(event.newNick, isNull);
      },
    );

    test(
      'RN-002 [HP] nick change self-presence includes new nick data',
      () async {
        final events = <mox.XmppEvent>[];
        final manager = MucJoinBootstrapManager()
          ..register(_buildAttributes(events: events));

        final mucUser = _createMucUserNode(
          nick: _roomNick,
          statusCodes: {
            MucStatusCode.selfPresence.code,
            MucStatusCode.nickChange.code,
          },
          newNick: _roomNickUpdated,
        );
        final presence = _createPresence(
          from: _roomJidWithNewNick,
          mucUser: mucUser,
        );
        final handler = manager.getIncomingStanzaHandlers().single;

        await handler.callback(
          presence,
          mox.StanzaHandlerData(
            _handlerDone,
            _handlerCancel,
            presence,
            mox.TypedMap<mox.StanzaHandlerExtension>(),
          ),
        );

        expect(events, hasLength(_singleEventCount));
        final event = events.single as MucSelfPresenceEvent;
        expect(event.isNickChange, isTrue);
        expect(event.newNick, equals(_roomNickUpdated));
        expect(event.statusCodes, contains(MucStatusCode.nickChange.code));
      },
    );

    test(
      'JOIN-011 [HP] self-presence error without muc#user still emits a self-presence event',
      () async {
        final events = <mox.XmppEvent>[];
        final manager = MucJoinBootstrapManager()
          ..register(_buildAttributes(events: events));

        final presence = _createErrorPresence(
          from: _roomJidWithNick,
          to: _accountJid,
        );
        final handler = manager.getIncomingStanzaHandlers().single;

        await handler.callback(
          presence,
          mox.StanzaHandlerData(
            _handlerDone,
            _handlerCancel,
            presence,
            mox.TypedMap<mox.StanzaHandlerExtension>(),
          ),
        );

        expect(events, hasLength(_singleEventCount));
        final event = events.single as MucSelfPresenceEvent;
        expect(event.roomJid, equals(_roomJid));
        expect(event.occupantJid, equals(_roomJidWithNick));
        expect(event.nick, equals(_roomNick));
        expect(event.isAvailable, isFalse);
        expect(event.isError, isTrue);
        expect(event.isNickChange, isFalse);
      },
    );

    test(
      'JOIN-012 [HP] destroyed self-presence carries alternate room metadata',
      () async {
        final events = <mox.XmppEvent>[];
        final manager = MucJoinBootstrapManager()
          ..register(_buildAttributes(events: events));

        final mucUser = _createMucUserNode(
          nick: _roomNick,
          statusCodes: {MucStatusCode.selfPresence.code},
          destroyReason: _reasonRaw,
          destroyAlternateRoomJid: _destroyRoomJid,
        );
        final presence = _createPresence(
          from: _roomJidWithNick,
          mucUser: mucUser,
          type: _presenceUnavailable,
        );
        final handler = manager.getIncomingStanzaHandlers().single;

        await handler.callback(
          presence,
          mox.StanzaHandlerData(
            _handlerDone,
            _handlerCancel,
            presence,
            mox.TypedMap<mox.StanzaHandlerExtension>(),
          ),
        );

        expect(events, hasLength(_singleEventCount));
        final event = events.single as MucSelfPresenceEvent;
        expect(event.isAvailable, isFalse);
        expect(event.isRoomDestroyed, isTrue);
        expect(event.reason, equals(_reasonTrimmed));
        expect(event.destroyAlternateRoomJid, equals(_destroyRoomJid));
      },
    );
  });
}
