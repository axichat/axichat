part of 'package:axichat/src/xmpp/xmpp_service.dart';

final class DirectMucInviteData implements mox.StanzaHandlerExtension {
  const DirectMucInviteData({
    required this.roomJid,
    this.reason,
    this.password,
    this.continueFlag,
  });

  final String roomJid;
  final String? reason;
  final String? password;
  final bool? continueFlag;

  mox.XMLNode toXml() {
    final trimmedReason = reason?.trim();
    final trimmedPassword = password?.trim();
    return mox.XMLNode.xmlns(
      tag: _directInviteTag,
      xmlns: _directInviteXmlns,
      attributes: {
        _directInviteRoomAttr: roomJid,
        if (trimmedReason?.isNotEmpty == true)
          _directInviteReasonAttr: trimmedReason!,
        if (trimmedPassword?.isNotEmpty == true)
          _directInvitePasswordAttr: trimmedPassword!,
        if (continueFlag == true) _directInviteContinueAttr: 'true',
      },
    );
  }

  static DirectMucInviteData? fromStanza(mox.Stanza stanza) {
    final invite = stanza.firstTag(_directInviteTag, xmlns: _directInviteXmlns);
    if (invite == null) return null;
    final roomJid = invite.attributes[_directInviteRoomAttr]?.toString().trim();
    if (roomJid == null || roomJid.isEmpty) return null;
    final reasonAttr =
        invite.attributes[_directInviteReasonAttr]?.toString().trim();
    final passwordAttr =
        invite.attributes[_directInvitePasswordAttr]?.toString().trim();
    final continueAttr =
        invite.attributes[_directInviteContinueAttr]?.toString().trim();
    final reason = _normalizeInviteText(reasonAttr ?? invite.innerText());
    final password = _normalizeInviteText(passwordAttr);
    final continueFlag = _parseInviteBool(continueAttr);
    return DirectMucInviteData(
      roomJid: roomJid,
      reason: reason,
      password: password,
      continueFlag: continueFlag,
    );
  }
}

final class AxiMucInvitePayload implements mox.StanzaHandlerExtension {
  const AxiMucInvitePayload({
    required this.roomJid,
    this.token,
    this.inviter,
    this.invitee,
    this.roomName,
    this.reason,
    this.password,
    this.revoked = false,
  });

  final String roomJid;
  final String? token;
  final String? inviter;
  final String? invitee;
  final String? roomName;
  final String? reason;
  final String? password;
  final bool revoked;

  mox.XMLNode toXml() {
    final trimmedToken = token?.trim();
    final trimmedInviter = inviter?.trim();
    final trimmedInvitee = invitee?.trim();
    final trimmedRoomName = roomName?.trim();
    final trimmedReason = reason?.trim();
    final trimmedPassword = password?.trim();
    return mox.XMLNode.xmlns(
      tag: revoked ? _axiInviteRevokeTag : _axiInviteTag,
      xmlns: _axiInviteXmlns,
      attributes: {
        _axiInviteRoomAttr: roomJid,
        if (trimmedToken?.isNotEmpty == true)
          _axiInviteTokenAttr: trimmedToken!,
        if (trimmedInviter?.isNotEmpty == true)
          _axiInviteInviterAttr: trimmedInviter!,
        if (trimmedInvitee?.isNotEmpty == true)
          _axiInviteInviteeAttr: trimmedInvitee!,
        if (trimmedRoomName?.isNotEmpty == true)
          _axiInviteRoomNameAttr: trimmedRoomName!,
        if (trimmedReason?.isNotEmpty == true)
          _axiInviteReasonAttr: trimmedReason!,
        if (trimmedPassword?.isNotEmpty == true)
          _axiInvitePasswordAttr: trimmedPassword!,
      },
    );
  }

  static AxiMucInvitePayload? fromStanza(mox.Stanza stanza) {
    final invite = stanza.firstTag(_axiInviteTag, xmlns: _axiInviteXmlns);
    final revoke = stanza.firstTag(_axiInviteRevokeTag, xmlns: _axiInviteXmlns);
    final node = invite ?? revoke;
    if (node == null) return null;
    final roomJid = node.attributes[_axiInviteRoomAttr]?.toString().trim();
    if (roomJid == null || roomJid.isEmpty) return null;
    final token = _normalizeInviteText(
      node.attributes[_axiInviteTokenAttr]?.toString(),
    );
    final inviter = _normalizeInviteText(
      node.attributes[_axiInviteInviterAttr]?.toString(),
    );
    final invitee = _normalizeInviteText(
      node.attributes[_axiInviteInviteeAttr]?.toString(),
    );
    final roomName = _normalizeInviteText(
      node.attributes[_axiInviteRoomNameAttr]?.toString(),
    );
    final reason = _normalizeInviteText(
      node.attributes[_axiInviteReasonAttr]?.toString(),
    );
    final password = _normalizeInviteText(
      node.attributes[_axiInvitePasswordAttr]?.toString(),
    );
    return AxiMucInvitePayload(
      roomJid: roomJid,
      token: token,
      inviter: inviter,
      invitee: invitee,
      roomName: roomName,
      reason: reason,
      password: password,
      revoked: revoke != null,
    );
  }
}

bool? _parseInviteBool(String? raw) {
  final normalized = raw?.trim().toLowerCase();
  return switch (normalized) {
    'true' || '1' || 'yes' => true,
    'false' || '0' || 'no' => false,
    _ => null,
  };
}

String? _normalizeInviteText(String? text) {
  final trimmed = text?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

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

  @override
  Future<void> postRegisterCallback() async {
    await super.postRegisterCallback();
    getAttributes()
        .getManagerById<mox.MessageManager>(mox.messageManager)
        ?.registerMessageSendingCallback(_messageSendingCallback);
  }

  bool _isMucInvite(mox.Stanza stanza) {
    final mucUser = stanza.firstTag(_mucUserTag, xmlns: _mucUserXmlns);
    if (mucUser == null) return false;
    return mucUser.firstTag(_mucInviteTag) != null;
  }

  List<mox.XMLNode> _messageSendingCallback(
    mox.TypedMap<mox.StanzaHandlerExtension> extensions,
  ) {
    final nodes = <mox.XMLNode>[];
    final directInvite = extensions.get<DirectMucInviteData>();
    if (directInvite != null) {
      nodes.add(directInvite.toXml());
    }
    final axiInvite = extensions.get<AxiMucInvitePayload>();
    if (axiInvite != null) {
      nodes.add(axiInvite.toXml());
    }
    return nodes;
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

    final directInvite = DirectMucInviteData.fromStanza(stanza);
    if (directInvite != null) {
      state.extensions.set(directInvite);
    }

    final axiInvite = AxiMucInvitePayload.fromStanza(stanza);
    if (axiInvite != null) {
      state.extensions.set(axiInvite);
    }

    final subjectNode = stanza.firstTag(_subjectTag);
    final type = stanza.type ?? stanza.attributes[_iqTypeAttr]?.toString();
    if (type == _messageTypeGroupchat && subjectNode != null) {
      final fromAttr = stanza.from?.trim();
      if (fromAttr?.isNotEmpty == true) {
        final subject = _normalizeInviteText(subjectNode.innerText());
        final roomJid = mox.JID.fromString(fromAttr!).toBare().toString();
        getAttributes().sendEvent(
          MucSubjectChangedEvent(
            roomJid: roomJid,
            subject: subject,
          ),
        );
      }
    }

    if (stanza.id == null || stanza.id!.isEmpty) {
      _log.fine('Allowing message stanza without id');
    }

    return state;
  }
}
