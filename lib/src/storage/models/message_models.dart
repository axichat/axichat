// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:convert';

import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/calendar/models/calendar_availability_message.dart';
import 'package:axichat/src/calendar/models/calendar_fragment.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/calendar_task_ics_message.dart';
import 'package:axichat/src/calendar/interop/calendar_task_ics_codec.dart';
import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/common/message_content_limits.dart';
import 'package:axichat/src/common/synthetic_forward.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/email/util/email_message_ids.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/storage/models/database_converters.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:drift/drift.dart' hide JsonKey;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;
import 'package:omemo_dart/omemo_dart.dart' as omemo;
import 'package:uuid/uuid.dart';

part 'message_models.freezed.dart';

const uuid = Uuid();

bool isMultiDeviceSyncMessage({
  required String? subject,
  required String? body,
}) {
  final normalizedSubject = subject?.trim().toLowerCase();
  if (normalizedSubject != 'multi device synchronization') {
    return false;
  }
  final normalizedBody = body?.trim().toLowerCase();
  return normalizedBody?.startsWith(
        'this message is used to synchronize data between your devices',
      ) ==
      true;
}

bool isHiddenInternalMultiDeviceSyncMessage({
  required String? subject,
  required String? body,
  required String senderJid,
  required String chatJid,
  required bool received,
}) {
  if (received) {
    return false;
  }
  if (!sameNormalizedAddressValue(senderJid, chatJid)) {
    return false;
  }
  return isMultiDeviceSyncMessage(subject: subject, body: body);
}

final class DeltaAccountDefaults {
  static const int legacyId = 0;
}

// ENUMS WARNING: New values must only be added to the end of the list.
// If not, the database will break

enum MessageError {
  none,
  unknown,
  serviceUnavailable,
  serverNotFound,
  serverTimeout,
  invalidAffixElements,
  fileDownloadFailure,
  fileUploadFailure,
  omemoUnsupported,
  notEncryptedForDevice,
  malformedKey,
  malformedCiphertext,
  noDeviceSession,
  noKeyMaterial,
  noDecryptionKey,
  emptyDeviceList,
  invalidHMAC,
  invalidKEX,
  invalidEnvelope,
  encryptionFailure,
  skippingTooManyKeys,
  unknownSPK,
  unknownOmemoError,
  fileDecryptionFailure,
  fileEncryptionFailure,
  plaintextFileInOmemo,
  // Email-specific failures must remain at the end to preserve
  // the stored enum indexes.
  emailSendFailure,
  emailAttachmentTooLarge,
  emailRecipientRejected,
  emailAuthenticationFailed,
  emailBounced,
  emailThrottled;

  bool get isNone => this == none;

  bool get isNotNone => this != none;

  static MessageError fromOmemo(Object? error) => switch (error) {
    omemo.NotEncryptedForDeviceError _ => notEncryptedForDevice,
    omemo.MalformedEncryptedKeyError _ => malformedKey,
    omemo.UnknownSignedPrekeyError _ => unknownSPK,
    omemo.NoSessionWithDeviceError _ => noDeviceSession,
    omemo.SkippingTooManyKeysError _ => skippingTooManyKeys,
    omemo.InvalidMessageHMACError _ => invalidHMAC,
    omemo.MalformedCiphertextError _ => malformedCiphertext,
    omemo.NoKeyMaterialAvailableError _ => noKeyMaterial,
    omemo.InvalidKeyExchangeSignatureError _ => invalidKEX,
    mox.UnknownOmemoError _ => unknownOmemoError,
    mox.InvalidAffixElementsException _ => invalidAffixElements,
    mox.EmptyDeviceListException _ => emptyDeviceList,
    mox.OmemoNotSupportedForContactException _ => omemoUnsupported,
    mox.EncryptionFailedException _ => encryptionFailure,
    mox.InvalidEnvelopePayloadException _ => invalidEnvelope,
    _ => none,
  };
}

enum MessageWarning {
  none,
  fileIntegrityFailure,
  plaintextFileInOmemo,
  emailSpamQuarantined;

  bool get isNotNone => this != none;
}

extension MessageErrorLocalization on MessageError {
  String? tooltip(AppLocalizations l10n) {
    if (this == MessageError.serviceUnavailable) {
      return l10n.messageErrorServiceUnavailableTooltip;
    }
    return null;
  }

  String label(AppLocalizations l10n) => switch (this) {
    MessageError.serviceUnavailable => l10n.messageErrorServiceUnavailable,
    MessageError.serverNotFound => l10n.messageErrorServerNotFound,
    MessageError.serverTimeout => l10n.messageErrorServerTimeout,
    MessageError.unknown => l10n.messageErrorUnknown,
    MessageError.notEncryptedForDevice =>
      l10n.messageErrorNotEncryptedForDevice,
    MessageError.malformedKey => l10n.messageErrorMalformedKey,
    MessageError.unknownSPK => l10n.messageErrorUnknownSignedPrekey,
    MessageError.noDeviceSession => l10n.messageErrorNoDeviceSession,
    MessageError.skippingTooManyKeys => l10n.messageErrorSkippingTooManyKeys,
    MessageError.invalidHMAC => l10n.messageErrorInvalidHmac,
    MessageError.malformedCiphertext => l10n.messageErrorMalformedCiphertext,
    MessageError.noKeyMaterial => l10n.messageErrorNoKeyMaterial,
    MessageError.noDecryptionKey => l10n.messageErrorNoDecryptionKey,
    MessageError.invalidKEX => l10n.messageErrorInvalidKex,
    MessageError.unknownOmemoError => l10n.messageErrorUnknownOmemo,
    MessageError.invalidAffixElements => l10n.messageErrorInvalidAffixElements,
    MessageError.emptyDeviceList => l10n.messageErrorEmptyDeviceList,
    MessageError.omemoUnsupported => l10n.messageErrorOmemoUnsupported,
    MessageError.encryptionFailure => l10n.messageErrorEncryptionFailure,
    MessageError.invalidEnvelope => l10n.messageErrorInvalidEnvelope,
    MessageError.fileDownloadFailure => l10n.messageErrorFileDownloadFailure,
    MessageError.fileUploadFailure => l10n.messageErrorFileUploadFailure,
    MessageError.fileDecryptionFailure =>
      l10n.messageErrorFileDecryptionFailure,
    MessageError.fileEncryptionFailure =>
      l10n.messageErrorFileEncryptionFailure,
    MessageError.plaintextFileInOmemo => l10n.messageErrorPlaintextFileInOmemo,
    MessageError.emailSendFailure => l10n.messageErrorEmailSendFailure,
    MessageError.emailAttachmentTooLarge =>
      l10n.messageErrorEmailAttachmentTooLarge,
    MessageError.emailRecipientRejected =>
      l10n.messageErrorEmailRecipientRejected,
    MessageError.emailAuthenticationFailed =>
      l10n.messageErrorEmailAuthenticationFailed,
    MessageError.emailBounced => l10n.messageErrorEmailBounced,
    MessageError.emailThrottled => l10n.messageErrorEmailThrottled,
    _ => l10n.messageErrorUnknown,
  };
}

enum EncryptionProtocol {
  none,
  omemo,
  mls,
  openPgp;

  bool get isNone => this == none;

  bool get isNotNone => this != none;

  bool get isOmemo => this == omemo;

  bool get isMls => this == mls;

  bool get isOpenPgp => this == openPgp;
}

