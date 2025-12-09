import 'package:moxxmpp/moxxmpp.dart' as mox;

/// Guarded version of moxxmpp's [VCardManager] that ignores malformed
/// presence updates instead of throwing.
class SafeVCardManager extends mox.VCardManager {
  @override
  List<mox.StanzaHandler> getIncomingStanzaHandlers() => [
        mox.StanzaHandler(
          stanzaTag: 'presence',
          tagName: 'x',
          tagXmlns: mox.vCardTempUpdate,
          callback: _onPresenceSafe,
        ),
      ];

  Future<mox.StanzaHandlerData> _onPresenceSafe(
    mox.Stanza presence,
    mox.StanzaHandlerData state,
  ) async {
    final x = presence.firstTag('x', xmlns: mox.vCardTempUpdate);
    final from = presence.from;
    if (x == null || from == null) {
      return state;
    }

    final hash = x.firstTag('photo')?.innerText() ?? '';

    getAttributes().sendEvent(
      mox.VCardAvatarUpdatedEvent(
        mox.JID.fromString(from),
        hash,
      ),
    );
    return state;
  }
}
