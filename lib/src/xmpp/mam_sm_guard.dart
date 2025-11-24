part of 'package:axichat/src/xmpp/xmpp_service.dart';

/// Prevents double-counting of MAM replay stanzas in stream management.
///
/// moxxmpp's MAM manager replays the forwarded message through the pipeline,
/// which makes the StreamManagementManager increment `s2c` a second time for a
/// single server stanza. This guard runs immediately after SM's pre-stanza
/// handler and rolls back the extra increment when the stanza originated from
/// MAM replay.
class MamStreamManagementGuard extends mox.XmppManagerBase {
  MamStreamManagementGuard() : super('axi.mam.sm.guard');

  // 32-bit SM counters wrap at this modulus per XEP-0198.
  static const int _xmlUintMax = 4294967296;

  @override
  List<mox.StanzaHandler> getIncomingPreStanzaHandlers() => [
        mox.StanzaHandler(
          priority: 9998, // SM pre-handler uses 9999; run immediately after.
          callback: _onIncomingPreStanza,
        ),
      ];

  @override
  Future<bool> isSupported() async => true;

  Future<mox.StanzaHandlerData> _onIncomingPreStanza(
    mox.Stanza stanza,
    mox.StanzaHandlerData state,
  ) async {
    final mamContext = state.extensions.get<mox.MAMContextData>();
    if (!(mamContext?.isFromMAM ?? false)) {
      return state;
    }

    final sm = getAttributes()
        .getManagerById<XmppStreamManagementManager>(mox.smManager);
    if (sm == null || !sm.isStreamManagementEnabled()) {
      return state;
    }

    final current = sm.state;
    final adjusted = current.copyWith(
      s2c: (current.s2c + _xmlUintMax - 1) % _xmlUintMax,
    );

    if (adjusted.s2c != current.s2c) {
      await sm.setState(adjusted);
    }

    return state;
  }
}