enum MessageTimelineFilter {
  directOnly,
  allWithContact;

  bool get isDirect => this == MessageTimelineFilter.directOnly;
}

enum MessageParticipantRole { sender, recipient }

enum PseudoMessageType {
  newDevice,
  changedDevice,
  unknown,
  mucInvite,
  mucInviteRevocation,
  calendarFragment,
  calendarTaskIcs,
  calendarAvailabilityShare,
  calendarAvailabilityRequest,
  calendarAvailabilityResponse,
  mucInviteAccepted,
  emailEncryptionStatus,
}

extension PseudoMessageTypeX on PseudoMessageType {
  bool get isInvite =>
      this == PseudoMessageType.mucInvite ||
      this == PseudoMessageType.mucInviteRevocation;

  bool get isCalendarFragment => this == PseudoMessageType.calendarFragment;

  bool get isCalendarTaskIcs => this == PseudoMessageType.calendarTaskIcs;

  bool get isCalendarAvailability =>
      this == PseudoMessageType.calendarAvailabilityShare ||
      this == PseudoMessageType.calendarAvailabilityRequest ||
      this == PseudoMessageType.calendarAvailabilityResponse;

  bool get isCalendarAvailabilityShare =>
      this == PseudoMessageType.calendarAvailabilityShare;

  bool get isCalendarAvailabilityRequest =>
      this == PseudoMessageType.calendarAvailabilityRequest;

  bool get isCalendarAvailabilityResponse =>
      this == PseudoMessageType.calendarAvailabilityResponse;

  bool get isSystemStatus => this == PseudoMessageType.emailEncryptionStatus;

  bool get isHiddenInviteLifecycle =>
      this == PseudoMessageType.mucInviteAccepted;
}

String emailEncryptionStatusMarkerStanzaId(String chatJid) {
  final normalized = normalizedAddressValue(chatJid);
  final fallback = chatJid.trim().toLowerCase();
  final identifier = normalized?.isNotEmpty == true ? normalized! : fallback;
  return 'email-encryption-status:$identifier';
}

Map<String, dynamic> emailEncryptionStatusMarkerData({
  required String anchorStanzaId,
  required DateTime anchorTimestamp,
}) {
  return <String, dynamic>{
    'anchorStanzaId': anchorStanzaId,
    'anchorTimestampMicros': anchorTimestamp.microsecondsSinceEpoch,
  };
}

typedef BTBVTrustState = omemo.BTBVTrustState;

class ReactionPreview {
  const ReactionPreview({
    required this.emoji,
    required this.count,
    this.reactedBySelf = false,
  });

  final String emoji;
  final int count;
  final bool reactedBySelf;

  ReactionPreview copyWith({String? emoji, int? count, bool? reactedBySelf}) =>
      ReactionPreview(
        emoji: emoji ?? this.emoji,
        count: count ?? this.count,
        reactedBySelf: reactedBySelf ?? this.reactedBySelf,
      );

  @override
  int get hashCode => Object.hash(emoji, count, reactedBySelf);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReactionPreview &&
          other.emoji == emoji &&
          other.count == count &&
          other.reactedBySelf == reactedBySelf;

  @override
  String toString() =>
      'ReactionPreview(emoji: $emoji, count: $count, reactedBySelf: $reactedBySelf)';
}

class OmemoDeviceData {
  const OmemoDeviceData({required this.id});

  final int id;
}

@Freezed(toJson: false, fromJson: false)
abstract class Message with _$Message implements Insertable<Message> {
  const factory Message({
    required String stanzaID,
    required String senderJid,
    String? senderRealJid,
    required String chatJid,
    DateTime? timestamp,
    String? id,
    String? originID,
    String? mucStanzaId,
    String? occupantID,
    String? body,
    String? htmlBody,
    String? subject,
    @Default(MessageError.none) MessageError error,
    @Default(MessageWarning.none) MessageWarning warning,
    @Default(EncryptionProtocol.none) EncryptionProtocol encryptionProtocol,
    BTBVTrustState? trust,
    bool? trusted,
    int? deviceID,
    @Default(false) bool noStore,
    @Default(false) bool acked,
    @Default(false) bool received,
    @Default(false) bool displayed,
    @Default(false) bool edited,
    @Default(false) bool retracted,
    @Default(false) bool isFileUploadNotification,
    @Default(false) bool fileDownloading,
    @Default(false) bool fileUploading,
    String? fileMetadataID,
    String? quoting,
    MessageReferenceKind? quotingReferenceKind,
    String? stickerPackID,
    PseudoMessageType? pseudoMessageType,
    Map<String, dynamic>? pseudoMessageData,
    String? manualSendAgainStanzaID,
    @Default(<ReactionPreview>[]) List<ReactionPreview> reactionsPreview,
    @Default(DeltaAccountDefaults.legacyId) int deltaAccountId,
    int? deltaChatId,
    int? deltaMsgId,
  }) = _Message;

  const factory Message.fromDb({
    required String id,
    required String stanzaID,
    required String? originID,
    required String? mucStanzaId,
    required String? occupantID,
    required String senderJid,
    required String? senderRealJid,
    required String chatJid,
    required String? body,
    required String? htmlBody,
    required String? subject,
    required DateTime timestamp,
    required MessageError error,
    required MessageWarning warning,
    required EncryptionProtocol encryptionProtocol,
    required BTBVTrustState? trust,
    required bool? trusted,
    required int? deviceID,
    required bool noStore,
    required bool acked,
    required bool received,
    required bool displayed,
    required bool edited,
    required bool retracted,
    required bool isFileUploadNotification,
    required bool fileDownloading,
    required bool fileUploading,
    required String? fileMetadataID,
    required String? quoting,
    required MessageReferenceKind? quotingReferenceKind,
    required String? stickerPackID,
    required PseudoMessageType? pseudoMessageType,
    required Map<String, dynamic>? pseudoMessageData,
    required String? manualSendAgainStanzaID,
    @Default(<ReactionPreview>[]) List<ReactionPreview> reactionsPreview,
    required int deltaAccountId,
    required int? deltaChatId,
    required int? deltaMsgId,
  }) = _MessageFromDb;

