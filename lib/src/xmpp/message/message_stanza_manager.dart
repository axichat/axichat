// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

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
const bool _calendarTaskIcsReadOnlyDefault = true;
const _calendarAvailabilityXmlns = 'urn:axichat:calendar-availability:1';
const _calendarAvailabilityTag = 'calendar-availability';
const _calendarAvailabilityPayloadTag = 'payload';
const _calendarAvailabilityVersionAttr = 'version';
const _calendarAvailabilityVersionValue = '1';
const _pinMutationXmlns = 'urn:axichat:pins:1';
const _pinMutationTag = 'pin';
const _pinMutationVersionAttr = 'version';
const _pinMutationVersionValue = '2';
const _pinMutationMessageIdAttr = 'message-id';
const _pinMutationReferenceKindAttr = 'reference-kind';
const _pinMutationPinnedAttr = 'pinned';
const _pinMutationScopeAttr = 'scope';
const _pinMutationTimestampAttr = 'timestamp';
const _mucUserXmlns = 'http://jabber.org/protocol/muc#user';
const _mucUserTag = 'x';
const _mucUserItemTag = 'item';
const _mucUserItemJidAttr = 'jid';
const _mucJoinXmlns = 'http://jabber.org/protocol/muc';
const _directInviteTag = 'x';
const _directInviteXmlns = 'jabber:x:conference';
const _directInviteRoomAttr = 'jid';
const _directInviteReasonAttr = 'reason';
const _directInvitePasswordAttr = 'password';
const _directInviteContinueAttr = 'continue';
const _axiInviteXmlns = 'urn:axichat:invite:1';
const _axiInviteTag = 'invite';
const _axiInviteRevokeTag = 'invite-revoke';
const _axiInviteAcceptedTag = 'invite-accepted';
const _axiInviteRoomAttr = 'room';
const _axiInviteTokenAttr = 'token';
const _axiInviteInviterAttr = 'inviter';
const _axiInviteInviteeAttr = 'invitee';
const _axiInviteRoomNameAttr = 'room_name';
const _axiInviteReasonAttr = 'reason';
const _axiInvitePasswordAttr = 'password';
const int _inviteFieldMaxLength = 512;
const int _inviteRoomJidMaxLength = 1024;
const int _calendarFragmentPayloadMaxLength = 200000;
const int _calendarTaskIcsPayloadMaxLength = 200000;
const int _calendarAvailabilityPayloadMaxLength = 200000;
const int _pinMutationMessageIdMaxLength = 1024;
const int _pinMutationTimestampMaxLength = 64;
const String _xmlNamespaceAttr = 'xmlns';
const String _messageTypeError = 'error';
const String _errorTypeAttr = 'type';
const String _errorTextTag = 'text';
const String _errorTypeModify = 'modify';
const String _errorTypeWait = 'wait';
const String _errorTypeCancel = 'cancel';
const String _errorConditionNotAcceptable = 'not-acceptable';
const String _errorConditionResourceConstraint = 'resource-constraint';
const String _errorConditionServiceUnavailable = 'service-unavailable';
const String _messageTag = 'message';
const int _outgoingMessageHandlerPriority = 120;

int _utf8ByteLength(String value) => utf8.encode(value).length;

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
    final trimmedReason = _normalizeInviteText(
      reason,
      maxLength: _inviteFieldMaxLength,
    );
    final trimmedPassword = _normalizeInviteText(
      password,
      maxLength: _inviteFieldMaxLength,
    );
    return mox.XMLNode.xmlns(
      tag: _directInviteTag,
      xmlns: _directInviteXmlns,
      attributes: {
        _directInviteRoomAttr: escapeXmlAttribute(roomJid),
        if (trimmedReason?.isNotEmpty == true)
          _directInviteReasonAttr: escapeXmlAttribute(trimmedReason!),
        if (trimmedPassword?.isNotEmpty == true)
          _directInvitePasswordAttr: escapeXmlAttribute(trimmedPassword!),
        if (continueFlag == true) _directInviteContinueAttr: 'true',
      },
    );
  }

  static DirectMucInviteData? fromStanza(mox.Stanza stanza) {
    final invite = stanza.firstTag(_directInviteTag, xmlns: _directInviteXmlns);
    if (invite == null) return null;
    final roomJid = invite.attributes[_directInviteRoomAttr]?.toString().trim();
    if (roomJid == null ||
        roomJid.isEmpty ||
        roomJid.length > _inviteRoomJidMaxLength) {
      return null;
    }
    final reasonAttr = invite.attributes[_directInviteReasonAttr]
        ?.toString()
        .trim();
    final passwordAttr = invite.attributes[_directInvitePasswordAttr]
        ?.toString()
        .trim();
    final continueAttr = invite.attributes[_directInviteContinueAttr]
        ?.toString()
        .trim();
    final reason = _normalizeInviteText(
      reasonAttr ?? invite.innerText(),
      maxLength: _inviteFieldMaxLength,
    );
    final password = _normalizeInviteText(
      passwordAttr,
      maxLength: _inviteFieldMaxLength,
    );
    final continueFlag = _parseInviteBool(continueAttr);
    return DirectMucInviteData(
      roomJid: roomJid,
      reason: reason,
      password: password,
      continueFlag: continueFlag,
    );
  }
}

