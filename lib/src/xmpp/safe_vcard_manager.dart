// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:moxxmpp/moxxmpp.dart' as mox;

final class RoomVCardAvatarUpdatedEvent extends mox.XmppEvent {
  RoomVCardAvatarUpdatedEvent(this.jid, this.hash);

  final mox.JID jid;
  final String hash;
}

/// Guarded version of moxxmpp's [VCardManager] that ignores malformed
/// presence updates instead of throwing.
class SafeVCardManager extends mox.VCardManager {
  SafeVCardManager({this.isRoomJid});

  final bool Function(mox.JID jid)? isRoomJid;

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

    final jid = mox.JID.fromString(from);
    final isRoom = isRoomJid?.call(jid) ?? false;
    getAttributes().sendEvent(
      isRoom
          ? RoomVCardAvatarUpdatedEvent(jid, hash)
          : mox.VCardAvatarUpdatedEvent(jid, hash),
    );
    return state;
  }
}