  factory Message.fromMox(
    mox.MessageEvent event, {
    String? accountJid,
    String? senderRealJid,
  }) {
    final get = event.extensions.get;
    final to = event.to.toBare().toString();
    final from = event.from.toBare().toString();
    final isGroupChat = event.type == 'groupchat';
    final invite = _ParsedInvite.fromEvent(event, to: to);
    final chatJid = isGroupChat
        ? from
        : invite?.chatJidOverride ??
              (accountJid != null &&
                      accountJid.isNotEmpty &&
                      from.toLowerCase() == accountJid.toLowerCase()
                  ? to
                  : from);
    final senderJid = isGroupChat ? event.from.toString() : from;
    final fragmentPayload = get<CalendarFragmentPayload>();
    final taskIcsPayload = get<CalendarTaskIcsPayload>();
    final CalendarTask? calendarTaskIcs = taskIcsPayload == null
        ? null
        : _decodeCalendarTaskIcsPayload(taskIcsPayload);
    final CalendarTaskIcsMessage? taskIcsMessage = calendarTaskIcs == null
        ? null
        : CalendarTaskIcsMessage(
            task: calendarTaskIcs,
            readOnly: CalendarTaskIcsMessage.defaultReadOnly,
          );
    final availabilityPayload = get<CalendarAvailabilityMessagePayload>();
    final PseudoMessageType? availabilityType = _availabilityPseudoMessageType(
      availabilityPayload,
    );
    final PseudoMessageType? pseudoMessageType =
        invite?.type ??
        availabilityType ??
        (calendarTaskIcs == null
            ? (fragmentPayload == null
                  ? null
                  : PseudoMessageType.calendarFragment)
            : PseudoMessageType.calendarTaskIcs);
    final Map<String, dynamic>? pseudoMessageData =
        invite?.data ??
        availabilityPayload?.message.toJson() ??
        (taskIcsMessage == null
            ? fragmentPayload?.fragment.toJson()
            : taskIcsMessage.toJson());
    final htmlData = get<XhtmlImData>();
    final boundedHtml = clampMessageHtml(htmlData?.xhtmlBody);
    final normalizedHtml = HtmlContentCodec.normalizeHtml(boundedHtml);
    final htmlPlain = clampMessageText(htmlData?.plainText) ?? '';
    final fallbackText = htmlPlain.isNotEmpty
        ? htmlPlain
        : (normalizedHtml == null
              ? ''
              : HtmlContentCodec.toPlainText(normalizedHtml));
    final boundedText = clampMessageText(event.text) ?? '';
    final resolvedText = boundedText.isNotEmpty ? boundedText : fallbackText;
    final subjectText = get<MessageSubjectData>()?.subject.trim();
    final stableIdData = get<mox.StableIdData>();
    final String? mucStanzaId = isGroupChat
        ? stableIdData?.stanzaIds
              ?.where((stanzaId) => stanzaId.by.toBare().toString() == chatJid)
              .map((stanzaId) => stanzaId.id.trim())
              .firstWhere((id) => id.isNotEmpty, orElse: () => '')
        : '';

    final rawOccupantId = get<mox.OccupantIdData>()?.id.trim();
    final occupantId = rawOccupantId == null || rawOccupantId.isEmpty
        ? null
        : rawOccupantId;
    final normalizedSenderRealJid = bareAddress(senderRealJid)?.trim();

    return Message(
      stanzaID: event.id ?? uuid.v4(),
      senderJid: senderJid,
      senderRealJid:
          normalizedSenderRealJid == null || normalizedSenderRealJid.isEmpty
          ? null
          : normalizedSenderRealJid,
      chatJid: chatJid,
      body: invite?.displayBody ?? (resolvedText.isEmpty ? null : resolvedText),
      htmlBody: normalizedHtml,
      subject: subjectText == null || subjectText.isEmpty ? null : subjectText,
      timestamp: get<mox.DelayedDeliveryData>()?.timestamp,
      noStore:
          get<mox.MessageProcessingHintData>()?.hints.contains(
            mox.MessageProcessingHint.noStore,
          ) ??
          false,
      quoting: get<mox.ReplyData>()?.id,
      quotingReferenceKind: isGroupChat
          ? MessageReferenceKind.mucStanzaId
          : null,
      originID: stableIdData?.originId,
      mucStanzaId: mucStanzaId == null || mucStanzaId.isEmpty
          ? null
          : mucStanzaId,
      occupantID: occupantId,
      encryptionProtocol: event.encrypted
          ? EncryptionProtocol.omemo
          : EncryptionProtocol.none,
      deviceID: get<OmemoDeviceData>()?.id,
      error: MessageError.fromOmemo(event.encryptionError),
      pseudoMessageType: pseudoMessageType,
      pseudoMessageData: pseudoMessageData,
    );
  }

  const Message._();

  bool authorized(mox.JID jid) {
    final sender = senderJid.trim();
    if (sender.isEmpty) {
      return false;
    }
    try {
      return mox.JID.fromString(sender).toBare() == jid.toBare();
    } on Exception {
      return sender == jid.toString();
    }
  }

  bool isFromAuthorizedJid(String? jid) {
    final trimmedJid = jid?.trim();
    if (trimmedJid == null || trimmedJid.isEmpty) {
      return false;
    }
    final realJid = effectiveSenderRealJid;
    if (realJid != null) {
      return sameBareAddress(realJid, trimmedJid);
    }
    try {
      return authorized(mox.JID.fromString(trimmedJid));
    } on Exception {
      return sameBareAddress(senderJid, trimmedJid);
    }
  }

  String? get effectiveSenderRealJid {
    final realJid = bareAddress(senderRealJid)?.trim();
    if (realJid == null || realJid.isEmpty) {
      return null;
    }
    return realJid;
  }

  bool get isMucOccupantSender {
    final parsedSender = parseJid(senderJid);
    if (parsedSender == null || parsedSender.resource.trim().isEmpty) {
      return false;
    }
    return sameNormalizedAddressValue(
      parsedSender.toBare().toString(),
      chatJid,
    );
  }

  bool isFromAccount(String? accountJid) {
    final realJid = effectiveSenderRealJid;
    if (realJid != null) {
      return sameBareAddress(realJid, accountJid);
    }
    return sameBareAddress(senderJid, accountJid);
  }

  bool get isAxiImServerAnnouncement {
    return isAxiImServerAnnouncementJid(senderJid) &&
        isAxiImServerAnnouncementJid(chatJid);
  }

  bool senderMatchesClaimedJid(String claimedJid) {
    final trimmedClaimed = claimedJid.trim();
    if (trimmedClaimed.isEmpty) {
      return false;
    }
    final realJid = effectiveSenderRealJid;
    if (realJid != null) {
      return sameBareAddress(realJid, trimmedClaimed);
    }
    if (isMucOccupantSender) {
      return false;
    }
    return sameBareAddress(senderJid, trimmedClaimed);
  }

  bool authorizedForMutation({required mox.JID from, String? actorRealJid}) {
    final sender = senderJid.trim();
    if (sender.isEmpty) {
      return false;
    }
    final realJid = effectiveSenderRealJid;
    if (realJid != null) {
      final normalizedActorRealJid = bareAddress(actorRealJid)?.trim();
      if (normalizedActorRealJid != null && normalizedActorRealJid.isNotEmpty) {
        return sameBareAddress(realJid, normalizedActorRealJid);
      }
      if (isMucOccupantSender) {
        return false;
      }
      return sameBareAddress(realJid, from.toBare().toString());
    }
    try {
      final senderParsed = mox.JID.fromString(sender);
      if (senderParsed.resource.trim().isNotEmpty) {
        return sender == from.toString();
      }
      return senderParsed.toBare() == from.toBare();
    } on Exception {
      return sender == from.toString();
    }
  }

  bool get editable =>
      error.isNone &&
      fileMetadataID == null &&
      !isFileUploadNotification &&
      !fileUploading &&
      !fileDownloading;

  bool get isPseudoMessage =>
      pseudoMessageType != null && pseudoMessageData != null;