enum AxiMucInvitePayloadKind {
  invite,
  revocation,
  acceptance;

  String get tag => switch (this) {
    AxiMucInvitePayloadKind.invite => _axiInviteTag,
    AxiMucInvitePayloadKind.revocation => _axiInviteRevokeTag,
    AxiMucInvitePayloadKind.acceptance => _axiInviteAcceptedTag,
  };

  bool get isRevocation => this == AxiMucInvitePayloadKind.revocation;

  bool get isAcceptance => this == AxiMucInvitePayloadKind.acceptance;
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
    AxiMucInvitePayloadKind kind = AxiMucInvitePayloadKind.invite,
    bool revoked = false,
  }) : kind = revoked ? AxiMucInvitePayloadKind.revocation : kind;

  final String roomJid;
  final String? token;
  final String? inviter;
  final String? invitee;
  final String? roomName;
  final String? reason;
  final String? password;
  final AxiMucInvitePayloadKind kind;

  bool get revoked => kind.isRevocation;

  mox.XMLNode toXml() {
    final trimmedToken = _normalizeInviteText(
      token,
      maxLength: _inviteFieldMaxLength,
    );
    final trimmedInviter = _normalizeInviteText(
      inviter,
      maxLength: _inviteFieldMaxLength,
    );
    final trimmedInvitee = _normalizeInviteText(
      invitee,
      maxLength: _inviteFieldMaxLength,
    );
    final trimmedRoomName = _normalizeInviteText(
      roomName,
      maxLength: _inviteFieldMaxLength,
    );
    final trimmedReason = _normalizeInviteText(
      reason,
      maxLength: _inviteFieldMaxLength,
    );
    final trimmedPassword = _normalizeInviteText(
      password,
      maxLength: _inviteFieldMaxLength,
    );
    return mox.XMLNode.xmlns(
      tag: kind.tag,
      xmlns: _axiInviteXmlns,
      attributes: {
        _axiInviteRoomAttr: escapeXmlAttribute(roomJid),
        if (trimmedToken?.isNotEmpty == true)
          _axiInviteTokenAttr: escapeXmlAttribute(trimmedToken!),
        if (trimmedInviter?.isNotEmpty == true)
          _axiInviteInviterAttr: escapeXmlAttribute(trimmedInviter!),
        if (trimmedInvitee?.isNotEmpty == true)
          _axiInviteInviteeAttr: escapeXmlAttribute(trimmedInvitee!),
        if (trimmedRoomName?.isNotEmpty == true)
          _axiInviteRoomNameAttr: escapeXmlAttribute(trimmedRoomName!),
        if (!kind.isAcceptance && trimmedReason?.isNotEmpty == true)
          _axiInviteReasonAttr: escapeXmlAttribute(trimmedReason!),
        if (!kind.isAcceptance && trimmedPassword?.isNotEmpty == true)
          _axiInvitePasswordAttr: escapeXmlAttribute(trimmedPassword!),
      },
    );
  }

  static AxiMucInvitePayload? fromStanza(mox.Stanza stanza) {
    final invite = stanza.firstTag(_axiInviteTag, xmlns: _axiInviteXmlns);
    final revoke = stanza.firstTag(_axiInviteRevokeTag, xmlns: _axiInviteXmlns);
    final accepted = stanza.firstTag(
      _axiInviteAcceptedTag,
      xmlns: _axiInviteXmlns,
    );
    final node = invite ?? revoke ?? accepted;
    if (node == null) return null;
    final roomJid = node.attributes[_axiInviteRoomAttr]?.toString().trim();
    if (roomJid == null ||
        roomJid.isEmpty ||
        roomJid.length > _inviteRoomJidMaxLength) {
      return null;
    }
    final token = _normalizeInviteText(
      node.attributes[_axiInviteTokenAttr]?.toString(),
      maxLength: _inviteFieldMaxLength,
    );
    final inviter = _normalizeInviteText(
      node.attributes[_axiInviteInviterAttr]?.toString(),
      maxLength: _inviteFieldMaxLength,
    );
    final invitee = _normalizeInviteText(
      node.attributes[_axiInviteInviteeAttr]?.toString(),
      maxLength: _inviteFieldMaxLength,
    );
    final roomName = _normalizeInviteText(
      node.attributes[_axiInviteRoomNameAttr]?.toString(),
      maxLength: _inviteFieldMaxLength,
    );
    final reason = _normalizeInviteText(
      node.attributes[_axiInviteReasonAttr]?.toString(),
      maxLength: _inviteFieldMaxLength,
    );
    final password = _normalizeInviteText(
      node.attributes[_axiInvitePasswordAttr]?.toString(),
      maxLength: _inviteFieldMaxLength,
    );
    final kind = invite != null
        ? AxiMucInvitePayloadKind.invite
        : revoke != null
        ? AxiMucInvitePayloadKind.revocation
        : AxiMucInvitePayloadKind.acceptance;
    if (kind.isAcceptance &&
        (token == null || inviter == null || invitee == null)) {
      return null;
    }
    return AxiMucInvitePayload(
      roomJid: roomJid,
      token: token,
      inviter: inviter,
      invitee: invitee,
      roomName: roomName,
      reason: reason,
      password: password,
      kind: kind,
    );
  }
}

