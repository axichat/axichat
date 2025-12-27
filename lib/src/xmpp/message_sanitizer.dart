part of 'package:axichat/src/xmpp/xmpp_service.dart';

const _calendarFragmentXmlns = 'urn:axichat:calendar-fragment:1';
const _calendarFragmentTag = 'calendar-fragment';
const _calendarFragmentPayloadTag = 'payload';
const _calendarFragmentVersionAttr = 'version';
const _calendarFragmentVersionValue = '1';
const _calendarTaskIcsXmlns = 'urn:axichat:calendar-task-ics:1';
const _calendarTaskIcsTag = 'calendar-task-ics';
const _calendarTaskIcsPayloadTag = 'payload';
const _calendarTaskIcsVersionAttr = 'version';
const _calendarTaskIcsVersionValue = '1';
const _calendarAvailabilityXmlns = 'urn:axichat:calendar-availability:1';
const _calendarAvailabilityTag = 'calendar-availability';
const _calendarAvailabilityPayloadTag = 'payload';
const _calendarAvailabilityVersionAttr = 'version';
const _calendarAvailabilityVersionValue = '1';

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

final class CalendarFragmentPayload implements mox.StanzaHandlerExtension {
  const CalendarFragmentPayload({required this.fragment});

  final CalendarFragment fragment;

  mox.XMLNode toXml() {
    final payload = jsonEncode(fragment.toJson());
    return mox.XMLNode.xmlns(
      tag: _calendarFragmentTag,
      xmlns: _calendarFragmentXmlns,
      attributes: const {
        _calendarFragmentVersionAttr: _calendarFragmentVersionValue,
      },
      children: [
        mox.XMLNode(
          tag: _calendarFragmentPayloadTag,
          text: payload,
        ),
      ],
    );
  }

  static CalendarFragmentPayload? fromStanza(mox.Stanza stanza) {
    final node = stanza.firstTag(
      _calendarFragmentTag,
      xmlns: _calendarFragmentXmlns,
    );
    if (node == null) return null;
    final payloadNode = node.firstTag(_calendarFragmentPayloadTag);
    final payloadText =
        payloadNode?.innerText().trim() ?? node.innerText().trim();
    if (payloadText.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(payloadText);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return CalendarFragmentPayload(
        fragment: CalendarFragment.fromJson(decoded),
      );
    } catch (_) {
      return null;
    }
  }
}

final class CalendarTaskIcsPayload implements mox.StanzaHandlerExtension {
  const CalendarTaskIcsPayload({required this.ics});

  final String ics;

  mox.XMLNode toXml() {
    final payload = ics.trim();
    return mox.XMLNode.xmlns(
      tag: _calendarTaskIcsTag,
      xmlns: _calendarTaskIcsXmlns,
      attributes: const {
        _calendarTaskIcsVersionAttr: _calendarTaskIcsVersionValue,
      },
      children: [
        mox.XMLNode(
          tag: _calendarTaskIcsPayloadTag,
          text: payload,
        ),
      ],
    );
  }

  static CalendarTaskIcsPayload? fromStanza(mox.Stanza stanza) {
    final node = stanza.firstTag(
      _calendarTaskIcsTag,
      xmlns: _calendarTaskIcsXmlns,
    );
    if (node == null) return null;
    final payloadNode = node.firstTag(_calendarTaskIcsPayloadTag);
    final payloadText =
        payloadNode?.innerText().trim() ?? node.innerText().trim();
    if (payloadText.isEmpty) {
      return null;
    }
    return CalendarTaskIcsPayload(ics: payloadText);
  }
}

final class CalendarAvailabilityMessagePayload
    implements mox.StanzaHandlerExtension {
  const CalendarAvailabilityMessagePayload({required this.message});

  final CalendarAvailabilityMessage message;

  mox.XMLNode toXml() {
    final payload = jsonEncode(message.toJson());
    return mox.XMLNode.xmlns(
      tag: _calendarAvailabilityTag,
      xmlns: _calendarAvailabilityXmlns,
      attributes: const {
        _calendarAvailabilityVersionAttr: _calendarAvailabilityVersionValue,
      },
      children: [
        mox.XMLNode(
          tag: _calendarAvailabilityPayloadTag,
          text: payload,
        ),
      ],
    );
  }

  static CalendarAvailabilityMessagePayload? fromStanza(mox.Stanza stanza) {
    final node = stanza.firstTag(
      _calendarAvailabilityTag,
      xmlns: _calendarAvailabilityXmlns,
    );
    if (node == null) return null;
    final payloadNode = node.firstTag(_calendarAvailabilityPayloadTag);
    final payloadText =
        payloadNode?.innerText().trim() ?? node.innerText().trim();
    if (payloadText.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(payloadText);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return CalendarAvailabilityMessagePayload(
        message: CalendarAvailabilityMessage.fromJson(decoded),
      );
    } catch (_) {
      return null;
    }
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
    final fragment = extensions.get<CalendarFragmentPayload>();
    if (fragment != null) {
      nodes.add(fragment.toXml());
    }
    final taskIcs = extensions.get<CalendarTaskIcsPayload>();
    if (taskIcs != null) {
      nodes.add(taskIcs.toXml());
    }
    final availability = extensions.get<CalendarAvailabilityMessagePayload>();
    if (availability != null) {
      nodes.add(availability.toXml());
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

    final fragment = CalendarFragmentPayload.fromStanza(stanza);
    if (fragment != null) {
      state.extensions.set(fragment);
    }
    final taskIcs = CalendarTaskIcsPayload.fromStanza(stanza);
    if (taskIcs != null) {
      state.extensions.set(taskIcs);
    }
    final availability = CalendarAvailabilityMessagePayload.fromStanza(stanza);
    if (availability != null) {
      state.extensions.set(availability);
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