  mox.MessageEvent toMox({
    String? quotedBody,
    mox.JID? quotedJid,
    List<mox.StanzaHandlerExtension> extraExtensions = const [],
    mox.JID? toJidOverride,
    String? type,
    bool includeOriginId = false,
  }) {
    final isGroupChat = type == 'groupchat';
    final extensions = <mox.StanzaHandlerExtension>[
      const mox.MarkableData(true),
      if (!isGroupChat) const mox.MessageDeliveryReceiptData(true),
      mox.MessageIdData(stanzaID),
      mox.ChatState.active,
    ];

    var outgoingBody = plainText;
    mox.ReplyData? replyData;
    if (quoting != null) {
      if (quotedBody != null) {
        final quote = mox.QuoteData.fromBodies(quotedBody, outgoingBody);
        outgoingBody = quote.body;
        replyData = mox.ReplyData.fromQuoteData(
          quoting!,
          quote,
          jid: quotedJid,
        );
      } else {
        replyData = mox.ReplyData(quoting!, jid: quotedJid);
      }
    }

    extensions.insert(0, mox.MessageBodyData(outgoingBody));
    final normalizedHtml = normalizedHtmlBody;
    if (normalizedHtml != null) {
      final xhtml = HtmlContentCodec.toXhtml(normalizedHtml);
      if (xhtml != null) {
        extensions.add(XhtmlImData(xhtmlBody: xhtml, plainText: outgoingBody));
      }
    }
    if (replyData != null) {
      extensions.add(replyData);
    }

    if (noStore) {
      extensions.add(
        const mox.MessageProcessingHintData([
          mox.MessageProcessingHint.noStore,
        ]),
      );
    }

    if (includeOriginId || encryptionProtocol == EncryptionProtocol.omemo) {
      final trimmedOriginId = originID?.trim();
      final stableId = trimmedOriginId == null || trimmedOriginId.isEmpty
          ? stanzaID
          : trimmedOriginId;
      extensions.add(mox.StableIdData(stableId, null));
    }

    extensions.addAll(extraExtensions);

    final toJid = toJidOverride ?? mox.JID.fromString(chatJid);
    final fromJid = mox.JID.fromString(senderJid);
    return mox.MessageEvent(
      fromJid,
      toJid,
      false,
      mox.TypedMap<mox.StanzaHandlerExtension>.fromList(extensions),
      id: stanzaID,
      type: type,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{
      'stanza_i_d': Variable<String>(stanzaID),
      'sender_jid': Variable<String>(senderJid),
      'chat_jid': Variable<String>(chatJid),
      'error': Variable<int>(error.index),
      'warning': Variable<int>(warning.index),
      'encryption_protocol': Variable<int>(encryptionProtocol.index),
      'no_store': Variable<bool>(noStore),
      'acked': Variable<bool>(acked),
      'received': Variable<bool>(received),
      'displayed': Variable<bool>(displayed),
      'edited': Variable<bool>(edited),
      'retracted': Variable<bool>(retracted),
      'is_file_upload_notification': Variable<bool>(isFileUploadNotification),
      'file_downloading': Variable<bool>(fileDownloading),
      'file_uploading': Variable<bool>(fileUploading),
      'file_metadata_i_d': Variable<String>(fileMetadataID),
      'delta_account_id': Variable<int>(deltaAccountId),
    };
    if (id != null) {
      map['id'] = Variable<String>(id!);
    }
    if (originID != null) {
      map['origin_i_d'] = Variable<String>(originID);
    }
    final storedSenderRealJid = effectiveSenderRealJid;
    if (storedSenderRealJid != null) {
      map['sender_real_jid'] = Variable<String>(storedSenderRealJid);
    }
    if (mucStanzaId != null) {
      map['muc_stanza_id'] = Variable<String>(mucStanzaId);
    }
    if (occupantID != null) {
      map['occupant_i_d'] = Variable<String>(occupantID);
    }
    if (body != null) {
      map['body'] = Variable<String>(body);
    }
    if (htmlBody != null) {
      map['html_body'] = Variable<String>(htmlBody);
    }
    if (subject != null) {
      map['subject'] = Variable<String>(subject);
    }
    if (timestamp != null) {
      map['timestamp'] = Variable<DateTime>(timestamp!);
    }
    if (trust != null) {
      map['trust'] = Variable<int>(trust!.index);
    }
    if (trusted != null) {
      map['trusted'] = Variable<bool>(trusted!);
    }
    if (deviceID != null) {
      map['device_i_d'] = Variable<int>(deviceID);
    }
    if (quoting != null) {
      map['quoting'] = Variable<String>(quoting);
    }
    if (quotingReferenceKind != null) {
      map['quoting_reference_kind'] = Variable<int>(
        quotingReferenceKind!.index,
      );
    }
    if (stickerPackID != null) {
      map['sticker_pack_i_d'] = Variable<String>(stickerPackID);
    }
    if (pseudoMessageType != null) {
      map['pseudo_message_type'] = Variable<int>(pseudoMessageType!.index);
    }
    if (pseudoMessageData != null) {
      map['pseudo_message_data'] = Variable<String>(
        const MapStringDynamicConverter().toSql(pseudoMessageData!),
      );
    }
    if (manualSendAgainStanzaID != null) {
      map['manual_send_again_stanza_i_d'] = Variable<String>(
        manualSendAgainStanzaID,
      );
    }
    if (deltaChatId != null) {
      map['delta_chat_id'] = Variable<int>(deltaChatId);
    }
    if (deltaMsgId != null) {
      map['delta_msg_id'] = Variable<int>(deltaMsgId);
    }
    return map;
  }
}

extension MessageContent on Message {
  bool get isEmailBacked => deltaChatId != null || deltaMsgId != null;

  String? get emailRfcGroupKey {
    if (!isEmailBacked) {
      return null;
    }
    final originId = normalizeEmailMessageId(originID);
    if (originId == null || originId.isEmpty) {
      return null;
    }
    final chatKey = normalizedAddressKey(chatJid);
    if (chatKey == null || chatKey.isEmpty) {
      return null;
    }
    final senderKey =
        normalizedAddressKey(senderJid) ?? senderJid.trim().toLowerCase();
    if (senderKey.isEmpty) {
      return null;
    }
    return '$chatKey\u0000$deltaAccountId\u0000$senderKey\u0000$originId';
  }

  bool hasSameEmailRfcGroup(Message other) =>
      emailRfcGroupKey != null && emailRfcGroupKey == other.emailRfcGroupKey;

  bool get hasGeneratedEmailAttachmentCaption =>
      pseudoMessageData?['emailAttachmentCaption'] == true;

  bool get hasRfc822BodyContent =>
      pseudoMessageData?['emailRfc822Body'] == true;

  bool canSendXmppReaction({required MessageTransport chatDefaultTransport}) =>
      chatDefaultTransport.isXmpp && !isEmailBacked;

  bool isStaleUnackedXmppSendAgainCandidate({
    required bool isSelf,
    required bool isEmailChat,
    required DateTime staleBefore,
  }) {
    final messageTimestamp = timestamp;
    if (messageTimestamp == null) {
      return false;
    }
    final sendAgainStanzaId = manualSendAgainStanzaID?.trim();
    return !isEmailChat &&
        !isEmailBacked &&
        isSelf &&
        error.isNone &&
        !acked &&
        !received &&
        !displayed &&
        !fileUploading &&
        sendAgainStanzaId?.isNotEmpty != true &&
        !messageTimestamp.toUtc().isAfter(staleBefore.toUtc());
  }

  bool get isHiddenMultiDeviceSyncMessage =>
      isHiddenInternalMultiDeviceSyncMessage(
        subject: subject,
        body: body,
        senderJid: senderJid,
        chatJid: chatJid,
        received: received,
      );

  bool get isFpushMailNotifyMarker {
    if (isEmailBacked) {
      return false;
    }
    final senderKey = normalizedAddressKey(senderJid);
    if (senderKey == null) {
      return false;
    }
    if (senderKey == 'mail-notify') {
      return true;
    }
    return addressLocalPart(senderKey)?.toLowerCase() == 'mail-notify';
  }

