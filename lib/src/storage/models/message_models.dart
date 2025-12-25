import 'dart:convert';

import 'package:axichat/src/calendar/models/calendar_availability_message.dart';
import 'package:axichat/src/calendar/models/calendar_fragment.dart';
import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/storage/models/database_converters.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:drift/drift.dart' hide JsonKey;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;
import 'package:omemo_dart/omemo_dart.dart' as omemo;
import 'package:uuid/uuid.dart';

part 'message_models.freezed.dart';

const uuid = Uuid();

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

  String? get tooltip {
    if (this == serviceUnavailable) {
      return 'Recipient\'s client or server does not support this action.';
    }
    return null;
  }

  String get asString => switch (this) {
        serviceUnavailable =>
          'Recipient\'s client or server does not support this action',
        serverNotFound => 'Could not reach server',
        serverTimeout => 'Server timeout',
        unknown =>
          'Message failed to send. Check your connection and try again.',
        notEncryptedForDevice => 'Message not encrypted for this device',
        malformedKey => 'Message has malformed encrypted key',
        unknownSPK => 'Message has unknown Signed Prekey',
        noDeviceSession => 'No session with this device',
        skippingTooManyKeys => 'Message would skip too many keys',
        invalidHMAC => 'Invalid HMAC',
        malformedCiphertext => 'Malformed ciphertext',
        noKeyMaterial => 'Can\'t find contact\'s devices',
        invalidKEX => 'Invalid Key Exchange Signature',
        unknownOmemoError => 'Unknown encryption error',
        invalidAffixElements => 'Invalid affix elements',
        emptyDeviceList => 'Contact has no devices to encrypt for',
        omemoUnsupported => 'Contact doesn\'t support encryption',
        encryptionFailure => 'Encryption failed',
        invalidEnvelope => 'Invalid contents',
        plaintextFileInOmemo =>
          'Attachment could not be encrypted. Please try again.',
        emailSendFailure => 'Email failed to send',
        emailAttachmentTooLarge => 'Attachment is too large to send',
        emailRecipientRejected => 'Recipient email server rejected the message',
        emailAuthenticationFailed =>
          'Email credentials were rejected by the server',
        emailBounced => 'Email bounced back from the recipient',
        emailThrottled => 'Email sending temporarily throttled',
        _ => toString(),
      };

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

enum EncryptionProtocol {
  none,
  omemo,
  mls;

  bool get isNone => this == none;

  bool get isNotNone => this != none;

  bool get isOmemo => this == omemo;

  bool get isMls => this == mls;
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
  calendarAvailabilityShare,
  calendarAvailabilityRequest,
  calendarAvailabilityResponse,
}

extension PseudoMessageTypeX on PseudoMessageType {
  bool get isInvite =>
      this == PseudoMessageType.mucInvite ||
      this == PseudoMessageType.mucInviteRevocation;

  bool get isCalendarFragment => this == PseudoMessageType.calendarFragment;

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

  ReactionPreview copyWith({
    String? emoji,
    int? count,
    bool? reactedBySelf,
  }) =>
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
class Message with _$Message implements Insertable<Message> {
  const factory Message({
    required String stanzaID,
    required String senderJid,
    required String chatJid,
    DateTime? timestamp,
    String? id,
    String? originID,
    String? occupantID,
    String? body,
    String? htmlBody,
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
    String? stickerPackID,
    PseudoMessageType? pseudoMessageType,
    Map<String, dynamic>? pseudoMessageData,
    @Default(<ReactionPreview>[]) List<ReactionPreview> reactionsPreview,
    int? deltaChatId,
    int? deltaMsgId,
  }) = _Message;

  const factory Message.fromDb({
    required String id,
    required String stanzaID,
    required String? originID,
    required String? occupantID,
    required String senderJid,
    required String chatJid,
    required String? body,
    required String? htmlBody,
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
    required String? stickerPackID,
    required PseudoMessageType? pseudoMessageType,
    required Map<String, dynamic>? pseudoMessageData,
    @Default(<ReactionPreview>[]) List<ReactionPreview> reactionsPreview,
    required int? deltaChatId,
    required int? deltaMsgId,
  }) = _MessageFromDb;