final class StanzaErrorConditionData implements mox.StanzaHandlerExtension {
  const StanzaErrorConditionData({required this.condition, this.type});

  final String condition;
  final String? type;
}

final class MessageSubjectData implements mox.StanzaHandlerExtension {
  const MessageSubjectData(this.subject);

  final String subject;

  static MessageSubjectData? fromStanza(mox.Stanza stanza) {
    final type = (stanza.type ?? stanza.attributes[_iqTypeAttr]?.toString())
        ?.trim();
    if (type == _messageTypeGroupchat) return null;
    final subject = clampMessageText(
      stanza.firstTag(_subjectTag)?.innerText(),
    )?.trim();
    if (subject == null || subject.isEmpty) return null;
    return MessageSubjectData(subject);
  }
}

final class MucUserItemData implements mox.StanzaHandlerExtension {
  const MucUserItemData({required this.jid});

  final String jid;

  static MucUserItemData? fromStanza(mox.Stanza stanza) {
    final mucUser = stanza.firstTag(_mucUserTag, xmlns: _mucUserXmlns);
    final item = mucUser?.firstTag(_mucUserItemTag);
    final jid = item?.attributes[_mucUserItemJidAttr]?.toString().trim();
    if (jid == null || jid.isEmpty || jid.length > _inviteRoomJidMaxLength) {
      return null;
    }
    return MucUserItemData(jid: jid);
  }
}

final class OutboundGroupchatStanzaEvent extends mox.XmppEvent {
  OutboundGroupchatStanzaEvent({required this.stanzaId, required this.roomJid});

  final String stanzaId;
  final String roomJid;
}

final class InboundGroupchatMucStanzaIdEvent extends mox.XmppEvent {
  InboundGroupchatMucStanzaIdEvent({
    required this.stanzaId,
    required this.roomJid,
    required this.mucStanzaId,
  });