  String? get normalizedHtmlBody => HtmlContentCodec.normalizeHtml(htmlBody);

  String get plainText {
    final bodyText = body;
    if (bodyText?.isNotEmpty == true) return bodyText!;
    final html = normalizedHtmlBody;
    if (html == null) return '';
    return HtmlContentCodec.toPlainText(html);
  }
}

enum MessageReferenceKind {
  stanzaId,
  originId,
  mucStanzaId;

  int get storageValue => switch (this) {
    MessageReferenceKind.stanzaId => 0,
    MessageReferenceKind.originId => 1,
    MessageReferenceKind.mucStanzaId => 2,
  };

  String get wireValue => switch (this) {
    MessageReferenceKind.stanzaId => 'stanza-id',
    MessageReferenceKind.originId => 'origin-id',
    MessageReferenceKind.mucStanzaId => 'muc-stanza-id',
  };

  static MessageReferenceKind? fromStorageValue(int? value) => switch (value) {
    0 => MessageReferenceKind.stanzaId,
    1 => MessageReferenceKind.originId,
    2 => MessageReferenceKind.mucStanzaId,
    _ => null,
  };

  static MessageReferenceKind? fromWireValue(String? value) {
    final normalized = value?.trim();
    return switch (normalized) {
      'stanza-id' => MessageReferenceKind.stanzaId,
      'origin-id' => MessageReferenceKind.originId,
      'muc-stanza-id' => MessageReferenceKind.mucStanzaId,
      _ => null,
    };
  }
}

enum DirectMessageReferencePolicy { currentWire, preferOriginId }

final class MessageReference {
  const MessageReference({required this.kind, required this.value});

  final MessageReferenceKind kind;
  final String value;
}

final class MucActorIdentity {
  const MucActorIdentity._({
    required this.senderJid,
    this.occupantJid,
    this.occupantId,
    this.senderRealJid,
  });

  const MucActorIdentity.direct({
    required String senderJid,
    String? senderRealJid,
  }) : this._(senderJid: senderJid, senderRealJid: senderRealJid);

  const MucActorIdentity.room({
    required String occupantJid,
    String? occupantId,
    String? senderRealJid,
  }) : this._(
         senderJid: occupantJid,
         occupantJid: occupantJid,
         occupantId: occupantId,
         senderRealJid: senderRealJid,
       );

  final String senderJid;
  final String? occupantJid;
  final String? occupantId;
  final String? senderRealJid;
}

extension MessageReferenceIds on Message {
  String? get trimmedStanzaId {
    final stanzaId = stanzaID.trim();
    if (stanzaId.isEmpty) {
      return null;
    }
    return stanzaId;
  }

  String? get trimmedOriginId {
    final originId = originID?.trim();
    if (originId == null || originId.isEmpty) {
      return null;
    }
    return originId;
  }

  String? get trimmedMucStanzaId {
    final mucId = mucStanzaId?.trim();
    if (mucId == null || mucId.isEmpty) {
      return null;
    }
    return mucId;
  }

  MucActorIdentity get mucActorIdentity {
    final trimmedSender = senderJid.trim();
    final parsedSender = parseJid(trimmedSender);
    final normalizedChatJid = normalizedAddressValue(chatJid);
    final occupantJid =
        parsedSender != null &&
            parsedSender.resource.trim().isNotEmpty &&
            normalizedChatJid != null &&
            normalizedAddressValue(parsedSender.toBare().toString()) ==
                normalizedChatJid
        ? trimmedSender
        : null;
    if (occupantJid != null) {
      return MucActorIdentity.room(
        occupantJid: occupantJid,
        occupantId: occupantID,
        senderRealJid: effectiveSenderRealJid,
      );
    }
    return MucActorIdentity.direct(
      senderJid: trimmedSender,
      senderRealJid: effectiveSenderRealJid,
    );
  }

  bool get hasMucReference => trimmedMucStanzaId != null;

  bool awaitsMucReference({
    required bool isGroupChat,
    required bool isEmailBacked,
  }) => isGroupChat && !isEmailBacked && !hasMucReference;

  bool waitsForOwnMucReference({
    required bool isGroupChat,
    required bool isEmailBacked,
    required String? selfJid,
    required String? myOccupantJid,
  }) {
    if (!awaitsMucReference(
      isGroupChat: isGroupChat,
      isEmailBacked: isEmailBacked,
    )) {
      return false;
    }
    if (error.isNotNone || retracted) {
      return false;
    }
    final normalizedMyOccupantJid = myOccupantJid?.trim();
    if (normalizedMyOccupantJid != null && normalizedMyOccupantJid.isNotEmpty) {
      if (senderJid.trim() == normalizedMyOccupantJid) {
        return true;
      }
    }
    return sameNormalizedAddressValue(senderJid, selfJid);
  }

  bool get hasUnreadContent {
    final hasBody = body?.trim().isNotEmpty == true;
    final hasSubject = subject?.trim().isNotEmpty == true;
    final hasAttachment = fileMetadataID?.trim().isNotEmpty == true;
    final pseudoMessageType = this.pseudoMessageType;
    if (isHiddenMultiDeviceSyncMessage || isFpushMailNotifyMarker) {
      return false;
    }
    if (!(hasBody || hasSubject || hasAttachment)) {
      return false;
    }
    if (pseudoMessageType != null && !pseudoMessageType.isInvite) {
      return false;
    }
    return true;
  }

  bool countsTowardUnread({
    required String? selfJid,
    required bool isGroupChat,
    required String? myOccupantJid,
  }) {
    if (!hasUnreadContent) {
      return false;
    }
    final realJid = effectiveSenderRealJid;
    if (realJid != null && sameNormalizedAddressValue(realJid, selfJid)) {
      return false;
    }
    if (sameNormalizedAddressValue(senderJid, selfJid)) {
      return false;
    }
    final normalizedMyOccupantJid = myOccupantJid?.trim();
    if (isGroupChat &&
        normalizedMyOccupantJid != null &&
        normalizedMyOccupantJid.isNotEmpty &&
        senderJid.trim() == normalizedMyOccupantJid) {
      return false;
    }
    return true;
  }

  Set<String> get referenceIds => <String>{
    ?trimmedStanzaId,
    ?trimmedOriginId,
    ?trimmedMucStanzaId,
  };

  MessageReference? get _stanzaReference {
    final stanzaId = trimmedStanzaId;
    if (stanzaId == null) {
      return null;
    }
    return MessageReference(
      kind: MessageReferenceKind.stanzaId,
      value: stanzaId,
    );
  }

  MessageReference? get _originReference {
    final originId = trimmedOriginId;
    if (originId == null) {
      return null;
    }
    return MessageReference(
      kind: MessageReferenceKind.originId,
      value: originId,
    );
  }

  MessageReference? get _mucStanzaReference {
    final mucStanzaId = trimmedMucStanzaId;
    if (mucStanzaId == null) {
      return null;
    }
    return MessageReference(
      kind: MessageReferenceKind.mucStanzaId,
      value: mucStanzaId,
    );
  }

  MessageReference? markerReference({required bool isGroupChat}) {
    if (isGroupChat) {
      return _mucStanzaReference;
    }
    return _stanzaReference;
  }

  MessageReference? receiptReference({required bool isGroupChat}) {
    if (isGroupChat) {
      return null;
    }
    return _stanzaReference;
  }