  factory Message.fromMox(
    mox.MessageEvent event, {
    String? accountJid,
  }) {
    final get = event.extensions.get;
    final to = event.to.toBare().toString();
    final from = event.from.toBare().toString();
    final isGroupChat = event.type == 'groupchat';
    final chatJid = isGroupChat
        ? from
        : (accountJid != null &&
                accountJid.isNotEmpty &&
                from.toLowerCase() == accountJid.toLowerCase()
            ? to
            : from);
    final senderJid = isGroupChat ? event.from.toString() : from;
    final invite = _ParsedInvite.fromEvent(event, to: to);
    final fragmentPayload = get<CalendarFragmentPayload>();
    final availabilityPayload = get<CalendarAvailabilityMessagePayload>();
    final PseudoMessageType? availabilityType =
        _availabilityPseudoMessageType(availabilityPayload);
    final PseudoMessageType? pseudoMessageType = invite?.type ??
        availabilityType ??
        (fragmentPayload == null ? null : PseudoMessageType.calendarFragment);
    final Map<String, dynamic>? pseudoMessageData = invite?.data ??
        availabilityPayload?.message.toJson() ??
        fragmentPayload?.fragment.toJson();
    final htmlData = get<XhtmlImData>();
    final normalizedHtml = HtmlContentCodec.normalizeHtml(
      htmlData?.xhtmlBody,
    );
    final fallbackText = normalizedHtml == null
        ? ''
        : HtmlContentCodec.toPlainText(normalizedHtml);
    final resolvedText = event.text.isNotEmpty ? event.text : fallbackText;

    return Message(
      stanzaID: event.id ?? uuid.v4(),
      senderJid: senderJid,
      chatJid: chatJid,
      body: invite?.displayBody ?? (resolvedText.isEmpty ? null : resolvedText),
      htmlBody: normalizedHtml,
      timestamp: get<mox.DelayedDeliveryData>()?.timestamp,
      noStore: get<mox.MessageProcessingHintData>()?.hints.contains(
                mox.MessageProcessingHint.noStore,
              ) ??
          false,
      quoting: get<mox.ReplyData>()?.id,
      originID: get<mox.StableIdData>()?.originId,
      occupantID: get<mox.OccupantIdData>()?.id ??
          (isGroupChat ? event.from.toString() : null),
      encryptionProtocol:
          event.encrypted ? EncryptionProtocol.omemo : EncryptionProtocol.none,
      deviceID: get<OmemoDeviceData>()?.id,
      error: MessageError.fromOmemo(event.encryptionError),
      pseudoMessageType: pseudoMessageType,
      pseudoMessageData: pseudoMessageData,
    );
  }

  const Message._();

