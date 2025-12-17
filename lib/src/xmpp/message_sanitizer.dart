part of 'package:axichat/src/xmpp/xmpp_service.dart';

class MessageSanitizerManager extends mox.XmppManagerBase {
  MessageSanitizerManager() : super('axi.message.sanitizer');

  final _log = Logger('MessageSanitizer');
  static const String _mucUserTag = 'x';
  static const String _mucInviteTag = 'invite';

  @override
  List<mox.StanzaHandler> getIncomingPreStanzaHandlers() => [
        mox.StanzaHandler(
          stanzaTag: 'message',
          priority: 9997,
          callback: _onIncomingMessage,
        ),
      ];

  @override
  Future<bool> isSupported() async => true;

  bool _isMucInvite(mox.Stanza stanza) {
    final mucUser = stanza.firstTag(_mucUserTag, xmlns: _mucUserXmlns);
    if (mucUser == null) return false;
    return mucUser.firstTag(_mucInviteTag) != null;
  }

  Future<mox.StanzaHandlerData> _onIncomingMessage(
    mox.Stanza stanza,
    mox.StanzaHandlerData state,
  ) async {
    final hasFrom = stanza.from != null && stanza.from!.isNotEmpty;
    if (!hasFrom) {
      _log.warning('Dropping malformed message stanza missing required fields');
      state.done = true;
      return state;
    }

    if (_isMucInvite(stanza)) {
      state.done = true;
      return state;
    }

    if (stanza.id == null || stanza.id!.isEmpty) {
      _log.fine('Allowing message stanza without id');
    }

    return state;
  }
}