  MessageReference? replyReference({required bool isGroupChat}) {
    if (isEmailBacked) {
      return _originReference;
    }
    if (isGroupChat) {
      return _mucStanzaReference;
    }
    return _originReference ?? _stanzaReference;
  }

  MessageReference? reactionReference({required bool isGroupChat}) {
    if (isEmailBacked) {
      return _originReference;
    }
    if (isGroupChat) {
      return _mucStanzaReference;
    }
    return _originReference ?? _stanzaReference;
  }

  MessageReference? collectionReference({required bool isGroupChat}) {
    if (isEmailBacked) {
      return _originReference;
    }
    if (isGroupChat) {
      return _mucStanzaReference;
    }
    return _originReference ?? _stanzaReference;
  }

  MessageReference? pinReference({required bool isGroupChat}) {
    if (isGroupChat) {
      return _mucStanzaReference;
    }
    return _stanzaReference;
  }

  MessageReference? outboundReference({
    required bool isGroupChat,
    DirectMessageReferencePolicy directPolicy =
        DirectMessageReferencePolicy.currentWire,
  }) {
    if (isGroupChat) {
      return _mucStanzaReference;
    }
    if (directPolicy == DirectMessageReferencePolicy.preferOriginId) {
      return _originReference ?? _stanzaReference;
    }
    return _stanzaReference;
  }

  String? outboundReferenceId({
    required bool isGroupChat,
    DirectMessageReferencePolicy directPolicy =
        DirectMessageReferencePolicy.currentWire,
  }) => outboundReference(
    isGroupChat: isGroupChat,
    directPolicy: directPolicy,
  )?.value;
}

extension MessageForwardingX on Message {
  bool get isForwarded {
    final payload = pseudoMessageData;
    if (payload == null || payload.isEmpty) {
      return false;
    }
    return payload['forwarded'] == true;
  }

  String? get forwardedFromJid {
    final payload = pseudoMessageData;
    if (payload == null || payload.isEmpty) {
      return null;
    }
    final raw = payload['forwardedFromJid'];
    if (raw is! String) {
      return null;
    }
    final resolved = raw.trim();
    if (resolved.isEmpty) {
      return null;
    }
    return resolved;
  }

  String? get forwardedOriginalSenderLabel {
    final payload = pseudoMessageData;
    if (payload == null || payload.isEmpty) {
      return null;
    }
    final raw = payload['forwardedOriginalSenderLabel'];
    if (raw is! String) {
      return null;
    }
    final resolved = raw.trim();
    if (resolved.isEmpty) {
      return null;
    }
    return resolved;
  }

  String? resolveForwardedOriginalSenderLabel() {
    final storedOriginalSender = forwardedOriginalSenderLabel;
    if (storedOriginalSender != null) {
      return storedOriginalSender;
    }
    final markedSubject = syntheticForwardMarkedVisibleSubject(subject);
    final markedSubjectSender = syntheticForwardSenderLabel(markedSubject);
    if (markedSubjectSender != null && markedSubjectSender.isNotEmpty) {
      return markedSubjectSender;
    }
    final subjectSender = syntheticForwardSenderLabel(subject);
    if (subjectSender != null &&
        subjectSender.isNotEmpty &&
        bareAddressOrNull(subjectSender) != null) {
      return subjectSender;
    }
    final bodySender = forwardedBodySenderLabel(body);
    if (bodySender != null && bodySender.isNotEmpty) {
      return bodySender;
    }
    final resource = parseJid(senderJid)?.resource.trim();
    if (resource != null && resource.isNotEmpty) {
      return resource;
    }
    final safeAddress = displaySafeAddress(senderJid)?.trim();
    if (safeAddress != null && safeAddress.isNotEmpty) {
      return safeAddress;
    }
    final sender = senderJid.trim();
    return sender.isEmpty ? null : sender;
  }

  Map<String, dynamic> pseudoMessageDataWithForwarded({
    String? forwardedFromJid,
    String? forwardedOriginalSenderLabel,
  }) {
    final resolvedForwardedFrom = forwardedFromJid?.trim();
    final resolvedOriginalSender = forwardedOriginalSenderLabel?.trim();
    return <String, dynamic>{
      ...(pseudoMessageData ?? const <String, dynamic>{}),
      'forwarded': true,
      if (resolvedForwardedFrom != null && resolvedForwardedFrom.isNotEmpty)
        'forwardedFromJid': resolvedForwardedFrom,
      if (resolvedOriginalSender != null && resolvedOriginalSender.isNotEmpty)
        'forwardedOriginalSenderLabel': resolvedOriginalSender,
    };
  }
}

extension MessageEmailEncryptionStatusX on Message {
  bool get isEmailBackedOpenPgpContent {
    if (pseudoMessageType != null || retracted) {
      return false;
    }
    return encryptionProtocol.isOpenPgp &&
        (deltaChatId != null || deltaMsgId != null);
  }

  bool get isEmailEncryptionStatusMarker {
    return pseudoMessageType == PseudoMessageType.emailEncryptionStatus &&
        stanzaID == emailEncryptionStatusMarkerStanzaId(chatJid);
  }

  String? get emailEncryptionStatusAnchorStanzaId {
    final value = pseudoMessageData?['anchorStanzaId'];
    if (value is! String) {
      return null;
    }
    final anchor = value.trim();
    return anchor.isEmpty ? null : anchor;
  }

  int? get emailEncryptionStatusAnchorTimestampMicros {
    final value = pseudoMessageData?['anchorTimestampMicros'];
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  bool isRenderableEmailEncryptionStatusMarker({
    required Set<String> loadedOpenPgpEmailStanzaIds,
  }) {
    final anchorStanzaId = emailEncryptionStatusAnchorStanzaId;
    return isEmailEncryptionStatusMarker &&
        anchorStanzaId != null &&
        loadedOpenPgpEmailStanzaIds.contains(anchorStanzaId);
  }
}

extension MessageCalendarFragmentX on Message {
  CalendarFragment? get calendarFragment {
    if (pseudoMessageType != PseudoMessageType.calendarFragment) {
      return null;
    }
    final payload = pseudoMessageData;
    if (payload == null || payload.isEmpty) {
      return null;
    }
    try {
      return CalendarFragment.fromJson(Map<String, dynamic>.from(payload));
    } catch (_) {
      return null;
    }
  }
}

extension MessageCalendarTaskIcsX on Message {
  CalendarTaskIcsMessage? get calendarTaskIcsMessage {
    if (pseudoMessageType != PseudoMessageType.calendarTaskIcs) {
      return null;
    }
    final payload = pseudoMessageData;
    if (payload == null || payload.isEmpty) {
      return null;
    }
    return CalendarTaskIcsMessage.tryParse(Map<String, dynamic>.from(payload));
  }

  CalendarTask? get calendarTaskIcs => calendarTaskIcsMessage?.task;

  bool get calendarTaskIcsReadOnly =>
      calendarTaskIcsMessage?.readOnly ??
      CalendarTaskIcsMessage.defaultReadOnly;
}

extension MessageCalendarAvailabilityX on Message {
  CalendarAvailabilityMessage? get calendarAvailabilityMessage {
    final type = pseudoMessageType;
    if (type == null || !type.isCalendarAvailability) {
      return null;
    }
    final payload = pseudoMessageData;
    if (payload == null || payload.isEmpty) {
      return null;
    }
    try {
      return CalendarAvailabilityMessage.fromJson(
        Map<String, dynamic>.from(payload),
      );
    } catch (_) {
      return null;
    }
  }

