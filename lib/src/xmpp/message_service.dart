// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'package:axichat/src/xmpp/xmpp_service.dart';

final RegExp _crlfPattern = RegExp(r'[\r\n]');
const CalendarTaskIcsCodec _calendarTaskIcsCodec = CalendarTaskIcsCodec();

const String _messageStatusSyncEnvelopeKey = 'message_status_sync';
const int _messageStatusSyncEnvelopeVersion = 1;
const String _messageStatusSyncEnvelopeIdKey = 'id';
const String _messageStatusSyncEnvelopeVersionKey = 'v';
const String _messageStatusSyncEnvelopeAckedKey = 'acked';
const String _messageStatusSyncEnvelopeReceivedKey = 'received';
const String _messageStatusSyncEnvelopeDisplayedKey = 'displayed';
const String _availabilityShareFallbackText = 'Shared availability';
const String _availabilityRequestFallbackText = 'Availability request';
const String _availabilityResponseAcceptedFallbackText =
    'Availability accepted';
const String _availabilityResponseDeclinedFallbackText =
    'Availability declined';
const String _calendarSyncOperationUpdate = 'update';
const String _calendarSyncOperationDelete = 'delete';
const String _calendarSyncEntityTask = 'task';
const String _calendarSyncMissingRoleLog =
    'Rejected calendar sync message; sender role unavailable.';
const String _calendarSyncUnauthorizedLog =
    'Rejected calendar sync message; sender role insufficient.';
const String _calendarSyncMamBypassLog =
    'Allowing calendar sync message without sender role (MAM history).';
const String _calendarSyncReadOnlyRejectedLog =
    'Rejected calendar sync message targeting read-only task.';
const String _attachmentUploadStartLog =
    'Uploading attachment to HTTP upload slot.';
const String _attachmentUploadCompleteLog = 'Upload complete for attachment.';
const String _attachmentUploadFailedLog = 'Failed to upload attachment.';
const String _uploadSlotRequestLog = 'Requesting HTTP upload slot.';
const String _uploadSlotRequestFailedLog = 'Failed to request upload slot.';
const String _carbonOriginRejectedLog =
    'Rejected carbon message with unexpected sender.';
const String _mamOriginRejectedLog =
    'Rejected archive message without local account routing.';
const String _mamGlobalNoProgressLog =
    'Global MAM sync stalled; stopping to avoid churn.';
const String _mucMutationRejectedLog =
    'Rejected group chat mutation from unknown occupant.';
const bool _mucSendAllowRejoin = true;
const int _outboundSummaryLimit = 80;
const String _outboundMessageRejectedLog = 'Outbound message rejected';
const String _outboundMessageRejectedMissingSummaryLog =
    'Outbound message rejected without summary';
const String _outboundSummaryUnknownType = 'unknown';
const String _outboundSummaryPrefixSeparator = ': ';
const String _outboundSummarySeparator = '; ';
const String _outboundSummaryPairSeparator = '=';
const String _outboundSummaryFlagSeparator = ',';
const String _outboundSummaryKindLabel = 'kind';
const String _outboundSummaryChatTypeLabel = 'chat_type';
const String _outboundSummaryMessageTypeLabel = 'message_type';
const String _outboundSummaryHasBodyLabel = 'has_body';
const String _outboundSummaryHasHtmlLabel = 'has_html';
const String _outboundSummaryFlagsLabel = 'flags';
const String _outboundSummaryErrorLabel = 'error';
const String _outboundSummaryKindMessage = 'message';
const String _outboundSummaryKindAttachment = 'attachment';
const String _outboundSummaryChatTypeChat = 'chat';
const String _outboundSummaryChatTypeGroup = 'group';
const String _outboundSummaryChatTypeNote = 'note';
const String _outboundSummaryFlagChatState = 'chat_state';
const String _outboundSummaryFlagMarkable = 'markable';
const String _outboundSummaryFlagReceipt = 'receipt';
const String _outboundSummaryFlagMarker = 'marker';
const String _outboundSummaryFlagProcessingHints = 'processing_hints';
const String _outboundSummaryFlagReply = 'reply';
const String _outboundSummaryFlagRetraction = 'retraction';
const String _outboundSummaryFlagCorrection = 'correction';
const String _outboundSummaryFlagOmemo = 'omemo';
const String _outboundSummaryFlagOob = 'oob';
const String _outboundSummaryFlagSfs = 'sfs';
const String _outboundSummaryFlagUploadNotification = 'upload_notification';
const String _outboundSummaryFlagXhtml = 'xhtml';
const String _pinPubSubNamespace = 'urn:axi:pins';
const String _pinPubSubNodePrefix = 'urn:axi:pins:';
const String _pinTag = 'pin';
const String _pinMessageIdAttr = 'message_id';
const String _pinPinnedAtAttr = 'pinned_at';
const String _pinChatJidAttr = 'chat_jid';
const String _pinPublishModelOpen = 'open';
const String _pinPublishModelPublishers = 'publishers';
const mox.PubSubAffiliation _pinAffiliationOwner = mox.PubSubAffiliation.owner;
const mox.PubSubAffiliation _pinAffiliationPublisher =
    mox.PubSubAffiliation.publisher;
const String _pinSendLastOnSubscribe = 'on_subscribe';
const int _pinSyncMaxItems = 500;
const String _pinSyncMaxItemsValue = '500';
const bool _pinNotifyEnabled = true;
const bool _pinDeliverNotificationsEnabled = true;
const bool _pinDeliverPayloadsEnabled = true;
const bool _pinPersistItemsEnabled = true;
const bool _pinPresenceBasedDeliveryDisabled = false;
const mox.AccessModel _pinAccessModelOpen = mox.AccessModel.open;
const mox.AccessModel _pinAccessModelRestricted = mox.AccessModel.whitelist;
const String _pinPubSubHostPrefix = 'pubsub.';
const String _pinPendingPublishesKeyName = 'pin_sync_pending_publishes';
const String _pinPendingRetractionsKeyName = 'pin_sync_pending_retractions';
const Set<String> _emptyPinPublisherSet = <String>{};
final _pinPendingPublishesKey =
    XmppStateStore.registerKey(_pinPendingPublishesKeyName);
final _pinPendingRetractionsKey =
    XmppStateStore.registerKey(_pinPendingRetractionsKeyName);
const String _pinBase64PaddingChar = '=';
const int _pinBase64Quantum = 4;
final RegExp _pinBase64PaddingPattern = RegExp(r'=+$');
const int _tlsRequirementNegotiatorPriority = 95;
const bool _tlsRequirementSendStreamHeader = false;
const bool _tlsRequirementErrorRecoverable = false;
const bool _tlsRequirementMatchesAllFeatures = true;
const bool _tlsRequirementNonFeatureDefault = true;
const String _tlsRequirementNegotiatorId = 'axi.im.tls.required';
const String _tlsRequirementNegotiatorXmlns = 'axi.im.tls.required';
const String _tlsRequirementErrorMessage =
    'TLS is required before authentication.';
const String _streamFeaturesTag = 'stream:features';

final class _MessageStatusSyncEnvelope {
  const _MessageStatusSyncEnvelope({
    required this.id,
    required this.acked,
    required this.received,
    required this.displayed,
  });

  final String id;
  final bool acked;
  final bool received;
  final bool displayed;

  Map<String, dynamic> toJson() => {
        _messageStatusSyncEnvelopeVersionKey: _messageStatusSyncEnvelopeVersion,
        _messageStatusSyncEnvelopeIdKey: id,
        _messageStatusSyncEnvelopeAckedKey: acked,
        _messageStatusSyncEnvelopeReceivedKey: received,
        _messageStatusSyncEnvelopeDisplayedKey: displayed,
      };

  static _MessageStatusSyncEnvelope? tryParseEnvelope(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final payload = decoded[_messageStatusSyncEnvelopeKey];
      if (payload is! Map<String, dynamic>) {
        return null;
      }
      final version = payload[_messageStatusSyncEnvelopeVersionKey] as int?;
      if (version != _messageStatusSyncEnvelopeVersion) {
        return null;
      }
      final id = payload[_messageStatusSyncEnvelopeIdKey] as String?;
      if (id == null || id.isEmpty) {
        return null;
      }
      final acked =
          payload[_messageStatusSyncEnvelopeAckedKey] as bool? ?? false;
      final received =
          payload[_messageStatusSyncEnvelopeReceivedKey] as bool? ?? false;
      final displayed =
          payload[_messageStatusSyncEnvelopeDisplayedKey] as bool? ?? false;
      final normalizedDisplayed = displayed;
      final normalizedReceived = normalizedDisplayed || received;
      final normalizedAcked = normalizedReceived || acked;
      return _MessageStatusSyncEnvelope(
        id: id,
        acked: normalizedAcked,
        received: normalizedReceived,
        displayed: normalizedDisplayed,
      );
    } catch (_) {
      return null;
    }
  }

  static bool isEnvelope(String raw) => tryParseEnvelope(raw) != null;
}

enum _OutboundMessageKind {
  message,
  attachment,
}

extension _OutboundMessageKindView on _OutboundMessageKind {
  String get label => switch (this) {
        _OutboundMessageKind.message => _outboundSummaryKindMessage,
        _OutboundMessageKind.attachment => _outboundSummaryKindAttachment,
      };
}

enum _OutboundMessageFlag {
  chatState,
  markable,
  receipt,
  marker,
  processingHints,
  reply,
  retraction,
  correction,
  omemo,
  oob,
  sfs,
  uploadNotification,
  xhtml,
}

extension _OutboundMessageFlagView on _OutboundMessageFlag {
  String get label => switch (this) {
        _OutboundMessageFlag.chatState => _outboundSummaryFlagChatState,
        _OutboundMessageFlag.markable => _outboundSummaryFlagMarkable,
        _OutboundMessageFlag.receipt => _outboundSummaryFlagReceipt,
        _OutboundMessageFlag.marker => _outboundSummaryFlagMarker,
        _OutboundMessageFlag.processingHints =>
          _outboundSummaryFlagProcessingHints,
        _OutboundMessageFlag.reply => _outboundSummaryFlagReply,
        _OutboundMessageFlag.retraction => _outboundSummaryFlagRetraction,
        _OutboundMessageFlag.correction => _outboundSummaryFlagCorrection,
        _OutboundMessageFlag.omemo => _outboundSummaryFlagOmemo,
        _OutboundMessageFlag.oob => _outboundSummaryFlagOob,
        _OutboundMessageFlag.sfs => _outboundSummaryFlagSfs,
        _OutboundMessageFlag.uploadNotification =>
          _outboundSummaryFlagUploadNotification,
        _OutboundMessageFlag.xhtml => _outboundSummaryFlagXhtml,
      };
}

extension _ChatTypeLogView on ChatType {
  String get logLabel => switch (this) {
        ChatType.chat => _outboundSummaryChatTypeChat,
        ChatType.groupChat => _outboundSummaryChatTypeGroup,
        ChatType.note => _outboundSummaryChatTypeNote,
      };
}

final class _OutboundMessageSummary {
  const _OutboundMessageSummary({
    required this.kind,
    required this.chatType,
    required this.messageType,
    required this.hasBody,
    required this.hasHtml,
    required this.flags,
    required this.chatJid,
  });

  final _OutboundMessageKind kind;
  final ChatType chatType;
  final String messageType;
  final bool hasBody;
  final bool hasHtml;
  final List<_OutboundMessageFlag> flags;
  final String? chatJid;

  String toLogPayload({String? errorName}) {
    final List<String> parts = <String>[
      _pair(_outboundSummaryKindLabel, kind.label),
      _pair(_outboundSummaryChatTypeLabel, chatType.logLabel),
      _pair(_outboundSummaryMessageTypeLabel, messageType),
      _pair(_outboundSummaryHasBodyLabel, hasBody),
      _pair(_outboundSummaryHasHtmlLabel, hasHtml),
    ];
    if (flags.isNotEmpty) {
      final String joinedFlags =
          flags.map((flag) => flag.label).join(_outboundSummaryFlagSeparator);
      parts.add(_pair(_outboundSummaryFlagsLabel, joinedFlags));
    }
    if (errorName != null && errorName.isNotEmpty) {
      parts.add(_pair(_outboundSummaryErrorLabel, errorName));
    }
    return parts.join(_outboundSummarySeparator);
  }

  String _pair(String label, Object value) {
    return '$label$_outboundSummaryPairSeparator$value';
  }
}

extension MessageEvent on mox.MessageEvent {
  String get text {
    final replyText = get<mox.ReplyData>()?.withoutFallback;
    if (replyText != null) return replyText;
    final body = get<mox.MessageBodyData>()?.body;
    if (body != null && body.isNotEmpty) return body;
    final htmlPlain = get<XhtmlImData>()?.plainText;
    if (htmlPlain != null && htmlPlain.isNotEmpty) {
      return htmlPlain;
    }
    return '';
  }

  bool get isCarbon => get<mox.CarbonsData>()?.isCarbon ?? false;

  bool get displayable {
    final hasBody = get<mox.MessageBodyData>()?.body?.isNotEmpty ?? false;
    final htmlData = get<XhtmlImData>();
    final hasHtml = htmlData != null && htmlData.xhtmlBody.isNotEmpty;
    final hasSfs = get<mox.StatelessFileSharingData>() != null;
    final hasFun = get<mox.FileUploadNotificationData>() != null;
    final hasOob = get<mox.OOBData>() != null;
    return hasBody || hasHtml || hasSfs || hasFun || hasOob;
  }
}

bool _isOversizedMessage(mox.MessageEvent event, Logger log) {
  final body = event.extensions.get<mox.MessageBodyData>()?.body;
  if (body != null && !isMessageTextWithinLimit(body)) {
    final looksLikeCalendarSync = CalendarSyncMessage.looksLikeEnvelope(body);
    final maxBytes = looksLikeCalendarSync
        ? CalendarSyncMessage.maxEnvelopeLength
        : maxMessageTextBytes;
    if (!isWithinUtf8ByteLimit(body, maxBytes: maxBytes)) {
      final sizeBytes = utf8ByteLength(body);
      log.warning('Dropped message with oversized text payload ($sizeBytes)');
      return true;
    }
  }
  final htmlBody = event.extensions.get<XhtmlImData>()?.xhtmlBody;
  if (htmlBody != null && !isMessageHtmlWithinLimit(htmlBody)) {
    final sizeBytes = utf8ByteLength(htmlBody);
    log.warning('Dropped message with oversized HTML payload ($sizeBytes)');
    return true;
  }
  return false;
}

String? _normalizeBareJidValue(String? jid) {
  final trimmed = jid?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  try {
    return mox.JID.fromString(trimmed).toBare().toString().toLowerCase();
  } on Exception {
    return trimmed.toLowerCase();
  }
}

String? _normalizeMucRoomJidCandidate(String? jid) {
  final normalized = _normalizeBareJidValue(jid);
  if (normalized == null) return null;
  try {
    final parsed = mox.JID.fromString(normalized);
    if (parsed.local.isEmpty) return null;
    return parsed.toBare().toString();
  } on Exception {
    return null;
  }
}

bool _hasInvalidArchiveOrigin(mox.MessageEvent event, String? accountJid) {
  final normalizedAccount = _normalizeBareJidValue(accountJid);
  if (normalizedAccount == null) return false;
  if (event.isCarbon) {
    final fromBare = _normalizeBareJidValue(event.from.toBare().toString());
    if (fromBare == null || fromBare != normalizedAccount) {
      return true;
    }
  }
  if (!event.isFromMAM) return false;
  final fromBare = _normalizeBareJidValue(event.from.toBare().toString());
  final toBare = _normalizeBareJidValue(event.to.toBare().toString());
  final bool isGroupChat = event.type == _messageTypeGroupchat;
  if (isGroupChat) {
    return toBare == null || toBare != normalizedAccount;
  }
  if (fromBare == null && toBare == null) return true;
  return fromBare != normalizedAccount && toBare != normalizedAccount;
}

Future<bool> _isBlockedInboundSender(
  mox.MessageEvent event,
  Future<bool> Function(String jid) isJidBlocked,
  String? accountJid,
) async {
  if (event.type == _messageTypeGroupchat) {
    return false;
  }
  final fromBare = _normalizeBareJidValue(event.from.toBare().toString());
  if (fromBare == null) {
    return false;
  }
  final accountBare = _normalizeBareJidValue(accountJid);
  if (accountBare != null && fromBare == accountBare) {
    return false;
  }
  return isJidBlocked(fromBare);
}

String? _normalizePinJid(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  try {
    return mox.JID.fromString(trimmed).toBare().toString().toLowerCase();
  } on Exception {
    return trimmed.toLowerCase();
  }
}

String? _normalizePinChatJid(String raw) => _normalizePinJid(raw);

String? _normalizePinPublisherJid(String raw) => _normalizePinJid(raw);

String _encodePinChatJid(String chatJid) {
  final bytes = utf8.encode(chatJid);
  final encoded = base64Url.encode(bytes);
  return encoded.replaceAll(_pinBase64PaddingPattern, '');
}

String? _decodePinChatJid(String encoded) {
  final trimmed = encoded.trim();
  if (trimmed.isEmpty) return null;
  var normalized = trimmed;
  final paddingRemainder = normalized.length % _pinBase64Quantum;
  if (paddingRemainder != 0) {
    final paddingLength = _pinBase64Quantum - paddingRemainder;
    normalized = '$normalized${_pinBase64PaddingChar * paddingLength}';
  }
  try {
    final bytes = base64Url.decode(normalized);
    final decoded = utf8.decode(bytes);
    return _normalizePinChatJid(decoded);
  } on FormatException {
    return null;
  }
}

String? _pinNodeForChat(String chatJid) {
  final normalized = _normalizePinChatJid(chatJid);
  if (normalized == null) return null;
  final encoded = _encodePinChatJid(normalized);
  return '$_pinPubSubNodePrefix$encoded';
}

String? _chatJidFromPinNode(String nodeId) {
  if (!nodeId.startsWith(_pinPubSubNodePrefix)) return null;
  final encoded = nodeId.substring(_pinPubSubNodePrefix.length);
  return _decodePinChatJid(encoded);
}

enum _PinNodePolicy {
  shared,
  restricted,
}

final class _PinNodeContext {
  const _PinNodeContext({
    required this.policy,
    required this.chat,
    this.affiliations,
  });

  final _PinNodePolicy policy;
  final Chat? chat;
  final Map<String, mox.PubSubAffiliation>? affiliations;
}

final class _PinNodeConfigResult {
  const _PinNodeConfigResult({
    required this.host,
    required this.policy,
  });

  final mox.JID host;
  final _PinNodePolicy policy;
}

mox.AccessModel _pinAccessModelForPolicy(_PinNodePolicy policy) =>
    switch (policy) {
      _PinNodePolicy.restricted => _pinAccessModelRestricted,
      _PinNodePolicy.shared => _pinAccessModelOpen,
    };

String _pinPublishModelForPolicy(_PinNodePolicy policy) => switch (policy) {
      _PinNodePolicy.restricted => _pinPublishModelPublishers,
      _PinNodePolicy.shared => _pinPublishModelOpen,
    };

AxiPubSubNodeConfig _pinNodeConfig(_PinNodePolicy policy) =>
    AxiPubSubNodeConfig(
      accessModel: _pinAccessModelForPolicy(policy),
      publishModel: _pinPublishModelForPolicy(policy),
      deliverNotifications: _pinDeliverNotificationsEnabled,
      deliverPayloads: _pinDeliverPayloadsEnabled,
      maxItems: _pinSyncMaxItemsValue,
      notifyRetract: _pinNotifyEnabled,
      notifyDelete: _pinNotifyEnabled,
      notifyConfig: _pinNotifyEnabled,
      notifySub: _pinNotifyEnabled,
      presenceBasedDelivery: _pinPresenceBasedDeliveryDisabled,
      persistItems: _pinPersistItemsEnabled,
      sendLastPublishedItem: _pinSendLastOnSubscribe,
    );

mox.NodeConfig _pinCreateNodeConfig(_PinNodePolicy policy) =>
    _pinNodeConfig(policy).toNodeConfig();

mox.PubSubPublishOptions _pinPublishOptions(_PinNodePolicy policy) =>
    mox.PubSubPublishOptions(
      accessModel: _pinAccessModelForPolicy(policy).value,
      maxItems: _pinSyncMaxItemsValue,
      persistItems: _pinPersistItemsEnabled,
      publishModel: _pinPublishModelForPolicy(policy),
      sendLastPublishedItem: _pinSendLastOnSubscribe,
    );

final class _PinnedMessageSyncPayload {
  const _PinnedMessageSyncPayload({
    required this.messageStanzaId,
    required this.chatJid,
    required this.pinnedAt,
  });

  final String messageStanzaId;
  final String chatJid;
  final DateTime pinnedAt;

  String get itemId => messageStanzaId;

  static _PinnedMessageSyncPayload? fromXml(
    mox.XMLNode node, {
    required String chatJid,
    String? itemId,
  }) {
    if (node.tag != _pinTag) return null;
    if (node.attributes['xmlns']?.toString() != _pinPubSubNamespace) {
      return null;
    }
    final rawMessageId = node.attributes[_pinMessageIdAttr]?.toString().trim();
    final resolvedMessageId = rawMessageId == null || rawMessageId.isEmpty
        ? itemId?.trim()
        : rawMessageId;
    if (resolvedMessageId == null || resolvedMessageId.isEmpty) {
      return null;
    }
    final rawPinnedAt = node.attributes[_pinPinnedAtAttr]?.toString().trim();
    if (rawPinnedAt == null || rawPinnedAt.isEmpty) {
      return null;
    }
    final parsedPinnedAt = DateTime.tryParse(rawPinnedAt);
    if (parsedPinnedAt == null) return null;
    final normalizedChat = _normalizePinChatJid(chatJid);
    if (normalizedChat == null) return null;
    final rawChat = node.attributes[_pinChatJidAttr]?.toString().trim();
    if (rawChat != null && rawChat.isNotEmpty) {
      final normalizedRawChat = _normalizePinChatJid(rawChat);
      if (normalizedRawChat != null && normalizedRawChat != normalizedChat) {
        return null;
      }
    }
    return _PinnedMessageSyncPayload(
      messageStanzaId: resolvedMessageId,
      chatJid: normalizedChat,
      pinnedAt: parsedPinnedAt.toUtc(),
    );
  }

  mox.XMLNode toXml() {
    return mox.XMLNode.xmlns(
      tag: _pinTag,
      xmlns: _pinPubSubNamespace,
      attributes: {
        _pinMessageIdAttr: messageStanzaId,
        _pinChatJidAttr: chatJid,
        _pinPinnedAtAttr: pinnedAt.toUtc().toIso8601String(),
      },
    );
  }
}

class MamPageResult {
  const MamPageResult({
    required this.complete,
    this.firstId,
    this.lastId,
    this.count,
  });

  final bool complete;
  final String? firstId;
  final String? lastId;
  final int? count;
}

enum MamGlobalSyncOutcome {
  completed,
  skippedUnsupported,
  skippedDenied,
  skippedInFlight,
  skippedResumed,
  failed;
}

extension MamGlobalSyncOutcomeBehavior on MamGlobalSyncOutcome {
  bool get shouldFallbackToPerChat => switch (this) {
        MamGlobalSyncOutcome.failed => true,
        MamGlobalSyncOutcome.skippedDenied => true,
        MamGlobalSyncOutcome.completed => false,
        MamGlobalSyncOutcome.skippedUnsupported => false,
        MamGlobalSyncOutcome.skippedInFlight => false,
        MamGlobalSyncOutcome.skippedResumed => false,
      };
}

final _capabilityCacheKey =
    XmppStateStore.registerKey('message_peer_capabilities');
const String _mamGlobalLastIdKeyName = 'mam_global_last_id';
const String _mamGlobalLastSyncKeyName = 'mam_global_last_sync';
const String _mamGlobalDeniedUntilKeyName = 'mam_global_denied_until';
final _mamGlobalLastIdKey = XmppStateStore.registerKey(_mamGlobalLastIdKeyName);
final _mamGlobalLastSyncKey =
    XmppStateStore.registerKey(_mamGlobalLastSyncKeyName);
final _mamGlobalDeniedUntilKey =
    XmppStateStore.registerKey(_mamGlobalDeniedUntilKeyName);
const String _mamGlobalScopeFallback = 'default';
const String _mamGlobalScopeSeparator = ':';
final Map<String, RegisteredStateKey> _mamGlobalScopedKeyCache = {};
const Duration _httpUploadSlotTimeout = Duration(seconds: 30);
const Duration _httpUploadPutTimeout = Duration(minutes: 2);
const Duration _httpAttachmentGetTimeout = Duration(minutes: 2);
const int _xmppAttachmentDownloadLimitFallbackBytes = 50 * 1024 * 1024;
const int _xmppAttachmentDownloadMaxRedirects = 5;
const int _aesGcmTagLengthBytes = 16;
const int _attachmentMaxFilenameLength = 120;
const int _attachmentMaxUrlLength = 2048;
const int _attachmentMaxMimeTypeLength = 128;
const int _attachmentSourceMaxCount = 8;
const String _attachmentFallbackName = 'attachment';
const int _attachmentSizeFallbackBytes = 0;
const int _attachmentCacheEmptyByteCount = 0;
const int _attachmentCacheMaxBytes = 256 * 1024 * 1024;
const String _attachmentCacheTempPrefix = '.';
const bool _attachmentCacheFollowLinks = false;
const String _attachmentCacheSessionPrefixLabel = 'session';
const String _attachmentCacheSessionPrefixSeparator = '_';
const Duration _inboundAttachmentAutoDownloadRateLimitWindow =
    Duration(minutes: 1);
const Duration _inboundAttachmentAutoDownloadRateLimitCleanupInterval =
    Duration(minutes: 5);
const int _inboundAttachmentAutoDownloadMaxEventsPerChat = 30;
const int _inboundAttachmentAutoDownloadMaxEventsGlobal = 120;
const WindowRateLimit _inboundAttachmentAutoDownloadPerChatRateLimit =
    WindowRateLimit(
  maxEvents: _inboundAttachmentAutoDownloadMaxEventsPerChat,
  window: _inboundAttachmentAutoDownloadRateLimitWindow,
);
const WindowRateLimit _inboundAttachmentAutoDownloadGlobalRateLimit =
    WindowRateLimit(
  maxEvents: _inboundAttachmentAutoDownloadMaxEventsGlobal,
  window: _inboundAttachmentAutoDownloadRateLimitWindow,
);
const int serverOnlyChatMessageCap = 500;
const int mamLoginBackfillMessageLimit = 50;
const int _emptyMessageCount = 0;
const Duration _mamGlobalDeniedBackoff = Duration(minutes: 5);
const int _calendarMamPageSize = 100;
const int _calendarSnapshotDownloadMaxBytes =
    CalendarSnapshotCodec.maxCompressedBytes;
const Duration _calendarSyncInboundWindow = Duration(seconds: 60);
const int _calendarSyncInboundMaxMessages = 120;
const String _calendarSnapshotDefaultName =
    'calendar_snapshot${CalendarSnapshotCodec.fileExtension}';
const String _calendarSnapshotNoJidMessage =
    'Attempted to upload a snapshot before a JID was bound.';
const String _calendarSnapshotMissingFileMessage = 'Snapshot missing on disk.';
const String _calendarSnapshotInvalidFileMessage = 'Snapshot file invalid.';
const String _calendarSnapshotUploadFailedMessage =
    'Failed to upload calendar snapshot';
const String _calendarSnapshotDecodeFailedMessage =
    'Failed to decode snapshot attachment';
const String _calendarSnapshotChecksumFailedMessage =
    'Snapshot checksum verification failed';
const String _calendarSnapshotChecksumMismatchMessage =
    'Snapshot checksum mismatch';
const String _calendarSnapshotFallbackRequestFailedMessage =
    'Failed to request calendar snapshot fallback';
const Set<String> _safeHttpUploadLogHeaders = {
  HttpHeaders.contentLengthHeader,
  HttpHeaders.contentTypeHeader,
};
const Set<String> _allowedHttpUploadPutHeaders = {
  'authorization',
  'cookie',
  'expires',
};

class _PeerCapabilities {
  const _PeerCapabilities({
    required this.supportsMarkers,
    required this.supportsReceipts,
  });

  final bool supportsMarkers;
  final bool supportsReceipts;

  Map<String, Object> toJson() => {
        'markers': supportsMarkers,
        'receipts': supportsReceipts,
      };