  bool authorized(mox.JID jid) =>
      mox.JID.fromString(senderJid).toBare() == jid.toBare();

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
  }) {
    final extensions = <mox.StanzaHandlerExtension>[
      const mox.MarkableData(true),
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
        extensions.add(
          XhtmlImData(
            xhtmlBody: xhtml,
            plainText: outgoingBody,
          ),
        );
      }
    }
    if (replyData != null) {
      extensions.add(replyData);
    }

    if (noStore) {
      extensions.add(
        const mox.MessageProcessingHintData(
          [mox.MessageProcessingHint.noStore],
        ),
      );
    }

    // Add OMEMO flag if encryption is requested
    if (encryptionProtocol == EncryptionProtocol.omemo) {
      // The OmemoManager will intercept based on _shouldEncryptStanza callback
      // But we should ensure the message is properly flagged
      extensions.add(mox.StableIdData(originID ?? stanzaID, null));
    }

    extensions.addAll(extraExtensions);

    final toJid = toJidOverride ?? mox.JID.fromString(chatJid);
    return mox.MessageEvent(
      mox.JID.fromString(senderJid),
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
    };
    if (id != null) {
      map['id'] = Variable<String>(id!);
    }
    if (originID != null) {
      map['origin_i_d'] = Variable<String>(originID);
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
  String? get normalizedHtmlBody => HtmlContentCodec.normalizeHtml(htmlBody);

  String get plainText {
    final bodyText = body;
    if (bodyText?.isNotEmpty == true) return bodyText!;
    final html = normalizedHtmlBody;
    if (html == null) return '';
    return HtmlContentCodec.toPlainText(html);
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
      return CalendarFragment.fromJson(
        Map<String, dynamic>.from(payload),
      );
    } catch (_) {
      return null;
    }
  }
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
  });

  final PseudoMessageType type;
  final Map<String, dynamic> data;
  final String displayBody;

  static const _invitePrefix = 'axc-invite:';
  static const _inviteRevokePrefix = 'axc-invite-revoke:';
  static const _inviteBodyLabel = 'You have been invited to a group chat';
  static const _inviteRevokedBodyLabel = 'Invite revoked';

  static String? _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed?.isNotEmpty == true) return trimmed;
    }
    return null;
  }

  static _ParsedInvite? fromEvent(mox.MessageEvent event,
      {required String to}) {
    final directInvite = event.get<DirectMucInviteData>();
    final axiInvite = event.get<AxiMucInvitePayload>();
    if (directInvite == null && axiInvite == null) {
      return fromBody(event.text, to: to);
    }

    final roomJid = _firstNonEmpty([
      axiInvite?.roomJid,
      directInvite?.roomJid,
    ]);
    if (roomJid == null) {
      return fromBody(event.text, to: to);
    }

    final inviter = _firstNonEmpty([
      axiInvite?.inviter,
      event.from.toBare().toString(),
    ]);
    final invitee = _firstNonEmpty([
      axiInvite?.invitee,
      to,
    ]);
    final roomName = _firstNonEmpty([axiInvite?.roomName]);
    final reason = _firstNonEmpty([
      axiInvite?.reason,
      directInvite?.reason,
    ]);
    final password = _firstNonEmpty([
      axiInvite?.password,
      directInvite?.password,
    ]);
    final token = _firstNonEmpty([axiInvite?.token]);
    final isRevoked = axiInvite?.revoked == true;

    final payload = <String, dynamic>{
      'roomJid': roomJid,
      if (inviter != null) 'inviter': inviter,
      if (invitee != null) 'invitee': invitee,
      if (roomName != null) 'roomName': roomName,
      if (reason != null) 'reason': reason,
      if (password != null) 'password': password,
      if (token != null) 'token': token,
      if (isRevoked) 'revoked': true,
    };

    return _ParsedInvite(
      type: isRevoked
          ? PseudoMessageType.mucInviteRevocation
          : PseudoMessageType.mucInvite,
      data: payload,
      displayBody: isRevoked ? _inviteRevokedBodyLabel : _inviteBodyLabel,
    );
  }

  static _ParsedInvite? fromBody(String body, {required String to}) {
    if (body.isEmpty) return null;
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
    payload['invitee'] ??= to;
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
class Messages extends Table {
  TextColumn get id => text().clientDefault(() => uuid.v4())();

  TextColumn get stanzaID => text()();

  TextColumn get originID => text().nullable()();

  TextColumn get occupantID => text().nullable()();

  TextColumn get senderJid => text()();

  TextColumn get chatJid => text()();

  TextColumn get body => text().nullable()();

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

  TextColumn get stickerPackID => text().nullable()();

  IntColumn get pseudoMessageType => intEnum<PseudoMessageType>().nullable()();

  TextColumn get pseudoMessageData =>
      text().nullable().map(const MapStringDynamicConverter())();

  IntColumn get deltaChatId => integer().nullable()();

  IntColumn get deltaMsgId => integer().nullable()();

  @override
  Set<Column<Object>>? get primaryKey => {stanzaID};
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

  List<Index> get indexes => [
        Index(
          'idx_message_participants_contact',
          'contact_jid, share_id',
        ),
      ];
}

@DataClassName('MessageCopyData')
class MessageCopies extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get shareId => text().references(MessageShares, #shareId)();

  IntColumn get dcMsgId => integer()();

  IntColumn get dcChatId => integer()();

  @override
  List<String> get customConstraints => const ['UNIQUE(dc_msg_id)'];

  List<Index> get indexes => [
        Index('idx_message_copies_share', 'share_id, dc_chat_id'),
        Index('idx_message_copies_dc_msg', 'dc_msg_id'),
      ];
}

@Freezed(toJson: false, fromJson: false)
class Reaction with _$Reaction {
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
class Notification with _$Notification {
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