  CalendarAvailabilityMessage? validatedCalendarAvailabilityMessage({
    String? Function(String shareId)? ownerJidForShare,
  }) {
    final raw = calendarAvailabilityMessage;
    if (raw == null) {
      return null;
    }
    final isValid = raw.map(
      share: (value) => senderMatchesClaimedJid(value.share.overlay.owner),
      request: (value) {
        final request = value.request;
        if (!senderMatchesClaimedJid(request.requesterJid)) {
          return false;
        }
        final claimedOwner = request.ownerJid?.trim();
        if (claimedOwner == null || claimedOwner.isEmpty) {
          return true;
        }
        final knownOwner = ownerJidForShare?.call(request.shareId)?.trim();
        if (knownOwner == null || knownOwner.isEmpty) {
          return true;
        }
        return sameBareAddress(claimedOwner, knownOwner);
      },
      response: (value) {
        final ownerJid = ownerJidForShare?.call(value.response.shareId)?.trim();
        if (ownerJid == null || ownerJid.isEmpty) {
          return true;
        }
        return senderMatchesClaimedJid(ownerJid);
      },
    );
    return isValid ? raw : null;
  }
}

CalendarTask? _decodeCalendarTaskIcsPayload(CalendarTaskIcsPayload payload) {
  final raw = payload.ics.trim();
  if (raw.isEmpty) return null;
  const maxBytes = maxMessageHtmlBytes;
  if (!isWithinUtf8ByteLimit(raw, maxBytes: maxBytes)) {
    return null;
  }
  try {
    const calendarTaskIcsCodec = CalendarTaskIcsCodec();
    return calendarTaskIcsCodec.decode(raw);
  } on Exception {
    return null;
  }
}

PseudoMessageType? _availabilityPseudoMessageType(
  CalendarAvailabilityMessagePayload? payload,
) {
  final message = payload?.message;
  if (message == null) {
    return null;
  }
  return message.map(
    share: (_) => PseudoMessageType.calendarAvailabilityShare,
    request: (_) => PseudoMessageType.calendarAvailabilityRequest,
    response: (_) => PseudoMessageType.calendarAvailabilityResponse,
  );
}

class _ParsedInvite {
  _ParsedInvite({
    required this.type,
    required this.data,
    required this.displayBody,
    this.chatJidOverride,
  });

  final PseudoMessageType type;
  final Map<String, dynamic> data;
  final String displayBody;
  final String? chatJidOverride;

  static const _invitePrefix = 'axc-invite:';
  static const _inviteRevokePrefix = 'axc-invite-revoke:';
  static const _inviteBodyLabel = 'You have been invited to a group chat';
  static const _inviteRevokedBodyLabel = 'Invite revoked';
  static const _inviteAcceptedBodyLabel = 'Invite accepted';
  static const _messageTypeGroupChat = 'groupchat';

  static String? _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed?.isNotEmpty == true) return trimmed;
    }
    return null;
  }

  static String? _normalizeBareJid(String? raw) {
    return bareAddress(raw);
  }

  static bool _matchesBareJid(String candidate, String expectedBare) {
    return sameBareAddress(candidate, expectedBare);
  }

  static _ParsedInvite? fromEvent(
    mox.MessageEvent event, {
    required String to,
  }) {
    if (event.type == _messageTypeGroupChat) {
      return null;
    }
    final senderBare = _normalizeBareJid(event.from.toBare().toString());
    final recipientBare = _normalizeBareJid(to);
    if (senderBare == null || recipientBare == null) {
      return null;
    }
    final directInvite = event.get<DirectMucInviteData>();
    final axiInvite = event.get<AxiMucInvitePayload>();
    if (directInvite == null && axiInvite == null) {
      return fromBody(event.text, to: recipientBare, sender: senderBare);
    }

    final roomJid = _firstNonEmpty([axiInvite?.roomJid, directInvite?.roomJid]);
    if (roomJid == null) {
      return fromBody(event.text, to: recipientBare, sender: senderBare);
    }

    final kind = axiInvite?.kind ?? AxiMucInvitePayloadKind.invite;
    final payloadInviter = _firstNonEmpty([axiInvite?.inviter]);
    final payloadInvitee = _firstNonEmpty([axiInvite?.invitee]);
    if (kind.isAcceptance) {
      if (payloadInvitee == null ||
          payloadInviter == null ||
          !_matchesBareJid(payloadInvitee, senderBare)) {
        return null;
      }
      if (!_matchesBareJid(payloadInviter, recipientBare) &&
          !_matchesBareJid(senderBare, recipientBare)) {
        return null;
      }
    } else {
      if (payloadInviter != null &&
          !_matchesBareJid(payloadInviter, senderBare)) {
        return null;
      }
      if (payloadInvitee != null &&
          !_matchesBareJid(payloadInvitee, recipientBare)) {
        return null;
      }
    }

    final inviterCandidate = kind.isAcceptance
        ? _firstNonEmpty([payloadInviter, recipientBare])
        : _firstNonEmpty([payloadInviter, senderBare]);
    final inviteeCandidate = kind.isAcceptance
        ? _firstNonEmpty([payloadInvitee, senderBare])
        : _firstNonEmpty([payloadInvitee, recipientBare]);
    final inviter = _normalizeBareJid(inviterCandidate) ?? inviterCandidate;
    final invitee = _normalizeBareJid(inviteeCandidate) ?? inviteeCandidate;
    final chatJidOverride =
        kind.isAcceptance && _matchesBareJid(senderBare, recipientBare)
        ? inviter
        : null;
    final roomName = _firstNonEmpty([axiInvite?.roomName]);
    final reason = kind.isAcceptance
        ? null
        : _firstNonEmpty([axiInvite?.reason, directInvite?.reason]);
    final password = kind.isAcceptance
        ? null
        : _firstNonEmpty([axiInvite?.password, directInvite?.password]);
    final token = _firstNonEmpty([axiInvite?.token]);
    if (kind.isAcceptance && token == null) {
      return null;
    }

    final payload = <String, dynamic>{
      'roomJid': roomJid,
      'inviter': ?inviter,
      'invitee': ?invitee,
      'roomName': ?roomName,
      'reason': ?reason,
      'password': ?password,
      'token': ?token,
      if (kind.isRevocation) 'revoked': true,
      if (kind.isAcceptance) 'accepted': true,
    };

    return _ParsedInvite(
      type: kind.isAcceptance
          ? PseudoMessageType.mucInviteAccepted
          : kind.isRevocation
          ? PseudoMessageType.mucInviteRevocation
          : PseudoMessageType.mucInvite,
      data: payload,
      displayBody: kind.isAcceptance
          ? _inviteAcceptedBodyLabel
          : kind.isRevocation
          ? _inviteRevokedBodyLabel
          : _inviteBodyLabel,
      chatJidOverride: chatJidOverride,
    );
  }

  static _ParsedInvite? fromBody(
    String body, {
    required String to,
    required String sender,
  }) {
    if (body.isEmpty) return null;
    final recipientBare = _normalizeBareJid(to);
    final senderBare = _normalizeBareJid(sender);
    if (recipientBare == null || senderBare == null) {
      return null;
    }
    final lines = body.split('\n');
    final metaLine = lines.lastWhere(
      (line) =>
          line.trim().startsWith(_invitePrefix) ||
          line.trim().startsWith(_inviteRevokePrefix),
      orElse: () => '',
    );
    if (metaLine.isEmpty) return null;
    final isRevoke = metaLine.startsWith(_inviteRevokePrefix);
    final jsonString = metaLine.substring(
      isRevoke ? _inviteRevokePrefix.length : _invitePrefix.length,
    );
    Map<String, dynamic> payload = {};
    try {
      payload = jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
    final rawInviter = payload['inviter'] as String?;
    if (rawInviter != null && !_matchesBareJid(rawInviter, senderBare)) {
      return null;
    }
    final rawInvitee = payload['invitee'] as String?;
    if (rawInvitee != null && !_matchesBareJid(rawInvitee, recipientBare)) {
      return null;
    }
    payload['inviter'] ??= senderBare;
    payload['invitee'] ??= recipientBare;
    final displayBody = isRevoke ? _inviteRevokedBodyLabel : _inviteBodyLabel;
    return _ParsedInvite(
      type: isRevoke
          ? PseudoMessageType.mucInviteRevocation
          : PseudoMessageType.mucInvite,
      data: payload,
      displayBody: displayBody,
    );
  }
}