  static _PeerCapabilities fromJson(Map<dynamic, dynamic> json) =>
      _PeerCapabilities(
        supportsMarkers: json['markers'] as bool? ?? false,
        supportsReceipts: json['receipts'] as bool? ?? false,
      );

  static const empty = _PeerCapabilities(
    supportsMarkers: false,
    supportsReceipts: false,
  );

  static const supportsAll = _PeerCapabilities(
    supportsMarkers: true,
    supportsReceipts: true,
  );
}

class XmppAttachmentUpload {
  const XmppAttachmentUpload._({
    required this.metadata,
    required this.getUrl,
    required String putUrl,
    required List<XmppUploadHeader> headers,
    required String contentType,
    required int sizeBytes,
    required File file,
  })  : _putUrl = putUrl,
        _headers = headers,
        _contentType = contentType,
        _sizeBytes = sizeBytes,
        _file = file;

  final FileMetadataData metadata;
  final String getUrl;
  final String _putUrl;
  final List<XmppUploadHeader> _headers;
  final String _contentType;
  final int _sizeBytes;
  final File _file;
}

class XmppUploadHeader {
  const XmppUploadHeader({
    required this.name,
    required this.value,
  });

  final String name;
  final String value;
}

mixin MessageService
    on
        XmppBase,
        BaseStreamService,
        MucService,
        ChatsService,
        DraftSyncService,
        BlockingService {
  ImpatientCompleter<XmppDatabase> get _database;

  set _database(ImpatientCompleter<XmppDatabase> value);

  String? get _databasePrefix;

  String? get _databasePassphrase;

  Future<XmppDatabase> _buildDatabase(String prefix, String passphrase);

  void _notifyDatabaseReloaded();

  Stream<List<Message>> messageStreamForChat(
    String jid, {
    int start = 0,
    int end = 50,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
  }) {
    List<Message> filteredMessagesForChat(
      List<Message> messages,
    ) {
      final filtered = messages.where((message) {
        return !_isInternalSyncEnvelope(message.body);
      }).toList(growable: false);

      return List<Message>.unmodifiable(filtered);
    }

    return _localMessageStreamForChat(
      jid: jid,
      start: start,
      end: end,
      filter: filter,
    ).map(filteredMessagesForChat);
  }

  bool _isInternalSyncEnvelope(String? body) {
    final trimmed = body?.trim();
    if (trimmed == null || trimmed.isEmpty) return false;
    return CalendarSyncMessage.isCalendarSyncEnvelope(trimmed) ||
        CalendarSyncMessage.looksLikeEnvelope(trimmed) ||
        _MessageStatusSyncEnvelope.isEnvelope(trimmed);
  }

  Stream<List<Message>> _localMessageStreamForChat({
    required String jid,
    required int start,
    required int end,
    required MessageTimelineFilter filter,
  }) {
    return createSingleItemStream<List<Message>, XmppDatabase>(
      watchFunction: (db) async {
        final messagesStream = db.watchChatMessages(
          jid,
          start: start,
          end: end,
          filter: filter,
        );
        final reactionsStream = db.watchReactionsForChat(jid);
        final initialMessages = await db.getChatMessages(
          jid,
          start: start,
          end: end,
          filter: filter,
        );
        final initialReactions = await db.getReactionsForChat(jid);
        return _combineMessageAndReactionStreams(
          messageStream: messagesStream,
          reactionStream: reactionsStream,
          initialMessages: initialMessages,
          initialReactions: initialReactions,
        );
      },
    );
  }

  Future<void> _storeMessage(
    Message message, {
    required ChatType chatType,
  }) async {
    await _dbOp<XmppDatabase>((db) async {
      await db.saveMessage(
        message,
        chatType: chatType,
      );
      if (messageStorageMode.isServerOnly) {
        await db.trimChatMessages(
          jid: message.chatJid,
          maxMessages: serverOnlyChatMessageCap,
        );
      }
    });
  }

  Future<int> countLocalMessages({
    required String jid,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
    bool includePseudoMessages = true,
  }) async {
    return _dbOpReturning<XmppDatabase, int>(
      (db) => db.countChatMessages(
        jid,
        filter: filter,
        includePseudoMessages: includePseudoMessages,
      ),
    );
  }

  MessageStorageMode get messageStorageMode =>
      _messageStorageMode.isServerOnly && !_mamSupported
          ? MessageStorageMode.local
          : _messageStorageMode;

  void updateMessageStorageMode(MessageStorageMode mode) {
    final previous = messageStorageMode;
    _messageStorageMode = mode;
    final next = messageStorageMode;
    if (mode.isServerOnly && !_mamSupported) {
      _log.warning(
        'Server-only storage requires MAM; using local persistence instead.',
      );
    }
    if (previous == next) return;
    unawaited(
      _applyMessageStorageModeChange(
        previous: previous,
        next: next,
      ),
    );
  }

  Future<void> _applyMessageStorageModeChange({
    required MessageStorageMode previous,
    required MessageStorageMode next,
  }) async {
    _log.info('Message storage mode change: $previous -> $next');
    if (next.isServerOnly) {
      await purgeMessageHistory();
    }
    await _reopenDatabaseForStorageMode(
      previous: previous,
      next: next,
    );
  }

  Future<void> _reopenDatabaseForStorageMode({
    required MessageStorageMode previous,
    required MessageStorageMode next,
  }) async {
    if (!_database.isCompleted) return;
    final currentDb = _database.value;
    final wantsInMemory = next.isServerOnly && _mamSupported;
    final isCurrentInMemory =
        currentDb is XmppDrift ? currentDb.isInMemory : false;
    if (wantsInMemory == isCurrentInMemory) return;
    _log.info(
      'Reopening database for storage mode change '
      '($previous -> $next); inMemoryTarget=$wantsInMemory',
    );
    final prefix = _databasePrefix;
    final passphrase = _databasePassphrase;
    if (prefix == null || passphrase == null) {
      _log.warning(
        'Unable to reopen database for storage mode change; missing prefix or passphrase.',
      );
      return;
    }
    try {
      await currentDb?.close();
    } catch (error, stackTrace) {
      _log.warning(
        'Failed to close existing database during storage mode change.',
        error,
        stackTrace,
      );
    }
    _database = ImpatientCompleter(Completer<XmppDatabase>());
    _database.complete(await _buildDatabase(prefix, passphrase));
    _notifyDatabaseReloaded();
  }

  void _updateMamSupport(bool supported) {
    if (_mamSupported == supported) return;
    final previousEffective = messageStorageMode;
    _mamSupported = supported;
    if (!_mamSupportController.isClosed) {
      _mamSupportController.add(supported);
    }
    final nextEffective = messageStorageMode;
    if (previousEffective != nextEffective) {
      unawaited(
        _applyMessageStorageModeChange(
          previous: previousEffective,
          next: nextEffective,
        ),
      );
    }
  }

  @visibleForTesting
  void setMamSupportOverride(bool? supported) {
    _mamSupportOverride = supported;
    if (supported != null) {
      _updateMamSupport(supported);
    }
  }

  Future<void> purgeMessageHistory({bool awaitDatabase = true}) async {
    _resetStableKeyCache();
    await _dbOp<XmppDatabase>(
      (db) => db.clearMessageHistory(),
      awaitDatabase: awaitDatabase,
    );
  }

  void _resetStableKeyCache() {
    _seenStableKeys.clear();
    _stableKeyOrder.clear();
  }

  String? _stableKeyForEvent(mox.MessageEvent event) {
    final stableIdData = event.extensions.get<mox.StableIdData>();
    final stanzaIds = stableIdData?.stanzaIds;
    if (stanzaIds != null && stanzaIds.isNotEmpty) {
      final stanza = stanzaIds.first;
      return 'sid:${stanza.id}@${stanza.by.toBare()}';
    }
    if (stableIdData?.originId case final origin?) {
      return 'oid:$origin';
    }
    if (event.id != null) {
      return 'mid:${event.id}-${event.from.toBare()}';
    }
    return null;
  }

  bool _stableKeySeen(String chatJid, String key) =>
      _seenStableKeys[chatJid]?.contains(key) ?? false;

  void _rememberStableKey(String chatJid, String key) {
    final seen = _seenStableKeys.putIfAbsent(chatJid, () => <String>{});
    final order = _stableKeyOrder.putIfAbsent(chatJid, () => Queue<String>());
    if (seen.contains(key)) return;
    seen.add(key);
    order.addLast(key);
    if (order.length > _stableKeyLimit) {
      final evicted = order.removeFirst();
      seen.remove(evicted);
    }
  }

  Future<bool> _isDuplicate(
    Message message,
    mox.MessageEvent event, {
    String? stableKey,
  }) async {
    final chatJid = message.chatJid;
    if (stableKey != null && _stableKeySeen(chatJid, stableKey)) {
      return true;
    }
    if (message.originID != null) {
      final existing = await _dbOpReturning<XmppDatabase, Message?>(
        (db) => db.getMessageByOriginID(message.originID!),
      );
      if (existing != null) return true;
    }
    final existing = await _dbOpReturning<XmppDatabase, Message?>(
      (db) => db.getMessageByStanzaID(message.stanzaID),
    );
    return existing != null;
  }

  Future<void> _hydrateDuplicatePayload({
    required Message incoming,
    FileMetadataData? metadata,
    String? body,
  }) async {
    final hasText = body?.trim().isNotEmpty == true;
    await _dbOp<XmppDatabase>((db) async {
      Message? existing;
      if (incoming.originID?.isNotEmpty == true) {
        existing = await db.getMessageByOriginID(incoming.originID!);
      }
      existing ??= await db.getMessageByStanzaID(incoming.stanzaID);
      if (existing == null) return;

      final shouldUpdateDisplayed = incoming.displayed && !existing.displayed;
      final shouldUpdateReceived =
          (incoming.received || shouldUpdateDisplayed) && !existing.received;
      final shouldUpdateAcked =
          (incoming.acked || shouldUpdateReceived) && !existing.acked;

      final needsMetadata = metadata != null &&
          (existing.fileMetadataID == null || existing.fileMetadataID!.isEmpty);
      final needsBody =
          hasText && (existing.body == null || existing.body!.isEmpty);
      if (!needsMetadata &&
          !needsBody &&
          !shouldUpdateAcked &&
          !shouldUpdateReceived &&
          !shouldUpdateDisplayed) {
        return;
      }

      await db.updateMessageAttachment(
        stanzaID: existing.stanzaID,
        metadata: needsMetadata ? metadata : null,
        body: needsBody ? body : null,
      );

      if (shouldUpdateDisplayed) {
        await db.markMessageDisplayed(incoming.originID ?? incoming.stanzaID);
      }
      if (shouldUpdateReceived) {
        await db.markMessageReceived(incoming.originID ?? incoming.stanzaID);
      }
      if (shouldUpdateAcked) {
        await db.markMessageAcked(incoming.originID ?? incoming.stanzaID);
      }
    });
  }

  RegisteredStateKey _lastSeenKeyFor(String jid) => _lastSeenKeys.putIfAbsent(
        jid,
        () => XmppStateStore.registerKey('mam_last_seen_$jid'),
      );

  Future<void> _recordLastSeenTimestamp(
    String chatJid,
    DateTime? timestamp,
  ) async {
    if (timestamp == null) return;
    final key = _lastSeenKeyFor(chatJid);
    await _dbOp<XmppStateStore>(
      (ss) async {
        final raw = ss.read(key: key) as String?;
        final existing = raw == null ? null : DateTime.tryParse(raw);
        if (existing != null && !timestamp.isAfter(existing)) {
          return;
        }
        await ss.write(
          key: key,
          value: timestamp.toIso8601String(),
        );
      },
      awaitDatabase: true,
    );
  }

  Future<DateTime?> loadLastSeenTimestamp(String chatJid) async {
    return await _dbOpReturning<XmppStateStore, DateTime?>(
      (ss) {
        final raw = ss.read(key: _lastSeenKeyFor(chatJid)) as String?;
        return raw == null ? null : DateTime.tryParse(raw);
      },
    );
  }

  String _mamScopeToken() {
    final prefix = _databasePrefix?.trim();
    if (prefix != null && prefix.isNotEmpty) {
      return _hashMamScope(prefix);
    }
    final jid = myJid?.trim();
    if (jid != null && jid.isNotEmpty) {
      return _hashMamScope(jid);
    }
    return _mamGlobalScopeFallback;
  }

  String _hashMamScope(String value) {
    final bytes = utf8.encode(value);
    return crypto.sha256.convert(bytes).toString();
  }

  RegisteredStateKey _mamScopedKey(String baseName) {
    final scope = _mamScopeToken();
    final scopedName = '$baseName$_mamGlobalScopeSeparator$scope';
    return _mamGlobalScopedKeyCache.putIfAbsent(
      scopedName,
      () => XmppStateStore.registerKey(scopedName),
    );
  }

  Future<String?> _readMamScopedString({
    required String baseName,
    required RegisteredStateKey legacyKey,
  }) async {
    final scopedKey = _mamScopedKey(baseName);
    final scoped = await _dbOpReturning<XmppStateStore, String?>(
      (ss) => ss.read(key: scopedKey) as String?,
    );
    final normalizedScoped = scoped?.trim();
    if (normalizedScoped != null && normalizedScoped.isNotEmpty) {
      return normalizedScoped;
    }
    final legacy = await _dbOpReturning<XmppStateStore, String?>(
      (ss) => ss.read(key: legacyKey) as String?,
    );
    final normalizedLegacy = legacy?.trim();
    if (normalizedLegacy == null || normalizedLegacy.isEmpty) {
      return null;
    }
    await _dbOp<XmppStateStore>(
      (ss) async {
        await ss.write(key: scopedKey, value: normalizedLegacy);
        await ss.delete(key: legacyKey);
      },
      awaitDatabase: true,
    );
    return normalizedLegacy;
  }

  Future<DateTime?> _readMamScopedTimestamp({
    required String baseName,
    required RegisteredStateKey legacyKey,
  }) async {
    final raw = await _readMamScopedString(
      baseName: baseName,
      legacyKey: legacyKey,
    );
    if (raw == null) {
      return null;
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) {
      return parsed;
    }
    final scopedKey = _mamScopedKey(baseName);
    await _dbOp<XmppStateStore>(
      (ss) async => ss.delete(key: scopedKey),
      awaitDatabase: true,
    );
    return null;
  }

  Future<String?> _loadMamGlobalLastId() async {
    return await _readMamScopedString(
      baseName: _mamGlobalLastIdKeyName,
      legacyKey: _mamGlobalLastIdKey,
    );
  }

  Future<void> _storeMamGlobalLastId(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    final scopedKey = _mamScopedKey(_mamGlobalLastIdKeyName);
    await _dbOp<XmppStateStore>(
      (ss) async {
        await ss.write(key: scopedKey, value: trimmed);
        await ss.delete(key: _mamGlobalLastIdKey);
      },
      awaitDatabase: true,
    );
  }

  Future<DateTime?> _loadMamGlobalLastSync() async {
    return await _readMamScopedTimestamp(
      baseName: _mamGlobalLastSyncKeyName,
      legacyKey: _mamGlobalLastSyncKey,
    );
  }

  Future<void> _storeMamGlobalLastSync(DateTime timestamp) async {
    final scopedKey = _mamScopedKey(_mamGlobalLastSyncKeyName);
    await _dbOp<XmppStateStore>(
      (ss) async {
        await ss.write(
          key: scopedKey,
          value: timestamp.toUtc().toIso8601String(),
        );
        await ss.delete(key: _mamGlobalLastSyncKey);
      },
      awaitDatabase: true,
    );
  }

  Future<DateTime?> _loadMamGlobalDeniedUntil() async {
    final scope = _mamScopeToken();
    if (_mamGlobalDeniedUntilLoaded && _mamGlobalDeniedUntilScope == scope) {
      return _mamGlobalDeniedUntil;
    }
    _mamGlobalDeniedUntilScope = scope;
    final loaded = await _readMamScopedTimestamp(
      baseName: _mamGlobalDeniedUntilKeyName,
      legacyKey: _mamGlobalDeniedUntilKey,
    );
    _mamGlobalDeniedUntil = loaded;
    _mamGlobalDeniedUntilLoaded = true;
    return loaded;
  }

  Future<void> _storeMamGlobalDeniedUntil(DateTime? until) async {
    final scope = _mamScopeToken();
    _mamGlobalDeniedUntilScope = scope;
    _mamGlobalDeniedUntilLoaded = true;
    _mamGlobalDeniedUntil = until;
    final scopedKey = _mamScopedKey(_mamGlobalDeniedUntilKeyName);
    await _dbOp<XmppStateStore>(
      (ss) async {
        if (until == null) {
          await ss.delete(key: scopedKey);
          await ss.delete(key: _mamGlobalDeniedUntilKey);
          return;
        }
        await ss.write(
          key: scopedKey,
          value: until.toUtc().toIso8601String(),
        );
        await ss.delete(key: _mamGlobalDeniedUntilKey);
      },
      awaitDatabase: true,
    );
  }

  Future<List<Message>> searchChatMessages({
    required String jid,
    String? query,
    String? subject,
    bool excludeSubject = false,
    MessageTimelineFilter filter = MessageTimelineFilter.directOnly,
    SearchSortOrder sortOrder = SearchSortOrder.newestFirst,
    int limit = 200,
  }) async {
    final trimmed = query?.trim() ?? '';
    final trimmedSubject = subject?.trim() ?? '';
    if (trimmed.isEmpty && trimmedSubject.isEmpty) return const [];
    return await _dbOpReturning<XmppDatabase, List<Message>>(
      (db) => db.searchChatMessages(
        jid: jid,
        query: trimmed,
        subject: trimmedSubject,
        excludeSubject: excludeSubject,
        filter: filter,
        limit: limit,
        ascending: sortOrder == SearchSortOrder.oldestFirst,
      ),
    );
  }

  Future<List<String>> subjectsForChat(String jid) async =>
      await _dbOpReturning<XmppDatabase, List<String>>(
        (db) => db.subjectsForChat(jid),
      );

  Stream<List<Draft>> draftsStream({
    int start = 0,
    int end = basePageItemLimit,
  }) =>
      createPaginatedStream<Draft, XmppDatabase>(
        watchFunction: (db) async => db.watchDrafts(start: start, end: end),
        getFunction: (db) => db.getDrafts(start: start, end: end),
      );

  Stream<List<PinnedMessageEntry>> pinnedMessagesStream(String chatJid) =>
      createPaginatedStream<PinnedMessageEntry, XmppDatabase>(
        watchFunction: (db) async => db.watchPinnedMessages(chatJid),
        getFunction: (db) => db.getPinnedMessages(chatJid),
      );

  String? _selfBareJid() {
    final selfJid = myJid?.trim();
    if (selfJid == null || selfJid.isEmpty) {
      return null;
    }
    try {
      return mox.JID.fromString(selfJid).toBare().toString();
    } on Exception {
      return selfJid;
    }
  }

  Map<String, mox.PubSubAffiliation>? _basePinAffiliations() {
    final selfBare = _selfBareJid();
    if (selfBare == null || selfBare.isEmpty) {
      return null;
    }
    return <String, mox.PubSubAffiliation>{selfBare: _pinAffiliationOwner};
  }

  Map<String, mox.PubSubAffiliation>? _pinDirectAffiliations(Chat chat) {
    final affiliations = _basePinAffiliations();
    if (affiliations == null) {
      return null;
    }
    final peerJid = chat.remoteJid.trim();
    if (peerJid.isEmpty) {
      return null;
    }
    affiliations[peerJid] = _pinAffiliationPublisher;
    return affiliations;
  }

  int _appendPinAffiliations(
    Map<String, mox.PubSubAffiliation> affiliations,
    List<MucAffiliationEntry> entries,
  ) {
    var added = 0;
    for (final entry in entries) {
      final jid = entry.jid?.trim();
      if (jid == null || jid.isEmpty) {
        continue;
      }
      if (affiliations.containsKey(jid)) {
        continue;
      }
      affiliations[jid] = _pinAffiliationPublisher;
      added += 1;
    }
    return added;
  }

  Future<Map<String, mox.PubSubAffiliation>?> _pinGroupAffiliations(
    Chat chat,
  ) async {
    final affiliations = _basePinAffiliations();
    if (affiliations == null) {
      return null;
    }
    final roomJid = chat.jid.trim();
    if (roomJid.isEmpty) {
      return null;
    }
    try {
      final members = await fetchRoomMembers(roomJid: roomJid);
      final admins = await fetchRoomAdmins(roomJid: roomJid);
      final owners = await fetchRoomOwners(roomJid: roomJid);
      final entries = <MucAffiliationEntry>[
        ...members,
        ...admins,
        ...owners,
      ];
      final added = _appendPinAffiliations(affiliations, entries);
      if (added == 0) {
        return null;
      }
      return affiliations;
    } on Exception {
      return null;
    }
  }

  Future<_PinNodeContext> _resolvePinNodeContext(String chatJid) async {
    final chat = await _dbOpReturning<XmppDatabase, Chat?>(
      (db) => db.getChat(chatJid),
    );
    if (chat == null) {
      return _PinNodeContext(
        policy: _PinNodePolicy.restricted,
        chat: null,
        affiliations: _basePinAffiliations(),
      );
    }
    if (chat.isEmailBacked) {
      return _PinNodeContext(
        policy: _PinNodePolicy.restricted,
        chat: chat,
        affiliations: _basePinAffiliations(),
      );
    }
    if (chat.type == ChatType.groupChat) {
      final affiliations = await _pinGroupAffiliations(chat);
      return _PinNodeContext(
        policy: _PinNodePolicy.restricted,
        chat: chat,
        affiliations: affiliations,
      );
    }
    final affiliations = _pinDirectAffiliations(chat);
    return _PinNodeContext(
      policy: _PinNodePolicy.restricted,
      chat: chat,
      affiliations: affiliations,
    );
  }

  Set<String> _normalizePinPublishers(Iterable<String> publishers) {
    final normalized = <String>{};
    for (final publisher in publishers) {
      final resolved = _normalizePinPublisherJid(publisher);
      if (resolved != null) {
        normalized.add(resolved);
      }
    }
    return normalized;
  }

  Set<String> _pinAuthorizedPublishersFromContext(_PinNodeContext context) {
    final candidates = <String>[];
    final selfBare = _selfBareJid();
    if (selfBare != null && selfBare.isNotEmpty) {
      candidates.add(selfBare);
    }
    final chat = context.chat;
    if (chat != null &&
        !chat.isEmailBacked &&
        chat.type != ChatType.groupChat) {
      final peerJid = chat.remoteJid.trim();
      if (peerJid.isNotEmpty) {
        candidates.add(peerJid);
      }
    }
    final affiliations = context.affiliations;
    if (affiliations != null && affiliations.isNotEmpty) {
      candidates.addAll(affiliations.keys);
    }
    return _normalizePinPublishers(candidates);
  }

  void _cachePinAuthorizedPublishers(
    String chatJid,
    _PinNodeContext context,
  ) {
    final normalizedChat = _normalizePinChatJid(chatJid);
    if (normalizedChat == null) {
      return;
    }
    final publishers = _pinAuthorizedPublishersFromContext(context);
    if (publishers.isEmpty) {
      return;
    }
    _pinAuthorizedPublishersByChat[normalizedChat] = publishers;
  }

  Future<Set<String>?> _resolvePinAuthorizedPublishers(String chatJid) async {
    final normalizedChat = _normalizePinChatJid(chatJid);
    if (normalizedChat == null) {
      return null;
    }
    final cached = _pinAuthorizedPublishersByChat[normalizedChat];
    if (cached != null) {
      return cached;
    }
    final context = await _resolvePinNodeContext(normalizedChat);
    _cachePinAuthorizedPublishers(normalizedChat, context);
    return _pinAuthorizedPublishersByChat[normalizedChat];
  }

  bool _isPinPublisherAllowed({
    required Set<String>? allowedPublishers,
    required Set<String> pendingPublishes,
    required String messageStanzaId,
    required String? publisher,
  }) {
    if (pendingPublishes.contains(messageStanzaId)) {
      return true;
    }
    final rawPublisher = publisher?.trim();
    if (rawPublisher == null || rawPublisher.isEmpty) {
      return false;
    }
    final normalizedPublisher = _normalizePinPublisherJid(rawPublisher);
    if (normalizedPublisher == null) {
      return false;
    }
    if (allowedPublishers == null || allowedPublishers.isEmpty) {
      return false;
    }
    return allowedPublishers.contains(normalizedPublisher);
  }

  Future<bool> _isPinPublisherAuthorized({
    required String chatJid,
    required String messageStanzaId,
    required String? publisher,
  }) async {
    await _ensurePendingPinSyncLoaded();
    final pendingPublishes =
        _pendingPinPublishesByChat[chatJid] ?? _emptyPinPublisherSet;
    final allowedPublishers = await _resolvePinAuthorizedPublishers(chatJid);
    return _isPinPublisherAllowed(
      allowedPublishers: allowedPublishers,
      pendingPublishes: pendingPublishes,
      messageStanzaId: messageStanzaId,
      publisher: publisher,
    );
  }

  Future<void> pinMessage({
    required String chatJid,
    required Message message,
  }) async {
    final normalizedChat = _normalizePinChatJid(chatJid);
    final stanzaId = message.stanzaID.trim();
    if (normalizedChat == null || stanzaId.isEmpty) {
      return;
    }
    final pinnedAt = DateTime.timestamp().toUtc();
    await _dbOp<XmppDatabase>(
      (db) => db.upsertPinnedMessage(
        PinnedMessageEntry(
          messageStanzaId: stanzaId,
          chatJid: normalizedChat,
          pinnedAt: pinnedAt,
        ),
      ),
    );
    await _queuePinPublish(normalizedChat, stanzaId);
    await _flushPendingPinSyncForChat(normalizedChat);
  }

  Future<void> unpinMessage({
    required String chatJid,
    required Message message,
  }) async {
    final normalizedChat = _normalizePinChatJid(chatJid);
    final stanzaId = message.stanzaID.trim();
    if (normalizedChat == null || stanzaId.isEmpty) {
      return;
    }
    await _dbOp<XmppDatabase>(
      (db) => db.deletePinnedMessage(
        chatJid: normalizedChat,
        messageStanzaId: stanzaId,
      ),
    );
    await _queuePinRetraction(normalizedChat, stanzaId);
    await _flushPendingPinSyncForChat(normalizedChat);
  }

  Future<void> syncPinnedMessagesForChat(String chatJid) async {
    final normalizedChat = _normalizePinChatJid(chatJid);
    if (normalizedChat == null) {
      return;
    }
    if (_pinSyncInFlight.contains(normalizedChat)) {
      return;
    }
    if (!_connection.hasConnectionSettings) {
      return;
    }
    if (connectionState != ConnectionState.connected) {
      return;
    }
    final context = await _resolvePinNodeContext(normalizedChat);
    _cachePinAuthorizedPublishers(normalizedChat, context);
    _pinSyncInFlight.add(normalizedChat);
    try {
      await database;
      if (connectionState != ConnectionState.connected) {
        return;
      }
      await _ensurePendingPinSyncLoaded();
      final support = await refreshPubSubSupport();
      if (!support.pubSubSupported) {
        return;
      }
      final nodeConfig =
          await _ensurePinNodeForChat(normalizedChat, context: context);
      if (nodeConfig == null) {
        return;
      }
      final host = nodeConfig.host;
      final nodeId = _pinNodeForChat(normalizedChat);
      if (nodeId == null) {
        return;
      }
      await _subscribeToPins(host: host, nodeId: nodeId);
      await _flushPendingPinSyncForChat(normalizedChat);
      final snapshot = await _fetchPinSnapshot(
        host: host,
        nodeId: nodeId,
        chatJid: normalizedChat,
      );
      if (snapshot == null) {
        return;
      }
      await _applyPinSnapshot(
        chatJid: normalizedChat,
        items: snapshot,
      );
      await _flushPendingPinSyncForChat(normalizedChat);
    } on XmppAbortedException {
      return;
    } finally {
      _pinSyncInFlight.remove(normalizedChat);
    }
  }

  Future<void> _syncEmailPinnedMessagesOnReconnect() async {
    if (_emailPinSnapshotInFlight) {
      return;
    }
    if (!_connection.hasConnectionSettings) {
      return;
    }
    if (connectionState != ConnectionState.connected) {
      return;
    }
    _emailPinSnapshotInFlight = true;
    try {
      await database;
      if (connectionState != ConnectionState.connected) {
        return;
      }
      final support = await refreshPubSubSupport();
      if (!support.pubSubSupported) {
        return;
      }
      final emailChats = await _dbOpReturning<XmppDatabase, List<Chat>>(
        (db) => db.getDeltaChats(),
      );
      for (final chat in emailChats) {
        if (connectionState != ConnectionState.connected) {
          return;
        }
        if (!chat.isEmailBacked) {
          continue;
        }
        final chatJid = chat.jid.trim();
        if (chatJid.isEmpty) {
          continue;
        }
        await syncPinnedMessagesForChat(chatJid);
      }
    } on XmppAbortedException {
      return;
    } finally {
      _emailPinSnapshotInFlight = false;
    }
  }

  final _log = Logger('MessageService');

  final _messageStream = StreamController<Message>.broadcast();

  final Map<String, _OutboundMessageSummary> _outboundMessageSummaries =
      <String, _OutboundMessageSummary>{};
  final Map<String, String> _outboundGroupchatStanzaRooms = <String, String>{};

  static const _stableKeyLimit = 500;
  static const _mamDiscoChatLimit = 500;
  static const Duration _conversationIndexMutedForeverDuration =
      Duration(days: 3650);
  bool _mamLoginSyncInFlight = false;
  bool _mamGlobalSyncInFlight = false;
  DateTime? _mamGlobalSyncCompletedAt;
  bool _calendarMamRehydrateInFlight = false;
  bool _calendarMamSnapshotSeen = false;
  bool _calendarMamSnapshotUnavailableNotified = false;
  final Queue<DateTime> _calendarSyncInboundTimestamps = Queue<DateTime>();
  final Set<String> _mucMamUnsupportedRooms = {};
  final Set<String> _mucJoinMamSyncRooms = {};
  final Set<String> _mucJoinMamDeferredRooms = {};
  DateTime? _mamGlobalDeniedUntil;
  String? _mamGlobalDeniedUntilScope;
  bool _mamGlobalDeniedUntilLoaded = false;
  DateTime? _mamGlobalMaxTimestamp;

  final Map<String, Set<String>> _seenStableKeys = {};
  final Map<String, Queue<String>> _stableKeyOrder = {};
  final Map<String, RegisteredStateKey> _lastSeenKeys = {};
  MessageStorageMode _messageStorageMode = MessageStorageMode.local;
  bool _mamSupported = false;
  bool? _mamSupportOverride;
  final StreamController<bool> _mamSupportController =
      StreamController<bool>.broadcast();

  final Map<String, _PeerCapabilities> _capabilityCache = {};
  var _capabilityCacheLoaded = false;
  final Map<String, Map<String, String>> _readOnlyTaskOwnersByChat =
      <String, Map<String, String>>{};
  final Map<String, Future<String?>> _inboundAttachmentDownloads = {};
  Directory? _attachmentDirectory;
  String? _attachmentCacheSessionPrefix;
  final WindowRateLimiter _inboundAttachmentAutoDownloadGlobalLimiter =
      WindowRateLimiter(_inboundAttachmentAutoDownloadGlobalRateLimit);
  final KeyedWindowRateLimiter _inboundAttachmentAutoDownloadChatLimiter =
      KeyedWindowRateLimiter(
    limit: _inboundAttachmentAutoDownloadPerChatRateLimit,
    cleanupInterval: _inboundAttachmentAutoDownloadRateLimitCleanupInterval,
  );
  bool _pendingPinSyncLoaded = false;
  final Map<String, Set<String>> _pinAuthorizedPublishersByChat = {};
  final Map<String, Set<String>> _pendingPinPublishesByChat = {};
  final Map<String, Set<String>> _pendingPinRetractionsByChat = {};
  final SyncRateLimiter _pinSyncRateLimiter = SyncRateLimiter(pinSyncRateLimit);
  final Set<String> _pinSyncInFlight = {};
  bool _emailPinSnapshotInFlight = false;
  mox.JID? _pinPubSubHost;

  @override
  void configureEventHandlers(EventManager<mox.XmppEvent> manager) {
    super.configureEventHandlers(manager);
    manager
      ..registerHandler<mox.MessageEvent>((event) async {
        if (await _handleError(event)) return;
        if (_isOversizedMessage(event, _log)) return;
        if (_hasInvalidArchiveOrigin(event, myJid)) {
          if (event.isCarbon) {
            _log.warning(_carbonOriginRejectedLog);
          }
          if (event.isFromMAM) {
            _log.warning(_mamOriginRejectedLog);
          }
          return;
        }
        _trackMamGlobalAnchor(event);
        final accountJidValue = myJid?.toString();
        if (await _isBlockedInboundSender(
          event,
          isJidBlocked,
          accountJidValue,
        )) {
          return;
        }

        final reactionOnly = await _handleReactions(event);
        if (reactionOnly) return;

        final metadata = _extractFileMetadata(event);
        final hasAttachmentMetadata = metadata != null;

        var message = Message.fromMox(event, accountJid: myJid);
        final shouldPersistAttachment = metadata != null && !message.noStore;
        final isGroupChat = event.type == 'groupchat';
        final stableKey = _stableKeyForEvent(event);

        message = message.copyWith(
          timestamp: message.timestamp ?? DateTime.timestamp(),
        );
        final accountJid = myJid;
        if (accountJid != null &&
            !isGroupChat &&
            message.senderJid.toLowerCase() == accountJid.toLowerCase() &&
            (event.isCarbon || event.isFromMAM)) {
          message = message.copyWith(acked: true);
        }
        if (shouldPersistAttachment) {
          message = message.copyWith(fileMetadataID: metadata.id);
        }
        if (metadata != null && (message.body?.trim().isEmpty ?? true)) {
          const fallbackFilename = 'Attachment';
          final filename = metadata.filename.trim();
          final labelFilename =
              filename.isNotEmpty ? filename : fallbackFilename;
          final sizeBytes = metadata.sizeBytes ?? 0;
          message = message.copyWith(
            body: _attachmentLabel(labelFilename, sizeBytes),
          );
        }

        if (await _isDuplicate(message, event, stableKey: stableKey)) {
          _log.fine(
            'Dropping duplicate message for ${message.chatJid} (${message.stanzaID})',
          );
          await _hydrateDuplicatePayload(
            incoming: message,
            metadata: metadata,
            body: message.body,
          );
          return;
        }

        if (stableKey != null) {
          _rememberStableKey(message.chatJid, stableKey);
        }

        await _handleChatState(event, message.chatJid);

        if (await _handleCorrection(event, message.senderJid)) return;
        if (await _handleRetraction(event, message.senderJid)) return;

        if (await _handleMessageStatusSync(event)) return;
        if (await _handleCalendarSync(event, metadata: metadata)) return;
        if (_isInternalSyncEnvelope(message.body)) {
          unawaited(_acknowledgeMessage(event));
          return;
        }

        final hasInvite = event.get<DirectMucInviteData>() != null ||
            event.get<AxiMucInvitePayload>() != null;
        if (!event.displayable &&
            !hasInvite &&
            event.encryptionError == null &&
            !hasAttachmentMetadata) {
          return;
        }
        if (event.encryptionError is omemo.InvalidKeyExchangeSignatureError) {
          return;
        }

        unawaited(_acknowledgeMessage(event));

        if (shouldPersistAttachment) {
          await _dbOp<XmppDatabase>(
            (db) => db.saveFileMetadata(metadata),
          );
          message = message.copyWith(fileMetadataID: metadata.id);
        }

        await _handleFile(event, message.senderJid);

        if (event.get<mox.OmemoData>() case final data?) {
          final newRatchets = data.newRatchets.values.map((e) => e.length);
          final newCount = newRatchets.fold(0, (v, e) => v + e);
          final replacedRatchets =
              data.replacedRatchets.values.map((e) => e.length);
          final replacedCount = replacedRatchets.fold(0, (v, e) => v + e);
          final pseudoMessageData = {
            'ratchetsAdded': newRatchets.toList(),
            'ratchetsReplaced': replacedRatchets.toList(),
          };

          if (newCount > 0) {
            await _storeMessage(
              Message(
                stanzaID: _connection.generateId(),
                senderJid: myJid!.toString(),
                chatJid: message.chatJid,
                pseudoMessageType: PseudoMessageType.newDevice,
                pseudoMessageData: pseudoMessageData,
              ),
              chatType: isGroupChat ? ChatType.groupChat : ChatType.chat,
            );
          }

          if (replacedCount > 0) {
            await _storeMessage(
              Message(
                stanzaID: _connection.generateId(),
                senderJid: myJid!.toString(),
                chatJid: message.chatJid,
                pseudoMessageType: PseudoMessageType.changedDevice,
                pseudoMessageData: pseudoMessageData,
              ),
              chatType: isGroupChat ? ChatType.groupChat : ChatType.chat,
            );
          }
        }

        if (isGroupChat) {
          handleMucIdentifiersFromMessage(event, message);
        }

        _rememberReadOnlyTaskShare(message);

        if (!message.noStore) {
          await _storeMessage(
            message,
            chatType: isGroupChat ? ChatType.groupChat : ChatType.chat,
          );
        }
        if (shouldPersistAttachment &&
            _allowInboundAttachmentAutoDownload(message.chatJid)) {
          unawaited(
            _autoDownloadTrustedInboundAttachment(
              message: message,
              metadataId: metadata.id,
            ),
          );
        }

        await _recordLastSeenTimestamp(message.chatJid, message.timestamp);
        final isDirectChat = !isGroupChat &&
            message.chatJid.isNotEmpty &&
            !_isMucChatJid(message.chatJid);
        final isPeerChat = isDirectChat && message.chatJid != myJid;
        if (isPeerChat && this is AvatarService) {
          unawaited(
            (this as AvatarService).prefetchAvatarForJid(message.chatJid),
          );
        }
        if (isDirectChat) {
          unawaited(
            _upsertConversationIndexForPeer(
              peerJid: message.chatJid,
              lastTimestamp: message.timestamp ?? DateTime.timestamp(),
              lastId: message.originID ?? message.stanzaID,
            ),
          );
        }

        _messageStream.add(message);
      })
      ..registerHandler<MucSelfPresenceEvent>((event) async {
        if (!event.isAvailable) return;
        if (event.isNickChange) return;
        final roomJid = event.roomJid.trim();
        if (roomJid.isEmpty) return;
        if (!_isMucChatJid(roomJid)) return;
        if (_mamLoginSyncInFlight) {
          _mucJoinMamDeferredRooms.add(roomJid);
          return;
        }
        unawaited(_syncMucArchiveAfterJoin(roomJid));
      })
      ..registerHandler<OutboundGroupchatStanzaEvent>((event) async {
        _trackOutboundGroupchatStanza(
          stanzaId: event.stanzaId,
          roomJid: event.roomJid,
        );
      })
      ..registerHandler<mox.ChatMarkerEvent>((event) async {
        _log.info('Received chat marker');

        final isDisplayed = event.type == mox.ChatMarker.displayed;
        final isReceived = isDisplayed || event.type == mox.ChatMarker.received;
        const bool isAcked = true;
        await _dbOp<XmppDatabase>(
          (db) async {
            switch (event.type) {
              case mox.ChatMarker.displayed:
                db.markMessageDisplayed(event.id);
                db.markMessageReceived(event.id);
                db.markMessageAcked(event.id);
              case mox.ChatMarker.received:
                db.markMessageReceived(event.id);
                db.markMessageAcked(event.id);
              case mox.ChatMarker.acknowledged:
                db.markMessageAcked(event.id);
            }
          },
        );

        await _broadcastMessageStatusSync(
          id: event.id,
          acked: isAcked,
          received: isReceived,
          displayed: isDisplayed,
        );
      })
      ..registerHandler<mox.DeliveryReceiptReceivedEvent>((event) async {
        await _dbOp<XmppDatabase>(
          (db) async {
            db.markMessageReceived(event.id);
            db.markMessageAcked(event.id);
          },
        );

        await _broadcastMessageStatusSync(
          id: event.id,
          acked: true,
          received: true,
          displayed: false,
        );
      })
      ..registerHandler<mox.PubSubNotificationEvent>((event) async {
        await _handlePinNotification(event);
      })
      ..registerHandler<mox.PubSubItemsRetractedEvent>((event) async {
        await _handlePinRetraction(event);
      })
      ..registerHandler<mox.StreamNegotiationsDoneEvent>((event) async {
        if (connectionState != ConnectionState.connected) return;
        unawaited(_flushPendingPinSync());
        unawaited(_syncEmailPinnedMessagesOnReconnect());
      });
  }

  Future<void> syncMessageArchiveOnLogin({
    bool includeDirect = true,
    bool includeMuc = true,
  }) async {
    if (_mamLoginSyncInFlight) return;
    if (connectionState != ConnectionState.connected) return;
    _mamLoginSyncInFlight = true;
    try {
      await database;
      if (connectionState != ConnectionState.connected) return;
      await _resolveMamSupportForAccount();
      final canSyncDirect = _mamSupported;

      final chats = await _loadChatsForMamSync();

      for (final chat in chats) {
        if (connectionState != ConnectionState.connected) return;
        if (chat.defaultTransport.isEmail) continue;
        if (chat.type == ChatType.chat && (!includeDirect || !canSyncDirect)) {
          continue;
        }
        if (chat.type == ChatType.groupChat && !includeMuc) continue;

        final chatJid = chat.remoteJid;
        if (chatJid.isEmpty) continue;
        if (!chatJid.contains('@')) continue;
        try {
          final localCount = await countLocalMessages(
            jid: chatJid,
            includePseudoMessages: false,
          );
          final lastSeen = await loadLastSeenTimestamp(chatJid);
          final shouldBackfillLatest = messageStorageMode.isServerOnly ||
              localCount == 0 ||
              lastSeen == null;

          if (shouldBackfillLatest) {
            await fetchLatestFromArchive(
              jid: chatJid,
              pageSize: mamLoginBackfillMessageLimit,
              isMuc: chat.type == ChatType.groupChat,
            );
            continue;
          }

          await _catchUpChatFromArchive(
            jid: chatJid,
            since: lastSeen,
            isMuc: chat.type == ChatType.groupChat,
          );
        } on XmppAbortedException {
          return;
        } on Exception catch (error, stackTrace) {
          _log.fine(
            'Failed to sync one or more chat archives during login.',
            error,
            stackTrace,
          );
        }
      }
    } on XmppAbortedException {
      return;
    } finally {
      _mamLoginSyncInFlight = false;
      if (_mucJoinMamDeferredRooms.isNotEmpty) {
        final deferred = List<String>.from(_mucJoinMamDeferredRooms);
        _mucJoinMamDeferredRooms.clear();
        for (final roomJid in deferred) {
          unawaited(_syncMucArchiveAfterJoin(roomJid));
        }
      }
    }
  }

  Future<void> _syncMucArchiveAfterJoin(String roomJid) async {
    if (_mamLoginSyncInFlight) return;
    if (connectionState != ConnectionState.connected) return;
    final normalizedRoom = _roomKey(roomJid);
    if (_mucJoinMamSyncRooms.contains(normalizedRoom)) return;
    _mucJoinMamSyncRooms.add(normalizedRoom);
    try {
      final mamSupported = await resolveMamSupport();
      if (!mamSupported) return;
      if (!_canQueryMucArchive(normalizedRoom)) return;
      final localCount = await countLocalMessages(
        jid: normalizedRoom,
        includePseudoMessages: false,
      );
      final lastSeen = await loadLastSeenTimestamp(normalizedRoom);
      final shouldBackfillLatest = messageStorageMode.isServerOnly ||
          localCount == _emptyMessageCount ||
          lastSeen == null;

      if (shouldBackfillLatest) {
        await fetchLatestFromArchive(
          jid: normalizedRoom,
          pageSize: mamLoginBackfillMessageLimit,
          isMuc: true,
        );
        return;
      }

      await _catchUpChatFromArchive(
        jid: normalizedRoom,
        since: lastSeen,
        isMuc: true,
      );
    } on XmppAbortedException {
      return;
    } finally {
      _mucJoinMamSyncRooms.remove(normalizedRoom);
    }
  }

  Future<List<Chat>> _loadChatsForMamSync() async {
    final chats = <Chat>[];
    var start = 0;
    while (true) {
      final page = await _dbOpReturning<XmppDatabase, List<Chat>>(
        (db) => db.getChats(
          start: start,
          end: start + _mamDiscoChatLimit,
        ),
      );
      if (page.isEmpty) break;
      chats.addAll(page);
      if (page.length < _mamDiscoChatLimit) break;
      start += page.length;
    }
    return List<Chat>.unmodifiable(chats);
  }

  Future<void> _catchUpChatFromArchive({
    required String jid,
    required DateTime? since,
    required bool isMuc,
  }) async {
    if (since == null) return;
    String? afterId;
    while (true) {
      final result = await fetchSinceFromArchive(
        jid: jid,
        since: since,
        pageSize: mamLoginBackfillMessageLimit,
        isMuc: isMuc,
        after: afterId,
      );
      final nextAfterId = result.lastId ?? afterId;
      if (result.complete || nextAfterId == null || nextAfterId == afterId) {
        break;
      }
      afterId = nextAfterId;
    }
  }

  void _trackMamGlobalAnchor(mox.MessageEvent event) {
    if (!_mamGlobalSyncInFlight) return;
    if (!event.isFromMAM) return;
    final stamp = event.extensions.get<mox.DelayedDeliveryData>()?.timestamp;
    if (stamp == null) return;
    final normalized = stamp.toUtc();
    final current = _mamGlobalMaxTimestamp;
    if (current == null || normalized.isAfter(current)) {
      _mamGlobalMaxTimestamp = normalized;
    }
  }

  Future<MamGlobalSyncOutcome> syncGlobalMamCatchUp({
    int pageSize = mamLoginBackfillMessageLimit,
  }) async {
    if (_mamGlobalSyncInFlight) {
      return MamGlobalSyncOutcome.skippedInFlight;
    }
    if (connectionState != ConnectionState.connected) {
      return MamGlobalSyncOutcome.failed;
    }
    _mamGlobalSyncInFlight = true;
    try {
      await database;
      _mamGlobalMaxTimestamp = null;
      if (connectionState != ConnectionState.connected) {
        return MamGlobalSyncOutcome.failed;
      }
      await _resolveMamSupportForAccount();
      if (!_mamSupported) {
        return MamGlobalSyncOutcome.skippedUnsupported;
      }

      final deniedUntil = await _loadMamGlobalDeniedUntil();
      if (deniedUntil != null && deniedUntil.isAfter(DateTime.timestamp())) {
        return MamGlobalSyncOutcome.skippedDenied;
      }

      String? after = await _loadMamGlobalLastId();
      final anchor = await _loadMamGlobalLastSync();
      DateTime? start = after == null ? anchor : null;
      String? before = after == null && start == null
          ? ''
          : null; // Seed last page only on first-run.

      while (true) {
        final result = await _fetchGlobalMamPage(
          after: after,
          before: before,
          start: start,
          pageSize: pageSize,
        );
        final lastId = result.lastId;
        final hasProgress = lastId != null && lastId != after;
        if (hasProgress) {
          after = lastId;
          await _storeMamGlobalLastId(lastId);
        }
        if (result.complete || lastId == null) {
          break;
        }
        if (!hasProgress) {
          _log.fine(_mamGlobalNoProgressLog);
          throw XmppMessageException();
        }
        before = null;
        start = null;
      }

      final anchorTimestamp =
          _mamGlobalMaxTimestamp?.toUtc() ?? DateTime.timestamp().toUtc();
      await _storeMamGlobalLastSync(anchorTimestamp);
      await _storeMamGlobalDeniedUntil(null);
      _mamGlobalSyncCompletedAt = DateTime.timestamp();
      return MamGlobalSyncOutcome.completed;
    } on XmppAbortedException {
      return MamGlobalSyncOutcome.failed;
    } on Exception catch (error, stackTrace) {
      _log.fine('Global MAM sync failed.', error, stackTrace);
      final backoff = DateTime.timestamp().add(_mamGlobalDeniedBackoff);
      await _storeMamGlobalDeniedUntil(backoff);
      return MamGlobalSyncOutcome.failed;
    } finally {
      _mamGlobalSyncInFlight = false;
    }
  }

  Future<MamPageResult> _fetchGlobalMamPage({
    String? before,
    String? after,
    DateTime? start,
    int pageSize = mamLoginBackfillMessageLimit,
  }) async {
    final mamManager = _connection.getManager<mox.MAMManager>();
    if (mamManager == null) {
      _log.warning('MAM manager unavailable; ensure it is registered.');
      throw XmppMessageException();
    }
    final options = mox.MAMQueryOptions(
      withJid: null,
      start: start,
      formType: mox.mamXmlns,
      forceForm: true,
    );
    final result = await mamManager.queryArchive(
      to: null,
      options: options,
      rsm: mox.ResultSetManagement(
        before: before,
        after: after,
        max: pageSize,
      ),
    );
    if (result == null) {
      _log.warning('Global MAM query failed.');
      throw XmppMessageException();
    }
    final rsm = result.rsm;
    return MamPageResult(
      complete: result.complete,
      firstId: rsm?.first,
      lastId: rsm?.last,
      count: rsm?.count,
    );
  }

  bool _canQueryMucArchive(String jid) {
    final trimmed = jid.trim();
    if (trimmed.isEmpty) return false;
    late final String bareRoom;
    try {
      bareRoom = mox.JID.fromString(trimmed).toBare().toString();
    } on Exception {
      return false;
    }
    if (_mucMamUnsupportedRooms.contains(bareRoom)) return false;
    if (hasLeftRoom(bareRoom)) return false;
    final roomState = roomStateFor(bareRoom);
    if (roomState == null) return false;
    if (roomState.myOccupantId == null) return false;
    if (!roomState.hasSelfPresence) return false;
    return true;
  }

  @override
  List<mox.XmppManagerBase> get featureManagers => super.featureManagers
    ..addAll([
      MessageSanitizerManager(),
      mox.MessageManager(),
      XhtmlImManager(),
      mox.CarbonsManager(),
      mox.MAMManager(),
      MamStreamManagementGuard(),
      mox.MessageDeliveryReceiptManager(),
      mox.ChatMarkerManager(),
      mox.MessageRepliesManager(),
      mox.ChatStateManager(),
      mox.DelayedDeliveryManager(),
      mox.MessageRetractionManager(),
      mox.LastMessageCorrectionManager(),
      mox.MessageReactionsManager(),
      mox.MessageProcessingHintManager(),
      mox.EmeManager(),
      MUCManager(),
      mox.OOBManager(),
      mox.HttpFileUploadManager(),
      mox.FileUploadNotificationManager(),
      // mox.StickersManager(),
      // mox.MUCManager(),
      mox.SFSManager(),
    ]);

  mox.MessageEvent _buildOutgoingMessageEvent({
    required Message message,
    Message? quotedMessage,
    List<mox.StanzaHandlerExtension> extraExtensions = const [],
    ChatType chatType = ChatType.chat,
  }) {
    final quotedJid = quotedMessage == null
        ? null
        : mox.JID.fromString(quotedMessage.senderJid);
    final targetJid = mox.JID.fromString(message.chatJid);
    final isGroupChat = chatType == ChatType.groupChat;
    final isPrivateMucMessage = isGroupChat && targetJid.resource.isNotEmpty;
    final toJid =
        isGroupChat && !isPrivateMucMessage ? targetJid.toBare() : targetJid;
    final type = isGroupChat && !isPrivateMucMessage ? 'groupchat' : 'chat';

    return message.toMox(
      quotedBody: quotedMessage?.body,
      quotedJid: quotedJid,
      extraExtensions: extraExtensions,
      toJidOverride: toJid,
      type: type,
    );
  }

  Future<void> _ensureMucJoinForSend({
    required String roomJid,
  }) async {
    if (connectionState != ConnectionState.connected) return;
    late final String normalizedRoom;
    try {
      normalizedRoom = _roomKey(roomJid);
    } on Exception {
      throw XmppMessageException();
    }
    final manager = _connection.getManager<MUCManager>();
    if (manager == null) {
      throw XmppMessageException();
    }
    if (await _hasMucPresenceForSend(roomJid: normalizedRoom)) {
      await _awaitInstantRoomConfigurationIfNeeded(normalizedRoom);
      return;
    }

    try {
      await ensureJoined(
        roomJid: normalizedRoom,
        allowRejoin: _mucSendAllowRejoin,
      );
    } on Exception {
      // Join failures are surfaced by the follow-up presence check.
    }

    if (await _hasMucPresenceForSend(roomJid: normalizedRoom)) {
      await _awaitInstantRoomConfigurationIfNeeded(normalizedRoom);
      return;
    }

    throw XmppMessageException();
  }

  String _resolveOutboundMessageType(String? messageType) {
    final trimmed = messageType?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return _outboundSummaryUnknownType;
    }
    return trimmed;
  }

  void _trackOutboundMessageSummary({
    required mox.MessageEvent stanza,
    required ChatType chatType,
    required _OutboundMessageKind kind,
    required String chatJid,
  }) {
    final String? stanzaId = stanza.id;
    if (stanzaId == null || stanzaId.isEmpty) {
      return;
    }

    final String messageType = _resolveOutboundMessageType(stanza.type);
    final mox.TypedMap<mox.StanzaHandlerExtension> extensions =
        stanza.extensions;
    final bool hasBody =
        extensions.get<mox.MessageBodyData>()?.body?.isNotEmpty ?? false;
    final bool hasHtml =
        extensions.get<XhtmlImData>()?.xhtmlBody.isNotEmpty ?? false;
    final List<_OutboundMessageFlag> flags = <_OutboundMessageFlag>[
      if (extensions.get<mox.ChatState>() != null)
        _OutboundMessageFlag.chatState,
      if (extensions.get<mox.MarkableData>() != null)
        _OutboundMessageFlag.markable,
      if (extensions.get<mox.MessageDeliveryReceiptData>() != null)
        _OutboundMessageFlag.receipt,
      if (extensions.get<mox.ChatMarkerData>() != null)
        _OutboundMessageFlag.marker,
      if (extensions.get<mox.MessageProcessingHintData>() != null)
        _OutboundMessageFlag.processingHints,
      if (extensions.get<mox.ReplyData>() != null) _OutboundMessageFlag.reply,
      if (extensions.get<mox.MessageRetractionData>() != null)
        _OutboundMessageFlag.retraction,
      if (extensions.get<mox.LastMessageCorrectionData>() != null)
        _OutboundMessageFlag.correction,
      if (extensions.get<mox.OmemoData>() != null) _OutboundMessageFlag.omemo,
      if (extensions.get<mox.OOBData>() != null) _OutboundMessageFlag.oob,
      if (extensions.get<mox.StatelessFileSharingData>() != null)
        _OutboundMessageFlag.sfs,
      if (extensions.get<mox.FileUploadNotificationData>() != null)
        _OutboundMessageFlag.uploadNotification,
      if (extensions.get<XhtmlImData>() != null) _OutboundMessageFlag.xhtml,
    ];
    final String? normalizedChatJid = _normalizeBareJidValue(chatJid);
    final _OutboundMessageSummary summary = _OutboundMessageSummary(
      kind: kind,
      chatType: chatType,
      messageType: messageType,
      hasBody: hasBody,
      hasHtml: hasHtml,
      flags: flags,
      chatJid: normalizedChatJid,
    );
    _outboundMessageSummaries[stanzaId] = summary;
    _trimOutboundMessageSummaries();
  }

  void _trackOutboundGroupchatStanza({
    required String stanzaId,
    required String roomJid,
  }) {
    final trimmedId = stanzaId.trim();
    if (trimmedId.isEmpty) return;
    final normalizedRoom = _normalizeMucRoomJidCandidate(roomJid);
    if (normalizedRoom == null) return;
    _outboundGroupchatStanzaRooms[trimmedId] = normalizedRoom;
    _trimOutboundGroupchatStanzas();
  }

  String? _takeOutboundGroupchatRoomJid(String stanzaId) {
    final trimmedId = stanzaId.trim();
    if (trimmedId.isEmpty) return null;
    return _outboundGroupchatStanzaRooms.remove(trimmedId);
  }

  void _trimOutboundMessageSummaries() {
    if (_outboundMessageSummaries.length <= _outboundSummaryLimit) {
      return;
    }
    final String oldestKey = _outboundMessageSummaries.keys.first;
    _outboundMessageSummaries.remove(oldestKey);
  }

  void _trimOutboundGroupchatStanzas() {
    if (_outboundGroupchatStanzaRooms.length <= _outboundSummaryLimit) {
      return;
    }
    final oldestKey = _outboundGroupchatStanzaRooms.keys.first;
    _outboundGroupchatStanzaRooms.remove(oldestKey);
  }

  Future<void> sendMessage({
    required String jid,
    required String text,
    EncryptionProtocol encryptionProtocol = EncryptionProtocol.omemo,
    String? htmlBody,
    Message? quotedMessage,
    CalendarFragment? calendarFragment,
    CalendarTask? calendarTaskIcs,
    bool calendarTaskIcsReadOnly = CalendarTaskIcsMessage.defaultReadOnly,
    CalendarAvailabilityMessage? calendarAvailabilityMessage,
    bool? storeLocally,
    bool noStore = false,
    List<mox.StanzaHandlerExtension> extraExtensions = const [],
    ChatType chatType = ChatType.chat,
  }) async {
    final accountJid = myJid;
    if (accountJid == null) {
      _log.warning('Attempted to send a message before a JID was bound.');
      throw XmppMessageException();
    }
    if (!_isFirstPartyJid(myJid: _myJid, jid: jid)) {
      _log.warning(
        SafeLogging.sanitizeMessage(
          'Blocked XMPP send to foreign domain: $jid',
        ),
      );
      throw XmppForeignDomainException();
    }
    final offlineDemo = demoOfflineMode;
    final isGroupChat = chatType == ChatType.groupChat;
    if (chatType == ChatType.chat && !_isMucChatJid(jid) && jid != accountJid) {
      if (this is AvatarService) {
        unawaited(
          (this as AvatarService).prefetchAvatarForJid(jid),
        );
      }
    }
    if (isGroupChat && !offlineDemo) {
      await _ensureMucJoinForSend(roomJid: jid);
    }
    final senderJid = isGroupChat
        ? (roomStateFor(jid)?.myOccupantId ?? accountJid)
        : accountJid;
    final storePreference = storeLocally ?? true;
    final shouldStore = storePreference && !noStore;
    final normalizedHtml = HtmlContentCodec.normalizeHtml(htmlBody);
    final resolvedText = text.isNotEmpty
        ? text
        : (normalizedHtml == null
            ? ''
            : HtmlContentCodec.toPlainText(normalizedHtml));
    final CalendarFragmentPayload? fragmentPayload = calendarFragment == null
        ? null
        : CalendarFragmentPayload(fragment: calendarFragment);
    final CalendarTaskIcsPayload? taskIcsPayload = calendarTaskIcs == null
        ? null
        : CalendarTaskIcsPayload(
            ics: _calendarTaskIcsCodec.encode(calendarTaskIcs),
            readOnly: calendarTaskIcsReadOnly,
          );
    final CalendarTaskIcsMessage? taskIcsMessage = calendarTaskIcs == null
        ? null
        : CalendarTaskIcsMessage(
            task: calendarTaskIcs,
            readOnly: calendarTaskIcsReadOnly,
          );
    final CalendarAvailabilityMessagePayload? availabilityPayload =
        calendarAvailabilityMessage == null
            ? null
            : CalendarAvailabilityMessagePayload(
                message: calendarAvailabilityMessage,
              );
    final List<mox.StanzaHandlerExtension> resolvedExtensions =
        List<mox.StanzaHandlerExtension>.from(extraExtensions);
    if (fragmentPayload != null) {
      resolvedExtensions.add(fragmentPayload);
    }
    if (taskIcsPayload != null) {
      resolvedExtensions.add(taskIcsPayload);
    }
    if (availabilityPayload != null) {
      resolvedExtensions.add(availabilityPayload);
    }
    final Map<String, dynamic>? fragmentData = calendarFragment?.toJson();
    final Map<String, dynamic>? taskData = taskIcsMessage?.toJson();
    final Map<String, dynamic>? availabilityData =
        calendarAvailabilityMessage?.toJson();
    final PseudoMessageType? resolvedPseudoType =
        _calendarAvailabilityPseudoType(calendarAvailabilityMessage) ??
            (taskData == null
                ? (fragmentData == null
                    ? null
                    : PseudoMessageType.calendarFragment)
                : PseudoMessageType.calendarTaskIcs);
    final Map<String, dynamic>? pseudoMessageData =
        availabilityData ?? taskData ?? fragmentData;
    final message = Message(
      stanzaID: _connection.generateId(),
      originID: _connection.generateId(),
      senderJid: senderJid,
      chatJid: jid,
      body: resolvedText,
      htmlBody: normalizedHtml,
      encryptionProtocol: encryptionProtocol,
      noStore: noStore,
      quoting: quotedMessage?.stanzaID,
      timestamp: DateTime.timestamp(),
      acked: offlineDemo,
      received: offlineDemo,
      displayed: offlineDemo,
      pseudoMessageType: resolvedPseudoType,
      pseudoMessageData: pseudoMessageData,
    );
    _log.info(
      'Sending message ${message.stanzaID} (length=${resolvedText.length} chars)',
    );
    _rememberReadOnlyTaskShare(message);
    if (shouldStore) {
      await _storeMessage(message, chatType: chatType);
    }

    if (offlineDemo) {
      await _recordLastSeenTimestamp(message.chatJid, message.timestamp);
      return;
    }

    try {
      final mox.MessageEvent stanza = _buildOutgoingMessageEvent(
        message: message,
        quotedMessage: quotedMessage,
        extraExtensions: resolvedExtensions,
        chatType: chatType,
      );
      _trackOutboundMessageSummary(
        stanza: stanza,
        chatType: chatType,
        kind: _OutboundMessageKind.message,
        chatJid: message.chatJid,
      );
      final sent = await _connection.sendMessage(
        stanza,
      );
      if (!sent) {
        if (shouldStore) {
          await _handleMessageSendFailure(message.stanzaID);
        }
        throw XmppMessageException();
      }
      if (shouldStore) {
        await _dbOp<XmppDatabase>(
          (db) => db.markMessageAcked(message.stanzaID),
        );
      }
      if (chatType == ChatType.chat && !_isMucChatJid(jid)) {
        unawaited(
          _upsertConversationIndexForPeer(
            peerJid: jid,
            lastTimestamp: message.timestamp ?? DateTime.timestamp(),
            lastId: message.originID ?? message.stanzaID,
          ),
        );
      }
    } catch (error, stackTrace) {
      _log.warning(
        'Failed to send message ${message.stanzaID}',
        error,
        stackTrace,
      );
      if (shouldStore) {
        await _handleMessageSendFailure(message.stanzaID);
      }
      throw XmppMessageException();
    }
    await _recordLastSeenTimestamp(message.chatJid, message.timestamp);
  }

  Future<void> _upsertConversationIndexForPeer({
    required String peerJid,
    required DateTime lastTimestamp,
    required String? lastId,
  }) async {
    if (connectionState != ConnectionState.connected) return;
    final normalizedPeer = peerJid.trim();
    if (normalizedPeer.isEmpty) return;
    if (_isMucChatJid(normalizedPeer)) return;

    final manager = _connection.getManager<ConversationIndexManager>();
    if (manager == null) return;

    late final mox.JID peerBare;
    try {
      peerBare = mox.JID.fromString(normalizedPeer).toBare();
    } on Exception {
      return;
    }

    final chat = await _dbOpReturning<XmppDatabase, Chat?>(
      (db) => db.getChat(peerBare.toString()),
    );
    if (chat != null && !chat.transport.isXmpp) return;

    final cached = manager.cachedForPeer(peerBare);
    final cachedTimestamp = cached?.lastTimestamp;
    final lastTimestampUtc = lastTimestamp.toUtc();
    final nextTimestamp =
        cachedTimestamp != null && cachedTimestamp.isAfter(lastTimestampUtc)
            ? cachedTimestamp
            : lastTimestampUtc;

    final mutedUntil = (chat?.muted ?? false)
        ? DateTime.timestamp()
            .add(_conversationIndexMutedForeverDuration)
            .toUtc()
        : null;

    final trimmedLastId = lastId?.trim();
    await manager.upsert(
      ConvItem(
        peerBare: peerBare,
        lastTimestamp: nextTimestamp,
        lastId: trimmedLastId?.isNotEmpty == true ? trimmedLastId : null,
        pinned: chat?.favorited ?? false,
        archived: chat?.archived ?? false,
        mutedUntil: mutedUntil,
      ),
    );
  }

  PseudoMessageType? _calendarAvailabilityPseudoType(
    CalendarAvailabilityMessage? message,
  ) {
    if (message == null) {
      return null;
    }
    return message.map(
      share: (_) => PseudoMessageType.calendarAvailabilityShare,
      request: (_) => PseudoMessageType.calendarAvailabilityRequest,
      response: (_) => PseudoMessageType.calendarAvailabilityResponse,
    );
  }

  String _availabilityFallbackText(CalendarAvailabilityMessage message) {
    return message.map(
      share: (_) => _availabilityShareFallbackText,
      request: (_) => _availabilityRequestFallbackText,
      response: (value) => value.response.status.isAccepted
          ? _availabilityResponseAcceptedFallbackText
          : _availabilityResponseDeclinedFallbackText,
    );
  }

  Future<XmppAttachmentUpload> sendAttachment({
    required String jid,
    required EmailAttachment attachment,
    EncryptionProtocol encryptionProtocol = EncryptionProtocol.omemo,
    String? htmlCaption,
    String? transportGroupId,
    int? attachmentOrder,
    Message? quotedMessage,
    ChatType chatType = ChatType.chat,
    XmppAttachmentUpload? upload,
  }) async {
    final accountJid = myJid;
    if (accountJid == null) {
      _log.warning('Attempted to send an attachment before a JID was bound.');
      throw XmppMessageException();
    }
    if (!_isFirstPartyJid(myJid: _myJid, jid: jid)) {
      _log.warning('Blocked XMPP attachment send to foreign domain.');
      throw XmppForeignDomainException();
    }
    final isGroupChat = chatType == ChatType.groupChat;
    if (isGroupChat) {
      await _ensureMucJoinForSend(roomJid: jid);
    }
    final senderJid = isGroupChat
        ? (roomStateFor(jid)?.myOccupantId ?? accountJid)
        : accountJid;
    final resolvedUpload = upload ?? await _uploadAttachment(attachment);
    final metadata = resolvedUpload.metadata;
    final getUrl = resolvedUpload.getUrl;
    final size = metadata.sizeBytes ?? _attachmentSizeFallbackBytes;
    final filename = metadata.filename;
    await _dbOp<XmppDatabase>((db) => db.saveFileMetadata(metadata));
    final normalizedHtmlCaption = HtmlContentCodec.normalizeHtml(htmlCaption);
    final captionText = attachment.caption?.trim() ?? '';
    final resolvedCaption = captionText.isNotEmpty
        ? captionText
        : (normalizedHtmlCaption == null
            ? ''
            : HtmlContentCodec.toPlainText(normalizedHtmlCaption));
    final body = resolvedCaption.isNotEmpty
        ? resolvedCaption
        : _attachmentLabel(
            filename,
            size,
          );
    final message = Message(
      stanzaID: _connection.generateId(),
      originID: _connection.generateId(),
      senderJid: senderJid,
      chatJid: jid,
      body: body,
      htmlBody: normalizedHtmlCaption,
      encryptionProtocol: encryptionProtocol,
      timestamp: DateTime.timestamp(),
      fileMetadataID: metadata.id,
      quoting: quotedMessage?.stanzaID,
    );
    const shouldStore = true;
    await _storeMessage(message, chatType: chatType);
    if (transportGroupId != null || attachmentOrder != null) {
      await _dbOp<XmppDatabase>((db) async {
        final persisted = await db.getMessageByStanzaID(message.stanzaID);
        final messageId = persisted?.id;
        if (messageId == null || messageId.isEmpty) {
          return;
        }
        await db.addMessageAttachment(
          messageId: messageId,
          fileMetadataId: metadata.id,
          transportGroupId: transportGroupId,
          sortOrder: attachmentOrder,
        );
      });
    }
    if (upload == null) {
      await _uploadAttachmentFile(
        upload: resolvedUpload,
        metadata: metadata,
        stanzaId: message.stanzaID,
        shouldStore: shouldStore,
      );
    }

    try {
      final sfsData = _sfsDataForAttachment(
        metadata: metadata,
        url: getUrl,
      );
      final extraExtensions = <mox.StanzaHandlerExtension>[
        const mox.MessageProcessingHintData(
          [mox.MessageProcessingHint.store],
        ),
        sfsData,
        mox.OOBData(getUrl, filename),
      ];
      final mox.MessageEvent stanza = _buildOutgoingMessageEvent(
        message: message,
        quotedMessage: quotedMessage,
        extraExtensions: extraExtensions,
        chatType: chatType,
      );
      _trackOutboundMessageSummary(
        stanza: stanza,
        chatType: chatType,
        kind: _OutboundMessageKind.attachment,
        chatJid: message.chatJid,
      );
      final sent = await _connection.sendMessage(
        stanza,
      );
      if (!sent) {
        if (shouldStore) {
          await _dbOp<XmppDatabase>(
            (db) => db.saveMessageError(
              stanzaID: message.stanzaID,
              error: MessageError.fileUploadFailure,
            ),
          );
        }
        throw XmppMessageException();
      }
      await _dbOp<XmppDatabase>(
        (db) => db.markMessageAcked(message.stanzaID),
      );
    } catch (error, stackTrace) {
      _log.warning(
        'Failed to send attachment message ${message.stanzaID}',
        error,
        stackTrace,
      );
      if (shouldStore) {
        await _dbOp<XmppDatabase>(
          (db) => db.saveMessageError(
            stanzaID: message.stanzaID,
            error: MessageError.fileUploadFailure,
          ),
        );
      }
      throw XmppMessageException();
    }
    await _recordLastSeenTimestamp(message.chatJid, message.timestamp);
    return resolvedUpload;
  }

  @override
  Future<XmppAttachmentUpload> _uploadDraftAttachment(
    EmailAttachment attachment,
  ) =>
      _uploadAttachment(attachment);

  @override
  Future<void> _uploadDraftAttachmentFile({
    required XmppAttachmentUpload upload,
    required FileMetadataData metadata,
    required String stanzaId,
    required bool shouldStore,
  }) =>
      _uploadAttachmentFile(
        upload: upload,
        metadata: metadata,
        stanzaId: stanzaId,
        shouldStore: shouldStore,
      );

  Future<XmppAttachmentUpload> _uploadAttachment(
    EmailAttachment attachment,
  ) async {
    final uploadManager = _connection.getManager<mox.HttpFileUploadManager>();
    if (uploadManager == null) {
      _log.warning('HTTP upload manager unavailable; ensure it is registered.');
      throw XmppMessageException();
    }
    final uploadSupport = httpUploadSupport;
    _log.fine(
      'HTTP upload support snapshot: supported=${uploadSupport.supported} '
      'maxSize=${uploadSupport.maxFileSizeBytes ?? 'unspecified'}',
    );
    if (!await uploadManager.isSupported()) {
      _log.warning('Server does not advertise HTTP file upload support.');
      throw XmppUploadNotSupportedException();
    }
    final file = File(attachment.path);
    if (!await file.exists()) {
      _log.warning('Attachment missing on disk.');
      throw XmppMessageException();
    }
    final actualSize = await file.length();
    _log.fine(
      'Attachment size check: declared=${attachment.sizeBytes} '
      'actual=$actualSize',
    );
    if (attachment.sizeBytes > 0 && attachment.sizeBytes != actualSize) {
      _log.fine(
        'Attachment size mismatch; declared=${attachment.sizeBytes} '
        'actual=$actualSize. Using actual size.',
      );
    }
    final size = actualSize;
    final filename = attachment.fileName.isEmpty
        ? p.basename(file.path)
        : p.normalize(attachment.fileName);
    final contentType = attachment.mimeType?.isNotEmpty == true
        ? attachment.mimeType!
        : 'application/octet-stream';
    final slot = await _requestHttpUploadSlot(
      filename: filename,
      sizeBytes: size,
      contentType: contentType,
    );
    final getUrl = slot.getUrl;
    final metadata = FileMetadataData(
      id: attachment.metadataId ?? uuid.v4(),
      filename: filename,
      path: file.path,
      mimeType: contentType,
      sizeBytes: size,
      width: attachment.width,
      height: attachment.height,
      sourceUrls: [getUrl],
    );
    final headers = slot.headers
        .map(
          (header) => XmppUploadHeader(
            name: header.name,
            value: header.value,
          ),
        )
        .toList(growable: false);
    return XmppAttachmentUpload._(
      metadata: metadata,
      getUrl: getUrl,
      putUrl: slot.putUrl,
      headers: headers,
      contentType: contentType,
      sizeBytes: size,
      file: file,
    );
  }

  Future<void> _uploadAttachmentFile({
    required XmppAttachmentUpload upload,
    required FileMetadataData metadata,
    required String stanzaId,
    required bool shouldStore,
  }) async {
    _log.fine(_attachmentUploadStartLog);
    try {
      await _uploadFileToSlot(
        _UploadSlot(
          getUrl: upload.getUrl,
          putUrl: upload._putUrl,
          headers: upload._headers
              .map(
                (header) => _UploadSlotHeader(
                  name: header.name,
                  value: header.value,
                ),
              )
              .toList(growable: false),
        ),
        upload._file,
        sizeBytes: upload._sizeBytes,
        putUrl: upload._putUrl,
        contentType: upload._contentType,
      );
      _log.fine(_attachmentUploadCompleteLog);
    } catch (error, stackTrace) {
      _log.warning(
        _attachmentUploadFailedLog,
        error,
        stackTrace,
      );
      if (shouldStore) {
        await _dbOp<XmppDatabase>(
          (db) => db.saveMessageError(
            stanzaID: stanzaId,
            error: MessageError.fileUploadFailure,
          ),
        );
      }
      throw XmppMessageException();
    }
  }

  mox.StatelessFileSharingData _sfsDataForAttachment({
    required FileMetadataData metadata,
    required String url,
  }) {
    final sfsMetadata = mox.FileMetadataData(
      thumbnails: const [],
      mediaType: metadata.mimeType,
      width: metadata.width,
      height: metadata.height,
      name: metadata.filename,
      size: metadata.sizeBytes,
      hashes: metadata.plainTextHashes ?? const {},
    );
    return mox.StatelessFileSharingData(
      sfsMetadata,
      [mox.StatelessFileSharingUrlSource(url)],
    );
  }

  Future<_UploadSlot> _requestHttpUploadSlot({
    required String filename,
    required int sizeBytes,
    required String contentType,
  }) async {
    final uploadTarget = httpUploadSupport.entityJid;
    final maxSize = httpUploadSupport.maxFileSizeBytes;
    if (maxSize != null && sizeBytes > maxSize) {
      throw XmppFileTooBigException(maxSize);
    }
    if (uploadTarget == null) {
      throw XmppUploadNotSupportedException();
    }
    try {
      _log.fine(_uploadSlotRequestLog);
      return await _requestUploadSlotViaStanza(
        uploadJid: uploadTarget,
        filename: filename,
        sizeBytes: sizeBytes,
        contentType: contentType,
      );
    } on XmppUploadUnavailableException {
      _log.severe('HTTP upload service unavailable; request failed.');
      rethrow;
    } on XmppUploadNotSupportedException {
      _log.warning('HTTP upload service not supported on this server.');
      rethrow;
    } on XmppUploadMisconfiguredException {
      _log.warning('HTTP upload service misconfigured or unavailable.');
      rethrow;
    } on XmppMessageException {
      rethrow;
    } catch (error, stackTrace) {
      _log.warning(
        _uploadSlotRequestFailedLog,
        error,
        stackTrace,
      );
      throw XmppMessageException();
    }
  }

  Future<void> sendCalendarSyncMessage({
    required String jid,
    required CalendarSyncOutbound outbound,
    ChatType chatType = ChatType.chat,
  }) async {
    const hint = mox.MessageProcessingHintData(
      [mox.MessageProcessingHint.store],
    );
    final extensions = <mox.StanzaHandlerExtension>[hint];
    final attachment = outbound.attachment;
    if (attachment != null) {
      extensions.add(mox.OOBData(attachment.url, attachment.fileName));
    }
    await sendMessage(
      jid: jid,
      text: outbound.envelope,
      encryptionProtocol: EncryptionProtocol.none,
      storeLocally: false,
      extraExtensions: extensions,
      chatType: chatType,
    );
  }

  Future<void> sendAvailabilityMessage({
    required String jid,
    required CalendarAvailabilityMessage message,
    ChatType chatType = ChatType.chat,
  }) async {
    final fallbackText = _availabilityFallbackText(message);
    await sendMessage(
      jid: jid,
      text: fallbackText,
      encryptionProtocol: EncryptionProtocol.none,
      calendarAvailabilityMessage: message,
      chatType: chatType,
    );
  }

  Future<CalendarSnapshotUploadResult> uploadCalendarSnapshot(File file) async {
    final accountJid = myJid;
    if (accountJid == null) {
      _log.warning(_calendarSnapshotNoJidMessage);
      throw XmppMessageException();
    }
    final uploadManager = _connection.getManager<mox.HttpFileUploadManager>();
    if (uploadManager == null) {
      _log.warning('HTTP upload manager unavailable; ensure it is registered.');
      throw XmppMessageException();
    }
    if (!await uploadManager.isSupported()) {
      _log.warning('Server does not advertise HTTP file upload support.');
      throw XmppUploadNotSupportedException();
    }
    if (!await file.exists()) {
      _log.warning(_calendarSnapshotMissingFileMessage);
      throw XmppMessageException();
    }
    final snapshot = await CalendarSnapshotCodec.decodeFile(file);
    if (snapshot == null) {
      _log.warning(_calendarSnapshotInvalidFileMessage);
      throw XmppMessageException();
    }
    final size = await file.length();
    final filename = p.basename(file.path).trim().isNotEmpty
        ? p.basename(file.path)
        : _calendarSnapshotDefaultName;
    const contentType = CalendarSnapshotCodec.mimeType;
    final slot = await _requestHttpUploadSlot(
      filename: filename,
      sizeBytes: size,
      contentType: contentType,
    );
    try {
      await _uploadFileToSlot(
        slot,
        file,
        sizeBytes: size,
        putUrl: slot.putUrl,
        contentType: contentType,
      );
    } catch (error, stackTrace) {
      _log.warning(
        '$_calendarSnapshotUploadFailedMessage $filename',
        error,
        stackTrace,
      );
      throw XmppMessageException();
    }
    return CalendarSnapshotUploadResult(
      url: slot.getUrl,
      checksum: snapshot.checksum,
      version: snapshot.version,
    );
  }

  Future<_UploadSlot> _requestUploadSlotViaStanza({
    required String uploadJid,
    required String filename,
    required int sizeBytes,
    required String contentType,
  }) async {
    try {
      final response = await _connection
          .sendStanza(
            mox.StanzaDetails(
              mox.Stanza.iq(
                to: uploadJid,
                type: 'get',
                children: [
                  mox.XMLNode.xmlns(
                    tag: 'request',
                    xmlns: mox.httpFileUploadXmlns,
                    attributes: {
                      'filename': filename,
                      'size': sizeBytes.toString(),
                      'content-type': contentType,
                    },
                  ),
                ],
              ),
            ),
          )
          .timeout(_httpUploadSlotTimeout);
      if (response == null) {
        throw XmppUploadUnavailableException();
      }
      final type = response.attributes['type']?.toString();
      if (type != 'result') {
        final error = response.firstTag('error');
        final condition = error?.firstTagByXmlns(mox.fullStanzaXmlns)?.tag;
        if (condition == 'not-acceptable') {
          throw XmppFileTooBigException(httpUploadSupport.maxFileSizeBytes);
        }
        if (condition == 'service-unavailable') {
          throw XmppUploadMisconfiguredException();
        }
        throw XmppUploadUnavailableException();
      }
      final slot = response.firstTag('slot', xmlns: mox.httpFileUploadXmlns);
      final putUrl = slot?.firstTag('put')?.attributes['url']?.toString();
      final getUrl = slot?.firstTag('get')?.attributes['url']?.toString();
      if (putUrl == null || getUrl == null) {
        throw XmppUploadMisconfiguredException();
      }
      await _validateHttpUploadSlotUrls(
        putUrl: putUrl,
        getUrl: getUrl,
      );
      return _UploadSlot(
        getUrl: getUrl,
        putUrl: putUrl,
        headers: _parseHttpUploadPutHeaders(slot),
      );
    } on TimeoutException {
      throw XmppUploadUnavailableException();
    }
  }

  List<_UploadSlotHeader> _parseHttpUploadPutHeaders(mox.XMLNode? slot) {
    final put = slot?.firstTag('put');
    if (put == null) return const [];
    final headers = <_UploadSlotHeader>[];
    for (final tag in put.findTags('header')) {
      final rawName = tag.attributes['name']?.toString() ?? '';
      final rawValue = tag.innerText();
      final cleanedName = rawName.replaceAll(_crlfPattern, '').trim();
      final cleanedValue = rawValue.replaceAll(_crlfPattern, '').trim();
      if (cleanedName.isEmpty || cleanedValue.isEmpty) continue;
      if (!_allowedHttpUploadPutHeaders.contains(cleanedName.toLowerCase())) {
        continue;
      }
      headers.add(_UploadSlotHeader(name: cleanedName, value: cleanedValue));
    }
    return List.unmodifiable(headers);
  }

  Future<void> _validateHttpUploadSlotUrls({
    required String putUrl,
    required String getUrl,
  }) async {
    final putUri = Uri.tryParse(putUrl);
    final getUri = Uri.tryParse(getUrl);
    if (putUri == null || getUri == null) {
      throw XmppUploadMisconfiguredException('Upload slot URL invalid.');
    }
    const allowInsecure = !kReleaseMode && kAllowInsecureXmppHttpUploadSlots;
    final putIsHttps = putUri.scheme.toLowerCase() == 'https';
    final getIsHttps = getUri.scheme.toLowerCase() == 'https';
    if (putIsHttps && getIsHttps) {
      // continue
    } else if (allowInsecure) {
      _log.warning(
        'Using non-HTTPS upload slot URLs '
        '(development override enabled).',
      );
    } else {
      throw XmppUploadMisconfiguredException(
        'Upload slot URLs must use HTTPS.',
      );
    }
    if (putUri.userInfo.trim().isNotEmpty ||
        getUri.userInfo.trim().isNotEmpty) {
      throw XmppUploadMisconfiguredException('Upload slot URL invalid.');
    }
    final putHost = putUri.host.trim();
    final getHost = getUri.host.trim();
    if (putHost.isEmpty || getHost.isEmpty) {
      throw XmppUploadMisconfiguredException('Upload slot URL invalid.');
    }
    if (!allowInsecure) {
      final putSafe = await isSafeHostForRemoteConnection(putHost);
      final getSafe = await isSafeHostForRemoteConnection(getHost);
      if (!putSafe || !getSafe) {
        throw XmppUploadMisconfiguredException(
          'Upload slot host not allowed.',
        );
      }
    }
  }

  Future<void> _uploadFileToSlot(
    _UploadSlot slot,
    File file, {
    int? sizeBytes,
    required String putUrl,
    required String contentType,
  }) async {
    final client = HttpClient()..connectionTimeout = _httpUploadPutTimeout;
    final uploadLength = sizeBytes ?? await file.length();
    final stopwatch = Stopwatch()..start();
    final uri = Uri.parse(putUrl);
    try {
      final request = await client.openUrl('PUT', uri)
        ..followRedirects = false
        ..maxRedirects = 0;
      for (final header in slot.headers) {
        request.headers.add(header.name, header.value);
      }
      final hasContentTypeHeader = slot.headers.any(
        (header) => header.name.toLowerCase() == HttpHeaders.contentTypeHeader,
      );
      if (!hasContentTypeHeader) {
        request.headers.contentType = ContentType.parse(contentType);
      }
      request.headers.contentLength = uploadLength;
      final safeHeaders = <String>{
        ...slot.headers
            .map((header) => header.name.toLowerCase())
            .where(_safeHttpUploadLogHeaders.contains),
        ..._safeHttpUploadLogHeaders,
      }.toList()
        ..sort();
      final redactedHeaders = slot.headers
          .where(
            (header) =>
                !_safeHttpUploadLogHeaders.contains(header.name.toLowerCase()),
          )
          .length;
      final headerSuffix =
          redactedHeaders > 0 ? ' (+$redactedHeaders redacted)' : '';
      _log.finer(
        'HTTP upload PUT started len=$uploadLength '
        'headers=${safeHeaders.join(',')}$headerSuffix',
      );
      await file.openRead().timeout(_httpUploadPutTimeout).forEach(request.add);
      _log.finer(
        'HTTP upload PUT stream sent in ${stopwatch.elapsedMilliseconds}ms '
        'len=$uploadLength',
      );
      final response = await request.close().timeout(_httpUploadPutTimeout);
      final statusCode = response.statusCode;
      _log.finer(
        'HTTP upload PUT received status $statusCode '
        'after ${stopwatch.elapsedMilliseconds}ms',
      );
      final bodyBytes = await response
          .timeout(_httpUploadPutTimeout)
          .fold<List<int>>(<int>[], (buffer, data) {
        buffer.addAll(data);
        return buffer;
      });
      final success = statusCode >= 200 && statusCode < 300;
      if (!success) {
        _log.warning(
          'HTTP upload failed with status $statusCode '
          '(bodyLen=${bodyBytes.length})',
        );
        throw XmppMessageException();
      }
      _log.finer(
        'HTTP upload PUT completed with $statusCode '
        'in ${stopwatch.elapsedMilliseconds}ms '
        'bodyLen=${bodyBytes.length}',
      );
    } on TimeoutException {
      _log.warning(
        'HTTP upload timed out after ${_httpUploadPutTimeout.inSeconds}s',
      );
      throw XmppUploadUnavailableException();
    } catch (error, stackTrace) {
      _log.warning(
        'HTTP upload failed.',
        error,
        stackTrace,
      );
      rethrow;
    } finally {
      client.close();
      stopwatch.stop();
    }
  }

  String _attachmentLabel(String filename, int sizeBytes) {
    final prettySize = _formatBytes(sizeBytes);
    return '📎 $filename ($prettySize)';
  }

  String _formatBytes(int? bytes) {
    if (bytes == null || bytes <= 0) return 'Unknown size';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    final precision = value >= 10 || unitIndex == 0 ? 0 : 1;
    return '${value.toStringAsFixed(precision)} ${units[unitIndex]}';
  }

  // ignore: unused_element
  Future<void> _logHttpUploadServiceError({
    required String filename,
    required int sizeBytes,
    required String contentType,
  }) async {
    final target = httpUploadSupport.entityJid;
    if (target == null) {
      _log.warning('Cannot log HTTP upload IQ error: no upload entity known.');
      return;
    }
    try {
      final response = await _connection.sendStanza(
        mox.StanzaDetails(
          mox.Stanza.iq(
            to: target,
            type: 'get',
            children: [
              mox.XMLNode.xmlns(
                tag: 'request',
                xmlns: mox.httpFileUploadXmlns,
                attributes: {
                  'filename': filename,
                  'size': sizeBytes.toString(),
                  'content-type': contentType,
                },
              ),
            ],
          ),
        ),
      );
      if (response == null || response.attributes['type'] != 'error') {
        return;
      }
      final error = response.firstTag('error');
      final stanzaCondition =
          error?.firstTagByXmlns(mox.fullStanzaXmlns)?.tag ?? 'unknown';
      final text = error?.firstTag('text')?.innerText() ?? '';
      final from = response.attributes['from']?.toString();
      _log.warning(
        'HTTP upload slot request error from=${from ?? 'unknown'} '
        'condition=$stanzaCondition text=${text.isEmpty ? 'none' : text}',
      );
    } catch (error, stackTrace) {
      _log.fine(
        'Failed to log HTTP upload IQ error.',
        error,
        stackTrace,
      );
    }
  }

  Future<void> reactToMessage({
    required String stanzaID,
    required String emoji,
  }) async {
    final normalizedEmoji = emoji.trim();
    if (normalizedEmoji.isEmpty) return;
    if (!isWithinUtf8ByteLimit(
      normalizedEmoji,
      maxBytes: maxReactionEmojiBytes,
    )) {
      return;
    }
    final sender = myJid;
    final fromJid = _myJid;
    if (sender == null || fromJid == null) return;
    final message = await _dbOpReturning<XmppDatabase, Message?>(
      (db) => db.getMessageByStanzaID(stanzaID),
    );
    if (message == null) return;
    final existing = await _dbOpReturning<XmppDatabase, List<Reaction>>(
      (db) => db.getReactionsForMessageSender(
        messageId: message.stanzaID,
        senderJid: sender,
      ),
    );
    final emojis = existing.map((reaction) => reaction.emoji).toList();
    if (emojis.contains(normalizedEmoji)) {
      emojis.remove(normalizedEmoji);
    } else {
      emojis.add(normalizedEmoji);
    }
    final sanitizedEmojis = emojis.clampReactionEmojis();
    final reactionEvent = mox.MessageEvent(
      fromJid,
      mox.JID.fromString(message.chatJid),
      false,
      mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
        mox.MessageReactionsData(message.stanzaID, sanitizedEmojis),
      ]),
      id: _connection.generateId(),
    );
    try {
      final sent = await _connection.sendMessage(reactionEvent);
      if (!sent) {
        throw XmppMessageException();
      }
    } catch (error, stackTrace) {
      _log.warning(
        'Failed to send reaction for ${message.stanzaID}',
        error,
        stackTrace,
      );
      rethrow;
    }
    await _dbOp<XmppDatabase>(
      (db) => db.replaceReactions(
        messageId: message.stanzaID,
        senderJid: sender,
        emojis: sanitizedEmojis,
      ),
    );
  }

  Future<Message?> loadMessageByStanzaId(String stanzaID) async {
    return await _dbOpReturning<XmppDatabase, Message?>(
      (db) => db.getMessageByStanzaID(stanzaID),
    );
  }

  Future<void> resendMessage(
    String stanzaID, {
    ChatType? chatType,
  }) async {
    final message = await _dbOpReturning<XmppDatabase, Message?>(
      (db) => db.getMessageByStanzaID(stanzaID),
    );
    final normalizedHtml = message?.normalizedHtmlBody;
    final resolvedBody = message?.plainText ?? '';
    if (message == null || (resolvedBody.isEmpty && normalizedHtml == null)) {
      return;
    }
    final CalendarFragment? fragment = message.calendarFragment;
    final CalendarTask? taskIcs = message.calendarTaskIcs;
    final bool taskIcsReadOnly = message.calendarTaskIcsReadOnly;
    final CalendarAvailabilityMessage? availabilityMessage =
        message.calendarAvailabilityMessage;
    final resolvedChatType = chatType ??
        await _dbOpReturning<XmppDatabase, ChatType?>(
          (db) async => (await db.getChat(message.chatJid))?.type,
        ) ??
        ChatType.chat;
    Message? quoted;
    if (message.quoting != null) {
      quoted = await _dbOpReturning<XmppDatabase, Message?>(
        (db) => db.getMessageByStanzaID(message.quoting!),
      );
    }
    await sendMessage(
      jid: message.chatJid,
      text: resolvedBody,
      htmlBody: normalizedHtml,
      encryptionProtocol: message.encryptionProtocol,
      quotedMessage: quoted,
      calendarFragment: fragment,
      calendarTaskIcs: taskIcs,
      calendarTaskIcsReadOnly: taskIcsReadOnly,
      calendarAvailabilityMessage: availabilityMessage,
      chatType: resolvedChatType,
    );
  }

  Future<bool> _canSendChatMarkers({required String to}) async {
    if (_isMucChatJid(to)) return false;
    if (to == myJid) return false;
    final capabilities = await _capabilitiesFor(to);
    return capabilities.supportsMarkers;
  }

  Future<void> sendReadMarker(String to, String stanzaID) async {
    if (!await _canSendChatMarkers(to: to)) return;
    final messageType = _chatStateMessageType(to);
    _connection.sendChatMarker(
      to: to,
      stanzaID: stanzaID,
      marker: mox.ChatMarker.received,
      messageType: messageType,
    );

    await _connection.sendChatMarker(
      to: to,
      stanzaID: stanzaID,
      marker: mox.ChatMarker.displayed,
      messageType: messageType,
    );

    await _dbOp<XmppDatabase>(
      (db) async {
        db.markMessageDisplayed(stanzaID);
        db.markMessageReceived(stanzaID);
        db.markMessageAcked(stanzaID);
      },
    );
  }

  Future<MamPageResult> fetchLatestFromArchive({
    required String jid,
    int pageSize = 50,
    bool isMuc = false,
  }) async =>
      _fetchMamPage(
        jid: jid,
        before: '',
        pageSize: pageSize,
        isMuc: isMuc,
      );

  DateTime? get mamGlobalSyncCompletedAt => _mamGlobalSyncCompletedAt;

  bool get isMamGlobalSyncInFlight => _mamGlobalSyncInFlight;

  Future<bool> resolveMamSupport() async {
    await _resolveMamSupportForAccount();
    return _mamSupported;
  }

  Future<MamPageResult> fetchBeforeFromArchive({
    required String jid,
    required String before,
    int pageSize = 50,
    bool isMuc = false,
  }) async =>
      _fetchMamPage(
        jid: jid,
        before: before,
        pageSize: pageSize,
        isMuc: isMuc,
      );

  Future<MamPageResult> fetchSinceFromArchive({
    required String jid,
    required DateTime since,
    int pageSize = 50,
    bool isMuc = false,
    String? after,
  }) async =>
      _fetchMamPage(
        jid: jid,
        start: since,
        pageSize: pageSize,
        isMuc: isMuc,
        after: after,
      );

  Future<MamPageResult> _fetchMamPage({
    required String jid,
    String? before,
    String? after,
    DateTime? start,
    int pageSize = 50,
    bool isMuc = false,
  }) async {
    if (isMuc && !_canQueryMucArchive(jid)) {
      return const MamPageResult(complete: true);
    }
    final mamManager = _connection.getManager<mox.MAMManager>();
    if (mamManager == null) {
      _log.warning('MAM manager unavailable; ensure it is registered.');
      throw XmppMessageException();
    }
    final peerJid = mox.JID.fromString(jid);
    final options = mox.MAMQueryOptions(
      withJid: isMuc ? null : peerJid,
      start: start,
      formType: mox.mamXmlns,
      forceForm: true,
    );
    final result = await mamManager.queryArchive(
      to: isMuc ? peerJid : null,
      options: options,
      rsm: mox.ResultSetManagement(
        before: before,
        after: after,
        max: pageSize,
      ),
    );
    if (result == null) {
      _log.warning('MAM query failed.');
      throw XmppMessageException();
    }
    final rsm = result.rsm;
    return MamPageResult(
      complete: result.complete,
      firstId: rsm?.first,
      lastId: rsm?.last,
      count: rsm?.count,
    );
  }

  Future<List<String>> persistDraftAttachmentMetadata(
    Iterable<EmailAttachment> attachments,
  ) async {
    if (attachments.isEmpty) {
      return const <String>[];
    }
    final List<String> metadataIds = <String>[];
    for (final attachment in attachments) {
      final metadataId = await _persistDraftAttachmentMetadata(attachment);
      metadataIds.add(metadataId);
    }
    return List.unmodifiable(metadataIds);
  }

  Future<DraftSaveResult> saveDraft({
    int? id,
    required List<String> jids,
    required String body,
    String? subject,
    List<EmailAttachment> attachments = const [],
  }) async {
    final Draft? existingDraft = id == null
        ? null
        : await _dbOpReturning<XmppDatabase, Draft?>(
            (db) => db.getDraft(id),
          );
    final previousMetadataIds =
        existingDraft?.attachmentMetadataIds ?? const <String>[];
    final draftRecipients = await _resolveDraftRecipientRecords(
      jids: jids,
      existingRecipients:
          existingDraft?.draftRecipients ?? const <DraftRecipientData>[],
    );
    final resolvedSyncId = existingDraft?.draftSyncId.trim().isNotEmpty == true
        ? existingDraft!.draftSyncId
        : uuid.v4();
    final resolvedSourceId = await _ensureDraftSourceId();
    final resolvedUpdatedAt = DateTime.timestamp().toUtc();
    final metadataIds = <String>[];
    for (final attachment in attachments) {
      final metadataId = await _persistDraftAttachmentMetadata(attachment);
      metadataIds.add(metadataId);
    }
    final savedId = await _dbOpReturning<XmppDatabase, int>(
      (db) => db.saveDraft(
        id: id,
        jids: jids,
        body: body,
        draftSyncId: resolvedSyncId,
        draftUpdatedAt: resolvedUpdatedAt,
        draftSourceId: resolvedSourceId,
        draftRecipients: draftRecipients,
        subject: subject,
        attachmentMetadataIds: metadataIds,
      ),
    );
    final staleMetadataIds = previousMetadataIds
        .where((existing) => !metadataIds.contains(existing))
        .toList();
    if (staleMetadataIds.isNotEmpty) {
      await _deleteAttachmentMetadata(staleMetadataIds);
    }
    final savedDraft = await _dbOpReturning<XmppDatabase, Draft?>(
      (db) => db.getDraft(savedId),
    );
    if (savedDraft != null) {
      unawaited(publishDraftSync(savedDraft));
    }
    final draftCount = await _dbOpReturning<XmppDatabase, int>(
      (db) => db.countDrafts(),
    );
    return DraftSaveResult(
      draftId: savedId,
      attachmentMetadataIds: List.unmodifiable(metadataIds),
      draftCount: draftCount,
    );
  }

  Future<List<EmailAttachment>> loadDraftAttachments(
    Iterable<String> metadataIds,
  ) async {
    if (metadataIds.isEmpty) return const [];
    final attachments = <EmailAttachment>[];
    for (final metadataId in metadataIds) {
      final metadata = await _dbOpReturning<XmppDatabase, FileMetadataData?>(
        (db) => db.getFileMetadata(metadataId),
      );
      if (metadata == null) {
        continue;
      }
      var path = metadata.path;
      if (path == null || path.trim().isEmpty) {
        try {
          path = await downloadInboundAttachment(metadataId: metadata.id);
        } on Exception {
          continue;
        }
      }
      if (path == null || path.trim().isEmpty) {
        continue;
      }
      final file = File(path);
      if (!await file.exists()) {
        try {
          final downloaded = await downloadInboundAttachment(
            metadataId: metadata.id,
          );
          if (downloaded != null && downloaded.trim().isNotEmpty) {
            path = downloaded;
          }
        } on Exception {
          continue;
        }
      }
      final resolvedFile = File(path);
      if (!await resolvedFile.exists()) {
        continue;
      }
      final size = metadata.sizeBytes ?? await resolvedFile.length();
      attachments.add(
        EmailAttachment(
          path: path,
          fileName: metadata.filename,
          sizeBytes: size,
          mimeType: metadata.mimeType,
          width: metadata.width,
          height: metadata.height,
          metadataId: metadata.id,
        ),
      );
    }
    return attachments;
  }

  Future<void> deleteDraft({required int id}) async {
    final draft = await _dbOpReturning<XmppDatabase, Draft?>(
      (db) => db.getDraft(id),
    );
    final metadataIds = draft?.attachmentMetadataIds ?? const <String>[];
    final syncId = draft?.draftSyncId ?? '';
    await _dbOp<XmppDatabase>(
      (db) => db.removeDraft(id),
    );
    if (metadataIds.isNotEmpty) {
      await _deleteAttachmentMetadata(metadataIds);
    }
    if (syncId.trim().isNotEmpty) {
      unawaited(retractDraftSync(syncId));
    }
  }

  Future<void> deleteFileMetadata(String id) async {
    final String trimmed = id.trim();
    if (trimmed.isEmpty) {
      return;
    }
    await _dbOp<XmppDatabase>(
      (db) => db.deleteFileMetadata(trimmed),
    );
  }

  Future<void> _handleMessageSendFailure(String stanzaID) async {
    await _dbOp<XmppDatabase>(
      (db) => db.saveMessageError(
        error: MessageError.unknown,
        stanzaID: stanzaID,
      ),
    );
  }

  Future<String> _persistDraftAttachmentMetadata(
    EmailAttachment attachment,
  ) async {
    final resolvedId = attachment.metadataId ?? uuid.v4();
    final existing = await _dbOpReturning<XmppDatabase, FileMetadataData?>(
      (db) => db.getFileMetadata(resolvedId),
    );
    final resolvedFilename = attachment.fileName.isNotEmpty
        ? attachment.fileName
        : existing?.filename ?? p.basename(attachment.path);
    final resolvedSizeBytes =
        attachment.sizeBytes > 0 ? attachment.sizeBytes : existing?.sizeBytes;
    final metadata = FileMetadataData(
      id: resolvedId,
      filename: resolvedFilename,
      path: attachment.path,
      sourceUrls: existing?.sourceUrls,
      mimeType: attachment.mimeType ?? existing?.mimeType,
      sizeBytes: resolvedSizeBytes,
      width: attachment.width ?? existing?.width,
      height: attachment.height ?? existing?.height,
      encryptionKey: existing?.encryptionKey,
      encryptionIV: existing?.encryptionIV,
      encryptionScheme: existing?.encryptionScheme,
      cipherTextHashes: existing?.cipherTextHashes,
      plainTextHashes: existing?.plainTextHashes,
      thumbnailType: existing?.thumbnailType,
      thumbnailData: existing?.thumbnailData,
    );
    await _dbOp<XmppDatabase>((db) => db.saveFileMetadata(metadata));
    return metadata.id;
  }

  Future<void> _deleteAttachmentMetadata(
    Iterable<String> metadataIds,
  ) async {
    if (metadataIds.isEmpty) return;
    await _dbOp<XmppDatabase>(
      (db) async {
        for (final metadataId in metadataIds) {
          await db.deleteFileMetadata(metadataId);
        }
      },
    );
  }

  Future<void> _ensureCapabilityCacheLoaded() async {
    if (_capabilityCacheLoaded) return;
    await _dbOp<XmppStateStore>((ss) {
      final stored =
          (ss.read(key: _capabilityCacheKey) as Map<dynamic, dynamic>?) ?? {};
      _capabilityCache
        ..clear()
        ..addAll(stored.map(
          (key, value) => MapEntry(
            key as String,
            _PeerCapabilities.fromJson(value as Map<dynamic, dynamic>),
          ),
        ));
    }, awaitDatabase: true);
    _capabilityCacheLoaded = true;
  }

  Future<void> _persistCapabilityCache() async {
    if (!_capabilityCacheLoaded) return;
    await _dbOp<XmppStateStore>(
      (ss) => ss.write(
        key: _capabilityCacheKey,
        value: _capabilityCache.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
      ),
      awaitDatabase: true,
    );
  }

  Future<_PeerCapabilities> _capabilitiesFor(String jid) async {
    await _ensureCapabilityCacheLoaded();
    if (_capabilityCache[jid] case final _PeerCapabilities cached) {
      return cached;
    }

    final result = await _connection.discoInfoQuery(jid);
    if (result == null || result.isType<mox.StanzaError>()) {
      const fallback = _PeerCapabilities.empty;
      _capabilityCache[jid] = fallback;
      await _persistCapabilityCache();
      await _dbOp<XmppDatabase>(
        (db) => db.markChatMarkerResponsive(
          jid: jid,
          responsive: fallback.supportsMarkers,
        ),
      );
      return fallback;
    }

    final info = result.get<mox.DiscoInfo>();
    final features = info.features;
    final capabilities = _PeerCapabilities(
      supportsMarkers: features.contains(mox.chatMarkersXmlns),
      supportsReceipts: features.contains(mox.deliveryXmlns),
    );

    _capabilityCache[jid] = capabilities;
    await _persistCapabilityCache();

    await _dbOp<XmppDatabase>(
      (db) => db.markChatMarkerResponsive(
        jid: jid,
        responsive: capabilities.supportsMarkers,
      ),
    );

    return capabilities;
  }

  Future<bool> _supportsMam(String jid) async {
    final result = await _connection.discoInfoQuery(jid);
    if (result == null || result.isType<mox.StanzaError>()) {
      return false;
    }
    final info = result.get<mox.DiscoInfo>();
    return info.features.contains(mox.mamXmlns);
  }

  Future<void> _resolveMamSupportForAccount() async {
    if (_mamSupportOverride != null) {
      _updateMamSupport(_mamSupportOverride!);
      return;
    }
    final accountJid = myJid;
    if (accountJid == null) {
      _updateMamSupport(false);
      return;
    }
    try {
      final supported = await _supportsMam(accountJid);
      _updateMamSupport(supported);
    } on Exception catch (error, stackTrace) {
      _log.fine('Failed to resolve MAM support.', error, stackTrace);
      _updateMamSupport(false);
    }
  }

  Future<void> _verifyMamSupportOnLogin() async {
    if (connectionState != ConnectionState.connected) return;
    final accountJid = myJid;
    if (accountJid != null) {
      final supportsMam = await _supportsMam(accountJid);
      if (!supportsMam) {
        _log.warning(
          'Archive queries may be limited: server did not advertise MAM v2.',
        );
      }
      _updateMamSupport(supportsMam);
    }

    List<Chat> chats;
    try {
      chats = await _dbOpReturning<XmppDatabase, List<Chat>>(
        (db) => db.getChats(start: 0, end: _mamDiscoChatLimit),
      );
    } on XmppAbortedException {
      return;
    }

    final mucChats =
        chats.where((chat) => chat.type == ChatType.groupChat).toList();
    if (mucChats.isEmpty) return;

    final unsupportedRooms = <String>{};
    for (final chat in mucChats) {
      try {
        final hasMam = await _supportsMam(chat.jid);
        if (!hasMam) {
          unsupportedRooms.add(
            mox.JID.fromString(chat.jid).toBare().toString(),
          );
        }
      } on Exception catch (error, stackTrace) {
        _log.fine('MAM disco for a group chat failed.', error, stackTrace);
      }
    }
    _mucMamUnsupportedRooms
      ..clear()
      ..addAll(unsupportedRooms);
    if (unsupportedRooms.isNotEmpty) {
      _log.warning(
        'Archive backfill may be incomplete: one or more group chats did not advertise MAM v2.',
      );
    }
    _updateMamSupport(_mamSupported);
  }

  Future<void> _acknowledgeMessage(mox.MessageEvent event) async {
    if (event.isCarbon) return;
    final bool isDelayed =
        event.extensions.get<mox.DelayedDeliveryData>() != null;
    if (event.isFromMAM || isDelayed) {
      return;
    }
    final body = event.get<mox.MessageBodyData>()?.body?.trim();
    if (body != null &&
        body.isNotEmpty &&
        _MessageStatusSyncEnvelope.isEnvelope(body)) {
      return;
    }

    final markable =
        event.extensions.get<mox.MarkableData>()?.isMarkable ?? false;
    final deliveryReceiptRequested = event.extensions
            .get<mox.MessageDeliveryReceiptData>()
            ?.receiptRequested ??
        false;

    if (!markable && !deliveryReceiptRequested) return;

    final id = event.extensions.get<mox.StableIdData>()?.originId ?? event.id;
    if (id == null) return;

    final peer = event.from.toBare().toString();
    final isMuc = event.type == 'groupchat';
    if (isMuc) {
      await _dbOp<XmppDatabase>(
        (db) async {
          db.markMessageReceived(id);
          db.markMessageAcked(id);
        },
      );
      return;
    }
    final target = isMuc ? event.from.toString() : peer;
    final messageType = _chatStateMessageType(target);
    final capabilities =
        isMuc ? _PeerCapabilities.supportsAll : await _capabilitiesFor(peer);

    if (markable && capabilities.supportsMarkers) {
      await _connection.sendChatMarker(
        to: target,
        stanzaID: id,
        marker: mox.ChatMarker.received,
        messageType: messageType,
      );

      await _dbOp<XmppDatabase>(
        (db) async {
          db.markMessageReceived(id);
          db.markMessageAcked(id);
        },
      );
    }

    if (deliveryReceiptRequested && capabilities.supportsReceipts) {
      await _connection.sendMessage(
        mox.MessageEvent(
          _myJid!,
          mox.JID.fromString(target),
          false,
          mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
            mox.MessageDeliveryReceivedData(id),
          ]),
          type: messageType,
        ),
      );

      await _dbOp<XmppDatabase>(
        (db) async {
          db.markMessageReceived(id);
          db.markMessageAcked(id);
        },
      );
    }
  }

  Future<bool> _handleMessageStatusSync(mox.MessageEvent event) async {
    final raw = event.get<mox.MessageBodyData>()?.body?.trim();
    if (raw == null || raw.isEmpty) {
      return false;
    }
    final from = event.from.toBare().toString().toLowerCase();
    final to = event.to.toBare().toString().toLowerCase();
    final accountJid = myJid;
    final self = accountJid?.toLowerCase();
    if (self == null || self.isEmpty) {
      return false;
    }
    if (from != self || to != self) {
      return false;
    }

    final envelope = _MessageStatusSyncEnvelope.tryParseEnvelope(raw);
    if (envelope == null) {
      if (raw.contains(_messageStatusSyncEnvelopeKey)) {
        _log.fine('Dropped malformed message status sync envelope from self');
        return true;
      }
      return false;
    }

    await _dbOp<XmppDatabase>(
      (db) async {
        if (envelope.displayed) {
          db.markMessageDisplayed(envelope.id);
        }
        if (envelope.received) {
          db.markMessageReceived(envelope.id);
        }
        if (envelope.acked) {
          db.markMessageAcked(envelope.id);
        }
      },
    );
    return true;
  }

  Future<void> _broadcastMessageStatusSync({
    required String id,
    required bool acked,
    required bool received,
    required bool displayed,
  }) async {
    final accountJid = myJid;
    if (accountJid == null || accountJid.isEmpty) {
      return;
    }

    final normalizedDisplayed = displayed;
    final normalizedReceived = normalizedDisplayed || received;
    final normalizedAcked = normalizedReceived || acked;

    final db = await database;
    final message =
        await db.getMessageByStanzaID(id) ?? await db.getMessageByOriginID(id);
    if (message == null) {
      return;
    }
    if (message.senderJid.toLowerCase() != accountJid.toLowerCase()) {
      return;
    }
    final body = message.body;
    if (body != null &&
        body.isNotEmpty &&
        (CalendarSyncMessage.looksLikeEnvelope(body) ||
            _MessageStatusSyncEnvelope.isEnvelope(body))) {
      return;
    }

    final envelopeJson = jsonEncode({
      _messageStatusSyncEnvelopeKey: _MessageStatusSyncEnvelope(
        id: id,
        acked: normalizedAcked,
        received: normalizedReceived,
        displayed: normalizedDisplayed,
      ).toJson(),
    });

    try {
      await sendMessage(
        jid: accountJid,
        text: envelopeJson,
        storeLocally: false,
      );
    } on Exception catch (error, stackTrace) {
      _log.finer('Failed to broadcast message status sync', error, stackTrace);
    }
  }

  @override
  Future<void> _reset() async {
    await super._reset();

    _mamLoginSyncInFlight = false;
    _mamGlobalSyncInFlight = false;
    _mamGlobalSyncCompletedAt = null;
    _mucMamUnsupportedRooms.clear();
    _mucJoinMamDeferredRooms.clear();
    _mamGlobalDeniedUntil = null;
    _mamGlobalDeniedUntilScope = null;
    _mamGlobalDeniedUntilLoaded = false;
    _mamGlobalMaxTimestamp = null;
    _resetStableKeyCache();
    _lastSeenKeys.clear();
    _capabilityCache.clear();
    _capabilityCacheLoaded = false;
    _inboundAttachmentDownloads.clear();
    _inboundAttachmentAutoDownloadGlobalLimiter.reset();
    _inboundAttachmentAutoDownloadChatLimiter.reset();
    _attachmentDirectory = null;
    _attachmentCacheSessionPrefix = null;
  }

  // Future<void> _handleMessage(mox.MessageEvent event) async {
  //   if (await _handleError(event)) throw EventHandlerAbortedException();
  //
  //   final get = event.extensions.get;
  //   final isCarbon = get<mox.CarbonsData>()?.isCarbon ?? false;
  //   final to = event.to.toBare().toString();
  //   final from = event.from.toBare().toString();
  //   final chatJid = isCarbon ? to : from;
  //
  //   await _handleChatState(event, chatJid);
  //
  //   if (await _handleCorrection(event, from)) {
  //     throw EventHandlerAbortedException();
  //   }
  //   if (await _handleRetraction(event, from)) {
  //     throw EventHandlerAbortedException();
  //   }
  //
  //   // TODO: Include InvalidKeyExchangeSignatureError for OMEMO.
  //   if (!event.displayable && event.encryptionError == null) {
  //     throw EventHandlerAbortedException();
  //   }
  //   if (get<mox.FileUploadNotificationData>() case final data?) {
  //     if (data.metadata.name == null) throw EventHandlerAbortedException();
  //   }
  //
  //   await _handleFile(event, from);
  //
  //   final metadata = _extractFileMetadata(event);
  //   if (metadata != null) {
  //     await _dbOp<XmppDatabase>((db) async {
  //       await db.saveFileMetadata(metadata);
  //     });
  //   }
  //
  //   final body = get<mox.ReplyData>()?.withoutFallback ??
  //       get<mox.MessageBodyData>()?.body ??
  //       '';
  //
  //   final message = Message(
  //     stanzaID: event.id ?? _connection.generateId(),
  //     senderJid: from,
  //     chatJid: chatJid,
  //     body: body,
  //     timestamp: get<mox.DelayedDeliveryData>()?.timestamp,
  //     fileMetadataID: metadata?.id,
  //     noStore: get<mox.MessageProcessingHintData>()
  //             ?.hints
  //             .contains(mox.MessageProcessingHint.noStore) ??
  //         false,
  //     quoting: get<mox.ReplyData>()?.id,
  //     originID: get<mox.StableIdData>()?.originId,
  //     occupantID: get<mox.OccupantIdData>()?.id,
  //     encryptionProtocol:
  //         event.encrypted ? EncryptionProtocol.omemo : EncryptionProtocol.none,
  //     acked: true,
  //     received: true,
  //   );
  //   await _dbOp<XmppDatabase>((db) async {
  //     await db.saveMessage(message);
  //   });
  // }

  MessageError _resolveMessageError(
    mox.StanzaError? stanzaError,
  ) {
    return switch (stanzaError) {
      mox.ServiceUnavailableError _ => MessageError.serviceUnavailable,
      mox.RemoteServerNotFoundError _ => MessageError.serverNotFound,
      mox.RemoteServerTimeoutError _ => MessageError.serverTimeout,
      _ => MessageError.unknown,
    };
  }

  bool _matchesStanzaErrorType(String? errorType, String expected) {
    if (errorType == null) return true;
    return errorType == expected;
  }

  bool _shouldAttemptMucRepair(
    StanzaErrorConditionData? conditionData,
  ) {
    if (conditionData == null) return false;
    final String condition = conditionData.condition;
    final String? errorType = conditionData.type;
    if (condition == _errorConditionNotAcceptable &&
        _matchesStanzaErrorType(errorType, _errorTypeModify)) {
      return true;
    }
    if (condition == _errorConditionResourceConstraint &&
        _matchesStanzaErrorType(errorType, _errorTypeWait)) {
      return true;
    }
    if (condition == _errorConditionServiceUnavailable &&
        _matchesStanzaErrorType(errorType, _errorTypeCancel)) {
      return true;
    }
    return false;
  }

  bool _shouldAttemptMucRepairForRoom({
    required String roomJid,
    required StanzaErrorConditionData? conditionData,
  }) {
    if (!_shouldAttemptMucRepair(conditionData)) return false;
    late final String key;
    try {
      key = _roomKey(roomJid);
    } on Exception {
      return false;
    }
    final RoomState? room = _roomStates[key];
    if (room == null) return false;
    if (room.wasBanned || room.wasKicked || room.roomShutdown) return false;

    final String condition = conditionData?.condition ?? '';
    final String? errorType = conditionData?.type;
    if (condition == _errorConditionNotAcceptable &&
        _matchesStanzaErrorType(errorType, _errorTypeModify)) {
      return true;
    }

    final bool pendingConfig = _instantRoomPendingRooms.contains(key);
    if (pendingConfig) return true;
    if (room.roomCreated) return true;
    return room.hasSelfPresence != true;
  }

  String? _resolveGroupChatRoomJid({
    required mox.MessageEvent event,
    required _OutboundMessageSummary summary,
  }) {
    final String? summaryJid = _normalizeMucRoomJidCandidate(summary.chatJid);
    if (summaryJid != null) return summaryJid;
    final String? fromBare =
        _normalizeMucRoomJidCandidate(event.from.toBare().toString());
    final String? toBare =
        _normalizeMucRoomJidCandidate(event.to.toBare().toString());
    final String? ownBare = _normalizeBareJidValue(_myJid?.toBare().toString());
    if (ownBare == null || ownBare.isEmpty) {
      return fromBare ?? toBare;
    }
    if (fromBare != null && fromBare != ownBare) return fromBare;
    if (toBare != null && toBare != ownBare) return toBare;
    return null;
  }

  String? _resolveGroupChatRoomJidFromEvent(mox.MessageEvent event) {
    final String? fromBare =
        _normalizeMucRoomJidCandidate(event.from.toBare().toString());
    final String? toBare =
        _normalizeMucRoomJidCandidate(event.to.toBare().toString());
    final String? ownBare = _normalizeBareJidValue(_myJid?.toBare().toString());
    if (ownBare == null || ownBare.isEmpty) {
      return fromBare ?? toBare;
    }
    if (fromBare != null && fromBare != ownBare) return fromBare;
    if (toBare != null && toBare != ownBare) return toBare;
    return null;
  }

  Future<String?> _resolveGroupChatRoomJidFromDb(String stanzaId) async {
    final trimmed = stanzaId.trim();
    if (trimmed.isEmpty) return null;
    try {
      final message = await _dbOpReturning<XmppDatabase, Message?>(
        (db) => db.getMessageByStanzaID(trimmed),
      );
      if (message == null) return null;
      return _normalizeMucRoomJidCandidate(message.chatJid);
    } on XmppAbortedException {
      return null;
    }
  }

  bool _shouldClearMucPresenceForError(
    StanzaErrorConditionData? conditionData,
  ) {
    if (conditionData == null) return false;
    final condition = conditionData.condition;
    final errorType = conditionData.type;
    if (condition == _errorConditionNotAcceptable &&
        _matchesStanzaErrorType(errorType, _errorTypeModify)) {
      return true;
    }
    return condition == _errorConditionServiceUnavailable &&
        _matchesStanzaErrorType(errorType, _errorTypeCancel);
  }

  Future<void> _repairMucJoin(String roomJid) async {
    try {
      final String normalizedRoom = _roomKey(roomJid);
      await ensureJoined(
        roomJid: normalizedRoom,
        allowRejoin: true,
        forceRejoin: true,
      );
    } on Exception {
      // Join failures are already reflected in message errors.
    }
  }

  Future<bool> _handleError(mox.MessageEvent event) async {
    if (event.type != _messageTypeError) return false;

    _log.info('Handling error message...');
    final stanzaId = event.id;
    if (stanzaId == null) return true;

    final stanzaError = event.error;
    final MessageError error = _resolveMessageError(stanzaError);
    final StanzaErrorConditionData? errorCondition =
        event.extensions.get<StanzaErrorConditionData>();

    await _dbOp<XmppDatabase>(
      (db) => db.saveMessageError(
        stanzaID: stanzaId,
        error: error,
      ),
    );
    final _OutboundMessageSummary? summary =
        _outboundMessageSummaries.remove(stanzaId);
    final String? mappedRoomJid = _takeOutboundGroupchatRoomJid(stanzaId);
    final bool summaryIsGroupChat = summary?.chatType == ChatType.groupChat;
    String? roomJid = summaryIsGroupChat
        ? _resolveGroupChatRoomJid(event: event, summary: summary!)
        : _resolveGroupChatRoomJidFromEvent(event);
    roomJid ??= mappedRoomJid;
    roomJid ??= await _resolveGroupChatRoomJidFromDb(stanzaId);
    if (roomJid != null &&
        _isMucChatJid(roomJid) &&
        _shouldAttemptMucRepairForRoom(
          roomJid: roomJid,
          conditionData: errorCondition,
        )) {
      _markRoomNeedsJoin(roomJid);
      if (_shouldClearMucPresenceForError(errorCondition)) {
        _markRoomLeft(
          roomJid,
          statusCodes: _emptyStatusCodes,
          preserveOccupants: _preserveOccupantsOnMucError,
        );
      }
      unawaited(_repairMucJoin(roomJid));
    }
    if (summary == null) {
      _log.info(_outboundMessageRejectedMissingSummaryLog);
      return true;
    }
    final String errorName = stanzaError == null
        ? _outboundSummaryUnknownType
        : stanzaError.runtimeType.toString();
    _log.info(
      '$_outboundMessageRejectedLog$_outboundSummaryPrefixSeparator'
      '${summary.toLogPayload(errorName: errorName)}',
    );
    return true;
  }

  Future<void> _handleChatState(mox.MessageEvent event, String jid) async {
    if (event.extensions.get<mox.ChatState>() case final state?) {
      _trackTypingParticipant(
        chatJid: jid,
        senderJid: event.from.toString(),
        state: state,
      );
      await _dbOp<XmppDatabase>(
        (db) => db.updateChatState(chatJid: jid, state: state),
      );
    }
  }

  Future<bool> _handleCorrection(mox.MessageEvent event, String jid) async {
    final correction = event.extensions.get<mox.LastMessageCorrectionData>();
    if (correction == null) return false;
    if (!_isGroupChatMutationAuthorized(event)) {
      _log.warning(_mucMutationRejectedLog);
      return true;
    }

    final mox.OccupantIdData? occupantData =
        event.extensions.get<mox.OccupantIdData>();
    final String? occupantId = occupantData?.id;
    return await _dbOpReturning<XmppDatabase, bool>(
      (db) async {
        if (await db.getMessageByOriginID(correction.id) case final message?) {
          if (!message.authorizedForMutation(
                from: event.from,
                occupantId: occupantId,
              ) ||
              !message.editable) {
            return false;
          }
          await db.saveMessageEdit(
            stanzaID: message.stanzaID,
            body: event.extensions.get<mox.MessageBodyData>()?.body,
          );
          return true;
        }
        return false;
      },
    );
  }

  Future<bool> _handleRetraction(mox.MessageEvent event, String jid) async {
    final retraction = event.extensions.get<mox.MessageRetractionData>();
    if (retraction == null) return false;
    if (!_isGroupChatMutationAuthorized(event)) {
      _log.warning(_mucMutationRejectedLog);
      return true;
    }

    final mox.OccupantIdData? occupantData =
        event.extensions.get<mox.OccupantIdData>();
    final String? occupantId = occupantData?.id;
    return await _dbOpReturning<XmppDatabase, bool>(
      (db) async {
        if (await db.getMessageByOriginID(retraction.id) case final message?) {
          if (!message.authorizedForMutation(
            from: event.from,
            occupantId: occupantId,
          )) {
            return false;
          }
          await db.markMessageRetracted(message.stanzaID);
          return true;
        }
        return false;
      },
    );
  }

  Future<bool> _handleReactions(mox.MessageEvent event) async {
    final reactions = event.extensions.get<mox.MessageReactionsData>();
    if (reactions == null) return false;
    if (!_isGroupChatMutationAuthorized(event)) {
      _log.warning(_mucMutationRejectedLog);
      return true;
    }
    final sanitizedEmojis = reactions.emojis.clampReactionEmojis();
    if (reactions.emojis.isNotEmpty && sanitizedEmojis.isEmpty) {
      _log.fine('Dropping reactions with no valid emoji payload');
      return !event.displayable;
    }
    return await _dbOpReturning<XmppDatabase, bool>(
      (db) async {
        final message = await db.getMessageByStanzaID(reactions.messageId);
        if (message == null) {
          _log.fine(
            'Dropping reactions for unknown message ${reactions.messageId}',
          );
          return !event.displayable;
        }
        final bool isGroupChat = event.type == _messageTypeGroupchat;
        final String senderJid = isGroupChat
            ? event.from.toString()
            : event.from.toBare().toString();
        await db.replaceReactions(
          messageId: message.stanzaID,
          senderJid: senderJid,
          emojis: sanitizedEmojis,
        );
        return !event.displayable;
      },
    );
  }

  Future<bool> _handleCalendarSync(
    mox.MessageEvent event, {
    FileMetadataData? metadata,
  }) async {
    // Check if this is a calendar sync message by looking at the message body
    final messageText = event.text;
    if (messageText.isEmpty) return false;
    if (!isWithinUtf8ByteLimit(
      messageText,
      maxBytes: CalendarSyncMessage.maxEnvelopeLength,
    )) {
      _log.warning('Dropped calendar sync message exceeding size limits');
      return true;
    }

    final bool isGroupChat = event.type == _messageTypeGroupchat;
    final senderJid =
        isGroupChat ? event.from.toString() : event.from.toBare().toString();
    final selfJid = myJid;
    final chatJid = _calendarSyncChatJid(event, selfJid);
    final chatType = _calendarSyncChatType(event);
    final bool isSelfSender =
        selfJid != null && senderJid.toLowerCase() == selfJid.toLowerCase();
    final bool isSelfCalendar =
        selfJid != null && chatJid.toLowerCase() == selfJid.toLowerCase();

    final looksLikeCalendarSync = CalendarSyncMessage.looksLikeEnvelope(
      messageText,
    );
    final syncMessage = looksLikeCalendarSync
        ? CalendarSyncMessage.tryParseEnvelope(messageText)
        : null;
    if (syncMessage == null) {
      if (looksLikeCalendarSync) {
        _log.info('Dropped malformed calendar sync envelope');
        return true;
      }
      return false;
    }

    if (_isCalendarSyncRateLimited()) {
      _log.warning('Dropping calendar sync message due to rate limits');
      return true;
    }

    if (isSelfCalendar && !isSelfSender) {
      _log.warning('Rejected calendar sync message from unauthorized sender');
      return true;
    }
    if (!isSelfCalendar &&
        !_canApplyChatCalendarSync(
          syncMessage: syncMessage,
          event: event,
          chatJid: chatJid,
          chatType: chatType,
        )) {
      return true;
    }
    if (!isSelfCalendar &&
        _isReadOnlyTaskSyncBlocked(
          syncMessage: syncMessage,
          event: event,
          chatJid: chatJid,
        )) {
      _log.warning(_calendarSyncReadOnlyRejectedLog);
      return true;
    }

    _log.info('Received calendar sync message type: ${syncMessage.type}');

    // Handle snapshot messages by downloading and decoding the file
    if (_isSnapshotCalendarMessage(syncMessage)) {
      await _handleCalendarSnapshot(
        syncMessage,
        event,
        metadata: metadata,
        allowSelfDownload: isSelfSender,
        onMessageDecoded: (fullMessage, decodedEvent) async {
          if (isSelfCalendar) {
            return _invokeCalendarCallback(fullMessage, decodedEvent);
          }
          await _invokeChatCalendarCallback(
            fullMessage,
            decodedEvent,
            chatJid: chatJid,
            chatType: chatType,
            senderJid: senderJid,
          );
          return false;
        },
      );
      return true;
    }

    if (isSelfCalendar) {
      // Route to CalendarSyncManager for processing
      await _invokeCalendarCallback(syncMessage, event);
    } else {
      await _invokeChatCalendarCallback(
        syncMessage,
        event,
        chatJid: chatJid,
        chatType: chatType,
        senderJid: senderJid,
      );
    }

    return true; // Handled - don't process as regular chat message
  }

  bool _canApplyChatCalendarSync({
    required CalendarSyncMessage syncMessage,
    required mox.MessageEvent event,
    required String chatJid,
    required ChatType chatType,
  }) {
    final CalendarChatAcl acl = chatType.calendarDefaultAcl;
    final CalendarChatRole requiredRole =
        _calendarSyncRequiredRole(syncMessage, acl: acl);
    final CalendarChatRole? senderRole = _calendarSyncSenderRole(
      event,
      chatJid: chatJid,
      chatType: chatType,
    );
    if (senderRole == null) {
      if (event.isFromMAM) {
        _log.fine(_calendarSyncMamBypassLog);
        return true;
      }
      _log.warning(_calendarSyncMissingRoleLog);
      return false;
    }
    if (!senderRole.allows(requiredRole)) {
      _log.warning(_calendarSyncUnauthorizedLog);
      return false;
    }
    return true;
  }

  CalendarChatRole _calendarSyncRequiredRole(
    CalendarSyncMessage message, {
    required CalendarChatAcl acl,
  }) {
    switch (message.type) {
      case CalendarSyncType.request:
        return acl.read;
      case CalendarSyncType.update:
        final String operation =
            message.operation ?? _calendarSyncOperationUpdate;
        if (operation == _calendarSyncOperationDelete) {
          return acl.delete;
        }
        return acl.write;
      case CalendarSyncType.full:
      case CalendarSyncType.snapshot:
        return acl.write;
    }
    return acl.write;
  }

  CalendarChatRole? _calendarSyncSenderRole(
    mox.MessageEvent event, {
    required String chatJid,
    required ChatType chatType,
  }) {
    if (chatType != ChatType.groupChat) {
      return CalendarChatRole.participant;
    }
    final RoomState? roomState = roomStateFor(chatJid);
    if (roomState == null) {
      return null;
    }
    final Occupant? occupant = _calendarSyncOccupantForSender(
      event,
      roomState: roomState,
    );
    if (occupant == null) {
      return null;
    }
    return occupant.role.calendarChatRole;
  }

  Occupant? _calendarSyncOccupantForSender(
    mox.MessageEvent event, {
    required RoomState roomState,
  }) {
    return _mucOccupantForSender(event, roomState: roomState);
  }

  Occupant? _mucOccupantForSender(
    mox.MessageEvent event, {
    required RoomState roomState,
  }) {
    final sender = event.from.toString();
    final Occupant? direct = roomState.occupants[sender];
    if (direct != null) {
      return direct;
    }
    final String nick = event.from.resource;
    if (nick.isEmpty) {
      return null;
    }
    for (final occupant in roomState.occupants.values) {
      if (occupant.nick == nick) {
        return occupant;
      }
    }
    return null;
  }

  bool _isGroupChatMutationAuthorized(mox.MessageEvent event) {
    if (event.type != _messageTypeGroupchat) {
      return true;
    }
    if (event.isFromMAM) {
      return true;
    }
    final roomJid = event.from.toBare().toString();
    if (hasLeftRoom(roomJid)) {
      return false;
    }
    final RoomState? roomState = roomStateFor(roomJid);
    if (roomState == null) {
      return false;
    }
    final Occupant? occupant =
        _mucOccupantForSender(event, roomState: roomState);
    return occupant?.isPresent ?? false;
  }

  bool _isReadOnlyTaskSyncBlocked({
    required CalendarSyncMessage syncMessage,
    required mox.MessageEvent event,
    required String chatJid,
  }) {
    if (syncMessage.type != CalendarSyncType.update) {
      return false;
    }
    if (syncMessage.entity != _calendarSyncEntityTask) {
      return false;
    }
    final String? taskId = syncMessage.taskId?.trim();
    if (taskId == null || taskId.isEmpty) {
      return false;
    }
    final Map<String, String>? owners = _readOnlyTaskOwnersByChat[chatJid];
    if (owners == null || owners.isEmpty) {
      return false;
    }
    final String? owner = owners[taskId];
    if (owner == null || owner.trim().isEmpty) {
      return false;
    }
    final String senderIdentity = event.type == _messageTypeGroupchat
        ? event.from.toString()
        : event.from.toBare().toString();
    return !_calendarReadOnlyOwnerMatchesSender(
      senderJid: senderIdentity,
      ownerJid: owner,
    );
  }

  bool _calendarReadOnlyOwnerMatchesSender({
    required String senderJid,
    required String ownerJid,
  }) {
    final String sender = senderJid.trim();
    final String owner = ownerJid.trim();
    if (sender.isEmpty || owner.isEmpty) {
      return false;
    }
    try {
      final senderParsed = mox.JID.fromString(sender);
      final ownerParsed = mox.JID.fromString(owner);
      final String senderBare = senderParsed.toBare().toString().toLowerCase();
      final String ownerBare = ownerParsed.toBare().toString().toLowerCase();
      if (senderBare != ownerBare) {
        return false;
      }
      final String senderResource = senderParsed.resource.trim().toLowerCase();
      final String ownerResource = ownerParsed.resource.trim().toLowerCase();
      if (senderResource.isEmpty && ownerResource.isEmpty) {
        return true;
      }
      return senderResource == ownerResource;
    } on Exception {
      return sender.toLowerCase() == owner.toLowerCase();
    }
  }

  void _rememberReadOnlyTaskShare(Message message) {
    final CalendarTask? task = message.calendarTaskIcs;
    if (task == null) {
      return;
    }
    if (!message.calendarTaskIcsReadOnly) {
      return;
    }
    final String taskId = task.id.trim();
    if (taskId.isEmpty) {
      return;
    }
    final String chatJid = message.chatJid.trim();
    if (chatJid.isEmpty) {
      return;
    }
    final String owner = message.senderJid.trim();
    if (owner.isEmpty) {
      return;
    }
    final Map<String, String> owners = _readOnlyTaskOwnersByChat.putIfAbsent(
      chatJid,
      () => <String, String>{},
    );
    owners[taskId] = owner;
  }

  bool _isCalendarSyncRateLimited() {
    final now = DateTime.now();
    final windowStart = now.subtract(_calendarSyncInboundWindow);
    while (_calendarSyncInboundTimestamps.isNotEmpty &&
        _calendarSyncInboundTimestamps.first.isBefore(windowStart)) {
      _calendarSyncInboundTimestamps.removeFirst();
    }
    if (_calendarSyncInboundTimestamps.length >=
        _calendarSyncInboundMaxMessages) {
      return true;
    }
    _calendarSyncInboundTimestamps.addLast(now);
    return false;
  }

  bool _isSnapshotCalendarMessage(CalendarSyncMessage message) {
    if (message.type == CalendarSyncType.snapshot) {
      return true;
    }
    if (message.isSnapshot) {
      return true;
    }
    final url = message.snapshotUrl;
    if (url == null) {
      return false;
    }
    return url.trim().isNotEmpty;
  }

  Future<void> _handleCalendarSnapshot(
    CalendarSyncMessage syncMessage,
    mox.MessageEvent event, {
    FileMetadataData? metadata,
    required bool allowSelfDownload,
    required Future<bool> Function(
      CalendarSyncMessage fullMessage,
      mox.MessageEvent event,
    ) onMessageDecoded,
  }) async {
    final url = syncMessage.snapshotUrl;
    final hasUrl = url != null && url.trim().isNotEmpty;
    final inlineData = syncMessage.data;
    final hasInlineData = inlineData != null && inlineData.isNotEmpty;
    if (!hasUrl && metadata == null && hasInlineData) {
      final resolvedChecksum =
          syncMessage.snapshotChecksum ?? syncMessage.checksum;
      final inlineMessage = syncMessage.copyWith(
        type: CalendarSyncType.snapshot,
        isSnapshot: true,
        snapshotChecksum: resolvedChecksum,
      );
      final applied = await onMessageDecoded(inlineMessage, event);
      if (applied && _calendarMamRehydrateInFlight) {
        _calendarMamSnapshotSeen = true;
      }
      return;
    }
    if (!hasUrl && metadata == null) {
      _log.warning('Snapshot message missing URL');
      await _maybeNotifySnapshotUnavailable(event);
      return;
    }

    try {
      final bool? allowSelfOverride =
          allowSelfDownload ? allowSelfDownload : null;
      final decoded = await _decodeSnapshotFromAttachment(
        url ?? '',
        metadata: metadata,
        allowHttpOverride: allowSelfOverride,
        allowInsecureHostsOverride: allowSelfOverride,
        allowRemoteDownload: allowSelfDownload,
      );
      if (decoded == null) {
        _log.warning(_calendarSnapshotDecodeFailedMessage);
        await _maybeNotifySnapshotUnavailable(event);
        return;
      }

      if (!CalendarSnapshotCodec.verifyChecksum(decoded)) {
        _log.warning(_calendarSnapshotChecksumFailedMessage);
        await _maybeNotifySnapshotUnavailable(event);
        return;
      }

      final expectedChecksum = syncMessage.snapshotChecksum;
      if (expectedChecksum != null && expectedChecksum != decoded.checksum) {
        _log.warning(_calendarSnapshotChecksumMismatchMessage);
        await _maybeNotifySnapshotUnavailable(event);
        return;
      }

      // Synthesize a full calendar message with the decoded model data
      final fullMessage = CalendarSyncMessage(
        type: CalendarSyncType.snapshot,
        data: decoded.model.toJson(),
        checksum: decoded.checksum,
        timestamp: syncMessage.timestamp,
        isSnapshot: true,
        snapshotChecksum: decoded.checksum,
        snapshotVersion: decoded.version,
        snapshotUrl: url ?? metadata?.sourceUrls?.first,
      );

      final applied = await onMessageDecoded(fullMessage, event);
      if (applied && _calendarMamRehydrateInFlight) {
        _calendarMamSnapshotSeen = true;
      }
    } catch (e) {
      _log.warning('Failed to process calendar snapshot: $e');
    }
  }

  Future<CalendarSnapshotResult?> _decodeSnapshotFromAttachment(
    String url, {
    FileMetadataData? metadata,
    bool? allowHttpOverride,
    bool? allowInsecureHostsOverride,
    required bool allowRemoteDownload,
  }) async {
    if (metadata != null) {
      final decoded = await _decodeSnapshotFromMetadata(
        metadata,
        allowHttpOverride: allowHttpOverride,
        allowInsecureHostsOverride: allowInsecureHostsOverride,
        allowRemoteDownload: allowRemoteDownload,
      );
      if (decoded != null) {
        return decoded;
      }
    }
    if (!allowRemoteDownload) {
      return null;
    }
    return _downloadAndDecodeSnapshot(
      url,
      allowHttpOverride: allowHttpOverride,
      allowInsecureHostsOverride: allowInsecureHostsOverride,
    );
  }

  Future<CalendarSnapshotResult?> _decodeSnapshotFromMetadata(
    FileMetadataData metadata, {
    bool? allowHttpOverride,
    bool? allowInsecureHostsOverride,
    required bool allowRemoteDownload,
  }) async {
    await _dbOp<XmppDatabase>(
      (db) => db.saveFileMetadata(metadata),
    );
    final existingPath = metadata.path?.trim();
    final existingFile = existingPath == null || existingPath.isEmpty
        ? null
        : File(existingPath);
    if (existingFile?.existsSync() ?? false) {
      return CalendarSnapshotCodec.decodeFile(existingFile!);
    }
    if (!allowRemoteDownload) {
      return null;
    }
    final path = await downloadInboundAttachment(
      metadataId: metadata.id,
      allowHttpOverride: allowHttpOverride,
      allowInsecureHostsOverride: allowInsecureHostsOverride,
    );
    if (path == null) return null;
    final file = File(path);
    return CalendarSnapshotCodec.decodeFile(file);
  }

  Future<CalendarSnapshotResult?> _downloadAndDecodeSnapshot(
    String url, {
    bool? allowHttpOverride,
    bool? allowInsecureHostsOverride,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return null;

    File? tmpFile;
    try {
      final directory = await _attachmentCacheDirectory();
      final fileName = '.snapshot_${DateTime.now().millisecondsSinceEpoch}.tmp';
      tmpFile = File(p.join(directory.path, fileName));

      const maxBytes = _calendarSnapshotDownloadMaxBytes;
      const allowInsecureDownloads =
          !kReleaseMode && kAllowInsecureXmppAttachmentDownloads;
      final allowHttpOverrideEnabled = allowHttpOverride == true;
      final allowInsecureHostsOverrideEnabled =
          allowInsecureHostsOverride == true;
      final allowHttp =
          !kReleaseMode && (allowHttpOverrideEnabled || allowInsecureDownloads);
      final allowInsecureHosts = !kReleaseMode &&
          (allowInsecureHostsOverrideEnabled || allowInsecureDownloads);
      await _downloadUrlToFile(
        uri: uri,
        destination: tmpFile,
        maxBytes: maxBytes,
        allowHttp: allowHttp,
        allowInsecureHosts: allowInsecureHosts,
      );

      final bytes = await tmpFile.readAsBytes();
      return CalendarSnapshotCodec.decode(bytes);
    } finally {
      if (tmpFile != null && await tmpFile.exists()) {
        await tmpFile.delete();
      }
    }
  }

  Future<bool> _invokeCalendarCallback(
    CalendarSyncMessage syncMessage,
    mox.MessageEvent event,
  ) async {
    if (owner is XmppService &&
        (owner as XmppService)._calendarSyncCallback != null) {
      try {
        final callback = (owner as XmppService)._calendarSyncCallback!;
        final inbound = CalendarSyncInbound(
          message: syncMessage,
          stanzaId: _calendarSyncStanzaId(event),
          receivedAt: _calendarSyncTimestamp(event),
          isFromMam: event.isFromMAM,
        );
        final applied = await callback(inbound);
        unawaited(_acknowledgeMessage(event));
        return applied;
      } catch (e) {
        _log.warning('Calendar sync callback failed: $e');
        return false;
      }
    }
    _log.info('No calendar sync callback registered - message ignored');
    return false;
  }

  Future<void> _maybeNotifySnapshotUnavailable(mox.MessageEvent event) async {
    if (!_calendarMamRehydrateInFlight && !event.isFromMAM) {
      return;
    }
    await _emitCalendarSnapshotWarning();
  }

  Future<void> _emitCalendarSnapshotWarning() async {
    if (_calendarMamSnapshotUnavailableNotified) {
      return;
    }
    _calendarMamSnapshotUnavailableNotified = true;
    if (owner is XmppService &&
        (owner as XmppService)._calendarSyncWarningCallback != null) {
      const warning = CalendarSyncWarning(
        title: calendarSnapshotUnavailableWarningTitle,
        message: calendarSnapshotUnavailableWarningMessage,
      );
      try {
        await (owner as XmppService)._calendarSyncWarningCallback!(warning);
      } catch (e) {
        _log.warning('Calendar sync warning callback failed: $e');
      }
    }
  }

  Future<void> _requestCalendarSnapshotFallback(String jid) async {
    if (connectionState != ConnectionState.connected) return;
    final syncMessage = CalendarSyncMessage.request();
    final messageJson = jsonEncode({
      'calendar_sync': syncMessage.toJson(),
    });
    try {
      await sendCalendarSyncMessage(
        jid: jid,
        outbound: CalendarSyncOutbound(envelope: messageJson),
      );
    } catch (e) {
      _log.warning('$_calendarSnapshotFallbackRequestFailedMessage: $e');
    }
  }

  Future<void> _invokeChatCalendarCallback(
    CalendarSyncMessage syncMessage,
    mox.MessageEvent event, {
    required String chatJid,
    required ChatType chatType,
    required String senderJid,
  }) async {
    if (owner is XmppService &&
        (owner as XmppService)._chatCalendarSyncCallback != null) {
      try {
        final inbound = CalendarSyncInbound(
          message: syncMessage,
          stanzaId: _calendarSyncStanzaId(event),
          receivedAt: _calendarSyncTimestamp(event),
          isFromMam: event.isFromMAM,
        );
        final envelope = ChatCalendarSyncEnvelope(
          chatJid: chatJid,
          chatType: chatType,
          senderJid: senderJid,
          inbound: inbound,
        );
        await (owner as XmppService)._chatCalendarSyncCallback!(envelope);
        unawaited(_acknowledgeMessage(event));
      } catch (e) {
        _log.warning('Chat calendar sync callback failed: $e');
      }
    } else {
      _log.info('No chat calendar sync callback registered - message ignored');
    }
  }

  String? _calendarSyncStanzaId(mox.MessageEvent event) {
    final stableIdData = event.extensions.get<mox.StableIdData>();
    final stanzaIds = stableIdData?.stanzaIds;
    if (stanzaIds != null && stanzaIds.isNotEmpty) {
      return stanzaIds.first.id;
    }
    return event.id;
  }

  DateTime? _calendarSyncTimestamp(mox.MessageEvent event) {
    return event.extensions.get<mox.DelayedDeliveryData>()?.timestamp;
  }

  String _calendarSyncChatJid(mox.MessageEvent event, String? accountJid) {
    final isGroupChat = event.type == 'groupchat';
    final to = event.to.toBare().toString();
    final from = event.from.toBare().toString();
    if (isGroupChat) {
      return from;
    }
    if (accountJid != null && accountJid.isNotEmpty) {
      if (from.toLowerCase() == accountJid.toLowerCase()) {
        return to;
      }
    }
    return from;
  }

  ChatType _calendarSyncChatType(mox.MessageEvent event) {
    return event.type == 'groupchat' ? ChatType.groupChat : ChatType.chat;
  }

  /// Rehydrates calendar data from MAM (Message Archive Management).
  ///
  /// Queries MAM for recent self-messages containing calendar sync data.
  /// Messages are processed through normal event handlers, which invoke
  /// the calendar sync callback for each valid sync message found.
  ///
  /// Returns true if MAM query was successful.
  Future<bool> rehydrateCalendarFromMam() async {
    final selfJid = myJid;
    if (selfJid == null) {
      _log.warning('Cannot rehydrate calendar: no self JID available');
      return false;
    }
    if (_calendarMamRehydrateInFlight) {
      return false;
    }

    final mamSupported = await resolveMamSupport();
    if (!mamSupported) {
      _log.info('MAM not supported, skipping calendar rehydration');
      return false;
    }

    _log.info('Starting calendar rehydration from MAM');

    try {
      _calendarMamRehydrateInFlight = true;
      _calendarMamSnapshotSeen = false;
      _calendarMamSnapshotUnavailableNotified = false;
      final state = CalendarSyncState.read();
      final lastApplied = state.lastAppliedTimestamp;
      if (lastApplied != null) {
        await _catchUpCalendarFromArchive(
          jid: selfJid,
          since: lastApplied,
        );
        _log.info('Calendar rehydration catch-up complete');
        return true;
      }

      await _backfillCalendarFromArchive(jid: selfJid);
      if (!_calendarMamSnapshotSeen) {
        await _emitCalendarSnapshotWarning();
        await _requestCalendarSnapshotFallback(selfJid);
      }
      _log.info('Calendar rehydration query complete');
      return true;
    } on Exception catch (e) {
      _log.warning('Calendar rehydration failed: $e');
      return false;
    } finally {
      _calendarMamRehydrateInFlight = false;
      _calendarMamSnapshotSeen = false;
      _calendarMamSnapshotUnavailableNotified = false;
    }
  }

  Future<void> _catchUpCalendarFromArchive({
    required String jid,
    required DateTime since,
  }) async {
    String? afterId;
    while (true) {
      if (connectionState != ConnectionState.connected) return;
      final result = await fetchSinceFromArchive(
        jid: jid,
        since: since,
        pageSize: _calendarMamPageSize,
        isMuc: false,
        after: afterId,
      );
      final nextAfter = result.lastId ?? afterId;
      if (result.complete || nextAfter == null || nextAfter == afterId) {
        break;
      }
      afterId = nextAfter;
    }
  }

  Future<void> _backfillCalendarFromArchive({required String jid}) async {
    String? beforeId;
    while (true) {
      if (connectionState != ConnectionState.connected) return;
      final result = beforeId == null
          ? await fetchLatestFromArchive(
              jid: jid,
              pageSize: _calendarMamPageSize,
              isMuc: false,
            )
          : await fetchBeforeFromArchive(
              jid: jid,
              before: beforeId,
              pageSize: _calendarMamPageSize,
              isMuc: false,
            );
      if (_calendarMamSnapshotSeen || result.complete) {
        break;
      }
      final nextBefore = result.firstId ?? result.lastId ?? beforeId;
      if (nextBefore == null || nextBefore == beforeId) {
        break;
      }
      beforeId = nextBefore;
    }
  }

  Future<void> _handleFile(mox.MessageEvent event, String jid) async {}

  Stream<List<Message>> _combineMessageAndReactionStreams({
    required Stream<List<Message>> messageStream,
    required Stream<List<Reaction>> reactionStream,
    required List<Message> initialMessages,
    required List<Reaction> initialReactions,
  }) {
    final controller = StreamController<List<Message>>.broadcast();
    StreamSubscription<List<Message>>? messageSubscription;
    StreamSubscription<List<Reaction>>? reactionSubscription;
    var listeners = 0;
    var closed = false;
    var currentMessages = initialMessages;
    var currentReactions = initialReactions;

    void emit() {
      if (!controller.hasListener) return;
      controller.add(
        _applyReactionPreviews(currentMessages, currentReactions),
      );
    }

    void start() {
      emit();
      messageSubscription = messageStream.listen((messages) {
        currentMessages = messages;
        emit();
      });
      reactionSubscription = reactionStream.listen((reactions) {
        currentReactions = reactions;
        emit();
      });
    }

    Future<void> stop() async {
      if (closed) return;
      closed = true;
      await messageSubscription?.cancel();
      await reactionSubscription?.cancel();
      await controller.close();
    }

    controller.onListen = () {
      listeners++;
      if (listeners == 1) {
        start();
      } else {
        emit();
      }
    };

    controller.onCancel = () async {
      listeners--;
      if (listeners <= 0) {
        await stop();
      }
    };

    return controller.stream;
  }

  List<Message> _applyReactionPreviews(
    List<Message> messages,
    List<Reaction> reactions,
  ) {
    if (messages.isEmpty) return messages;
    final allowedIds = <String>{};
    for (final message in messages) {
      allowedIds.add(message.stanzaID);
    }
    if (allowedIds.isEmpty || reactions.isEmpty) {
      return messages
          .map(
            (message) => message.reactionsPreview.isEmpty
                ? message
                : message.copyWith(reactionsPreview: const []),
          )
          .toList();
    }
    final grouped = <String, Map<String, _ReactionBucket>>{};
    final selfJid = myJid;
    for (final reaction in reactions) {
      if (!allowedIds.contains(reaction.messageID)) continue;
      final buckets = grouped.putIfAbsent(
        reaction.messageID,
        () => <String, _ReactionBucket>{},
      );
      final bucket = buckets.putIfAbsent(
        reaction.emoji,
        () => _ReactionBucket(reaction.emoji),
      );
      bucket.add(reaction.senderJid, selfJid);
    }
    return messages.map((message) {
      final id = message.stanzaID;
      final buckets = grouped[id];
      if (buckets == null || buckets.isEmpty) {
        return message.reactionsPreview.isEmpty
            ? message
            : message.copyWith(reactionsPreview: const []);
      }
      final previews =
          buckets.values.map((bucket) => bucket.toPreview()).toList()
            ..sort((a, b) {
              final countCompare = b.count.compareTo(a.count);
              if (countCompare != 0) return countCompare;
              return a.emoji.compareTo(b.emoji);
            });
      return message.copyWith(reactionsPreview: previews);
    }).toList();
  }

  FileMetadataData? _extractFileMetadata(mox.MessageEvent event) {
    final fun = event.extensions.get<mox.FileUploadNotificationData>();
    final statelessData = event.extensions.get<mox.StatelessFileSharingData>();
    final oob = event.extensions.get<mox.OOBData>();
    final oobUrl = _sanitizeAttachmentUrl(oob?.url);
    final oobDesc = oob?.desc?.trim();
    final oobName = oobDesc?.isNotEmpty == true
        ? _sanitizeAttachmentFilename(oobDesc!)
        : null;
    if (statelessData == null || statelessData.sources.isEmpty) {
      if (fun != null) {
        final name = fun.metadata.name;
        final fallbackName =
            oobName ?? (oobUrl == null ? null : _filenameFromUrl(oobUrl));
        final resolvedName = _sanitizeAttachmentFilename(
          name ?? fallbackName ?? _attachmentFallbackName,
        );
        final mimeType = _sanitizeAttachmentMimeType(fun.metadata.mediaType);
        return FileMetadataData(
          id: uuid.v4(),
          sourceUrls: oobUrl == null ? null : [oobUrl],
          filename: resolvedName,
          mimeType: mimeType,
          sizeBytes: fun.metadata.size,
          width: fun.metadata.width,
          height: fun.metadata.height,
          plainTextHashes: fun.metadata.hashes,
        );
      }
      if (oobUrl != null) {
        return FileMetadataData(
          id: uuid.v4(),
          sourceUrls: [oobUrl],
          filename: _sanitizeAttachmentFilename(
            oobName ?? _filenameFromUrl(oobUrl),
          ),
        );
      }
      return null;
    }
    final encryptedSources = statelessData.sources
        .whereType<mox.StatelessFileSharingEncryptedSource>()
        .toList(growable: false);
    if (encryptedSources.isNotEmpty) {
      String? encryptedUrl;
      mox.StatelessFileSharingEncryptedSource? encryptedSource;
      for (final source in encryptedSources) {
        final sanitizedUrl = _sanitizeAttachmentUrl(source.source.url);
        if (sanitizedUrl == null) {
          continue;
        }
        encryptedUrl = sanitizedUrl;
        encryptedSource = source;
        break;
      }
      if (encryptedUrl != null && encryptedSource != null) {
        final resolvedName = _sanitizeAttachmentFilename(
          statelessData.metadata.name ?? p.basename(encryptedUrl),
        );
        final mimeType =
            _sanitizeAttachmentMimeType(statelessData.metadata.mediaType);
        return FileMetadataData(
          id: uuid.v4(),
          sourceUrls: [encryptedUrl],
          filename: resolvedName,
          mimeType: mimeType,
          encryptionKey: base64Encode(encryptedSource.key),
          encryptionIV: base64Encode(encryptedSource.iv),
          encryptionScheme: encryptedSource.encryption.toNamespace(),
          cipherTextHashes: encryptedSource.hashes,
          plainTextHashes: statelessData.metadata.hashes,
          sizeBytes: statelessData.metadata.size,
          width: statelessData.metadata.width,
          height: statelessData.metadata.height,
        );
      }
    }
    final urls = <String>[];
    var exceededSourceLimit = false;
    for (final source in statelessData.sources
        .whereType<mox.StatelessFileSharingUrlSource>()) {
      if (urls.length >= _attachmentSourceMaxCount) {
        exceededSourceLimit = true;
        break;
      }
      final sanitizedUrl = _sanitizeAttachmentUrl(source.url);
      if (sanitizedUrl == null) {
        continue;
      }
      urls.add(sanitizedUrl);
    }
    if (exceededSourceLimit) {
      _log.warning('Attachment source list exceeded safe limits');
    }
    if (urls.isNotEmpty) {
      final resolvedName = _sanitizeAttachmentFilename(
        statelessData.metadata.name ?? p.basename(urls.first),
      );
      final mimeType =
          _sanitizeAttachmentMimeType(statelessData.metadata.mediaType);
      return FileMetadataData(
        id: uuid.v4(),
        sourceUrls: urls,
        filename: resolvedName,
        mimeType: mimeType,
        sizeBytes: statelessData.metadata.size,
        width: statelessData.metadata.width,
        height: statelessData.metadata.height,
        plainTextHashes: statelessData.metadata.hashes,
      );
    }
    if (oobUrl != null) {
      return FileMetadataData(
        id: uuid.v4(),
        sourceUrls: [oobUrl],
        filename: _sanitizeAttachmentFilename(
          oobName ?? _filenameFromUrl(oobUrl),
        ),
      );
    }
    return null;
  }

  String _filenameFromUrl(String url) {
    final uri = Uri.tryParse(url);
    final segments = uri?.pathSegments;
    final candidate = segments != null && segments.isNotEmpty
        ? segments.last
        : p.basename(url);
    final normalized = p.basename(candidate).trim();
    return normalized.isEmpty ? _attachmentFallbackName : normalized;
  }

  Stream<FileMetadataData?> fileMetadataStream(String id) =>
      createSingleItemStream<FileMetadataData?, XmppDatabase>(
        watchFunction: (db) async {
          final stream = db.watchFileMetadata(id);
          final initial = await db.getFileMetadata(id);
          return stream.startWith(initial);
        },
      );

  Future<String?> downloadInboundAttachment({
    required String metadataId,
    String? stanzaId,
    bool? allowHttpOverride,
    bool? allowInsecureHostsOverride,
  }) async {
    final existing = _inboundAttachmentDownloads[metadataId];
    if (existing != null) return await existing;
    final future = _downloadInboundAttachment(
      metadataId: metadataId,
      stanzaId: stanzaId,
      allowHttpOverride: allowHttpOverride,
      allowInsecureHostsOverride: allowInsecureHostsOverride,
    );
    _inboundAttachmentDownloads[metadataId] = future;
    try {
      return await future;
    } finally {
      if (_inboundAttachmentDownloads[metadataId] == future) {
        _inboundAttachmentDownloads.remove(metadataId);
      }
    }
  }

  Future<String?> _downloadInboundAttachment({
    required String metadataId,
    String? stanzaId,
    bool? allowHttpOverride,
    bool? allowInsecureHostsOverride,
  }) async {
    File? tmpFile;
    File? decryptedTmp;
    try {
      final metadata = await _dbOpReturning<XmppDatabase, FileMetadataData?>(
        (db) => db.getFileMetadata(metadataId),
      );
      if (metadata == null) return null;

      final existingPath = metadata.path?.trim();
      if (existingPath != null && existingPath.isNotEmpty) {
        final existingFile = File(existingPath);
        if (await existingFile.exists()) return existingFile.path;
      }

      final urls = metadata.sourceUrls;
      final url = urls == null || urls.isEmpty ? null : urls.first.trim();
      if (url == null || url.isEmpty) {
        throw XmppMessageException();
      }

      final uri = Uri.tryParse(url);
      if (uri == null) {
        throw XmppMessageException();
      }
      final scheme = uri.scheme.toLowerCase();
      if (scheme != 'http' && scheme != 'https') {
        throw XmppMessageException();
      }
      if (uri.userInfo.trim().isNotEmpty) {
        throw XmppMessageException();
      }
      if (uri.host.trim().isEmpty) {
        throw XmppMessageException();
      }

      final encrypted = metadata.encryptionScheme?.isNotEmpty == true;
      final hasPlainHash = _hasExpectedSha256Hash(metadata.plainTextHashes);
      final hasCipherHash = _hasExpectedSha256Hash(metadata.cipherTextHashes);
      if (encrypted && !hasPlainHash && !hasCipherHash) {
        throw XmppMessageException();
      }
      const allowInsecureDownloads =
          !kReleaseMode && kAllowInsecureXmppAttachmentDownloads;
      final allowHttpOverrideEnabled = allowHttpOverride == true;
      final allowInsecureHostsOverrideEnabled =
          allowInsecureHostsOverride == true;
      final resolvedAllowHttp =
          !kReleaseMode && (allowHttpOverrideEnabled || allowInsecureDownloads);
      final resolvedAllowInsecureHosts = !kReleaseMode &&
          (allowInsecureHostsOverrideEnabled || allowInsecureDownloads);

      await _validateInboundAttachmentDownloadUri(
        uri,
        allowHttp: resolvedAllowHttp,
        allowInsecureHosts: resolvedAllowInsecureHosts,
      );

      final directory = await _attachmentCacheDirectory();
      final safeFileName = _attachmentFileName(metadata);
      final finalFile = File(p.join(directory.path, safeFileName));
      tmpFile = File(p.join(directory.path, '.${metadata.id}.download'));
      final maxBytes = _attachmentDownloadLimitBytes(metadata);
      final expectedSize = metadata.sizeBytes;
      if (expectedSize != null && expectedSize > 0 && expectedSize > maxBytes) {
        throw XmppFileTooBigException(maxBytes);
      }
      final responseMimeType = await _downloadUrlToFile(
        uri: uri,
        destination: tmpFile,
        maxBytes: maxBytes,
        allowHttp: resolvedAllowHttp,
        allowInsecureHosts: resolvedAllowInsecureHosts,
      );

      late final int resolvedSizeBytes;
      if (encrypted) {
        final cipherBytes = await tmpFile.readAsBytes();
        await _verifySha256Hash(
          expected: metadata.cipherTextHashes,
          bytes: cipherBytes,
        );
        final plainBytes = await _decryptAttachmentBytes(
          metadata: metadata,
          cipherBytes: cipherBytes,
        );
        await _verifySha256Hash(
          expected: metadata.plainTextHashes,
          bytes: plainBytes,
        );
        resolvedSizeBytes = plainBytes.length;
        decryptedTmp =
            File(p.join(directory.path, '.${metadata.id}.decrypted'));
        await decryptedTmp.writeAsBytes(plainBytes, flush: true);
        await _replaceFile(source: decryptedTmp, destination: finalFile);
        decryptedTmp = null;
      } else {
        await _verifySha256HashForFile(
          expected: metadata.plainTextHashes,
          file: tmpFile,
        );
        await _replaceFile(source: tmpFile, destination: finalFile);
        tmpFile = null;
        resolvedSizeBytes = await finalFile.length();
      }

      final resolvedMime = metadata.mimeType?.trim().isNotEmpty == true
          ? metadata.mimeType
          : responseMimeType?.trim().isNotEmpty == true
              ? responseMimeType
              : null;
      final updatedMetadata = metadata.copyWith(
        path: finalFile.path,
        mimeType: resolvedMime,
        sizeBytes: resolvedSizeBytes,
      );
      await _dbOp<XmppDatabase>(
        (db) => db.saveFileMetadata(updatedMetadata),
        awaitDatabase: true,
      );
      unawaited(
        _enforceAttachmentCacheLimit(exemptPaths: {finalFile.path}),
      );
      return finalFile.path;
    } on XmppAbortedException {
      return null;
    } on XmppException catch (_) {
      if (stanzaId != null) {
        await _dbOp<XmppDatabase>(
          (db) => db.saveMessageError(
            stanzaID: stanzaId,
            error: MessageError.fileDownloadFailure,
          ),
          awaitDatabase: true,
        );
      }
      rethrow;
    } on Exception {
      if (stanzaId != null) {
        await _dbOp<XmppDatabase>(
          (db) => db.saveMessageError(
            stanzaID: stanzaId,
            error: MessageError.fileDownloadFailure,
          ),
          awaitDatabase: true,
        );
      }
      throw XmppMessageException();
    } finally {
      try {
        await tmpFile?.delete();
      } on Exception {
        // Ignore cleanup failures.
      }
      try {
        await decryptedTmp?.delete();
      } on Exception {
        // Ignore cleanup failures.
      }
    }
  }

  int _attachmentDownloadLimitBytes(FileMetadataData metadata) {
    final limit = httpUploadSupport.maxFileSizeBytes;
    if (limit != null && limit > 0) return limit;
    return _xmppAttachmentDownloadLimitFallbackBytes;
  }

  String _resolveAttachmentCachePrefix() {
    final prefix = _databasePrefix?.trim();
    if (prefix != null && prefix.isNotEmpty) {
      return prefix;
    }
    final cached = _attachmentCacheSessionPrefix;
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    final generated = [
      _attachmentCacheSessionPrefixLabel,
      uuid.v4(),
    ].join(_attachmentCacheSessionPrefixSeparator);
    _attachmentCacheSessionPrefix = generated;
    return generated;
  }

  Future<Directory> _attachmentCacheDirectory() async {
    final cached = _attachmentDirectory;
    if (cached != null && await cached.exists()) {
      return cached;
    }
    final supportDir = await getApplicationSupportDirectory();
    final prefix = _resolveAttachmentCachePrefix();
    final normalizedPrefix = prefix.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final directory = Directory(
      p.join(supportDir.path, 'attachments', normalizedPrefix),
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    _attachmentDirectory = directory;
    return directory;
  }

  Future<void> _enforceAttachmentCacheLimit({
    Set<String> exemptPaths = const <String>{},
  }) async {
    if (_attachmentCacheMaxBytes <= _attachmentCacheEmptyByteCount) {
      return;
    }
    final Directory directory;
    try {
      directory = await _attachmentCacheDirectory();
    } on Exception {
      return;
    }
    if (!await directory.exists()) {
      return;
    }
    final normalizedExempt = <String>{}..addAll(
        exemptPaths
            .map((path) => p.normalize(path.trim()))
            .where((path) => path.isNotEmpty),
      );
    final entries = <_AttachmentCacheEntry>[];
    var totalBytes = _attachmentCacheEmptyByteCount;
    await for (final entity in directory.list(
      followLinks: _attachmentCacheFollowLinks,
    )) {
      if (entity is! File) continue;
      final path = p.normalize(entity.path);
      if (normalizedExempt.contains(path)) {
        continue;
      }
      final baseName = p.basename(path);
      if (baseName.startsWith(_attachmentCacheTempPrefix)) {
        continue;
      }
      FileStat stat;
      try {
        stat = await entity.stat();
      } on Exception {
        continue;
      }
      final size = stat.size;
      if (size <= _attachmentCacheEmptyByteCount) {
        continue;
      }
      totalBytes += size;
      entries.add(
        _AttachmentCacheEntry(
          file: entity,
          sizeBytes: size,
          lastModified: stat.modified,
        ),
      );
    }
    if (totalBytes <= _attachmentCacheMaxBytes) {
      return;
    }
    entries.sort((a, b) => a.lastModified.compareTo(b.lastModified));
    var remainingBytes = totalBytes;
    for (final entry in entries) {
      if (remainingBytes <= _attachmentCacheMaxBytes) {
        break;
      }
      try {
        await entry.file.delete();
        remainingBytes -= entry.sizeBytes;
      } on Exception {
        continue;
      }
    }
  }

  String _attachmentFileName(FileMetadataData metadata) {
    final sanitized = _sanitizeAttachmentFilename(metadata.filename);
    return '${metadata.id}_$sanitized';
  }

  @visibleForTesting
  String sanitizeAttachmentFilenameForTest(String filename) =>
      _sanitizeAttachmentFilename(filename);

  @visibleForTesting
  String buildAttachmentFileNameForTest(FileMetadataData metadata) =>
      _attachmentFileName(metadata);

  String _sanitizeAttachmentFilename(String filename) {
    final base = p.basename(filename).trim();
    if (base.isEmpty) return _attachmentFallbackName;
    final strippedSeparators = base.replaceAll(RegExp(r'[\\/]'), '_');
    final collapsedWhitespace =
        strippedSeparators.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsedWhitespace.isEmpty) return _attachmentFallbackName;
    final safe = collapsedWhitespace.replaceAll(
      RegExp(r'[^a-zA-Z0-9._() \[\]-]'),
      '_',
    );
    final normalized = safe.trim();
    if (normalized.isEmpty) return _attachmentFallbackName;
    if (normalized.length <= _attachmentMaxFilenameLength) return normalized;
    final extension = p.extension(normalized);
    final baseName = p.basenameWithoutExtension(normalized);
    final maxBase = _attachmentMaxFilenameLength - extension.length;
    if (maxBase <= 0) {
      return normalized.substring(0, _attachmentMaxFilenameLength);
    }
    return '${baseName.substring(0, maxBase)}$extension';
  }

  String? _sanitizeAttachmentMimeType(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    if (trimmed.length > _attachmentMaxMimeTypeLength) {
      return null;
    }
    return trimmed;
  }

  String? _sanitizeAttachmentUrl(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    if (trimmed.length > _attachmentMaxUrlLength) {
      return null;
    }
    return trimmed;
  }

  Future<void> _replaceFile({
    required File source,
    required File destination,
  }) async {
    if (await destination.exists()) {
      await destination.delete();
    }
    await source.rename(destination.path);
  }

  Future<String?> _downloadUrlToFile({
    required Uri uri,
    required File destination,
    required int maxBytes,
    required bool allowHttp,
    required bool allowInsecureHosts,
  }) async {
    final client = HttpClient()..connectionTimeout = _httpAttachmentGetTimeout;
    try {
      var redirects = 0;
      var current = uri;
      while (true) {
        await _validateInboundAttachmentDownloadUri(
          current,
          allowHttp: allowHttp,
          allowInsecureHosts: allowInsecureHosts,
        );
        final request =
            await client.getUrl(current).timeout(_httpAttachmentGetTimeout)
              ..followRedirects = false
              ..maxRedirects = 0;
        final response =
            await request.close().timeout(_httpAttachmentGetTimeout);
        final statusCode = response.statusCode;

        if (_isHttpRedirectStatusCode(statusCode)) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          await response.listen((_) {}).cancel();
          if (location == null || location.trim().isEmpty) {
            throw XmppMessageException();
          }
          if (redirects >= _xmppAttachmentDownloadMaxRedirects) {
            throw XmppMessageException();
          }
          final redirected = current.resolve(location.trim());
          final redirectedScheme = redirected.scheme.toLowerCase();
          if (current.scheme.toLowerCase() == 'https' &&
              redirectedScheme == 'http') {
            throw XmppMessageException();
          }
          current = redirected;
          redirects += 1;
          continue;
        }

        final success = statusCode >= 200 && statusCode < 300;
        if (!success) {
          throw XmppMessageException();
        }

        final mimeType = response.headers.contentType?.mimeType;
        final responseLength = response.contentLength;
        if (responseLength != -1 && responseLength > maxBytes) {
          throw XmppFileTooBigException(maxBytes);
        }
        final sink = destination.openWrite();
        var received = 0;
        try {
          await for (final chunk
              in response.timeout(_httpAttachmentGetTimeout)) {
            received += chunk.length;
            if (received > maxBytes) {
              throw XmppFileTooBigException(maxBytes);
            }
            sink.add(chunk);
          }
        } finally {
          await sink.close();
        }
        return mimeType;
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _validateInboundAttachmentDownloadUri(
    Uri uri, {
    required bool allowHttp,
    required bool allowInsecureHosts,
  }) async {
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      throw XmppMessageException();
    }
    if (scheme == 'http' && !allowHttp) {
      throw XmppMessageException();
    }
    if (uri.userInfo.trim().isNotEmpty) {
      throw XmppMessageException();
    }
    final host = uri.host.trim();
    if (host.isEmpty) {
      throw XmppMessageException();
    }
    if (!allowInsecureHosts) {
      final safe = await isSafeHostForRemoteConnection(host)
          .timeout(_httpAttachmentGetTimeout);
      if (!safe) {
        throw XmppMessageException();
      }
    }
  }

  bool _isHttpRedirectStatusCode(int statusCode) => switch (statusCode) {
        HttpStatus.movedPermanently ||
        HttpStatus.found ||
        HttpStatus.seeOther ||
        HttpStatus.temporaryRedirect ||
        HttpStatus.permanentRedirect =>
          true,
        _ => false,
      };

  Future<Uint8List> _decryptAttachmentBytes({
    required FileMetadataData metadata,
    required List<int> cipherBytes,
  }) async {
    final scheme = metadata.encryptionScheme?.trim();
    final keyEncoded = metadata.encryptionKey?.trim();
    final ivEncoded = metadata.encryptionIV?.trim();
    if (scheme == null ||
        scheme.isEmpty ||
        keyEncoded == null ||
        keyEncoded.isEmpty ||
        ivEncoded == null ||
        ivEncoded.isEmpty) {
      throw XmppMessageException();
    }
    final keyBytes = base64Decode(keyEncoded);
    final ivBytes = base64Decode(ivEncoded);
    switch (scheme) {
      case mox.sfsEncryptionAes128GcmNoPaddingXmlns:
      case mox.sfsEncryptionAes256GcmNoPaddingXmlns:
        if (cipherBytes.length <= _aesGcmTagLengthBytes) {
          throw XmppMessageException();
        }
        final macBytes =
            cipherBytes.sublist(cipherBytes.length - _aesGcmTagLengthBytes);
        final body =
            cipherBytes.sublist(0, cipherBytes.length - _aesGcmTagLengthBytes);
        final secretBox = SecretBox(
          body,
          nonce: ivBytes,
          mac: Mac(macBytes),
        );
        final algorithm = scheme == mox.sfsEncryptionAes128GcmNoPaddingXmlns
            ? AesGcm.with128bits()
            : AesGcm.with256bits();
        final decrypted = await algorithm.decrypt(
          secretBox,
          secretKey: SecretKey(keyBytes),
        );
        return Uint8List.fromList(decrypted);
      case mox.sfsEncryptionAes256CbcPkcs7Xmlns:
        final algorithm = AesCbc.with256bits(macAlgorithm: MacAlgorithm.empty);
        final secretBox = SecretBox(
          cipherBytes,
          nonce: ivBytes,
          mac: Mac.empty,
        );
        final decrypted = await algorithm.decrypt(
          secretBox,
          secretKey: SecretKey(keyBytes),
        );
        return Uint8List.fromList(decrypted);
    }
    throw XmppMessageException();
  }

  Future<void> _verifySha256Hash({
    required Map<mox.HashFunction, String>? expected,
    required List<int> bytes,
  }) async {
    if (expected == null || expected.isEmpty) return;
    final hashValue = expected[mox.HashFunction.sha256];
    if (hashValue == null || hashValue.trim().isEmpty) return;
    final expectedBytes = _decodeSha256Expected(hashValue);
    if (expectedBytes == null) {
      throw XmppMessageException();
    }
    final computed = sha256.convert(bytes).bytes;
    if (!_constantTimeBytesEqual(computed, expectedBytes)) {
      throw XmppMessageException();
    }
  }

  bool _hasExpectedSha256Hash(Map<mox.HashFunction, String>? expected) {
    if (expected == null || expected.isEmpty) return false;
    final hashValue = expected[mox.HashFunction.sha256];
    if (hashValue == null || hashValue.trim().isEmpty) return false;
    return _decodeSha256Expected(hashValue) != null;
  }

  Future<void> _verifySha256HashForFile({
    required Map<mox.HashFunction, String>? expected,
    required File file,
  }) async {
    if (expected == null || expected.isEmpty) return;
    final hashValue = expected[mox.HashFunction.sha256];
    if (hashValue == null || hashValue.trim().isEmpty) return;
    final expectedBytes = _decodeSha256Expected(hashValue);
    if (expectedBytes == null) {
      throw XmppMessageException();
    }
    final digest = await sha256.bind(file.openRead()).first;
    if (!_constantTimeBytesEqual(digest.bytes, expectedBytes)) {
      throw XmppMessageException();
    }
  }

  Uint8List? _decodeSha256Expected(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final looksLikeHex =
        trimmed.length == 64 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(trimmed);
    if (looksLikeHex) {
      try {
        final bytes = <int>[];
        for (var index = 0; index < trimmed.length; index += 2) {
          bytes.add(int.parse(trimmed.substring(index, index + 2), radix: 16));
        }
        return Uint8List.fromList(bytes);
      } on Exception {
        return null;
      }
    }
    final normalized = _normalizeBase64(trimmed);
    try {
      final decoded = base64Decode(normalized);
      return decoded.length == 32 ? Uint8List.fromList(decoded) : null;
    } on FormatException {
      return null;
    }
  }

  bool _shouldProcessPinSyncEvent(String chatJid) {
    if (_pinSyncRateLimiter.allowEvent()) {
      return true;
    }
    if (_pinSyncRateLimiter.shouldRefreshNow()) {
      unawaited(syncPinnedMessagesForChat(chatJid));
    }
    return false;
  }

  Future<void> _handlePinNotification(
    mox.PubSubNotificationEvent event,
  ) async {
    final nodeId = event.item.node;
    final chatJid = _chatJidFromPinNode(nodeId);
    if (chatJid == null) return;
    if (!_shouldProcessPinSyncEvent(chatJid)) return;
    await _ensurePendingPinSyncLoaded();
    final itemId = event.item.id.trim();
    if (itemId.isNotEmpty &&
        _pendingPinRetractionsByChat[chatJid]?.contains(itemId) == true) {
      return;
    }
    final payload = event.item.payload;
    if (payload == null) {
      unawaited(syncPinnedMessagesForChat(chatJid));
      return;
    }
    final parsed = _PinnedMessageSyncPayload.fromXml(
      payload,
      chatJid: chatJid,
      itemId: itemId.isEmpty ? null : itemId,
    );
    if (parsed == null) {
      return;
    }
    if (_pendingPinRetractionsByChat[chatJid]
            ?.contains(parsed.messageStanzaId) ==
        true) {
      return;
    }
    final publisher = event.item.publisher;
    final canApply = await _isPinPublisherAuthorized(
      chatJid: chatJid,
      messageStanzaId: parsed.messageStanzaId,
      publisher: publisher,
    );
    if (!canApply) {
      if (publisher == null || publisher.trim().isEmpty) {
        unawaited(syncPinnedMessagesForChat(chatJid));
      }
      return;
    }
    await _applyPinSyncUpdate(parsed);
  }

  Future<void> _handlePinRetraction(
    mox.PubSubItemsRetractedEvent event,
  ) async {
    final chatJid = _chatJidFromPinNode(event.node);
    if (chatJid == null) return;
    if (event.itemIds.isEmpty) return;
    if (!_shouldProcessPinSyncEvent(chatJid)) return;
    await _ensurePendingPinSyncLoaded();
    var pendingChanged = false;
    for (final itemId in event.itemIds) {
      final normalized = itemId.trim();
      if (normalized.isEmpty) continue;
      await _applyPinSyncRetraction(
        chatJid: chatJid,
        messageStanzaId: normalized,
      );
      pendingChanged =
          _pendingPinPublishesByChat[chatJid]?.remove(normalized) == true ||
              _pendingPinRetractionsByChat[chatJid]?.remove(normalized) ==
                  true ||
              pendingChanged;
    }
    if (pendingChanged) {
      await _persistPendingPinSync();
    }
  }

  Future<void> _applyPinSyncUpdate(
    _PinnedMessageSyncPayload payload,
  ) async {
    await _dbOp<XmppDatabase>(
      (db) => db.upsertPinnedMessage(
        PinnedMessageEntry(
          messageStanzaId: payload.messageStanzaId,
          chatJid: payload.chatJid,
          pinnedAt: payload.pinnedAt,
        ),
      ),
    );
    final pending = _pendingPinPublishesByChat[payload.chatJid];
    if (pending?.remove(payload.messageStanzaId) == true) {
      await _persistPendingPinSync();
    }
  }

  Future<void> _applyPinSyncRetraction({
    required String chatJid,
    required String messageStanzaId,
  }) async {
    await _dbOp<XmppDatabase>(
      (db) => db.deletePinnedMessage(
        chatJid: chatJid,
        messageStanzaId: messageStanzaId,
      ),
    );
  }

  SafePubSubManager? _pinPubSub() =>
      _connection.getManager<SafePubSubManager>();

  List<mox.JID> _pinPubSubHosts() {
    final domain = _myJid?.domain.trim();
    if (domain == null || domain.isEmpty) {
      return const <mox.JID>[];
    }
    final candidates = <mox.JID>[];
    final seen = <String>{};
    void addCandidate(String raw) {
      final normalized = raw.trim();
      if (normalized.isEmpty || seen.contains(normalized)) return;
      try {
        candidates.add(mox.JID.fromString(normalized));
        seen.add(normalized);
      } on Exception {
        return;
      }
    }

    final cachedHost = _pinPubSubHost?.toString();
    if (cachedHost != null && cachedHost.isNotEmpty) {
      addCandidate(cachedHost);
    }
    addCandidate('$_pinPubSubHostPrefix$domain');
    addCandidate(domain);
    return candidates;
  }

  Future<_PinNodeConfigResult?> _ensurePinNodeForChat(
    String chatJid, {
    required _PinNodeContext context,
  }) async {
    final nodeId = _pinNodeForChat(chatJid);
    if (nodeId == null) return null;
    final pubsub = _pinPubSub();
    if (pubsub == null) return null;
    for (final host in _pinPubSubHosts()) {
      final appliedPolicy = await _configurePinNode(
        pubsub: pubsub,
        host: host,
        nodeId: nodeId,
        context: context,
      );
      if (appliedPolicy == null) continue;
      _pinPubSubHost = host;
      return _PinNodeConfigResult(host: host, policy: appliedPolicy);
    }
    return null;
  }

  Future<_PinNodePolicy?> _configurePinNode({
    required SafePubSubManager pubsub,
    required mox.JID host,
    required String nodeId,
    required _PinNodeContext context,
  }) async {
    final applied = await _configurePinNodeWithPolicy(
      pubsub: pubsub,
      host: host,
      nodeId: nodeId,
      policy: context.policy,
      affiliations: context.affiliations,
    );
    if (!applied) {
      return null;
    }
    return context.policy;
  }

  Future<bool> _configurePinNodeWithPolicy({
    required SafePubSubManager pubsub,
    required mox.JID host,
    required String nodeId,
    required _PinNodePolicy policy,
    Map<String, mox.PubSubAffiliation>? affiliations,
  }) async {
    final config = _pinNodeConfig(policy);
    final configured = await pubsub.configureNode(host, nodeId, config);
    if (!configured.isType<mox.PubSubError>()) {
      return _applyPinAffiliationsIfNeeded(
        pubsub: pubsub,
        host: host,
        nodeId: nodeId,
        policy: policy,
        affiliations: affiliations,
      );
    }
    final configuredError = configured.get<mox.PubSubError>();
    final shouldCreateNode = configuredError.indicatesMissingNode;
    if (!shouldCreateNode) {
      return false;
    }

    try {
      await pubsub.createNodeWithConfig(
        host,
        _pinCreateNodeConfig(policy),
        nodeId: nodeId,
      );
      final applied = await pubsub.configureNode(host, nodeId, config);
      if (applied.isType<mox.PubSubError>()) {
        return false;
      }
      return _applyPinAffiliationsIfNeeded(
        pubsub: pubsub,
        host: host,
        nodeId: nodeId,
        policy: policy,
        affiliations: affiliations,
      );
    } on Exception {
      // Ignore and try fallback creation.
    }

    try {
      await pubsub.createNode(host, nodeId: nodeId);
      final applied = await pubsub.configureNode(host, nodeId, config);
      if (applied.isType<mox.PubSubError>()) {
        return false;
      }
      return _applyPinAffiliationsIfNeeded(
        pubsub: pubsub,
        host: host,
        nodeId: nodeId,
        policy: policy,
        affiliations: affiliations,
      );
    } on Exception {
      return false;
    }
  }

  Future<bool> _applyPinAffiliationsIfNeeded({
    required SafePubSubManager pubsub,
    required mox.JID host,
    required String nodeId,
    required _PinNodePolicy policy,
    Map<String, mox.PubSubAffiliation>? affiliations,
  }) async {
    if (policy != _PinNodePolicy.restricted) {
      return true;
    }
    if (affiliations == null || affiliations.isEmpty) {
      return false;
    }
    final result = await pubsub.setAffiliations(host, nodeId, affiliations);
    return !result.isType<mox.PubSubError>();
  }

  Future<void> _subscribeToPins({
    required mox.JID host,
    required String nodeId,
  }) async {
    final pubsub = _pinPubSub();
    if (pubsub == null) return;
    final result = await pubsub.subscribe(host, nodeId);
    if (!result.isType<mox.PubSubError>()) {
      return;
    }
    final error = result.get<mox.PubSubError>();
    if (error is mox.MalformedResponseError) {
      return;
    }
  }

  Future<List<_PinnedMessageSyncPayload>?> _fetchPinSnapshot({
    required mox.JID host,
    required String nodeId,
    required String chatJid,
  }) async {
    final pubsub = _pinPubSub();
    if (pubsub == null) return null;
    final result = await pubsub.getItems(
      host,
      nodeId,
      maxItems: _pinSyncMaxItems,
    );
    if (result.isType<mox.PubSubError>()) {
      return null;
    }
    await _ensurePendingPinSyncLoaded();
    final allowedPublishers = await _resolvePinAuthorizedPublishers(chatJid);
    final pendingPublishes =
        _pendingPinPublishesByChat[chatJid] ?? _emptyPinPublisherSet;
    final items = result.get<List<mox.PubSubItem>>();
    final parsed = <_PinnedMessageSyncPayload>[];
    for (final item in items) {
      final payload = item.payload;
      if (payload == null) continue;
      final entry = _PinnedMessageSyncPayload.fromXml(
        payload,
        chatJid: chatJid,
        itemId: item.id,
      );
      if (entry != null &&
          _isPinPublisherAllowed(
            allowedPublishers: allowedPublishers,
            pendingPublishes: pendingPublishes,
            messageStanzaId: entry.messageStanzaId,
            publisher: item.publisher,
          )) {
        parsed.add(entry);
      }
    }
    return parsed;
  }

  Future<void> _applyPinSnapshot({
    required String chatJid,
    required List<_PinnedMessageSyncPayload> items,
  }) async {
    await _ensurePendingPinSyncLoaded();
    final pendingPublishes =
        _pendingPinPublishesByChat[chatJid] ?? const <String>{};
    final pendingRetractions =
        _pendingPinRetractionsByChat[chatJid] ?? const <String>{};
    for (final item in items) {
      if (pendingRetractions.contains(item.messageStanzaId)) {
        continue;
      }
      await _applyPinSyncUpdate(item);
    }
    final remoteById = <String, _PinnedMessageSyncPayload>{
      for (final item in items) item.messageStanzaId: item,
    };
    final localItems =
        await _dbOpReturning<XmppDatabase, List<PinnedMessageEntry>>(
      (db) => db.getPinnedMessages(chatJid),
    );
    for (final local in localItems) {
      final messageId = local.messageStanzaId;
      if (remoteById.containsKey(messageId)) {
        continue;
      }
      if (pendingPublishes.contains(messageId)) {
        continue;
      }
      await _applyPinSyncRetraction(
        chatJid: chatJid,
        messageStanzaId: messageId,
      );
    }
  }

  Future<void> _queuePinPublish(
    String chatJid,
    String messageStanzaId,
  ) async {
    await _ensurePendingPinSyncLoaded();
    final publishes = _pendingPinPublishesByChat.putIfAbsent(
      chatJid,
      () => <String>{},
    );
    final retractions = _pendingPinRetractionsByChat.putIfAbsent(
      chatJid,
      () => <String>{},
    );
    retractions.remove(messageStanzaId);
    publishes.add(messageStanzaId);
    await _persistPendingPinSync();
  }

  Future<void> _queuePinRetraction(
    String chatJid,
    String messageStanzaId,
  ) async {
    await _ensurePendingPinSyncLoaded();
    final retractions = _pendingPinRetractionsByChat.putIfAbsent(
      chatJid,
      () => <String>{},
    );
    final publishes = _pendingPinPublishesByChat.putIfAbsent(
      chatJid,
      () => <String>{},
    );
    publishes.remove(messageStanzaId);
    retractions.add(messageStanzaId);
    await _persistPendingPinSync();
  }

  Map<String, Set<String>> _decodePendingPinMap(Object? raw) {
    final decoded = <String, Set<String>>{};
    if (raw is! Map) {
      return decoded;
    }
    for (final entry in raw.entries) {
      final key = entry.key;
      if (key is! String) continue;
      final value = entry.value;
      if (value is! Iterable) continue;
      final normalized = value
          .whereType<String>()
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toSet();
      if (normalized.isEmpty) continue;
      decoded[key] = normalized;
    }
    return decoded;
  }

  Map<String, List<String>> _encodePendingPinMap(
    Map<String, Set<String>> source,
  ) {
    final encoded = <String, List<String>>{};
    for (final entry in source.entries) {
      if (entry.value.isEmpty) continue;
      encoded[entry.key] = entry.value.toList(growable: false);
    }
    return encoded;
  }

  Future<void> _ensurePendingPinSyncLoaded() async {
    if (_pendingPinSyncLoaded) {
      return;
    }
    final rawPublishes = await _dbOpReturning<XmppStateStore, Object?>(
      (ss) => ss.read(key: _pinPendingPublishesKey),
    );
    final rawRetractions = await _dbOpReturning<XmppStateStore, Object?>(
      (ss) => ss.read(key: _pinPendingRetractionsKey),
    );
    _pendingPinPublishesByChat
      ..clear()
      ..addAll(_decodePendingPinMap(rawPublishes));
    _pendingPinRetractionsByChat
      ..clear()
      ..addAll(_decodePendingPinMap(rawRetractions));
    _pendingPinSyncLoaded = true;
  }

  Future<void> _persistPendingPinSync() async {
    if (!_pendingPinSyncLoaded) {
      return;
    }
    _pendingPinPublishesByChat.removeWhere((_, ids) => ids.isEmpty);
    _pendingPinRetractionsByChat.removeWhere((_, ids) => ids.isEmpty);
    final publishes = _encodePendingPinMap(_pendingPinPublishesByChat);
    final retractions = _encodePendingPinMap(_pendingPinRetractionsByChat);
    await _dbOp<XmppStateStore>(
      (ss) async {
        if (publishes.isEmpty) {
          await ss.delete(key: _pinPendingPublishesKey);
        } else {
          await ss.write(key: _pinPendingPublishesKey, value: publishes);
        }
        if (retractions.isEmpty) {
          await ss.delete(key: _pinPendingRetractionsKey);
        } else {
          await ss.write(key: _pinPendingRetractionsKey, value: retractions);
        }
      },
      awaitDatabase: true,
    );
  }

  Future<void> _flushPendingPinSync() async {
    if (!_connection.hasConnectionSettings) {
      return;
    }
    if (connectionState != ConnectionState.connected) {
      return;
    }
    await _ensurePendingPinSyncLoaded();
    if (_pendingPinPublishesByChat.isEmpty &&
        _pendingPinRetractionsByChat.isEmpty) {
      return;
    }
    final chatIds = <String>{
      ..._pendingPinPublishesByChat.keys,
      ..._pendingPinRetractionsByChat.keys,
    };
    for (final chatJid in chatIds) {
      await _flushPendingPinSyncForChat(chatJid);
    }
  }

  Future<void> _flushPendingPinSyncForChat(String chatJid) async {
    if (!_connection.hasConnectionSettings) {
      return;
    }
    if (connectionState != ConnectionState.connected) {
      return;
    }
    await _ensurePendingPinSyncLoaded();
    final normalizedChat = _normalizePinChatJid(chatJid);
    if (normalizedChat == null) {
      return;
    }
    final context = await _resolvePinNodeContext(normalizedChat);
    final support = await refreshPubSubSupport();
    if (!support.pubSubSupported) {
      return;
    }
    final pubsub = _pinPubSub();
    if (pubsub == null) {
      return;
    }
    final nodeConfig =
        await _ensurePinNodeForChat(normalizedChat, context: context);
    if (nodeConfig == null) {
      return;
    }
    final host = nodeConfig.host;
    final policy = nodeConfig.policy;
    final nodeId = _pinNodeForChat(normalizedChat);
    if (nodeId == null) {
      return;
    }
    await _subscribeToPins(host: host, nodeId: nodeId);
    final pendingRetractions =
        _pendingPinRetractionsByChat[normalizedChat]?.toList(growable: false) ??
            const <String>[];
    final pendingPublishes =
        _pendingPinPublishesByChat[normalizedChat]?.toList(growable: false) ??
            const <String>[];
    final pinnedEntries =
        await _dbOpReturning<XmppDatabase, List<PinnedMessageEntry>>(
      (db) => db.getPinnedMessages(normalizedChat),
    );
    final pinnedById = <String, PinnedMessageEntry>{
      for (final entry in pinnedEntries) entry.messageStanzaId: entry,
    };
    var pendingChanged = false;
    for (final messageId in pendingRetractions) {
      final trimmed = messageId.trim();
      if (trimmed.isEmpty) continue;
      final success = await _retractPinFromServer(
        pubsub: pubsub,
        host: host,
        nodeId: nodeId,
        messageStanzaId: trimmed,
      );
      if (!success) {
        continue;
      }
      pendingChanged =
          _pendingPinRetractionsByChat[normalizedChat]?.remove(trimmed) ==
                  true ||
              pendingChanged;
    }
    for (final messageId in pendingPublishes) {
      final trimmed = messageId.trim();
      if (trimmed.isEmpty) continue;
      final entry = pinnedById[trimmed];
      if (entry == null) {
        pendingChanged =
            _pendingPinPublishesByChat[normalizedChat]?.remove(trimmed) ==
                    true ||
                pendingChanged;
        continue;
      }
      final success = await _publishPinToServer(
        pubsub: pubsub,
        host: host,
        nodeId: nodeId,
        entry: entry,
        policy: policy,
      );
      if (!success) {
        continue;
      }
      pendingChanged =
          _pendingPinPublishesByChat[normalizedChat]?.remove(trimmed) == true ||
              pendingChanged;
    }
    if (pendingChanged) {
      await _persistPendingPinSync();
    }
  }

  Future<bool> _publishPinToServer({
    required SafePubSubManager pubsub,
    required mox.JID host,
    required String nodeId,
    required PinnedMessageEntry entry,
    required _PinNodePolicy policy,
  }) async {
    final messageId = entry.messageStanzaId.trim();
    if (messageId.isEmpty) return false;
    final payload = _PinnedMessageSyncPayload(
      messageStanzaId: messageId,
      chatJid: entry.chatJid,
      pinnedAt: entry.pinnedAt,
    );
    final result = await pubsub.publish(
      host,
      nodeId,
      payload.toXml(),
      id: payload.itemId,
      options: _pinPublishOptions(policy),
      autoCreate: true,
      createNodeConfig: _pinCreateNodeConfig(policy),
    );
    return !result.isType<mox.PubSubError>();
  }

  Future<bool> _retractPinFromServer({
    required SafePubSubManager pubsub,
    required mox.JID host,
    required String nodeId,
    required String messageStanzaId,
  }) async {
    final trimmed = messageStanzaId.trim();
    if (trimmed.isEmpty) return false;
    final result = await pubsub.retract(
      host,
      nodeId,
      trimmed,
      notify: _pinNotifyEnabled,
    );
    return !result.isType<mox.PubSubError>();
  }

  String _normalizeBase64(String input) {
    final sanitized = input.replaceAll('-', '+').replaceAll('_', '/');
    final padding = sanitized.length % 4;
    if (padding == 0) return sanitized;
    return '$sanitized${'=' * (4 - padding)}';
  }

  bool _constantTimeBytesEqual(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    var result = 0;
    for (var index = 0; index < left.length; index++) {
      result |= left[index] ^ right[index];
    }
    return result == 0;
  }

  bool _allowInboundAttachmentAutoDownload(String chatJid) {
    final normalized = _normalizeBareJidValue(chatJid);
    if (normalized == null) {
      return true;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final chatAllowed = _inboundAttachmentAutoDownloadChatLimiter.allowEvent(
      normalized,
      nowMs: nowMs,
    );
    if (!chatAllowed) {
      return false;
    }
    return _inboundAttachmentAutoDownloadGlobalLimiter.allowEvent(
      nowMs: nowMs,
    );
  }

  Future<void> _autoDownloadTrustedInboundAttachment({
    required Message message,
    required String metadataId,
  }) async {
    final trimmedMetadataId = metadataId.trim();
    if (trimmedMetadataId.isEmpty) return;
    final stanzaId = message.stanzaID.trim();
    if (stanzaId.isEmpty) return;
    try {
      final accountJid = myJid?.trim();
      final isSelf = accountJid != null &&
          message.senderJid.trim().toLowerCase() == accountJid.toLowerCase();
      var isTrusted = isSelf;
      if (!isTrusted) {
        isTrusted = await _dbOpReturning<XmppDatabase, bool>(
          (db) async {
            final chat = await db.getChat(message.chatJid);
            if (chat?.spam ?? false) {
              return false;
            }
            if (chat == null) return false;
            return chat.attachmentAutoDownload.isAllowed;
          },
        );
      }
      if (!isTrusted) return;
      final metadata = await _dbOpReturning<XmppDatabase, FileMetadataData?>(
        (db) => db.getFileMetadata(trimmedMetadataId),
      );
      if (metadata == null) return;
      if (!attachmentAutoDownloadSettings.allowsMetadata(metadata)) {
        return;
      }
      await downloadInboundAttachment(
        metadataId: trimmedMetadataId,
        stanzaId: stanzaId,
      );
    } on Exception {
      // Best-effort: errors are reflected on the message via fileDownloadFailure.
    }
  }

// Future<bool> _downloadAllowed(String chatJid) async {
//   if (!(await Permission.storage.status).isGranted) return false;
//   if ((await _connection.getConnectionState()) !=
//       mox.XmppConnectionState.connected) return false;
//   var allowed = false;
//   await _dbOp<XmppDatabase>((db) async {
//     allowed = (await db.rosterAccessor.selectOne(chatJid) != null);
//   });
//   return allowed;
// }
}

final class _AttachmentCacheEntry {
  const _AttachmentCacheEntry({
    required this.file,
    required this.sizeBytes,
    required this.lastModified,
  });

  final File file;
  final int sizeBytes;
  final DateTime lastModified;
}

class _UploadSlot {
  _UploadSlot({
    required this.getUrl,
    required this.putUrl,
    List<_UploadSlotHeader>? headers,
  }) : headers = headers ?? const [];

  // ignore: unused_element
  factory _UploadSlot.fromMox(mox.HttpFileUploadSlot slot) {
    return _UploadSlot(
      getUrl: slot.getUrl.toString(),
      putUrl: slot.putUrl.toString(),
      headers: slot.headers.entries
          .map(
            (entry) => _UploadSlotHeader(
              name: entry.key,
              value: entry.value,
            ),
          )
          .where(
            (header) => _allowedHttpUploadPutHeaders
                .contains(header.name.toLowerCase()),
          )
          .toList(growable: false),
    );
  }

  final String getUrl;
  final String putUrl;
  final List<_UploadSlotHeader> headers;
}

class _UploadSlotHeader {
  const _UploadSlotHeader({
    required this.name,
    required this.value,
  });

  final String name;
  final String value;
}

class _ReactionBucket {
  _ReactionBucket(this.emoji);

  final String emoji;
  var count = 0;
  var reactedBySelf = false;

  void add(String senderJid, String? selfJid) {
    count += 1;
    if (!reactedBySelf && senderJid == selfJid) {
      reactedBySelf = true;
    }
  }

  ReactionPreview toPreview() => ReactionPreview(
        emoji: emoji,
        count: count,
        reactedBySelf: reactedBySelf,
      );
}