  final String stanzaId;
  final String roomJid;
  final String mucStanzaId;
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
          text: escapeXmlText(payload),
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
    final int payloadLength = _utf8ByteLength(payloadText);
    if (payloadLength > _calendarFragmentPayloadMaxLength) {
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
  const CalendarTaskIcsPayload({
    required this.ics,
    bool readOnly = _calendarTaskIcsReadOnlyDefault,
  }) : readOnly = _calendarTaskIcsReadOnlyDefault;

  final String ics;
  final bool readOnly;

  mox.XMLNode toXml() {
    final payload = ics.trim();
    return mox.XMLNode.xmlns(
      tag: _calendarTaskIcsTag,
      xmlns: _calendarTaskIcsXmlns,
      attributes: {_calendarTaskIcsVersionAttr: _calendarTaskIcsVersionValue},
      children: [
        mox.XMLNode(
          tag: _calendarTaskIcsPayloadTag,
          text: escapeXmlText(payload),
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
    final int payloadLength = _utf8ByteLength(payloadText);
    if (payloadLength > _calendarTaskIcsPayloadMaxLength) {
      return null;
    }
    return CalendarTaskIcsPayload(
      ics: payloadText,
      readOnly: _calendarTaskIcsReadOnlyDefault,
    );
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
          text: escapeXmlText(payload),
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
    final int payloadLength = _utf8ByteLength(payloadText);
    if (payloadLength > _calendarAvailabilityPayloadMaxLength) {
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

enum PinMessageMutationScope {
  own,
  all;

  String get wireValue => switch (this) {
    PinMessageMutationScope.own => 'own',
    PinMessageMutationScope.all => 'all',
  };

  static PinMessageMutationScope fromWireValue(String? value) {
    final normalized = value?.trim();
    return switch (normalized) {
      'all' => PinMessageMutationScope.all,
      _ => PinMessageMutationScope.own,
    };
  }
}

final class PinMessageMutationData implements mox.StanzaHandlerExtension {
  PinMessageMutationData({
    String? messageId,
    MessageReference? reference,
    MessageReferenceKind? messageReferenceKind,
    required this.pinned,
    required this.timestamp,
    this.scope = PinMessageMutationScope.own,
  }) : assert(reference != null || messageId != null),
       reference =
           reference ??
           MessageReference(
             kind: messageReferenceKind ?? MessageReferenceKind.stanzaId,
             value: messageId ?? '',
           );

  final MessageReference reference;
  final bool pinned;
  final DateTime timestamp;
  final PinMessageMutationScope scope;

  String get messageId => reference.value;

  mox.XMLNode toXml() {
    return mox.XMLNode.xmlns(
      tag: _pinMutationTag,
      xmlns: _pinMutationXmlns,
      attributes: {
        _pinMutationVersionAttr: _pinMutationVersionValue,
        _pinMutationMessageIdAttr: escapeXmlAttribute(reference.value),
        _pinMutationReferenceKindAttr: reference.kind.wireValue,
        _pinMutationPinnedAttr: pinned.toString(),
        _pinMutationScopeAttr: scope.wireValue,
        _pinMutationTimestampAttr: timestamp.toUtc().toIso8601String(),
      },
    );
  }

  static PinMessageMutationData? fromStanza(mox.Stanza stanza) {
    final node = stanza.firstTag(_pinMutationTag, xmlns: _pinMutationXmlns);
    if (node == null) return null;
    final messageId = node.attributes[_pinMutationMessageIdAttr]
        ?.toString()
        .trim();
    if (messageId == null ||
        messageId.isEmpty ||
        messageId.length > _pinMutationMessageIdMaxLength) {
      return null;
    }
    final pinned = _parseInviteBool(
      node.attributes[_pinMutationPinnedAttr]?.toString(),
    );
    if (pinned == null) {
      return null;
    }
    final referenceKind =
        MessageReferenceKind.fromWireValue(
          node.attributes[_pinMutationReferenceKindAttr]?.toString(),
        ) ??
        (stanza.type == _messageTypeGroupchat
            ? MessageReferenceKind.mucStanzaId
            : MessageReferenceKind.stanzaId);
    final scope = PinMessageMutationScope.fromWireValue(
      node.attributes[_pinMutationScopeAttr]?.toString(),
    );
    final rawTimestamp = node.attributes[_pinMutationTimestampAttr]
        ?.toString()
        .trim();
    if (rawTimestamp == null ||
        rawTimestamp.isEmpty ||
        rawTimestamp.length > _pinMutationTimestampMaxLength) {
      return null;
    }
    final timestamp = DateTime.tryParse(rawTimestamp);
    if (timestamp == null) {
      return null;
    }
    return PinMessageMutationData(
      reference: MessageReference(kind: referenceKind, value: messageId),
      pinned: pinned,
      scope: scope,
      timestamp: timestamp.toUtc(),
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

String? _normalizeInviteText(String? text, {required int maxLength}) {
  final trimmed = text?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  if (trimmed.length > maxLength) return null;
  return trimmed;
}

String? _normalizeStanzaErrorType(String? rawType) {
  final trimmed = rawType?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed.toLowerCase();
}

@visibleForTesting
bool normalizeReactionNamespace(mox.Stanza stanza) {
  final reactionNode = stanza.firstTag('reactions');
  if (reactionNode == null) {
    return false;
  }
  final rawXmlns = reactionNode.attributes[_xmlNamespaceAttr]
      ?.toString()
      .trim();
  if (rawXmlns == mox.messageReactionsXmlns) {
    return false;
  }
  if (rawXmlns != null && rawXmlns.isNotEmpty) {
    return false;
  }
  reactionNode.attributes = <String, dynamic>{
    ...reactionNode.attributes,
    _xmlNamespaceAttr: mox.messageReactionsXmlns,
  };
  return true;
}

mox.XMLNode? _findStanzaErrorConditionNode(mox.XMLNode errorNode) {
  for (final child in errorNode.children) {
    final String? xmlns = child.attributes[_xmlNamespaceAttr]?.toString();
    if (xmlns != mox.fullStanzaXmlns) continue;
    final tag = child.tag.trim();
    if (tag.isEmpty) continue;
    if (tag == _errorTextTag) continue;
    return child;
  }
  return null;
}

StanzaErrorConditionData? _parseStanzaErrorCondition(mox.Stanza stanza) {
  final String? stanzaType = stanza.type?.trim();
  if (stanzaType != _messageTypeError) return null;
  final mox.XMLNode? errorNode = stanza.firstTag(_errorTag);
  if (errorNode == null) return null;
  final mox.XMLNode? conditionNode = _findStanzaErrorConditionNode(errorNode);
  final String? condition = conditionNode?.tag.trim();
  if (condition == null || condition.isEmpty) return null;
  final String? normalizedType = _normalizeStanzaErrorType(
    errorNode.attributes[_errorTypeAttr]?.toString(),
  );
  return StanzaErrorConditionData(condition: condition, type: normalizedType);
}

class MessageStanzaManager extends mox.XmppManagerBase {
  MessageStanzaManager() : super('axi.message.stanza');

  final _log = Logger('MessageStanzaManager');
  static const String _mucInviteTag = 'invite';

  @override
  List<mox.StanzaHandler> getIncomingPreStanzaHandlers() => [
    mox.StanzaHandler(
      stanzaTag: _messageTag,
      priority: 9997,
      callback: _onIncomingMessage,
    ),
  ];

  @override
  List<mox.StanzaHandler> getOutgoingPreStanzaHandlers() => [
    mox.StanzaHandler(
      stanzaTag: _messageTag,
      priority: _outgoingMessageHandlerPriority,
      callback: _onOutgoingMessage,
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
    final pinMutation = extensions.get<PinMessageMutationData>();
    if (pinMutation != null) {
      nodes.add(pinMutation.toXml());
    }
    return nodes;
  }

  Future<mox.StanzaHandlerData> _onOutgoingMessage(
    mox.Stanza stanza,
    mox.StanzaHandlerData state,
  ) async {
    final stanzaId = stanza.id?.trim();
    if (stanzaId == null || stanzaId.isEmpty) return state;
    final normalizedReactionNamespace = normalizeReactionNamespace(stanza);
    final reactionNode = stanza.firstTag(
      'reactions',
      xmlns: mox.messageReactionsXmlns,
    );
    if (reactionNode != null) {
      final emojis = reactionNode
          .findTags('reaction')
          .map((node) => node.innerText())
          .toList();
      _log.fine(
        'Outgoing raw reaction stanza id=$stanzaId to=${stanza.to ?? 'none'} '
        'type=${stanza.type ?? 'chat'} '
        'target=${reactionNode.attributes['id']?.toString() ?? 'none'} '
        'emojis=$emojis normalized=$normalizedReactionNamespace',
      );
    }
    final type = stanza.type?.trim();
    if (type != _messageTypeGroupchat) return state;
    final toRaw = stanza.to?.trim();
    if (toRaw == null || toRaw.isEmpty) return state;
    final roomJid = _normalizeMucRoomJidCandidate(toRaw);
    if (roomJid == null) return state;
    getAttributes().sendEvent(
      OutboundGroupchatStanzaEvent(stanzaId: stanzaId, roomJid: roomJid),
    );
    return state;
  }

  void _emitInboundGroupchatMucStanzaId(mox.Stanza stanza) {
    final stanzaId = stanza.id?.trim();
    if (stanzaId == null || stanzaId.isEmpty) return;
    if (stanza.type?.trim() != _messageTypeGroupchat) return;
    final fromAttr = stanza.from?.trim();
    if (fromAttr == null || fromAttr.isEmpty) return;
    late final String roomJid;
    try {
      final roomCandidate = mox.JID.fromString(fromAttr).toBare().toString();
      final normalizedRoom = _normalizeMucRoomJidCandidate(roomCandidate);
      if (normalizedRoom == null) return;
      roomJid = normalizedRoom;
    } on Exception {
      return;
    }
    for (final child in stanza.findTags(
      'stanza-id',
      xmlns: mox.stableIdXmlns,
    )) {
      if (!sameNormalizedAddressValue(
        child.attributes['by']?.toString(),
        roomJid,
      )) {
        continue;
      }
      final mucStanzaId = child.attributes['id']?.toString().trim();
      if (mucStanzaId == null || mucStanzaId.isEmpty) {
        continue;
      }
      getAttributes().sendEvent(
        InboundGroupchatMucStanzaIdEvent(
          stanzaId: stanzaId,
          roomJid: roomJid,
          mucStanzaId: mucStanzaId,
        ),
      );
      return;
    }
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

    final StanzaErrorConditionData? errorCondition = _parseStanzaErrorCondition(
      stanza,
    );
    if (errorCondition != null) {
      state.extensions.set(errorCondition);
    }

    final mucUserItem = MucUserItemData.fromStanza(stanza);
    if (mucUserItem != null) {
      state.extensions.set(mucUserItem);
    }

    _emitInboundGroupchatMucStanzaId(stanza);

    if (_isMucInvite(stanza)) {
      state.done = true;
      return state;
    }

    final normalizedReactionNamespace = normalizeReactionNamespace(stanza);
    final reactionNode = stanza.firstTag(
      'reactions',
      xmlns: mox.messageReactionsXmlns,
    );
    if (reactionNode != null) {
      final emojis = reactionNode
          .findTags('reaction')
          .map((node) => node.innerText())
          .toList();
      _log.fine(
        'Incoming raw reaction stanza id=${stanza.id ?? 'none'} '
        'from=${stanza.from ?? 'none'} to=${stanza.to ?? 'none'} '
        'type=${stanza.type ?? 'chat'} '
        'target=${reactionNode.attributes['id']?.toString() ?? 'none'} '
        'emojis=$emojis normalized=$normalizedReactionNamespace',
      );
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
    final pinMutation = PinMessageMutationData.fromStanza(stanza);
    if (pinMutation != null) {
      state.extensions.set(pinMutation);
    }

    final subject = MessageSubjectData.fromStanza(stanza);
    if (subject != null) {
      state.extensions.set(subject);
    }

    final subjectNode = stanza.firstTag(_subjectTag);
    final type = stanza.type ?? stanza.attributes[_iqTypeAttr]?.toString();
    if (type == _messageTypeGroupchat && subjectNode != null) {
      final fromAttr = stanza.from?.trim();
      if (fromAttr?.isNotEmpty == true) {
        final subject = _normalizeInviteText(
          subjectNode.innerText(),
          maxLength: _inviteFieldMaxLength,
        );
        final roomJid = mox.JID.fromString(fromAttr!).toBare().toString();
        getAttributes().sendEvent(
          MucSubjectChangedEvent(roomJid: roomJid, subject: subject),
        );
      }
    }

    if (stanza.id == null || stanza.id!.isEmpty) {
      _log.fine('Allowing message stanza without id');
    }

    return state;
  }
}
