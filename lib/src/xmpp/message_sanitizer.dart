part of 'package:axichat/src/xmpp/xmpp_service.dart';

class MessageSanitizerManager extends mox.XmppManagerBase {
  MessageSanitizerManager() : super('axi.message.sanitizer');

  final _log = Logger('MessageSanitizer');

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

    if (stanza.id == null || stanza.id!.isEmpty) {
      _log.fine('Allowing message stanza without id from ${stanza.from}');
    }

    return state;
  }
}