@UseRowClass(Message)
@TableIndex(
  name: 'messages_delta_locator',
  columns: {#deltaAccountId, #deltaMsgId},
  unique: true,
)
class Messages extends Table {
  TextColumn get id => text().clientDefault(() => uuid.v4())();

  TextColumn get stanzaID => text()();

  TextColumn get originID => text().nullable()();

  TextColumn get mucStanzaId => text().nullable()();

  TextColumn get occupantID => text().nullable()();

  TextColumn get senderJid => text()();

  TextColumn get senderRealJid => text().nullable()();

  TextColumn get chatJid => text()();

  TextColumn get body => text().nullable()();

  TextColumn get subject => text().nullable()();

  TextColumn get htmlBody => text().nullable()();

  DateTimeColumn get timestamp =>
      dateTime().clientDefault(() => DateTime.timestamp())();

  IntColumn get error =>
      intEnum<MessageError>().withDefault(const Constant(0))();

  IntColumn get warning =>
      intEnum<MessageWarning>().withDefault(const Constant(0))();

  IntColumn get encryptionProtocol =>
      intEnum<EncryptionProtocol>().withDefault(const Constant(0))();

  IntColumn get trust => intEnum<BTBVTrustState>().nullable()();

  BoolColumn get trusted => boolean().nullable()();

  IntColumn get deviceID => integer().nullable()();

  BoolColumn get noStore => boolean().withDefault(const Constant(false))();

  BoolColumn get acked => boolean().withDefault(const Constant(false))();

  BoolColumn get received => boolean().withDefault(const Constant(false))();

  BoolColumn get displayed => boolean().withDefault(const Constant(false))();

  BoolColumn get edited => boolean().withDefault(const Constant(false))();

  BoolColumn get retracted => boolean().withDefault(const Constant(false))();

  BoolColumn get isFileUploadNotification =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get fileDownloading =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get fileUploading =>
      boolean().withDefault(const Constant(false))();

  TextColumn get fileMetadataID => text().nullable()();

  TextColumn get quoting => text().nullable()();

  IntColumn get quotingReferenceKind =>
      intEnum<MessageReferenceKind>().nullable()();

  TextColumn get stickerPackID => text().nullable()();

  IntColumn get pseudoMessageType => intEnum<PseudoMessageType>().nullable()();

  TextColumn get pseudoMessageData =>
      text().nullable().map(const MapStringDynamicConverter())();

  TextColumn get manualSendAgainStanzaID => text().nullable()();

  IntColumn get deltaChatId => integer().nullable()();

  IntColumn get deltaMsgId => integer().nullable()();

  IntColumn get deltaAccountId =>
      integer().withDefault(const Constant(DeltaAccountDefaults.legacyId))();

  @override
  Set<Column<Object>>? get primaryKey => {stanzaID};
}

@DataClassName('MessageAttachmentData')
class MessageAttachments extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get messageId => text()();

  TextColumn get fileMetadataId => text()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  TextColumn get transportGroupId => text().nullable()();

  TextColumn get groupQuotedReference => text().nullable()();

  IntColumn get groupQuotedReferenceKind =>
      intEnum<MessageReferenceKind>().nullable()();

  @override
  List<String> get customConstraints => const [
    'UNIQUE(message_id, file_metadata_id)',
  ];
}

@DataClassName('MessageShareData')
class MessageShares extends Table {
  TextColumn get shareId => text()();

  IntColumn get originatorDcMsgId => integer().nullable()();

  TextColumn get subjectToken => text().nullable()();

  TextColumn get subject => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.timestamp())();

  IntColumn get participantCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {shareId};

  @override
  List<String> get customConstraints => const ['UNIQUE(subject_token)'];
}

@DataClassName('MessageParticipantData')
class MessageParticipants extends Table {
  TextColumn get shareId => text().references(MessageShares, #shareId)();

  TextColumn get contactJid => text()();

  TextColumn get role => textEnum<MessageParticipantRole>()();

  @override
  Set<Column> get primaryKey => {shareId, contactJid};
}

@DataClassName('MessageCopyData')
class MessageCopies extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get shareId => text().references(MessageShares, #shareId)();

  IntColumn get dcMsgId => integer()();

  IntColumn get dcChatId => integer()();

  IntColumn get dcAccountId =>
      integer().withDefault(const Constant(DeltaAccountDefaults.legacyId))();

  @override
  List<String> get customConstraints => const [
    'UNIQUE(dc_msg_id, dc_account_id)',
  ];
}

@Freezed(toJson: false, fromJson: false)
abstract class Reaction with _$Reaction {
  const factory Reaction({
    required String messageID,
    required String senderJid,
    required String emoji,
  }) = _Reaction;
}

@UseRowClass(Reaction)
class Reactions extends Table {
  TextColumn get messageID => text().references(Messages, #stanzaID)();

  TextColumn get senderJid => text()();

  TextColumn get emoji => text()();

  @override
  Set<Column> get primaryKey => {messageID, senderJid, emoji};
}

@Freezed(toJson: false, fromJson: false)
abstract class ReactionState with _$ReactionState {
  const factory ReactionState({
    required String messageID,
    required String senderJid,
    required DateTime updatedAt,
    required bool identityVerified,
  }) = _ReactionState;
}

@UseRowClass(ReactionState)
class ReactionStates extends Table {
  TextColumn get messageID => text().references(Messages, #stanzaID)();

  TextColumn get senderJid => text()();

  DateTimeColumn get updatedAt => dateTime()();

  BoolColumn get identityVerified =>
      boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {messageID, senderJid};
}

@Freezed(toJson: false, fromJson: false)
abstract class Notification with _$Notification {
  const factory Notification({
    required int id,
    required String? senderJid,
    required String chatJid,
    required String? senderName,
    required String body,
    required DateTime timestamp,
    required String? avatarPath,
    required String? mediaMimeType,
    required String? mediaPath,
  }) = _Notification;
}

@UseRowClass(Notification)
class Notifications extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get senderJid => text().nullable()();

  TextColumn get chatJid => text()();

  TextColumn get senderName => text().nullable()();

  TextColumn get body => text()();

  DateTimeColumn get timestamp => dateTime()();

  TextColumn get avatarPath => text().nullable()();

  TextColumn get mediaMimeType => text().nullable()();

  TextColumn get mediaPath => text().nullable()();
}
